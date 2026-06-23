import SwiftUI
import FamilyFeudAppCore
import FamilyFeudCore
import FamilyFeudIntents
import FamilyFeudManagers
import FamilyFeudModules
import FamilyFeudServices
import FirebaseFamilyFeudService
import SideKickAppCore

public struct FamilyFeudBootstrapView: View {
    private let platform: SideKickPlatform
    private let initialRole: FamilyFeudRole?
    @State private var service: (any FamilyFeudService)?

    public init(platform: SideKickPlatform, initialRole: FamilyFeudRole? = nil) {
        self.platform = platform
        self.initialRole = initialRole
    }

    public var body: some View {
        Group {
            if let service {
                FamilyFeudRootView(platform: platform, service: service, initialRole: initialRole)
            } else {
                ProgressView()
                    .task {
                        service = await Self.makeDefaultService()
                    }
            }
        }
    }

    private static func makeDefaultService() async -> any FamilyFeudService {
        do {
            return try await FirebaseFamilyFeudServiceFactory.makeLocalEmulatorService()
        } catch {
            return FakeLocalFamilyFeudService()
        }
    }
}

public struct FamilyFeudRootView: View {
    @State private var manager: FamilyFeudManager
    @State private var navigationStore: FamilyFeudNavigationStore
    private let initialRole: FamilyFeudRole?

    public init(platform: SideKickPlatform, service: any FamilyFeudService, initialRole: FamilyFeudRole? = nil) {
        _manager = State(initialValue: FamilyFeudManager(service: service))
        _navigationStore = State(initialValue: FamilyFeudNavigationStore(platform: platform))
        self.initialRole = initialRole
    }

    public var body: some View {
        FamilyFeudRootContent(manager: manager, navigationStore: navigationStore)
            .task {
                if let initialRole {
                    navigationStore.selectRole(initialRole)
                }
            }
    }
}

struct FamilyFeudRootContent: View {
    @State var manager: FamilyFeudManager
    @State var navigationStore: FamilyFeudNavigationStore

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                switch navigationStore.state.root {
                case .launching:
                    ProgressView()
                case .entry:
                    FamilyFeudEntryModuleView(viewModel: FamilyFeudEntryViewModel(router: AppFamilyFeudEntryRouter(navigationStore: navigationStore)))
                case .host:
                    let viewModel = FamilyFeudHostViewModel(
                        snapshot: manager.snapshot,
                        interactor: AppFamilyFeudHostInteractor(manager: manager),
                        router: AppFamilyFeudModuleRouter(navigationStore: navigationStore)
                    )
                    FamilyFeudHostModuleView(viewModel: viewModel)
                        .task {
                            if manager.snapshot.room == nil {
                                await viewModel.send(.createRoom)
                            }
                            while !Task.isCancelled {
                                try? await Task.sleep(for: .seconds(1))
                                await viewModel.send(.refresh)
                            }
                        }
                case .player:
                    let viewModel = FamilyFeudJoinViewModel(
                        snapshot: manager.snapshot,
                        interactor: AppFamilyFeudJoinInteractor(manager: manager),
                        router: AppFamilyFeudModuleRouter(navigationStore: navigationStore)
                    )
                    FamilyFeudJoinModuleView(viewModel: viewModel)
                        .task {
                            while !Task.isCancelled {
                                try? await Task.sleep(for: .seconds(1))
                                if manager.snapshot.room != nil {
                                    await viewModel.send(.refresh)
                                }
                            }
                        }
                }
            }
            .padding()
            .sheet(isPresented: Binding(
                get: { navigationStore.state.presentedRoute != nil },
                set: { if !$0 { navigationStore.dismissPresentedRoute() } }
            )) {
                FamilyFeudDevSettingsView(manager: manager)
            }
        }
    }
}

@MainActor
private final class AppFamilyFeudEntryRouter: FamilyFeudEntryRouter {
    private let navigationStore: FamilyFeudNavigationStore

    init(navigationStore: FamilyFeudNavigationStore) {
        self.navigationStore = navigationStore
    }

    func showHost() {
        navigationStore.selectRole(.host)
    }

    func showJoin() {
        navigationStore.selectRole(.join)
    }
}

@MainActor
private final class AppFamilyFeudModuleRouter: FamilyFeudModuleRouter {
    private let navigationStore: FamilyFeudNavigationStore

    init(navigationStore: FamilyFeudNavigationStore) {
        self.navigationStore = navigationStore
    }

    func showDevSettings() {
        navigationStore.presentDevSettings()
    }
}

@MainActor
private final class AppFamilyFeudHostInteractor: FamilyFeudHostInteractor {
    private let manager: FamilyFeudManager

    init(manager: FamilyFeudManager) {
        self.manager = manager
        self.manager.setClientRole(.host)
    }

    func createRoom() async throws(FamilyFeudServiceError) -> FamilyFeudSnapshot {
        _ = try await CreateFamilyFeudRoomIntent().perform(manager: manager)
        return manager.snapshot
    }

    func startGame() async throws(FamilyFeudServiceError) -> FamilyFeudSnapshot {
        try await StartFamilyFeudGameIntent().perform(manager: manager)
        return manager.snapshot
    }

    func reveal(answerID: FeudAnswerID, teamID: FeudTeamID) async throws(FamilyFeudServiceError) -> FamilyFeudSnapshot {
        try await RevealFamilyFeudAnswerIntent().perform(manager: manager, answerID: answerID, teamID: teamID)
        return manager.snapshot
    }

    func endRound() async throws(FamilyFeudServiceError) -> FamilyFeudSnapshot {
        try await EndFamilyFeudRoundIntent().perform(manager: manager)
        return manager.snapshot
    }

    func advance() async throws(FamilyFeudServiceError) -> FamilyFeudSnapshot {
        try await AdvanceFamilyFeudQuestionIntent().perform(manager: manager)
        return manager.snapshot
    }

    func refresh() async throws(FamilyFeudServiceError) -> FamilyFeudSnapshot {
        try await manager.refreshRoom()
        return manager.snapshot
    }
}

@MainActor
private final class AppFamilyFeudJoinInteractor: FamilyFeudJoinInteractor {
    private let manager: FamilyFeudManager

    init(manager: FamilyFeudManager) {
        self.manager = manager
        self.manager.setClientRole(.player)
    }

    func join(joinCode: FeudJoinCode, displayName: String) async throws(FamilyFeudServiceError) -> FamilyFeudSnapshot {
        _ = try await JoinFamilyFeudRoomIntent().perform(manager: manager, joinCode: joinCode, displayName: displayName)
        return manager.snapshot
    }

    func refresh() async throws(FamilyFeudServiceError) -> FamilyFeudSnapshot {
        try await manager.refreshRoom()
        return manager.snapshot
    }
}

struct FamilyFeudDevSettingsView: View {
    let manager: FamilyFeudManager

    var body: some View {
        NavigationStack {
            List(manager.debugActions(for: manager.clientRole ?? .player), id: \.self) { action in
                Button(action.rawValue) {
                    Task { try? await manager.runDebugAction(action) }
                }
            }
            .navigationTitle("Dev Settings")
        }
    }
}
