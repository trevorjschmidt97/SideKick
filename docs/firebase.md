# Firebase and Firestore Services

Firebase is isolated behind service targets. App, Manager, Intent, and UI targets
exchange SideKick value models and typed feature errors; Firebase SDK types stay
inside Firebase/service adapter targets.

## Target Layout

- `FirebaseCoreService`: shared Firebase configuration, emulator endpoint
  parsing, and authenticated principal value types.
- `FirestoreDataService`: shared generic Firestore document infrastructure:
  `FirestoreDocument`, `FirestoreDocumentStore`, `InMemoryFirestoreDocumentStore`,
  `AnyFirestoreDocumentStore`, and conditional `FirestoreSDKDocumentStore`.
- `FirebaseGameService`: Jeopardy adapter. It maps `GameCore` models and
  `GameServiceError` onto generic Firestore document operations.
- `FirebaseFamilyFeudService`: Family Feud adapter. It maps `FamilyFeudCore`
  models and `FamilyFeudServiceError` onto generic Firestore document operations.

Feature cores do not import Firebase SDKs. Shared Firestore infrastructure does
not know about Jeopardy or Family Feud errors.

## Config Files

Add platform credentials only to concrete app composition targets:

- Apple: `GoogleService-Info.plist` in the app bundle target.
- Android: `google-services.json` in the future Android app target.

Do not add Firebase credentials to feature cores, managers, intents, reusable
modules, or shared app-core targets.

## Local Development

The current app containers default to fake local services when Firebase
credentials are absent:

- Jeopardy: `FakeLocalGameService`
- Family Feud: `FakeLocalFamilyFeudService`

For production-like Firebase rule work, run Firestore and Auth emulators
together:

```sh
firebase emulators:start --only firestore,auth
```

Jeopardy app composition uses production Firebase when
`GoogleService-Info.plist` is present. Without credentials, SDK-backed local
Firebase builds use `FirebaseGameServiceFactory.makeLocalEmulatorService()` with
demo Firebase options. That path configures Firebase, uses a stable local
principal for the app install, configures Firestore to use the local emulator
with SSL disabled, and returns `any GameService`.

Family Feud uses `FirebaseFamilyFeudServiceFactory.makeLocalEmulatorService()`
for SDK-backed local Firebase builds. It stores documents in
`familyFeudRooms`.

Normal Bazel app targets intentionally use SDK-optional Firebase service
surfaces so `//...` stays lightweight. To run simulators against the local
Firebase emulators, use the manual `*_FirebaseLocal` app targets.

Start the local backend:

```sh
firebase --config firebase.local.json emulators:start --only firestore,auth --project demo-sidekick
```

`firebase.local.json` uses `firestore.local.rules`, which intentionally allows
local simulator reads and writes without Firebase Auth. This avoids simulator
keychain/signing requirements while still running all shared state through the
local Firestore emulator. Use `firebase.json` and `firestore.rules` when
validating production-style Auth rules.

Then run as many simulators as you want against the same local backend:

```sh
npx --yes @bazel/bazelisk run \
  //Apps/Jeopardy/Apple:Jeopardy_iOS_FirebaseLocal \
  --ios_simulator_device="iPhone 16"

npx --yes @bazel/bazelisk run \
  //Apps/FamilyFeud/Apple:FamilyFeud_iOS_FirebaseLocal \
  --ios_simulator_device="iPhone 16"
```

If the emulator is not running, app bootstraps fall back to fake local services
so the UI still opens. Multiple fake-service app instances do not share state.

## Firestore Shape

Jeopardy first-slice collections:

- `rooms/{roomID}`: flat room document with `id`, `joinCode`, `hostID`,
  primitive `playerIDs`, `board`, embedded `players`, `phase`,
  `selectedClueID`, and `firstBuzzedPlayerID`.

Family Feud first-slice documents:

- `familyFeudRooms/{roomID}`: documents contain `id`, `joinCode`, `hostID`,
  primitive `playerIDs`, primitive `teamIDs`, `board`, embedded `players`,
  embedded `teams`, `phase`, `activeQuestionID`, and `currentRoundIndex`.

Top-level Firestore ID fields should be primitive strings, not encoded wrapper
objects. Feature document types expose `primitiveFieldValues` for scalar lookup
fields such as `id`, `joinCode`, `hostID`, and `phase`.

Host-only mutations must present the same host identity stored on the room.
Player mutations must present the authenticated player identity. Production
rules should enforce the same authority checks that the Swift services enforce.

Firestore mutations that update game state should use a transaction or a single
generic `mutateDocument` operation. This matters for:

- Jeopardy first-buzz correctness.
- Family Feud atomic team assignment on start.
- Family Feud answer reveal and score updates.

## Generic Store Contracts

Use `FirestoreDataService` for shared persistence behavior:

- `InMemoryFirestoreDocumentStore<Document>` for tests and local adapters.
- `AnyFirestoreDocumentStore<Document>` when feature services need type erasure.
- `FirestoreSDKDocumentStore<Document>` when `FirebaseFirestore` is available.

Feature Firebase adapters translate generic `FirestoreDataServiceError` values
into feature-specific typed errors at the boundary.

## Build Notes

SwiftPM resolves Firebase SDK products for SDK-backed targets through
`firebase-ios-sdk` `12.15.0`.

Bazel owns the internal graph:

- Normal `//...` builds compile SDK-optional service surfaces without linking
  Firebase SDK frameworks into every target.
- Manual SDK-backed targets validate Firebase integration:

```sh
npx --yes @bazel/bazelisk build \
  //Sources/FirestoreDataService:FirestoreDataServiceSDK \
  //Sources/FirebaseGameService:FirebaseGameServiceSDK \
  //Sources/FirebaseFamilyFeudService:FirebaseFamilyFeudServiceSDK
```

## Security Rules

Initial rules currently cover the Jeopardy `rooms` shape:

- A signed-in host can create a waiting room only for its own `hostID` and with
  no initial players.
- A host device can mutate phase, clue selection, scoring, and used clues only
  when its host identity matches `rooms/{roomID}.hostID`.
- A player join can change only `players` and `playerIDs`, must happen while the
  room is waiting, and must add `request.auth.uid` exactly once to `playerIDs`.
- A player can buzz only while the room phase is `clueOpen`, only if that user
  is already present in `playerIDs`, and only by setting
  `firstBuzzedPlayerID == request.auth.uid`.
- Clients cannot write Firebase SDK-specific fields into SideKick model data.

The rules include the first Family Feud collection shape and basic authenticated
host/join constraints, but they do not yet validate every nested field or every
game-rule transition. The Swift services remain the source of game-rule
transitions, and emulator tests should cover representative allow and deny cases
before production rollout.

## Validation

Use these checks after Firebase or Firestore changes:

```sh
swift test
npx --yes @bazel/bazelisk test //...
npx --yes @bazel/bazelisk build \
  //Sources/FirestoreDataService:FirestoreDataServiceSDK \
  //Sources/FirebaseGameService:FirebaseGameServiceSDK \
  //Sources/FirebaseFamilyFeudService:FirebaseFamilyFeudServiceSDK
firebase emulators:exec --only firestore,auth --project demo-sidekick "true"
```

## Indexes

The current Jeopardy lookup path uses room IDs and `joinCode` equality lookups,
so no composite index is required. Add indexes only when list/query screens or
multi-field filters are introduced.
