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
    /// Appends a component to a path.
    ///
    /// ```swift
    /// let dir = try Path("/Users/coen")
    /// let file = dir / "readme.txt"
    /// print(file.string)  // "/Users/coen/readme.txt"
    ///
    /// let nested = dir / "sub" / "path" / "file.txt"
    /// print(nested.string)  // "/Users/coen/sub/path/file.txt"
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
    @_disfavoredOverload
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

// MARK: - ExpressibleByStringInterpolation for Component

extension Path.Component: ExpressibleByStringInterpolation {
    /// Creates a component from string interpolation.
    ///
    /// - Warning: Crashes at runtime if the resulting string is invalid.
    ///   For safe construction, use `try Path.Component(_:)`.
    ///
    /// ```swift
    /// let i = 5
    /// let component: Path.Component = "file-\(i).txt"
    /// ```
}
