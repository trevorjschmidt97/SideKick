import SwiftUI
import JeopardyAppleApp
import SideKickAppCore

@main
struct JeopardyMacMain: App {
    var body: some Scene {
        WindowGroup {
            JeopardyBootstrapView(platform: .mac)
        }
    }
}
