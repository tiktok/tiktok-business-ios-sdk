# Flalingo consent fork

`1.7.2-flalingo.3` adds opt-in consent boundaries to upstream iOS SDK 1.7.2. Set `TikTokConfig.discardEventsWhileTrackingDisabled = YES` before initialization. Without this option, upstream disabled-event caching remains unchanged.

Withdrawal invalidates the current work generation, cancels pending transport tasks, stops event timers and payment observation, and purges queued/persisted app and monitor events. Every endpoint, callback, and queued flush/write checks its original generation under the same lock as withdrawal. Bytes already transmitted before withdrawal cannot be recalled.

Call `clearPersistedEventsWithCompletion:` and require `success == YES` before first initialization or reconsent. Its main-queue callback acknowledges the logger queue barrier, app/monitor deletion, legacy crash-report deletion, and legacy boot-history defaults deletion. The application must invalidate any pending activation when consent changes while waiting for this callback.

The optional crash subsystem has no reliable uninstall, so consent mode never installs it, including during authorized sessions. Explicit local payment-tracking opt-out cannot be overridden by remote settings. Remote settings also cannot enable screenshots without local debug-mode opt-in.

## Production data minimization and manifest

In consent mode, optional monitor events require **both local `debugModeEnabled` and active consent**. Production builds that do not enable debug mode neither store nor transmit these monitors. Retrieval deletes legacy monitor rows; direct transport calls cannot bypass the gate. Configuration requests still carry the basic app/device context needed by the SDK, but never attach `debug_info`. Detailed hardware/timezone telemetry and raw boot-time/history collection have been removed entirely, including from the optional crash boot-time monitor. Initialization and acknowledged purge delete old boot-history defaults; retired `debug_info` rows cannot be written or replayed, even in debug mode.

Consent-mode requests use only `analytics.us.tiktok.com`; a remote domain value cannot change their recipient. Local EDP opt-out also suppresses previously cached enhanced events at serialization, and local debug opt-out removes old screenshot payloads. Current automatic IAP, crash and EDP opt-outs remain independent of remote enable flags.

`PrivacyInfo.xcprivacy` declares device identifiers, product interactions and purchase history as linked data used for developer advertising and analytics/tracking. Performance, other diagnostic and crash data are declared for the still-supported optional debug/non-consent instrumentation; **the documented Speaking Coach production configuration does not enable that instrumentation**. The app must describe its actual active collection in App Store Connect, including data sent by other dependencies, and separately declare any extra developer-supplied identity/custom-event payloads, debug screenshot/EDP capture, or non-consent custom tracking domains. No app account ID, email, phone, voice or transcript is supplied by the Speaking Coach advertising adapter.

The SDK's required-API reasons are `CA92.1` (its own app defaults) and `C617.1` (metadata/size of its files inside the app container). Raw system boot-time APIs are absent, so the SDK does not claim a SystemBootTime reason. Other app dependencies may still need their own reasons.

Primary Apple references used to verify enum values and reasons:

- [Collected data types](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatype)
- [Collection purposes](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacycollecteddatatypes/nsprivacycollecteddatatypepurposes)
- [Required API reasons](https://developer.apple.com/documentation/bundleresources/app-privacy-configuration/nsprivacyaccessedapitypes/nsprivacyaccessedapitypereasons)
- [Tracking-domain declarations](https://developer.apple.com/documentation/technotes/tn3182-adding-privacy-tracking-keys-to-your-privacy-manifest)

## Native regression checks

The tests use the real SDK persistence, logger, and request handler with a deterministic session double. No request contacts TikTok. They cover default behavior, withdrawal/drop/purge, all five transport endpoints, late config callbacks/retries across reconsent, suspended queue replay prevention, fresh event delivery, remote payment/screenshot opt-out, legacy crash-report deletion, decoded configuration bodies, retired boot telemetry/defaults, remote host/debug/EDP overrides, legacy diagnostic and screenshot/EDP replay prevention, and fresh manual subscription delivery.

The upstream test project needs obsolete tests and duplicate static SDK linkage isolated. With Ruby's `xcodeproj` gem installed, create a new harness directory:

```sh
ruby scripts/prepare-consent-tests.rb /tmp/tiktok-consent-tests
xcodebuild -project /tmp/tiktok-consent-tests/TikTokBusinessSDK.xcodeproj \
  -scheme ConsentRegression -configuration Debug \
  -destination 'platform=iOS Simulator,id=YOUR_SIMULATOR_UDID' \
  -parallel-testing-enabled NO -derivedDataPath /tmp/tiktok-consent-derived \
  CODE_SIGNING_ALLOWED=NO SWIFT_ENABLE_EXPLICIT_MODULES=NO test
```

This does not replace physical-device ATT/revocation/reconsent network capture, app build verification, or Events Manager delivery/attribution validation.
