// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-path open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-path project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// MARK: - Stem Errors

extension Path.Component.Stem {
    /// Errors that can occur during stem construction.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The stem string is empty.
        case empty
        /// The stem contains a path separator.
        case containsPathSeparator
        /// The stem contains ASCII control characters.
        case containsControlCharacters
    }
}

extension Path.Component.Stem.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .empty:
            return "Stem is empty"
        case .containsPathSeparator:
            return "Stem contains path separator"
        case .containsControlCharacters:
            return "Stem contains control characters"
        }
    }
}
