import Foundation
import Observation
import SideKickAppCore

public struct PartyGameEncodedNavigationState: Codable, Hashable, Sendable {
    public var root: PartyGameRootTree
    public var routePath: PartyGameRoutePath
    public var presentedRoute: PartyGameRoute?

    public init(root: PartyGameRootTree, routePath: PartyGameRoutePath? = nil, presentedRoute: PartyGameRoute? = nil) {
        self.root = root
        self.routePath = routePath ?? PartyGameRoutePath.empty(for: root)
        self.presentedRoute = presentedRoute
    }
}

@MainActor
@Observable
public final class PartyGameNavigationStore {
    public private(set) var state: PartyGameEncodedNavigationState
    private let rolePolicy: PartyGamePlatformRolePolicy
    private let platform: SideKickPlatform

    public init(platform: SideKickPlatform, rolePolicy: PartyGamePlatformRolePolicy = PartyGamePlatformRolePolicy()) {
        self.platform = platform
        self.rolePolicy = rolePolicy
        self.state = PartyGameEncodedNavigationState(root: rolePolicy.defaultRoot(on: platform))
    }

    public func selectRole(_ role: PartyGameRole) {
        guard rolePolicy.canUse(role, on: platform) else {
            return
        }
        switch role {
        case .board:
            state = PartyGameEncodedNavigationState(root: .board, routePath: .board([.board(PartyGameBoardConfig())]))
        case .join:
            state = PartyGameEncodedNavigationState(root: .player, routePath: .player([.join(PartyGameJoinConfig())]))
        }
    }

    public func presentDevSettings() {
        switch state.root {
        case .board, .player:
            state.presentedRoute = .devSettings(PartyGameDevSettingsConfig())
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
        let decoded = try JSONDecoder().decode(PartyGameEncodedNavigationState.self, from: data)
        guard rolePolicy.isStateAllowed(decoded, on: platform) else {
            state = PartyGameEncodedNavigationState(root: rolePolicy.defaultRoot(on: platform))
            return
        }
        state = decoded
    }
}

public typealias EncodedNavigationState = PartyGameEncodedNavigationState
public typealias AppNavigationStore = PartyGameNavigationStore
