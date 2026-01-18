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
        let s = string

        #if os(Windows)
            // Find last separator
            guard let lastSep = s.lastIndex(where: { $0 == "/" || $0 == "\\" }) else {
                return nil
            }

            // If separator is at start, check if it's a drive letter or UNC
            if lastSep == s.startIndex {
                return nil
            }

            // Check for drive letter case (C:\)
            let beforeSep = s[..<lastSep]
            if beforeSep.count == 2 && beforeSep.last == ":" {
                // Return drive root (e.g., "C:\")
                return try? Path.init(Swift.String(beforeSep) + "\\")
            }

            // Return parent
            let parentStr = Swift.String(beforeSep)
            return parentStr.isEmpty ? nil : try? Path.init(parentStr)
        #else
            // Find last separator
            guard let lastSep = s.lastIndex(of: "/") else {
                return nil
            }

            // If separator is at start and it's the only character, no parent
            if lastSep == s.startIndex {
                return s.count == 1 ? nil : try? Path.init("/")
            }

            // Return parent
            let parentStr = Swift.String(s[..<lastSep])
            return parentStr.isEmpty ? try? Path.init("/") : try? Path.init(parentStr)
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
        let s = string

        #if os(Windows)
            // Check if path already ends with separator
            let needsSep = !s.isEmpty && !s.hasSuffix("/") && !s.hasSuffix("\\")
            let newPath = needsSep ? s + "\\" + component.string : s + component.string
        #else
            // Check if path already ends with separator
            let needsSep = !s.isEmpty && !s.hasSuffix("/")
            let newPath = needsSep ? s + "/" + component.string : s + component.string
        #endif

        // This should not fail since we're appending valid components
        return (try? Path.init(newPath)) ?? self
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
    public func appending(_ other: Path) -> Path {
        // If other is absolute, return it unchanged
        if other.isAbsolute {
            return other
        }

        let s = string

        #if os(Windows)
            let needsSep = !s.isEmpty && !s.hasSuffix("/") && !s.hasSuffix("\\")
            let newPath = needsSep ? s + "\\" + other.string : s + other.string
        #else
            let needsSep = !s.isEmpty && !s.hasSuffix("/")
            let newPath = needsSep ? s + "/" + other.string : s + other.string
        #endif

        return (try? Path.init(newPath)) ?? self
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
