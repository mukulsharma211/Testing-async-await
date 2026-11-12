// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SearchDemo",
    platforms: [.iOS(.v16), .tvOS(.v16), .macOS(.v13)],
    products: [
        .library(name: "SearchDemo", targets: ["SearchDemo"])
    ],
    dependencies: [
        // Only the TEST target depends on swift-clocks. Production code uses `any Clock<Duration>`.
        .package(url: "https://github.com/pointfreeco/swift-clocks", from: "1.0.0")
    ],
    targets: [
        .target(
            name: "SearchDemo",
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        ),
        .testTarget(
            name: "SearchDemoTests",
            dependencies: [
                "SearchDemo",
                .product(name: "Clocks", package: "swift-clocks")
            ],
            swiftSettings: [.enableExperimentalFeature("StrictConcurrency")]
        )
    ]
)
