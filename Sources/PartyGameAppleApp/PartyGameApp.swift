import SwiftUI
import BoardGameModule
import FirebaseGameService
import GameCore
import GameEntryModule
import GameIntents
import GameManagers
import GameServices
import JoinGameModule
import PartyGameAppCore
import SideKickAppCore

public struct PartyGameBootstrapView: View {
    private let platform: SideKickPlatform
    private let initialRole: GameRole?
    private let launchJoin: PartyGameLaunchJoin?
    @State private var service: (any GameService)?

    public init(platform: SideKickPlatform, initialRole: GameRole? = nil, launchJoin: PartyGameLaunchJoin? = nil) {
        self.platform = platform
        self.initialRole = initialRole
        self.launchJoin = launchJoin
    }

    public var body: some View {
        Group {
            if let service {
                PartyGameRootView(platform: platform, service: service, initialRole: initialRole, launchJoin: launchJoin)
            } else {
                ProgressView()
                    .task {
                        service = await Self.makeDefaultService()
                    }
            }
        }
    }

    private static func makeDefaultService() async -> any GameService {
        if Bundle.main.path(forResource: "GoogleService-Info", ofType: "plist") != nil {
            do {
                return try await FirebaseGameServiceFactory.makeAuthenticatedService(
                    configuration: FirebaseGameServiceConfiguration()
                )
            } catch {
                return FakeLocalGameService()
            }
        }
        do {
            return try await FirebaseGameServiceFactory.makeLocalEmulatorService()
        } catch {
            return FakeLocalGameService()
        }
    }
}

public struct PartyGameRootView: View {
    @State private var gameManager: GameManager
    @State private var navigationStore: AppNavigationStore
    private let initialRole: GameRole?
    private let launchJoin: PartyGameLaunchJoin?

    public init(
        platform: SideKickPlatform,
        service: any GameService,
        initialRole: GameRole? = nil,
        launchJoin: PartyGameLaunchJoin? = nil
    ) {
        _gameManager = State(initialValue: GameManager(service: service))
        _navigationStore = State(initialValue: AppNavigationStore(platform: platform))
        self.initialRole = initialRole
        self.launchJoin = launchJoin
    }

    public var body: some View {
        GameRootView(gameManager: gameManager, navigationStore: navigationStore, launchJoin: launchJoin)
            .task {
                if let initialRole {
                    navigationStore.selectRole(initialRole)
                }
            }
    }
}

struct GameRootView: View {
    @State var gameManager: GameManager
    @State var navigationStore: AppNavigationStore
    var launchJoin: PartyGameLaunchJoin?

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                switch navigationStore.state.root {
                case .launching:
                    ProgressView()
                case .gameEntry:
                    GameEntryModuleView(viewModel: GameEntryViewModel(router: AppEntryRouter(navigationStore: navigationStore)))
                case .board:
                    let viewModel = BoardModuleViewModel(
                        snapshot: gameManager.snapshot,
                        interactor: AppBoardInteractor(gameManager: gameManager),
                        router: AppModuleRouter(navigationStore: navigationStore)
                    )
                    BoardModuleView(viewModel: viewModel)
                        .task {
                            if gameManager.snapshot.room == nil {
                                await viewModel.send(.createRoom)
                            }
                            while !Task.isCancelled {
                                try? await Task.sleep(for: .seconds(1))
                                await viewModel.send(.refresh)
                            }
                        }
                case .player:
                    let viewModel = JoinModuleViewModel(
                        snapshot: gameManager.snapshot,
                        interactor: AppJoinInteractor(gameManager: gameManager),
                        router: AppModuleRouter(navigationStore: navigationStore)
                    )
                    JoinModuleView(viewModel: viewModel)
                        .task {
                            if let launchJoin, gameManager.snapshot.room == nil {
                                _ = try? await gameManager.joinRoom(
                                    joinCode: launchJoin.joinCode,
                                    displayName: launchJoin.displayName
                                )
                            }
                            while !Task.isCancelled {
                                try? await Task.sleep(for: .seconds(1))
                                if gameManager.snapshot.room != nil {
                                    await viewModel.send(.refresh)
                                }
                            }
                        }
                }
            }
            .padding()
            .toolbar {
                Button("Dev") {
                    navigationStore.presentDevSettings()
                }
            }
            .sheet(isPresented: Binding(
                get: { navigationStore.state.presentedRoute != nil },
                set: { if !$0 { navigationStore.dismissPresentedRoute() } }
            )) {
                DevSettingsView(gameManager: gameManager)
            }
        }
    }
}

