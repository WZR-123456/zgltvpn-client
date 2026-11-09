# ZGLTVPN Windows 客户端

Tauri v2 + React/TypeScript 桌面应用，内嵌官方 sing-box.exe（sidecar 进程）。

## 功能（v0.1 最小可用版）

- **登录**：邮箱 + 密码（支持 TOTP 两步验证），调 `POST /api/login` 拿 `sub_token`；登录信息只存本机 localStorage。
- **拉订阅**：`GET /sub/<sub_token>?format=singbox`，按 `client/shared/SUBSCRIPTION.md` 第 3 节与模板合并（inbounds/dns/route 取模板，outbounds 取服务端 + `dns-out`，`route.final` 取服务端），写本地配置 `%APPDATA%/com.zgltvpn.client/sing-box/config.json`。
- **一键连接/断开**：Rust 后端拉起/杀掉 sing-box.exe sidecar；连接时自动开启 Windows 系统代理（127.0.0.1:10808，本地地址直连），断开时关闭。
- **状态显示**：连接状态、当前节点（默认自动选最快，可切换）、实时上下行（读 sing-box Clash API `/traffic`）、当前节点延迟测试、剩余流量与到期日（读 `subscription-userinfo` 头）。
- **系统托盘**：托盘图标 + 菜单（连接/断开、显示主窗口、退出）；点关闭按钮收到托盘，不退出程序。

## 模式说明（重要）

- MVP 用 **mixed 入站 + 系统代理**，不启用 TUN：不需要管理员权限和 wintun 驱动，大部分应用（浏览器等走系统代理的）可直接用。TUN 模式是第二步（需管理员权限 + 随包带 wintun.dll）。
- 模板里的 `tun-in` 在 Windows 合并时会被去掉（见 `src/singbox.ts`）。

## 本地开发

```bash
cd windows
npm install
npm run tauri dev
```

需要 Rust 工具链（stable）与 Node 20+。sing-box.exe 在开发时需手动放到
`src-tauri/binaries/sing-box-x86_64-pc-windows-msvc.exe`
（从 https://github.com/SagerNet/sing-box/releases/download/v1.14.4/sing-box-1.14.4-windows-amd64.zip 解出）。

## 打包

只走 GitHub Actions（`.github/workflows/windows.yml`，windows-latest）：
构建时自动下载 sing-box 1.14.4，放进 `src-tauri/binaries/` 后用
`tauri-action` 打 NSIS 安装包，上传为 artifact。

**暂不签名**：首次运行会弹 SmartScreen 警告，点“仍要运行”即可；后续再处理代码签名证书。

## 许可证

sing-box 为 GPL-3.0：随安装包提供的 sing-box.exe 受 GPL 约束，
源码见 https://github.com/SagerNet/sing-box ；本项目仓库
https://github.com/WZR-123456/zgltvpn-client 同样公开。
