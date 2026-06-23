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
        firestoreEmulatorHost: String = "localhost:8080",
        authEmulatorHost: String = "localhost:9099",
        database: Any? = nil
    ) async throws(FamilyFeudServiceError) -> any FamilyFeudService {
        #if canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(FirebaseFirestore)
        if FirebaseApp.app() == nil {
            let options = FirebaseOptions(
                googleAppID: "1:1234567890:ios:\(projectID.replacingOccurrences(of: "-", with: ""))",
                gcmSenderID: "1234567890"
            )
            options.apiKey = "fake-api-key"
            options.projectID = projectID
            options.bundleID = Bundle.main.bundleIdentifier ?? "com.sidekick.familyfeud.local"
            FirebaseApp.configure(options: options)
        }

        let (authHost, authPort) = hostAndPortParts(authEmulatorHost, defaultPort: 9099)
        Auth.auth().useEmulator(withHost: authHost, port: authPort)

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
        let (firestoreHost, firestorePort) = hostAndPortParts(firestoreEmulatorHost, defaultPort: 8080)
        firestore.useEmulator(withHost: firestoreHost, port: firestorePort)

        return FirebaseFamilyFeudService(
            configuration: FirebaseFamilyFeudServiceConfiguration(),
            principal: FirebaseFamilyFeudPrincipal(userID: authUser.uid),
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
        let host = parts.first ?? "localhost"
        let port = parts.dropFirst().first.flatMap(Int.init) ?? defaultPort
        return (host, port)
    }
    #endif
}
