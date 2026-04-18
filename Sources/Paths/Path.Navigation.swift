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

// MARK: - Path Components

extension Path {
    /// The components of this path.
    ///
    /// Components are the parts between path separators.
    /// An absolute path starts with an empty component representing the root.
    ///
    /// ```swift
    /// let path = try Path("/Users/coen/Documents")
    /// print(path.components.map(\.string))
    /// // ["Users", "coen", "Documents"]
    ///
    /// let winPath = try Path("C:\\Users\\coen")  // Windows
    /// // ["C:", "Users", "coen"]
    /// ```
    @inlinable
    public var components: [Component] {
        let s = string
        guard !s.isEmpty else { return [] }

        #if os(Windows)
            // Split on both / and \
            let parts = s.split(omittingEmptySubsequences: true) { char in
                char == "/" || char == "\\"
            }
            return parts.compactMap { part in
                try? Component.init(Swift.String(part))
            }
        #else
            // Split on /
            let parts = s.split(separator: "/", omittingEmptySubsequences: true)
            return parts.compactMap { part in
                try? Component.init(Swift.String(part))
            }
        #endif
    }

    /// The last component of the path (filename or final directory).
    ///
    /// Returns `nil` for root paths or paths with no components.
    ///
    /// ```swift
    /// let path = try Path("/Users/coen/readme.txt")
    /// print(path.lastComponent?.string)  // "readme.txt"
    ///
    /// let root = try Path("/")
    /// print(root.lastComponent)  // nil
    /// ```
    @inlinable
    public var lastComponent: Component? {
        components.last
    }

    /// The parent directory of this path.
    ///
    /// Returns `nil` if this is a root path or has no parent.
    ///
    /// ```swift
    /// let path = try Path("/Users/coen/Documents")
    /// print(path.parent?.string)  // "/Users/coen"
    ///
    /// let root = try Path("/")
    /// print(root.parent)  // nil
    /// ```
    @inlinable
    public var parent: Path? {
        guard let lastSep = _lastSeparator else {
            return nil
        }
        #if os(Windows)
            // Separator at start (e.g., `\foo` or UNC-style `\\server`): no further parent.
            if lastSep == 0 {
                return nil
            }
            // Drive-letter root: `C:\Users` → `C:\`, `C:/foo` → `C:\`.
            // Canonicalize the separator byte to the primary `\`.
            if lastSep == 2 && _storage.buffer[1] == 0x3A {
                return Path(storage: Storage(driveLetter: _storage.buffer[0]))
            }
            return Path(storage: Storage(copying: _storage.buffer[..<lastSep]))
        #else
            // Only the root separator: no parent.
            if lastSep == 0 && _storage.count == 1 {
                return nil
            }
            // Separator at start with content after: parent is root "/".
            if lastSep == 0 {
                return Path(storage: Storage(root: Self.separator))
            }
            return Path(storage: Storage(copying: _storage.buffer[..<lastSep]))
        #endif
    }
}

// MARK: - Path Appending

extension Path {
    /// Returns a new path with the given component appended.
    ///
    /// ```swift
    /// let dir = try Path("/Users/coen")
    /// let file = dir.appending(try Path.Component("readme.txt"))
    /// print(file.string)  // "/Users/coen/readme.txt"
    /// ```
    @inlinable
    public func appending(_ component: Component) -> Path {
        Path(storage: Storage(
            joining: _storage.buffer[..<_storage.count],
            component._storage.buffer[..<component._storage.count]
        ))
    }

    /// Returns a new path with the given string appended as a component.
    ///
    /// - Throws: If the string is not a valid component.
    ///
    /// ```swift
    /// let dir = try Path("/Users/coen")
    /// let file = try dir.appending("readme.txt")
    /// print(file.string)  // "/Users/coen/readme.txt"
    /// ```
    @inlinable
    public func appending(_ string: Swift.String) throws(Component.Error) -> Path {
        let component = try Component(string)
        return appending(component)
    }

    /// Returns a new path with the given path appended.
    ///
    /// If `other` is absolute, returns `other` unchanged.
    /// Otherwise, appends `other` to this path.
    ///
    /// ```swift
    /// let base = try Path("/Users")
    /// let rel = try Path("coen/Documents")
    /// let full = base.appending(rel)
    /// print(full.string)  // "/Users/coen/Documents"
    /// ```
    @inlinable
    public func appending(_ other: consuming Path) -> Path {
        if other.isAbsolute {
            return other
        }
        return Path(storage: Storage(
            joining: _storage.buffer[..<_storage.count],
            other._storage.buffer[..<other._storage.count]
        ))
    }
}

// MARK: - Relative Paths

