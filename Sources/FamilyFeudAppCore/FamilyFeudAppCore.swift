import Foundation
import FamilyFeudCore
import Observation
import SideKickAppCore

public enum FamilyFeudRole: String, Codable, Hashable, Sendable {
    case host
    case join
}

public enum FamilyFeudRootTree: String, Codable, Hashable, Sendable {
    case launching
    case entry
    case host
    case player
}

public enum FamilyFeudRoute: Codable, Hashable, Sendable {
    case entry(FamilyFeudEntryConfig)
    case host(FamilyFeudHostConfig)
    case join(FamilyFeudJoinConfig)
    case player(FamilyFeudPlayerConfig)
    case devSettings(FamilyFeudDevSettingsConfig)
}

public enum FamilyFeudRoutePath: Codable, Hashable, Sendable {
    case launching
    case entry([FamilyFeudRoute])
    case host([FamilyFeudRoute])
    case player([FamilyFeudRoute])

    public static func empty(for root: FamilyFeudRootTree) -> FamilyFeudRoutePath {
        switch root {
        case .launching:
            return .launching
        case .entry:
            return .entry([.entry(FamilyFeudEntryConfig())])
        case .host:
            return .host([.host(FamilyFeudHostConfig())])
        case .player:
            return .player([.join(FamilyFeudJoinConfig())])
        }
    }
}

public struct FamilyFeudEntryConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public init(schemaVersion: Int = 1) { self.schemaVersion = schemaVersion }
}

public struct FamilyFeudHostConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var roomID: FeudRoomID?
    public init(schemaVersion: Int = 1, roomID: FeudRoomID? = nil) {
        self.schemaVersion = schemaVersion
        self.roomID = roomID
    }
}

public struct FamilyFeudJoinConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var joinCode: FeudJoinCode?
    public init(schemaVersion: Int = 1, joinCode: FeudJoinCode? = nil) {
        self.schemaVersion = schemaVersion
        self.joinCode = joinCode
    }
}

public struct FamilyFeudPlayerConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public var joinCode: FeudJoinCode
    public var playerID: FeudPlayerID
    public init(schemaVersion: Int = 1, joinCode: FeudJoinCode, playerID: FeudPlayerID) {
        self.schemaVersion = schemaVersion
        self.joinCode = joinCode
        self.playerID = playerID
    }
}

public struct FamilyFeudDevSettingsConfig: Codable, Hashable, Sendable {
    public var schemaVersion: Int
    public init(schemaVersion: Int = 1) { self.schemaVersion = schemaVersion }
}

public struct FamilyFeudPlatformRolePolicy: Sendable {
    public init() {}

    public func allowedRoles(on platform: SideKickPlatform) -> Set<FamilyFeudRole> {
        switch platform {
        case .appleTV:
            return [.host]
        case .appleWatch:
            return [.join]
        case .iPhone, .iPad, .mac, .android:
            return [.host, .join]
        }
    }

    public func canUse(_ role: FamilyFeudRole, on platform: SideKickPlatform) -> Bool {
        allowedRoles(on: platform).contains(role)
    }

    public func defaultRoot(on platform: SideKickPlatform) -> FamilyFeudRootTree {
        switch platform {
        case .appleTV:
            return .host
        case .appleWatch:
            return .player
        case .iPhone, .iPad, .mac, .android:
            return .entry
        }
    }

    public func isStateAllowed(_ state: FamilyFeudEncodedNavigationState, on platform: SideKickPlatform) -> Bool {
        guard state.presentedRoute.map({ isPresentedRoute($0, allowedIn: state.root) }) ?? true else {
            return false
        }
        switch state.root {
        case .launching, .entry:
            guard platform != .appleTV && platform != .appleWatch else { return false }
            if case .entry = state.routePath { return true }
            return state.root == .launching && state.routePath == .launching
        case .host:
            if case .host = state.routePath { return canUse(.host, on: platform) }
            return false
        case .player:
            if case .player = state.routePath { return canUse(.join, on: platform) }
            return false
        }
    }

    private func isPresentedRoute(_ route: FamilyFeudRoute, allowedIn root: FamilyFeudRootTree) -> Bool {
        switch root {
        case .host, .player:
            if case .devSettings = route { return true }
            return false
        case .launching, .entry:
            return false
        }
    }
}

public struct FamilyFeudEncodedNavigationState: Codable, Hashable, Sendable {
    public var root: FamilyFeudRootTree
    public var routePath: FamilyFeudRoutePath
    public var presentedRoute: FamilyFeudRoute?

    public init(root: FamilyFeudRootTree, routePath: FamilyFeudRoutePath? = nil, presentedRoute: FamilyFeudRoute? = nil) {
        self.root = root
        self.routePath = routePath ?? FamilyFeudRoutePath.empty(for: root)
        self.presentedRoute = presentedRoute
    }
}

@MainActor
@Observable
public final class FamilyFeudNavigationStore {
    public private(set) var state: FamilyFeudEncodedNavigationState
    private let rolePolicy: FamilyFeudPlatformRolePolicy
    private let platform: SideKickPlatform

    public init(platform: SideKickPlatform, rolePolicy: FamilyFeudPlatformRolePolicy = FamilyFeudPlatformRolePolicy()) {
        self.platform = platform
        self.rolePolicy = rolePolicy
        self.state = FamilyFeudEncodedNavigationState(root: rolePolicy.defaultRoot(on: platform))
    }

    public func selectRole(_ role: FamilyFeudRole) {
        guard rolePolicy.canUse(role, on: platform) else { return }
        switch role {
        case .host:
            state = FamilyFeudEncodedNavigationState(root: .host, routePath: .host([.host(FamilyFeudHostConfig())]))
        case .join:
            state = FamilyFeudEncodedNavigationState(root: .player, routePath: .player([.join(FamilyFeudJoinConfig())]))
        }
    }

    public func presentDevSettings() {
        switch state.root {
        case .host, .player:
            state.presentedRoute = .devSettings(FamilyFeudDevSettingsConfig())
        case .launching, .entry:
            break
        }
    }

    public func dismissPresentedRoute() {
        state.presentedRoute = nil
    }

    public func encode() throws -> Data {
        try JSONEncoder().encode(state)
    }

    public func restore(from data: Data) throws {
        let decoded = try JSONDecoder().decode(FamilyFeudEncodedNavigationState.self, from: data)
        guard rolePolicy.isStateAllowed(decoded, on: platform) else {
            state = FamilyFeudEncodedNavigationState(root: rolePolicy.defaultRoot(on: platform))
            return
        }
        state = decoded
    }
}
