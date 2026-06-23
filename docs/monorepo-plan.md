# SideKick Monorepo Plan

Build many apps from shared Swift layers. The repo should make boilerplate reusable, dependencies explicit, previews/tests easy, vendor choices isolated, and app-specific customization safe. Internal throwing APIs should use Swift 6 typed throws.

## Layers
1. **Modules**: Reusable UI units.
2. **Intents**: Product actions that coordinate work.
3. **<Feature>Core**: Contracts, models, typed errors, and test helpers.
4. **Managers**: Shared state and focused app capabilities.
5. **Services**: Platform/vendor/shared infrastructure implementations.
6. **Apps**: Composition roots, resources, permissions, lifecycle, and extensions.
7. **Platforms**: Platform-specific shells and capabilities.
8. **Build System**: Bazel-owned build graph.
9. **Navigation**: App-owned route state, root trees, deep links, Handoff, and restoration.
10. **Performance and Concurrency**: Main-actor UI state with off-main work.
11. **Design Systems**: Repo-wide UI foundation plus app-owned brand layers.

## Modules
Modules are reusable UI pieces. They own presentation and view state, not app composition, vendor integrations, or cross-feature orchestration.

Each module source target should contain:
1. **View**: Presentation only. It should not hold real state except its ViewModel.
2. **ViewModel**: View state and event handling. Calls the Interactor and Router.
3. **Interactor**: Module-specific protocol for required state/actions, such as `func save() async throws(SaveError)`. Implementations usually live outside reusable modules.
4. **Router**: Module-specific protocol for navigation/presentation intent, such as `dismiss()` or `showProfile()`. It should not expose app-wide navigation.
5. **Config**: Module inputs. Navigation configs must be Codable, URL-representable, versionable, and safe to persist.
6. **Strings**: Module-local copy for localization.
7. **Events**: ViewModel inputs/state transitions.
8. **ABProps**: Experiment props required by the module.

The ceremony is intentional: it gives humans and agents predictable places to put code.

Module tests should cover ViewModels and UI states. Preview helpers should make it easy to render meaningful module states.

Config is the durable route contract. It should use stable IDs and lightweight values, not services, managers, closures, secrets, auth tokens, or live vendor models.

## Intents
Intents are pure Swift product actions. They represent meaningful user/system work, especially when that work coordinates multiple Managers.

Examples: `SignOutIntent`, `DeleteAccountIntent`, `CompleteOnboardingIntent`, `RestorePurchasesIntent`, `BootstrapAppIntent`, `SyncUserEntitlementsIntent`.

Modules call narrow Interactor methods. Interactor implementations can call Intents. Intents coordinate Managers.

Intents should:
1. Use Swift 6 typed errors.
2. Avoid importing AppIntents.
3. Be callable from modules, apps, widgets, background tasks, debug tools, and AppIntent adapters.

Apple AppIntents are adapters:
1. Every Apple AppIntent should map to an internal SideKick Intent.
2. Not every SideKick Intent should be exposed as an Apple AppIntent.
3. AppIntent adapters translate system parameters/results/errors at the boundary.

## <Feature>Core
`<Feature>Core` holds contracts for a feature area without concrete implementations.

It can contain:
1. Value models, such as `AuthUser` instead of `FirebaseAuth.User`.
2. Manager protocols used by Modules and Intents.
3. Service protocols used by Managers.
4. Swift 6 typed errors.
5. ABProps.
6. Test helpers, mocks, fakes, builders, and fixtures.

Modules, Intents, Managers, Services, and Apps can depend on `<Feature>Core` without pulling in Manager implementations or vendor SDKs.

## Managers
Managers hold cross-module state and focused capabilities. They are usually `@Observable` classes.

Managers should:
1. Depend on protocols and value models, not vendor SDKs.
2. Use Swift 6 typed errors.
3. Expose debug modules for DevTools and developer settings.
4. Have unit tests against mocked services.

Managers are not one-to-one with services. A Manager can depend on many service protocols, such as feature services, `DataService`, `ABPropsService`, `LoggingService`, and `PreferencesService`. New functionality can add new Managers and Services as needed.

Baseline Manager examples:
1. ABProps
2. Logging
3. Haptics
4. PushNotifications
5. Purchases
6. AppStore
7. Location
8. Game
9. Device
10. Preferences
11. Utilities

`PreferencesManager` owns app-facing lightweight local state and typed preference models. `PreferencesService` should be reusable KVS infrastructure for any Manager that needs small on-device persistence.

## Services
Services implement protocols from `<Feature>Core` or shared service protocol targets.

Services may depend on:
1. `<Feature>Core`
2. Shared service protocol targets
3. Platform frameworks
4. Vendor SDKs

Services should not depend on concrete Managers.

Services are not one-to-one with Managers. Shared infrastructure services, such as Logging, ABProps, Data, and Preferences, can support many Managers.

Service packages should document app requirements: permission strings, entitlements, URL schemes, background modes, StoreKit files, GameKit setup, push setup, associated domains, and similar integration needs.

Services may include build plugins. For example, Purchases can generate product enums from StoreKit config, and Game can generate models from GameKit config.

## Apps
Apps are composition roots. They set up dependency graphs, resources, permissions, entitlements, extensions, app lifecycle, root navigation, and app-specific design.

Apps should:
1. Build dependencies lazily.
2. Assemble Managers, Services, Intents, module Interactors, module Routers, resources, AppIntents, and app-specific Design Systems.
3. Own route encoding/decoding, Universal Links, URL schemes, Handoff, and navigation restoration.

A DevTools app should expose every Manager debug module and serve as the template for future apps.

