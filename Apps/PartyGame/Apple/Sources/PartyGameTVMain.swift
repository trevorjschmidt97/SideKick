import SwiftUI
import PartyGameAppleApp
import SideKickAppCore

@main
struct PartyGameTVMain: App {
    var body: some Scene {
        WindowGroup {
            PartyGameBootstrapView(platform: .appleTV, initialRole: .board)
        }
    }
}
