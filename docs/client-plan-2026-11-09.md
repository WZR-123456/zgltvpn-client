# ZGLTVPN 一键客户端 — 选型与实施计划

日期：2026-11-09 · 平台：Android + Windows 先行，iOS 延后
结论先行：**Android 用 SFA（sing-box for Android）fork；Windows 用 Tauri v2 + sing-box.exe 侧挂进程。两个平台都走 GitHub Actions 云端编译，本机 VM 不负责打包。**

---

## 1. 结论速览

| 平台 | 推荐栈 | 核心引擎 | UI | 打包方式 |
|---|---|---|---|---|
| Android | **Fork SFA**（sing-box-for-android，Kotlin + libbox） | libbox（sing-box 编译成 .aar） | SFA 原生界面改品牌 + 一键首页 | GitHub Actions（ubuntu runner + Android SDK/NDK）出 APK |
| Windows | **Tauri v2 + React/TS**，sidecar 进程跑 sing-box.exe | 官方预编译 sing-box.exe（v1.14.4，31.4 MB） | Web 前端（React/TS），托盘 + 连接开关 | GitHub Actions（windows-latest）出 .exe 安装包 |

为什么不选“一个代码库包打天下”（Flutter/Hiddify fork）：Flutter 在这台 Linux VM 上只能编 Android、编不出 Windows 安装包；Hiddify 是个大而全的 Flutter 工程，fork 后改造成本不低于上面两条路，且 iOS 眼下本来就不做。等 iOS 提上日程时再评估是否把 Android 迁到 Flutter——SFA fork 的订阅/配置逻辑可以复用为 spec。

---

## 2. 本机（这台 Linux VM）工具链现状

2026-11-09 实测：

| 工具 | 状态 | 版本/备注 |
|---|---|---|
| Node.js / npm | ✅ 已装 | node v24.22.1，npm 10.9.4 |
| Python / git / cmake | ✅ 已装 | Python 3.12.3，git 2.43.0，cmake（有，无 ninja） |
| Go | ❌ 未装 | 需装，最新稳定版 go1.27.3；tarball 约 70–100 MB |
| Rust / cargo | ❌ 未装 | rustup 安装约 1 GB（含工具链+注册表缓存） |
| Flutter / Dart | ❌ 未装 | SDK 约 1 GB |
| Java / JDK | ❌ 未装 | SFA 构建要 JDK 17（apt 可装，约 300 MB） |
| Android SDK / NDK / Gradle | ❌ 未装 | cmdline-tools + platform + build-tools + NDK r28 ≈ 2–3 GB |
| 磁盘 | ⚠️ 只有 7.5 GB 总量 | overlay 7.5G，可用 7.5G；/tmp 是 512 MB tmpfs |
| 内存 | ⚠️ 紧张 | 共 7.7 GB，实测当时仅剩约 635 MB 可用；Gradle 守护进程通常要 2–4 GB |
| CPU | 4 核（共享 1.5 核） | 编译会很慢 |
| 网络 | ✅ 通 | github.com、dl.google.com、go.dev、repo.maven.apache.org、static.rust-lang.org、nodejs.org 均可达 |

**结论：本机只适合写代码、做配置、跑轻量验证；打包 APK / Windows 安装包不要在本机做。** 装全套 Android 工具链约 2–3 GB 磁盘，加上 Gradle 缓存和构建产物，7.5 GB 磁盘随时会满；内存也不够 Gradle 用。正确姿势：代码放 GitHub，编译和签名打包走 GitHub Actions 免费 runner（公开仓库免费；私有仓库每月 2000 分钟免费额度，一般够用）。

---

## 3. Android 路线对比

### 3.1 推荐：Fork SFA（sing-box-for-android）

- 是什么：sing-box 官方 Android 客户端，Kotlin 编写，VpnService + libbox（Go 核心编成 .aar 嵌进 App），开源 GPL-3.0，最新版 v1.14.4（2026-10-27），支持 Android 7.0+、arm64/arm/x86。
- 构建要求（实测文档）：Go 1.26+、Android NDK r28、JDK 17；核心命令 `go run ./cmd/internal/build_libbox -target android -platform android/arm64` 生成 libbox.aar，再由 Gradle 打 APK；仓库自带 GitHub Actions 发布流程。
- 要改什么：换包名/应用名/图标为 ZGLTVPN；首页改成品牌一键连接页（登录 → 拉订阅 → 一键连接/断开 → 显示节点、流量、到期）；把 SFA 的高级功能（规则、逐应用代理等）收进“高级”菜单；启动时自动同步订阅。
- 优点：VPN 核心、TUN、耗电/断线重连、逐应用代理全部是现成的、经过大量用户验证的；工作量集中在品牌和一键流程，不用从零写 VpnService。
- 代价：SFA 代码库不小，首次上手要读它的 Profile/Service 结构；GPL-3.0 要求 fork 必须开源、公开源码。

