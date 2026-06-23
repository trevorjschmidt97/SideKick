import Foundation
import GameCore

public struct CreateGameIntent: Sendable {
    public init() {}

    @MainActor
    public func perform(manager: any GameManaging, board: GameBoard = .sample) async throws(GameServiceError) -> GameRoom {
        try await manager.createRoom(board: board)
    }
}

public struct JoinGameIntent: Sendable {
    public init() {}

    @MainActor
    public func perform(manager: any GameManaging, joinCode: JoinCode, displayName: String) async throws(GameServiceError) -> Player {
        try await manager.joinRoom(joinCode: joinCode, displayName: displayName)
    }
}

public struct StartGameIntent: Sendable {
    public init() {}

    @MainActor
    public func perform(manager: any GameManaging) async throws(GameServiceError) {
        try await manager.startGame()
    }
}

public struct SelectClueIntent: Sendable {
    public init() {}

    @MainActor
    public func perform(manager: any GameManaging, clueID: ClueID) async throws(GameServiceError) {
        try await manager.selectClue(clueID)
    }
}

public struct BuzzIntent: Sendable {
    public init() {}

    @MainActor
    public func perform(manager: any GameManaging) async throws(GameServiceError) {
        try await manager.buzz()
    }
}

public struct MarkCorrectIntent: Sendable {
    public init() {}

    @MainActor
    public func perform(manager: any GameManaging) async throws(GameServiceError) {
        try await manager.markCorrect()
    }
}

public struct MarkIncorrectIntent: Sendable {
    public init() {}

    @MainActor
    public func perform(manager: any GameManaging) async throws(GameServiceError) {
        try await manager.markIncorrect()
    }
}
