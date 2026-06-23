import Foundation

public struct FeudPlayerID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: Encoder) throws { var container = encoder.singleValueContainer(); try container.encode(rawValue) }
}

public struct FeudHostID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: Encoder) throws { var container = encoder.singleValueContainer(); try container.encode(rawValue) }
}

public struct FeudRoomID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: Encoder) throws { var container = encoder.singleValueContainer(); try container.encode(rawValue) }
}

public struct FeudJoinCode: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() }
    public init(stringLiteral value: String) { self.init(rawValue: value) }
    public init(from decoder: Decoder) throws { self.init(rawValue: try decoder.singleValueContainer().decode(String.self)) }
    public func encode(to encoder: Encoder) throws { var container = encoder.singleValueContainer(); try container.encode(rawValue) }
}

public struct FeudTeamID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: Encoder) throws { var container = encoder.singleValueContainer(); try container.encode(rawValue) }
}

public struct FeudQuestionID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: Encoder) throws { var container = encoder.singleValueContainer(); try container.encode(rawValue) }
}

public struct FeudAnswerID: RawRepresentable, Codable, Hashable, Sendable, ExpressibleByStringLiteral {
    public var rawValue: String
    public init(rawValue: String) { self.rawValue = rawValue }
    public init(stringLiteral value: String) { self.rawValue = value }
    public init(from decoder: Decoder) throws { rawValue = try decoder.singleValueContainer().decode(String.self) }
    public func encode(to encoder: Encoder) throws { var container = encoder.singleValueContainer(); try container.encode(rawValue) }
}

public enum FamilyFeudClientRole: String, Codable, Hashable, Sendable {
    case host
    case player
}

public enum FamilyFeudPhase: String, Codable, Hashable, Sendable {
    case waiting
    case questionOpen
    case roundComplete
    case finished
}

public struct FeudPlayer: Codable, Hashable, Identifiable, Sendable {
    public var id: FeudPlayerID
    public var displayName: String
    public var teamID: FeudTeamID?

    public init(id: FeudPlayerID, displayName: String, teamID: FeudTeamID? = nil) {
        self.id = id
        self.displayName = displayName
        self.teamID = teamID
    }
}

public struct FeudTeam: Codable, Hashable, Identifiable, Sendable {
    public var id: FeudTeamID
    public var name: String
    public var playerIDs: [FeudPlayerID]
    public var score: Int

    public init(id: FeudTeamID, name: String, playerIDs: [FeudPlayerID] = [], score: Int = 0) {
        self.id = id
        self.name = name
        self.playerIDs = playerIDs
        self.score = score
    }
}

public struct FeudAnswer: Codable, Hashable, Identifiable, Sendable {
    public var id: FeudAnswerID
    public var text: String
    public var points: Int
    public var isRevealed: Bool
    public var revealedByTeamID: FeudTeamID?

    public init(id: FeudAnswerID, text: String, points: Int, isRevealed: Bool = false, revealedByTeamID: FeudTeamID? = nil) {
        self.id = id
        self.text = text
        self.points = points
        self.isRevealed = isRevealed
        self.revealedByTeamID = revealedByTeamID
    }
}

public struct FeudQuestion: Codable, Hashable, Identifiable, Sendable {
    public var id: FeudQuestionID
    public var prompt: String
    public var answers: [FeudAnswer]

    public init(id: FeudQuestionID, prompt: String, answers: [FeudAnswer]) {
        self.id = id
        self.prompt = prompt
        self.answers = answers
    }
}

public struct FeudBoard: Codable, Hashable, Sendable {
    public var questions: [FeudQuestion]

    public init(questions: [FeudQuestion]) {
        self.questions = questions
    }

    public static let sample = FeudBoard(questions: [
        FeudQuestion(id: "morning", prompt: "Name something people do before leaving for work.", answers: [
            FeudAnswer(id: "coffee", text: "Drink coffee", points: 32),
            FeudAnswer(id: "shower", text: "Take a shower", points: 27),
            FeudAnswer(id: "teeth", text: "Brush teeth", points: 24),
            FeudAnswer(id: "breakfast", text: "Eat breakfast", points: 17),
        ]),
        FeudQuestion(id: "vacation", prompt: "Name something people forget to pack for vacation.", answers: [
            FeudAnswer(id: "charger", text: "Phone charger", points: 35),
            FeudAnswer(id: "toothbrush", text: "Toothbrush", points: 30),
            FeudAnswer(id: "sunscreen", text: "Sunscreen", points: 20),
            FeudAnswer(id: "swimsuit", text: "Swimsuit", points: 15),
        ]),
    ])
}

public struct FamilyFeudRoom: Codable, Hashable, Identifiable, Sendable {
    public var id: FeudRoomID
    public var joinCode: FeudJoinCode
    public var hostID: FeudHostID
    public var board: FeudBoard
    public var players: [FeudPlayer]
    public var teams: [FeudTeam]
    public var phase: FamilyFeudPhase
    public var activeQuestionID: FeudQuestionID?
    public var currentRoundIndex: Int

    public init(
        id: FeudRoomID,
        joinCode: FeudJoinCode,
        hostID: FeudHostID = "feud-host-local",
        board: FeudBoard = .sample,
        players: [FeudPlayer] = [],
        teams: [FeudTeam] = [],
        phase: FamilyFeudPhase = .waiting,
        activeQuestionID: FeudQuestionID? = nil,
        currentRoundIndex: Int = 0
    ) {
        self.id = id
        self.joinCode = joinCode
        self.hostID = hostID
        self.board = board
        self.players = players
        self.teams = teams
        self.phase = phase
        self.activeQuestionID = activeQuestionID
        self.currentRoundIndex = currentRoundIndex
    }

    public var activeQuestion: FeudQuestion? {
        guard let activeQuestionID else { return nil }
        return board.questions.first { $0.id == activeQuestionID }
    }
}