### 3.2 备选：Flutter + libbox（Hiddify 路线）

- 一个 Dart 代码库可覆盖 Android/iOS/Windows/macOS，UI 好做；Hiddify 是现成的参考实现。
- 否决理由（现阶段）：本机没 Flutter，且 Flutter 在 Linux 上编不出 Windows 桌面版；iOS 眼下不做，Flutter 最大的优势暂时用不上；libbox 的 Flutter 插件同样要先走 gomobile 编译，省不掉 Go+NDK；Hiddify 工程庞大，fork 改造成本不比 SFA fork 低。

### 3.3 备选：全新极简 Kotlin App + libbox.aar

- 只写登录 + 列表 + 开关，代码量最小。
- 否决理由：libbox.aar 没有官方预编译发布（Maven Central 查无 `io.nekohasekai:libbox`；sing-box release 里也只有 APK 和核心 tarball，没有 .aar），必须自己用 gomobile 从源码编；且 VpnService 生命周期、保活、断线重连、DNS 泄漏处理都要自己写，等于重做 SFA 已经做好的部分。

---

## 4. Windows 路线对比

### 4.1 推荐：Tauri v2 + React/TypeScript + sing-box.exe sidecar

- 模式（Skylark、Clash Verge Rev、onebox 都是这个模式）：Tauri 壳（Rust）+ Web 前端；sing-box.exe 作为 sidecar 子进程由 Rust 后端拉起/杀掉，配置由前端生成后写盘；用 sing-box 的 experimental Clash API（external-controller）拿实时流量、节点延迟。
- 引擎获取：**不用自己编译**——sing-box 官方 release 自带 `sing-box-1.14.4-windows-amd64.zip`（31.4 MB），解压即得 sing-box.exe，直接放进 `src-tauri/binaries/`。
- 优点：安装包小（Tauri 约 5–15 MB，Electron 约 80–150 MB）；Rust 后端做进程管理、开机自启、托盘都很顺；生态里同类项目最多，遇到问题有现成答案。
- 要求：Rust ≥ 1.88（rustup 装）；**Windows 安装包必须在 Windows 上编**（MSVC 链接器、WebView2、NSIS），走 GitHub Actions windows-latest runner；本机 Linux 编不出（mingw 交叉编译理论可行但 WebView2/NSIS 链路极其折腾，不采用）。
- TUN 模式注意：sing-box 的 tun inbound 在 Windows 上依赖 wintun.dll；做法是随安装包带上 wintun.dll（WireGuard 官方签名），或让 sing-box 首次启动时自动下载。初期可用混合模式（mixed 入站 + 系统代理）先跑通，TUN 作为第二步。

### 4.2 备选：Electron + sing-box.exe

- 优点：本机有 Node，Electron-builder 理论上能在 Linux 上打出 Windows portable zip（NSIS 安装器需要 wine）。
- 否决理由：包体大、内存占用高；同样解决不了“Windows 安装器要在 Windows 上做”的问题；Tauri 在这个品类已是主流，优先选它。

### 4.3 备选：原生 Qt/C++（Throne 路线）

- 优点：性能最好、无 WebView 依赖。
- 否决理由：开发量最大；本机无 Qt 工具链；团队（当前只有这一个 agent + Maya）维护成本最高。

---

## 5. 后端订阅对接（已按 v7 代码核实，文件 `vpn-index-fixed-v7-2026-11-08.js`）

### 5.1 登录

- `POST /api/login` Body `{email, password, totp?}` → 成功返回 `{token, user}`。
  - `token`：32 位随机会话 token，KV `sess:<token>`，有效期 30 天；后续 `/api/me` 凭它鉴权。
  - `user` = pubUser，内含 **`sub_token`**（28 位随机字符串，用户注册时生成，可通过 `POST /api/u/reset-sub` 重置）。
- 失败形态：密码错 401；5 次失败/15 分钟 → 429（“登录尝试过多，请稍后再试”）；账号被封 403；开了 TOTP 时先返回 `{need_totp: true}`，再带 6 位码重发。
- 客户端存储：`token` 和 `sub_token` 都相当于密码。Android 用 EncryptedSharedPreferences；Windows 用系统凭据库（Tauri stronghold / Windows Credential Manager）或至少加密后落盘；**绝不打日志、不进崩溃上报**。

