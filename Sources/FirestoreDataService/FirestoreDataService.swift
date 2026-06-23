import Foundation

public protocol FirestoreDocumentID: RawRepresentable, Codable, Hashable, Sendable where RawValue == String {}

public protocol FirestoreDocument: Codable, Equatable, Sendable {
    associatedtype DocumentID: RawRepresentable & Codable & Hashable & Sendable where DocumentID.RawValue == String

    var id: DocumentID { get }
    var primitiveFieldValues: [String: String] { get }
}

public extension FirestoreDocument {
    var primitiveFieldValues: [String: String] {
        ["id": id.rawValue]
    }
}

public struct FirestoreCollection<Document: FirestoreDocument>: Sendable {
    public var name: String

    public init(_ name: String) {
        self.name = name
    }
}

public enum FirestoreDataServiceError: Error, Codable, Equatable, Sendable {
    case documentNotFound
    case documentAlreadyExists
    case queryConflict
    case backendUnavailable(String)
}

public protocol FirestoreDocumentStore: Sendable {
    associatedtype Document: FirestoreDocument

    func document(id: Document.DocumentID) async throws(FirestoreDataServiceError) -> Document?
    func firstDocument(where field: String, equals value: String) async throws(FirestoreDataServiceError) -> Document?
    func createDocument(_ document: Document) async throws(FirestoreDataServiceError)
    func saveDocument(_ document: Document) async throws(FirestoreDataServiceError)
    func mutateDocument(
        id: Document.DocumentID,
        operation: @escaping @Sendable (Document) -> Result<Document, FirestoreDataServiceError>
    ) async throws(FirestoreDataServiceError) -> Document
}

public actor InMemoryFirestoreDocumentStore<Document: FirestoreDocument>: FirestoreDocumentStore {
    private var documentsByID: [Document.DocumentID: Document]

    public init(documents: [Document] = []) {
        self.documentsByID = Dictionary(uniqueKeysWithValues: documents.map { ($0.id, $0) })
    }

    public func document(id: Document.DocumentID) async throws(FirestoreDataServiceError) -> Document? {
        documentsByID[id]
    }

    public func firstDocument(where field: String, equals value: String) async throws(FirestoreDataServiceError) -> Document? {
        documentsByID.values.first { $0.primitiveFieldValues[field] == value }
    }

    public func createDocument(_ document: Document) async throws(FirestoreDataServiceError) {
        guard documentsByID[document.id] == nil else {
            throw .documentAlreadyExists
        }
        documentsByID[document.id] = document
    }

    public func saveDocument(_ document: Document) async throws(FirestoreDataServiceError) {
        documentsByID[document.id] = document
    }

    public func mutateDocument(
        id: Document.DocumentID,
        operation: @escaping @Sendable (Document) -> Result<Document, FirestoreDataServiceError>
    ) async throws(FirestoreDataServiceError) -> Document {
        guard let document = documentsByID[id] else {
            throw .documentNotFound
        }
        switch operation(document) {
        case .failure(let error):
            throw error
        case .success(let next):
            documentsByID[next.id] = next
            return next
        }
    }
}

public struct AnyFirestoreDocumentStore<Document: FirestoreDocument>: FirestoreDocumentStore {
    private let _document: @Sendable (Document.DocumentID) async throws(FirestoreDataServiceError) -> Document?
    private let _firstDocument: @Sendable (String, String) async throws(FirestoreDataServiceError) -> Document?
    private let _createDocument: @Sendable (Document) async throws(FirestoreDataServiceError) -> Void
    private let _saveDocument: @Sendable (Document) async throws(FirestoreDataServiceError) -> Void
    private let _mutateDocument: @Sendable (Document.DocumentID, @escaping @Sendable (Document) -> Result<Document, FirestoreDataServiceError>) async throws(FirestoreDataServiceError) -> Document

    public init<Store: FirestoreDocumentStore>(_ store: Store) where Store.Document == Document {
        self._document = { (id: Document.DocumentID) async throws(FirestoreDataServiceError) -> Document? in
            do {
                return try await store.document(id: id)
            } catch let error as FirestoreDataServiceError {
                throw error
            } catch {
                throw .backendUnavailable(error.localizedDescription)
            }
        }
        self._firstDocument = { (field: String, value: String) async throws(FirestoreDataServiceError) -> Document? in
            do {
                return try await store.firstDocument(where: field, equals: value)
            } catch let error as FirestoreDataServiceError {
                throw error
            } catch {
                throw .backendUnavailable(error.localizedDescription)
            }
        }
        self._createDocument = { (document: Document) async throws(FirestoreDataServiceError) -> Void in
            do {
                try await store.createDocument(document)
            } catch let error as FirestoreDataServiceError {
                throw error
            } catch {
                throw .backendUnavailable(error.localizedDescription)
            }
        }
        self._saveDocument = { (document: Document) async throws(FirestoreDataServiceError) -> Void in
            do {
                try await store.saveDocument(document)
            } catch let error as FirestoreDataServiceError {
                throw error
            } catch {
                throw .backendUnavailable(error.localizedDescription)
            }
        }
        self._mutateDocument = { (
            id: Document.DocumentID,
            operation: @escaping @Sendable (Document) -> Result<Document, FirestoreDataServiceError>
        ) async throws(FirestoreDataServiceError) -> Document in
            do {
                return try await store.mutateDocument(id: id, operation: operation)
            } catch let error as FirestoreDataServiceError {
                throw error
            } catch {
                throw .backendUnavailable(error.localizedDescription)
            }
        }
    }

    public func document(id: Document.DocumentID) async throws(FirestoreDataServiceError) -> Document? {
        try await _document(id)
    }

    public func firstDocument(where field: String, equals value: String) async throws(FirestoreDataServiceError) -> Document? {
        try await _firstDocument(field, value)
    }

    public func createDocument(_ document: Document) async throws(FirestoreDataServiceError) {
        try await _createDocument(document)
    }

    public func saveDocument(_ document: Document) async throws(FirestoreDataServiceError) {
        try await _saveDocument(document)
    }

    public func mutateDocument(
        id: Document.DocumentID,
        operation: @escaping @Sendable (Document) -> Result<Document, FirestoreDataServiceError>
    ) async throws(FirestoreDataServiceError) -> Document {
        try await _mutateDocument(id, operation)
    }
}
