# ZGLTVPN 客户端

品牌一键 VPN 客户端：Android + Windows 先行，iOS 延后。

## 结构

- `android/` — SFA（sing-box-for-android）fork：Kotlin + libbox，改品牌与一键流程
- `windows/` — Tauri v2 + React/TypeScript，sidecar 进程跑官方 sing-box.exe
- `shared/` — 两个平台共用的契约与模板
  - `SUBSCRIPTION.md` — 登录 / 订阅 / 配置合并的共享规范
  - `singbox-template.json` — 客户端侧 inbounds / dns / route 模板（与服务端下发的 outbounds 合并）

## 构建（全部走 GitHub Actions，不在本机打包）

- Android：fork 后 Actions 出 APK（需要 Go 1.26+、NDK r28、JDK 17、keystore secret）
- Windows：windows-latest runner 出 .exe/.msi（需要 Rust ≥ 1.88、Tauri CLI）

## 状态

- 2026-11-09：选型完成，见 `../files/client-plan-2026-11-09.md`
- 阻塞：无真实节点（后端 nodes 为假测试数据，AlaVPS 待激活）；无 GitHub 仓库
- 下一步：真实节点就绪后先用官方 SFA / sing-box.exe 手工验证订阅，再开工 fork 与 Tauri 工程
