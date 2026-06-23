# Family Feud Apple App Targets

Bazel owns the production build graph. The shared SwiftUI app shell is in
`//Sources/FamilyFeudAppleApp:FamilyFeudAppleApp`.

Platform role rules:

- Apple TV: host only (`FamilyFeud_tvOS`).
- Apple Watch: join only (`FamilyFeud_watchOS`).
- iPhone, iPad, and Mac: host or join (`FamilyFeud_iOS`, `FamilyFeud_macOS`).

For local multi-simulator runs, start the Firebase emulators and use the manual
SDK-backed target:

```sh
firebase emulators:start --only firestore,auth --project demo-sidekick
npx --yes @bazel/bazelisk run \
  //Apps/FamilyFeud/Apple:FamilyFeud_iOS_FirebaseLocal \
  --ios_simulator_device="iPhone 16"
```

If Firebase startup fails, the app falls back to `FakeLocalFamilyFeudService`.
Fake service instances do not share state across separate app processes.
