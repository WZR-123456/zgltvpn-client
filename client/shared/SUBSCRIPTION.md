# 订阅与登录 — 共享契约

Android（SFA fork）与 Windows（Tauri）两个客户端都按本文档实现。后端是 Cloudflare Worker `vpn.zgltvpn.workers.dev`，代码见 `../files/vpn-index-fixed-v7-2026-11-08.js`（v7；v8 只加了 KV 缓存，接口不变）。

## 1. 登录

```
POST https://vpn.zgltvpn.workers.dev/api/login
Body: {"email": "…", "password": "…", "totp": "123456"?}
```

- 成功 → `{"token": "<32位会话token>", "user": {…}}`
  - `user.sub_token`：28 位订阅 token，订阅 URL 的唯一凭证。
  - `user.expires`：套餐到期毫秒时间戳；`user.traffic_total` / `user.traffic_used`：流量总额/已用（字节）。
- 失败：
  - 401 密码错；429 五次失败/15 分钟（提示“尝试过多，15 分钟后再试”）；
  - 403 账号被封；`{"need_totp": true}` 表示需输 6 位两步验证码后重发。
- 会话 token 有效期 30 天，存在 KV `sess:<token>`。客户端用它调 `/api/me` 刷新用户信息。
- 存储：`token` 与 `sub_token` 都按密码对待——Android 用 EncryptedSharedPreferences，Windows 用系统凭据库或加密落盘；**绝不写日志、不进崩溃上报、不展示完整订阅链接**。

## 2. 拉订阅（首选 singbox 格式）

```
GET https://vpn.zgltvpn.workers.dev/sub/<sub_token>?format=singbox
```

- 成功返回 JSON：`{log, outbounds, route}`。
  - `outbounds`：节点 outbound（vmess 等）+ `urltest`（tag `auto`）+ `selector`（tag `proxy`，默认 `auto`）+ `direct`。
  - `route.final`：有节点为 `proxy`，无节点为 `direct`。
  - **没有 `inbounds`、没有 `dns`**——客户端必须按第 3 节合并模板后才能交给核心。
- 响应头 `subscription-userinfo`：`upload=0; download=<已用字节>; total=<总额字节>; expire=<到期 unix 秒>`，解析后显示在首页。
- 失败：404 token 无效；403 账号被封；套餐过期时返回空节点列表（只有 direct），客户端识别后提示“套餐已过期，请续费”。
- 备用格式：默认 Clash YAML；`?format=base64` 为 vmess:// 链接的 base64；`?format=surge` 为 Surge 配置。仅在 singbox 格式不可用时使用。
- 节点协议：后端已支持 ss / vmess / vless / trojan / hysteria2，全部是 sing-box 原生类型，新增节点类型时客户端不用改代码。
- 节点状态（公开接口，无需登录）：`GET /api/nodestatus` 返回每节点 `{name, region, ok, ms, history}`，用于列表里显示延迟；另有核心自带的 urltest 自动选最快节点。

## 3. 配置合并算法

取服务端 JSON 的 `outbounds` 与 `route.final`，其余全部取客户端模板 `singbox-template.json`：

1. `inbounds` = 模板的 inbounds（tun + mixed），原样采用。
2. `dns` = 模板的 dns，原样采用。
3. `outbounds` = 服务端 outbounds + 模板追加的 `{type: "dns", tag: "dns-out"}`。
4. `route` = 模板的 route，但 `route.final` 用服务端的 `route.final`（有节点 `proxy`，无节点 `direct`）。
5. `experimental.clash_api`（Windows 用；Android 由 libbox 自带统计接口，忽略本节）。
6. `log.level` 取 `info`。

节点列表 UI：从合并后的 outbounds 里取 tag，排除 `auto`、`proxy`、`direct`、`dns-out`，剩下的就是节点名；默认选中 `auto`。

## 4. 连接流程

1. 首次启动：登录（或粘贴订阅链接导入，从 URL path 取 token）。
2. 拉订阅 → 按第 3 节合并 → 写本地配置 → 启动核心。
   - Android：`VpnService.prepare()` 拿授权，把 TUN fd 交给 libbox。
   - Windows：拉起 sing-box.exe 子进程（`-c 配置路径 run`）。
3. 首页只显示：连接开关、当前节点（默认 Auto，可切换）、状态（已连接/延迟 ms）、剩余流量与到期日。
4. 每次启动与每天一次重新拉订阅；`POST /api/u/reset-sub` 可重置 sub_token（订阅泄露时用，重置后旧链接立即失效）。

## 5. 更新节奏

- 订阅：每次启动拉一次，之后每天一次；失败时用上次缓存的配置继续工作并提示。
- 客户端版本：启动时比对 KV 里的最新版本号（待后端加），有新版提示去官网下载。
