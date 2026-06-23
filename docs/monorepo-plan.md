I want you to setup a complete mono repo.

The idea is that we are going to be building out many many apps with this. So instead of writing the same boilerplate for every app, we should split things up into clear layers that make reuse, testing, previews, AI-assisted development, app-specific customization, and Swift 6 typed-error correctness easier.

The high-level layers should be:
1. Modules
2. Intents
3. <Feature>Core
4. Managers
5. Services
6. Apps
7. Navigation
8. Design Systems

## 1. Modules
Modules are the UI pieces that together make an app. A module should be reusable wherever possible and should only know about the state/actions that are required for its own screen or flow.

The module contains a few key files in the source directory:
1. **View**: The presentation layer of the module. It should not hold any real state except for the view model.
2. **ViewModel**: Holds all view state and helps the View interact with the rest of the app through the injected Interactor and Router.
3. **Interactor**: A module-specific protocol that describes exactly what the module needs from the rest of the app. It can expose state, such as `var x: Int { get }`, or functionality, such as `func markYAsDone(param: Something) async throws(MarkYAsDoneError)`. The Interactor protocol belongs in the module, but the implementation usually should not. The implementation can live in the app, feature assembly, or another composition layer, and it can call into Intents or Managers. This keeps the module from depending on the entire app.
4. **Router**: A module-specific protocol that allows the module to route to other modules, inject child modules, dismiss itself, or present things like alerts, sheets, and toasts. The Router should describe what the module needs, not expose a generic app-wide navigation API.
5. **Config**: A struct that allows injection of whatever is necessary for the module. For example, an upsert Item module would have an optional Item in the config. Any Config that participates in navigation, Handoff, deep linking, or state restoration should be Codable and representable as a stable route segment.
6. **Strings**: An enum or namespace that holds all strings for the module, so they are easy to localize.
7. **Events**: An enum of events that the ViewModel will use. This should make the state transitions and user actions easy to inspect and test.
8. **ABProps**: A protocol with the experiment/feature-flag props required by the module.

These 8 files may seem ceremonial, but this is intended. Having modules set up like this gives AI agents and human contributors clear principles and predictable places to put code.

The tests directory should set up view UI tests and view model unit tests. The UI tests should also make it possible to have a clean preview macro in the View where the dev can play around with the different states of the module and see how it appears.

Modules should also be designed so the current UI can be rebuilt from a decoded navigation path. The app should be able to represent the active navigation stack as a path-separated URL, where each route segment maps to a module and contains the Codable Config needed to rebuild that module. This gives us Handoff, deep links, state restoration, and shareable/debuggable navigation for free.

The Config should be the durable routing contract, not a dumping ground for runtime dependencies. It should avoid services, managers, closures, non-stable models, secrets, auth tokens, and anything that should not appear in a URL or persisted state. Prefer stable IDs and lightweight value data, then let the Interactor/Intent/Manager layer load the latest state after the module is rebuilt.

## 2. Intents
Intents are the product-action layer. They represent meaningful things a user or the system wants to do, especially when that action coordinates multiple Managers.

Examples:
1. SignOutIntent
2. DeleteAccountIntent
3. CompleteOnboardingIntent
4. RestorePurchasesIntent
5. RequestLocationPermissionIntent
6. RegisterForPushNotificationsIntent
7. BootstrapAppIntent
8. SyncUserEntitlementsIntent

A module should not be responsible for coordinating a large cross-app action. For example, if a user signs out, the module should not know that the app needs to sign out of auth, clear user state, reset AB experiment assignments, unregister push notifications, log out of purchases, clear analytics identity, and route back to onboarding.

Instead, the module should call a narrow Interactor method:

```swift
func signOut() async throws(SignOutError)
```

The Interactor implementation can call:

```swift
SignOutIntent.perform()
```

The SignOutIntent can coordinate the relevant Managers.

