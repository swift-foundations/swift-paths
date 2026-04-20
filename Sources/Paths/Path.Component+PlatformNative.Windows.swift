// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-path open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-path project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

#if os(Windows)

extension Path.Component {
    /// Creates a validated component from platform-native code units.
    ///
    /// Single entry point for building a `Path.Component` from raw
    /// filesystem-native code units (e.g., the code units returned by
    /// `readdir`, `FindFirstFileW`, or a `File.Name.rawBytes`). Consumer
    /// code can write a single unconditional call site instead of a
    /// `#if os(Windows)` hand-dispatch between a string-based init and a
    /// UTF-8-bytes-based init:
    ///
    /// ```swift
    /// // Before
    /// #if os(Windows)
    /// guard let s = Swift.String.strictUTF16(entry.rawBytes) else {
    ///     throw .invalidUTF8
    /// }
    /// return try Path.Component(s)
    /// #else
    /// return try Path.Component(utf8: entry.rawBytes)
    /// #endif
    ///
    /// // After
    /// return try Path.Component(platformNative: entry.rawBytes)
    /// ```
    ///
    /// - POSIX: strictly decodes the bytes as UTF-8.
    /// - Windows: strictly decodes the code units as UTF-16.
    ///
    /// Decoding is backed by the stdlib's `Swift.String.init(validating:as:)`,
    /// which returns `nil` on any invalid sequence instead of substituting
    /// `U+FFFD`. Domain validation (empty, separators, control characters,
    /// interior NUL) is delegated to ``Path/Component/init(_:)``.
    ///
    /// - Parameter codeUnits: Platform-native code units
    ///   (`Path.Char` — `UInt8` on POSIX, `UInt16` on Windows).
    /// - Throws: ``Path/Component/Error/invalidUTF8`` if the code units
    ///   contain an invalid sequence for the platform-native encoding;
    ///   any other ``Path/Component/Error`` raised by domain validation.
    @inlinable
    public init(platformNative codeUnits: [Path.Char]) throws(Error) {
        guard let string = Swift.String(validating: codeUnits, as: UTF16.self) else {
            throw .invalidUTF8
        }
        try self.init(string)
    }
}

#endif
