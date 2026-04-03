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

// MARK: - Path Component

extension Path {
    /// A single component of a path (filename or directory name).
    ///
    /// Components cannot contain path separators or control characters.
    ///
    /// ```swift
    /// let component = try Path.Component("readme.txt")
    /// print(component.stem)       // "readme"
    /// print(component.extension)  // "txt"
    /// ```
    public struct Component: Copyable, Sendable, Hashable {
        /// Internal storage for the component bytes.
        @usableFromInline
        internal var _storage: Path.Storage

        /// Creates a component from a string, validating the contents.
        ///
        /// - Parameter string: The component string.
        /// - Throws: `Component.Error` if the string is invalid.
        @inlinable
        public init(_ string: Swift.String) throws(Error) {
            // Check non-empty
            guard !string.isEmpty else {
                throw .empty
            }

            #if os(Windows)
                let units = string.utf16
                var buffer: [Path.Char] = []
                buffer.reserveCapacity(units.count + 1)

                for unit in units {
                    // Check for interior NUL
                    if unit == 0 {
                        throw .containsInteriorNUL
                    }
                    // Check for path separators (both / and \)
                    if unit == UInt16(ascii: "/") || unit == UInt16(ascii: "\\") {
                        throw .containsPathSeparator
                    }
                    // Check for control characters (0x00-0x1F, 0x7F)
                    if unit < 0x20 || unit == 0x7F {
                        throw .containsControlCharacters
                    }
                    buffer.append(unit)
                }
                buffer.append(0)  // Null terminator
                self._storage = Path.Storage(buffer: buffer)
            #else
                let bytes = string.utf8
                var buffer: [Path.Char] = []
                buffer.reserveCapacity(bytes.count + 1)

                for byte in bytes {
                    // Check for interior NUL
                    if byte == 0 {
                        throw .containsInteriorNUL
                    }
                    // Check for path separator
                    if byte == UInt8(ascii: "/") {
                        throw .containsPathSeparator
                    }
                    // Check for control characters (0x00-0x1F, 0x7F)
                    if byte < 0x20 || byte == 0x7F {
                        throw .containsControlCharacters
                    }
                    buffer.append(byte)  // Char is UInt8 on POSIX
                }
                buffer.append(0)  // Null terminator
                self._storage = Path.Storage(buffer: buffer)
            #endif
        }

        /// Creates a component from validated storage.
        @usableFromInline
        internal init(storage: Path.Storage) {
            self._storage = storage
        }
    }
}

// MARK: - Component String Conversion

extension Path.Component {
    /// The component as a String.
    @inlinable
    public var string: Swift.String {
        #if os(Windows)
            let units = _storage.buffer.dropLast()
            return Swift.String(decoding: units, as: UTF16.self)
        #else
            // Char is UInt8 on POSIX
            let bytes = _storage.buffer.dropLast()
            return Swift.String(decoding: bytes, as: UTF8.self)
        #endif
    }
}

extension Swift.String {
    /// Creates a string from a path component.
    @inlinable
    public init(_ component: Path.Component) {
        self = component.string
    }
}

// MARK: - Component Extension and Stem

extension Path.Component {
    /// The file extension without the leading dot, if any.
    ///
    /// Returns `nil` if there is no extension (no dot, or dot at start/end).
    ///
    /// ```swift
    /// let c1 = try Path.Component("readme.txt")
    /// print(c1.extension)  // "txt"
    ///
    /// let c2 = try Path.Component(".gitignore")
    /// print(c2.extension)  // nil (dot at start)
    ///
    /// let c3 = try Path.Component("Makefile")
    /// print(c3.extension)  // nil (no dot)
    /// ```
    @inlinable
    public var `extension`: Extension? {
        let s = string
        guard let dotIndex = s.lastIndex(of: ".") else {
            return nil
        }
        // Dot at start is not an extension (e.g., ".gitignore")
        if dotIndex == s.startIndex {
            return nil
        }
        // Dot at end is not an extension
        let afterDot = s.index(after: dotIndex)
        if afterDot == s.endIndex {
            return nil
        }
        return Extension(unchecked: Swift.String(s[afterDot...]))
    }

    /// The filename without the extension.
    ///
    /// If there is no extension, returns the full component string.
    ///
    /// ```swift
    /// let c1 = try Path.Component("readme.txt")
    /// print(c1.stem)  // "readme"
    ///
    /// let c2 = try Path.Component(".gitignore")
    /// print(c2.stem)  // ".gitignore"
    ///
    /// let c3 = try Path.Component("archive.tar.gz")
    /// print(c3.stem)  // "archive.tar"
    /// ```
    @inlinable
    public var stem: Stem {
        let s = string
        guard let dotIndex = s.lastIndex(of: ".") else {
            return Stem(unchecked: s)
        }
        // Dot at start is not an extension
        if dotIndex == s.startIndex {
            return Stem(unchecked: s)
        }
        // Dot at end is not an extension
        let afterDot = s.index(after: dotIndex)
        if afterDot == s.endIndex {
            return Stem(unchecked: s)
        }
        return Stem(unchecked: Swift.String(s[..<dotIndex]))
    }
}

// MARK: - CustomStringConvertible

extension Path.Component: CustomStringConvertible {
    public var description: Swift.String {
        string
    }
}

// MARK: - CustomDebugStringConvertible

extension Path.Component: CustomDebugStringConvertible {
    public var debugDescription: Swift.String {
        "Path.Component(\"\(string)\")"
    }
}
