//
//  BriefError.swift
//  BriefKit
//
//  Created by David Sherlock on 2026.
//

import Foundation

/// What can go wrong briefing a directory.
public enum BriefError: Error, Equatable, Sendable {

    /// The path does not exist.
    case noSuchPath(String)

    /// The path is a file, not a directory.
    case notADirectory(String)

    /// The directory could not be walked.
    case unreadable(String)
}

extension BriefError: LocalizedError {

    public var errorDescription: String? {
        switch self {
        case .noSuchPath(let path):     return "no such directory: \(path)"
        case .notADirectory(let path):  return "not a directory: \(path)"
        case .unreadable(let path):     return "could not read: \(path)"
        }
    }
}
