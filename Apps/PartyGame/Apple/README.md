# PartyGame Apple App Targets

Bazel owns the production build graph. The shared SwiftUI app shell is in
`//Sources/PartyGameAppleApp:PartyGameAppleApp` and is composed from app roots in
this directory when concrete bundle identifiers, provisioning, and assets are
ready.

Platform role rules:

- Apple TV: board only (`PartyGame_tvOS`).
- Apple Watch: join only (`PartyGame_watchOS`).
- iPhone, iPad, and Mac: board or join (`PartyGame_iOS`, `PartyGame_macOS`).

The first vertical slice falls back to `FakeLocalGameService` only when Firebase
startup fails. If `GoogleService-Info.plist` is bundled, `PartyGameBootstrapView`
uses production Firebase. For local multi-simulator runs, start the emulators
and use the manual SDK-backed target:

```sh
firebase emulators:start --only firestore,auth --project demo-sidekick
npx --yes @bazel/bazelisk run \
  //Apps/PartyGame/Apple:PartyGame_iOS_FirebaseLocal \
  --ios_simulator_device="iPhone 16"
```
