import XCTest
import FirebaseGameService
import GameCore

final class FirebaseBoundaryTests: XCTestCase {
    func testFirebaseServiceUsesGameCoreBoundaryTypesOnly() async {
        let service: any GameService = FirebaseGameService(configuration: FirebaseGameServiceConfiguration())

        do {
            _ = try await service.createRoom(board: .sample)
            XCTFail("Expected missing Firebase configuration to fail")
        } catch {
            XCTAssertEqual(error, .backendUnavailable("Firebase credentials are absent; use FakeLocalGameService for local development and tests."))
        }
    }

    func testFirebaseServiceRequiresPrincipalWhenStoreIsConfigured() async {
        let service: any GameService = FirebaseGameService(
            configuration: FirebaseGameServiceConfiguration(usesEmulator: true),
            store: InMemoryFirebaseGameDocumentStore()
        )

        do {
            _ = try await service.createRoom(board: .sample)
            XCTFail("Expected missing principal to fail")
        } catch {
            XCTAssertEqual(error, .backendUnavailable("Firebase authenticated principal is required for game mutations."))
        }
    }

    func testFirebaseServicePersistsRoomFlowThroughDocumentStore() async throws {
        let documentStore = InMemoryFirebaseGameDocumentStore()
        let hostService: any GameService = FirebaseGameService(
            configuration: FirebaseGameServiceConfiguration(emulatorHost: "localhost:8080", usesEmulator: true),
            principal: FirebaseGameServicePrincipal(userID: "host-user"),
            store: documentStore
        )
        let playerService: any GameService = FirebaseGameService(
            configuration: FirebaseGameServiceConfiguration(emulatorHost: "localhost:8080", usesEmulator: true),
            principal: FirebaseGameServicePrincipal(userID: "taylor-user"),
            store: documentStore
        )

        let created = try await hostService.createRoom(board: GameBoard.sample)
        let (_, taylor) = try await playerService.joinRoom(joinCode: created.joinCode, displayName: "Taylor")
        var room = try await hostService.room(joinCode: created.joinCode)
        XCTAssertEqual(room.players.map { $0.displayName }, ["Taylor"])

        room = try await hostService.startGame(roomID: room.id, hostID: room.hostID)
        room = try await hostService.selectClue(roomID: room.id, hostID: room.hostID, clueID: "science-400")
        room = try await playerService.buzz(roomID: room.id, playerID: taylor.id, callerPlayerID: taylor.id)
        room = try await hostService.markCorrect(roomID: room.id, hostID: room.hostID)

        XCTAssertEqual(room.players.first { $0.id == taylor.id }?.score, 400)
        XCTAssertTrue(room.board.clues.first { $0.id == "science-400" }?.isUsed == true)
        let persistedRoom = try await hostService.room(joinCode: created.joinCode)
        XCTAssertEqual(persistedRoom, room)
    }

    func testFirebaseJoinIsIdempotentForSamePrincipal() async throws {
        let documentStore = InMemoryFirebaseGameDocumentStore()
        let hostService: any GameService = FirebaseGameService(
            configuration: FirebaseGameServiceConfiguration(usesEmulator: true),
            principal: FirebaseGameServicePrincipal(userID: "host-user"),
            store: documentStore
        )
        let playerService: any GameService = FirebaseGameService(
            configuration: FirebaseGameServiceConfiguration(usesEmulator: true),
            principal: FirebaseGameServicePrincipal(userID: "player-user"),
            store: documentStore
        )

        let created = try await hostService.createRoom(board: .sample)
        let (firstJoin, firstPlayer) = try await playerService.joinRoom(joinCode: created.joinCode, displayName: "Taylor")
        let (secondJoin, secondPlayer) = try await playerService.joinRoom(joinCode: created.joinCode, displayName: "Taylor")

        XCTAssertEqual(firstPlayer, secondPlayer)
        XCTAssertEqual(firstJoin.players, secondJoin.players)
        XCTAssertEqual(secondJoin.players.map(\.id), ["player-user"])
    }

    func testFirebaseRoomDocumentEncodesPrimitiveFirestoreIDs() throws {
        let room = GameRoom(id: "room-1", joinCode: "ABCD", hostID: "host-1", players: [Player(id: "p1", displayName: "Taylor")], phase: .waiting)
        let data = try JSONEncoder().encode(FirebaseGameRoomDocument(room: room))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(object["id"] as? String, "room-1")
        XCTAssertEqual(object["joinCode"] as? String, "ABCD")
        XCTAssertEqual(object["hostID"] as? String, "host-1")
        XCTAssertEqual(object["playerIDs"] as? [String], ["p1"])
        let players = try XCTUnwrap(object["players"] as? [[String: Any]])
        XCTAssertEqual(players.first?["id"] as? String, "p1")
    }

