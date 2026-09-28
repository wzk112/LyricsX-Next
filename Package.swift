// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "LyricsX",
    platforms: [.macOS(.v26)],
    products: [
        .executable(name: "LyricsX", targets: ["LyricsXApp"]),
        .library(name: "LyricsXCore", targets: ["LyricsXCore"]),
    ],
    dependencies: [
        .package(path: "Vendor/LyricsKit"),
        .package(url: "https://github.com/MxIris-LyricsX-Project/mediaremote-adapter", revision: "0fa7db9dea7cdb72bbb4090eaccf2355d8e4279e"),
    ],
    targets: [
        .target(name: "LyricsXCore"),
        .target(name: "LyricsXServices", dependencies: [
            "LyricsXCore", .product(name: "LyricsKit", package: "LyricsKit"),
            .product(name: "MediaRemoteAdapter", package: "mediaremote-adapter"),
        ]),
        .executableTarget(name: "LyricsXApp", dependencies: ["LyricsXCore", "LyricsXServices"],
            resources: [.copy("GuideAssets")]),
        .testTarget(name: "LyricsXCoreTests", dependencies: ["LyricsXCore"]),
        .testTarget(name: "LyricsXServicesTests", dependencies: ["LyricsXServices"]),
        .testTarget(name: "LyricsXAppTests", dependencies: ["LyricsXApp"]),
    ],
    swiftLanguageModes: [.v6]
)
