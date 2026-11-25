// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "ClipGlyph",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(name: "ClipGlyph", path: "Sources/ClipGlyph")
    ],
    swiftLanguageVersions: [.v5]
)
