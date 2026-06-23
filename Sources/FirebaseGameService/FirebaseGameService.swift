import Foundation
import FirebaseCoreService
import FirestoreDataService
import GameCore

public struct FirebaseGameServiceConfiguration: Codable, Hashable, Sendable {
    public var projectID: String?
    public var emulatorHost: String?
    public var authEmulatorHost: String?
    public var usesEmulator: Bool

    public init(
        projectID: String? = nil,
        emulatorHost: String? = nil,
        authEmulatorHost: String? = nil,
        usesEmulator: Bool = false
    ) {
        self.projectID = projectID
        self.emulatorHost = emulatorHost
        self.authEmulatorHost = authEmulatorHost
        self.usesEmulator = usesEmulator
    }
}

public struct FirebaseGameServicePrincipal: Codable, Hashable, Sendable {
    public var userID: String

    public init(userID: String) {
        self.userID = userID
    }

    public var hostID: HostID {
        HostID(rawValue: userID)
    }

    public var playerID: PlayerID {
        PlayerID(rawValue: userID)
    }
}

public struct FirebaseGameRoomDocument: FirestoreDocument {
    public var id: RoomID
    public var joinCode: JoinCode
    public var hostID: HostID
    public var playerIDs: [String]
    public var board: GameBoard
    public var players: [Player]
    public var phase: GamePhase
    public var selectedClueID: ClueID?
    public var firstBuzzedPlayerID: PlayerID?

    public init(room: GameRoom) {
        self.id = room.id
        self.joinCode = room.joinCode
        self.hostID = room.hostID
        self.playerIDs = room.players.map(\.id.rawValue)
        self.board = room.board
        self.players = room.players
        self.phase = room.phase
        self.selectedClueID = room.selectedClueID
        self.firstBuzzedPlayerID = room.firstBuzzedPlayerID
    }

    public var room: GameRoom {
        GameRoom(
            id: id,
            joinCode: joinCode,
            hostID: hostID,
            board: board,
            players: players,
            phase: phase,
            selectedClueID: selectedClueID,
            firstBuzzedPlayerID: firstBuzzedPlayerID
        )
    }

    public var primitiveFieldValues: [String: String] {
        var values = [
            "id": id.rawValue,
            "joinCode": joinCode.rawValue,
            "hostID": hostID.rawValue,
            "phase": phase.rawValue,
        ]
        if let selectedClueID {
            values["selectedClueID"] = selectedClueID.rawValue
        }
        if let firstBuzzedPlayerID {
            values["firstBuzzedPlayerID"] = firstBuzzedPlayerID.rawValue
        }
        return values
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case joinCode
        case hostID
        case playerIDs
        case board
        case players
        case phase
        case selectedClueID
        case firstBuzzedPlayerID
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(RoomID.self, forKey: .id)
        joinCode = try container.decode(JoinCode.self, forKey: .joinCode)
        hostID = try container.decode(HostID.self, forKey: .hostID)
        board = try container.decode(GameBoard.self, forKey: .board)
        players = try container.decode([Player].self, forKey: .players)
        playerIDs = try container.decodeIfPresent([String].self, forKey: .playerIDs) ?? players.map(\.id.rawValue)
        phase = try container.decode(GamePhase.self, forKey: .phase)
        selectedClueID = try container.decodeIfPresent(ClueID.self, forKey: .selectedClueID)
        firstBuzzedPlayerID = try container.decodeIfPresent(PlayerID.self, forKey: .firstBuzzedPlayerID)
    }
}

public enum FirebaseGameMutationResult: Sendable {
    case updated(GameRoom)
}

public protocol FirebaseGameDocumentStore: Sendable {
    func roomDocument(roomID: RoomID) async throws(GameServiceError) -> FirebaseGameRoomDocument?
    func roomDocument(joinCode: JoinCode) async throws(GameServiceError) -> FirebaseGameRoomDocument?
    func createRoomDocument(_ document: FirebaseGameRoomDocument) async throws(GameServiceError)
    func saveRoomDocument(_ document: FirebaseGameRoomDocument) async throws(GameServiceError)
    func mutateRoomDocument(
        roomID: RoomID,
        operation: @escaping @Sendable (GameRoom) -> Result<FirebaseGameMutationResult, GameServiceError>
    ) async throws(GameServiceError) -> GameRoom
}

