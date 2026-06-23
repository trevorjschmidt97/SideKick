# Firebase Game Service

Firebase is isolated behind `GameCore.GameService`. App, Manager, Intent, and UI
targets exchange only SideKick value models such as `GameRoom`, `Player`,
`JoinCode`, and typed `GameServiceError`; Firebase SDK types must remain inside
`FirebaseGameService`.

## Config Files

Add platform credentials only to app composition targets:

- Apple: `GoogleService-Info.plist` in the concrete Apple app bundle target.
- Android: `google-services.json` in the future Android app target.

Do not add Firebase credentials to `GameCore`, `GameManagers`, `GameIntents`, or
reusable module targets.

## Local Development

The default app container uses `FakeLocalGameService`, so credentials are not
required for development or tests. `FirebaseGameService` can run when supplied a
`FirebaseGameDocumentStore`; the Firestore SDK adapter implements that protocol
inside the `FirebaseGameService` target so SDK types do not cross into Core,
Managers, Intents, Modules, AppCore, or reusable UI.

When Firebase is enabled, prefer the emulator locally:

```sh
firebase emulators:start --only firestore
```

Configure the service with `FirebaseGameServiceConfiguration(usesEmulator: true,
emulatorHost: "localhost:8080")` and a Firestore-backed
`FirebaseGameDocumentStore`.

For local Firebase Auth as well, run:

```sh
firebase emulators:start --only firestore,auth
```

The default auth emulator endpoint is `localhost:9099`; override it with
`authEmulatorHost` if needed.

For app composition, `FirebaseGameServiceFactory.makeAuthenticatedService`
calls `FirebaseApp.configure()` when needed, performs anonymous Firebase Auth
when no user is signed in, derives the `FirebaseGameServicePrincipal` from
`Auth.auth().currentUser.uid`, configures the Auth and Firestore emulators when
requested, and returns `any GameService`.

## Firestore Shape

Current first-slice collections:

- `rooms/{roomID}`: flat room document with `id`, `joinCode`, `hostID`,
  primitive `playerIDs`, `board`, embedded `players`, `phase`,
  `selectedClueID`, and `firstBuzzedPlayerID`.
- `joinCodes/{joinCode}`: room lookup document.

Top-level Firestore ID fields should be written as primitive strings, not as
Swift `RawRepresentable` wrapper objects. `FirebaseGameRoomDocument` exposes
`primitiveFieldValues` for scalar IDs and stores `playerIDs` beside embedded
`players` so security rules can check membership and caller authority without
trusting nested client data.

`rooms/{roomID}` includes `hostID`. Host-only mutations must present the same
host identity so rules can enforce start, clue selection, scoring, and clue
closure without trusting UI state.

`FirebaseGameServicePrincipal` represents the authenticated Firebase user in the
SDK adapter. When supplied, the service derives host/player IDs from that user
and rejects buzz calls for any other player ID. The production Firestore rules
must enforce the same `request.auth.uid == playerID` and
`request.auth.uid == hostID` checks.

The Firestore adapter implements `mutateRoomDocument` with a Firestore
transaction. This is required for first-buzz correctness: two players must not
be able to read `clueOpen` concurrently and both win by last write.

`Sources/FirebaseGameService/FirestoreGameDocumentStore.swift` contains the
conditional SDK adapter location. It compiles when `FirebaseFirestore` is
available and remains inside `FirebaseGameService` so SDK types do not leak into
Core, Managers, Intents, Modules, AppCore, or app UI.

To enable production Firebase:

1. Add `GoogleService-Info.plist` to the concrete Apple app bundle target.
2. Configure Firebase Auth for anonymous sign-in in the Firebase console.
3. Use `PartyGameBootstrapView` from platform shells. It composes
   `FirebaseGameServiceFactory.makeAuthenticatedService` when credentials are
   present and keeps `FakeLocalGameService` as the fallback when credentials are
   absent or Firebase startup fails.
4. Run the Firestore emulator rules suite before shipping rule changes.

SwiftPM already resolves `FirebaseAuth` and `FirebaseFirestore` for the
`FirebaseGameService` target. Bazel still compiles the SDK-optional service
surface without fetching Firebase; add `rules_swift_package_manager` or an
equivalent checked-in external dependency mapping before making Bazel compile
the Firebase SDK-backed adapter in CI.

## Security Rules

Initial rules enforce:

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

The current rules do not yet validate every nested `players` field or every
game-rule transition in Firestore itself. The Swift service remains the source
of game-rule transitions, and emulator tests should cover representative allow
and deny cases before production rollout.

## Indexes

The current lookup path uses direct document IDs, so no composite index is
required. Add indexes only if list/query screens are introduced.
