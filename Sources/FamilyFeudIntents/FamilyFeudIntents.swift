import FamilyFeudCore
import FamilyFeudManagers

public struct CreateFamilyFeudRoomIntent: Sendable {
    public init() {}
    @discardableResult
    public func perform(manager: FamilyFeudManager, board: FeudBoard = .sample) async throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        try await manager.createRoom(board: board)
    }
}

public struct JoinFamilyFeudRoomIntent: Sendable {
    public init() {}
    @discardableResult
    public func perform(manager: FamilyFeudManager, joinCode: FeudJoinCode, displayName: String) async throws(FamilyFeudServiceError) -> FeudPlayer {
        try await manager.joinRoom(joinCode: joinCode, displayName: displayName)
    }
}

public struct StartFamilyFeudGameIntent: Sendable {
    public init() {}
    public func perform(manager: FamilyFeudManager) async throws(FamilyFeudServiceError) {
        try await manager.startGame()
    }
}

public struct RevealFamilyFeudAnswerIntent: Sendable {
    public init() {}
    public func perform(manager: FamilyFeudManager, answerID: FeudAnswerID, teamID: FeudTeamID) async throws(FamilyFeudServiceError) {
        try await manager.revealAnswer(answerID, for: teamID)
    }
}

public struct EndFamilyFeudRoundIntent: Sendable {
    public init() {}
    public func perform(manager: FamilyFeudManager) async throws(FamilyFeudServiceError) {
        try await manager.endRound()
    }
}

public struct AdvanceFamilyFeudQuestionIntent: Sendable {
    public init() {}
    public func perform(manager: FamilyFeudManager) async throws(FamilyFeudServiceError) {
        try await manager.advanceToNextQuestion()
    }
}
