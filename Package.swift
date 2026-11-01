// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "s7r",
    defaultLocalization: "en",
    platforms: [.macOS(.v26)],
    products: [
        .library(name: "S7RCore", targets: ["S7RCore"]),
        .executable(name: "s7r", targets: ["s7r"]),
        .executable(name: "S7RApp", targets: ["S7RApp"])
    ],
    dependencies: [
        .package(url: "https://github.com/argmaxinc/argmax-oss-swift.git", exact: "1.1.1"),
        .package(url: "https://github.com/ml-explore/mlx-swift-lm.git", exact: "3.32.3"),
        .package(url: "https://github.com/huggingface/swift-transformers.git", exact: "1.3.0"),
        .package(url: "https://github.com/Blaizzy/mlx-audio-swift.git", exact: "0.1.7")
    ],
    targets: [
        .target(name: "S7RCore"),
        .target(name: "S7RPlatform", dependencies: [
            "S7RCore",
            .product(name: "WhisperKit", package: "argmax-oss-swift"),
            .product(name: "MLXAudioSTT", package: "mlx-audio-swift"),
            .product(name: "MLXLLM", package: "mlx-swift-lm"),
            .product(name: "MLXLMCommon", package: "mlx-swift-lm"),
            .product(name: "MLXHuggingFace", package: "mlx-swift-lm"),
            .product(name: "Tokenizers", package: "swift-transformers")
        ], resources: [.process("Resources")]),
        .executableTarget(name: "s7r", dependencies: ["S7RCore", "S7RPlatform"]),
        .executableTarget(name: "S7RApp", dependencies: ["S7RCore", "S7RPlatform"], resources: [.process("Resources")]),
        .testTarget(name: "S7RCoreTests", dependencies: ["S7RCore", "S7RPlatform"])
    ]
)
