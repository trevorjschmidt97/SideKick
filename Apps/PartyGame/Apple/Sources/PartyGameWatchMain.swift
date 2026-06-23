import SwiftUI
import PartyGameAppleApp
import SideKickAppCore

@main
struct PartyGameWatchMain: App {
    var body: some Scene {
        WindowGroup {
            PartyGameBootstrapView(platform: .appleWatch, initialRole: .join)
        }
    }
}
