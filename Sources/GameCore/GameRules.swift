import Foundation

public enum GameRules {
    public static func selectClue(_ clueID: ClueID, in room: GameRoom) throws(GameServiceError) -> GameRoom {
        guard room.phase == .grid else {
            throw .invalidPhase(expected: [.grid], actual: room.phase)
        }
        guard let clue = room.board.clues.first(where: { $0.id == clueID }) else {
            throw .clueNotFound
        }
        guard !clue.isUsed else {
            throw .clueAlreadyUsed
        }

        var next = room
        next.phase = .clueOpen
        next.selectedClueID = clueID
        next.firstBuzzedPlayerID = nil
        return next
    }

    public static func buzz(playerID: PlayerID, in room: GameRoom) throws(GameServiceError) -> GameRoom {
        guard room.phase == .clueOpen else {
            if room.phase == .buzzLocked {
                throw .buzzAlreadyLocked
            }
            throw .invalidPhase(expected: [.clueOpen], actual: room.phase)
        }
        guard let selectedClueID = room.selectedClueID else {
            throw .clueNotFound
        }
        guard let player = room.players.first(where: { $0.id == playerID }) else {
            throw .playerNotFound
        }
        guard !player.lockedOutClueIDs.contains(selectedClueID) else {
            throw .playerLockedOut
        }

        var next = room
        next.firstBuzzedPlayerID = playerID
        next.phase = .buzzLocked
        return next
    }

    public static func markCorrect(in room: GameRoom) throws(GameServiceError) -> GameRoom {
        guard room.phase == .buzzLocked else {
            throw .invalidPhase(expected: [.buzzLocked], actual: room.phase)
        }
        guard let selectedClue = room.selectedClue, let buzzedPlayerID = room.firstBuzzedPlayerID else {
            throw .clueNotFound
        }
        guard let playerIndex = room.players.firstIndex(where: { $0.id == buzzedPlayerID }) else {
            throw .playerNotFound
        }
        guard let clueIndex = room.board.clues.firstIndex(where: { $0.id == selectedClue.id }) else {
            throw .clueNotFound
        }

        var next = room
        next.players[playerIndex].score += selectedClue.value
        next.players.indices.forEach { next.players[$0].lockedOutClueIDs.remove(selectedClue.id) }
        next.board.clues[clueIndex].isUsed = true
        next.phase = next.board.clues.allSatisfy(\.isUsed) ? .finished : .grid
        next.selectedClueID = nil
        next.firstBuzzedPlayerID = nil
        return next
    }

    public static func markIncorrect(in room: GameRoom) throws(GameServiceError) -> GameRoom {
        guard room.phase == .buzzLocked else {
            throw .invalidPhase(expected: [.buzzLocked], actual: room.phase)
        }
        guard let selectedClue = room.selectedClue, let buzzedPlayerID = room.firstBuzzedPlayerID else {
            throw .clueNotFound
        }
        guard let playerIndex = room.players.firstIndex(where: { $0.id == buzzedPlayerID }) else {
            throw .playerNotFound
        }

        var next = room
        next.players[playerIndex].score -= selectedClue.value
        next.players[playerIndex].lockedOutClueIDs.insert(selectedClue.id)
        next.firstBuzzedPlayerID = nil
        if next.players.allSatisfy({ $0.lockedOutClueIDs.contains(selectedClue.id) }) {
            guard let clueIndex = next.board.clues.firstIndex(where: { $0.id == selectedClue.id }) else {
                throw .clueNotFound
            }
            next.players.indices.forEach { next.players[$0].lockedOutClueIDs.remove(selectedClue.id) }
            next.board.clues[clueIndex].isUsed = true
            next.phase = next.board.clues.allSatisfy(\.isUsed) ? .finished : .grid
            next.selectedClueID = nil
        } else {
            next.phase = .clueOpen
        }
        return next
    }
}
