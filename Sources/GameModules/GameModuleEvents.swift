import GameCore

public enum GameEntryEvent: Hashable, Sendable {
    case chooseBoard
    case chooseJoin
}

public enum BoardModuleEvent: Hashable, Sendable {
    case createRoom
    case startGame
    case selectClue(ClueID)
    case markCorrect
    case markIncorrect
    case refresh
}

public enum JoinModuleEvent: Hashable, Sendable {
    case join(joinCode: JoinCode, displayName: String)
    case buzz
    case refresh
}
