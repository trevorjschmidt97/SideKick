import XCTest
import BoardGameModule
import GameCore
import GameEntryModule
import GameModuleShared
import JoinGameModule

@MainActor
final class GameModuleViewModelTests: XCTestCase {
    func testEntryViewModelRoutesRoleChoices() {
        let router = SpyEntryRouter()
        let viewModel = GameEntryViewModel(router: router)

        viewModel.send(.chooseBoard)
        viewModel.send(.chooseJoin)

        XCTAssertEqual(router.events, [.board, .join])
    }

    func testBoardViewModelCallsInteractorAndPublishesSnapshot() async {
        let interactor = StubBoardInteractor()
        let viewModel = BoardModuleViewModel(interactor: interactor, router: SpyModuleRouter())

        await viewModel.send(.createRoom)
        await viewModel.send(.startGame)
        await viewModel.send(.selectClue("science-400"))

        XCTAssertEqual(interactor.events, [.createRoom, .startGame, .selectClue("science-400")])
        XCTAssertEqual(viewModel.snapshot.room?.phase, .clueOpen)
        XCTAssertNil(viewModel.lastError)
    }

    func testJoinViewModelNormalizesJoinCodeAndBuzzes() async {
        let interactor = StubJoinInteractor()
        let viewModel = JoinModuleViewModel(joinCodeText: " abcd ", displayName: "Taylor", interactor: interactor, router: SpyModuleRouter())

        await viewModel.join()
        await viewModel.send(.buzz)

        XCTAssertEqual(interactor.events, [.join(joinCode: "ABCD", displayName: "Taylor"), .buzz])
        XCTAssertEqual(viewModel.snapshot.localPlayerID, "player-1")
        XCTAssertEqual(viewModel.snapshot.room?.phase, .buzzLocked)
    }

    func testPlayerBuzzButtonEligibilityHonorsLockout() throws {
        var room = GameRoom(id: "room-1", joinCode: "ABCD", players: [
            Player(id: "player-1", displayName: "Taylor"),
            Player(id: "player-2", displayName: "Jordan"),
        ], phase: .grid)

        room = try GameRules.selectClue("movies-200", in: room)
        XCTAssertTrue(PlayerGameModuleView.canLocalPlayerBuzz(snapshot: GameSnapshot(room: room, localPlayerID: "player-1"), room: room))

        room = try GameRules.buzz(playerID: "player-1", in: room)
        room = try GameRules.markIncorrect(in: room)

        XCTAssertFalse(PlayerGameModuleView.canLocalPlayerBuzz(snapshot: GameSnapshot(room: room, localPlayerID: "player-1"), room: room))
        XCTAssertTrue(PlayerGameModuleView.canLocalPlayerBuzz(snapshot: GameSnapshot(room: room, localPlayerID: "player-2"), room: room))
    }

    func testBoardViewModelPublishesTypedErrors() async {
        let interactor = StubBoardInteractor(error: .unauthorizedHost)
        let viewModel = BoardModuleViewModel(interactor: interactor, router: SpyModuleRouter())

        await viewModel.send(.startGame)

        XCTAssertEqual(viewModel.lastError, .unauthorizedHost)
    }
}

private enum EntryRouteEvent: Equatable {
    case board
    case join
}

@MainActor
private final class SpyEntryRouter: GameEntryModuleRouter {
    var events: [EntryRouteEvent] = []

    func showBoard() {
        events.append(.board)
    }

    func showJoin() {
        events.append(.join)
    }
}

@MainActor
private final class SpyModuleRouter: BoardModuleRouter, JoinModuleRouter {
    var didShowDevSettings = false

    func showDevSettings() {
        didShowDevSettings = true
    }
}

@MainActor
private final class StubBoardInteractor: BoardModuleInteractor {
    var room = GameRoom(id: "room-1", joinCode: "ABCD", players: [Player(id: "player-1", displayName: "Taylor")], phase: .waiting)
    var events: [BoardModuleEvent] = []
    let error: GameServiceError?

    init(error: GameServiceError? = nil) {
        self.error = error
    }

    func createRoom() async throws(GameServiceError) -> GameSnapshot {
        if let error { throw error }
        events.append(.createRoom)
        return GameSnapshot(room: room, localHostID: room.hostID)
    }

    func startGame() async throws(GameServiceError) -> GameSnapshot {
        if let error { throw error }
        events.append(.startGame)
        room.phase = .grid
        return GameSnapshot(room: room, localHostID: room.hostID)
    }

    func selectClue(_ clueID: ClueID) async throws(GameServiceError) -> GameSnapshot {
        if let error { throw error }
        events.append(.selectClue(clueID))
        room = try GameRules.selectClue(clueID, in: room)
        return GameSnapshot(room: room, localHostID: room.hostID)
    }

    func markCorrect() async throws(GameServiceError) -> GameSnapshot {
        if let error { throw error }
        events.append(.markCorrect)
        room = try GameRules.markCorrect(in: room)
        return GameSnapshot(room: room, localHostID: room.hostID)
    }

    func markIncorrect() async throws(GameServiceError) -> GameSnapshot {
        if let error { throw error }
        events.append(.markIncorrect)
        room = try GameRules.markIncorrect(in: room)
        return GameSnapshot(room: room, localHostID: room.hostID)
    }

    func refresh() async throws(GameServiceError) -> GameSnapshot {
        if let error { throw error }
        events.append(.refresh)
        return GameSnapshot(room: room, localHostID: room.hostID)
    }
}

@MainActor
private final class StubJoinInteractor: JoinModuleInteractor {
    var room = GameRoom(id: "room-1", joinCode: "ABCD", players: [], phase: .waiting)
    var events: [JoinModuleEvent] = []

    func join(joinCode: JoinCode, displayName: String) async throws(GameServiceError) -> GameSnapshot {
        events.append(.join(joinCode: joinCode, displayName: displayName))
        let player = Player(id: "player-1", displayName: displayName)
        room.players = [player]
        return GameSnapshot(room: room, localPlayerID: player.id)
    }

    func buzz() async throws(GameServiceError) -> GameSnapshot {
        events.append(.buzz)
        room.phase = .clueOpen
        room.selectedClueID = "science-200"
        room = try GameRules.buzz(playerID: "player-1", in: room)
        return GameSnapshot(room: room, localPlayerID: "player-1")
    }

    func refresh() async throws(GameServiceError) -> GameSnapshot {
        events.append(.refresh)
        return GameSnapshot(room: room, localPlayerID: "player-1")
    }
}
