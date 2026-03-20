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

// MARK: - Path Component Stem

extension Path.Component {
    /// A validated filename stem (the part before the last dot in a filename).
    ///
    /// Stems cannot contain path separators or control characters.
    /// Unlike extensions, stems may contain dots (e.g., "archive.tar" is a valid stem).
    ///
    /// ```swift
    /// let stem = try Path.Component.Stem("readme")
    /// print(stem.string)  // "readme"
    ///
    /// let dotted = try Path.Component.Stem("archive.tar")
    /// print(dotted.string)  // "archive.tar"
    /// ```
    public struct Stem: Copyable, Sendable, Hashable {
        /// The validated stem string.
        @usableFromInline
        internal let _value: Swift.String

        /// Creates a stem from a string, validating the contents.
        ///
        /// - Parameter string: The stem string.
        /// - Throws: `Stem.Error` if the string is invalid.
        @inlinable
        public init(_ string: Swift.String) throws(Error) {
            guard !string.isEmpty else {
                throw .empty
            }

            for scalar in string.unicodeScalars {
                let value = scalar.value

                // Check for path separators
                #if os(Windows)
                if scalar == "/" || scalar == "\\" {
                    throw .containsPathSeparator
                }
                #else
                if scalar == "/" {
                    throw .containsPathSeparator
                }
                #endif

                // Check for control characters (0x00-0x1F, 0x7F)
                if value < 0x20 || value == 0x7F {
                    throw .containsControlCharacters
                }
            }

            self._value = string
        }

        /// Creates a stem from a validated string.
        @usableFromInline
        internal init(unchecked value: Swift.String) {
            self._value = value
        }
    }
}

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

// MARK: - String Conversion

extension Path.Component.Stem {
    /// The stem as a String.
    @inlinable
    public var string: Swift.String {
        _value
    }
}

extension Swift.String {
    /// Creates a string from a path component stem.
    @inlinable
    public init(_ stem: Path.Component.Stem) {
        self = stem.string
    }
}

// MARK: - CustomStringConvertible

extension Path.Component.Stem: CustomStringConvertible {
    public var description: Swift.String {
        string
    }
}

// MARK: - CustomDebugStringConvertible

extension Path.Component.Stem: CustomDebugStringConvertible {
    public var debugDescription: Swift.String {
        "Path.Component.Stem(\"\(string)\")"
    }
}

// MARK: - ExpressibleByStringLiteral

extension Path.Component.Stem: ExpressibleByStringLiteral {
    /// Creates a stem from a string literal.
    ///
    /// - Warning: Crashes at runtime if the string is invalid.
    ///   For safe construction, use `try Path.Component.Stem(_:)`.
    ///
    /// ```swift
    /// let stem: Path.Component.Stem = "readme"
    /// ```
    @inlinable
    public init(stringLiteral value: Swift.String) {
        do {
            try self.init(value)
        } catch {
            fatalError("Invalid stem literal: \(value) (\(error))")
        }
    }
}
