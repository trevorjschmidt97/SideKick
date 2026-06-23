import XCTest
import GameCore
import GameIntents
@testable import GameManagers
@testable import GameServices

@MainActor
final class GameManagerAndIntentTests: XCTestCase {
    func testIntentsDriveManagerFromCreateToCorrectScore() async throws {
        let service = FakeLocalGameService()
        let boardManager = GameManager(service: service, clientRole: .board)
        let playerManager = GameManager(service: service, clientRole: .player)
        let room = try await CreateGameIntent().perform(manager: boardManager)
        _ = try await JoinGameIntent().perform(manager: playerManager, joinCode: room.joinCode, displayName: "Taylor")
        try await boardManager.refreshRoom()

        try await StartGameIntent().perform(manager: boardManager)
        try await SelectClueIntent().perform(manager: boardManager, clueID: "science-400")
        try await playerManager.refreshRoom()
        try await BuzzIntent().perform(manager: playerManager)
        try await boardManager.refreshRoom()
        try await MarkCorrectIntent().perform(manager: boardManager)

        XCTAssertEqual(boardManager.snapshot.room?.players.first?.score, 400)
        XCTAssertEqual(boardManager.snapshot.room?.phase, .grid)
    }

    func testManagerRefreshesSharedFakeServiceState() async throws {
        let service = FakeLocalGameService()
        let boardManager = GameManager(service: service, clientRole: .board)
        let playerManager = GameManager(service: service, clientRole: .player)

        let room = try await boardManager.createRoom()
        _ = try await playerManager.joinRoom(joinCode: room.joinCode, displayName: "Casey")
        try await boardManager.refreshRoom()

        XCTAssertEqual(boardManager.snapshot.room?.players.map(\.displayName), ["Casey"])
    }

    func testDebugToolsExposeManagerActionsUsedByApp() {
        let manager = GameManager(service: FakeLocalGameService(), clientRole: .board)
        XCTAssertEqual(Set(manager.debugActions), Set(GameManagerDebugAction.allCases))
    }

    func testJoinClientCannotPerformHostActions() async throws {
        let service = FakeLocalGameService()
        let boardManager = GameManager(service: service, clientRole: .board)
        let playerManager = GameManager(service: service, clientRole: .player)
        let room = try await boardManager.createRoom()
        _ = try await playerManager.joinRoom(joinCode: room.joinCode, displayName: "Jordan")

        do {
            try await playerManager.startGame()
            XCTFail("Expected join client to be unauthorized")
        } catch {
            XCTAssertEqual(error, .unauthorizedHost)
            XCTAssertEqual(playerManager.lastError, .unauthorizedHost)
        }

        do {
            try await playerManager.selectClue("science-200")
            XCTFail("Expected join client clue selection to be unauthorized")
        } catch {
            XCTAssertEqual(error, .unauthorizedHost)
        }

        do {
            try await playerManager.markCorrect()
            XCTFail("Expected join client scoring to be unauthorized")
        } catch {
            XCTAssertEqual(error, .unauthorizedHost)
        }
    }

    func testIntentsDriveIncorrectRebuzzAndCorrectScoring() async throws {
        let service = FakeLocalGameService()
        let boardManager = GameManager(service: service, clientRole: .board)
        let jordanManager = GameManager(service: service, clientRole: .player)
        let caseyManager = GameManager(service: service, clientRole: .player)

        let room = try await CreateGameIntent().perform(manager: boardManager)
        _ = try await JoinGameIntent().perform(manager: jordanManager, joinCode: room.joinCode, displayName: "Jordan")
        _ = try await JoinGameIntent().perform(manager: caseyManager, joinCode: room.joinCode, displayName: "Casey")
        try await boardManager.refreshRoom()

        try await StartGameIntent().perform(manager: boardManager)
        try await SelectClueIntent().perform(manager: boardManager, clueID: "movies-200")
        try await jordanManager.refreshRoom()
        try await BuzzIntent().perform(manager: jordanManager)
        try await boardManager.refreshRoom()
        try await MarkIncorrectIntent().perform(manager: boardManager)

        XCTAssertEqual(boardManager.snapshot.room?.players.first { $0.displayName == "Jordan" }?.score, -200)
        XCTAssertEqual(boardManager.snapshot.room?.phase, .clueOpen)

        try await caseyManager.refreshRoom()
        try await BuzzIntent().perform(manager: caseyManager)
        try await boardManager.refreshRoom()
        try await MarkCorrectIntent().perform(manager: boardManager)

        XCTAssertEqual(boardManager.snapshot.room?.players.first { $0.displayName == "Casey" }?.score, 200)
        XCTAssertTrue(boardManager.snapshot.room?.board.clues.first { $0.id == "movies-200" }?.isUsed == true)
        XCTAssertEqual(boardManager.snapshot.room?.phase, .grid)
    }

    func testPlayerDebugToolsAreFilteredAndCannotRunHostActionsDirectly() async throws {
        let manager = GameManager(service: FakeLocalGameService(), clientRole: .player)

        XCTAssertEqual(manager.debugActions(for: .player), [.resetLocalSnapshot])

        do {
            try await manager.runDebugAction(.createRoom)
            XCTFail("Expected player debug host action to be unauthorized")
        } catch {
            XCTAssertEqual(error, .unauthorizedHost)
            XCTAssertEqual(manager.lastError, .unauthorizedHost)
        }
    }

    func testManagerReportsMissingRoomAndMissingPlayer() async throws {
        let boardManager = GameManager(service: FakeLocalGameService(), clientRole: .board)

        do {
            try await boardManager.startGame()
            XCTFail("Expected missing room")
        } catch {
            XCTAssertEqual(error, .roomNotFound)
            XCTAssertEqual(boardManager.lastError, .roomNotFound)
        }

        let playerManager = GameManager(service: FakeLocalGameService(), snapshot: GameSnapshot(room: GameRoom(id: "room-1", joinCode: "ABCD")), clientRole: .player)
        do {
            try await playerManager.buzz()
            XCTFail("Expected missing player")
        } catch {
            XCTAssertEqual(error, .playerNotFound)
            XCTAssertEqual(playerManager.lastError, .playerNotFound)
        }
    }
}
