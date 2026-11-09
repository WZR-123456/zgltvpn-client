#![cfg_attr(not(debug_assertions), windows_subsystem = "windows")]

mod proxy;

use std::path::PathBuf;
use std::sync::Mutex;

use serde::Serialize;
use tauri::{
    menu::{Menu, MenuItem},
    tray::{MouseButton, MouseButtonState, TrayIconBuilder, TrayIconEvent},
    AppHandle, Emitter, Manager, State, WindowEvent,
};
use tauri_plugin_shell::process::{CommandChild, CommandEvent};
use tauri_plugin_shell::ShellExt;

struct VpnState {
    child: Option<CommandChild>,
    running: bool,
    config_dir: PathBuf,
    config_path: PathBuf,
    node: String,
}

impl VpnState {
    fn new(config_dir: PathBuf) -> Self {
        let config_path = config_dir.join("config.json");
        Self {
            child: None,
            running: false,
            config_dir,
            config_path,
            node: "auto".into(),
        }
    }
}

#[derive(Serialize, Clone)]
struct StatusPayload {
    running: bool,
    node: String,
}

fn emit_status(app: &AppHandle) {
    if let Some(state) = app.try_state::<Mutex<VpnState>>() {
        let (running, node) = {
            let s = state.lock().unwrap();
            (s.running, s.node.clone())
        };
        let _ = app.emit(
            "vpn-status",
            StatusPayload { running, node },
        );
        if let Some(tray) = app.tray_by_id("main") {
            let _ = tray.set_tooltip(if running {
                "ZGLTVPN · 已连接"
            } else {
                "ZGLTVPN · 未连接"
            });
        }
    }
}

fn do_start(app: &AppHandle) -> Result<(), String> {
    let (config_path, config_dir) = {
        let state = app.state::<Mutex<VpnState>>();
        let s = state.lock().map_err(|e| e.to_string())?;
        if s.running {
            return Ok(());
        }
        (s.config_path.clone(), s.config_dir.clone())
    };
    if !config_path.exists() {
        return Err("还没有订阅配置，请先登录并刷新订阅".into());
    }

    let (mut rx, child) = app
        .shell()
        .sidecar("sing-box")
        .map_err(|e| format!("找不到 sing-box 核心: {e}"))?
        .args(["run", "-c", config_path.to_string_lossy().as_ref()])
        .current_dir(&config_dir)
        .spawn()
        .map_err(|e| format!("启动 sing-box 失败: {e}"))?;

    {
        let state = app.state::<Mutex<VpnState>>();
        let mut s = state.lock().map_err(|e| e.to_string())?;
        s.child = Some(child);
        s.running = true;
    }

    // 开系统代理；失败只记日志，不阻断连接本身
    if let Err(e) = proxy::enable_system_proxy() {
        let _ = app.emit("vpn-log", format!("[警告] 设置系统代理失败: {e}"));
    }

    // 后台消费核心输出：记日志，并处理核心意外退出
    let app2 = app.clone();
    tauri::async_runtime::spawn(async move {
        while let Some(event) = rx.recv().await {
            match event {
                CommandEvent::Stdout(line) | CommandEvent::Stderr(line) => {
                    let text = String::from_utf8_lossy(&line).trim().to_string();
                    if !text.is_empty() {
                        let _ = app2.emit("vpn-log", text);
                    }
                }
                CommandEvent::Terminated(payload) => {
                    let _ = app2.emit(
                        "vpn-log",
                        format!(
                            "[核心退出] code={:?} signal={:?}",
                            payload.code, payload.signal
                        ),
                    );
                    if let Some(state) = app2.try_state::<Mutex<VpnState>>() {
                        let mut s = state.lock().unwrap();
                        s.child = None;
                        s.running = false;
                    }
                    let _ = proxy::disable_system_proxy();
                    emit_status(&app2);
                }
                _ => {}
            }
        }
    });

    emit_status(app);
    Ok(())
}

fn do_stop(app: &AppHandle) -> Result<(), String> {
    let child = {
        let state = app.state::<Mutex<VpnState>>();
        let mut s = state.lock().map_err(|e| e.to_string())?;
        s.running = false;
        s.child.take()
    };
    if let Some(mut child) = child {
        let _ = child.kill();
    }
    let _ = proxy::disable_system_proxy();
    emit_status(app);
    Ok(())
}

