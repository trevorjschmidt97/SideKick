import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore

public final class FirestoreSDKDocumentStore<Document: FirestoreDocument>: FirestoreDocumentStore, @unchecked Sendable {
    private let collection: CollectionReference
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(collection: CollectionReference) {
        self.collection = collection
    }

    public func document(id: Document.DocumentID) async throws(FirestoreDataServiceError) -> Document? {
        do {
            let snapshot = try await collection.document(id.rawValue).getDocument()
            guard snapshot.exists, let data = snapshot.data() else {
                return nil
            }
            return try decode(data)
        } catch let error as FirestoreDataServiceError {
            throw error
        } catch {
            throw firestoreError(error)
        }
    }

    public func firstDocument(where field: String, equals value: String) async throws(FirestoreDataServiceError) -> Document? {
        do {
            let snapshot = try await collection.whereField(field, isEqualTo: value).limit(to: 1).getDocuments()
            guard let data = snapshot.documents.first?.data() else {
                return nil
            }
            return try decode(data)
        } catch let error as FirestoreDataServiceError {
            throw error
        } catch {
            throw firestoreError(error)
        }
    }

    public func createDocument(_ document: Document) async throws(FirestoreDataServiceError) {
        let reference = collection.document(document.id.rawValue)
        do {
            try await runTransaction { transaction, errorPointer in
                do {
                    guard !((try transaction.getDocument(reference)).exists) else {
                        errorPointer?.pointee = Self.transactionNSError(.documentAlreadyExists)
                        return nil
                    }
                    transaction.setData(try self.encode(document), forDocument: reference)
                    return document.id.rawValue
                } catch let error as FirestoreDataServiceError {
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

    public func saveDocument(_ document: Document) async throws(FirestoreDataServiceError) {
        do {
            try await collection.document(document.id.rawValue).setData(try encode(document))
        } catch let error as FirestoreDataServiceError {
            throw error
        } catch {
            throw firestoreError(error)
        }
    }

    public func mutateDocument(
        id: Document.DocumentID,
        operation: @escaping @Sendable (Document) -> Result<Document, FirestoreDataServiceError>
    ) async throws(FirestoreDataServiceError) -> Document {
        let reference = collection.document(id.rawValue)
        do {
            try await runTransaction { transaction, errorPointer in
                do {
                    let snapshot = try transaction.getDocument(reference)
                    guard snapshot.exists, let data = snapshot.data() else {
                        errorPointer?.pointee = Self.transactionNSError(.documentNotFound)
                        return nil
                    }

                    let current = try self.decode(data)
                    switch operation(current) {
                    case .failure(let error):
                        errorPointer?.pointee = Self.transactionNSError(error)
                        return nil
                    case .success(let next):
                        transaction.setData(try self.encode(next), forDocument: reference)
                        return next.id.rawValue
                    }
                } catch let error as FirestoreDataServiceError {
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

        guard let next = try await document(id: id) else {
            throw .documentNotFound
        }
        return next
    }

    private func encode(_ document: Document) throws(FirestoreDataServiceError) -> [String: Any] {
        do {
            let data = try encoder.encode(document)
            guard let dictionary = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                throw FirestoreDataServiceError.backendUnavailable("Document did not encode as a dictionary.")
            }
            return dictionary
        } catch let error as FirestoreDataServiceError {
            throw error
        } catch {
            throw .backendUnavailable("Failed to encode document: \(error.localizedDescription)")
        }
    }

    private func decode(_ fields: [String: Any]) throws(FirestoreDataServiceError) -> Document {
        do {
            let data = try JSONSerialization.data(withJSONObject: fields)
            return try decoder.decode(Document.self, from: data)
        } catch {
            throw .backendUnavailable("Failed to decode document: \(error.localizedDescription)")
        }
    }

    private func runTransaction(
        _ update: @escaping (Transaction, AutoreleasingUnsafeMutablePointer<NSError?>?) -> Any?
    ) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            collection.firestore.runTransaction(update) { result, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    _ = result
                    continuation.resume()
                }
            }
        }
    }

    private static func transactionNSError(_ error: FirestoreDataServiceError) -> NSError {
        NSError(
            domain: "SideKick.FirestoreDataService",
            code: 1,
            userInfo: [
                NSUnderlyingErrorKey: BoxedFirestoreDataServiceError(error),
                NSLocalizedDescriptionKey: String(describing: error),
            ]
        )
    }

    private func transactionError(_ error: Error) -> FirestoreDataServiceError {
        if let boxed = (error as NSError).userInfo[NSUnderlyingErrorKey] as? BoxedFirestoreDataServiceError {
            return boxed.error
        }
        return firestoreError(error)
    }

    private func firestoreError(_ error: Error) -> FirestoreDataServiceError {
        .backendUnavailable("Firestore operation failed: \(error.localizedDescription)")
    }
}

private final class BoxedFirestoreDataServiceError: NSObject {
    let error: FirestoreDataServiceError

    init(_ error: FirestoreDataServiceError) {
        self.error = error
    }
}
#endif
