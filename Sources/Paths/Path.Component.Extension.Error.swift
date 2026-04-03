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

// MARK: - Extension Errors

extension Path.Component.Extension {
    /// Errors that can occur during extension construction.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The extension string is empty.
        case empty
        /// The extension contains a dot.
        case containsDot
        /// The extension contains a path separator.
        case containsPathSeparator
        /// The extension contains ASCII control characters.
        case containsControlCharacters
    }
}

extension Path.Component.Extension.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .empty:
            return "Extension is empty"
        case .containsDot:
            return "Extension contains dot"
        case .containsPathSeparator:
            return "Extension contains path separator"
        case .containsControlCharacters:
            return "Extension contains control characters"
        }
    }
}
