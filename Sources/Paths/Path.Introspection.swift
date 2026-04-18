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

// MARK: - Path Introspection

extension Path {
    /// Whether this path is absolute.
    ///
    /// - **POSIX:** Starts with `/`
    /// - **Windows:** Starts with drive letter (`C:\`) or UNC path (`\\server`)
    ///
    /// ```swift
    /// let abs = try Path("/Users/coen")
    /// print(abs.isAbsolute)  // true
    ///
    /// let rel = try Path("Documents/file.txt")
    /// print(rel.isAbsolute)  // false
    /// ```
    ///
    /// On Windows, drive-letter detection restricts to ASCII `A-Z` / `a-z`
    /// (byte-level check). This matches the Win32 drive-letter specification
    /// and is slightly stricter than the previous `Character.isLetter`
    /// implementation, which admitted any Unicode letter.
    @inlinable
    public var isAbsolute: Bool {
        let count = _storage.count
        guard count > 0 else { return false }

        #if os(Windows)
            // UNC prefix: two consecutive separators (\\server or //server).
            if count >= 2 {
                let b0 = _storage.buffer[0]
                let b1 = _storage.buffer[1]
                if (b0 == Self.separator && b1 == Self.separator)
                    || (b0 == Self.altSeparator && b1 == Self.altSeparator)
                {
                    return true
                }
            }
            // Drive letter: ASCII [A-Za-z] ':' separator
            if count >= 3 {
                let b0 = _storage.buffer[0]
                let isLetter = (b0 >= 0x41 && b0 <= 0x5A) || (b0 >= 0x61 && b0 <= 0x7A)
                let isColon = _storage.buffer[1] == 0x3A
                let b2 = _storage.buffer[2]
                let isSep = b2 == Self.separator || b2 == Self.altSeparator
                if isLetter && isColon && isSep {
                    return true
                }
            }
            return false
        #else
            return _storage.buffer[0] == Self.separator
        #endif
    }

    /// Whether this path is relative (not absolute).
    @inlinable
    public var isRelative: Bool {
        !isAbsolute
    }

    /// Whether this path is empty.
    @inlinable
    public var isEmpty: Bool {
        _storage.isEmpty
    }

    /// The file extension of the path (from the last component), without the leading dot.
    ///
    /// Returns `nil` if there is no extension.
    /// Setting to `nil` removes the extension. Setting to a new value replaces it.
    ///
    /// ```swift
    /// var path = try Path("/Users/coen/readme.txt")
    /// print(path.extension)  // "txt"
    ///
    /// path.extension = "md"
    /// print(path.string)     // "/Users/coen/readme.md"
    ///
    /// path.extension = nil
    /// print(path.string)     // "/Users/coen/readme"
    ///
    /// let noExt = try Path("/Users/coen/Makefile")
    /// print(noExt.extension)  // nil
    /// ```
    @inlinable
    public var `extension`: Component.Extension? {
        get {
            lastComponent?.extension
        }
        set {
            guard let lastComp = lastComponent else { return }
            let stem = lastComp.stem

            let newName: Swift.String
            if let ext = newValue {
                newName = stem.string + "." + ext.string
            } else {
                newName = stem.string
            }

            guard let newComponent = try? Component(newName) else { return }

            if let parentPath = parent {
                // Direct storage transfer — parentPath.appending already produces
                // a valid Path; no need to round-trip through Swift.String + Path.init.
                self._storage = parentPath.appending(newComponent)._storage
            } else {
                // No parent — the new path IS just the component. Component's
                // storage is a valid Path storage (no separators, validated bytes).
                self._storage = newComponent._storage
            }
        }
    }

    /// The stem of the path (filename without extension from the last component).
    ///
    /// Returns `nil` if there is no last component.
    ///
    /// ```swift
    /// let path = try Path("/Users/coen/readme.txt")
    /// print(path.stem)  // "readme"
    ///
    /// let archive = try Path("/Users/coen/archive.tar.gz")
    /// print(archive.stem)  // "archive.tar"
    /// ```
    @inlinable
    public var stem: Component.Stem? {
        lastComponent?.stem
    }

    /// The number of path components.
    @inlinable
    public var count: Int {
        components.count
    }
}

// MARK: - Path Normalization Helpers

extension Path {
    /// Whether this path ends with a path separator.
    @inlinable
    public var endsWithSeparator: Bool {
        let count = _storage.count
        guard count > 0 else { return false }
        let last = _storage.buffer[count - 1]
        #if os(Windows)
            return last == Self.separator || last == Self.altSeparator
        #else
            return last == Self.separator
        #endif
    }

    /// Whether this path represents a root directory.
    ///
    /// - **POSIX:** "/" is the only root
    /// - **Windows:** "C:\", "D:\", "\\server\share" are roots
    @inlinable
    public var isRoot: Bool {
        let count = _storage.count

        #if os(Windows)
            // UNC root: \\server or //server with at most one further separator.
            if count >= 2 {
                let b0 = _storage.buffer[0]
                let b1 = _storage.buffer[1]
                let isUNCPrefix =
                    (b0 == Self.separator && b1 == Self.separator)
                    || (b0 == Self.altSeparator && b1 == Self.altSeparator)
                if isUNCPrefix {
                    var extraSeparators = 0
                    var i = 2
                    while i < count {
                        let b = _storage.buffer[i]
                        if b == Self.separator || b == Self.altSeparator {
                            extraSeparators += 1
                            if extraSeparators > 1 { return false }
                        }
                        i += 1
                    }
                    return true
                }
            }
            // Drive root: ASCII [A-Za-z] ':' separator — exactly 3 bytes.
            if count == 3 {
                let b0 = _storage.buffer[0]
                let isLetter = (b0 >= 0x41 && b0 <= 0x5A) || (b0 >= 0x61 && b0 <= 0x7A)
                let isColon = _storage.buffer[1] == 0x3A
                let b2 = _storage.buffer[2]
                let isSep = b2 == Self.separator || b2 == Self.altSeparator
                return isLetter && isColon && isSep
            }
            return false
        #else
            return count == 1 && _storage.buffer[0] == Self.separator
        #endif
    }
}
