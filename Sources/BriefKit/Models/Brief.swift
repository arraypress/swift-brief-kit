//
//  Brief.swift
//  BriefKit
//
//  Created by David Sherlock on 2026.
//
//  What a codebase is, in one value.
//

import Foundation

/// A directory, and how much of it is what.
public struct DirectorySummary: Codable, Hashable, Sendable {

    public let name: String
    public let fileCount: Int
    /// What the name and contents suggest it holds — "source", "tests", "docs", "config".
    public let role: String

    public init(name: String, fileCount: Int, role: String) {
        self.name = name
        self.fileCount = fileCount
        self.role = role
    }
}

/// Where the tests are and how many there seem to be.
public struct TestSummary: Codable, Hashable, Sendable {

    public let directories: [String]
    public let fileCount: Int
    /// The framework, when one is identifiable.
    public let framework: String?

    /// Whether anything test-shaped was found at all.
    public var exists: Bool { fileCount > 0 || !directories.isEmpty }

    public init(directories: [String], fileCount: Int, framework: String?) {
        self.directories = directories
        self.fileCount = fileCount
        self.framework = framework
    }
}

/// Everything the tool knows about a codebase.
public struct Brief: Codable, Hashable, Sendable {

    /// The directory briefed.
    public let path: String

    /// Its name — the last path component.
    public let name: String

    /// Languages found, most files first.
    public let ecosystems: [Detection]

    /// Git state, or nil if this is not a repository.
    public let git: GitState?

    /// Top-level directories with what they appear to hold.
    public let layout: [DirectorySummary]

    /// How to build, test and run.
    public let commands: [Command]

    /// Direct dependencies.
    public let dependencies: [Dependency]

    /// What this produces.
    public let entryPoints: [EntryPoint]

    /// Tests.
    public let tests: TestSummary

    /// Total files counted, excluding ignored directories.
    public let fileCount: Int

    /// Total bytes of those files.
    public let byteCount: Int

    /// Documentation found at the root.
    public let documents: [String]

    /// Whether the walk hit its limit — everything here describes a prefix of the tree.
    public let truncated: Bool

    /// The primary language, by file count.
    public var primary: Detection? { ecosystems.first }

    /// The commands most people want, in the order they want them.
    ///
    /// A repository can expose forty npm scripts; three of them are the ones anybody runs
    /// first, and a brief that lists all forty has not briefed anything.
    public var headlineCommands: [Command] {
        let wanted = ["build", "test", "run", "start", "dev", "lint"]
        var picked: [Command] = []
        for purpose in wanted {
            if let match = commands.first(where: { $0.purpose.lowercased() == purpose }) {
                picked.append(match)
            }
        }
        return picked
    }
}
