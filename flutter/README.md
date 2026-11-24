# ZGLTVPN — Android (Flutter rewrite)

Flutter rewrite of the ZGLTVPN Android client (NORTH project, Phase 4).
Brand: **ZGLTVPN** (中国联通境外VPN). NORTH is only the internal project
codename.

## Status (slice 1 — 2026-11-24)

- [x] Flutter scaffold (Riverpod 2.x, `flutter_secure_storage`, `sing_box`
      plugin dependency pinned)
- [x] Shared API client: login (+TOTP, 429), `/api/me`, `/api/plans`,
      `/api/nodes`, `/api/nodestatus`, subscription fetch (`?format=singbox`)
      + merge with the bundled sing-box template
- [x] Login page (email + password, TOTP field on demand, backend error
      text shown verbatim)
- [x] Home shell (connect button disabled, real traffic/membership from
      `/api/me`, working "刷新订阅", no faked data anywhere)
- [ ] Real VPN tunnel — lands with the Phase 2.5 prototype
      (`sing_box` plugin adapter for the `VpnService` interface)
- [ ] Plans / purchase / orders / messages / tickets / settings
      (later Phase 4 slices)

## Structure

```
lib/
├── main.dart                  # entry (ProviderScope)
├── app.dart                   # MaterialApp + auth-based routing
├── core/
│   ├── config.dart            # API_BASE (single source of truth)
│   ├── theme.dart             # phase-3 design tokens
│   ├── providers.dart         # Riverpod providers
│   ├── api/                   # ApiClient (dio), AuthApi, CatalogApi,
│   │                          # SubscriptionApi, ApiException
│   ├── config/                # mergeConfig port + template loader
│   ├── models/                # User / Plan / Node / UserinfoHeader
│   ├── storage/               # SecureStorage (flutter_secure_storage)
│   └── utils/                 # Format (bytes, expiry, dirty-data clamp)
├── features/
│   ├── auth/                  # login page + AuthController
│   └── connection/            # home shell + HomeController
└── platform/
    └── vpn/                   # plugin-agnostic VpnService interface + stub
assets/
└── singbox-template.json      # synced with client/shared/singbox-template.json
test/
├── merge_config_test.dart     # golden tests for the merge (incl. real asset)
├── userinfo_test.dart
└── format_test.dart
```

## Run / build

```sh
flutter pub get
flutter run                 # Android device / emulator
flutter analyze
flutter test
flutter build apk --debug --split-per-abi
```

Flutter SDK is pinned to **3.47.9** in CI (`.github/workflows/flutter-android.yml`).
Minimum Android: API 24 (Android 7.0).

## Decisions (locked by the Phase 2 architecture)

- **Riverpod 2.6.1** (plain API, no codegen in slice 1). Riverpod 3.5.0 exists
  but the architecture locks 2.x; re-evaluate only as a deliberate step.
- **VPN core: `sing_box` plugin 1.0.0** (pub.dev, GPL-3.0, libbox 1.14.4),
  pinned exactly. The Dart-side `VpnService` interface
  (`lib/platform/vpn/vpn_service.dart`) is plugin-agnostic so the core can
  fall back to a self-built plugin without touching business code.
- **libbox self-compile + plugin fork lock** (architecture §3.3c) are
  deferred to the Phase 2.5 prototype. Slice-1 CI uses the plugin's default
  prebuilt AAR download (SHA-256 verified by the plugin's Gradle).
- **Release signing** reuses the existing Android keystore Actions secrets
  (`ANDROID_KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`,
  `KEY_PASSWORD` — KEY_PASSWORD must equal the store password). Slice 1 CI
  builds debug APKs only; the release job is added with the release build.
- **API base URL** lives only in `lib/core/config.dart` (currently
  `https://vpn.zgltvpn.workers.dev`; switch to `https://cn.521com.xyz`
  once the custom domain is active).
- **No fake data**: connection state, latency, traffic and IP are shown only
  from real measurements or real API responses; otherwise "暂无数据".

## Security rules

- Passwords are never stored, never logged, never put in diagnostics.
- `token` / `sub_token` live only in `flutter_secure_storage`
  (Keystore-backed EncryptedSharedPreferences). Never in logs, never in
  crash reports, never shown in full (subscription links are never
  displayed whole).
- Logout deletes the local session.
- Dirty backend data (e.g. free-plan `traffic_gb = 1e+97`) is clamped in
  `Format` and labelled "不限量（数据异常）" instead of being shown raw.
