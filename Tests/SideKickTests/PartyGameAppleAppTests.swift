import XCTest
import SwiftUI
import GameServices
import PartyGameAppCore
import PartyGameAppleApp
import SideKickAppCore

@MainActor
final class PartyGameAppleAppTests: XCTestCase {
    func testRootViewInitializesForRoleRestrictedPlatformShells() {
        _ = PartyGameRootView(platform: .appleTV, service: FakeLocalGameService(), initialRole: .board)
        _ = PartyGameRootView(platform: .appleWatch, service: FakeLocalGameService(), initialRole: .join)
        _ = PartyGameRootView(platform: .iPhone, service: FakeLocalGameService())
    }

    func testBootstrapViewInitializesForRoleRestrictedPlatformShells() {
        _ = PartyGameBootstrapView(platform: .appleTV, initialRole: .board)
        _ = PartyGameBootstrapView(platform: .appleWatch, initialRole: .join)
        _ = PartyGameBootstrapView(platform: .iPhone)
    }

    func testRootViewAcceptsInjectedServiceAtCompositionBoundary() {
        _ = PartyGameRootView(platform: .iPhone, service: FakeLocalGameService())
    }
}
