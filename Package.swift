// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SwiFRP",
    defaultLocalization: "en",
    platforms: [
        .macOS(.v13)
    ],
    products: [
        .executable(name: "SwiFRP", targets: ["SwiFRP"])
    ],
    dependencies: [],
    targets: [
        .executableTarget(
            name: "SwiFRP",
            path: "SwiFRP",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "SwiFRPTests",
            dependencies: ["SwiFRP"],
            path: "SwiFRPTests"
        )
    ]
)
