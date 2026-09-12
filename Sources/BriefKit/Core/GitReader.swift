//
//  GitReader.swift
//  BriefKit
//
//  Created by David Sherlock on 2026.
//
//  What git already knows about a repository.
//
//  Shelling out to `git` rather than parsing `.git` by hand. Reading loose objects, packfiles
//  and ref formats correctly is a library's worth of work, and git is already installed
//  everywhere this runs — the only cost is a process, and there are four of them.
//

import Foundation

/// The repository's state.
public struct GitState: Codable, Hashable, Sendable {

    public let branch: String?
    public let uncommittedFiles: Int
    public let latestTag: String?
    public let recentCommits: [Commit]

    /// Files touched most often lately — where the work actually is.
    public let churn: [ChurnEntry]

    /// Whether the working tree is clean.
    public var isClean: Bool { uncommittedFiles == 0 }

    public init(branch: String?, uncommittedFiles: Int, latestTag: String?,
                recentCommits: [Commit], churn: [ChurnEntry]) {
        self.branch = branch
        self.uncommittedFiles = uncommittedFiles
        self.latestTag = latestTag
        self.recentCommits = recentCommits
        self.churn = churn
    }

    public struct Commit: Codable, Hashable, Sendable {
        public let hash: String
        public let subject: String
        public let date: String
        public let author: String

        public init(hash: String, subject: String, date: String, author: String) {
            self.hash = hash
            self.subject = subject
            self.date = date
            self.author = author
        }
    }

    public struct ChurnEntry: Codable, Hashable, Sendable {
        public let path: String
        public let changes: Int

        public init(path: String, changes: Int) {
            self.path = path
            self.changes = changes
        }
    }
}

public enum GitReader {

    /// Read a repository's state, or nil if this is not one.
    public static func read(at root: URL, commitLimit: Int = 5, churnLimit: Int = 5) -> GitState? {
        guard run(["rev-parse", "--is-inside-work-tree"], at: root)?
            .trimmingCharacters(in: .whitespacesAndNewlines) == "true" else { return nil }

        let branch = run(["rev-parse", "--abbrev-ref", "HEAD"], at: root)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let status = run(["status", "--porcelain"], at: root) ?? ""
        let uncommitted = status.split(separator: "\n").filter { !$0.isEmpty }.count

        let tag = run(["tag", "--sort=-v:refname"], at: root)?
            .split(separator: "\n").first.map(String.init)

        // A unit separator between fields: a commit subject can contain anything a person
        // can type, including whatever delimiter looked safe.
        let log = run(["log", "-n", "\(commitLimit)", "--date=short",
                       "--format=%h\u{1F}%s\u{1F}%ad\u{1F}%an"], at: root) ?? ""
        let commits = log.split(separator: "\n").compactMap { line -> GitState.Commit? in
            let parts = line.split(separator: "\u{1F}", omittingEmptySubsequences: false)
            guard parts.count == 4 else { return nil }
            return GitState.Commit(hash: String(parts[0]), subject: String(parts[1]),
                                   date: String(parts[2]), author: String(parts[3]))
        }

        return GitState(branch: branch, uncommittedFiles: uncommitted, latestTag: tag,
                        recentCommits: commits, churn: churn(at: root, limit: churnLimit))
    }

    /// Which files have been touched most in recent history.
    ///
    /// Bounded to the last 200 commits: churn means "where the work is now", and averaging it
    /// over the whole history of an old repository answers a different and less useful
    /// question.
    static func churn(at root: URL, limit: Int) -> [GitState.ChurnEntry] {
        guard let log = run(["log", "-n", "200", "--name-only", "--format="], at: root)
        else { return [] }
        var counts: [String: Int] = [:]
        for line in log.split(separator: "\n") {
            let path = line.trimmingCharacters(in: .whitespaces)
            guard !path.isEmpty else { continue }
            counts[path, default: 0] += 1
        }
        return counts.sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .prefix(limit)
            .map { GitState.ChurnEntry(path: $0.key, changes: $0.value) }
    }

    /// Run git, returning stdout, or nil if it failed.
    @discardableResult
    static func run(_ arguments: [String], at root: URL) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
        process.arguments = ["git", "-C", root.path] + arguments
        let output = Pipe()
        process.standardOutput = output
        // Discarded rather than inherited: "not a git repository" on the terminal is noise
        // when the tool is about to say so itself, in its own words.
        process.standardError = Pipe()
        do { try process.run() } catch { return nil }
        let data = output.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else { return nil }
        return String(decoding: data, as: UTF8.self)
    }
}
