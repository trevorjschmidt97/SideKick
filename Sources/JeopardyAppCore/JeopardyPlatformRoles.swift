import Foundation
import SideKickAppCore

public enum JeopardyRole: String, Codable, Hashable, Sendable {
    case board
    case join
}

public struct JeopardyPlatformRolePolicy: Sendable {
    public init() {}

    public func allowedRoles(on platform: SideKickPlatform) -> Set<JeopardyRole> {
        switch platform {
        case .appleTV:
            return [.board]
        case .appleWatch:
            return [.join]
        case .iPhone, .iPad, .mac, .android:
            return [.board, .join]
        }
    }

    public func canUse(_ role: JeopardyRole, on platform: SideKickPlatform) -> Bool {
        allowedRoles(on: platform).contains(role)
    }

    public func defaultRoot(on platform: SideKickPlatform) -> JeopardyRootTree {
        switch platform {
        case .appleTV:
            return .board
        case .appleWatch:
            return .player
        case .iPhone, .iPad, .mac, .android:
            return .gameEntry
        }
    }

    public func isStateAllowed(_ state: JeopardyEncodedNavigationState, on platform: SideKickPlatform) -> Bool {
        guard state.presentedRoute.map({ isPresentedRoute($0, allowedIn: state.root) }) ?? true else {
            return false
        }
        switch state.root {
        case .launching, .gameEntry:
            guard platform != .appleTV && platform != .appleWatch else {
                return false
            }
            if case .gameEntry = state.routePath {
                return true
            }
            return state.root == .launching && state.routePath == .launching
        case .board:
            if case .board = state.routePath {
                return canUse(.board, on: platform)
            }
            return false
        case .player:
            if case .player = state.routePath {
                return canUse(.join, on: platform)
            }
            return false
        }
    }

    private func isPresentedRoute(_ route: JeopardyRoute, allowedIn root: JeopardyRootTree) -> Bool {
        switch root {
        case .board, .player:
            if case .devSettings = route { return true }
            return false
        case .launching, .gameEntry:
            return false
        }
    }
}

public typealias GameRole = JeopardyRole
public typealias PlatformRolePolicy = JeopardyPlatformRolePolicy