    func testFirebaseServiceRejectsWrongHostThroughDocumentStore() async throws {
        let service: any GameService = FirebaseGameService(
            configuration: FirebaseGameServiceConfiguration(usesEmulator: true),
            principal: FirebaseGameServicePrincipal(userID: "host-user"),
            store: InMemoryFirebaseGameDocumentStore()
        )
        let room = try await service.createRoom(board: GameBoard.sample)

        do {
            _ = try await service.startGame(roomID: room.id, hostID: "not-host")
            XCTFail("Expected wrong host to fail")
        } catch {
            XCTAssertEqual(error, .unauthorizedHost)
        }
    }

    func testFirebaseServiceRequiresPlayerBeforeStart() async throws {
        let service: any GameService = FirebaseGameService(
            configuration: FirebaseGameServiceConfiguration(usesEmulator: true),
            principal: FirebaseGameServicePrincipal(userID: "host-user"),
            store: InMemoryFirebaseGameDocumentStore()
        )
        let room = try await service.createRoom(board: GameBoard.sample)

        do {
            _ = try await service.startGame(roomID: room.id, hostID: room.hostID)
            XCTFail("Expected empty Firebase-backed game start to fail")
        } catch {
            XCTAssertEqual(error, .notEnoughPlayers)
        }
    }

    func testFirebaseServiceUsesAtomicMutationForFirstBuzz() async throws {
        var room = GameRoom(id: "room-atomic", joinCode: "BUZZ", players: [
            Player(id: "jordan", displayName: "Jordan"),
            Player(id: "casey", displayName: "Casey"),
        ], phase: .grid)
        room = try GameRules.selectClue("science-200", in: room)
        let store = ContendedFirebaseGameDocumentStore(document: FirebaseGameRoomDocument(room: room))
        let jordanService: any GameService = FirebaseGameService(
            configuration: FirebaseGameServiceConfiguration(usesEmulator: true),
            principal: FirebaseGameServicePrincipal(userID: "jordan"),
            store: store
        )
        let caseyService: any GameService = FirebaseGameService(
            configuration: FirebaseGameServiceConfiguration(usesEmulator: true),
            principal: FirebaseGameServicePrincipal(userID: "casey"),
            store: store
        )

        let first = try await jordanService.buzz(roomID: room.id, playerID: "jordan", callerPlayerID: "jordan")
        XCTAssertEqual(first.firstBuzzedPlayerID, "jordan")

        do {
            _ = try await caseyService.buzz(roomID: room.id, playerID: "casey", callerPlayerID: "casey")
            XCTFail("Expected second buzz to be locked out by atomic mutation state")
        } catch {
            XCTAssertEqual(error, .buzzAlreadyLocked)
        }
    }

    func testFirebasePrincipalBindsHostAndPlayerAuthority() async throws {
        let store = InMemoryFirebaseGameDocumentStore()
        let hostService: any GameService = FirebaseGameService(
            configuration: FirebaseGameServiceConfiguration(usesEmulator: true),
            principal: FirebaseGameServicePrincipal(userID: "host-user"),
            store: store
        )
        let playerService: any GameService = FirebaseGameService(
            configuration: FirebaseGameServiceConfiguration(usesEmulator: true),
            principal: FirebaseGameServicePrincipal(userID: "player-user"),
            store: store
        )

        let created = try await hostService.createRoom(board: .sample)
        XCTAssertEqual(created.hostID, "host-user")
        let (joined, player) = try await playerService.joinRoom(joinCode: created.joinCode, displayName: "Taylor")
        XCTAssertEqual(player.id, "player-user")

        var room = try await hostService.startGame(roomID: joined.id, hostID: "host-user")
        room = try await hostService.selectClue(roomID: room.id, hostID: "host-user", clueID: "science-200")

        do {
            _ = try await playerService.buzz(roomID: room.id, playerID: "host-user", callerPlayerID: "host-user")
            XCTFail("Expected authenticated player service to reject caller impersonation")
        } catch {
            XCTAssertEqual(error, .playerNotFound)
        }
    }

    func testFirebaseRoomDocumentMatchesFlatFirestoreRoomShape() {
        let room = GameRoom(id: "room-1", joinCode: "ABCD", hostID: "host-1", players: [Player(id: "p1", displayName: "Taylor")], phase: .waiting)
        let document = FirebaseGameRoomDocument(room: room)

        XCTAssertEqual(document.id, room.id)
        XCTAssertEqual(document.joinCode, room.joinCode)
        XCTAssertEqual(document.hostID, room.hostID)
        XCTAssertEqual(document.players, room.players)
        XCTAssertEqual(document.playerIDs, ["p1"])
        XCTAssertEqual(document.room, room)
        XCTAssertEqual(document.primitiveFieldValues["id"], "room-1")
        XCTAssertEqual(document.primitiveFieldValues["joinCode"], "ABCD")
        XCTAssertEqual(document.primitiveFieldValues["hostID"], "host-1")
        XCTAssertEqual(document.primitiveFieldValues["phase"], "waiting")
    }
}
