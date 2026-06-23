import SwiftUI
import PartyGameAppleApp
import SideKickAppCore

@main
struct PartyGameMacMain: App {
    var body: some Scene {
        WindowGroup {
            PartyGameBootstrapView(platform: .mac)
        }
    }
}
