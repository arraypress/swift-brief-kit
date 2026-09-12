//
//  ManifestTests.swift
//  BriefKitTests
//
//  Created by David Sherlock on 2026.
//
//  How to build it, what it depends on, what it produces.
//

import XCTest
@testable import BriefKit

final class ManifestTests: XCTestCase {

    // MARK: Swift

    func testSwiftPackageGivesCommandsProductsAndDependencies() throws {
        let box = try Sandbox()
        try box.write("Package.swift", Fixture.swiftPackage)
        try box.write("Sources/ExampleKit/A.swift", "")
        let brief = try box.brief()

        XCTAssertEqual(brief.commands.first { $0.purpose == "build" }?.line, "swift build")
        XCTAssertEqual(brief.commands.first { $0.purpose == "test" }?.line, "swift test")
        XCTAssertEqual(brief.commands.first { $0.purpose == "run" }?.line, "swift run example")

        XCTAssertEqual(brief.entryPoints.first { $0.kind == "library" }?.name, "ExampleKit")
        XCTAssertEqual(brief.entryPoints.first { $0.kind == "executable" }?.name, "example")

        XCTAssertTrue(brief.dependencies.contains { $0.name == "swift-argument-parser" },
                      "a URL dependency should be named by its repository")
        XCTAssertEqual(brief.dependencies.first { $0.name == "sibling-kit" }?.version,
                       "local path", "a path dependency is worth marking as one")
    }

    // MARK: Node

    /// There is no convention to fall back on in a JavaScript project: `npm test` on a
    /// package with no test script is a lie, so the scripts ARE the commands.
    func testNodeScriptsAreTheCommands() throws {
        let box = try Sandbox()
        try box.write("package.json", Fixture.packageJSON)
        try box.write("src/index.js", "")
        let brief = try box.brief()

        XCTAssertEqual(brief.commands.first { $0.purpose == "build" }?.line, "npm run build")
        XCTAssertEqual(brief.commands.first { $0.purpose == "dev" }?.line, "npm run dev")
        XCTAssertEqual(brief.headlineCommands.map(\.purpose), ["build", "test", "dev"])
    }

    func testNodeDependenciesIncludeDevOnes() throws {
        let box = try Sandbox()
        try box.write("package.json", Fixture.packageJSON)
        let brief = try box.brief()

        XCTAssertEqual(brief.dependencies.first { $0.name == "react" }?.version, "^18.0.0")
        XCTAssertTrue(brief.dependencies.contains { $0.name == "vitest" })
    }

    func testNodeEntryPointsCoverMainAndBin() throws {
        let box = try Sandbox()
        try box.write("package.json", Fixture.packageJSON)
        let brief = try box.brief()

        XCTAssertEqual(brief.entryPoints.first { $0.kind == "main" }?.path, "dist/index.js")
        XCTAssertEqual(brief.entryPoints.first { $0.kind == "binary" }?.name, "thing")
    }

    // MARK: Rust

    func testCargoReadsOnlyTheDependenciesTable() throws {
        let box = try Sandbox()
        try box.write("Cargo.toml", Fixture.cargoPackage)
        let brief = try box.brief()

        XCTAssertEqual(brief.dependencies.first { $0.name == "serde" }?.version, "1.0")
        XCTAssertTrue(brief.dependencies.contains { $0.name == "anyhow" })
        XCTAssertNil(brief.dependencies.first { $0.name == "anyhow" }?.version,
                     "an inline table is not a version string")
        XCTAssertFalse(brief.dependencies.contains { $0.name == "opt-level" },
                       "[profile.release] is not a dependency table")
        XCTAssertFalse(brief.dependencies.contains { $0.name == "version" },
                       "[package] is not a dependency table")
    }

    /// A workspace root declares members, not dependencies. Reporting the stray entries it
    /// happens to carry would say "1 dependency" of a project with a hundred crates.
    func testAWorkspaceRootClaimsNoDependencies() throws {
        let box = try Sandbox()
        try box.write("Cargo.toml", Fixture.cargoWorkspace)
        let brief = try box.brief()

        XCTAssertTrue(brief.dependencies.isEmpty)
        XCTAssertEqual(brief.commands.first { $0.purpose == "build" }?.line, "cargo build")
    }

    // MARK: PHP

    func testComposerGivesRequirementsAndScripts() throws {
        let box = try Sandbox()
        try box.write("composer.json", Fixture.composerJSON)
        try box.write("src/Thing.php", "<?php")
        let brief = try box.brief()

        XCTAssertEqual(brief.dependencies.first { $0.name == "guzzlehttp/guzzle" }?.version, "^7.0")
        XCTAssertEqual(brief.commands.first { $0.purpose == "test" }?.line, "composer test")
    }

    // MARK: Make

    func testMakefileTargetsBecomeCommands() throws {
        let box = try Sandbox()
        try box.write("Makefile", Fixture.makefile)
        try box.write("Sources/a.swift", "")
        let brief = try box.brief()

        let fromMake = brief.commands.filter { $0.source == "Makefile" }
        XCTAssertTrue(fromMake.contains { $0.line == "make build" })
        XCTAssertTrue(fromMake.contains { $0.line == "make test" })
        XCTAssertFalse(fromMake.contains { $0.purpose.contains("%") },
                       "a pattern rule is not something a person runs")
        XCTAssertFalse(fromMake.contains { $0.purpose.hasPrefix(".") },
                       ".PHONY is not a target")
    }

    // MARK: Robustness

    /// A manifest half-written or mid-merge must not take the whole brief down.
    func testMalformedManifestsAreSurvived() throws {
        let box = try Sandbox()
        try box.write("package.json", "{ this is not json")
        try box.write("Cargo.toml", "[[[")
        try box.write("src/a.rs", "")

        let brief = try box.brief()
        XCTAssertEqual(brief.primary?.ecosystem, .rust)
        XCTAssertTrue(brief.dependencies.isEmpty)
        XCTAssertFalse(brief.commands.isEmpty, "cargo's commands are known regardless")
    }

    func testLoosePythonStillSuggestsHowToRunIt() throws {
        let box = try Sandbox()
        try box.write("train.py", "")
        let brief = try box.brief()
        XCTAssertTrue(brief.commands.contains { $0.purpose == "run" })
        XCTAssertTrue(brief.commands.first?.source.contains("no manifest") == true)
    }

    /// A repository can expose forty scripts; three are the ones anyone runs first.
    func testHeadlineCommandsAreOrderedAndFew() throws {
        let box = try Sandbox()
        try box.write("package.json", """
        { "name": "x", "scripts": { "zzz": "x", "test": "y", "build": "z", "lint": "l" } }
        """)
        let brief = try box.brief()
        XCTAssertEqual(brief.headlineCommands.map(\.purpose), ["build", "test", "lint"])
        XCTAssertFalse(brief.headlineCommands.contains { $0.purpose == "zzz" })
    }
}
