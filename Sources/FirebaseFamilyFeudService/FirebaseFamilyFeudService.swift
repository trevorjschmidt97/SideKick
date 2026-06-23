import Foundation
import FirebaseCoreService
import FirestoreDataService
import FamilyFeudCore

public struct FirebaseFamilyFeudServiceConfiguration: Codable, Hashable, Sendable {
    public var firebase: FirebaseServiceConfiguration

    public init(firebase: FirebaseServiceConfiguration = FirebaseServiceConfiguration()) {
        self.firebase = firebase
    }
}

public struct FirebaseFamilyFeudPrincipal: Codable, Hashable, Sendable {
    public var userID: String

    public init(userID: String) {
        self.userID = userID
    }

    public var hostID: FeudHostID { FeudHostID(rawValue: userID) }
    public var playerID: FeudPlayerID { FeudPlayerID(rawValue: userID) }
}

public struct FirebaseFamilyFeudRoomDocument: FirestoreDocument {
    public var id: FeudRoomID
    public var joinCode: FeudJoinCode
    public var hostID: FeudHostID
    public var playerIDs: [String]
    public var teamIDs: [String]
    public var board: FeudBoard
    public var players: [FeudPlayer]
    public var teams: [FeudTeam]
    public var phase: FamilyFeudPhase
    public var activeQuestionID: FeudQuestionID?
    public var currentRoundIndex: Int

    public init(room: FamilyFeudRoom) {
        self.id = room.id
        self.joinCode = room.joinCode
        self.hostID = room.hostID
        self.playerIDs = room.players.map(\.id.rawValue)
        self.teamIDs = room.teams.map(\.id.rawValue)
        self.board = room.board
        self.players = room.players
        self.teams = room.teams
        self.phase = room.phase
        self.activeQuestionID = room.activeQuestionID
        self.currentRoundIndex = room.currentRoundIndex
    }

    public var room: FamilyFeudRoom {
        FamilyFeudRoom(
            id: id,
            joinCode: joinCode,
            hostID: hostID,
            board: board,
            players: players,
            teams: teams,
            phase: phase,
            activeQuestionID: activeQuestionID,
            currentRoundIndex: currentRoundIndex
        )
    }

    public var primitiveFieldValues: [String: String] {
        var values = [
            "id": id.rawValue,
            "joinCode": joinCode.rawValue,
            "hostID": hostID.rawValue,
            "phase": phase.rawValue,
        ]
        if let activeQuestionID {
            values["activeQuestionID"] = activeQuestionID.rawValue
        }
        return values
    }
}

