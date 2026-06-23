import SwiftUI
import JeopardyAppCore
import JeopardyAppleApp
import SideKickAppCore

@main
struct JeopardyTVMain: App {
    var body: some Scene {
        WindowGroup {
            JeopardyBootstrapView(platform: .appleTV, initialRole: .board)
        }
    }
}
