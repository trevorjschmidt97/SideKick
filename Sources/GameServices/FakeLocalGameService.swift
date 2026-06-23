import Foundation
import GameCore

public actor FakeLocalGameService: GameService {
    private var roomsByID: [RoomID: GameRoom]
    private var roomIDsByJoinCode: [JoinCode: RoomID]
    private var nextRoomNumber: Int
    private var nextPlayerNumber: Int

    public init(rooms: [GameRoom] = []) {
        self.roomsByID = Dictionary(uniqueKeysWithValues: rooms.map { ($0.id, $0) })
        self.roomIDsByJoinCode = Dictionary(uniqueKeysWithValues: rooms.map { ($0.joinCode, $0.id) })
        self.nextRoomNumber = rooms.count + 1
        self.nextPlayerNumber = rooms.flatMap(\.players).count + 1
    }

    public func createRoom(board: GameBoard = .sample) async throws(GameServiceError) -> GameRoom {
        let roomNumber = nextRoomNumber
        nextRoomNumber += 1
        let room = GameRoom(
            id: RoomID(rawValue: "room-\(roomNumber)"),
            joinCode: uniqueJoinCode(for: roomNumber),
            hostID: HostID(rawValue: "host-\(roomNumber)"),
            board: board,
            phase: .waiting
        )
        roomsByID[room.id] = room
        roomIDsByJoinCode[room.joinCode] = room.id
        return room
    }

    public func room(joinCode: JoinCode) async throws(GameServiceError) -> GameRoom {
        guard let roomID = roomIDsByJoinCode[joinCode], let room = roomsByID[roomID] else {
            throw .roomNotFound
        }
        return room
    }

    public func joinRoom(joinCode: JoinCode, displayName: String) async throws(GameServiceError) -> (GameRoom, Player) {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw .invalidDisplayName
        }
        guard let roomID = roomIDsByJoinCode[joinCode], var room = roomsByID[roomID] else {
            throw .roomNotFound
        }
        guard room.phase == .waiting else {
            throw .invalidPhase(expected: [.waiting], actual: room.phase)
        }
        if let existingPlayer = room.players.first(where: { $0.displayName == trimmedName }) {
            return (room, existingPlayer)
        }

        let player = Player(id: PlayerID(rawValue: "player-\(nextPlayerNumber)"), displayName: trimmedName)
        nextPlayerNumber += 1
        room.players.append(player)
        roomsByID[roomID] = room
        return (room, player)
    }

    public func startGame(roomID: RoomID, hostID: HostID) async throws(GameServiceError) -> GameRoom {
        var room = try existingRoom(roomID)
        try validateHost(hostID, in: room)
        guard room.phase == .waiting else {
            throw .invalidPhase(expected: [.waiting], actual: room.phase)
        }
        guard !room.players.isEmpty else {
            throw .notEnoughPlayers
        }
        room.phase = .grid
        roomsByID[roomID] = room
        return room
    }

    public func selectClue(roomID: RoomID, hostID: HostID, clueID: ClueID) async throws(GameServiceError) -> GameRoom {
        try validateHost(hostID, in: existingRoom(roomID))
        let room = try GameRules.selectClue(clueID, in: existingRoom(roomID))
        roomsByID[roomID] = room
        return room
    }

    public func buzz(roomID: RoomID, playerID: PlayerID, callerPlayerID: PlayerID) async throws(GameServiceError) -> GameRoom {
        guard playerID == callerPlayerID else {
            throw .playerNotFound
        }
        let room = try GameRules.buzz(playerID: playerID, in: existingRoom(roomID))
        roomsByID[roomID] = room
        return room
    }

    public func markCorrect(roomID: RoomID, hostID: HostID) async throws(GameServiceError) -> GameRoom {
        try validateHost(hostID, in: existingRoom(roomID))
        let room = try GameRules.markCorrect(in: existingRoom(roomID))
        roomsByID[roomID] = room
        return room
    }

    public func markIncorrect(roomID: RoomID, hostID: HostID) async throws(GameServiceError) -> GameRoom {
        try validateHost(hostID, in: existingRoom(roomID))
        let room = try GameRules.markIncorrect(in: existingRoom(roomID))
        roomsByID[roomID] = room
        return room
    }

    private func existingRoom(_ roomID: RoomID) throws(GameServiceError) -> GameRoom {
        guard let room = roomsByID[roomID] else {
            throw .roomNotFound
        }
        return room
    }

    private func validateHost(_ hostID: HostID, in room: GameRoom) throws(GameServiceError) {
        guard room.hostID == hostID else {
            throw .unauthorizedHost
        }
    }

    private func uniqueJoinCode(for seed: Int) -> JoinCode {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var candidate = seed
        while true {
            var code = ""
            var value = candidate
            for _ in 0..<4 {
                code.append(alphabet[value % alphabet.count])
                value /= alphabet.count
            }
            let joinCode = JoinCode(rawValue: String(code.reversed()))
            if roomIDsByJoinCode[joinCode] == nil {
                return joinCode
            }
            candidate += 1
        }
    }
}
