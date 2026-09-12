//
//  Briefer.swift
//  BriefKit
//
//  Created by David Sherlock on 2026.
//
//  The whole job: a directory in, a ``Brief`` out.
//

import Foundation

public enum Briefer {

    /// Brief a directory.
    ///
    /// - Parameters:
    ///   - path: the directory to look at.
    ///   - includeGit: ask git about branch, tags, churn and recent commits. Four processes;
    ///     pass false to skip them.
    public static func brief(path: String, includeGit: Bool = true) throws -> Brief {
        let root = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
            .standardizedFileURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: root.path, isDirectory: &isDirectory) else {
            throw BriefError.noSuchPath(path)
        }
        guard isDirectory.boolValue else { throw BriefError.notADirectory(path) }

        let survey = try Walker.survey(root)
        let ecosystems = detect(survey: survey)
        let read = ManifestReader.read(root: root, survey: survey, ecosystems: ecosystems)

        return Brief(
            path: root.path,
            name: root.lastPathComponent,
            ecosystems: ecosystems,
            git: includeGit ? GitReader.read(at: root) : nil,
            layout: layout(survey: survey),
            commands: read.commands,
            dependencies: read.dependencies,
            entryPoints: read.entryPoints,
            tests: tests(survey: survey, ecosystems: ecosystems),
            fileCount: survey.fileCount,
            byteCount: survey.byteCount,
            documents: survey.rootFiles.filter { name in
                let lower = name.lowercased()
                return lower.hasPrefix("readme") || lower.hasPrefix("changelog")
                    || lower.hasPrefix("contributing") || lower.hasPrefix("licen")
                    || lower.hasSuffix(".md") && lower != "claude.md"
            },
            truncated: survey.truncated
        )
    }

    /// Which ecosystems are present, most files first.
    static func detect(survey: Survey) -> [Detection] {
        var found: [Detection] = []
        for ecosystem in Ecosystem.allCases {
            let files = ecosystem.extensions.reduce(0) { $0 + (survey.extensionCounts[$1] ?? 0) }
            let manifests = survey.manifests.filter { path in
                let name = (path as NSString).lastPathComponent
                return ecosystem.manifests.contains(name)
            }
            // A manifest with no source files is still a real project — a freshly initialised
            // one — and source files with no manifest are still a real project, which is how
            // loose Python scripts show up. Either alone is enough.
            guard files > 0 || !manifests.isEmpty else { continue }
            // The shallowest manifest is the root one; the rest are workspace members.
            found.append(Detection(ecosystem: ecosystem, manifest: manifests.first,
                                   fileCount: files, memberManifests: manifests))
        }
        return found.sorted { ($0.fileCount, $0.isDeclared ? 1 : 0) > ($1.fileCount, $1.isDeclared ? 1 : 0) }
    }

    /// Top-level directories, largest first, with a guess at what each is for.
    static func layout(survey: Survey) -> [DirectorySummary] {
        survey.topLevelDirectories
            .filter { $0.value > 0 }
            .sorted { ($0.value, $1.key) > ($1.value, $0.key) }
            .map { DirectorySummary(name: $0.key, fileCount: $0.value, role: role(of: $0.key)) }
    }

    /// What a directory name conventionally means.
    ///
    /// A guess from the name, and labelled as a role rather than a fact — a directory called
    /// "lib" holding documentation is unusual but not impossible.
    static func role(of name: String) -> String {
        let lower = name.lowercased()
        if Ignore.looksLikeTests(lower) { return "tests" }
        switch lower {
        case "sources", "src", "lib", "app", "source":        return "source"
        case "docs", "doc", "documentation":                  return "docs"
        case "scripts", "bin", "tools":                       return "scripts"
        case ".github", "ci", "config", "conf", "etc":        return "config"
        case "examples", "example", "samples", "demo":        return "examples"
        case "assets", "resources", "static", "public":       return "assets"
        case "migrations", "db", "database":                  return "data"
        default:                                              return "—"
        }
    }

    /// Where the tests are, and what runs them.
    static func tests(survey: Survey, ecosystems: [Detection]) -> TestSummary {
        let framework: String?
        switch ecosystems.first?.ecosystem {
        case .swift:  framework = "XCTest / swift-testing"
        case .node:   framework = survey.rootFiles.contains { $0.hasPrefix("vitest") } ? "Vitest" : "npm test"
        case .python: framework = "pytest"
        case .rust:   framework = "cargo test"
        case .php:    framework = "PHPUnit"
        case .go:     framework = "go test"
        case .ruby:   framework = "RSpec"
        case nil:     framework = nil
        }
        return TestSummary(directories: survey.testDirectories,
                           fileCount: survey.testFileCount,
                           framework: survey.testFileCount > 0 ? framework : nil)
    }
}