Intents should be plain Swift and should not import AppIntents. They should be testable, reusable, and callable from modules, apps, widgets, background tasks, debug tools, and Apple AppIntent adapters.

Intents should use Swift 6 typed errors. Each Intent should define or reuse a specific error type, such as `SignOutError`, instead of exposing generic `Error`.

Apple AppIntents should map to these internal Intents when the action is appropriate to expose to the system.

Rule:
1. Every Apple AppIntent should map to an internal SideKick Intent.
2. Not every internal SideKick Intent needs to be exposed as an Apple AppIntent.

The Apple AppIntent should be a thin adapter. It should translate supported AppIntent parameters/entities into internal models, call the internal Intent, translate typed failures into AppIntent-compatible failures when needed, then return an AppIntent result.

## 3. <Feature>Core
The <Feature>Core layer contains the contracts and value models for a feature area. This layer exists so Modules, Managers, Services, Intents, and Apps can share feature concepts without depending on concrete implementations.

The <Feature>Core target can contain:
1. **Value-based models**: For example, AuthUser instead of FirebaseAuth.User.
2. **Public Manager protocols**: The protocols that Modules and Intents should depend on when they need to interact with a Manager.
3. **Service protocols**: The protocols that concrete Managers use to call into service implementations.
4. **Errors**: Feature-specific error types that should not depend on vendor SDKs. These should be designed for Swift 6 typed throws, such as `throws(AuthError)`, `throws(PurchasesError)`, or narrower action-specific errors.
5. **ABProps**: A protocol with the AB props required for this feature area.
6. **Test helpers**: Shared mocks, fakes, builders, and fixtures that make module and manager tests easier.

This means the concrete Manager can depend on <Feature>Core, the Service implementation can depend on <Feature>Core, and Modules/Intents can depend on <Feature>Core without pulling in either the Manager implementation or vendor SDKs.

## 4. Managers
Managers hold cross-module state and focused app capabilities. A Manager can be something like an AuthenticationManager, which holds state for the current signed-in AuthUser and exposes functionality to sign in, sign up, refresh the session, and sign out.

A Manager contains a few key files in the source directory:
1. **The Manager itself**: A @Observable class that gets injected with the service protocols it needs from <Feature>Core or shared service protocol targets.
2. **Debug module**: Each Manager should make available its own debug view module. Apps can add these manager debug tools to a developer settings screen, and the DevTools app can show all of them.
3. **Manager-specific helpers**: Any focused helpers that belong to the Manager implementation but do not belong in <Feature>Core.

The Manager should not depend on Firebase, RevenueCat, StoreKit, CoreLocation service details, or other vendor-specific implementations. It should depend on service protocols and value models from <Feature>Core.

Managers are not limited to one service. A Manager can depend on many service protocols when it needs them, such as a feature service, DataService, ABPropsService, LoggingService, PreferencesService, or any other shared infrastructure service. For example, a PurchasesManager might depend on a PurchasesService, LoggingService, ABPropsService, and PreferencesService.

In the tests directory, there should be unit tests that test the Manager against different things the service could do. Service mocks can be created here. Manager mocks can also be made available to module tests and intent tests to make them easier to write.

Some examples of required Managers:
1. ABProps
2. Logging
3. Haptics
4. PushNotifications
5. Purchases
6. AppStore: Requesting reviews, showing app download upsells, and handling store-related app actions.
7. Location
8. Game: Achievements, challenges, leaderboards, etc.
9. Device: Volume, display brightness, read/write display state, and display sleep prevention.
10. Preferences: Lightweight key-value storage for on-device preferences and small pieces of local state that should not require a database or network-backed service.
11. Utilities: Bundle ID, build number, app version, isTestFlight, isDebug, environment, locale, etc.

## 5. Services
Services are the implementation side of Managers. Services should implement service protocols defined in <Feature>Core or shared service protocol targets.

Services can depend on:
1. <Feature>Core
2. Platform frameworks
3. Vendor SDKs

