import SwiftUI
import FamilyFeudAppleApp
import SideKickAppCore

@main
struct FamilyFeudMacMain: App {
    var body: some Scene {
        WindowGroup {
            FamilyFeudBootstrapView(platform: .mac)
        }
    }
}