extension Path {
    /// Returns whether this path has the given prefix.
    ///
    /// ```swift
    /// let path = try Path("/Users/coen/Documents/file.txt")
    /// print(path.hasPrefix(try Path("/Users/coen")))  // true
    /// print(path.hasPrefix(try Path("/var")))         // false
    /// ```
    @inlinable
    public func hasPrefix(_ other: Path) -> Bool {
        let selfComponents = components
        let otherComponents = other.components

        guard otherComponents.count <= selfComponents.count else {
            return false
        }

        for (i, otherComp) in otherComponents.enumerated() {
            if selfComponents[i].string != otherComp.string {
                return false
            }
        }

        return true
    }

    /// Returns this path relative to the given base path.
    ///
    /// Returns `nil` if this path does not have `base` as a prefix.
    ///
    /// ```swift
    /// let full = try Path("/Users/coen/Documents/file.txt")
    /// let base = try Path("/Users/coen")
    /// let rel = full.relative(to: base)
    /// print(rel?.string)  // "Documents/file.txt"
    /// ```
    @inlinable
    public func relative(to base: Path) -> Path? {
        guard hasPrefix(base) else {
            return nil
        }

        let selfComponents = components
        let baseComponents = base.components

        let relativeComponents = selfComponents.dropFirst(baseComponents.count)

        if relativeComponents.isEmpty {
            return try? Path.init(".")
        }

        #if os(Windows)
            let separator = "\\"
        #else
            let separator = "/"
        #endif

        let relativeString = relativeComponents.map(\.string).joined(separator: separator)
        return try? Path.init(relativeString)
    }
}

// MARK: - Byte-Scanning Helpers

extension Path {
    /// Index of the last path separator in the content bytes, or `nil` if none.
    ///
    /// Scans `_storage.buffer[0..<count]` in reverse — excluding the trailing NUL.
    /// On POSIX, matches `Self.separator` (0x2F). On Windows, matches either
    /// `Self.separator` (0x5C) or `Self.altSeparator` (0x2F).
    @usableFromInline
    internal var _lastSeparator: Int? {
        let count = _storage.count
        var i = count - 1
        while i >= 0 {
            let byte = _storage.buffer[i]
            if byte == Self.separator {
                return i
            }
            #if os(Windows)
                if byte == Self.altSeparator {
                    return i
                }
            #endif
            i -= 1
        }
        return nil
    }
}

extension Path.Storage {
    /// Creates storage by copying a validated slice and appending the NUL terminator.
    ///
    /// The slice MUST originate from a validated `Path.Storage.buffer`: this init
    /// does no validation, relying on the source's "no control chars, no interior
    /// NUL" invariant.
    @usableFromInline
    internal init(copying slice: ArraySlice<Path.Char>) {
        var out: [Path.Char] = []
        out.reserveCapacity(slice.count + 1)
        out.append(contentsOf: slice)
        out.append(0)
        self.buffer = out
    }

    /// Creates single-character root storage (e.g., `/` on POSIX).
    @usableFromInline
    internal init(root separator: Path.Char) {
        self.buffer = [separator, 0]
    }

    #if os(Windows)
        /// Creates Windows drive-root storage (e.g., `C:\`) from a drive-letter byte.
        ///
        /// Canonicalizes to the primary `\` separator regardless of the input path's
        /// separator byte (so both `C:\foo` and `C:/foo` parent to the same `C:\`).
        @usableFromInline
        internal init(driveLetter: Path.Char) {
            self.buffer = [driveLetter, 0x3A, Path.separator, 0]
        }
    #endif

    /// Creates storage by joining two validated slices with a platform separator.
    ///
    /// If the prefix already ends with a separator, no additional separator is
    /// inserted. On Windows, a trailing `\` or `/` both count for deduplication;
    /// the inserted separator (when needed) is always the primary `Path.separator`.
    ///
    /// Both slices MUST originate from validated storages — concatenating two
    /// validated paths with a single ASCII separator cannot introduce control
    /// chars or interior NULs, so this init performs no validation.
    @usableFromInline
    internal init(
        joining prefix: ArraySlice<Path.Char>,
        _ suffix: ArraySlice<Path.Char>
    ) {
        let endsWithSep: Bool
        if let last = prefix.last {
            #if os(Windows)
                endsWithSep = last == Path.separator || last == Path.altSeparator
            #else
                endsWithSep = last == Path.separator
            #endif
        } else {
            endsWithSep = false
        }
        let needsSep = !prefix.isEmpty && !endsWithSep
        let total = prefix.count + (needsSep ? 1 : 0) + suffix.count

        var out: [Path.Char] = []
        out.reserveCapacity(total + 1)
        out.append(contentsOf: prefix)
        if needsSep {
            out.append(Path.separator)
        }
        out.append(contentsOf: suffix)
        out.append(0)
        self.buffer = out
    }
}
