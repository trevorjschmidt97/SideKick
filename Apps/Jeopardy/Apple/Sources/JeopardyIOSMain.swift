import SwiftUI
import GameCore
import JeopardyAppCore
import JeopardyAppleApp
import SideKickAppCore

@main
struct JeopardyIOSMain: App {
    var body: some Scene {
        WindowGroup {
            JeopardyBootstrapView(
                platform: .iPhone,
                initialRole: Self.launchRole,
                launchJoin: Self.launchJoin
            )
        }
    }

    private static var launchRole: GameRole? {
        value(after: "--sidekick-jeopardy-role").flatMap(GameRole.init(rawValue:))
    }

    private static var launchJoin: JeopardyLaunchJoin? {
        guard
            let code = value(after: "--sidekick-jeopardy-join-code"),
            let displayName = value(after: "--sidekick-jeopardy-display-name")
        else {
            return nil
        }
        return JeopardyLaunchJoin(joinCode: JoinCode(rawValue: code), displayName: displayName)
    }

    private static func value(after flag: String) -> String? {
        let arguments = ProcessInfo.processInfo.arguments
        guard let index = arguments.firstIndex(of: flag) else {
            return nil
        }
        let valueIndex = arguments.index(after: index)
        return arguments.indices.contains(valueIndex) ? arguments[valueIndex] : nil
    }
}
