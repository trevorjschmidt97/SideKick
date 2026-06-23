import Foundation

public struct PlayerID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct HostID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum GameClientRole: String, Codable, Hashable, Sendable {
    case board
    case player
}

public struct RoomID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct JoinCode: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = valueNormalized(rawValue)
    }

    public init(stringLiteral value: String) {
        self.rawValue = valueNormalized(value)
    }

    public init(from decoder: Decoder) throws {
        rawValue = valueNormalized(try decoder.singleValueContainer().decode(String.self))
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

private func valueNormalized(_ value: String) -> String {
    value.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()
}

public struct ClueID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String

    public init(rawValue: String) {
        self.rawValue = rawValue
    }

    public init(stringLiteral value: String) {
        self.rawValue = value
    }

    public init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public enum GamePhase: String, Codable, Hashable, Sendable {
    case waiting
    case grid
    case clueOpen
    case buzzLocked
    case finished
}

public struct Player: Codable, Hashable, Identifiable, Sendable {
    public var id: PlayerID
    public var displayName: String
    public var score: Int
    public var lockedOutClueIDs: Set<ClueID>

    public init(id: PlayerID, displayName: String, score: Int = 0, lockedOutClueIDs: Set<ClueID> = []) {
        self.id = id
        self.displayName = displayName
        self.score = score
        self.lockedOutClueIDs = lockedOutClueIDs
    }
}

public struct Clue: Codable, Hashable, Identifiable, Sendable {
    public var id: ClueID
    public var category: String
    public var value: Int
    public var prompt: String
    public var answer: String
    public var isUsed: Bool

    public init(id: ClueID, category: String, value: Int, prompt: String, answer: String, isUsed: Bool = false) {
        self.id = id
        self.category = category
        self.value = value
        self.prompt = prompt
        self.answer = answer
        self.isUsed = isUsed
    }
}

public struct GameBoard: Codable, Hashable, Sendable {
    public var categories: [String]
    public var clues: [Clue]

    public init(categories: [String], clues: [Clue]) {
        self.categories = categories
        self.clues = clues
    }

    public static let sample = GameBoard(
        categories: ["Science", "Movies", "History"],
        clues: [
            Clue(id: "science-200", category: "Science", value: 200, prompt: "This planet is known as the Red Planet.", answer: "Mars"),
            Clue(id: "science-400", category: "Science", value: 400, prompt: "This force keeps planets in orbit around the Sun.", answer: "Gravity"),
            Clue(id: "science-600", category: "Science", value: 600, prompt: "Water changes to vapor at this common boiling point in Celsius.", answer: "100"),
            Clue(id: "movies-200", category: "Movies", value: 200, prompt: "This 1995 Pixar film stars Woody and Buzz.", answer: "Toy Story"),
            Clue(id: "movies-400", category: "Movies", value: 400, prompt: "This director made Jaws, E.T., and Jurassic Park.", answer: "Steven Spielberg"),
            Clue(id: "movies-600", category: "Movies", value: 600, prompt: "This movie features the quote, 'There is no place like home.'", answer: "The Wizard of Oz"),
            Clue(id: "history-200", category: "History", value: 200, prompt: "This document was signed in 1776 by American colonies.", answer: "Declaration of Independence"),
            Clue(id: "history-400", category: "History", value: 400, prompt: "This wall fell in Germany in 1989.", answer: "Berlin Wall"),
            Clue(id: "history-600", category: "History", value: 600, prompt: "This ancient civilization built pyramids at Giza.", answer: "Egyptians"),
        ]
    )
}

public struct GameRoom: Codable, Hashable, Identifiable, Sendable {
    public var id: RoomID
    public var joinCode: JoinCode
    public var hostID: HostID
    public var board: GameBoard
    public var players: [Player]
    public var phase: GamePhase
    public var selectedClueID: ClueID?
    public var firstBuzzedPlayerID: PlayerID?

    public init(
        id: RoomID,
        joinCode: JoinCode,
        hostID: HostID = "host-local",
        board: GameBoard = .sample,
        players: [Player] = [],
        phase: GamePhase = .waiting,
        selectedClueID: ClueID? = nil,
        firstBuzzedPlayerID: PlayerID? = nil
    ) {
        self.id = id
        self.joinCode = joinCode
        self.hostID = hostID
        self.board = board
        self.players = players
        self.phase = phase
        self.selectedClueID = selectedClueID
        self.firstBuzzedPlayerID = firstBuzzedPlayerID
    }

    public var selectedClue: Clue? {
        guard let selectedClueID else { return nil }
        return board.clues.first { $0.id == selectedClueID }
    }

    public var firstBuzzedPlayer: Player? {
        guard let firstBuzzedPlayerID else { return nil }
        return players.first { $0.id == firstBuzzedPlayerID }
    }
}