Services should not depend on the concrete Manager they support. The direction should be:
1. Manager depends on service protocols.
2. Service implementation conforms to service protocols.

Services are not limited to one Manager. A service can be passed around to many Managers when it represents shared infrastructure. For example, LoggingService, ABPropsService, DataService, and PreferencesService can support many Managers. The Preferences service should be lightweight and expandable enough to support KVS-style local storage needs across the repo, while the PreferencesManager owns the app-facing preferences state, behavior, debug tools, and typed preference models.

In the source directory:
1. **<Feature>ServiceImplementation**: The implementation of the service protocol.
2. **Models**: Extensions or adapters for converting between <Feature>Core models and vendor/platform models.
3. **ABProps**: A protocol with the AB props required for this layer.

A test directory can be set up as well.

Each service should make it clear what is required in the app, such as Location permission strings, entitlements, URL schemes, background modes, StoreKit files, GameKit configuration, push notification setup, or associated domains. This can live in a README, AGENTS.md, or service-specific integration doc.

This layer can also have build plugins that make things available as code. For example, the purchases service should be able to convert StoreKit configuration files into enums of the models. The game service should be able to convert GameKit configuration into game enum models.

## 6. Apps
Apps are applications that set up the dependency graph, resources, permissions, entitlements, extensions, app lifecycle, and root navigation. Apps should be Xcode projects or generated Xcode projects.

All dependency graph setup should be done lazily.

The app is the composition root. It can depend on everything and assemble:
1. Managers
2. Services
3. Intents
4. Module Interactor implementations
5. Module Router implementations
6. App-specific Design System
7. Resources
8. App lifecycle
9. Extensions and AppIntents
10. URL routing, Handoff, deep links, and navigation state restoration

A DevTools application can be put together to show all manager debug tools. The DevTools app can be the template for other apps because it should have all the shared Managers set up lazily already.

Apps should own the encoding and decoding of the current navigation path. A route should be able to decode into module identifiers and module Config values, then the app should assemble the matching modules with the correct Interactor and Router implementations. This keeps modules reusable while still allowing each app to define its own root navigation, URL scheme, Universal Links, Handoff activities, and route versioning.

If needed, because we are going to have a lot of apps, there can be an Architecture module that handles boilerplate for delegates, lifecycle, dependency containers, environment injection, and root app setup. Ultimately, it would be cool to just pass in the dependency container.

## 7. Navigation
Navigation should be app-owned. Modules should describe navigation intent through module-specific Router protocols, while the app owns the actual navigation mechanics, route encoding, root view tree selection, deep links, Handoff, and state restoration.

The navigation flow should be:
1. View
2. ViewModel
3. Module Router protocol
4. App Router implementation
5. AppNavigationStore
6. SwiftUI NavigationStack, sheet, alert, cover, or root tree switch

Modules should not push raw views directly. A module should ask its Router for a meaningful action, such as `showProfile()`, `showNotificationSettings()`, `dismiss()`, or `presentPaywall()`. The app's Router implementation translates that action into an app route, sheet, alert, or root transition.

The app should have a central navigation store that owns the currently active root tree and the navigation state inside that tree. Root tree selection is separate from normal push/sheet navigation.

Example root trees:
1. Launching
2. SignedOut
3. SignedIn
4. Locked
5. Maintenance
6. ForceUpgrade

If a user is not signed in, the active root tree should only expose onboarding/auth flows. The app should not merely hide signed-in screens; the signed-in route enum should be unavailable from the signed-out tree. This makes invalid navigation impossible by construction.

Each root tree can own its own route enum and navigation state:
1. OnboardingRoute for signed-out onboarding/auth flows.
2. MainRoute for signed-in app flows.
3. LockedRoute for locked/paywall/maintenance flows when needed.

Managers determine app eligibility state, such as signed out, signed in, subscription required, or force upgrade required. The app root resolver observes that state and chooses the active root tree. Modules and Intents can cause Manager state changes, but they should not directly replace the app's root view tree.

