import XCTest
import SwiftUI
import GameServices
import JeopardyAppCore
import JeopardyAppleApp
import SideKickAppCore

@MainActor
final class JeopardyAppleAppTests: XCTestCase {
    func testRootViewInitializesForRoleRestrictedPlatformShells() {
        _ = JeopardyRootView(platform: .appleTV, service: FakeLocalGameService(), initialRole: .board)
        _ = JeopardyRootView(platform: .appleWatch, service: FakeLocalGameService(), initialRole: .join)
        _ = JeopardyRootView(platform: .iPhone, service: FakeLocalGameService())
    }

    func testBootstrapViewInitializesForRoleRestrictedPlatformShells() {
        _ = JeopardyBootstrapView(platform: .appleTV, initialRole: .board)
        _ = JeopardyBootstrapView(platform: .appleWatch, initialRole: .join)
        _ = JeopardyBootstrapView(platform: .iPhone)
    }

    func testRootViewAcceptsInjectedServiceAtCompositionBoundary() {
        _ = JeopardyRootView(platform: .iPhone, service: FakeLocalGameService())
    }
}
