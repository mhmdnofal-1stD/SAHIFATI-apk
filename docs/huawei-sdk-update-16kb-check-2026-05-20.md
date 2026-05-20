# Huawei SDK 16 KB Check — 2026-05-20

- Checked pub.dev package metadata for `huawei_account` on 2026-05-20.
- Current project version: `6.12.0+304`.
- Latest published version on pub.dev at check time: `6.12.0+304`.
- Result: no newer Flutter Huawei Account plugin is available yet.

- Checked Huawei Maven metadata for `com.huawei.agconnect:agcp` on 2026-05-20.
- Previous project version: `1.9.1.301`.
- Latest release in Maven metadata at check time: `1.9.5.302`.
- Result: upgraded project AGCP classpath to `1.9.5.302`.

- Partial blocker remains for native Huawei Account libraries until Huawei publishes a newer `huawei_account` package or updated underlying Android artifacts through the plugin.
- Added `android.experimental.enableNativePageAlignedLibraries=true` as build-time mitigation for native page alignment on our side.