For example, a Settings module can call `interactor.signOut()`. The Interactor implementation calls `SignOutIntent.perform()`. The SignOutIntent coordinates the relevant Managers. When AuthManager changes to signed out, the app root resolver switches from the SignedIn tree to the SignedOut tree and clears or stores the old route path as appropriate.

For deep links and Handoff, the app should decode both the root tree and the route path. For example, a signed-in URL can decode into a MainRoute path, while a signed-out URL can decode into an OnboardingRoute path. If a signed-out user opens a signed-in route, the app should stage the intended route as a pending route after auth, switch to the SignedOut tree, and apply the pending route after sign-in succeeds.

Routes should be Codable, Hashable, versionable, and backed by module Configs. The app should be able to encode `root + path + presented route` into a durable URL/state representation, then decode it later and rebuild the UI by assembling the matching modules with the correct Config, Interactor, and Router implementations.

The navigation rules are:
1. Modules describe navigation intent.
2. Apps own navigation mechanics.
3. Routes are Codable app contracts.
4. Configs rebuild modules.
5. Routers bridge module actions to app routes.
6. Root trees control which major view tree is exposed.
7. Managers determine eligibility state.
8. Intents can change Manager state, which can cause root tree changes.

## 8. Design Systems
There should be a repo-wide Design System that defines the company-wide UI foundation. Then each app can own its own app-specific Design System layer on top.

The repo-wide Design System should contain:
1. Shared design tokens
2. Semantic colors
3. Typography roles
4. Spacing
5. Base components
6. Layout helpers
7. Animation conventions
8. Shared icons or icon wrappers
9. Shared preview helpers

Each app's Design System should be app-owned. It should usually be a sibling target/package owned by the app, not code inside the app executable target itself.

For example:

```text
Apps/
  FocusApp/
    FocusApp/
    FocusDesignSystem/
    FocusModules/
```

The app-specific Design System can contain:
1. Brand colors
2. App typography mapping
3. App assets
4. App-specific components
5. Themed wrappers around shared components
6. Navigation styling
7. App-specific screen chrome

Shared reusable modules should depend on the repo-wide Design System. App-specific modules can depend on the app-specific Design System when they are intentionally tied to that app.

## 9. Dependency Rules
The dependency graph should be strict:
1. Modules may depend on Architecture, repo-wide DesignSystem, and the <Feature>Core contracts/models they need.
2. Modules should define their own Interactor and Router protocols.
3. Module Interactor and Router implementations usually live outside the reusable module.
4. Module Configs that participate in navigation should be Codable, URL-representable, versionable, and safe to persist.
5. Intents may depend on Architecture and Manager protocols/models from <Feature>Core.
6. Intents may coordinate multiple Managers.
7. Intents should not import AppIntents.
8. Apple AppIntents should be thin adapters around internal Intents.
9. All throwing APIs in Modules, Intents, <Feature>Core, Managers, and Services should use Swift 6 typed throws. Generic `Error` should only appear at unavoidable adapter boundaries, such as Apple framework protocols or vendor SDK callbacks.
10. Managers may depend on Architecture and <Feature>Core.
11. Managers may depend on multiple service protocols from <Feature>Core or shared service protocol targets.
12. Services may depend on <Feature>Core, shared service protocol targets, and platform/vendor SDKs.
13. Services can implement shared infrastructure used by many Managers.
14. Services should not depend on concrete Managers.
15. Apps may depend on everything and assemble the graph.
16. Apps own root tree selection, route decoding, route encoding, Handoff, deep links, and navigation state restoration.
17. Modules should describe navigation intent through Routers, but should not directly mutate app root trees or push raw app routes.
18. Root trees should expose only the routes valid for the current app eligibility state.
19. App-specific Design Systems are app-owned and can depend on the repo-wide Design System.
20. Shared modules should not depend on app-specific Design Systems unless they are intentionally app-specific modules.
