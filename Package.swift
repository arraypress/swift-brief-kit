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
