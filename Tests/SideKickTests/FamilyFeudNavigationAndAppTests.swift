import XCTest
import FamilyFeudAppCore
import FamilyFeudAppleApp
import FamilyFeudServices
import SideKickAppCore

@MainActor
final class FamilyFeudNavigationAndAppTests: XCTestCase {
    func testFamilyFeudPlatformRoleRestrictions() {
        let policy = FamilyFeudPlatformRolePolicy()

        XCTAssertEqual(policy.allowedRoles(on: .appleTV), [.host])
        XCTAssertEqual(policy.allowedRoles(on: .appleWatch), [.join])
        XCTAssertEqual(policy.allowedRoles(on: .iPhone), [.host, .join])
    }

    func testFamilyFeudRootSelection() {
        let store = FamilyFeudNavigationStore(platform: .iPhone)

        store.selectRole(.host)
        XCTAssertEqual(store.state.root, .host)

        store.selectRole(.join)
        XCTAssertEqual(store.state.root, .player)
    }

    func testFamilyFeudRootViewInitializesForRoleRestrictedPlatforms() {
        _ = FamilyFeudRootView(platform: .appleTV, service: FakeLocalFamilyFeudService(), initialRole: .host)
        _ = FamilyFeudRootView(platform: .appleWatch, service: FakeLocalFamilyFeudService(), initialRole: .join)
        _ = FamilyFeudRootView(platform: .iPhone, service: FakeLocalFamilyFeudService())
    }
}