public actor FirebaseFamilyFeudService: FamilyFeudService {
    private let configuration: FirebaseFamilyFeudServiceConfiguration
    private let principal: FirebaseFamilyFeudPrincipal?
    private let store: AnyFirestoreDocumentStore<FirebaseFamilyFeudRoomDocument>

    public init<Store: FirestoreDocumentStore>(
        configuration: FirebaseFamilyFeudServiceConfiguration,
        principal: FirebaseFamilyFeudPrincipal? = nil,
        store: Store
    ) where Store.Document == FirebaseFamilyFeudRoomDocument {
        self.configuration = configuration
        self.principal = principal
        self.store = AnyFirestoreDocumentStore(store)
    }

    public func createRoom(board: FeudBoard) async throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        let principal = try principalOrThrow()
        for _ in 0..<100 {
            let room = FamilyFeudRoom(
                id: FeudRoomID(rawValue: "firebase-feud-room-\(UUID().uuidString)"),
                joinCode: randomJoinCode(),
                hostID: principal.hostID,
                board: board
            )
            do {
                if try await store.firstDocument(where: "joinCode", equals: room.joinCode.rawValue) != nil {
                    continue
                }
                try await store.createDocument(FirebaseFamilyFeudRoomDocument(room: room))
                return room
            } catch .documentAlreadyExists {
                continue
            } catch {
                throw mapFirestoreError(error)
            }
        }
        throw .joinCodeUnavailable
    }

    public func room(joinCode: FeudJoinCode) async throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        do {
            guard let document = try await store.firstDocument(where: "joinCode", equals: joinCode.rawValue) else {
                throw FamilyFeudServiceError.roomNotFound
            }
            return document.room
        } catch let error as FamilyFeudServiceError {
            throw error
        } catch let error as FirestoreDataServiceError {
            throw mapFirestoreError(error)
        } catch {
            throw .backendUnavailable(error.localizedDescription)
        }
    }

    public func joinRoom(joinCode: FeudJoinCode, displayName: String) async throws(FamilyFeudServiceError) -> (FamilyFeudRoom, FeudPlayer) {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw .invalidDisplayName
        }
        let principal = try principalOrThrow()
        let player = FeudPlayer(id: principal.playerID, displayName: trimmedName)
        let existingRoom = try await room(joinCode: joinCode)
        let room = try await mutateRoom(roomID: existingRoom.id) { room in
            guard room.phase == .waiting else {
                return .failure(.invalidPhase(expected: [.waiting], actual: room.phase))
            }
            if room.players.contains(where: { $0.id == player.id }) {
                return .success(room)
            }
            var next = room
            next.players.append(player)
            return .success(next)
        }
        return (room, room.players.first(where: { $0.id == player.id }) ?? player)
    }

    public func startGame(roomID: FeudRoomID, hostID: FeudHostID) async throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        try validatePrincipal(hostID)
        return try await mutateHostRoom(roomID: roomID, hostID: hostID) { room in
            Result { try FamilyFeudRules.startGame(in: room) }.mapError { error in
                (error as? FamilyFeudServiceError) ?? .backendUnavailable(error.localizedDescription)
            }
        }
    }

    public func revealAnswer(roomID: FeudRoomID, hostID: FeudHostID, answerID: FeudAnswerID, teamID: FeudTeamID) async throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        try validatePrincipal(hostID)
        return try await mutateHostRoom(roomID: roomID, hostID: hostID) { room in
            Result { try FamilyFeudRules.revealAnswer(answerID, for: teamID, in: room) }.mapError { error in
                (error as? FamilyFeudServiceError) ?? .backendUnavailable(error.localizedDescription)
            }
        }
    }

    public func endRound(roomID: FeudRoomID, hostID: FeudHostID) async throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        try validatePrincipal(hostID)
        return try await mutateHostRoom(roomID: roomID, hostID: hostID) { room in
            Result { try FamilyFeudRules.endRound(in: room) }.mapError { error in
                (error as? FamilyFeudServiceError) ?? .backendUnavailable(error.localizedDescription)
            }
        }
    }

    public func advanceToNextQuestion(roomID: FeudRoomID, hostID: FeudHostID) async throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        try validatePrincipal(hostID)
        return try await mutateHostRoom(roomID: roomID, hostID: hostID) { room in
            Result { try FamilyFeudRules.advanceToNextQuestion(in: room) }.mapError { error in
                (error as? FamilyFeudServiceError) ?? .backendUnavailable(error.localizedDescription)
            }
        }
    }

    private func mutateHostRoom(
        roomID: FeudRoomID,
        hostID: FeudHostID,
        operation: @escaping @Sendable (FamilyFeudRoom) -> Result<FamilyFeudRoom, FamilyFeudServiceError>
    ) async throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        try await mutateRoom(roomID: roomID) { room in
            guard room.hostID == hostID else {
                return .failure(.unauthorizedHost)
            }
            return operation(room)
        }
    }

    private func mutateRoom(
        roomID: FeudRoomID,
        operation: @escaping @Sendable (FamilyFeudRoom) -> Result<FamilyFeudRoom, FamilyFeudServiceError>
    ) async throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        nonisolated(unsafe) var featureError: FamilyFeudServiceError?
        do {
            let document = try await store.mutateDocument(id: roomID) { document in
                switch operation(document.room) {
                case .failure(let error):
                    featureError = error
                    return .failure(.backendUnavailable("Family Feud mutation rejected."))
                case .success(let room):
                    return .success(FirebaseFamilyFeudRoomDocument(room: room))
                }
            }
            return document.room
        } catch {
            throw featureError ?? mapFirestoreError(error)
        }
    }

    private func principalOrThrow() throws(FamilyFeudServiceError) -> FirebaseFamilyFeudPrincipal {
        guard let principal else {
            throw .backendUnavailable("Firebase principal is required.")
        }
        return principal
    }

    private func validatePrincipal(_ hostID: FeudHostID) throws(FamilyFeudServiceError) {
        guard principal?.hostID == hostID else {
            throw .unauthorizedHost
        }
    }

    private func randomJoinCode() -> FeudJoinCode {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return FeudJoinCode(rawValue: String((0..<4).map { _ in alphabet.randomElement() ?? "A" }))
    }

    private func mapFirestoreError(_ error: FirestoreDataServiceError) -> FamilyFeudServiceError {
        switch error {
        case .documentNotFound:
            return .roomNotFound
        case .documentAlreadyExists:
            return .joinCodeUnavailable
        case .queryConflict:
            return .backendUnavailable("Firestore query returned conflicting Family Feud documents.")
        case .backendUnavailable(let message):
            return .backendUnavailable(message)
        }
    }
}
