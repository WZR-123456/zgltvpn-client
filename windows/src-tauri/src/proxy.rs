//! Windows 系统代理设置。
//!
//! MVP 用 mixed 入站（127.0.0.1:10808）+ 系统代理模式，不启用 TUN，
//! 因此不需要管理员权限和 wintun 驱动。连接时开启代理，断开时关闭。

use winreg::enums::*;
use winreg::RegKey;

const INTERNET_SETTINGS_KEY: &str =
    "Software\\Microsoft\\Windows\\CurrentVersion\\Internet Settings";
const PROXY_SERVER: &str = "127.0.0.1:10808";

#[link(name = "wininet")]
extern "system" {
    fn InternetSetOptionW(
        h_internet: *mut core::ffi::c_void,
        dw_option: u32,
        lp_buffer: *mut core::ffi::c_void,
        dw_buffer_length: u32,
    ) -> i32;
}

const INTERNET_OPTION_SETTINGS_CHANGED: u32 = 39;
const INTERNET_OPTION_REFRESH: u32 = 37;

fn notify_settings_changed() {
    unsafe {
        InternetSetOptionW(
            core::ptr::null_mut(),
            INTERNET_OPTION_SETTINGS_CHANGED,
            core::ptr::null_mut(),
            0,
        );
        InternetSetOptionW(
            core::ptr::null_mut(),
            INTERNET_OPTION_REFRESH,
            core::ptr::null_mut(),
            0,
        );
    }
}

fn internet_settings_key() -> Result<RegKey, String> {
    RegKey::predef(HKEY_CURRENT_USER)
        .open_subkey_with_flags(INTERNET_SETTINGS_KEY, KEY_SET_VALUE)
        .map_err(|e| format!("打开注册表失败: {e}"))
}

/// 开启系统代理（走本地 mixed 入站；本地地址直连，避免 Clash API 走代理）。
pub fn enable_system_proxy() -> Result<(), String> {
    let key = internet_settings_key()?;
    key.set_value("ProxyEnable", &1u32)
        .map_err(|e| format!("写入 ProxyEnable 失败: {e}"))?;
    key.set_value("ProxyServer", &PROXY_SERVER)
        .map_err(|e| format!("写入 ProxyServer 失败: {e}"))?;
    key.set_value("ProxyOverride", &"<local>")
        .map_err(|e| format!("写入 ProxyOverride 失败: {e}"))?;
    notify_settings_changed();
    Ok(())
}

/// 关闭系统代理。
pub fn disable_system_proxy() -> Result<(), String> {
    let key = internet_settings_key()?;
    key.set_value("ProxyEnable", &0u32)
        .map_err(|e| format!("写入 ProxyEnable 失败: {e}"))?;
    notify_settings_changed();
    Ok(())
}
