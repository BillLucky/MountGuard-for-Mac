// swift-tools-version: 6.3
import PackageDescription

let package = Package(
    name: "MountGuard",
    platforms: [
        .macOS(.v13),
    ],
    products: [
        .library(
            name: "MountGuardKit",
            targets: ["MountGuardKit"]
        ),
        .executable(
            name: "MountGuardApp",
            targets: ["MountGuardApp"]
        ),
        .executable(
            name: "mountguardctl",
            targets: ["mountguardctl"]
        ),
    ],
    targets: [
        .target(
            name: "MountGuardKit"
        ),
        .executableTarget(
            name: "MountGuardApp",
            dependencies: ["MountGuardKit"]
        ),
        .executableTarget(
            name: "mountguardctl",
            dependencies: ["MountGuardKit"]
        ),
        .testTarget(
            name: "MountGuardKitTests",
            dependencies: ["MountGuardKit"]
        ),
    ],
    swiftLanguageModes: [.v6]
)
