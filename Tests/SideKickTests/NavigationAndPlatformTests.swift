import XCTest
@testable import SideKickAppCore

@MainActor
final class NavigationAndPlatformTests: XCTestCase {
    func testPlatformRoleRestrictions() {
        let policy = PlatformRolePolicy()

        XCTAssertEqual(policy.allowedRoles(on: .appleTV), [.board])
        XCTAssertEqual(policy.allowedRoles(on: .appleWatch), [.join])
        XCTAssertEqual(policy.allowedRoles(on: .iPhone), [.board, .join])
        XCTAssertEqual(policy.allowedRoles(on: .iPad), [.board, .join])
        XCTAssertEqual(policy.allowedRoles(on: .mac), [.board, .join])
        XCTAssertEqual(policy.allowedRoles(on: .android), [.board, .join])
    }

    func testRootSelectionForHostVsJoin() {
        let store = AppNavigationStore(platform: .iPhone)

        store.selectRole(.board)
        XCTAssertEqual(store.state.root, .board)
        XCTAssertEqual(store.state.routePath, .board([.board(BoardConfig())]))

        store.selectRole(.join)
        XCTAssertEqual(store.state.root, .player)
        XCTAssertEqual(store.state.routePath, .player([.join(JoinGameConfig())]))
    }

    func testRestrictedPlatformIgnoresUnavailableRole() {
        let tvStore = AppNavigationStore(platform: .appleTV)
        tvStore.selectRole(.join)
        XCTAssertEqual(tvStore.state.root, .board)

        let watchStore = AppNavigationStore(platform: .appleWatch)
        watchStore.selectRole(.board)
        XCTAssertEqual(watchStore.state.root, .player)
    }

    func testRouteConfigCodableRoundTrip() throws {
        let state = EncodedNavigationState(
            root: .player,
            routePath: .player([.join(JoinGameConfig(joinCode: "WXYZ"))]),
            presentedRoute: .devSettings(DevSettingsConfig())
        )

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(EncodedNavigationState.self, from: data)

        XCTAssertEqual(decoded, state)
    }

    func testRoutesAreURLRepresentable() {
        let routes: [GameRoute] = [
            .entry(GameEntryConfig()),
            .board(BoardConfig(roomID: "room-1")),
            .join(JoinGameConfig(joinCode: "ABCD")),
            .player(PlayerGameConfig(joinCode: "ABCD", playerID: "player-1")),
            .devSettings(DevSettingsConfig()),
        ]

        for route in routes {
            XCTAssertEqual(GameRoute(urlPath: route.urlPath), route)
        }
    }

    func testRestoreReappliesPlatformRolePolicy() throws {
        let tvStore = AppNavigationStore(platform: .appleTV)
        let invalidTVState = EncodedNavigationState(root: .player, routePath: .player([.join(JoinGameConfig())]))
        try tvStore.restore(from: JSONEncoder().encode(invalidTVState))
        XCTAssertEqual(tvStore.state.root, .board)

        let watchStore = AppNavigationStore(platform: .appleWatch)
        let invalidWatchState = EncodedNavigationState(root: .board, routePath: .board([.board(BoardConfig())]))
        try watchStore.restore(from: JSONEncoder().encode(invalidWatchState))
        XCTAssertEqual(watchStore.state.root, .player)
    }

    func testRootSpecificRoutesRejectMismatchedRoutePathOnRestore() throws {
        let store = AppNavigationStore(platform: .iPhone)
        let invalidState = EncodedNavigationState(root: .board, routePath: .player([.join(JoinGameConfig())]))

        try store.restore(from: JSONEncoder().encode(invalidState))

        XCTAssertEqual(store.state.root, .gameEntry)
        XCTAssertEqual(store.state.routePath, .gameEntry([.entry(GameEntryConfig())]))
    }

    func testRestoreRejectsPresentedRouteInvalidForRoot() throws {
        let store = AppNavigationStore(platform: .iPhone)
        let invalidState = EncodedNavigationState(
            root: .gameEntry,
            routePath: .gameEntry([.entry(GameEntryConfig())]),
            presentedRoute: .devSettings(DevSettingsConfig())
        )

        try store.restore(from: JSONEncoder().encode(invalidState))

        XCTAssertEqual(store.state.root, .gameEntry)
        XCTAssertNil(store.state.presentedRoute)
    }
}
