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
    /// A lazy view over the path's components.
    ///
    /// Components are the segments between path separators, with empty
    /// segments (runs of separators) omitted. On Windows, both `/` and `\`
    /// are recognized as separators.
    ///
    /// The returned value is a `BidirectionalCollection` — iteration,
    /// `.last`, `.first`, subscript, and `.count` all work without
    /// pre-materializing an `Array<Component>`. Each access builds the
    /// requested Component lazily via byte scanning over `_storage.buffer`.
    ///
    /// ```swift
    /// let path = try Path("/Users/coen/Documents")
    /// print(path.components.map(\.string))
    /// // ["Users", "coen", "Documents"]
    ///
    /// print(path.components.last?.string)  // "Documents" — O(k), 1 alloc
    ///
    /// let trailing = try Path("backup/")
    /// print(trailing.components.last?.string)  // "backup"
    ///
    /// let winPath = try Path("C:\\Users\\coen")  // Windows
    /// // ["C:", "Users", "coen"]
    /// ```
    ///
    /// - Complexity: `O(1)` for the view; each access is `O(k)` where `k`
    ///   is the distance scanned plus the component length.
    @inlinable
    public var components: Components { Components(self) }


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

        // Iterator-based comparison: walks both lazy Components in lockstep.
        // Using `.enumerated()` + subscript would be incorrect because
        // Components' Index is a byte position, not an element offset.
        var selfIter = selfComponents.makeIterator()
        var otherIter = otherComponents.makeIterator()
        while let otherComp = otherIter.next() {
            guard let selfComp = selfIter.next() else { return false }
            if selfComp != otherComp { return false }
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
        // Walk both components in lockstep; verify prefix match and collect
        // the remainder of self in one pass. `Components` iterators are lazy
        // over the byte buffer, so no intermediate arrays materialize.
        var selfIter = components.makeIterator()
        var baseIter = base.components.makeIterator()
        while let baseComp = baseIter.next() {
            guard let selfComp = selfIter.next(), selfComp == baseComp else {
                return nil
            }
        }

        // baseIter exhausted; whatever remains in selfIter is the relative path.
        var remainder: [Component] = []
        while let comp = selfIter.next() {
            remainder.append(comp)
        }
        if remainder.isEmpty {
            return try? Path.init(".")
        }

        // Join remainder component buffers directly with Self.separator.
        var total = 0
        for comp in remainder {
            total += comp._storage.count
        }
        total += remainder.count - 1  // interior separators

        var buffer: [Char] = []
        buffer.reserveCapacity(total + 1)
        var first = true
        for comp in remainder {
            if !first {
                buffer.append(Self.separator)
            }
            first = false
            let cCount = comp._storage.count
            buffer.append(contentsOf: comp._storage.buffer[0..<cCount])
        }
        buffer.append(0)
        return Path(storage: Storage(buffer: buffer))
    }
}

// MARK: - Byte-Scanning Helpers

extension Path {
    /// Returns true if `byte` is a platform path separator.
    ///
    /// On POSIX, `Self.separator` (0x2F). On Windows, `Self.separator` (0x5C)
    /// or `Self.altSeparator` (0x2F).
    @inlinable
    internal static func _isSeparator(_ byte: Char) -> Bool {
        #if os(Windows)
            return byte == Self.separator || byte == Self.altSeparator
        #else
            return byte == Self.separator
        #endif
    }

    /// First separator position at or after `start`, or `nil` if none.
    @usableFromInline
    internal func _firstSeparator(from start: Int) -> Int? {
        let count = _storage.count
        var i = start
        while i < count {
            if Self._isSeparator(_storage.buffer[i]) { return i }
            i += 1
        }
        return nil
    }

    /// First non-separator position at or after `start`, or `_storage.count` if none.
    @usableFromInline
    internal func _firstNonSeparator(from start: Int) -> Int {
        let count = _storage.count
        var i = start
        while i < count {
            if !Self._isSeparator(_storage.buffer[i]) { return i }
            i += 1
        }
        return count
    }

    /// Last separator position in `[0, end)`, or `nil` if none.
    @usableFromInline
    internal func _lastSeparator(before end: Int) -> Int? {
        var i = end - 1
        while i >= 0 {
            if Self._isSeparator(_storage.buffer[i]) { return i }
            i -= 1
        }
        return nil
    }

    /// `j + 1` where `j` is the last non-separator position in `[0, end)`;
    /// `0` if no non-separator exists.
    @usableFromInline
    internal func _lastNonSeparator(before end: Int) -> Int {
        var i = end - 1
        while i >= 0 {
            if !Self._isSeparator(_storage.buffer[i]) { return i + 1 }
            i -= 1
        }
        return 0
    }

    /// Index of the last path separator in the content bytes, or `nil` if none.
    ///
    /// Convenience for `_lastSeparator(before: _storage.count)`. Used by `parent`.
    @usableFromInline
    internal var _lastSeparator: Int? {
        _lastSeparator(before: _storage.count)
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
