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
    @inlinable
    public var isAbsolute: Bool {
        let s = string
        guard !s.isEmpty else { return false }

        #if os(Windows)
            // UNC path: \\server\share
            if s.hasPrefix("\\\\") || s.hasPrefix("//") {
                return true
            }
            // Drive letter: C:\ or C:/
            if s.count >= 3 {
                let first = s.first!
                let second = s[s.index(after: s.startIndex)]
                let third = s[s.index(s.startIndex, offsetBy: 2)]
                if (first.isLetter && second == ":" && (third == "\\" || third == "/")) {
                    return true
                }
            }
            return false
        #else
            return s.hasPrefix("/")
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
    public var `extension`: Swift.String? {
        get {
            lastComponent?.extension
        }
        set {
            guard let lastComp = lastComponent else { return }
            let stem = lastComp.stem

            let newName: Swift.String
            if let ext = newValue, !ext.isEmpty {
                newName = stem + "." + ext
            } else {
                newName = stem
            }

            guard let newComponent = try? Component(newName) else { return }

            if let parentPath = parent {
                if let newPath = try? Path(parentPath.appending(newComponent).string) {
                    self._storage = newPath._storage
                }
            } else {
                if let newPath = try? Path(newName) {
                    self._storage = newPath._storage
                }
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
    public var stem: Swift.String? {
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
        let s = string
        #if os(Windows)
            return s.hasSuffix("/") || s.hasSuffix("\\")
        #else
            return s.hasSuffix("/")
        #endif
    }

    /// Whether this path represents a root directory.
    ///
    /// - **POSIX:** "/" is the only root
    /// - **Windows:** "C:\", "D:\", "\\server\share" are roots
    @inlinable
    public var isRoot: Bool {
        let s = string

        #if os(Windows)
            // UNC root: \\server\share (but no further path)
            if s.hasPrefix("\\\\") || s.hasPrefix("//") {
                let withoutPrefix = s.dropFirst(2)
                // Count separators after the prefix
                let separatorCount = withoutPrefix.filter { $0 == "/" || $0 == "\\" }.count
                return separatorCount <= 1
            }
            // Drive root: C:\ or C:/
            if s.count == 3 {
                let first = s.first!
                let second = s[s.index(after: s.startIndex)]
                let third = s[s.index(s.startIndex, offsetBy: 2)]
                return first.isLetter && second == ":" && (third == "\\" || third == "/")
            }
            return false
        #else
            return s == "/"
        #endif
    }
}
