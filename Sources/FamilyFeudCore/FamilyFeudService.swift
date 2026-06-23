import Foundation

public enum FamilyFeudServiceError: Error, Codable, Equatable, Hashable, Sendable {
    case roomNotFound
    case playerNotFound
    case teamNotFound
    case questionNotFound
    case answerNotFound
    case answerAlreadyRevealed
    case invalidDisplayName
    case joinCodeUnavailable
    case unauthorizedHost
    case notEnoughPlayers
    case invalidPhase(expected: [FamilyFeudPhase], actual: FamilyFeudPhase)
    case backendUnavailable(String)
}

public protocol FamilyFeudService: Sendable {
    func createRoom(board: FeudBoard) async throws(FamilyFeudServiceError) -> FamilyFeudRoom
    func room(joinCode: FeudJoinCode) async throws(FamilyFeudServiceError) -> FamilyFeudRoom
    func joinRoom(joinCode: FeudJoinCode, displayName: String) async throws(FamilyFeudServiceError) -> (FamilyFeudRoom, FeudPlayer)
    func startGame(roomID: FeudRoomID, hostID: FeudHostID) async throws(FamilyFeudServiceError) -> FamilyFeudRoom
    func revealAnswer(roomID: FeudRoomID, hostID: FeudHostID, answerID: FeudAnswerID, teamID: FeudTeamID) async throws(FamilyFeudServiceError) -> FamilyFeudRoom
    func endRound(roomID: FeudRoomID, hostID: FeudHostID) async throws(FamilyFeudServiceError) -> FamilyFeudRoom
    func advanceToNextQuestion(roomID: FeudRoomID, hostID: FeudHostID) async throws(FamilyFeudServiceError) -> FamilyFeudRoom
}

public protocol FamilyFeudManaging: AnyObject {
    @MainActor func createRoom(board: FeudBoard) async throws(FamilyFeudServiceError) -> FamilyFeudRoom
    @MainActor func joinRoom(joinCode: FeudJoinCode, displayName: String) async throws(FamilyFeudServiceError) -> FeudPlayer
    @MainActor func startGame() async throws(FamilyFeudServiceError)
    @MainActor func revealAnswer(_ answerID: FeudAnswerID, for teamID: FeudTeamID) async throws(FamilyFeudServiceError)
    @MainActor func endRound() async throws(FamilyFeudServiceError)
    @MainActor func advanceToNextQuestion() async throws(FamilyFeudServiceError)
}

public struct FamilyFeudSnapshot: Codable, Hashable, Sendable {
    public var room: FamilyFeudRoom?
    public var localPlayerID: FeudPlayerID?
    public var localHostID: FeudHostID?

    public init(room: FamilyFeudRoom? = nil, localPlayerID: FeudPlayerID? = nil, localHostID: FeudHostID? = nil) {
        self.room = room
        self.localPlayerID = localPlayerID
        self.localHostID = localHostID
    }
}
