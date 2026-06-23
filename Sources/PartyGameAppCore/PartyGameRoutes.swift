import Foundation
import GameCore

public enum PartyGameRootTree: String, Codable, Hashable, Sendable {
    case launching
    case gameEntry
    case board
    case player
}

public enum PartyGameRoute: Codable, Hashable, Sendable {
    case entry(PartyGameEntryConfig)
    case board(PartyGameBoardConfig)
    case join(PartyGameJoinConfig)
    case player(PartyGamePlayerConfig)
    case devSettings(PartyGameDevSettingsConfig)

    public var urlPath: String {
        switch self {
        case .entry:
            return "/entry"
        case .board(let config):
            return "/board" + (config.roomID.map { "/\($0.rawValue)" } ?? "")
        case .join(let config):
            return "/join" + (config.joinCode.map { "/\($0.rawValue)" } ?? "")
        case .player(let config):
            return "/player/\(config.joinCode.rawValue)/\(config.playerID.rawValue)"
        case .devSettings:
            return "/dev-settings"
        }
    }

    public init?(urlPath: String) {
        let parts = urlPath.split(separator: "/").map(String.init)
        guard let first = parts.first else { return nil }
        switch first {
        case "entry":
            self = .entry(PartyGameEntryConfig())
        case "board":
            self = .board(PartyGameBoardConfig(roomID: parts.dropFirst().first.map(RoomID.init(rawValue:))))
        case "join":
            self = .join(PartyGameJoinConfig(joinCode: parts.dropFirst().first.map(JoinCode.init(rawValue:))))
        case "player" where parts.count == 3:
            self = .player(PartyGamePlayerConfig(joinCode: JoinCode(rawValue: parts[1]), playerID: PlayerID(rawValue: parts[2])))
        case "dev-settings":
            self = .devSettings(PartyGameDevSettingsConfig())
        default:
            return nil
        }
    }
}

public enum PartyGameEntryRoute: Codable, Hashable, Sendable {
    case entry(PartyGameEntryConfig)
}

public enum PartyGameBoardRoute: Codable, Hashable, Sendable {
    case board(PartyGameBoardConfig)
    case devSettings(PartyGameDevSettingsConfig)
}

public enum PartyGamePlayerRoute: Codable, Hashable, Sendable {
    case join(PartyGameJoinConfig)
    case player(PartyGamePlayerConfig)
    case devSettings(PartyGameDevSettingsConfig)
}

public enum PartyGameRoutePath: Codable, Hashable, Sendable {
    case launching
    case gameEntry([PartyGameEntryRoute])
    case board([PartyGameBoardRoute])
    case player([PartyGamePlayerRoute])

    public static func empty(for root: PartyGameRootTree) -> PartyGameRoutePath {
        switch root {
        case .launching:
            return .launching
        case .gameEntry:
            return .gameEntry([.entry(PartyGameEntryConfig())])
        case .board:
            return .board([.board(PartyGameBoardConfig())])
        case .player:
            return .player([.join(PartyGameJoinConfig())])
        }
    }
}

public struct PartyGameEntryConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int

    public init(schemaVersion: Int = 1) {
        self.schemaVersion = schemaVersion
    }
}

public struct PartyGameBoardConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var roomID: RoomID?

    public init(schemaVersion: Int = 1, roomID: RoomID? = nil) {
        self.schemaVersion = schemaVersion
        self.roomID = roomID
    }
}

public struct PartyGameJoinConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var joinCode: JoinCode?

    public init(schemaVersion: Int = 1, joinCode: JoinCode? = nil) {
        self.schemaVersion = schemaVersion
        self.joinCode = joinCode
    }
}

public struct PartyGamePlayerConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var joinCode: JoinCode
    public var playerID: PlayerID

    public init(schemaVersion: Int = 1, joinCode: JoinCode, playerID: PlayerID) {
        self.schemaVersion = schemaVersion
        self.joinCode = joinCode
        self.playerID = playerID
    }
}

public struct PartyGameDevSettingsConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int

    public init(schemaVersion: Int = 1) {
        self.schemaVersion = schemaVersion
    }
}

public typealias AppRootTree = PartyGameRootTree
public typealias GameRoute = PartyGameRoute
public typealias GameEntryRoute = PartyGameEntryRoute
public typealias BoardRoute = PartyGameBoardRoute
public typealias PlayerRoute = PartyGamePlayerRoute
public typealias RootRoutePath = PartyGameRoutePath
public typealias GameEntryConfig = PartyGameEntryConfig
public typealias BoardConfig = PartyGameBoardConfig
public typealias JoinGameConfig = PartyGameJoinConfig
public typealias PlayerGameConfig = PartyGamePlayerConfig
public typealias DevSettingsConfig = PartyGameDevSettingsConfig
