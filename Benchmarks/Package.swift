// swift-tools-version: 6.2
import PackageDescription
let package = Package(
    name: "SpeechBench",
    platforms: [.macOS(.v26)],
    dependencies: [.package(url: "https://github.com/Blaizzy/mlx-audio-swift.git", exact: "0.1.7")],
    targets: [.executableTarget(name: "SpeechBench", dependencies: [
        .product(name: "MLXAudioSTT", package: "mlx-audio-swift"),
        .product(name: "MLXAudioCore", package: "mlx-audio-swift")
    ])]
)
