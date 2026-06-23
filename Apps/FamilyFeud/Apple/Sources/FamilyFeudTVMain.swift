import SwiftUI
import FamilyFeudAppCore
import FamilyFeudAppleApp
import SideKickAppCore

@main
struct FamilyFeudTVMain: App {
    var body: some Scene {
        WindowGroup {
            FamilyFeudBootstrapView(platform: .appleTV, initialRole: .host)
        }
    }
}
