//
//  Fixtures.swift
//  BriefKitTests
//
//  Created by David Sherlock on 2026.
//
//  Codebases built in a temporary directory, so every assertion has a known answer.
//
//  Real repositories are not used as fixtures, with one exception noted in
//  ``RealRepositoryTests``. A test that reads the repository it lives in passes or fails
//  depending on what somebody committed that morning.
//

import Foundation
import XCTest
@testable import BriefKit

/// Builds a throwaway directory tree.
final class Sandbox {

    let root: URL

    init() throws {
        root = URL(fileURLWithPath: NSTemporaryDirectory())
            .appendingPathComponent("briefkit-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
    }

    deinit { try? FileManager.default.removeItem(at: root) }

    /// Write a file, creating the directories above it.
    @discardableResult
    func write(_ relativePath: String, _ contents: String = "") throws -> URL {
        let url = root.appendingPathComponent(relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try contents.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    /// Create a directory, even an empty one.
    func directory(_ relativePath: String) throws {
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent(relativePath), withIntermediateDirectories: true)
    }

    func brief(includeGit: Bool = false) throws -> Brief {
        try Briefer.brief(path: root.path, includeGit: includeGit)
    }

    /// Run git in the sandbox, for the tests that need a real repository.
    @discardableResult
    func git(_ arguments: [String]) -> String? {
        GitReader.run(arguments, at: root)
    }

    /// A repository with one commit, so git assertions have something to read.
    func makeRepository() throws {
        _ = git(["init", "-q", "-b", "main"])
        _ = git(["config", "user.email", "test@example.com"])
        _ = git(["config", "user.name", "Test"])
        _ = git(["add", "-A"])
        _ = git(["commit", "-q", "-m", "first"])
    }
}

// MARK: - Manifest contents

enum Fixture {

    static let swiftPackage = """
    // swift-tools-version: 6.2
    import PackageDescription
    let package = Package(
        name: "example",
        products: [
            .library(name: "ExampleKit", targets: ["ExampleKit"]),
            .executable(name: "example", targets: ["Example"]),
        ],
        dependencies: [
            .package(url: "https://github.com/apple/swift-argument-parser.git", from: "1.5.0"),
            .package(path: "../sibling-kit"),
        ],
        targets: [.target(name: "ExampleKit"), .executableTarget(name: "Example")]
    )
    """

    static let packageJSON = """
    {
      "name": "@scope/thing",
      "main": "dist/index.js",
      "bin": { "thing": "bin/cli.js" },
      "scripts": { "build": "tsc", "test": "vitest run", "dev": "vite" },
      "dependencies": { "react": "^18.0.0" },
      "devDependencies": { "vitest": "^1.0.0" }
    }
    """

    static let cargoPackage = """
    [package]
    name = "thing"
    version = "0.1.0"

    [dependencies]
    serde = "1.0"
    anyhow = { version = "1.0", features = ["backtrace"] }

    [dev-dependencies]
    criterion = "0.5"

    [profile.release]
    opt-level = 3
    """

    static let cargoWorkspace = """
    [workspace]
    resolver = "2"
    members = ["crates/one", "crates/two"]

    [profile.release]
    opt-level = 3
    """

    static let composerJSON = """
    {
      "name": "vendor/thing",
      "require": { "php": ">=8.1", "guzzlehttp/guzzle": "^7.0" },
      "scripts": { "test": "phpunit" }
    }
    """

    static let makefile = """
    .PHONY: build test
    build:
    \tswift build
    test:
    \tswift test
    %.o: %.c
    \tcc -c $<
    """
}
