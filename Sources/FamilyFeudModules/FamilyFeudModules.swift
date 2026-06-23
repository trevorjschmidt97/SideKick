import SwiftUI
import Observation
import FamilyFeudCore

public enum FamilyFeudEntryEvent: Sendable {
    case host
    case join
}

public protocol FamilyFeudEntryRouter: AnyObject {
    @MainActor func showHost()
    @MainActor func showJoin()
}

@MainActor
@Observable
public final class FamilyFeudEntryViewModel {
    private let router: any FamilyFeudEntryRouter

    public init(router: any FamilyFeudEntryRouter) {
        self.router = router
    }

    public func send(_ event: FamilyFeudEntryEvent) {
        switch event {
        case .host:
            router.showHost()
        case .join:
            router.showJoin()
        }
    }
}

public struct FamilyFeudEntryModuleView: View {
    @Bindable private var viewModel: FamilyFeudEntryViewModel

    public init(viewModel: FamilyFeudEntryViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(spacing: 16) {
            Text("Family Feud")
                .font(.largeTitle.bold())
            Button("Host Game") {
                viewModel.send(.host)
            }
            .buttonStyle(.borderedProminent)
            Button("Join Game") {
                viewModel.send(.join)
            }
            .buttonStyle(.bordered)
        }
    }
}

public enum FamilyFeudHostEvent: Sendable {
    case createRoom
    case startGame
    case reveal(FeudAnswerID, FeudTeamID)
    case endRound
    case advance
    case refresh
    case showDevSettings
}

public protocol FamilyFeudHostInteractor: AnyObject {
    @MainActor func createRoom() async throws(FamilyFeudServiceError) -> FamilyFeudSnapshot
    @MainActor func startGame() async throws(FamilyFeudServiceError) -> FamilyFeudSnapshot
    @MainActor func reveal(answerID: FeudAnswerID, teamID: FeudTeamID) async throws(FamilyFeudServiceError) -> FamilyFeudSnapshot
    @MainActor func endRound() async throws(FamilyFeudServiceError) -> FamilyFeudSnapshot
    @MainActor func advance() async throws(FamilyFeudServiceError) -> FamilyFeudSnapshot
    @MainActor func refresh() async throws(FamilyFeudServiceError) -> FamilyFeudSnapshot
}

public protocol FamilyFeudModuleRouter: AnyObject {
    @MainActor func showDevSettings()
}

public struct FamilyFeudHostState: Codable, Hashable, Sendable {
    public var room: FamilyFeudRoom?
    public var lastError: FamilyFeudServiceError?

    public init(room: FamilyFeudRoom? = nil, lastError: FamilyFeudServiceError? = nil) {
        self.room = room
        self.lastError = lastError
    }
}

@MainActor
@Observable
public final class FamilyFeudHostViewModel {
    public private(set) var state: FamilyFeudHostState
    private let interactor: any FamilyFeudHostInteractor
    private let router: any FamilyFeudModuleRouter

    public init(
        snapshot: FamilyFeudSnapshot = FamilyFeudSnapshot(),
        interactor: any FamilyFeudHostInteractor,
        router: any FamilyFeudModuleRouter
    ) {
        self.state = FamilyFeudHostState(room: snapshot.room)
        self.interactor = interactor
        self.router = router
    }

    public func send(_ event: FamilyFeudHostEvent) async {
        do {
            switch event {
            case .createRoom:
                state = FamilyFeudHostState(room: try await interactor.createRoom().room)
            case .startGame:
                state = FamilyFeudHostState(room: try await interactor.startGame().room)
            case .reveal(let answerID, let teamID):
                state = FamilyFeudHostState(room: try await interactor.reveal(answerID: answerID, teamID: teamID).room)
            case .endRound:
                state = FamilyFeudHostState(room: try await interactor.endRound().room)
            case .advance:
                state = FamilyFeudHostState(room: try await interactor.advance().room)
            case .refresh:
                state = FamilyFeudHostState(room: try await interactor.refresh().room)
            case .showDevSettings:
                router.showDevSettings()
            }
        } catch {
            state.lastError = error
        }
    }
}

public struct FamilyFeudHostModuleView: View {
    @Bindable private var viewModel: FamilyFeudHostViewModel

