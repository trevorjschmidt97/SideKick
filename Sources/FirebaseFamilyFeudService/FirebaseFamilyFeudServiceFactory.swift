import Foundation
import FirestoreDataService
import FamilyFeudCore

#if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
import FirebaseAuth
import FirebaseCore
import FirebaseFirestore
#endif

public enum FirebaseFamilyFeudServiceFactory {
    public static func makeLocalEmulatorService(
        projectID: String = "demo-sidekick",
        firestoreEmulatorHost: String = "127.0.0.1:8080",
        authEmulatorHost: String = "127.0.0.1:9099",
        database: Any? = nil
    ) async throws(FamilyFeudServiceError) -> any FamilyFeudService {
        #if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
        if FirebaseApp.app() == nil {
            let options = FirebaseOptions(
                googleAppID: "1:1234567890:ios:1234567890abcdef123456",
                gcmSenderID: "1234567890"
            )
            options.apiKey = "AIzaSyDLocalEmulatorOnlyKey000000000000000"
            options.projectID = projectID
            options.bundleID = Bundle.main.bundleIdentifier ?? "com.sidekick.familyfeud.local"
            FirebaseApp.configure(options: options)
        }

        _ = authEmulatorHost
        let principal = FirebaseFamilyFeudPrincipal(userID: localEmulatorUserID())

        let firestore: Firestore
        if let suppliedDatabase = database as? Firestore {
            firestore = suppliedDatabase
        } else {
            firestore = Firestore.firestore()
        }
        let (firestoreHost, firestorePort) = hostAndPortParts(firestoreEmulatorHost, defaultPort: 8080)
        let settings = firestore.settings
        settings.host = "\(firestoreHost):\(firestorePort)"
        settings.isSSLEnabled = false
        firestore.settings = settings

        return FirebaseFamilyFeudService(
            configuration: FirebaseFamilyFeudServiceConfiguration(),
            principal: principal,
            store: FirestoreSDKDocumentStore<FirebaseFamilyFeudRoomDocument>(
                collection: firestore.collection("familyFeudRooms")
            )
        )
        #else
        _ = database
        throw .backendUnavailable("FirebaseAuth, FirebaseCore, and FirebaseFirestore SDKs are required to create a Firebase-backed Family Feud service.")
        #endif
    }

    #if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
    private static func hostAndPortParts(_ hostAndPort: String, defaultPort: Int) -> (String, Int) {
        let parts = hostAndPort.split(separator: ":", maxSplits: 1).map(String.init)
        let host = parts.first ?? "127.0.0.1"
        let port = parts.dropFirst().first.flatMap(Int.init) ?? defaultPort
        return (host, port)
    }

    private static func localEmulatorUserID() -> String {
        let key = "SideKick.FirebaseFamilyFeudService.localEmulatorUserID"
        if let existing = UserDefaults.standard.string(forKey: key) {
            return existing
        }
        let created = "local-\(UUID().uuidString)"
        UserDefaults.standard.set(created, forKey: key)
        return created
    }
    #endif
}
