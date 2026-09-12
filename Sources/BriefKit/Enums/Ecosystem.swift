//
//  Ecosystem.swift
//  BriefKit
//
//  Created by David Sherlock on 2026.
//
//  What a codebase is written in, and how you would know.
//

import Foundation

/// A language and its tooling.
public enum Ecosystem: String, Codable, Hashable, Sendable, CaseIterable {
    case swift
    case node
    case python
    case rust
    case php
    case go
    case ruby

    /// Manifest filenames that identify this ecosystem, strongest evidence first.
    public var manifests: [String] {
        switch self {
        case .swift:  return ["Package.swift"]
        case .node:   return ["package.json"]
        case .python: return ["pyproject.toml", "setup.py", "setup.cfg", "requirements.txt", "Pipfile"]
        case .rust:   return ["Cargo.toml"]
        case .php:    return ["composer.json"]
        case .go:     return ["go.mod"]
        case .ruby:   return ["Gemfile", "*.gemspec"]
        }
    }

    /// Source file extensions, used when there is no manifest at all.
    ///
    /// NOT decoration — this is the only way some real codebases are detectable. A probe of
    /// this machine found Python living in two directories as loose `.py` scripts with no
    /// `pyproject.toml`, `setup.py` or `requirements.txt` anywhere. A manifest-only detector
    /// would report those as "nothing here".
    public var extensions: [String] {
        switch self {
        case .swift:  return ["swift"]
        case .node:   return ["js", "mjs", "cjs", "ts", "tsx", "jsx"]
        case .python: return ["py"]
        case .rust:   return ["rs"]
        case .php:    return ["php"]
        case .go:     return ["go"]
        case .ruby:   return ["rb"]
        }
    }

    public var displayName: String {
        switch self {
        case .swift:  return "Swift"
        case .node:   return "JavaScript / TypeScript"
        case .python: return "Python"
        case .rust:   return "Rust"
        case .php:    return "PHP"
        case .go:     return "Go"
        case .ruby:   return "Ruby"
        }
    }
}

/// How sure the detection is, and why.
public struct Detection: Codable, Hashable, Sendable {

    public let ecosystem: Ecosystem

    /// The manifest that identified it, relative to the root, if there was one.
    public let manifest: String?

    /// How many source files of this ecosystem were found.
    public let fileCount: Int

    /// Manifests found below the root — a workspace's members.
    ///
    /// Workspaces are the normal case, not the exception: a probe of this machine found a
    /// JavaScript project with 19 `package.json` files and a Rust project with 67
    /// `Cargo.toml`. Reporting only the root manifest would describe one crate of sixty-seven.
    public let memberManifests: [String]

    /// Whether a manifest identified this, rather than loose source files alone.
    public var isDeclared: Bool { manifest != nil }

    /// Whether this looks like a workspace of several packages.
    public var isWorkspace: Bool { memberManifests.count > 1 }

    public init(ecosystem: Ecosystem, manifest: String?, fileCount: Int,
                memberManifests: [String] = []) {
        self.ecosystem = ecosystem
        self.manifest = manifest
        self.fileCount = fileCount
        self.memberManifests = memberManifests
    }
}
