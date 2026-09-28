// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "FluenceCore",
    platforms: [.macOS(.v14), .iOS(.v17)],
    products: [.library(name: "FluenceCore", targets: ["FluenceCore"])],
    targets: [
        .target(name: "FluenceCore", path: "Core"),
        .testTarget(name: "FluenceCoreTests", dependencies: ["FluenceCore"], path: "Tests")
    ]
)