public struct PartyGameLaunchJoin: Sendable {
    public var joinCode: JoinCode
    public var displayName: String

    public init(joinCode: JoinCode, displayName: String) {
        self.joinCode = joinCode
        self.displayName = displayName
    }
}

@MainActor
private final class AppEntryRouter: GameEntryModuleRouter {
    private let navigationStore: AppNavigationStore

    init(navigationStore: AppNavigationStore) {
        self.navigationStore = navigationStore
    }

    func showBoard() {
        navigationStore.selectRole(.board)
    }

    func showJoin() {
        navigationStore.selectRole(.join)
    }
}

@MainActor
private final class AppModuleRouter: BoardModuleRouter, JoinModuleRouter {
    private let navigationStore: AppNavigationStore

    init(navigationStore: AppNavigationStore) {
        self.navigationStore = navigationStore
    }

    func showDevSettings() {
        navigationStore.presentDevSettings()
    }
}

@MainActor
private final class AppBoardInteractor: BoardModuleInteractor {
    private let gameManager: GameManager

    init(gameManager: GameManager) {
        self.gameManager = gameManager
        self.gameManager.setClientRole(.board)
    }

    func createRoom() async throws(GameServiceError) -> GameSnapshot {
        _ = try await CreateGameIntent().perform(manager: gameManager)
        return gameManager.snapshot
    }

    func startGame() async throws(GameServiceError) -> GameSnapshot {
        try await StartGameIntent().perform(manager: gameManager)
        return gameManager.snapshot
    }

    func selectClue(_ clueID: ClueID) async throws(GameServiceError) -> GameSnapshot {
        try await SelectClueIntent().perform(manager: gameManager, clueID: clueID)
        return gameManager.snapshot
    }

    func markCorrect() async throws(GameServiceError) -> GameSnapshot {
        try await MarkCorrectIntent().perform(manager: gameManager)
        return gameManager.snapshot
    }

    func markIncorrect() async throws(GameServiceError) -> GameSnapshot {
        try await MarkIncorrectIntent().perform(manager: gameManager)
        return gameManager.snapshot
    }

    func refresh() async throws(GameServiceError) -> GameSnapshot {
        try await gameManager.refreshRoom()
        return gameManager.snapshot
    }
}

@MainActor
private final class AppJoinInteractor: JoinModuleInteractor {
    private let gameManager: GameManager

    init(gameManager: GameManager) {
        self.gameManager = gameManager
        self.gameManager.setClientRole(.player)
    }

    func join(joinCode: JoinCode, displayName: String) async throws(GameServiceError) -> GameSnapshot {
        _ = try await JoinGameIntent().perform(manager: gameManager, joinCode: joinCode, displayName: displayName)
        return gameManager.snapshot
    }

    func buzz() async throws(GameServiceError) -> GameSnapshot {
        try await BuzzIntent().perform(manager: gameManager)
        return gameManager.snapshot
    }

    func refresh() async throws(GameServiceError) -> GameSnapshot {
        try await gameManager.refreshRoom()
        return gameManager.snapshot
    }
}

struct DevSettingsView: View {
    let gameManager: GameManager

    var body: some View {
        NavigationStack {
            List(gameManager.debugActions(for: gameManager.clientRole ?? .player), id: \.self) { action in
                Button(action.rawValue) {
                    Task { try? await gameManager.runDebugAction(action) }
                }
            }
            .navigationTitle("Dev Settings")
        }
    }
}
