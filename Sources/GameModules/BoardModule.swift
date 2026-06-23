import SwiftUI
import GameCore
import GameModuleShared

public protocol BoardModuleInteractor: AnyObject {
    @MainActor func createRoom() async throws(GameServiceError) -> GameSnapshot
    @MainActor func startGame() async throws(GameServiceError) -> GameSnapshot
    @MainActor func selectClue(_ clueID: ClueID) async throws(GameServiceError) -> GameSnapshot
    @MainActor func markCorrect() async throws(GameServiceError) -> GameSnapshot
    @MainActor func markIncorrect() async throws(GameServiceError) -> GameSnapshot
    @MainActor func refresh() async throws(GameServiceError) -> GameSnapshot
}

public protocol BoardModuleRouter: AnyObject {
    @MainActor func showDevSettings()
}

@MainActor
@Observable
public final class BoardModuleViewModel {
    private let interactor: any BoardModuleInteractor
    private let router: any BoardModuleRouter

    public private(set) var snapshot: GameSnapshot
    public private(set) var lastError: GameServiceError?

    public init(snapshot: GameSnapshot = GameSnapshot(), interactor: any BoardModuleInteractor, router: any BoardModuleRouter) {
        self.snapshot = snapshot
        self.interactor = interactor
        self.router = router
    }

    public func send(_ event: BoardModuleEvent) async {
        do {
            switch event {
            case .createRoom:
                snapshot = try await interactor.createRoom()
            case .startGame:
                snapshot = try await interactor.startGame()
            case .selectClue(let clueID):
                snapshot = try await interactor.selectClue(clueID)
            case .markCorrect:
                snapshot = try await interactor.markCorrect()
            case .markIncorrect:
                snapshot = try await interactor.markIncorrect()
            case .refresh:
                snapshot = try await interactor.refresh()
            }
            lastError = nil
        } catch {
            lastError = error
        }
    }

    public func showDevSettings() {
        router.showDevSettings()
    }
}

public struct BoardModuleView: View {
    @State private var viewModel: BoardModuleViewModel

    public init(viewModel: BoardModuleViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 16) {
            if let room = viewModel.snapshot.room {
                Text("Code \(room.joinCode.rawValue)")
                    .font(.title.bold())
                phaseContent(room)
            } else {
                Button(GameModuleStrings.createGameBoard) {
                    Task { await viewModel.send(.createRoom) }
                }
                .buttonStyle(.borderedProminent)
            }
            if let lastError = viewModel.lastError {
                Text(String(describing: lastError))
                    .foregroundStyle(.red)
            }
        }
    }

    @ViewBuilder
    private func phaseContent(_ room: GameRoom) -> some View {
        switch room.phase {
        case .waiting:
            WaitingPlayersModuleView(room: room) {
                Task { await viewModel.send(.startGame) }
            }
        case .grid:
            ClueGridModuleView(room: room) { clue in
                Task { await viewModel.send(.selectClue(clue.id)) }
            }
        case .clueOpen:
            OpenClueModuleView(room: room, showBuzzButton: false, showAnswer: true, onBuzz: {})
        case .buzzLocked:
            LockedBuzzModuleView(room: room, onCorrect: {
                Task { await viewModel.send(.markCorrect) }
            }, onIncorrect: {
                Task { await viewModel.send(.markIncorrect) }
            })
        case .finished:
            Text(GameModuleStrings.gameOver)
        }
    }
}

public struct WaitingPlayersModuleView: View {
    public let room: GameRoom
    public let onStart: () -> Void

    public init(room: GameRoom, onStart: @escaping () -> Void) {
        self.room = room
        self.onStart = onStart
    }

    public var body: some View {
        VStack(spacing: 12) {
            Text(GameModuleStrings.waitingPlayers)
                .font(.headline)
            ForEach(room.players) { player in
                Text("\(player.displayName): \(player.score)")
            }
            Button(GameModuleStrings.startGame, action: onStart)
                .buttonStyle(.borderedProminent)
                .disabled(room.players.isEmpty)
        }
    }
}

public struct ClueGridModuleView: View {
    public let room: GameRoom
    public let onSelect: (Clue) -> Void

    public init(room: GameRoom, onSelect: @escaping (Clue) -> Void) {
        self.room = room
        self.onSelect = onSelect
    }

    public var body: some View {
        Grid(horizontalSpacing: 8, verticalSpacing: 8) {
            GridRow {
                ForEach(room.board.categories, id: \.self) { category in
                    Text(category)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                }
            }
            ForEach([200, 400, 600], id: \.self) { value in
                GridRow {
                    ForEach(room.board.categories, id: \.self) { category in
                        if let clue = room.board.clues.first(where: { $0.category == category && $0.value == value }) {
                            Button(clue.isUsed ? "-" : "\(clue.value)") {
                                onSelect(clue)
                            }
                            .disabled(clue.isUsed)
                            .frame(width: 110, height: 64)
                        }
                    }
                }
            }
        }
    }
}

public struct LockedBuzzModuleView: View {
    public let room: GameRoom
    public let onCorrect: () -> Void
    public let onIncorrect: () -> Void

    public init(room: GameRoom, onCorrect: @escaping () -> Void, onIncorrect: @escaping () -> Void) {
        self.room = room
        self.onCorrect = onCorrect
        self.onIncorrect = onIncorrect
    }

    public var body: some View {
        VStack(spacing: 16) {
            OpenClueModuleView(room: room, showBuzzButton: false, showAnswer: true, onBuzz: {})
            Text("First buzz: \(room.firstBuzzedPlayer?.displayName ?? "Unknown")")
                .font(.headline)
            HStack {
                Button(GameModuleStrings.incorrect, action: onIncorrect)
                    .buttonStyle(.bordered)
                Button(GameModuleStrings.correct, action: onCorrect)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
