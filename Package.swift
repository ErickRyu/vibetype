// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "VibeType",
    platforms: [
        .macOS(.v14),
        .iOS(.v17),
    ],
    products: [
        .library(name: "VibeTypeCore", targets: ["VibeTypeCore"]),
        .executable(name: "vibetype-cli", targets: ["VibeTypeCLI"]),
    ],
    dependencies: [
        .package(url: "https://github.com/ml-explore/mlx-swift", from: "0.21.0"),
        .package(url: "https://github.com/ml-explore/mlx-swift-examples", from: "2.21.0"),
    ],
    targets: [
        .target(
            name: "VibeTypeCore",
            dependencies: [
                .product(name: "MLX", package: "mlx-swift"),
                .product(name: "MLXNN", package: "mlx-swift"),
                .product(name: "MLXLLM", package: "mlx-swift-examples"),
                .product(name: "MLXLMCommon", package: "mlx-swift-examples"),
            ],
            path: "Sources/VibeTypeCore"
        ),
        .executableTarget(
            name: "VibeTypeCLI",
            dependencies: ["VibeTypeCore"],
            path: "Sources/VibeTypeCLI"
        ),
        .testTarget(
            name: "VibeTypeCoreTests",
            dependencies: ["VibeTypeCore"],
            path: "Tests/VibeTypeCoreTests"
        ),
    ]
)