fn do_toggle(app: &AppHandle) -> Result<(), String> {
    let running = {
        let state = app.state::<Mutex<VpnState>>();
        state.lock().map_err(|e| e.to_string())?.running
    };
    if running {
        do_stop(app)
    } else {
        do_start(app)
    }
}

#[tauri::command]
fn get_status(state: State<'_, Mutex<VpnState>>) -> Result<StatusPayload, String> {
    let s = state.lock().map_err(|e| e.to_string())?;
    Ok(StatusPayload {
        running: s.running,
        node: s.node.clone(),
    })
}

/// 前端把合并好的 sing-box 配置写到本地（%APPDATA%/com.zgltvpn.client/sing-box/config.json）。
#[tauri::command]
fn save_config(app: AppHandle, config: serde_json::Value) -> Result<(), String> {
    let (config_dir, config_path) = {
        let state = app.state::<Mutex<VpnState>>();
        let s = state.lock().map_err(|e| e.to_string())?;
        (s.config_dir.clone(), s.config_path.clone())
    };
    std::fs::create_dir_all(&config_dir).map_err(|e| format!("创建配置目录失败: {e}"))?;
    let text = serde_json::to_string_pretty(&config).map_err(|e| e.to_string())?;
    std::fs::write(&config_path, text).map_err(|e| format!("写入配置失败: {e}"))?;
    Ok(())
}

#[tauri::command]
fn set_current_node(app: AppHandle, node: String) -> Result<(), String> {
    {
        let state = app.state::<Mutex<VpnState>>();
        let mut s = state.lock().map_err(|e| e.to_string())?;
        s.node = node;
    }
    emit_status(&app);
    Ok(())
}

#[tauri::command]
fn start_vpn(app: AppHandle) -> Result<(), String> {
    do_start(&app)
}

#[tauri::command]
fn stop_vpn(app: AppHandle) -> Result<(), String> {
    do_stop(&app)
}

fn main() {
    tauri::Builder::default()
        .plugin(tauri_plugin_shell::init())
        .setup(|app| {
            let config_dir = app
                .path()
                .app_config_dir()
                .map_err(|e| e.to_string())?
                .join("sing-box");
            app.manage(Mutex::new(VpnState::new(config_dir)));

            let toggle =
                MenuItem::with_id(app, "toggle", "连接 / 断开", true, None::<&str>)?;
            let show =
                MenuItem::with_id(app, "show", "显示主窗口", true, None::<&str>)?;
            let quit = MenuItem::with_id(app, "quit", "退出", true, None::<&str>)?;
            let menu = Menu::with_items(app, &[&toggle, &show, &quit])?;

            let _tray = TrayIconBuilder::with_id("main")
                .icon(app.default_window_icon().unwrap().clone())
                .tooltip("ZGLTVPN · 未连接")
                .menu(&menu)
                .show_menu_on_left_click(false)
                .on_menu_event(|app, event| match event.id().as_ref() {
                    "toggle" => {
                        if let Err(e) = do_toggle(app) {
                            let _ = app.emit("vpn-log", format!("操作失败: {e}"));
                        }
                    }
                    "show" => {
                        if let Some(w) = app.get_webview_window("main") {
                            let _ = w.show();
                            let _ = w.set_focus();
                        }
                    }
                    "quit" => {
                        let _ = do_stop(app);
                        app.exit(0);
                    }
                    _ => {}
                })
                .on_tray_icon_event(|tray, event| {
                    if let TrayIconEvent::Click {
                        button: MouseButton::Left,
                        button_state: MouseButtonState::Up,
                        ..
                    } = event
                    {
                        let app = tray.app_handle();
                        if let Some(w) = app.get_webview_window("main") {
                            let _ = w.show();
                            let _ = w.set_focus();
                        }
                    }
                })
                .build(app)?;
            Ok(())
        })
        .on_window_event(|window, event| {
            // 点关闭时收到托盘，不退出程序
            if let WindowEvent::CloseRequested { api, .. } = event {
                api.prevent_close();
                let _ = window.hide();
            }
        })
        .invoke_handler(tauri::generate_handler![
            get_status,
            save_config,
            set_current_node,
            start_vpn,
            stop_vpn
        ])
        .run(tauri::generate_context!())
        .expect("启动 ZGLTVPN 失败");
}
