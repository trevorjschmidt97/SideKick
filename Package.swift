// swift-tools-version: 6.0

import PackageDescription

let package = Package(
    name: "SideKick",
    platforms: [
        .iOS(.v18),
        .macOS(.v15),
        .tvOS(.v18),
        .watchOS(.v11),
    ],
    products: [
        .library(name: "GameCore", targets: ["GameCore"]),
        .library(name: "GameIntents", targets: ["GameIntents"]),
        .library(name: "GameModuleShared", targets: ["GameModuleShared"]),
        .library(name: "GameEntryModule", targets: ["GameEntryModule"]),
        .library(name: "BoardGameModule", targets: ["BoardGameModule"]),
        .library(name: "JoinGameModule", targets: ["JoinGameModule"]),
        .library(name: "GameManagers", targets: ["GameManagers"]),
        .library(name: "GameServices", targets: ["GameServices"]),
        .library(name: "FirebaseCoreService", targets: ["FirebaseCoreService"]),
        .library(name: "FirestoreDataService", targets: ["FirestoreDataService"]),
        .library(name: "FirebaseGameService", targets: ["FirebaseGameService"]),
        .library(name: "SideKickAppCore", targets: ["SideKickAppCore"]),
        .library(name: "PartyGameAppCore", targets: ["PartyGameAppCore"]),
        .library(name: "PartyGameAppleApp", targets: ["PartyGameAppleApp"]),
        .library(name: "FamilyFeudCore", targets: ["FamilyFeudCore"]),
        .library(name: "FamilyFeudServices", targets: ["FamilyFeudServices"]),
        .library(name: "FamilyFeudManagers", targets: ["FamilyFeudManagers"]),
        .library(name: "FamilyFeudIntents", targets: ["FamilyFeudIntents"]),
        .library(name: "FamilyFeudModules", targets: ["FamilyFeudModules"]),
        .library(name: "FamilyFeudAppCore", targets: ["FamilyFeudAppCore"]),
        .library(name: "FirebaseFamilyFeudService", targets: ["FirebaseFamilyFeudService"]),
        .library(name: "FamilyFeudAppleApp", targets: ["FamilyFeudAppleApp"]),
    ],
    dependencies: [
        .package(url: "https://github.com/firebase/firebase-ios-sdk.git", from: "12.15.0"),
    ],
    targets: [
        .target(name: "GameCore", exclude: ["BUILD.bazel"]),
        .target(name: "GameIntents", dependencies: ["GameCore"], exclude: ["BUILD.bazel"]),
        .target(
            name: "GameModuleShared",
            dependencies: ["GameCore"],
            path: "Sources/GameModules",
            exclude: ["BUILD.bazel", "GameEntryModule.swift", "BoardModule.swift", "JoinModule.swift"],
            sources: ["GameModuleEvents.swift", "GameModuleStrings.swift", "SharedGameModuleViews.swift"]
        ),
        .target(
            name: "GameEntryModule",
            dependencies: ["GameCore", "GameModuleShared"],
            path: "Sources/GameModules",
            exclude: ["BUILD.bazel", "GameModuleEvents.swift", "GameModuleStrings.swift", "SharedGameModuleViews.swift", "BoardModule.swift", "JoinModule.swift"],
            sources: ["GameEntryModule.swift"]
        ),
        .target(
            name: "BoardGameModule",
            dependencies: ["GameCore", "GameModuleShared"],
            path: "Sources/GameModules",
            exclude: ["BUILD.bazel", "GameModuleEvents.swift", "GameModuleStrings.swift", "SharedGameModuleViews.swift", "GameEntryModule.swift", "JoinModule.swift"],
            sources: ["BoardModule.swift"]
        ),
        .target(
            name: "JoinGameModule",
            dependencies: ["GameCore", "GameModuleShared"],
            path: "Sources/GameModules",
            exclude: ["BUILD.bazel", "GameModuleEvents.swift", "GameModuleStrings.swift", "SharedGameModuleViews.swift", "GameEntryModule.swift", "BoardModule.swift"],
            sources: ["JoinModule.swift"]
        ),
        .target(name: "GameManagers", dependencies: ["GameCore"], exclude: ["BUILD.bazel"]),
        .target(name: "GameServices", dependencies: ["GameCore"], exclude: ["BUILD.bazel"]),
        .target(name: "FirebaseCoreService", exclude: ["BUILD.bazel"]),
        .target(
            name: "FirestoreDataService",
            dependencies: [
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
            ],
            exclude: ["BUILD.bazel"]
        ),
        .target(
            name: "FirebaseGameService",
            dependencies: [
                "FirebaseCoreService",
                "FirestoreDataService",
                "GameCore",
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
            ],
            exclude: ["BUILD.bazel"]
        ),
        .target(name: "SideKickAppCore", exclude: ["BUILD.bazel"]),
        .target(name: "PartyGameAppCore", dependencies: ["GameCore", "SideKickAppCore"], exclude: ["BUILD.bazel"]),
        .target(name: "PartyGameAppleApp", dependencies: ["BoardGameModule", "FirebaseGameService", "GameCore", "GameEntryModule", "GameIntents", "GameServices", "JoinGameModule", "GameManagers", "PartyGameAppCore", "SideKickAppCore"], exclude: ["BUILD.bazel"]),
        .target(name: "FamilyFeudCore", exclude: ["BUILD.bazel"]),
        .target(name: "FamilyFeudServices", dependencies: ["FamilyFeudCore"], exclude: ["BUILD.bazel"]),
        .target(name: "FamilyFeudManagers", dependencies: ["FamilyFeudCore"], exclude: ["BUILD.bazel"]),
        .target(name: "FamilyFeudIntents", dependencies: ["FamilyFeudCore", "FamilyFeudManagers"], exclude: ["BUILD.bazel"]),
        .target(name: "FamilyFeudModules", dependencies: ["FamilyFeudCore"], exclude: ["BUILD.bazel"]),
        .target(name: "FamilyFeudAppCore", dependencies: ["FamilyFeudCore", "SideKickAppCore"], exclude: ["BUILD.bazel"]),
        .target(name: "FirebaseFamilyFeudService", dependencies: ["FamilyFeudCore", "FirebaseCoreService", "FirestoreDataService"], exclude: ["BUILD.bazel"]),
        .target(name: "FamilyFeudAppleApp", dependencies: ["FamilyFeudAppCore", "FamilyFeudCore", "FamilyFeudIntents", "FamilyFeudManagers", "FamilyFeudModules", "FamilyFeudServices", "SideKickAppCore"], exclude: ["BUILD.bazel"]),
        .testTarget(name: "SideKickTests", dependencies: ["BoardGameModule", "FamilyFeudAppCore", "FamilyFeudAppleApp", "FamilyFeudCore", "FamilyFeudIntents", "FamilyFeudManagers", "FamilyFeudModules", "FamilyFeudServices", "FirebaseCoreService", "FirebaseFamilyFeudService", "FirebaseGameService", "FirestoreDataService", "GameCore", "GameEntryModule", "GameIntents", "GameModuleShared", "JoinGameModule", "GameManagers", "GameServices", "PartyGameAppCore", "SideKickAppCore", "PartyGameAppleApp"], exclude: ["BUILD.bazel"]),
    ]
)
