import Foundation
import GameCore

public enum AppRootTree: String, Codable, Hashable, Sendable {
    case launching
    case gameEntry
    case board
    case player
}

public enum GameRoute: Codable, Hashable, Sendable {
    case entry(GameEntryConfig)
    case board(BoardConfig)
    case join(JoinGameConfig)
    case player(PlayerGameConfig)
    case devSettings(DevSettingsConfig)

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
            self = .entry(GameEntryConfig())
        case "board":
            self = .board(BoardConfig(roomID: parts.dropFirst().first.map(RoomID.init(rawValue:))))
        case "join":
            self = .join(JoinGameConfig(joinCode: parts.dropFirst().first.map(JoinCode.init(rawValue:))))
        case "player" where parts.count == 3:
            self = .player(PlayerGameConfig(joinCode: JoinCode(rawValue: parts[1]), playerID: PlayerID(rawValue: parts[2])))
        case "dev-settings":
            self = .devSettings(DevSettingsConfig())
        default:
            return nil
        }
    }
}

public enum GameEntryRoute: Codable, Hashable, Sendable {
    case entry(GameEntryConfig)
}

public enum BoardRoute: Codable, Hashable, Sendable {
    case board(BoardConfig)
    case devSettings(DevSettingsConfig)
}

public enum PlayerRoute: Codable, Hashable, Sendable {
    case join(JoinGameConfig)
    case player(PlayerGameConfig)
    case devSettings(DevSettingsConfig)
}

public enum RootRoutePath: Codable, Hashable, Sendable {
    case launching
    case gameEntry([GameEntryRoute])
    case board([BoardRoute])
    case player([PlayerRoute])

    public static func empty(for root: AppRootTree) -> RootRoutePath {
        switch root {
        case .launching:
            return .launching
        case .gameEntry:
            return .gameEntry([.entry(GameEntryConfig())])
        case .board:
            return .board([.board(BoardConfig())])
        case .player:
            return .player([.join(JoinGameConfig())])
        }
    }
}

public struct GameEntryConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int

    public init(schemaVersion: Int = 1) {
        self.schemaVersion = schemaVersion
    }
}

public struct BoardConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var roomID: RoomID?

    public init(schemaVersion: Int = 1, roomID: RoomID? = nil) {
        self.schemaVersion = schemaVersion
        self.roomID = roomID
    }
}

public struct JoinGameConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var joinCode: JoinCode?

    public init(schemaVersion: Int = 1, joinCode: JoinCode? = nil) {
        self.schemaVersion = schemaVersion
        self.joinCode = joinCode
    }
}

public struct PlayerGameConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var joinCode: JoinCode
    public var playerID: PlayerID

    public init(schemaVersion: Int = 1, joinCode: JoinCode, playerID: PlayerID) {
        self.schemaVersion = schemaVersion
        self.joinCode = joinCode
        self.playerID = playerID
    }
}

public struct DevSettingsConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int

    public init(schemaVersion: Int = 1) {
        self.schemaVersion = schemaVersion
    }
}
