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

// MARK: - Path Operators

extension Path {
    /// Appends a string to a path.
    ///
    /// The string can be a single component (`"readme.txt"`) or a relative path
    /// with multiple components (`"Documents/readme.txt"`).
    ///
    /// ```swift
    /// let dir = try Path("/Users/coen")
    /// let file = dir / "readme.txt"
    /// print(file.string)  // "/Users/coen/readme.txt"
    ///
    /// let nested = dir / "Documents/Projects/readme.txt"
    /// print(nested.string)  // "/Users/coen/Documents/Projects/readme.txt"
    /// ```
    ///
    /// - Precondition: The string must be a valid component or relative path.
    ///   Passing an absolute path or invalid string is a programmer error.
    @inlinable
    public static func / (lhs: Path, rhs: Swift.String) -> Path {
        // Fast path: try as single component first (common case)
        if let component = try? Component.init(rhs) {
            return lhs.appending(component)
        }
        // Slow path: parse as relative path (handles "a/b/file.txt")
        if let relativePath = try? Path.init(rhs), relativePath.isRelative {
            return lhs.appending(relativePath)
        }
        // Absolute path or truly invalid string is programmer error
        fatalError("Invalid path operand for /: '\(rhs)' - must be a valid component or relative path")
    }

    /// Appends a component to a path.
    ///
    /// ```swift
    /// let dir = try Path("/Users/coen")
    /// let component = try Path.Component("readme.txt")
    /// let file = dir / component
    /// print(file.string)  // "/Users/coen/readme.txt"
    /// ```
    @inlinable
    public static func / (lhs: Path, rhs: Component) -> Path {
        lhs.appending(rhs)
    }

    /// Appends one path to another.
    ///
    /// If the right-hand side is absolute, returns it unchanged.
    /// Otherwise, appends it to the left-hand side.
    ///
    /// ```swift
    /// let base = try Path("/Users")
    /// let rel = try Path("coen/Documents")
    /// let full = base / rel
    /// print(full.string)  // "/Users/coen/Documents"
    /// ```
    @inlinable
    public static func / (lhs: Path, rhs: Path) -> Path {
        lhs.appending(rhs)
    }
}

// MARK: - ExpressibleByStringLiteral

extension Path: ExpressibleByStringLiteral {
    /// Creates a path from a string literal.
    ///
    /// - Warning: Crashes at runtime if the string is invalid.
    ///   For safe construction, use `try Path(_:)`.
    ///
    /// ```swift
    /// let path: Path = "/Users/coen/Documents"
    /// ```
    @inlinable
    public init(stringLiteral value: Swift.String) {
        do {
            try self.init(value)
        } catch {
            fatalError("Invalid path literal: \(value) (\(error))")
        }
    }
}

// MARK: - ExpressibleByStringInterpolation

extension Path: ExpressibleByStringInterpolation {
    /// Creates a path from string interpolation.
    ///
    /// - Warning: Crashes at runtime if the resulting string is invalid.
    ///   For safe construction, use `try Path(_:)`.
    ///
    /// ```swift
    /// let name = "Documents"
    /// let path: Path = "/Users/coen/\(name)"
    /// ```
}

// MARK: - ExpressibleByStringLiteral for Component

extension Path.Component: ExpressibleByStringLiteral {
    /// Creates a component from a string literal.
    ///
    /// - Warning: Crashes at runtime if the string is invalid.
    ///   For safe construction, use `try Path.Component(_:)`.
    ///
    /// ```swift
    /// let component: Path.Component = "readme.txt"
    /// ```
    @inlinable
    public init(stringLiteral value: Swift.String) {
        do {
            try self.init(value)
        } catch {
            fatalError("Invalid path component literal: \(value) (\(error))")
        }
    }
}