### 5.2 订阅拉取（核心）

- `GET https://vpn.zgltvpn.workers.dev/sub/<sub_token>?format=singbox`
  - 返回**完整的 sing-box JSON 配置**（`buildSingbox` 生成）：`outbounds` = 全部可用节点（vmess 等）+ `urltest`（tag `auto`，10 分钟测速）+ `selector`（tag `proxy`，默认 `auto`）+ `direct`；`route.final` = 有节点时 `proxy`、无节点时 `direct`。
  - **关键限制：这个 JSON 只有 outbounds + route，没有 inbounds、没有 dns。** 不能原样喂给 sing-box 核心。客户端必须做“合并”：取服务端 `outbounds`，叠加客户端自带的 `inbounds`（tun + mixed）、`dns`、`route.rules`、`experimental.clash_api`。模板见 `client/shared/singbox-template.json`，合并规则见 `client/shared/SUBSCRIPTION.md`。
  - 响应头 `subscription-userinfo`：`upload=0; download=<已用字节>; total=<总额字节>; expire=<到期 unix 秒>`——客户端解析后显示流量和到期日。
- 其他格式（备用/兼容）：
  - 默认（无 format）：Clash YAML；`?format=base64`：每行一个 `vmess://` 链接再整体 base64；`?format=surge`：Surge 配置。**首选 singbox 格式**，因为节点结构是结构化 JSON，不用再解析链接。
- 异常：token 无效 → 404 `invalid token`；账号被封 → 403；套餐过期 → 返回空节点列表（outbounds 只有 direct），客户端要识别并提示“套餐已过期，请续费”。
- 节点协议：后端 `nodeToSingbox` 已支持 ss / vmess / vless / trojan / hysteria2 五种，全部是 sing-box 原生 outbound 类型。现在节点是 vmess，将来 Maya 在后台加其他类型节点时客户端不用改代码。
- 节点状态：`GET /api/nodestatus`（公开，无需登录）返回每节点 `ok / ms / history`，客户端可在节点列表里显示延迟；另有 sing-box 自带的 urltest 自动选最快节点。

### 5.3 一键连接流程（两个平台一致）

1. 首次启动：登录页（邮箱+密码，支持 TOTP）→ 拿到 `sub_token`；或“粘贴订阅链接”导入（从 URL 里取 token）。
2. 拉取 `?format=singbox` → 合并客户端模板 → 写本地配置 → 启动核心。
3. Android：经 `VpnService.prepare()` 拿授权后把 TUN fd 交给 libbox；Windows：拉起 sing-box.exe 子进程。
4. 首页只显示：连接开关、当前节点（可切换，默认 Auto）、状态（已连接/延迟 ms）、剩余流量与到期日。
5. 后台定时（每天一次或每次启动）重新拉订阅；`sub_token` 变化时自动重新拉取。

---

## 6. 项目布局（待建）

```
client/
├── README.md                     # 总说明：两个平台怎么编、怎么发版
├── shared/
│   ├── SUBSCRIPTION.md           # 订阅/登录/合并配置的共享契约（两个平台都按它实现）
│   └── singbox-template.json     # 客户端侧 inbounds/dns/route/clash_api 模板
├── android/                      # SFA fork（clone 后改品牌与一键流程）
│   ├── app/src/main/...          # 包名改为 com.zgltvpn.client（待定）
│   └── .github/workflows/        # 沿用 SFA 的 Actions 流程改触发条件
├── windows/                      # Tauri v2 应用
│   ├── src/                      # React + TypeScript 界面
│   ├── src-tauri/                # Rust 后端：进程管理、配置生成、托盘
│   │   └── binaries/sing-box-x86_64-pc-windows-msvc.exe   # 官方预编译核心
│   └── .github/workflows/        # windows-latest 打包 .exe/.msi
└── docs/
    ├── SIGNING.md                # keystore 与证书保管
    └── TESTPLAN.md               # 真机测试清单（等有真实节点后执行）
```

已建好的小脚手架（本次只搭了不会错的部分）：`client/README.md`、`client/shared/SUBSCRIPTION.md`、`client/shared/singbox-template.json`。`android/` 与 `windows/` 的完整工程在下一步建。

---

## 7. 签名、分发与许可证

