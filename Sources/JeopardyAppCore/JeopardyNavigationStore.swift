import Foundation
import Observation
import SideKickAppCore

public struct JeopardyEncodedNavigationState: Codable, Hashable, Sendable {
    public var root: JeopardyRootTree
    public var routePath: JeopardyRoutePath
    public var presentedRoute: JeopardyRoute?

    public init(root: JeopardyRootTree, routePath: JeopardyRoutePath? = nil, presentedRoute: JeopardyRoute? = nil) {
        self.root = root
        self.routePath = routePath ?? JeopardyRoutePath.empty(for: root)
        self.presentedRoute = presentedRoute
    }
}

@MainActor
@Observable
public final class JeopardyNavigationStore {
    public private(set) var state: JeopardyEncodedNavigationState
    private let rolePolicy: JeopardyPlatformRolePolicy
    private let platform: SideKickPlatform

    public init(platform: SideKickPlatform, rolePolicy: JeopardyPlatformRolePolicy = JeopardyPlatformRolePolicy()) {
        self.platform = platform
        self.rolePolicy = rolePolicy
        self.state = JeopardyEncodedNavigationState(root: rolePolicy.defaultRoot(on: platform))
    }

    public func selectRole(_ role: JeopardyRole) {
        guard rolePolicy.canUse(role, on: platform) else {
            return
        }
        switch role {
        case .board:
            state = JeopardyEncodedNavigationState(root: .board, routePath: .board([.board(JeopardyBoardConfig())]))
        case .join:
            state = JeopardyEncodedNavigationState(root: .player, routePath: .player([.join(JeopardyJoinConfig())]))
        }
    }

    public func presentDevSettings() {
        switch state.root {
        case .board, .player:
            state.presentedRoute = .devSettings(JeopardyDevSettingsConfig())
        case .launching, .gameEntry:
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
        let decoded = try JSONDecoder().decode(JeopardyEncodedNavigationState.self, from: data)
        guard rolePolicy.isStateAllowed(decoded, on: platform) else {
            state = JeopardyEncodedNavigationState(root: rolePolicy.defaultRoot(on: platform))
            return
        }
        state = decoded
    }
}

public typealias EncodedNavigationState = JeopardyEncodedNavigationState
public typealias AppNavigationStore = JeopardyNavigationStore
