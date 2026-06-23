# PartyGame Apple App Targets

Bazel owns the production build graph. The shared SwiftUI app shell is in
`//Sources/PartyGameAppleApp:PartyGameAppleApp` and is composed from app roots in
this directory when concrete bundle identifiers, provisioning, and assets are
ready.

Platform role rules:

- Apple TV: board only (`PartyGame_tvOS`).
- Apple Watch: join only (`PartyGame_watchOS`).
- iPhone, iPad, and Mac: board or join (`PartyGame_iOS`, `PartyGame_macOS`).

The first vertical slice falls back to `FakeLocalGameService` when credentials
are absent. If `GoogleService-Info.plist` is bundled, `PartyGameBootstrapView`
uses `FirebaseGameServiceFactory` to compose a Firebase Auth + Firestore-backed
`GameService`.