- **Android 签名**：自建 keystore（`keytool -genkeypair`）即可，不用上架 Play 商店；keystore + 密码必须一次建好、妥善保管（放 Secure Vault + GitHub Actions secret），丢了就无法原地升级、用户必须卸载重装。
- **Android 分发**：官网直接提供 APK 下载（侧载），用户开“允许安装未知来源”即可；不走 Google Play（VPN 类应用上架要开发者账号 $25 + 审核，且支付相关内容敏感）。
- **Windows 签名**：没有代码签名证书也能发，首次运行会弹 SmartScreen 警告（用户点“仍要运行”）；EV 代码签名证书约 $200+/年，初期可不买，等用户量起来再评估。
- **Windows 分发**：官网提供 .exe/.msi 下载；Tauri 可做自动更新（配合 GitHub Releases），初期手动下载即可。
- **许可证（重要）**：sing-box 与 SFA 均为 **GPL-3.0**。Fork 必须开源并公开源码；且不得用 "sing-box" 之名暗示官方关联。品牌统一用 ZGLTVPN，并在仓库放 LICENSE 与源码链接。Windows 端 Tauri 壳本身用 MIT/Apache 没问题，但捆绑的 sing-box.exe 同样受 GPL 约束——随安装包提供源码获取方式即可（链接到 sing-box 官方仓库与本项目 fork）。

---

## 8. 阻塞（按严重程度）

1. **没有真实节点（最大阻塞）**：后端 nodes 现在是假测试数据（香港 server "测试"、台湾 192.168.0.1），AlaVPS 免费 VPS 仍在 Pending，截止 2026-11-09 20:40 CST。若超时未激活，需另找 VPS 来源。没有真实节点，客户端联调完全无法做；只能先做 UI 与订阅解析。
2. **没有 GitHub 账号/仓库**：CI 编译、版本发布、自动更新都依赖它。Maya 是否有 GitHub 账号未知，需确认；没有则注册一个（免费）。
3. **本机无法打包**：见第 2 节。Android 与 Windows 的产物都走 GitHub Actions；本机只写代码与验证逻辑。
4. **待 Maya 确认**：应用包名/显示名（建议 `ZGLTVPN`，包名 `com.zgltvpn.client`）、官网下载页位置、是否接受 GPL 开源 fork、Windows 是否接受初期无签名（SmartScreen 警告）。
5. **iOS 延后项**：Apple 开发者账号（$99/年）、App Store 审核（VPN 需 NetworkExtension 权限，审核严）、macOS 编译机（GitHub Actions macOS runner）。届时优先评估 Flutter/Hiddify 路线复用。

---

## 9. 下一步（按顺序）

1. **先用现成客户端验证订阅**：真实节点一就绪，立刻用官方 SFA APK（手机）与官方 sing-box.exe（Windows 命令行）手工测 `?format=singbox` 返回的配置是否真能连通——这是所有客户端工作的前置验证，比写代码优先。
2. **确认 GitHub 账号**，建公开仓库 `zgltvpn-client`（或等效），生成 Android keystore 并存入 Actions secrets。
3. **Android**：fork sing-box-for-android → 改包名/名/图标 → 加登录页 + 一键首页 + 订阅同步（按 `shared/SUBSCRIPTION.md`）→ Actions 出首个内测 APK → 真机测试。
4. **Windows**：搭 Tauri v2 脚手架 → 捆绑 sing-box.exe → 实现配置合并、拉起/停止、托盘、状态显示 → Actions 出首个 .exe → 真机测试。
5. **官网加“下载客户端”入口**：首页/套餐页挂 APK 与 .exe 下载链接（小改动，等客户端能用时再做）。
6. **更新机制**：客户端启动时比对 KV 里的最新版本号，有新版提示下载（v2 功能，不阻塞首发）。

---

## 10. 风险清单

- SFA/ sing-box 版本升级频繁，fork 后要定期跟进上游安全更新，否则核心会落后。
- 订阅 URL 里 token 泄露 = 账号被盗用：客户端内绝不展示完整订阅链接；提供“重置订阅”入口调用 `POST /api/u/reset-sub`。
- 国内 Android 机型（小米/华为/OPPO 等）的后台保活策略各异，VPN 进程可能被杀，需在应用内做保活提示与自启引导。
- Windows 上部分杀毒软件会误报 sing-box 这类代理核心，需准备说明页；SmartScreen 警告同理。
- 免费 KV 额度问题与客户端无关，但客户端每次启动拉订阅会增加 KV 读（可用 v8 的 30 秒缓存缓解；订阅本身可缓存 1 小时，配置变化不敏感）。
- 若 AlaVPS 长期不激活，首个真实节点来源未定，客户端联调会一直拖着——这是当前最大时间风险。