An optional Architecture module can hold dependency containers, lifecycle adapters, environment injection, and root app bootstrapping.

## Platforms
Apps should be platform-aware composition targets. Shared Modules, Intents, Core, Managers, Services, and Design Systems should stay reusable across iPhone, iPad, watchOS, tvOS, widgets, and extensions when practical.

Platform targets own platform-specific shells, resources, entitlements, permissions, navigation chrome, and presentation choices. Shared contracts should expose capability checks when behavior differs by platform.

## Build System
Bazel is the repo's build source of truth.

Bazel should declare:
1. Swift libraries and tests for Modules, Intents, `<Feature>Core`, Managers, Services, and Design Systems.
2. Apple apps, extensions, resources, entitlements, and platform bundles through Apple/Swift rules.
3. Android targets when Android support is added.
4. Code generation, build plugins, and generated sources as explicit actions.
5. Test targets and CI entry points.

`BUILD.bazel` files should live near the source they describe. Targets should be small, explicit, and named after architecture units. Dependency violations should fail at build time.

Generated Xcode projects may exist for IDE ergonomics, but they are not the source of truth. SwiftPM manifests may exist for portable shared Swift packages or external distribution, but Bazel owns the internal dependency graph.

Bazel should start with local builds and local caching. Remote cache and remote execution can be added when build times justify the infrastructure.

## Navigation
Navigation is app-owned. Modules describe navigation intent; Apps perform navigation.

Flow:
1. View
2. ViewModel
3. Module Router protocol
4. App Router implementation
5. AppNavigationStore
6. SwiftUI `NavigationStack`, sheet, alert, cover, or root tree switch

The app owns:
1. Active root tree.
2. Navigation path inside that tree.
3. Presented route.
4. Route encoding/decoding.
5. Pending routes after auth or other eligibility gates.

Root trees define which UI is available:
1. Launching
2. SignedOut
3. SignedIn
4. Locked
5. Maintenance
6. ForceUpgrade

Each root tree should have its own route enum. A signed-out tree exposes onboarding/auth routes only. A signed-in route should be impossible to push while signed out.

Managers determine eligibility state. The app root resolver observes that state and selects the root tree. Intents can change Manager state, but they should not directly replace the root tree.

Routes should be Codable, Hashable, versionable, and backed by module Configs. The app should encode `root + path + presented route` into a durable URL/state representation and later rebuild the UI from it.

If a signed-out user opens a signed-in deep link, the app should store a pending route, show auth, then apply the route after sign-in succeeds.

## Performance and Concurrency
Modules should be `@MainActor`. Observable Managers should usually be `@MainActor` because they publish UI-facing state.

Managers should be thin main-actor facades. They update observable state, start async work, receive results, and publish small immutable snapshots. They should not perform disk IO, network waiting, decoding, migrations, SDK setup, image work, or expensive transforms on the main actor.

Services, data stores, caches, sync engines, and SDK adapters should be background-capable async types or actors. They own IO, vendor calls, persistence, mutable non-UI state, and heavy computation.

`async` does not guarantee work leaves the main actor. Expensive work must be intentionally kept outside `@MainActor` isolation.

Performance rules:
1. Build dependencies lazily.
2. Keep manager methods thin.
3. Keep services off the main actor unless a platform API requires it.
4. Use actors for mutable non-UI state.
5. Publish small immutable snapshots to UI.
6. Batch or debounce high-frequency state updates.
7. Avoid SDK initialization before first frame unless required.
8. Never block the main actor with disk, network, decoding, migrations, or expensive transforms.

## Design Systems
The repo-wide Design System defines the shared UI foundation:
1. Tokens
2. Semantic colors
3. Typography roles
4. Spacing
5. Base components
6. Layout helpers
7. Animation conventions
8. Shared icons
9. Preview helpers

Each app owns an app-specific Design System layer, usually as a sibling target to the app executable.

Example:

```text
Apps/
  FocusApp/
    FocusApp/
    FocusDesignSystem/
    FocusModules/
```

Shared modules depend on the repo-wide Design System. App-specific modules may depend on the app-specific Design System.

## Dependency Rules
1. Bazel owns the internal build graph and CI targets.
2. Bazel targets should stay small, explicit, and aligned with architecture units.
3. Modules may depend on Architecture, repo-wide DesignSystem, and needed `<Feature>Core` targets.
4. Modules define Interactor and Router protocols; implementations live outside reusable modules.
5. Navigation Configs must be Codable, URL-representable, versionable, and safe to persist.
6. Intents may depend on Architecture and Manager protocols/models from `<Feature>Core`.
7. Intents may coordinate multiple Managers.
8. Intents should not import AppIntents.
9. AppIntents should be thin adapters around internal Intents.
10. Internal throwing APIs should use Swift 6 typed throws. Generic `Error` belongs only at unavoidable adapter boundaries.
11. Managers may depend on Architecture, `<Feature>Core`, and multiple service protocols.
12. Services may depend on `<Feature>Core`, shared service protocol targets, platform frameworks, and vendor SDKs.
13. Services may support many Managers.
14. Services should not depend on concrete Managers.
15. Apps may depend on everything and assemble the graph.
16. Platform targets own platform-specific shells, resources, entitlements, permissions, and presentation choices.
17. Apps own root tree selection, route encoding/decoding, Handoff, deep links, and restoration.
18. Modules and observable Managers should be main-actor isolated; Services and heavy work should stay off-main.
19. Modules should not mutate root trees or push raw app routes.
20. Root trees should expose only routes valid for the current eligibility state.
21. App-specific Design Systems are app-owned and may depend on the repo-wide Design System.
22. Shared modules should not depend on app-specific Design Systems unless intentionally app-specific.
