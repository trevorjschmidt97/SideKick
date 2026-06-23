import SwiftUI
import PartyGameAppleApp
import SideKickAppCore

@main
struct PartyGameIOSMain: App {
    var body: some Scene {
        WindowGroup {
            PartyGameBootstrapView(platform: .iPhone)
        }
    }
}
