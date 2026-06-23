# Jeopardy Apple App Targets

Bazel owns the production build graph. The shared SwiftUI app shell is in
`//Sources/JeopardyAppleApp:JeopardyAppleApp` and is composed from app roots in
this directory when concrete bundle identifiers, provisioning, and assets are
ready.

Platform role rules:

- Apple TV: board only (`Jeopardy_tvOS`).
- Apple Watch: join only (`Jeopardy_watchOS`).
- iPhone, iPad, and Mac: board or join (`Jeopardy_iOS`, `Jeopardy_macOS`).

The first vertical slice falls back to `FakeLocalGameService` only when Firebase
startup fails. If `GoogleService-Info.plist` is bundled, `JeopardyBootstrapView`
uses production Firebase. For local multi-simulator runs, start the emulators
and use the manual SDK-backed target:

```sh
firebase emulators:start --only firestore,auth --project demo-sidekick
npx --yes @bazel/bazelisk run \
  //Apps/Jeopardy/Apple:Jeopardy_iOS_FirebaseLocal \
  --ios_simulator_device="iPhone 16"
```
