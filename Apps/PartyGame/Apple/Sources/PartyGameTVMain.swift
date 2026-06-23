import SwiftUI
import PartyGameAppCore
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
