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

// MARK: - Errors

extension Path {
    /// Errors that can occur during path construction.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The path string is empty.
        case empty
        /// The path contains ASCII control characters (0x00-0x1F, 0x7F).
        case containsControlCharacters
        /// The path contains an interior NUL byte.
        case containsInteriorNUL
    }
}

extension Path.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .empty:
            return "Path is empty"
        case .containsControlCharacters:
            return "Path contains control characters"
        case .containsInteriorNUL:
            return "Path contains interior NUL byte"
        }
    }
}
