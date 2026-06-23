import XCTest
@testable import GameCore

final class GameRulesTests: XCTestCase {
    func testCorrectRoundScoresPlayerAndDisablesClue() throws {
        var room = GameRoom(id: "room-1", joinCode: "ABCD", players: [
            Player(id: "taylor", displayName: "Taylor"),
            Player(id: "jordan", displayName: "Jordan"),
        ], phase: .grid)

        room = try GameRules.selectClue("science-400", in: room)
        room = try GameRules.buzz(playerID: "taylor", in: room)
        room = try GameRules.markCorrect(in: room)

        XCTAssertEqual(room.phase, .grid)
        XCTAssertNil(room.selectedClueID)
        XCTAssertEqual(room.players.first { $0.id == "taylor" }?.score, 400)
        XCTAssertTrue(room.board.clues.first { $0.id == "science-400" }?.isUsed == true)
    }

    func testIncorrectRoundSubtractsScoreLocksPlayerAndAllowsRebuzz() throws {
        var room = GameRoom(id: "room-1", joinCode: "ABCD", players: [
            Player(id: "jordan", displayName: "Jordan"),
            Player(id: "casey", displayName: "Casey"),
        ], phase: .grid)

        room = try GameRules.selectClue("movies-200", in: room)
        room = try GameRules.buzz(playerID: "jordan", in: room)
        room = try GameRules.markIncorrect(in: room)

        XCTAssertEqual(room.phase, .clueOpen)
        XCTAssertEqual(room.players.first { $0.id == "jordan" }?.score, -200)
        XCTAssertTrue(room.players.first { $0.id == "jordan" }?.lockedOutClueIDs.contains("movies-200") == true)
        XCTAssertThrowsError(try GameRules.buzz(playerID: "jordan", in: room))

        room = try GameRules.buzz(playerID: "casey", in: room)
        room = try GameRules.markCorrect(in: room)

        XCTAssertEqual(room.players.first { $0.id == "casey" }?.score, 200)
        XCTAssertTrue(room.board.clues.first { $0.id == "movies-200" }?.isUsed == true)
    }

    func testUsedCluesCannotBeSelected() throws {
        var room = GameRoom(id: "room-1", joinCode: "ABCD", players: [Player(id: "p1", displayName: "A")], phase: .grid)
        room = try GameRules.selectClue("science-200", in: room)
        room = try GameRules.buzz(playerID: "p1", in: room)
        room = try GameRules.markCorrect(in: room)

        XCTAssertThrowsError(try GameRules.selectClue("science-200", in: room))
    }

    func testFinalIncorrectMarksClueUsedAndReturnsToGrid() throws {
        var room = GameRoom(id: "room-1", joinCode: "ABCD", players: [Player(id: "solo", displayName: "Solo")], phase: .grid)

        room = try GameRules.selectClue("movies-200", in: room)
        room = try GameRules.buzz(playerID: "solo", in: room)
        room = try GameRules.markIncorrect(in: room)

        XCTAssertEqual(room.phase, .grid)
        XCTAssertNil(room.selectedClueID)
        XCTAssertTrue(room.board.clues.first { $0.id == "movies-200" }?.isUsed == true)
        XCTAssertEqual(room.players.first?.score, -200)
        XCTAssertTrue(room.players.first?.lockedOutClueIDs.isEmpty == true)
    }

    func testCorrectOnLastClueFinishesGame() throws {
        var board = GameBoard.sample
        for index in board.clues.indices where board.clues[index].id != "science-200" {
            board.clues[index].isUsed = true
        }
        var room = GameRoom(
            id: "room-1",
            joinCode: "ABCD",
            board: board,
            players: [Player(id: "taylor", displayName: "Taylor")],
            phase: .grid
        )

        room = try GameRules.selectClue("science-200", in: room)
        room = try GameRules.buzz(playerID: "taylor", in: room)
        room = try GameRules.markCorrect(in: room)

        XCTAssertEqual(room.phase, .finished)
        XCTAssertNil(room.selectedClueID)
        XCTAssertNil(room.firstBuzzedPlayerID)
        XCTAssertTrue(room.board.clues.allSatisfy(\.isUsed))
    }

    func testFinalIncorrectOnLastClueFinishesGame() throws {
        var board = GameBoard.sample
        for index in board.clues.indices where board.clues[index].id != "movies-200" {
            board.clues[index].isUsed = true
        }
        var room = GameRoom(
            id: "room-1",
            joinCode: "ABCD",
            board: board,
            players: [Player(id: "solo", displayName: "Solo")],
            phase: .grid
        )

        room = try GameRules.selectClue("movies-200", in: room)
        room = try GameRules.buzz(playerID: "solo", in: room)
        room = try GameRules.markIncorrect(in: room)

        XCTAssertEqual(room.phase, .finished)
        XCTAssertNil(room.selectedClueID)
        XCTAssertNil(room.firstBuzzedPlayerID)
        XCTAssertTrue(room.board.clues.allSatisfy(\.isUsed))
    }

    func testNegativeRuleTransitions() throws {
        let waitingRoom = GameRoom(id: "room-1", joinCode: "ABCD", players: [Player(id: "p1", displayName: "A")], phase: .waiting)
        XCTAssertThrowsError(try GameRules.selectClue("science-200", in: waitingRoom))

        let gridRoom = GameRoom(id: "room-1", joinCode: "ABCD", players: [Player(id: "p1", displayName: "A")], phase: .grid)
        XCTAssertThrowsError(try GameRules.selectClue("missing", in: gridRoom))
        XCTAssertThrowsError(try GameRules.buzz(playerID: "p1", in: gridRoom))

        var clueRoom = try GameRules.selectClue("science-200", in: gridRoom)
        XCTAssertThrowsError(try GameRules.buzz(playerID: "missing-player", in: clueRoom))
        clueRoom = try GameRules.buzz(playerID: "p1", in: clueRoom)
        XCTAssertThrowsError(try GameRules.buzz(playerID: "p1", in: clueRoom))

        let noBuzzRoom = try GameRules.selectClue("science-400", in: gridRoom)
        XCTAssertThrowsError(try GameRules.markCorrect(in: noBuzzRoom))
        XCTAssertThrowsError(try GameRules.markIncorrect(in: noBuzzRoom))
    }
}
