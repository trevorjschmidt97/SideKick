import SwiftUI
import GameModuleShared

public protocol GameEntryModuleRouter: AnyObject {
    @MainActor func showBoard()
    @MainActor func showJoin()
}

@MainActor
@Observable
public final class GameEntryViewModel {
    private let router: any GameEntryModuleRouter

    public init(router: any GameEntryModuleRouter) {
        self.router = router
    }

    public func send(_ event: GameEntryEvent) {
        switch event {
        case .chooseBoard:
            router.showBoard()
        case .chooseJoin:
            router.showJoin()
        }
    }
}

public struct GameEntryModuleView: View {
    @State private var viewModel: GameEntryViewModel

    public init(viewModel: GameEntryViewModel) {
        _viewModel = State(initialValue: viewModel)
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text(GameModuleStrings.title)
                .font(.largeTitle.bold())
            Button(GameModuleStrings.gameBoard) {
                viewModel.send(.chooseBoard)
            }
            .buttonStyle(.borderedProminent)
            Button(GameModuleStrings.joinGame) {
                viewModel.send(.chooseJoin)
            }
            .buttonStyle(.bordered)
        }
    }
}
