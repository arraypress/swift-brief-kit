//
//  GitTests.swift
//  BriefKitTests
//
//  Created by David Sherlock on 2026.
//
//  Reading a real repository, made in a temporary directory.
//

import XCTest
@testable import BriefKit

final class GitTests: XCTestCase {

    func testANonRepositoryHasNoGitState() throws {
        let box = try Sandbox()
        try box.write("a.swift", "")
        XCTAssertNil(GitReader.read(at: box.root))
        XCTAssertNil(try box.brief(includeGit: true).git)
    }

    func testBranchAndCleanlinessAreRead() throws {
        let box = try Sandbox()
        try box.write("a.swift", "")
        try box.makeRepository()

        let git = try XCTUnwrap(GitReader.read(at: box.root))
        XCTAssertEqual(git.branch, "main")
        XCTAssertTrue(git.isClean)
        XCTAssertEqual(git.uncommittedFiles, 0)
    }

    func testUncommittedFilesAreCounted() throws {
        let box = try Sandbox()
        try box.write("a.swift", "")
        try box.makeRepository()
        try box.write("b.swift", "new")
        try box.write("c.swift", "also new")

        let git = try XCTUnwrap(GitReader.read(at: box.root))
        XCTAssertFalse(git.isClean)
        XCTAssertEqual(git.uncommittedFiles, 2)
    }

    func testTheLatestTagIsRead() throws {
        let box = try Sandbox()
        try box.write("a.swift", "")
        try box.makeRepository()
        _ = box.git(["tag", "v0.1.0"])
        _ = box.git(["tag", "v0.10.0"])
        _ = box.git(["tag", "v0.2.0"])

        // Version sorting, not alphabetical — v0.10.0 is newer than v0.2.0 and a plain sort
        // disagrees.
        XCTAssertEqual(GitReader.read(at: box.root)?.latestTag, "v0.10.0")
    }

    func testRecentCommitsAreReadWithTheirFields() throws {
        let box = try Sandbox()
        try box.write("a.swift", "")
        try box.makeRepository()

        let git = try XCTUnwrap(GitReader.read(at: box.root))
        let commit = try XCTUnwrap(git.recentCommits.first)
        XCTAssertEqual(commit.subject, "first")
        XCTAssertEqual(commit.author, "Test")
        XCTAssertFalse(commit.hash.isEmpty)
        XCTAssertEqual(commit.date.count, 10, "an ISO date, not a timestamp")
    }

    /// A commit subject can contain anything a person can type, including whatever delimiter
    /// looked safe — hence the unit separator.
    func testACommitSubjectWithAwkwardCharactersSurvives() throws {
        let box = try Sandbox()
        try box.write("a.swift", "")
        _ = box.git(["init", "-q", "-b", "main"])
        _ = box.git(["config", "user.email", "t@e.com"])
        _ = box.git(["config", "user.name", "Test"])
        _ = box.git(["add", "-A"])
        _ = box.git(["commit", "-q", "-m", "fix: a|b, c\ttab — and 'quotes'"])

        let commit = try XCTUnwrap(GitReader.read(at: box.root)?.recentCommits.first)
        XCTAssertEqual(commit.subject, "fix: a|b, c\ttab — and 'quotes'")
        XCTAssertEqual(commit.author, "Test", "the fields after it must still line up")
    }

    func testChurnCountsTheFilesTouchedMost() throws {
        let box = try Sandbox()
        try box.write("busy.swift", "1")
        try box.write("quiet.swift", "1")
        try box.makeRepository()
        for i in 2 ... 4 {
            try box.write("busy.swift", "\(i)")
            _ = box.git(["add", "-A"])
            _ = box.git(["commit", "-q", "-m", "change \(i)"])
        }

        let churn = try XCTUnwrap(GitReader.read(at: box.root)?.churn)
        XCTAssertEqual(churn.first?.path, "busy.swift")
        XCTAssertEqual(churn.first?.changes, 4)
        XCTAssertEqual(churn.first(where: { $0.path == "quiet.swift" })?.changes, 1)
    }

    /// Four processes is the cost; a caller who does not want to pay it can say so.
    func testGitCanBeSkipped() throws {
        let box = try Sandbox()
        try box.write("a.swift", "")
        try box.makeRepository()
        XCTAssertNil(try box.brief(includeGit: false).git)
        XCTAssertNotNil(try box.brief(includeGit: true).git)
    }

    func testAFreshRepositoryWithNoCommitsDoesNotCrash() throws {
        let box = try Sandbox()
        try box.write("a.swift", "")
        _ = box.git(["init", "-q", "-b", "main"])

        let git = GitReader.read(at: box.root)
        XCTAssertNotNil(git, "an empty repository is still a repository")
        XCTAssertTrue(git?.recentCommits.isEmpty ?? false)
        XCTAssertNil(git?.latestTag)
    }
}
