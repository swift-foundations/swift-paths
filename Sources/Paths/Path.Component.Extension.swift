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

// MARK: - Path Component Extension

extension Path.Component {
    /// A validated file extension (the part after the last dot in a filename).
    ///
    /// Extensions cannot contain dots, path separators, or control characters.
    ///
    /// ```swift
    /// let ext = try Path.Component.Extension("txt")
    /// print(ext.string)  // "txt"
    ///
    /// let invalid = try? Path.Component.Extension("tar.gz")
    /// // nil — contains dot
    /// ```
    public struct Extension: Copyable, Sendable, Hashable {
        /// The validated extension string (without leading dot).
        @usableFromInline
        internal let _value: Swift.String

        /// Creates an extension from a string, validating the contents.
        ///
        /// - Parameter string: The extension string (without leading dot).
        /// - Throws: `Extension.Error` if the string is invalid.
        @inlinable
        public init(_ string: Swift.String) throws(Error) {
            guard !string.isEmpty else {
                throw .empty
            }

            for scalar in string.unicodeScalars {
                let value = scalar.value

                // Check for dot
                if scalar == "." {
                    throw .containsDot
                }

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

        /// Creates an extension from a validated string.
        @usableFromInline
        internal init(unchecked value: Swift.String) {
            self._value = value
        }
    }
}

// MARK: - String Conversion

extension Path.Component.Extension {
    /// The extension as a String.
    @inlinable
    public var string: Swift.String {
        _value
    }
}

extension Swift.String {
    /// Creates a string from a path component extension.
    @inlinable
    public init(_ ext: Path.Component.Extension) {
        self = ext.string
    }
}

// MARK: - CustomStringConvertible

extension Path.Component.Extension: CustomStringConvertible {
    public var description: Swift.String {
        string
    }
}

// MARK: - CustomDebugStringConvertible

extension Path.Component.Extension: CustomDebugStringConvertible {
    public var debugDescription: Swift.String {
        "Path.Component.Extension(\"\(string)\")"
    }
}

// MARK: - ExpressibleByStringLiteral

extension Path.Component.Extension: ExpressibleByStringLiteral {
    /// Creates an extension from a string literal.
    ///
    /// - Warning: Crashes at runtime if the string is invalid.
    ///   For safe construction, use `try Path.Component.Extension(_:)`.
    ///
    /// ```swift
    /// let ext: Path.Component.Extension = "txt"
    /// ```
    @inlinable
    public init(stringLiteral value: Swift.String) {
        do {
            try self.init(value)
        } catch {
            fatalError("Invalid extension literal: \(value) (\(error))")
        }
    }
}