public actor InMemoryFirebaseGameDocumentStore: FirebaseGameDocumentStore {
    private let store: InMemoryFirestoreDocumentStore<FirebaseGameRoomDocument>

    public init(documents: [FirebaseGameRoomDocument] = []) {
        self.store = InMemoryFirestoreDocumentStore(documents: documents)
    }

    public func roomDocument(roomID: RoomID) async throws(GameServiceError) -> FirebaseGameRoomDocument? {
        try await mapStoreError {
            try await store.document(id: roomID)
        }
    }

    public func roomDocument(joinCode: JoinCode) async throws(GameServiceError) -> FirebaseGameRoomDocument? {
        try await mapStoreError {
            try await store.firstDocument(where: "joinCode", equals: joinCode.rawValue)
        }
    }

    public func saveRoomDocument(_ document: FirebaseGameRoomDocument) async throws(GameServiceError) {
        try await mapStoreError {
            try await store.saveDocument(document)
        }
    }

    public func createRoomDocument(_ document: FirebaseGameRoomDocument) async throws(GameServiceError) {
        try await mapStoreError {
            if try await store.firstDocument(where: "joinCode", equals: document.joinCode.rawValue) != nil {
                throw FirestoreDataServiceError.documentAlreadyExists
            }
            try await store.createDocument(document)
        }
    }

    public func mutateRoomDocument(
        roomID: RoomID,
        operation: @escaping @Sendable (GameRoom) -> Result<FirebaseGameMutationResult, GameServiceError>
    ) async throws(GameServiceError) -> GameRoom {
        nonisolated(unsafe) var featureError: GameServiceError?
        let document = try await mapStoreError {
            try await store.mutateDocument(id: roomID) { document in
                switch operation(document.room) {
                case .failure(let error):
                    featureError = error
                    return .failure(.backendUnavailable("PartyGame mutation rejected."))
                case .success(.updated(let room)):
                    return .success(FirebaseGameRoomDocument(room: room))
                }
            }
        } onError: { error in
            featureError ?? mapFirestoreError(error)
        }
        return document.room
    }
}

public actor GenericFirebaseGameDocumentStore: FirebaseGameDocumentStore {
    private let store: AnyFirestoreDocumentStore<FirebaseGameRoomDocument>

    public init<Store: FirestoreDocumentStore>(store: Store) where Store.Document == FirebaseGameRoomDocument {
        self.store = AnyFirestoreDocumentStore(store)
    }

    public func roomDocument(roomID: RoomID) async throws(GameServiceError) -> FirebaseGameRoomDocument? {
        try await mapStoreError {
            try await store.document(id: roomID)
        }
    }

    public func roomDocument(joinCode: JoinCode) async throws(GameServiceError) -> FirebaseGameRoomDocument? {
        try await mapStoreError {
            try await store.firstDocument(where: "joinCode", equals: joinCode.rawValue)
        }
    }

    public func createRoomDocument(_ document: FirebaseGameRoomDocument) async throws(GameServiceError) {
        try await mapStoreError {
            if try await store.firstDocument(where: "joinCode", equals: document.joinCode.rawValue) != nil {
                throw FirestoreDataServiceError.documentAlreadyExists
            }
            try await store.createDocument(document)
        }
    }

    public func saveRoomDocument(_ document: FirebaseGameRoomDocument) async throws(GameServiceError) {
        try await mapStoreError {
            try await store.saveDocument(document)
        }
    }

    public func mutateRoomDocument(
        roomID: RoomID,
        operation: @escaping @Sendable (GameRoom) -> Result<FirebaseGameMutationResult, GameServiceError>
    ) async throws(GameServiceError) -> GameRoom {
        nonisolated(unsafe) var featureError: GameServiceError?
        let document = try await mapStoreError {
            try await store.mutateDocument(id: roomID) { document in
                switch operation(document.room) {
                case .failure(let error):
                    featureError = error
                    return .failure(.backendUnavailable("PartyGame mutation rejected."))
                case .success(.updated(let room)):
                    return .success(FirebaseGameRoomDocument(room: room))
                }
            }
        } onError: { error in
            featureError ?? mapFirestoreError(error)
        }
        return document.room
    }
}

private func mapStoreError<T>(
    _ operation: @Sendable () async throws -> T,
    onError: @Sendable (FirestoreDataServiceError) -> GameServiceError = { mapFirestoreError($0) }
) async throws(GameServiceError) -> T {
    do {
        return try await operation()
    } catch let error as FirestoreDataServiceError {
        throw onError(error)
    } catch {
        throw .backendUnavailable(error.localizedDescription)
    }
}

private func mapFirestoreError(_ error: FirestoreDataServiceError) -> GameServiceError {
    switch error {
    case .documentNotFound:
        return .roomNotFound
    case .documentAlreadyExists:
        return .joinCodeUnavailable
    case .queryConflict:
        return .backendUnavailable("Firestore query returned conflicting game room documents.")
    case .backendUnavailable(let message):
        return .backendUnavailable(message)
    }
}

