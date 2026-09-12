//
//  Walker.swift
//  BriefKit
//
//  Created by David Sherlock on 2026.
//
//  One pass over a directory tree, collecting everything the brief needs.
//
//  ONE PASS, not several. Every question a brief answers — what languages, how big, where
//  the tests are, which manifests exist — is answerable from the same walk, and a tool whose
//  whole promise is "faster than the twenty commands you would otherwise run" cannot walk
//  the tree twenty times to deliver it.
//

import Foundation

/// What a walk found.
public struct Survey: Sendable {

    /// Files per extension, lowercased and without the dot.
    public var extensionCounts: [String: Int] = [:]

    /// Manifest paths found, relative to the root.
    public var manifests: [String] = []

    /// Immediate subdirectories, with how many files are beneath each.
    public var topLevelDirectories: [String: Int] = [:]

    /// Files that look like tests.
    public var testFileCount: Int = 0

    /// Directories that look like test roots, relative to the root.
    public var testDirectories: [String] = []

    /// Every file counted.
    public var fileCount: Int = 0

    /// Total bytes of the files counted.
    public var byteCount: Int = 0

    /// Files at the root, which is where README, LICENSE and CI config live.
    public var rootFiles: [String] = []

    /// Whether the walk stopped early because the tree was enormous.
    public var truncated: Bool = false
}

public enum Walker {

    /// Every manifest filename worth noticing, across all ecosystems.
    static let manifestNames: Set<String> = {
        var names = Set<String>()
        for ecosystem in Ecosystem.allCases {
            for manifest in ecosystem.manifests where !manifest.contains("*") {
                names.insert(manifest)
            }
        }
        names.formUnion(["Makefile", "Justfile", "justfile", "Rakefile", "Dockerfile",
                         "docker-compose.yml", "Package.resolved", "package-lock.json",
                         "yarn.lock", "pnpm-lock.yaml", "Cargo.lock", "composer.lock"])
        return names
    }()

    /// Walk a directory.
    ///
    /// - Parameters:
    ///   - root: where to start.
    ///   - fileLimit: stop after this many files and set ``Survey/truncated``. A limit rather
    ///     than no limit because a brief is meant to be instant, and somebody will eventually
    ///     point this at a home directory.
    public static func survey(_ root: URL, fileLimit: Int = 200_000) throws -> Survey {
        var survey = Survey()
        let manager = FileManager.default

        guard let walker = manager.enumerator(
            at: root,
            includingPropertiesForKeys: [.isDirectoryKey, .fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            throw BriefError.unreadable(root.path)
        }

        while let item = walker.nextObject() as? URL {
            let values = try? item.resourceValues(forKeys: [.isDirectoryKey, .fileSizeKey])
            let relative = relativePath(of: item, from: root)
            let components = relative.split(separator: "/").map(String.init)

            if values?.isDirectory == true {
                if Ignore.directories.contains(item.lastPathComponent) {
                    walker.skipDescendants()
                    continue
                }
                if components.count == 1 { survey.topLevelDirectories[item.lastPathComponent] = 0 }
                if Ignore.looksLikeTests(item.lastPathComponent) {
                    survey.testDirectories.append(relative)
                }
                continue
            }

            survey.fileCount += 1
            survey.byteCount += values?.fileSize ?? 0
            if survey.fileCount >= fileLimit { survey.truncated = true; break }

            let name = item.lastPathComponent
            let ext = item.pathExtension.lowercased()
            if !ext.isEmpty { survey.extensionCounts[ext, default: 0] += 1 }
            if manifestNames.contains(name) { survey.manifests.append(relative) }
            if components.count == 1 { survey.rootFiles.append(name) }
            if let top = components.first, components.count > 1 {
                survey.topLevelDirectories[top, default: 0] += 1
            }
            if components.contains(where: Ignore.looksLikeTests) || Ignore.looksLikeTests(
                item.deletingPathExtension().lastPathComponent) {
                survey.testFileCount += 1
            }
        }

        survey.manifests.sort { $0.split(separator: "/").count < $1.split(separator: "/").count }
        survey.testDirectories.sort()
        survey.rootFiles.sort()
        return survey
    }

    /// A path relative to the root, with no leading slash.
    static func relativePath(of url: URL, from root: URL) -> String {
        let full = url.standardizedFileURL.path
        let base = root.standardizedFileURL.path
        guard full.hasPrefix(base) else { return url.lastPathComponent }
        return String(full.dropFirst(base.count).drop(while: { $0 == "/" }))
    }
}
