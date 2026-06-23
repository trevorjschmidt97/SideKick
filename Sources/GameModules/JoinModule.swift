import SwiftUI
import GameCore
import GameModuleShared

public protocol JoinModuleInteractor: AnyObject {
    @MainActor func join(joinCode: JoinCode, displayName: String) async throws(GameServiceError) -> GameSnapshot
    @MainActor func buzz() async throws(GameServiceError) -> GameSnapshot
    @MainActor func refresh() async throws(GameServiceError) -> GameSnapshot
}

public protocol JoinModuleRouter: AnyObject {
    @MainActor func showDevSettings()
}

@MainActor
@Observable
public final class JoinModuleViewModel {
    private let interactor: any JoinModuleInteractor
    private let router: any JoinModuleRouter

    public var joinCodeText: String
    public var displayName: String
    public private(set) var snapshot: GameSnapshot
    public private(set) var lastError: GameServiceError?

    public init(
        joinCodeText: String = "",
        displayName: String = "",
        snapshot: GameSnapshot = GameSnapshot(),
        interactor: any JoinModuleInteractor,
        router: any JoinModuleRouter
    ) {
        self.joinCodeText = joinCodeText
        self.displayName = displayName
        self.snapshot = snapshot
        self.interactor = interactor
        self.router = router
    }

    public func send(_ event: JoinModuleEvent) async {
        do {
            switch event {
            case .join(let joinCode, let displayName):
                snapshot = try await interactor.join(joinCode: joinCode, displayName: displayName)
            case .buzz:
                snapshot = try await interactor.buzz()
            case .refresh:
                snapshot = try await interactor.refresh()
            }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    public func join() async {
        await send(.join(joinCode: JoinCode(rawValue: joinCodeText), displayName: displayName))
    }

    public func showDevSettings() {
        router.showDevSettings()
    }
}

public struct JoinModuleView: View {
    @State private var viewModel: JoinModuleViewModel

    public init(viewModel: JoinModuleViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 16) {
            if let room = viewModel.snapshot.room, viewModel.snapshot.localPlayerID != nil {
                PlayerGameModuleView(snapshot: viewModel.snapshot, room: room) {
                    Task { await viewModel.send(.buzz) }
                }
            } else {
                TextField(GameModuleStrings.joinCode, text: $viewModel.joinCodeText)
                TextField(GameModuleStrings.displayName, text: $viewModel.displayName)
                Button(GameModuleStrings.joinGame) {
                    Task { await viewModel.join() }
                }
                .buttonStyle(.borderedProminent)
            }
            if let lastError = viewModel.lastError {
                Text(String(describing: lastError))
                    .foregroundStyle(.red)
            }
        }
    }
}

public struct PlayerGameModuleView: View {
    public let snapshot: GameSnapshot
    public let room: GameRoom
    public let onBuzz: () -> Void

    public init(snapshot: GameSnapshot, room: GameRoom, onBuzz: @escaping () -> Void) {
        self.snapshot = snapshot
        self.room = room
        self.onBuzz = onBuzz
    }

    public var body: some View {
        VStack(spacing: 16) {
            if let localPlayer = room.players.first(where: { $0.id == snapshot.localPlayerID }) {
                Text("\(localPlayer.displayName): \(localPlayer.score)")
                    .font(.title2.bold())
            }
            switch room.phase {
            case .waiting:
                Text(GameModuleStrings.waitingForHost)
            case .grid:
                Text(GameModuleStrings.chooseClue)
            case .clueOpen:
                OpenClueModuleView(room: room, showBuzzButton: Self.canLocalPlayerBuzz(snapshot: snapshot, room: room), onBuzz: onBuzz)
            case .buzzLocked:
                Text(room.firstBuzzedPlayerID == snapshot.localPlayerID ? "You buzzed first" : GameModuleStrings.buzzingLocked)
            case .finished:
                Text(GameModuleStrings.gameOver)
            }
        }
    }

    public static func canLocalPlayerBuzz(snapshot: GameSnapshot, room: GameRoom) -> Bool {
        guard room.phase == .clueOpen,
              let localPlayerID = snapshot.localPlayerID,
              let selectedClueID = room.selectedClueID,
              let localPlayer = room.players.first(where: { $0.id == localPlayerID }) else {
            return false
        }
        return !localPlayer.lockedOutClueIDs.contains(selectedClueID)
    }
}
