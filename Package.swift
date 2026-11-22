// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "Tickdesk",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(name: "Tickdesk", path: "Sources/Tickdesk")
    ]
)
