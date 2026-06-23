import Foundation
import Observation
import GameCore

public enum GameManagerDebugAction: String, CaseIterable, Codable, Hashable, Sendable {
    case createRoom
    case startGame
    case selectFirstAvailableClue
    case markCorrect
    case resetLocalSnapshot
}

@MainActor
@Observable
public final class GameManager: GameManaging {
    private let service: any GameService

    public private(set) var snapshot: GameSnapshot
    public private(set) var lastError: GameServiceError?
    public private(set) var clientRole: GameClientRole?

    public init(service: any GameService, snapshot: GameSnapshot = GameSnapshot(), clientRole: GameClientRole? = nil) {
        self.service = service
        self.snapshot = snapshot
        self.clientRole = clientRole
    }

    public var debugActions: [GameManagerDebugAction] {
        GameManagerDebugAction.allCases
    }

    public func createRoom(board: GameBoard = .sample) async throws(GameServiceError) -> GameRoom {
        try requireBoardRole()
        do {
            let room = try await service.createRoom(board: board)
            snapshot = GameSnapshot(room: room, localPlayerID: nil, localHostID: room.hostID)
            lastError = nil
            return room
        } catch {
            lastError = error
            throw error
        }
    }

    public func loadRoom(joinCode: JoinCode) async throws(GameServiceError) -> GameRoom {
        do {
            let room = try await service.room(joinCode: joinCode)
            snapshot = GameSnapshot(room: room, localPlayerID: snapshot.localPlayerID, localHostID: snapshot.localHostID)
            lastError = nil
            return room
        } catch {
            lastError = error
            throw error
        }
    }

    public func refreshRoom() async throws(GameServiceError) {
        guard let joinCode = snapshot.room?.joinCode else {
            throw .roomNotFound
        }
        _ = try await loadRoom(joinCode: joinCode)
    }

    public func joinRoom(joinCode: JoinCode, displayName: String) async throws(GameServiceError) -> Player {
        do {
            let (room, player) = try await service.joinRoom(joinCode: joinCode, displayName: displayName)
            clientRole = .player
            snapshot = GameSnapshot(room: room, localPlayerID: player.id, localHostID: nil)
            lastError = nil
            return player
        } catch {
            lastError = error
            throw error
        }
    }

    public func startGame() async throws(GameServiceError) {
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

    public func selectClue(_ clueID: ClueID) async throws(GameServiceError) {
        let roomID = try currentRoomID()
        let hostID = try currentHostID()
        do {
            snapshot.room = try await service.selectClue(roomID: roomID, hostID: hostID, clueID: clueID)
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
    }

    public func buzz() async throws(GameServiceError) {
        let roomID = try currentRoomID()
        guard let playerID = snapshot.localPlayerID else {
            lastError = .playerNotFound
            throw .playerNotFound
        }
        do {
            snapshot.room = try await service.buzz(roomID: roomID, playerID: playerID, callerPlayerID: playerID)
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
    }

    public func markCorrect() async throws(GameServiceError) {
        let roomID = try currentRoomID()
        let hostID = try currentHostID()
        do {
            snapshot.room = try await service.markCorrect(roomID: roomID, hostID: hostID)
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
    }

    public func markIncorrect() async throws(GameServiceError) {
        let roomID = try currentRoomID()
        let hostID = try currentHostID()
        do {
            snapshot.room = try await service.markIncorrect(roomID: roomID, hostID: hostID)
            lastError = nil
        } catch {
            lastError = error
            throw error
        }
    }

    public func runDebugAction(_ action: GameManagerDebugAction) async throws(GameServiceError) {
        switch action {
        case .createRoom:
            _ = try await createRoom()
        case .startGame:
            try await startGame()
        case .selectFirstAvailableClue:
            guard let clueID = snapshot.room?.board.clues.first(where: { !$0.isUsed })?.id else {
                throw .clueNotFound
            }
            try await selectClue(clueID)
        case .markCorrect:
            try await markCorrect()
        case .resetLocalSnapshot:
            snapshot = GameSnapshot()
            lastError = nil
        }
    }

    public func setClientRole(_ role: GameClientRole) {
        clientRole = role
    }

    public func debugActions(for role: GameClientRole) -> [GameManagerDebugAction] {
        switch role {
        case .board:
            return debugActions
        case .player:
            return [.resetLocalSnapshot]
        }
    }

    private func currentRoomID() throws(GameServiceError) -> RoomID {
        guard let roomID = snapshot.room?.id else {
            lastError = .roomNotFound
            throw .roomNotFound
        }
        return roomID
    }

    private func currentHostID() throws(GameServiceError) -> HostID {
        try requireBoardRole()
        guard let hostID = snapshot.localHostID else {
            lastError = .unauthorizedHost
            throw .unauthorizedHost
        }
        return hostID
    }

    private func requireBoardRole() throws(GameServiceError) {
        guard clientRole == .board else {
            lastError = .unauthorizedHost
            throw .unauthorizedHost
        }
    }
}