public actor ContendedFirebaseGameDocumentStore: FirebaseGameDocumentStore {
    private var document: FirebaseGameRoomDocument

    public init(document: FirebaseGameRoomDocument) {
        self.document = document
    }

    public func roomDocument(roomID: RoomID) async throws(GameServiceError) -> FirebaseGameRoomDocument? {
        document.room.id == roomID ? document : nil
    }

    public func roomDocument(joinCode: JoinCode) async throws(GameServiceError) -> FirebaseGameRoomDocument? {
        document.room.joinCode == joinCode ? document : nil
    }

    public func saveRoomDocument(_ document: FirebaseGameRoomDocument) async throws(GameServiceError) {
        self.document = document
    }

    public func createRoomDocument(_ document: FirebaseGameRoomDocument) async throws(GameServiceError) {
        guard self.document.room.joinCode != document.room.joinCode else {
            throw .joinCodeUnavailable
        }
        self.document = document
    }

    public func mutateRoomDocument(
        roomID: RoomID,
        operation: @escaping @Sendable (GameRoom) -> Result<FirebaseGameMutationResult, GameServiceError>
    ) async throws(GameServiceError) -> GameRoom {
        guard document.room.id == roomID else {
            throw .roomNotFound
        }
        switch operation(document.room) {
        case .failure(let error):
            throw error
        case .success(.updated(let room)):
            document = FirebaseGameRoomDocument(room: room)
            return room
        }
    }
}

