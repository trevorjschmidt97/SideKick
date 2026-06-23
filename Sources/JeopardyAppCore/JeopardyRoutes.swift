import Foundation
import GameCore

public enum JeopardyRootTree: String, Codable, Hashable, Sendable {
    case launching
    case gameEntry
    case board
    case player
}

public enum JeopardyRoute: Codable, Hashable, Sendable {
    case entry(JeopardyEntryConfig)
    case board(JeopardyBoardConfig)
    case join(JeopardyJoinConfig)
    case player(JeopardyPlayerConfig)
    case devSettings(JeopardyDevSettingsConfig)

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
            self = .entry(JeopardyEntryConfig())
        case "board":
            self = .board(JeopardyBoardConfig(roomID: parts.dropFirst().first.map(RoomID.init(rawValue:))))
        case "join":
            self = .join(JeopardyJoinConfig(joinCode: parts.dropFirst().first.map(JoinCode.init(rawValue:))))
        case "player" where parts.count == 3:
            self = .player(JeopardyPlayerConfig(joinCode: JoinCode(rawValue: parts[1]), playerID: PlayerID(rawValue: parts[2])))
        case "dev-settings":
            self = .devSettings(JeopardyDevSettingsConfig())
        default:
            return nil
        }
    }
}

public enum JeopardyEntryRoute: Codable, Hashable, Sendable {
    case entry(JeopardyEntryConfig)
}

public enum JeopardyBoardRoute: Codable, Hashable, Sendable {
    case board(JeopardyBoardConfig)
    case devSettings(JeopardyDevSettingsConfig)
}

public enum JeopardyPlayerRoute: Codable, Hashable, Sendable {
    case join(JeopardyJoinConfig)
    case player(JeopardyPlayerConfig)
    case devSettings(JeopardyDevSettingsConfig)
}

public enum JeopardyRoutePath: Codable, Hashable, Sendable {
    case launching
    case gameEntry([JeopardyEntryRoute])
    case board([JeopardyBoardRoute])
    case player([JeopardyPlayerRoute])

    public static func empty(for root: JeopardyRootTree) -> JeopardyRoutePath {
        switch root {
        case .launching:
            return .launching
        case .gameEntry:
            return .gameEntry([.entry(JeopardyEntryConfig())])
        case .board:
            return .board([.board(JeopardyBoardConfig())])
        case .player:
            return .player([.join(JeopardyJoinConfig())])
        }
    }
}

public struct JeopardyEntryConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int

    public init(schemaVersion: Int = 1) {
        self.schemaVersion = schemaVersion
    }
}

public struct JeopardyBoardConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var roomID: RoomID?

    public init(schemaVersion: Int = 1, roomID: RoomID? = nil) {
        self.schemaVersion = schemaVersion
        self.roomID = roomID
    }
}

public struct JeopardyJoinConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var joinCode: JoinCode?

    public init(schemaVersion: Int = 1, joinCode: JoinCode? = nil) {
        self.schemaVersion = schemaVersion
        self.joinCode = joinCode
    }
}

public struct JeopardyPlayerConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var joinCode: JoinCode
    public var playerID: PlayerID

    public init(schemaVersion: Int = 1, joinCode: JoinCode, playerID: PlayerID) {
        self.schemaVersion = schemaVersion
        self.joinCode = joinCode
        self.playerID = playerID
    }
}

public struct JeopardyDevSettingsConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int

    public init(schemaVersion: Int = 1) {
        self.schemaVersion = schemaVersion
    }
}

public typealias AppRootTree = JeopardyRootTree
public typealias GameRoute = JeopardyRoute
public typealias GameEntryRoute = JeopardyEntryRoute
public typealias BoardRoute = JeopardyBoardRoute
public typealias PlayerRoute = JeopardyPlayerRoute
public typealias RootRoutePath = JeopardyRoutePath
public typealias GameEntryConfig = JeopardyEntryConfig
public typealias BoardConfig = JeopardyBoardConfig
public typealias JoinGameConfig = JeopardyJoinConfig
public typealias PlayerGameConfig = JeopardyPlayerConfig
public typealias DevSettingsConfig = JeopardyDevSettingsConfig
