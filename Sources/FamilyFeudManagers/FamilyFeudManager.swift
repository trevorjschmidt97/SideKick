import Foundation
import Observation
import FamilyFeudCore

public enum FamilyFeudManagerDebugAction: String, CaseIterable, Codable, Hashable, Sendable {
    case createRoom
    case startGame
    case revealTopAnswerForTeamA
    case endRound
    case resetLocalSnapshot
}

@MainActor
@Observable
public final class FamilyFeudManager: FamilyFeudManaging {
    private let service: any FamilyFeudService

    public private(set) var snapshot: FamilyFeudSnapshot
    public private(set) var lastError: FamilyFeudServiceError?
    public private(set) var clientRole: FamilyFeudClientRole?

    public init(service: any FamilyFeudService, snapshot: FamilyFeudSnapshot = FamilyFeudSnapshot(), clientRole: FamilyFeudClientRole? = nil) {
        self.service = service
        self.snapshot = snapshot
        self.clientRole = clientRole
    }

    public var debugActions: [FamilyFeudManagerDebugAction] {
        FamilyFeudManagerDebugAction.allCases
    }

    public func createRoom(board: FeudBoard = .sample) async throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        try requireHostRole()
        do {
            let room = try await service.createRoom(board: board)
            snapshot = FamilyFeudSnapshot(room: room, localPlayerID: nil, localHostID: room.hostID)
            lastError = nil
            return room
        } catch {
            lastError = error
            throw error
        }
    }

    public func loadRoom(joinCode: FeudJoinCode) async throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        do {
            let room = try await service.room(joinCode: joinCode)
            snapshot = FamilyFeudSnapshot(room: room, localPlayerID: snapshot.localPlayerID, localHostID: snapshot.localHostID)
            lastError = nil
            return room
        } catch {
            lastError = error
            throw error
        }
    }

    public func refreshRoom() async throws(FamilyFeudServiceError) {
        guard let joinCode = snapshot.room?.joinCode else {
            throw .roomNotFound
        }
        _ = try await loadRoom(joinCode: joinCode)
    }

    public func joinRoom(joinCode: FeudJoinCode, displayName: String) async throws(FamilyFeudServiceError) -> FeudPlayer {
        do {
            let (room, player) = try await service.joinRoom(joinCode: joinCode, displayName: displayName)
            clientRole = .player
            snapshot = FamilyFeudSnapshot(room: room, localPlayerID: player.id, localHostID: nil)
            lastError = nil
            return player
        } catch {
            lastError = error
            throw error
        }
    }

    public func startGame() async throws(FamilyFeudServiceError) {
        let roomID = try currentRoomID()
        let hostID = try currentHostID()
        do {
            snapshot.room = try await service.startGame(roomID: roomID, hostID: hostID)
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
    }

    public func revealAnswer(_ answerID: FeudAnswerID, for teamID: FeudTeamID) async throws(FamilyFeudServiceError) {
        let roomID = try currentRoomID()
        let hostID = try currentHostID()
        do {
            snapshot.room = try await service.revealAnswer(roomID: roomID, hostID: hostID, answerID: answerID, teamID: teamID)
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
    }

    public func endRound() async throws(FamilyFeudServiceError) {
        let roomID = try currentRoomID()
        let hostID = try currentHostID()
        do {
            snapshot.room = try await service.endRound(roomID: roomID, hostID: hostID)
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
    }

    public func advanceToNextQuestion() async throws(FamilyFeudServiceError) {
        let roomID = try currentRoomID()
        let hostID = try currentHostID()
        do {
            snapshot.room = try await service.advanceToNextQuestion(roomID: roomID, hostID: hostID)
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
    }

    public func runDebugAction(_ action: FamilyFeudManagerDebugAction) async throws(FamilyFeudServiceError) {
        switch action {
        case .createRoom:
            _ = try await createRoom()
        case .startGame:
            try await startGame()
        case .revealTopAnswerForTeamA:
            guard let answerID = snapshot.room?.activeQuestion?.answers.first(where: { !$0.isRevealed })?.id else {
                throw .answerNotFound
            }
            try await revealAnswer(answerID, for: "team-a")
        case .endRound:
            try await endRound()
        case .resetLocalSnapshot:
            snapshot = FamilyFeudSnapshot()
            lastError = nil
        }
    }

    public func setClientRole(_ role: FamilyFeudClientRole) {
        clientRole = role
    }

    public func debugActions(for role: FamilyFeudClientRole) -> [FamilyFeudManagerDebugAction] {
        switch role {
        case .host:
            return debugActions
        case .player:
            return [.resetLocalSnapshot]
        }
    }

    private func currentRoomID() throws(FamilyFeudServiceError) -> FeudRoomID {
        guard let roomID = snapshot.room?.id else {
            lastError = .roomNotFound
            throw .roomNotFound
        }
        return roomID
    }

    private func currentHostID() throws(FamilyFeudServiceError) -> FeudHostID {
        try requireHostRole()
        guard let hostID = snapshot.localHostID else {
            lastError = .unauthorizedHost
            throw .unauthorizedHost
        }
        return hostID
    }

    private func requireHostRole() throws(FamilyFeudServiceError) {
        guard clientRole == .host else {
            lastError = .unauthorizedHost
            throw .unauthorizedHost
        }
    }
}
