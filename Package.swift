// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "swift-brief-kit",
    // Foundation only. Orienting in a codebase means reading files and asking git — there is
    // no framework to wrap and nothing to decode.
    platforms: [
        .macOS(.v14), .iOS(.v17)
    ],
    products: [
        .library(name: "BriefKit", targets: ["BriefKit"]),
    ],
    targets: [
        .target(name: "BriefKit"),
        .testTarget(name: "BriefKitTests", dependencies: ["BriefKit"]),
    ]
)

// Swift 7's import rule, today: a file must import every module whose members
// it uses, rather than leaning on another file's imports.
for target in package.targets where target.type != .system && target.type != .binary && target.type != .plugin {
    target.swiftSettings = (target.swiftSettings ?? []) + [.enableUpcomingFeature("MemberImportVisibility")]
}
