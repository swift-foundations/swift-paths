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

// MARK: - Component Errors

extension Path.Component {
    /// Errors that can occur during component construction.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The component string is empty.
        case empty
        /// The component contains a path separator.
        case containsPathSeparator
        /// The component contains ASCII control characters.
        case containsControlCharacters
        /// The component contains an interior NUL byte.
        case containsInteriorNUL
        /// The component contains invalid UTF-8 bytes.
        case invalidUTF8
    }
}

extension Path.Component.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .empty:
            return "Component is empty"
        case .containsPathSeparator:
            return "Component contains path separator"
        case .containsControlCharacters:
            return "Component contains control characters"
        case .containsInteriorNUL:
            return "Component contains interior NUL byte"
        case .invalidUTF8:
            return "Component contains invalid UTF-8"
        }
    }
}
