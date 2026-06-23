import Foundation

public enum GameServiceError: Error, Codable, Equatable, Sendable {
    case roomNotFound
    case playerNotFound
    case clueNotFound
    case invalidPhase(expected: [GamePhase], actual: GamePhase)
    case clueAlreadyUsed
    case playerLockedOut
    case buzzAlreadyLocked
    case invalidDisplayName
    case joinCodeUnavailable
    case unauthorizedHost
    case notEnoughPlayers
    case backendUnavailable(String)
}

public protocol GameService: Sendable {
    func createRoom(board: GameBoard) async throws(GameServiceError) -> GameRoom
    func room(joinCode: JoinCode) async throws(GameServiceError) -> GameRoom
    func joinRoom(joinCode: JoinCode, displayName: String) async throws(GameServiceError) -> (GameRoom, Player)
    func startGame(roomID: RoomID, hostID: HostID) async throws(GameServiceError) -> GameRoom
    func selectClue(roomID: RoomID, hostID: HostID, clueID: ClueID) async throws(GameServiceError) -> GameRoom
    func buzz(roomID: RoomID, playerID: PlayerID, callerPlayerID: PlayerID) async throws(GameServiceError) -> GameRoom
    func markCorrect(roomID: RoomID, hostID: HostID) async throws(GameServiceError) -> GameRoom
    func markIncorrect(roomID: RoomID, hostID: HostID) async throws(GameServiceError) -> GameRoom
}

public protocol GameManaging: AnyObject {
    @MainActor func createRoom(board: GameBoard) async throws(GameServiceError) -> GameRoom
    @MainActor func joinRoom(joinCode: JoinCode, displayName: String) async throws(GameServiceError) -> Player
    @MainActor func startGame() async throws(GameServiceError)
    @MainActor func selectClue(_ clueID: ClueID) async throws(GameServiceError)
    @MainActor func buzz() async throws(GameServiceError)
    @MainActor func markCorrect() async throws(GameServiceError)
    @MainActor func markIncorrect() async throws(GameServiceError)
}

public struct GameSnapshot: Codable, Hashable, Sendable {
    public var room: GameRoom?
    public var localPlayerID: PlayerID?
    public var localHostID: HostID?

    public init(room: GameRoom? = nil, localPlayerID: PlayerID? = nil, localHostID: HostID? = nil) {
        self.room = room
        self.localPlayerID = localPlayerID
        self.localHostID = localHostID
    }
}
