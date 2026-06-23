import XCTest
import FamilyFeudCore

final class FamilyFeudRulesTests: XCTestCase {
    func testStartAssignsTwoTeamsAndOpensFirstQuestion() throws {
        let room = FamilyFeudRoom(id: "room", joinCode: "ABCD", players: [
            FeudPlayer(id: "p1", displayName: "A"),
            FeudPlayer(id: "p2", displayName: "B"),
            FeudPlayer(id: "p3", displayName: "C"),
        ])

        let started = try FamilyFeudRules.startGame(in: room)

        XCTAssertEqual(started.phase, .questionOpen)
        XCTAssertEqual(started.teams.count, 2)
        XCTAssertEqual(started.teams[0].playerIDs, ["p1", "p3"])
        XCTAssertEqual(started.teams[1].playerIDs, ["p2"])
        XCTAssertEqual(started.players.compactMap(\.teamID).count, 3)
        XCTAssertEqual(started.activeQuestionID, started.board.questions.first?.id)
    }

    func testStartRejectsTooFewPlayers() {
        let room = FamilyFeudRoom(id: "room", joinCode: "ABCD", players: [
            FeudPlayer(id: "p1", displayName: "A"),
        ])

        XCTAssertThrowsError(try FamilyFeudRules.startGame(in: room)) { error in
            XCTAssertEqual(error as? FamilyFeudServiceError, .notEnoughPlayers)
        }
    }

    func testRevealAwardsPointsOnceAndCompletesRound() throws {
        var room = FamilyFeudRoom(id: "room", joinCode: "ABCD", players: [
            FeudPlayer(id: "p1", displayName: "A"),
            FeudPlayer(id: "p2", displayName: "B"),
        ])
        room.board = FeudBoard(questions: [
            FeudQuestion(id: "q1", prompt: "Prompt", answers: [
                FeudAnswer(id: "a1", text: "One", points: 10),
            ]),
        ])
        let started = try FamilyFeudRules.startGame(in: room)

        let revealed = try FamilyFeudRules.revealAnswer("a1", for: "team-a", in: started)

        XCTAssertEqual(revealed.teams.first { $0.id == "team-a" }?.score, 10)
        XCTAssertEqual(revealed.phase, .roundComplete)
        XCTAssertTrue(revealed.board.questions[0].answers[0].isRevealed)
        XCTAssertThrowsError(try FamilyFeudRules.revealAnswer("a1", for: "team-a", in: revealed))
    }

    func testAdvanceFinishesAfterFinalQuestion() throws {
        var room = FamilyFeudRoom(id: "room", joinCode: "ABCD", players: [
            FeudPlayer(id: "p1", displayName: "A"),
            FeudPlayer(id: "p2", displayName: "B"),
        ])
        room.board = FeudBoard(questions: [
            FeudQuestion(id: "q1", prompt: "Prompt", answers: [FeudAnswer(id: "a1", text: "One", points: 10)]),
        ])
        let started = try FamilyFeudRules.startGame(in: room)
        let ended = try FamilyFeudRules.endRound(in: started)

        let finished = try FamilyFeudRules.advanceToNextQuestion(in: ended)

        XCTAssertEqual(finished.phase, .finished)
        XCTAssertNil(finished.activeQuestionID)
    }
}
