# ZGLTVPN Android — fork of sing-box-for-android (SFA)

ZGLTVPN Android client, built on SFA with login + one-tap connect for the
ZGLTVPN service (https://vpn.zgltvpn.workers.dev).

## Upstream

- Source: https://github.com/SagerNet/sing-box-for-android
- Snapshot: `dev` branch, commit `a548a79` ("Bump version 1.15.0-alpha.13")
- Core: sing-box `v1.15.0-alpha.13` (libbox is built from source in CI)
- License: **GPL-3.0** (see `LICENSE`). This fork stays open source under the
  same license. The sing-box name is kept only where technically required
  (the libbox Java package `io.nekohasekai.libbox`, the `sing-box://` deep-link
  scheme, log tags); the app itself is branded ZGLTVPN.

## What changed vs upstream

- Package `io.nekohasekai.sfa` -> `com.zgltvpn.client`; app name -> ZGLTVPN;
  launcher icon replaced with a teal "Z" placeholder; user-visible strings
  no longer mention sing-box/SFA; notification title and VPN session name
  are ZGLTVPN.
- Version reset to `1.0.0` (version code 1) in `version.properties`.
- SFA's committed `app/release.keystore` removed; signing uses the repo
  secrets (see below) and the file is gitignored.
- New `com.zgltvpn.client.zglt` package:
  - `ZgltApi` — `POST /api/login`, `GET /sub/<sub_token>?format=singbox`,
    and the subscription/template merge (contract: `../client/shared/SUBSCRIPTION.md`).
  - `ZgltSubscription` — import/refresh the merged config as the "ZGLTVPN"
    profile (validated with `Libbox.checkConfig`, idempotent update in place).
  - `ZgltLoginScreen` / `ZgltLoginViewModel` — login page (route `zglt_login`),
    TOTP supported, backend error messages shown as-is (incl. the 5-fails /
    15-minutes rate limit).
  - `ZgltDashboardCard` — top card on the dashboard: sign in, big
    Connect/Disconnect button, refresh subscription, account.
- Account data (email, session token, sub_token, plan expiry/traffic) is
  stored in the app's local Settings store only, never in logs or profiles.
  Note: like SFA's own `githubToken`, this store is plaintext on device;
  moving the tokens to EncryptedSharedPreferences is a known follow-up.

## Build (GitHub Actions)

Push to the `android` branch (or run the workflow manually) — see
`.github/workflows/android.yml`. It builds libbox for all 4 ABIs from the
sing-box core, merges the AARs, then runs
`./gradlew :app:assembleOtherRelease` and uploads the APKs as the
`zgltvpn-android-apks` artifact.

Required repo secrets (already set):
`ANDROID_KEYSTORE_BASE64`, `KEYSTORE_PASSWORD`, `KEY_ALIAS`, `KEY_PASSWORD`.

The keystore itself is backed up outside the repo (see the project notes);
losing it would force users to reinstall on key rotation.

## Local build

Needs JDK 17, Android SDK 37, NDK r28, Go 1.26+. libbox is NOT in the
repo (`app/libs/` is gitignored); build it from the sing-box core:

```
# in a sing-box checkout at v1.15.0-alpha.13:
make lib_install
go run ./cmd/internal/build_libbox -target android -platform android/arm64
cp libbox.aar <this repo>/android/app/libs/
# then:
cd android && ./gradlew :app:assembleOtherRelease
```

## Known limitations (v1)

- No EncryptedSharedPreferences yet (tokens in plaintext Room KV).
- No subscription-userinfo header display (traffic/expiry shown from login
  only); no auto-refresh on a schedule (manual "更新订阅" button).
- No in-app update check (SFA's updater is off by default; do not enable
  it — it points at upstream releases).
- The deep-link scheme stays `sing-box://` for QR import compatibility.