    public init(viewModel: FamilyFeudHostViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                if let room = viewModel.state.room {
                    lobby(room)
                    board(room)
                } else {
                    Button("Create Room") {
                        Task { await viewModel.send(.createRoom) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var header: some View {
        HStack {
            Text("Family Feud Host")
                .font(.title.bold())
            Spacer()
            Button("Dev") {
                Task { await viewModel.send(.showDevSettings) }
            }
        }
    }

    private func lobby(_ room: FamilyFeudRoom) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Code \(room.joinCode.rawValue)").font(.headline)
            Text("Players: \(room.players.map(\.displayName).joined(separator: ", "))")
            HStack {
                Button("Start") { Task { await viewModel.send(.startGame) } }
                    .disabled(room.players.count < 2 || room.phase != .waiting)
                Button("Refresh") { Task { await viewModel.send(.refresh) } }
            }
        }
    }

    private func board(_ room: FamilyFeudRoom) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ForEach(room.teams) { team in
                    VStack(alignment: .leading) {
                        Text(team.name).bold()
                        Text("\(team.score) pts")
                        Text(team.playerIDs.compactMap { id in room.players.first(where: { $0.id == id })?.displayName }.joined(separator: ", "))
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            if let question = room.activeQuestion {
                Text(question.prompt).font(.title3.bold())
                ForEach(question.answers) { answer in
                    HStack {
                        Text(answer.isRevealed ? "\(answer.text) - \(answer.points)" : "Hidden answer")
                        Spacer()
                        ForEach(room.teams) { team in
                            Button(team.name) {
                                Task { await viewModel.send(.reveal(answer.id, team.id)) }
                            }
                            .disabled(answer.isRevealed)
                        }
                    }
                }
            }
            HStack {
                Button("End Round") { Task { await viewModel.send(.endRound) } }
                    .disabled(room.phase != .questionOpen)
                Button("Next Question") { Task { await viewModel.send(.advance) } }
                    .disabled(room.phase != .roundComplete)
            }
        }
    }
}

public enum FamilyFeudJoinEvent: Sendable {
    case updateJoinCode(String)
    case updateDisplayName(String)
    case join
    case refresh
    case showDevSettings
}

public protocol FamilyFeudJoinInteractor: AnyObject {
    @MainActor func join(joinCode: FeudJoinCode, displayName: String) async throws(FamilyFeudServiceError) -> FamilyFeudSnapshot
    @MainActor func refresh() async throws(FamilyFeudServiceError) -> FamilyFeudSnapshot
}

public struct FamilyFeudPlayerState: Codable, Hashable, Sendable {
    public var joinCode: String
    public var displayName: String
    public var room: FamilyFeudRoom?
    public var localPlayerID: FeudPlayerID?
    public var lastError: FamilyFeudServiceError?

    public init(joinCode: String = "", displayName: String = "", room: FamilyFeudRoom? = nil, localPlayerID: FeudPlayerID? = nil, lastError: FamilyFeudServiceError? = nil) {
        self.joinCode = joinCode
        self.displayName = displayName
        self.room = room
        self.localPlayerID = localPlayerID
        self.lastError = lastError
    }
}

@MainActor
@Observable
public final class FamilyFeudJoinViewModel {
    public private(set) var state: FamilyFeudPlayerState
    private let interactor: any FamilyFeudJoinInteractor
    private let router: any FamilyFeudModuleRouter

    public init(
        snapshot: FamilyFeudSnapshot = FamilyFeudSnapshot(),
        interactor: any FamilyFeudJoinInteractor,
        router: any FamilyFeudModuleRouter
    ) {
        self.state = FamilyFeudPlayerState(room: snapshot.room, localPlayerID: snapshot.localPlayerID)
        self.interactor = interactor
        self.router = router
    }

    public func send(_ event: FamilyFeudJoinEvent) async {
        do {
            switch event {
            case .updateJoinCode(let value):
                state.joinCode = FeudJoinCode(rawValue: value).rawValue
            case .updateDisplayName(let value):
                state.displayName = value
            case .join:
                let snapshot = try await interactor.join(joinCode: FeudJoinCode(rawValue: state.joinCode), displayName: state.displayName)
                state.room = snapshot.room
                state.localPlayerID = snapshot.localPlayerID
                state.lastError = nil
            case .refresh:
                let snapshot = try await interactor.refresh()
                state.room = snapshot.room
                state.localPlayerID = snapshot.localPlayerID
                state.lastError = nil
            case .showDevSettings:
                router.showDevSettings()
            }
        } catch {
            state.lastError = error
        }
    }
}

public struct FamilyFeudJoinModuleView: View {
    @Bindable private var viewModel: FamilyFeudJoinViewModel

    public init(viewModel: FamilyFeudJoinViewModel) {
        self.viewModel = viewModel
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Join Family Feud").font(.title.bold())
            if let room = viewModel.state.room {
                playerRoom(room)
            } else {
                TextField("Join code", text: Binding(
                    get: { viewModel.state.joinCode },
                    set: { value in Task { await viewModel.send(.updateJoinCode(value)) } }
                ))
                TextField("Display name", text: Binding(
                    get: { viewModel.state.displayName },
                    set: { value in Task { await viewModel.send(.updateDisplayName(value)) } }
                ))
                Button("Join") {
                    Task { await viewModel.send(.join) }
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private func playerRoom(_ room: FamilyFeudRoom) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Room \(room.joinCode.rawValue)")
            if let playerID = viewModel.state.localPlayerID,
               let player = room.players.first(where: { $0.id == playerID }),
               let team = room.teams.first(where: { $0.id == player.teamID }) {
                Text("Your team: \(team.name)").font(.headline)
            } else {
                Text("Waiting for teams")
            }
            if let question = room.activeQuestion {
                Text(question.prompt).font(.title3.bold())
                ForEach(question.answers) { answer in
                    Text(answer.isRevealed ? "\(answer.text) - \(answer.points)" : "Hidden answer")
                }
            }
            Button("Refresh") {
                Task { await viewModel.send(.refresh) }
            }
        }
    }
}
