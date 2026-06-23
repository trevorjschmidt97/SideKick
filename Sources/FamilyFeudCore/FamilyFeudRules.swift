import Foundation

public enum FamilyFeudRules {
    public static func startGame(in room: FamilyFeudRoom) throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        guard room.phase == .waiting else {
            throw .invalidPhase(expected: [.waiting], actual: room.phase)
        }
        guard room.players.count >= 2 else {
            throw .notEnoughPlayers
        }
        guard let firstQuestion = room.board.questions.first else {
            throw .questionNotFound
        }
        var next = try assignTeams(in: room)
        next.phase = .questionOpen
        next.currentRoundIndex = 0
        next.activeQuestionID = firstQuestion.id
        return next
    }

    public static func assignTeams(in room: FamilyFeudRoom) throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        guard room.players.count >= 2 else {
            throw .notEnoughPlayers
        }
        let leftID = FeudTeamID(rawValue: "team-a")
        let rightID = FeudTeamID(rawValue: "team-b")
        var players: [FeudPlayer] = []
        var leftPlayers: [FeudPlayerID] = []
        var rightPlayers: [FeudPlayerID] = []
        for (index, player) in room.players.enumerated() {
            var nextPlayer = player
            if index.isMultiple(of: 2) {
                nextPlayer.teamID = leftID
                leftPlayers.append(player.id)
            } else {
                nextPlayer.teamID = rightID
                rightPlayers.append(player.id)
            }
            players.append(nextPlayer)
        }
        var next = room
        next.players = players
        next.teams = [
            FeudTeam(id: leftID, name: "Team A", playerIDs: leftPlayers, score: room.teams.first(where: { $0.id == leftID })?.score ?? 0),
            FeudTeam(id: rightID, name: "Team B", playerIDs: rightPlayers, score: room.teams.first(where: { $0.id == rightID })?.score ?? 0),
        ]
        return next
    }

    public static func revealAnswer(
        _ answerID: FeudAnswerID,
        for teamID: FeudTeamID,
        in room: FamilyFeudRoom
    ) throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        guard room.phase == .questionOpen else {
            throw .invalidPhase(expected: [.questionOpen], actual: room.phase)
        }
        guard room.teams.contains(where: { $0.id == teamID }) else {
            throw .teamNotFound
        }
        guard let questionID = room.activeQuestionID,
              let questionIndex = room.board.questions.firstIndex(where: { $0.id == questionID }) else {
            throw .questionNotFound
        }
        guard let answerIndex = room.board.questions[questionIndex].answers.firstIndex(where: { $0.id == answerID }) else {
            throw .answerNotFound
        }
        guard !room.board.questions[questionIndex].answers[answerIndex].isRevealed else {
            throw .answerAlreadyRevealed
        }

        var next = room
        let points = next.board.questions[questionIndex].answers[answerIndex].points
        next.board.questions[questionIndex].answers[answerIndex].isRevealed = true
        next.board.questions[questionIndex].answers[answerIndex].revealedByTeamID = teamID
        guard let teamIndex = next.teams.firstIndex(where: { $0.id == teamID }) else {
            throw .teamNotFound
        }
        next.teams[teamIndex].score += points
        if next.board.questions[questionIndex].answers.allSatisfy(\.isRevealed) {
            next.phase = .roundComplete
        }
        return next
    }

    public static func endRound(in room: FamilyFeudRoom) throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        guard room.phase == .questionOpen else {
            throw .invalidPhase(expected: [.questionOpen], actual: room.phase)
        }
        var next = room
        next.phase = .roundComplete
        return next
    }

    public static func advanceToNextQuestion(in room: FamilyFeudRoom) throws(FamilyFeudServiceError) -> FamilyFeudRoom {
        guard room.phase == .roundComplete else {
            throw .invalidPhase(expected: [.roundComplete], actual: room.phase)
        }
        let nextIndex = room.currentRoundIndex + 1
        guard nextIndex < room.board.questions.count else {
            var finished = room
            finished.phase = .finished
            finished.activeQuestionID = nil
            return finished
        }
        var next = room
        next.currentRoundIndex = nextIndex
        next.activeQuestionID = next.board.questions[nextIndex].id
        next.phase = .questionOpen
        return next
    }
}
