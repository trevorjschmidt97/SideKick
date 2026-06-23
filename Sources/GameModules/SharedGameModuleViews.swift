import SwiftUI
import GameCore

public struct OpenClueModuleView: View {
    public let room: GameRoom
    public let showBuzzButton: Bool
    public let showAnswer: Bool
    public let onBuzz: () -> Void

    public init(room: GameRoom, showBuzzButton: Bool, showAnswer: Bool = false, onBuzz: @escaping () -> Void) {
        self.room = room
        self.showBuzzButton = showBuzzButton
        self.showAnswer = showAnswer
        self.onBuzz = onBuzz
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text(room.selectedClue?.prompt ?? "No clue selected")
                .font(.title2.bold())
                .multilineTextAlignment(.center)
            if showAnswer, let answer = room.selectedClue?.answer {
                Text("Answer: \(answer)")
                    .font(.headline)
            }
            if showBuzzButton {
                Button(GameModuleStrings.buzz, action: onBuzz)
                    .buttonStyle(.borderedProminent)
            }
        }
    }
}
