import SwiftUI
import FamilyFeudAppCore
import FamilyFeudAppleApp
import SideKickAppCore

@main
struct FamilyFeudWatchMain: App {
    var body: some Scene {
        WindowGroup {
            FamilyFeudBootstrapView(platform: .appleWatch, initialRole: .join)
        }
    }
}
