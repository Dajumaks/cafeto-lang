// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Cafeto",
    targets: [
        .target(name: "CafetoCore", path: "Sources/CafetoCore"),
        .executableTarget(
            name: "cafeto",
            dependencies: ["CafetoCore"],
            path: "Sources/cafeto"
        ),
        .testTarget(
            name: "CafetoCoreTests",
            dependencies: ["CafetoCore"],
            path: "Tests/CafetoCoreTests"
        ),
    ]
)