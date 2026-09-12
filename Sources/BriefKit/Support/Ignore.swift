//
//  Ignore.swift
//  BriefKit
//
//  Created by David Sherlock on 2026.
//
//  Directories not to walk into.
//
//  This is the difference between a tool that answers in a moment and one that walks
//  `node_modules`. It is a fixed list rather than a `.gitignore` parser on purpose: the
//  directories that make a walk slow are the same everywhere, and a gitignore parser is a
//  project of its own with pattern semantics that are easy to get subtly wrong.
//

import Foundation

public enum Ignore {

    /// Directory names never descended into.
    public static let directories: Set<String> = [
        // Build output
        ".build", "build", "DerivedData", "dist", "out", "target", "_build",
        ".next", ".nuxt", ".svelte-kit", ".parcel-cache", ".turbo",
        // Dependencies
        "node_modules", "vendor", "Pods", "Carthage", ".bundle",
        "site-packages", ".venv", "venv", "env", "virtualenv",
        // Tooling state
        ".git", ".svn", ".hg", ".swiftpm", ".idea", ".vscode", ".gradle",
        ".pytest_cache", "__pycache__", ".mypy_cache", ".ruff_cache", ".tox",
        ".cache", ".sass-cache", ".terraform",
        // macOS
        ".Trash", ".DS_Store"
    ]

    // NOTE: the walk also passes `.skipsHiddenFiles`, so every dot-directory is already
    // excluded before this list is consulted — `.github` included. That is deliberate: the
    // build and test commands come from the manifest, which is the file that has to be
    // right for the project to work at all, where a CI workflow can be stale for months
    // without anyone noticing.

    /// Directory names that mean "the tests are in here".
    public static let testDirectories: Set<String> = [
        "tests", "test", "spec", "specs", "__tests__", "testing"
    ]

    /// Whether a path component suggests test code.
    public static func looksLikeTests(_ name: String) -> Bool {
        let lower = name.lowercased()
        return testDirectories.contains(lower) || lower.hasSuffix("tests") || lower.hasSuffix("test")
    }
}
