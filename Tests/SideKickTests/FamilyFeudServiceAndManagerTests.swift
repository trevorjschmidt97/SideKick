import XCTest
import FamilyFeudCore
import FamilyFeudIntents
@testable import FamilyFeudManagers
@testable import FamilyFeudServices

@MainActor
final class FamilyFeudServiceAndManagerTests: XCTestCase {
    func testFakeServiceHostJoinStartAndRevealFlow() async throws {
        let service = FakeLocalFamilyFeudService()
        let room = try await service.createRoom(board: .sample)
        let (_, first) = try await service.joinRoom(joinCode: room.joinCode, displayName: "Taylor")
        let (_, second) = try await service.joinRoom(joinCode: room.joinCode, displayName: "Jordan")

        var started = try await service.startGame(roomID: room.id, hostID: room.hostID)

        XCTAssertEqual(started.phase, .questionOpen)
        XCTAssertEqual(Set(started.players.map(\.id)), [first.id, second.id])
        XCTAssertEqual(started.teams.count, 2)

        let answerID = try XCTUnwrap(started.activeQuestion?.answers.first?.id)
        started = try await service.revealAnswer(roomID: room.id, hostID: room.hostID, answerID: answerID, teamID: "team-a")
        XCTAssertGreaterThan(started.teams.first { $0.id == "team-a" }?.score ?? 0, 0)
    }

    func testFakeServiceRejectsLateJoinAndWrongHost() async throws {
        let service = FakeLocalFamilyFeudService()
        let room = try await service.createRoom(board: .sample)
        _ = try await service.joinRoom(joinCode: room.joinCode, displayName: "Taylor")
        _ = try await service.joinRoom(joinCode: room.joinCode, displayName: "Jordan")
        _ = try await service.startGame(roomID: room.id, hostID: room.hostID)

        do {
            _ = try await service.joinRoom(joinCode: room.joinCode, displayName: "Casey")
            XCTFail("Expected late join rejection")
        } catch {
            XCTAssertEqual(error, .invalidPhase(expected: [.waiting], actual: .questionOpen))
        }

        do {
            _ = try await service.endRound(roomID: room.id, hostID: "wrong")
            XCTFail("Expected wrong host")
        } catch {
            XCTAssertEqual(error, .unauthorizedHost)
        }
    }

    func testFamilyFeudIntentsDriveManager() async throws {
        let service = FakeLocalFamilyFeudService()
        let host = FamilyFeudManager(service: service, clientRole: .host)
        let playerA = FamilyFeudManager(service: service, clientRole: .player)
        let playerB = FamilyFeudManager(service: service, clientRole: .player)

        let room = try await CreateFamilyFeudRoomIntent().perform(manager: host)
        _ = try await JoinFamilyFeudRoomIntent().perform(manager: playerA, joinCode: room.joinCode, displayName: "Taylor")
        _ = try await JoinFamilyFeudRoomIntent().perform(manager: playerB, joinCode: room.joinCode, displayName: "Jordan")
        try await host.refreshRoom()
        try await StartFamilyFeudGameIntent().perform(manager: host)

        let answerID = try XCTUnwrap(host.snapshot.room?.activeQuestion?.answers.first?.id)
        try await RevealFamilyFeudAnswerIntent().perform(manager: host, answerID: answerID, teamID: "team-a")

        XCTAssertEqual(host.snapshot.room?.phase, .questionOpen)
        XCTAssertGreaterThan(host.snapshot.room?.teams.first { $0.id == "team-a" }?.score ?? 0, 0)
    }
}
