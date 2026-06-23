import SwiftUI
import GameCore
import PartyGameAppCore
import PartyGameAppleApp
import SideKickAppCore

@main
struct PartyGameIOSMain: App {
    var body: some Scene {
        WindowGroup {
            PartyGameBootstrapView(
                platform: .iPhone,
                initialRole: Self.launchRole,
                launchJoin: Self.launchJoin
            )
        }
    }

    private static var launchRole: GameRole? {
        value(after: "--sidekick-party-game-role").flatMap(GameRole.init(rawValue:))
    }

    private static var launchJoin: PartyGameLaunchJoin? {
        guard
            let code = value(after: "--sidekick-party-game-join-code"),
            let displayName = value(after: "--sidekick-party-game-display-name")
        else {
            return nil
        }
        return PartyGameLaunchJoin(joinCode: JoinCode(rawValue: code), displayName: displayName)
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
