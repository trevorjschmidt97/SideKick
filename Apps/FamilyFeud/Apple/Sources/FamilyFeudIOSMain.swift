import SwiftUI
import FamilyFeudAppleApp
import SideKickAppCore

@main
struct FamilyFeudIOSMain: App {
    var body: some Scene {
        WindowGroup {
            FamilyFeudBootstrapView(platform: .iPhone)
        }
    }
}
