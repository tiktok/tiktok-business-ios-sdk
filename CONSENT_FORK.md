# Flalingo consent fork

`1.7.2-flalingo.2` adds opt-in consent boundaries to upstream iOS SDK 1.7.2. Set `TikTokConfig.discardEventsWhileTrackingDisabled = YES` before initialization. Without this option, upstream disabled-event caching remains unchanged.

Withdrawal invalidates the current work generation, cancels pending transport tasks, stops event timers and payment observation, and purges queued/persisted app and monitor events. Every endpoint, callback, and queued flush/write checks its original generation under the same lock as withdrawal. Bytes already transmitted before withdrawal cannot be recalled.

Call `clearPersistedEventsWithCompletion:` and require `success == YES` before first initialization or reconsent. Its main-queue callback acknowledges the logger queue barrier, app/monitor deletion, and legacy crash-report deletion. The application must invalidate any pending activation when consent changes while waiting for this callback.

The optional crash subsystem has no reliable uninstall, so consent mode never installs it, including during authorized sessions. Explicit local payment-tracking opt-out cannot be overridden by remote settings. Remote settings also cannot enable screenshots without local debug-mode opt-in.

## Native regression checks

The tests use the real SDK persistence, logger, and request handler with a deterministic session double. No request contacts TikTok. They cover default behavior, withdrawal/drop/purge, all five transport endpoints, late config callbacks/retries across reconsent, suspended queue replay prevention, fresh event delivery, remote payment/screenshot opt-out, and legacy crash-report deletion.

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
