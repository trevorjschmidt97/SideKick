import Foundation
import GameCore
import Observation

public struct EncodedNavigationState: Codable, Hashable, Sendable {
    public var root: AppRootTree
    public var routePath: RootRoutePath
    public var presentedRoute: GameRoute?

    public init(root: AppRootTree, routePath: RootRoutePath? = nil, presentedRoute: GameRoute? = nil) {
        self.root = root
        self.routePath = routePath ?? RootRoutePath.empty(for: root)
        self.presentedRoute = presentedRoute
    }
}

@MainActor
@Observable
public final class AppNavigationStore {
    public private(set) var state: EncodedNavigationState
    private let rolePolicy: PlatformRolePolicy
    private let platform: SideKickPlatform

    public init(platform: SideKickPlatform, rolePolicy: PlatformRolePolicy = PlatformRolePolicy()) {
        self.platform = platform
        self.rolePolicy = rolePolicy
        self.state = EncodedNavigationState(root: rolePolicy.defaultRoot(on: platform))
    }

    public func selectRole(_ role: GameRole) {
        guard rolePolicy.canUse(role, on: platform) else {
            return
        }
        switch role {
        case .board:
            state = EncodedNavigationState(root: .board, routePath: .board([.board(BoardConfig())]))
        case .join:
            state = EncodedNavigationState(root: .player, routePath: .player([.join(JoinGameConfig())]))
        }
    }

    public func presentDevSettings() {
        switch state.root {
        case .board, .player:
            state.presentedRoute = .devSettings(DevSettingsConfig())
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
        let decoded = try JSONDecoder().decode(EncodedNavigationState.self, from: data)
        guard rolePolicy.isStateAllowed(decoded, on: platform) else {
            state = EncodedNavigationState(root: rolePolicy.defaultRoot(on: platform))
            return
        }
        state = decoded
    }
}
