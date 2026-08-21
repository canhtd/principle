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
    // Colours, type and geometry come from one package shared with VessaStudio
    // (spec #24): a token changes there once, not per app. A released version
    // rather than `main`, so a push over there cannot change this app's layout
    // between two builds of the same commit.
    dependencies: [
        .package(url: "https://github.com/canhtd/design-system.git", from: "0.2.5")
    ],
    targets: [
        // Thin shell: @main plus views only. Everything else lives in the library.
        .executableTarget(
            name: "Principle",
            dependencies: [
                "PrincipleCore",
                .product(name: "DesignSystem", package: "design-system"),
            ]
        ),
        .target(name: "PrincipleCore"),
        // DesignSystem is here for one assertion: the library repeats Eden's
        // sidebar width by hand (`PanelWidths.sidebarDefault`) because it cannot
        // depend on the package, and a copy nothing compares is a copy that
        // drifts. No view is tested from here.
        .testTarget(
            name: "PrincipleTests",
            dependencies: [
                "PrincipleCore",
                .product(name: "DesignSystem", package: "design-system"),
            ],
            resources: [.copy("Fixtures")]
        ),
    ]
)
