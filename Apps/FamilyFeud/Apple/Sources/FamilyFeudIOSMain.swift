import SwiftUI
import FamilyFeudAppCore
import FamilyFeudAppleApp
import FamilyFeudCore
import SideKickAppCore

@main
struct FamilyFeudIOSMain: App {
    var body: some Scene {
        WindowGroup {
            FamilyFeudBootstrapView(
                platform: .iPhone,
                initialRole: Self.launchRole,
                launchJoin: Self.launchJoin
            )
        }
    }

    private static var launchRole: FamilyFeudRole? {
        value(after: "--sidekick-family-feud-role").flatMap(FamilyFeudRole.init(rawValue:))
    }

    private static var launchJoin: FamilyFeudLaunchJoin? {
        guard
            let code = value(after: "--sidekick-family-feud-join-code"),
            let displayName = value(after: "--sidekick-family-feud-display-name")
        else {
            return nil
        }
        return FamilyFeudLaunchJoin(joinCode: FeudJoinCode(rawValue: code), displayName: displayName)
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
