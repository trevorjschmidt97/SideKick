import SwiftUI
import JeopardyAppCore
import JeopardyAppleApp
import SideKickAppCore

@main
struct JeopardyWatchMain: App {
    var body: some Scene {
        WindowGroup {
            JeopardyBootstrapView(platform: .appleWatch, initialRole: .join)
        }
    }
}