public actor FirebaseGameService: GameService {
    private let configuration: FirebaseGameServiceConfiguration
    private let principal: FirebaseGameServicePrincipal?
    private let store: (any FirebaseGameDocumentStore)?

    public init(
        configuration: FirebaseGameServiceConfiguration,
        principal: FirebaseGameServicePrincipal? = nil,
        store: (any FirebaseGameDocumentStore)? = nil
    ) {
        self.configuration = configuration
        self.principal = principal
        self.store = store
    }

    public func createRoom(board: GameBoard) async throws(GameServiceError) -> GameRoom {
        let store = try storeOrThrow()
        let principal = try principalOrThrow()
        for _ in 0..<100 {
            let room = GameRoom(
                id: RoomID(rawValue: "firebase-room-\(UUID().uuidString)"),
                joinCode: randomJoinCode(),
                hostID: principal.hostID,
                board: board,
                phase: .waiting
            )
            do {
                try await store.createRoomDocument(FirebaseGameRoomDocument(room: room))
                return room
            } catch .joinCodeUnavailable {
                continue
            }
        }
        throw .joinCodeUnavailable
    }

    public func room(joinCode: JoinCode) async throws(GameServiceError) -> GameRoom {
        guard let room = try await roomDocument(joinCode: joinCode)?.room else {
            throw .roomNotFound
        }
        return room
    }

    public func joinRoom(joinCode: JoinCode, displayName: String) async throws(GameServiceError) -> (GameRoom, Player) {
        let trimmedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else {
            throw .invalidDisplayName
        }
        let principal = try principalOrThrow()
        let player = Player(id: principal.playerID, displayName: trimmedName)
        let existingRoom = try await self.room(joinCode: joinCode)
        let room = try await mutateRoom(roomID: existingRoom.id) { room in
            guard room.phase == .waiting else {
                return .failure(.invalidPhase(expected: [.waiting], actual: room.phase))
            }
            if room.players.contains(where: { $0.id == player.id }) {
                return .success(.updated(room))
            }
            var next = room
            next.players.append(player)
            return .success(.updated(next))
        }
        return (room, room.players.first(where: { $0.id == player.id }) ?? player)
    }

    public func startGame(roomID: RoomID, hostID: HostID) async throws(GameServiceError) -> GameRoom {
        let principal = try principalOrThrow()
        guard principal.hostID == hostID else {
            throw .unauthorizedHost
        }
        return try await mutateRoom(roomID: roomID) { room in
            guard room.hostID == hostID else {
                return .failure(.unauthorizedHost)
            }
            guard room.phase == .waiting else {
                return .failure(.invalidPhase(expected: [.waiting], actual: room.phase))
            }
            guard !room.players.isEmpty else {
                return .failure(.notEnoughPlayers)
            }
            var next = room
            next.phase = .grid
            return .success(.updated(next))
        }
    }

    public func selectClue(roomID: RoomID, hostID: HostID, clueID: ClueID) async throws(GameServiceError) -> GameRoom {
        let principal = try principalOrThrow()
        guard principal.hostID == hostID else {
            throw .unauthorizedHost
        }
        return try await mutateRoom(roomID: roomID) { room in
            guard room.hostID == hostID else {
                return .failure(.unauthorizedHost)
            }
            do {
                return .success(.updated(try GameRules.selectClue(clueID, in: room)))
            } catch let error as GameServiceError {
                return .failure(error)
            } catch {
                return .failure(.backendUnavailable(String(describing: error)))
            }
        }
    }

    public func buzz(roomID: RoomID, playerID: PlayerID, callerPlayerID: PlayerID) async throws(GameServiceError) -> GameRoom {
        guard playerID == callerPlayerID else {
            throw .playerNotFound
        }
        let principal = try principalOrThrow()
        if principal.playerID != callerPlayerID {
            throw .playerNotFound
        }
        return try await mutateRoom(roomID: roomID) { room in
            do {
                return .success(.updated(try GameRules.buzz(playerID: playerID, in: room)))
            } catch let error as GameServiceError {
                return .failure(error)
            } catch {
                return .failure(.backendUnavailable(String(describing: error)))
            }
        }
    }

    public func markCorrect(roomID: RoomID, hostID: HostID) async throws(GameServiceError) -> GameRoom {
        let principal = try principalOrThrow()
        guard principal.hostID == hostID else {
            throw .unauthorizedHost
        }
        return try await mutateRoom(roomID: roomID) { room in
            guard room.hostID == hostID else {
                return .failure(.unauthorizedHost)
            }
            do {
                return .success(.updated(try GameRules.markCorrect(in: room)))
            } catch let error as GameServiceError {
                return .failure(error)
            } catch {
                return .failure(.backendUnavailable(String(describing: error)))
            }
        }
    }

    public func markIncorrect(roomID: RoomID, hostID: HostID) async throws(GameServiceError) -> GameRoom {
        let principal = try principalOrThrow()
        guard principal.hostID == hostID else {
            throw .unauthorizedHost
        }
        return try await mutateRoom(roomID: roomID) { room in
            guard room.hostID == hostID else {
                return .failure(.unauthorizedHost)
            }
            do {
                return .success(.updated(try GameRules.markIncorrect(in: room)))
            } catch let error as GameServiceError {
                return .failure(error)
            } catch {
                return .failure(.backendUnavailable(String(describing: error)))
            }
        }
    }

    private func existingRoom(_ roomID: RoomID) async throws(GameServiceError) -> GameRoom {
        guard let room = try await roomDocument(roomID: roomID)?.room else {
            throw .roomNotFound
        }
        return room
    }

    private func save(_ room: GameRoom) async throws(GameServiceError) {
        let store = try storeOrThrow()
        try await store.saveRoomDocument(FirebaseGameRoomDocument(room: room))
    }

    private func mutateRoom(
        roomID: RoomID,
        operation: @escaping @Sendable (GameRoom) -> Result<FirebaseGameMutationResult, GameServiceError>
    ) async throws(GameServiceError) -> GameRoom {
        let store = try storeOrThrow()
        return try await store.mutateRoomDocument(roomID: roomID, operation: operation)
    }

    private func roomDocument(roomID: RoomID) async throws(GameServiceError) -> FirebaseGameRoomDocument? {
        let store = try storeOrThrow()
        return try await store.roomDocument(roomID: roomID)
    }

    private func roomDocument(joinCode: JoinCode) async throws(GameServiceError) -> FirebaseGameRoomDocument? {
        let store = try storeOrThrow()
        return try await store.roomDocument(joinCode: joinCode)
    }

    private func storeOrThrow() throws(GameServiceError) -> any FirebaseGameDocumentStore {
        guard let store else {
            if configuration.usesEmulator {
                throw .backendUnavailable("Firebase emulator adapter is configured, but no FirebaseGameDocumentStore was supplied.")
            }
            throw .backendUnavailable("Firebase credentials are absent; use FakeLocalGameService for local development and tests.")
        }
        return store
    }

    private func principalOrThrow() throws(GameServiceError) -> FirebaseGameServicePrincipal {
        guard let principal else {
            throw .backendUnavailable("Firebase authenticated principal is required for game mutations.")
        }
        return principal
    }

    private func randomJoinCode() -> JoinCode {
        let alphabet = Array("ABCDEFGHJKLMNPQRSTUVWXYZ23456789")
        return JoinCode(rawValue: String((0..<4).map { _ in alphabet.randomElement() ?? "A" }))
    }
}
