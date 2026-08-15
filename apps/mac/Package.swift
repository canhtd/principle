// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Principle",
    // Without an explicit pin the toolchain deploys against the host macOS
    // version (macOS 26 here), which would make the built app refuse to launch
    // on anything older.
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "Principle", targets: ["Principle"]),
        .library(name: "PrincipleCore", targets: ["PrincipleCore"]),
    ],
    targets: [
        // Thin shell: @main plus views only. Everything else lives in the library.
        .executableTarget(
            name: "Principle",
            dependencies: ["PrincipleCore"]
        ),
        .target(name: "PrincipleCore"),
        .testTarget(
            name: "PrincipleTests",
            dependencies: ["PrincipleCore"]
        ),
    ]
)
