import Foundation
import FamilyFeudCore

public actor FakeLocalFamilyFeudService: FamilyFeudService {
    private var roomsByID: [FeudRoomID: FamilyFeudRoom]
    private var roomIDsByJoinCode: [FeudJoinCode: FeudRoomID]
    private var nextRoomNumber: Int
    private var nextPlayerNumber: Int

    public init(rooms: [FamilyFeudRoom] = []) {
        self.roomsByID = Dictionary(uniqueKeysWithValues: rooms.map { ($0.id, $0) })
        self.roomIDsByJoinCode = Dictionary(uniqueKeysWithValues: rooms.map { ($0.joinCode, $0.id) })
        self.nextRoomNumber = rooms.count + 1
        self.nextPlayerNumber = rooms.flatMap(\.players).count + 1
    }

    public func createRoom(board: FeudBoard = .sample) async throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        let roomNumber = nextRoomNumber
        nextRoomNumber += 1
        let room = FamilyFeudRoom(
            id: FeudRoomID(rawValue: "feud-room-\(roomNumber)"),
            joinCode: uniqueJoinCode(for: roomNumber),
            hostID: FeudHostID(rawValue: "feud-host-\(roomNumber)"),
            board: board
        )
        roomsByID[room.id] = room
        roomIDsByJoinCode[room.joinCode] = room.id
        return room
    }

    public func room(joinCode: FeudJoinCode) async throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        guard let roomID = roomIDsByJoinCode[joinCode], let room = roomsByID[roomID] else {
            throw .roomNotFound
        }
        return room
    }

    public func joinRoom(joinCode: FeudJoinCode, displayName: String) async throws(FamilyFeudServiceError) -> (FamilyFeudRoom, FeudPlayer) {
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
        let player = FeudPlayer(id: FeudPlayerID(rawValue: "feud-player-\(nextPlayerNumber)"), displayName: trimmedName)
        nextPlayerNumber += 1
        room.players.append(player)
        roomsByID[roomID] = room
        return (room, player)
    }

    public func startGame(roomID: FeudRoomID, hostID: FeudHostID) async throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        var room = try existingRoom(roomID)
        try validateHost(hostID, in: room)
        room = try FamilyFeudRules.startGame(in: room)
        roomsByID[roomID] = room
        return room
    }

    public func revealAnswer(roomID: FeudRoomID, hostID: FeudHostID, answerID: FeudAnswerID, teamID: FeudTeamID) async throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        try validateHost(hostID, in: existingRoom(roomID))
        let room = try FamilyFeudRules.revealAnswer(answerID, for: teamID, in: existingRoom(roomID))
        roomsByID[roomID] = room
        return room
    }

    public func endRound(roomID: FeudRoomID, hostID: FeudHostID) async throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        try validateHost(hostID, in: existingRoom(roomID))
        let room = try FamilyFeudRules.endRound(in: existingRoom(roomID))
        roomsByID[roomID] = room
        return room
    }

    public func advanceToNextQuestion(roomID: FeudRoomID, hostID: FeudHostID) async throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        try validateHost(hostID, in: existingRoom(roomID))
        let room = try FamilyFeudRules.advanceToNextQuestion(in: existingRoom(roomID))
        roomsByID[roomID] = room
        return room
    }

    private func existingRoom(_ roomID: FeudRoomID) throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        guard let room = roomsByID[roomID] else {
            throw .roomNotFound
        }
        return room
    }

    private func validateHost(_ hostID: FeudHostID, in room: FamilyFeudRoom) throws(FamilyFeudServiceError) {
        guard room.hostID == hostID else {
            throw .unauthorizedHost
        }
    }

    private func uniqueJoinCode(for seed: Int) -> FeudJoinCode {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        var candidate = seed
        while true {
            var code = ""
            var value = candidate
            for _ in 0..<4 {
                code.append(alphabet[value % alphabet.count])
                value /= alphabet.count
            }
            let joinCode = FeudJoinCode(rawValue: String(code.reversed()))
            if roomIDsByJoinCode[joinCode] == nil {
                return joinCode
            }
            candidate += 1
        }
    }
}
