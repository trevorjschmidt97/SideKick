import Foundation
import GameCore

#if canImport(FirebaseFirestore)
import FirebaseFirestore

public final class FirestoreGameDocumentStore: FirebaseGameDocumentStore, @unchecked Sendable {
    private let database: Firestore
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(database: Firestore = Firestore.firestore()) {
        self.database = database
    }

    public func roomDocument(roomID: RoomID) async throws(GameServiceError) -> FirebaseGameRoomDocument? {
        do {
            let snapshot = try await roomReference(roomID).getDocument()
            guard snapshot.exists, let data = snapshot.data() else {
                return nil
            }
            return try decodeRoomDocument(data)
        } catch let error as GameServiceError {
            throw error
        } catch {
            throw firestoreError(error)
        }
    }

    public func roomDocument(joinCode: JoinCode) async throws(GameServiceError) -> FirebaseGameRoomDocument? {
        do {
            let joinCodeSnapshot = try await joinCodeReference(joinCode).getDocument()
            if let roomIDValue = joinCodeSnapshot.data()?["roomID"] as? String {
                return try await roomDocument(roomID: RoomID(rawValue: roomIDValue))
            }

            let snapshot = try await roomsCollection()
                .whereField("joinCode", isEqualTo: joinCode.rawValue)
                .limit(to: 1)
                .getDocuments()
            guard let data = snapshot.documents.first?.data() else {
                return nil
            }
            return try decodeRoomDocument(data)
        } catch let error as GameServiceError {
            throw error
        } catch {
            throw firestoreError(error)
        }
    }

    public func createRoomDocument(_ document: FirebaseGameRoomDocument) async throws(GameServiceError) {
        let roomReference = roomReference(document.id)
        let joinCodeReference = joinCodeReference(document.joinCode)
        do {
            try await runTransaction { transaction, errorPointer in
                do {
                    if try transaction.getDocument(roomReference).exists
                        || transaction.getDocument(joinCodeReference).exists {
                        errorPointer?.pointee = Self.transactionNSError(.joinCodeUnavailable)
                        return nil
                    }
                    transaction.setData(try self.encode(document), forDocument: roomReference)
                    transaction.setData(
                        [
                            "roomID": document.id.rawValue,
                            "hostID": document.hostID.rawValue,
                        ],
                        forDocument: joinCodeReference
                    )
                    return document.id.rawValue
                } catch let error as GameServiceError {
                    errorPointer?.pointee = Self.transactionNSError(error)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }
        } catch {
            throw transactionError(error)
        }
    }

    public func saveRoomDocument(_ document: FirebaseGameRoomDocument) async throws(GameServiceError) {
        do {
            try await roomReference(document.id).setData(try encode(document))
            try await joinCodeReference(document.joinCode).setData([
                "roomID": document.id.rawValue,
                "hostID": document.hostID.rawValue,
            ])
        } catch let error as GameServiceError {
            throw error
        } catch {
            throw firestoreError(error)
        }
    }

    public func mutateRoomDocument(
        roomID: RoomID,
        operation: @escaping @Sendable (GameRoom) -> Result<FirebaseGameMutationResult, GameServiceError>
    ) async throws(GameServiceError) -> GameRoom {
        let reference = roomReference(roomID)
        do {
            try await runTransaction { transaction, errorPointer in
                do {
                    let snapshot = try transaction.getDocument(reference)
                    guard snapshot.exists, let data = snapshot.data() else {
                        errorPointer?.pointee = Self.transactionNSError(.roomNotFound)
                        return nil
                    }

                    let currentDocument = try self.decodeRoomDocument(data)
                    switch operation(currentDocument.room) {
                    case .failure(let error):
                        errorPointer?.pointee = Self.transactionNSError(error)
                        return nil
                    case .success(.updated(let room)):
                        let nextDocument = FirebaseGameRoomDocument(room: room)
                        transaction.setData(try self.encode(nextDocument), forDocument: reference)
                        return room.id.rawValue
                    }
                } catch let error as GameServiceError {
                    errorPointer?.pointee = Self.transactionNSError(error)
                    return nil
                } catch {
                    errorPointer?.pointee = error as NSError
                    return nil
                }
            }
        } catch {
            throw transactionError(error)
        }

        guard let document = try await roomDocument(roomID: roomID) else {
            throw .roomNotFound
        }
        return document.room
    }

    private func roomsCollection() -> CollectionReference {
        database.collection("rooms")
    }

    private func joinCodesCollection() -> CollectionReference {
        database.collection("joinCodes")
    }

    private func roomReference(_ roomID: RoomID) -> DocumentReference {
        roomsCollection().document(roomID.rawValue)
    }

    private func joinCodeReference(_ joinCode: JoinCode) -> DocumentReference {
        joinCodesCollection().document(joinCode.rawValue)
    }

    private func encode(_ document: FirebaseGameRoomDocument) throws(GameServiceError) -> [String: Any] {
        do {
            let data = try encoder.encode(document)
            let object = try JSONSerialization.jsonObject(with: data)
            guard let dictionary = object as? [String: Any] else {
                throw GameServiceError.backendUnavailable("Firebase room document did not encode as a dictionary.")
            }
            return dictionary
        } catch let error as GameServiceError {
            throw error
        } catch {
            throw .backendUnavailable("Failed to encode Firebase room document: \(error.localizedDescription)")
        }
    }

    private func decodeRoomDocument(_ fields: [String: Any]) throws(GameServiceError) -> FirebaseGameRoomDocument {
        do {
            let data = try JSONSerialization.data(withJSONObject: fields)
            return try decoder.decode(FirebaseGameRoomDocument.self, from: data)
        } catch {
            throw .backendUnavailable("Failed to decode Firebase room document: \(error.localizedDescription)")
        }
    }

    private func runTransaction(
        _ update: @escaping (Transaction, AutoreleasingUnsafeMutablePointer<NSError?>?) -> Any?
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            database.runTransaction(update) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    _ = result
                    continuation.resume()
                }
            }
        }
    }

    private static func transactionNSError(_ error: GameServiceError) -> NSError {
        NSError(
            domain: "SideKick.FirebaseGameService",
            code: 1,
            userInfo: [
                NSUnderlyingErrorKey: BoxedGameServiceError(error),
                NSLocalizedDescriptionKey: String(describing: error),
            ]
        )
    }

    private func transactionError(_ error: Error) -> GameServiceError {
        if let boxed = (error as NSError).userInfo[NSUnderlyingErrorKey] as? BoxedGameServiceError {
            return boxed.error
        }
        return firestoreError(error)
    }

    private func firestoreError(_ error: Error) -> GameServiceError {
        .backendUnavailable("Firestore operation failed: \(error.localizedDescription)")
    }
}

private final class BoxedGameServiceError: NSObject {
    let error: GameServiceError

    init(_ error: GameServiceError) {
        self.error = error
    }
}
#endif
