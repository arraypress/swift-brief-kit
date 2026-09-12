//
//  Commands.swift
//  BriefKit
//
//  Created by David Sherlock on 2026.
//
//  How to build it, test it and run it.
//
//  The highest-value field in a brief and the one a README most often gets wrong, because a
//  README is written once and the scripts change. These come from the manifest, so they are
//  what the project can actually do today.
//

import Foundation

/// A command you can run in this repository.
public struct Command: Codable, Hashable, Sendable {

    /// What it is for — "build", "test", "run", or a script's own name.
    public let purpose: String

    /// The command line.
    public let line: String

    /// Where it came from — "Package.swift", "package.json scripts", "Makefile".
    public let source: String

    public init(purpose: String, line: String, source: String) {
        self.purpose = purpose
        self.line = line
        self.source = source
    }
}

/// A direct dependency.
public struct Dependency: Codable, Hashable, Sendable {

    public let name: String
    /// Version or requirement as written, when the manifest gives one.
    public let version: String?
    public let ecosystem: Ecosystem

    public init(name: String, version: String?, ecosystem: Ecosystem) {
        self.name = name
        self.version = version
        self.ecosystem = ecosystem
    }
}

/// Something you can execute.
public struct EntryPoint: Codable, Hashable, Sendable {

    public let name: String
    /// "executable", "library", "binary", "script".
    public let kind: String
    public let path: String?

    public init(name: String, kind: String, path: String? = nil) {
        self.name = name
        self.kind = kind
        self.path = path
    }
}
