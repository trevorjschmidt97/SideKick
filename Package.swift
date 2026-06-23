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
        .library(name: "FirebaseGameService", targets: ["FirebaseGameService"]),
        .library(name: "SideKickAppCore", targets: ["SideKickAppCore"]),
        .library(name: "PartyGameAppleApp", targets: ["PartyGameAppleApp"]),
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
        .target(
            name: "FirebaseGameService",
            dependencies: [
                "GameCore",
                .product(name: "FirebaseAuth", package: "firebase-ios-sdk"),
                .product(name: "FirebaseCore", package: "firebase-ios-sdk"),
                .product(name: "FirebaseFirestore", package: "firebase-ios-sdk"),
            ],
            exclude: ["BUILD.bazel"]
        ),
        .target(name: "SideKickAppCore", dependencies: ["GameCore"], exclude: ["BUILD.bazel"]),
        .target(name: "PartyGameAppleApp", dependencies: ["BoardGameModule", "FirebaseGameService", "GameCore", "GameEntryModule", "GameIntents", "GameServices", "JoinGameModule", "GameManagers", "SideKickAppCore"], exclude: ["BUILD.bazel"]),
        .testTarget(name: "SideKickTests", dependencies: ["BoardGameModule", "GameCore", "GameEntryModule", "GameIntents", "GameModuleShared", "JoinGameModule", "GameManagers", "GameServices", "FirebaseGameService", "SideKickAppCore", "PartyGameAppleApp"], exclude: ["BUILD.bazel"]),
    ]
)
