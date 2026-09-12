//
//  WalkTests.swift
//  BriefKitTests
//
//  Created by David Sherlock on 2026.
//
//  What the walk counts, and above all what it refuses to walk into.
//

import XCTest
@testable import BriefKit

final class WalkTests: XCTestCase {

    /// The difference between a tool that answers instantly and one that walks
    /// `node_modules`. A JavaScript project's dependencies outnumber its source by orders of
    /// magnitude, so counting them makes every other number meaningless too.
    func testDependencyAndBuildDirectoriesAreNotWalked() throws {
        let box = try Sandbox()
        try box.write("package.json", Fixture.packageJSON)
        try box.write("src/index.js", "")
        for i in 0 ..< 50 { try box.write("node_modules/pkg\(i)/index.js", "") }
        for i in 0 ..< 20 { try box.write(".build/artifact\(i).js", "") }
        for i in 0 ..< 10 { try box.write("dist/bundle\(i).js", "") }

        let brief = try box.brief()
        XCTAssertEqual(brief.primary?.fileCount, 1, "only src/index.js is source")
        XCTAssertFalse(brief.layout.contains { $0.name == "node_modules" })
        XCTAssertFalse(brief.layout.contains { $0.name == "dist" })
    }

    func testEveryIgnoredDirectoryIsActuallySkipped() throws {
        for ignored in ["node_modules", ".build", "vendor", "target", "__pycache__", "Pods"] {
            let box = try Sandbox()
            try box.write("src/real.py", "")
            for i in 0 ..< 5 { try box.write("\(ignored)/junk\(i).py", "") }
            XCTAssertEqual(try box.brief().primary?.fileCount, 1, "\(ignored) was walked")
        }
    }

    func testTopLevelLayoutCountsFilesBeneathEachDirectory() throws {
        let box = try Sandbox()
        try box.write("Sources/a.swift", "")
        try box.write("Sources/deep/b.swift", "")
        try box.write("Tests/t.swift", "")
        try box.write("README.md", "")

        let brief = try box.brief()
        let sources = try XCTUnwrap(brief.layout.first { $0.name == "Sources" })
        XCTAssertEqual(sources.fileCount, 2, "nested files count toward the top-level directory")
        XCTAssertEqual(sources.role, "source")
        XCTAssertEqual(brief.layout.first { $0.name == "Tests" }?.role, "tests")
    }

    func testLayoutIsOrderedBySize() throws {
        let box = try Sandbox()
        try box.write("small/a.swift", "")
        for i in 0 ..< 5 { try box.write("big/f\(i).swift", "") }

        let brief = try box.brief()
        XCTAssertEqual(brief.layout.first?.name, "big")
    }

    func testTestsAreFoundByDirectoryName() throws {
        let box = try Sandbox()
        try box.write("Package.swift", Fixture.swiftPackage)
        try box.write("Sources/a.swift", "")
        try box.write("Tests/ExampleTests/AThing.swift", "")
        try box.write("Tests/ExampleTests/Another.swift", "")

        let brief = try box.brief()
        XCTAssertEqual(brief.tests.fileCount, 2)
        XCTAssertTrue(brief.tests.exists)
        XCTAssertTrue(brief.tests.directories.contains("Tests"))
        XCTAssertEqual(brief.tests.framework, "XCTest / swift-testing")
    }

    func testAProjectWithNoTestsSaysSo() throws {
        let box = try Sandbox()
        try box.write("Package.swift", Fixture.swiftPackage)
        try box.write("Sources/a.swift", "")

        let brief = try box.brief()
        XCTAssertEqual(brief.tests.fileCount, 0)
        XCTAssertFalse(brief.tests.exists)
        XCTAssertNil(brief.tests.framework, "no framework should be claimed with no tests")
    }

    func testDocumentsAtTheRootAreCollected() throws {
        let box = try Sandbox()
        try box.write("README.md", "")
        try box.write("CHANGELOG.md", "")
        try box.write("LICENSE", "")
        try box.write("Sources/a.swift", "")

        let brief = try box.brief()
        XCTAssertTrue(brief.documents.contains("README.md"))
        XCTAssertTrue(brief.documents.contains("CHANGELOG.md"))
        XCTAssertTrue(brief.documents.contains("LICENSE"))
    }

    func testFileAndByteCountsAreReported() throws {
        let box = try Sandbox()
        try box.write("a.swift", String(repeating: "x", count: 1000))
        try box.write("b.swift", String(repeating: "y", count: 500))

        let brief = try box.brief()
        XCTAssertEqual(brief.fileCount, 2)
        XCTAssertEqual(brief.byteCount, 1500)
    }

    /// Somebody will eventually point this at a home directory.
    func testTheWalkStopsAtItsLimit() throws {
        let box = try Sandbox()
        for i in 0 ..< 30 { try box.write("src/f\(i).swift", "") }

        let survey = try Walker.survey(box.root, fileLimit: 10)
        XCTAssertTrue(survey.truncated)
        XCTAssertLessThanOrEqual(survey.fileCount, 10)
    }
}
