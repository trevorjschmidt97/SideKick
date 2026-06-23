import XCTest
import GameCore
@testable import GameServices

final class FakeLocalGameServiceTests: XCTestCase {
    func testBoardHostAndPlayerJoinFlow() async throws {
        let service = FakeLocalGameService()
        let room = try await service.createRoom(board: .sample)
        let (joinedRoom, player) = try await service.joinRoom(joinCode: room.joinCode, displayName: " Taylor ")
        let loadedRoom = try await service.room(joinCode: room.joinCode)

        XCTAssertEqual(player.displayName, "Taylor")
        XCTAssertEqual(joinedRoom.players.map(\.displayName), ["Taylor"])
        XCTAssertEqual(loadedRoom, joinedRoom)
    }

    func testRepeatedLocalJoinWithSameDisplayNameIsIdempotent() async throws {
        let service = FakeLocalGameService()
        let room = try await service.createRoom(board: .sample)
        let (firstJoin, firstPlayer) = try await service.joinRoom(joinCode: room.joinCode, displayName: "Taylor")
        let (secondJoin, secondPlayer) = try await service.joinRoom(joinCode: room.joinCode, displayName: "Taylor")

        XCTAssertEqual(firstPlayer, secondPlayer)
        XCTAssertEqual(firstJoin.players, secondJoin.players)
        XCTAssertEqual(secondJoin.players.count, 1)
    }

    func testFullIncorrectThenCorrectFlowThroughService() async throws {
        let service = FakeLocalGameService()
        let created = try await service.createRoom(board: .sample)
        let (_, jordan) = try await service.joinRoom(joinCode: created.joinCode, displayName: "Jordan")
        let (withPlayers, casey) = try await service.joinRoom(joinCode: created.joinCode, displayName: "Casey")

        var room = try await service.startGame(roomID: withPlayers.id, hostID: withPlayers.hostID)
        room = try await service.selectClue(roomID: room.id, hostID: room.hostID, clueID: "movies-200")
        room = try await service.buzz(roomID: room.id, playerID: jordan.id, callerPlayerID: jordan.id)
        room = try await service.markIncorrect(roomID: room.id, hostID: room.hostID)
        XCTAssertEqual(room.players.first { $0.id == jordan.id }?.score, -200)

        room = try await service.buzz(roomID: room.id, playerID: casey.id, callerPlayerID: casey.id)
        room = try await service.markCorrect(roomID: room.id, hostID: room.hostID)
        XCTAssertEqual(room.players.first { $0.id == casey.id }?.score, 200)
        XCTAssertEqual(room.phase, .grid)
    }

    func testJoinAfterStartIsRejectedAndHostIDIsRequired() async throws {
        let service = FakeLocalGameService()
        var room = try await service.createRoom(board: .sample)
        let (withPlayer, _) = try await service.joinRoom(joinCode: room.joinCode, displayName: "Taylor")
        room = withPlayer
        room = try await service.startGame(roomID: room.id, hostID: room.hostID)

        do {
            _ = try await service.joinRoom(joinCode: room.joinCode, displayName: "Late")
            XCTFail("Expected late join to fail")
        } catch {
            XCTAssertEqual(error, .invalidPhase(expected: [.waiting], actual: .grid))
        }

        do {
            _ = try await service.selectClue(roomID: room.id, hostID: "wrong-host", clueID: "science-200")
            XCTFail("Expected wrong host to fail")
        } catch {
            XCTAssertEqual(error, .unauthorizedHost)
        }
    }

    func testStartGameRequiresAtLeastOnePlayer() async throws {
        let service = FakeLocalGameService()
        let room = try await service.createRoom(board: .sample)

        do {
            _ = try await service.startGame(roomID: room.id, hostID: room.hostID)
            XCTFail("Expected empty game start to fail")
        } catch {
            XCTAssertEqual(error, .notEnoughPlayers)
        }
    }

    func testPlayerCannotBuzzAsAnotherPlayer() async throws {
        let service = FakeLocalGameService()
        let created = try await service.createRoom(board: .sample)
        let (_, jordan) = try await service.joinRoom(joinCode: created.joinCode, displayName: "Jordan")
        let (withPlayers, casey) = try await service.joinRoom(joinCode: created.joinCode, displayName: "Casey")
        var room = try await service.startGame(roomID: withPlayers.id, hostID: withPlayers.hostID)
        room = try await service.selectClue(roomID: room.id, hostID: room.hostID, clueID: "science-200")

        do {
            _ = try await service.buzz(roomID: room.id, playerID: jordan.id, callerPlayerID: casey.id)
            XCTFail("Expected impersonated buzz to fail")
        } catch {
            XCTAssertEqual(error, .playerNotFound)
        }
    }
}
