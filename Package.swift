// swift-tools-version: 6.0
import PackageDescription

// Zero external dependencies on purpose: see CLAUDE.md ("fire and forget").
let package = Package(
    name: "Ledge",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "Ledge", targets: ["Ledge"])],
    targets: [
        // Pure logic, no UI. Everything testable lives here.
        .target(name: "LedgeCore"),
        // AppKit shell: panel, lifecycle, settings.
        .executableTarget(name: "Ledge", dependencies: ["LedgeCore"]),
        .testTarget(name: "LedgeCoreTests", dependencies: ["LedgeCore"]),
    ]
)
