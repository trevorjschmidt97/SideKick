import XCTest
import FirestoreDataService

private struct TestDocumentID: FirestoreDocumentID, ExpressibleByStringLiteral {
    var rawValue: String
    init(rawValue: String) { self.rawValue = rawValue }
    init(stringLiteral value: String) { self.rawValue = value }
}

private struct TestDocument: FirestoreDocument {
    var id: TestDocumentID
    var group: String
    var count: Int

    var primitiveFieldValues: [String: String] {
        ["id": id.rawValue, "group": group]
    }
}

final class FirestoreDataServiceTests: XCTestCase {
    func testGenericInMemoryStoreCreatesQueriesAndMutatesDocuments() async throws {
        let store = InMemoryFirestoreDocumentStore<TestDocument>()
        try await store.createDocument(TestDocument(id: "doc-1", group: "alpha", count: 1))

        let created = try await store.document(id: "doc-1")
        let queried = try await store.firstDocument(where: "group", equals: "alpha")
        XCTAssertEqual(created?.count, 1)
        XCTAssertEqual(queried?.id, "doc-1")

        let updated = try await store.mutateDocument(id: "doc-1") { document in
            var next = document
            next.count += 1
            return .success(next)
        }

        XCTAssertEqual(updated.count, 2)
        let persisted = try await store.document(id: "doc-1")
        XCTAssertEqual(persisted?.count, 2)
    }

    func testAnyFirestoreDocumentStorePreservesGenericShape() async throws {
        let store = AnyFirestoreDocumentStore(InMemoryFirestoreDocumentStore<TestDocument>(documents: [
            TestDocument(id: "doc-1", group: "beta", count: 3),
        ]))

        let queried = try await store.firstDocument(where: "group", equals: "beta")
        XCTAssertEqual(queried?.count, 3)
    }

    func testMutatingMissingDocumentReturnsGenericStoreError() async {
        let store = InMemoryFirestoreDocumentStore<TestDocument>()

        do {
            _ = try await store.mutateDocument(id: "missing") { .success($0) }
            XCTFail("Expected missing document")
        } catch {
            XCTAssertEqual(error, .documentNotFound)
        }
    }
}
