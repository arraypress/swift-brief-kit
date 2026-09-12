//
//  DetectionTests.swift
//  BriefKitTests
//
//  Created by David Sherlock on 2026.
//
//  Working out what a codebase is.
//

import XCTest
@testable import BriefKit

final class DetectionTests: XCTestCase {

    func testASwiftPackageIsDetected() throws {
        let box = try Sandbox()
        try box.write("Package.swift", Fixture.swiftPackage)
        try box.write("Sources/ExampleKit/Thing.swift", "public struct Thing {}")

        let brief = try box.brief()
        XCTAssertEqual(brief.primary?.ecosystem, .swift)
        XCTAssertEqual(brief.primary?.manifest, "Package.swift")
        XCTAssertTrue(brief.primary?.isDeclared == true)
    }

    /// The case a manifest-only detector misses entirely. A probe of this machine found two
    /// directories of Python living as loose scripts with no manifest of any kind.
    func testLooseScriptsAreDetectedWithNoManifest() throws {
        let box = try Sandbox()
        try box.write("train.py", "print('hi')")
        try box.write("tools/extract.py", "")
        try box.write("tools/probe.py", "")

        let brief = try box.brief()
        XCTAssertEqual(brief.primary?.ecosystem, .python)
        XCTAssertEqual(brief.primary?.fileCount, 3)
        XCTAssertFalse(brief.primary?.isDeclared ?? true, "there is no manifest to declare it")
    }

    /// A freshly initialised project is real even before anything is written in it.
    func testAManifestWithNoSourceFilesIsStillDetected() throws {
        let box = try Sandbox()
        try box.write("Cargo.toml", Fixture.cargoPackage)

        let brief = try box.brief()
        XCTAssertEqual(brief.primary?.ecosystem, .rust)
        XCTAssertEqual(brief.primary?.fileCount, 0)
        XCTAssertTrue(brief.primary?.isDeclared == true)
    }

    func testSeveralLanguagesAreRankedByFileCount() throws {
        let box = try Sandbox()
        try box.write("Cargo.toml", Fixture.cargoPackage)
        for i in 0 ..< 10 { try box.write("src/file\(i).rs", "") }
        try box.write("scripts/one.py", "")
        try box.write("scripts/two.py", "")

        let brief = try box.brief()
        XCTAssertEqual(brief.ecosystems.map(\.ecosystem), [.rust, .python])
        XCTAssertEqual(brief.primary?.fileCount, 10)
    }

    /// Workspaces are the normal case here, not the exception — one project on this machine
    /// holds 104 Cargo.toml and another 19 package.json.
    func testAWorkspaceIsRecognisedAndItsMembersCounted() throws {
        let box = try Sandbox()
        try box.write("Cargo.toml", Fixture.cargoWorkspace)
        try box.write("crates/one/Cargo.toml", Fixture.cargoPackage)
        try box.write("crates/two/Cargo.toml", Fixture.cargoPackage)
        try box.write("crates/one/src/lib.rs", "")

        let detection = try XCTUnwrap(box.brief().primary)
        XCTAssertTrue(detection.isWorkspace)
        XCTAssertEqual(detection.memberManifests.count, 3, "the root and both members")
        XCTAssertEqual(detection.manifest, "Cargo.toml", "the shallowest is the root")
    }

    /// A single-package project must not be called a workspace.
    func testASinglePackageIsNotAWorkspace() throws {
        let box = try Sandbox()
        try box.write("Cargo.toml", Fixture.cargoPackage)
        XCTAssertFalse(try XCTUnwrap(box.brief().primary).isWorkspace)
    }

    func testAnEmptyDirectoryBriefsWithoutFailing() throws {
        let box = try Sandbox()
        let brief = try box.brief()
        XCTAssertTrue(brief.ecosystems.isEmpty)
        XCTAssertEqual(brief.fileCount, 0)
        XCTAssertNil(brief.primary)
    }

    func testAMissingPathIsReportedNotCrashed() {
        XCTAssertThrowsError(try Briefer.brief(path: "/nope/not/here")) { error in
            XCTAssertEqual(error as? BriefError, .noSuchPath("/nope/not/here"))
        }
    }

    func testAFileIsNotADirectory() throws {
        let box = try Sandbox()
        let file = try box.write("thing.txt", "x")
        XCTAssertThrowsError(try Briefer.brief(path: file.path)) { error in
            guard case .notADirectory = (error as? BriefError) else {
                return XCTFail("expected notADirectory, got \(error)")
            }
        }
    }
}
