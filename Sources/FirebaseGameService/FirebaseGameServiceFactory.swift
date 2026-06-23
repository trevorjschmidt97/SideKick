import Foundation
import FirestoreDataService
import GameCore

#if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
#endif

public enum FirebaseGameServiceFactory {
    public static func makeLocalEmulatorService(
        projectID: String = "demo-sidekick",
        firestoreEmulatorHost: String = "localhost:8080",
        authEmulatorHost: String = "localhost:9099",
        database: Any? = nil
    ) async throws(GameServiceError) -> any GameService {
        try await makeAuthenticatedService(
            configuration: FirebaseGameServiceConfiguration(
                projectID: projectID,
                emulatorHost: firestoreEmulatorHost,
                authEmulatorHost: authEmulatorHost,
                usesEmulator: true
            ),
            database: database,
            allowsDemoOptions: true
        )
    }

    public static func makeAuthenticatedService(
        configuration: FirebaseGameServiceConfiguration,
        database: Any? = nil
    ) async throws(GameServiceError) -> any GameService {
        try await makeAuthenticatedService(
            configuration: configuration,
            database: database,
            allowsDemoOptions: false
        )
    }

    private static func makeAuthenticatedService(
        configuration: FirebaseGameServiceConfiguration,
        database: Any?,
        allowsDemoOptions: Bool
    ) async throws(GameServiceError) -> any GameService {
        #if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
        if FirebaseApp.app() == nil {
            configureFirebaseApp(configuration: configuration, allowsDemoOptions: allowsDemoOptions)
        }
        configureAuthEmulatorIfNeeded(configuration: configuration)

        let authUser: User
        if let currentUser = Auth.auth().currentUser {
            authUser = currentUser
        } else {
            do {
                authUser = try await Auth.auth().signInAnonymously().user
            } catch {
                throw .backendUnavailable("Firebase anonymous sign-in failed: \(error.localizedDescription)")
            }
        }

        let firestore: Firestore
        if let suppliedDatabase = database as? Firestore {
            firestore = suppliedDatabase
        } else {
            firestore = Firestore.firestore()
        }
        configureEmulatorIfNeeded(configuration: configuration, database: firestore)

        return FirebaseGameService(
            configuration: configuration,
            principal: FirebaseGameServicePrincipal(userID: authUser.uid),
            store: GenericFirebaseGameDocumentStore(
                store: FirestoreSDKDocumentStore<FirebaseGameRoomDocument>(collection: firestore.collection("rooms"))
            )
        )
        #else
        _ = database
        throw .backendUnavailable("FirebaseAuth, FirebaseCore, and FirebaseFirestore SDKs are required to create a Firebase-backed game service.")
        #endif
    }

    #if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
    private static func configureFirebaseApp(
        configuration: FirebaseGameServiceConfiguration,
        allowsDemoOptions: Bool
    ) {
        if allowsDemoOptions {
            let projectID = configuration.projectID ?? "demo-sidekick"
            let options = FirebaseOptions(
                googleAppID: "1:1234567890:ios:\(projectID.replacingOccurrences(of: "-", with: ""))",
                gcmSenderID: "1234567890"
            )
            options.apiKey = "fake-api-key"
            options.projectID = projectID
            options.bundleID = Bundle.main.bundleIdentifier ?? "com.sidekick.local"
            FirebaseApp.configure(options: options)
        } else {
            FirebaseApp.configure()
        }
    }

    private static func configureAuthEmulatorIfNeeded(configuration: FirebaseGameServiceConfiguration) {
        guard configuration.usesEmulator else {
            return
        }
        let (host, port) = hostAndPortParts(configuration.authEmulatorHost ?? "localhost:9099", defaultPort: 9099)
        Auth.auth().useEmulator(withHost: host, port: port)
    }

    private static func configureEmulatorIfNeeded(
        configuration: FirebaseGameServiceConfiguration,
        database: Firestore
    ) {
        guard configuration.usesEmulator else {
            return
        }
        let (host, port) = hostAndPortParts(configuration.emulatorHost ?? "localhost:8080", defaultPort: 8080)
        database.useEmulator(withHost: host, port: port)
    }

    private static func hostAndPortParts(_ hostAndPort: String, defaultPort: Int) -> (String, Int) {
        let parts = hostAndPort.split(separator: ":", maxSplits: 1).map(String.init)
        let host = parts.first ?? "localhost"
        let port = parts.dropFirst().first.flatMap(Int.init) ?? defaultPort
        return (host, port)
    }
    #endif
}
