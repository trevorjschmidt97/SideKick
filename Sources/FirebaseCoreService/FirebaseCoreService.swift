import Foundation

public struct FirebaseServiceConfiguration: Codable, Hashable, Sendable {
    public var projectID: String?
    public var firestoreEmulatorHost: String?
    public var authEmulatorHost: String?
    public var usesEmulator: Bool

    public init(
        projectID: String? = nil,
        firestoreEmulatorHost: String? = nil,
        authEmulatorHost: String? = nil,
        usesEmulator: Bool = false
    ) {
        self.projectID = projectID
        self.firestoreEmulatorHost = firestoreEmulatorHost
        self.authEmulatorHost = authEmulatorHost
        self.usesEmulator = usesEmulator
    }

    public func hostAndPort(for hostAndPort: String?, defaultHost: String = "localhost", defaultPort: Int) -> FirebaseEmulatorEndpoint {
        let parts = (hostAndPort ?? "\(defaultHost):\(defaultPort)")
            .split(separator: ":", maxSplits: 1)
            .map(String.init)
        return FirebaseEmulatorEndpoint(
            host: parts.first ?? defaultHost,
            port: parts.dropFirst().first.flatMap(Int.init) ?? defaultPort
        )
    }
}

public struct FirebaseEmulatorEndpoint: Codable, Hashable, Sendable {
    public var host: String
    public var port: Int

    public init(host: String, port: Int) {
        self.host = host
        self.port = port
    }
}

public struct FirebaseAuthenticatedPrincipal: Codable, Hashable, Sendable {
    public var userID: String

    public init(userID: String) {
        self.userID = userID
    }
}

public enum FirebaseCoreServiceError: Error, Codable, Equatable, Sendable {
    case backendUnavailable(String)
}
