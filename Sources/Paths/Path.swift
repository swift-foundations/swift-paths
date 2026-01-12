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

public import Kernel_Primitives

/// A platform-native owned file path.
///
/// `Path` provides a validated, owned representation of filesystem paths that:
/// - Is Copyable, Sendable, and Hashable
/// - Stores data in platform-native encoding (UTF-8 on POSIX, UTF-16 on Windows)
/// - Validates on construction (non-empty, no control characters, no interior NUL)
/// - Provides path manipulation (parent, components, joining via `/`)
/// - Bridges to `Kernel.Path` for syscall interop via `withKernelPath(_:)`
///
/// ## Platform Encoding
///
/// - **POSIX (macOS, Linux, BSD):** UTF-8 (`CChar` / `Int8`)
/// - **Windows:** UTF-16LE (`UInt16`)
///
/// ## Usage
///
/// ```swift
/// let path = try Path("/Users/coen/Documents")
/// let file = path / "readme.txt"
/// print(file.lastComponent?.string)  // "readme.txt"
/// print(file.extension)               // "txt"
/// print(file.parent)                  // Path("/Users/coen/Documents")
/// ```
public struct Path: Copyable, Sendable, Hashable {
    /// Internal storage for the path bytes.
    @usableFromInline
    internal var _storage: Storage

    /// Creates a path from a string, validating the contents.
    ///
    /// - Parameter string: The path string.
    /// - Throws: `Path.Error` if the string is invalid.
    @inlinable
    public init(_ string: String) throws(Error) {
        self._storage = try Storage(string)
    }

    /// Creates a path from validated storage.
    @usableFromInline
    internal init(storage: Storage) {
        self._storage = storage
    }
}

// MARK: - Platform Character Type

extension Path {
    /// Platform-native path character type.
    ///
    /// - POSIX (macOS, Linux): `CChar` (Int8, UTF-8)
    /// - Windows: `UInt16` (UTF-16)
    #if os(Windows)
        public typealias Char = UInt16
    #else
        public typealias Char = CChar
    #endif

    /// Platform path separator.
    #if os(Windows)
        @usableFromInline
        internal static let separator: Char = 0x5C  // backslash '\'
        @usableFromInline
        internal static let altSeparator: Char = 0x2F  // forward slash '/'
    #else
        @usableFromInline
        internal static let separator: Char = 0x2F  // forward slash '/'
    #endif
}

// MARK: - Errors

extension Path {
    /// Errors that can occur during path construction.
    public enum Error: Swift.Error, Sendable, Equatable {
        /// The path string is empty.
        case empty
        /// The path contains ASCII control characters (0x00-0x1F, 0x7F).
        case containsControlCharacters
        /// The path contains an interior NUL byte.
        case containsInteriorNUL
    }
}

extension Path.Error: CustomStringConvertible {
    public var description: String {
        switch self {
        case .empty:
            return "Path is empty"
        case .containsControlCharacters:
            return "Path contains control characters"
        case .containsInteriorNUL:
            return "Path contains interior NUL byte"
        }
    }
}

// MARK: - Storage

extension Path {
    /// Internal storage for path bytes.
    @usableFromInline
    internal struct Storage: Copyable, Sendable, Hashable {
        #if os(Windows)
            /// UTF-16 buffer, null-terminated.
            @usableFromInline
            internal var buffer: [UInt16]
        #else
            /// UTF-8 buffer, null-terminated.
            @usableFromInline
            internal var buffer: [CChar]
        #endif

        /// Creates storage from a string.
        @usableFromInline
        internal init(_ string: String) throws(Path.Error) {
            // Check non-empty
            guard !string.isEmpty else {
                throw Path.Error.empty
            }

            #if os(Windows)
                let units = string.utf16
                var buffer: [UInt16] = []
                buffer.reserveCapacity(units.count + 1)

                for unit in units {
                    // Check for interior NUL
                    if unit == 0 {
                        throw Path.Error.containsInteriorNUL
                    }
                    // Check for control characters (0x00-0x1F, 0x7F)
                    if unit < 0x20 || unit == 0x7F {
                        throw Path.Error.containsControlCharacters
                    }
                    buffer.append(unit)
                }
                buffer.append(0)  // Null terminator
                self.buffer = buffer
            #else
                let bytes = string.utf8
                var buffer: [CChar] = []
                buffer.reserveCapacity(bytes.count + 1)

                for byte in bytes {
                    // Check for interior NUL
                    if byte == 0 {
                        throw Path.Error.containsInteriorNUL
                    }
                    // Check for control characters (0x00-0x1F, 0x7F)
                    if byte < 0x20 || byte == 0x7F {
                        throw Path.Error.containsControlCharacters
                    }
                    buffer.append(CChar(bitPattern: byte))
                }
                buffer.append(0)  // Null terminator
                self.buffer = buffer
            #endif
        }

        /// Creates storage from a raw buffer (no validation).
        @usableFromInline
        internal init(buffer: [Char]) {
            self.buffer = buffer
        }

        /// The number of characters (excluding null terminator).
        @usableFromInline
        internal var count: Int {
            buffer.count - 1  // Exclude null terminator
        }

        /// Whether the storage is empty.
        @usableFromInline
        internal var isEmpty: Bool {
            count == 0
        }
    }
}

// MARK: - String Conversion

extension Path {
    /// The path as a String.
    ///
    /// On POSIX, this decodes UTF-8. On Windows, this decodes UTF-16.
    @inlinable
    public var string: String {
        #if os(Windows)
            // Exclude null terminator
            let units = _storage.buffer.dropLast()
            return String(decoding: units, as: UTF16.self)
        #else
            // Exclude null terminator
            let bytes = _storage.buffer.dropLast().map { UInt8(bitPattern: $0) }
            return String(decoding: bytes, as: UTF8.self)
        #endif
    }
}

extension String {
    /// Creates a string from a path.
    @inlinable
    public init(_ path: Path) {
        self = path.string
    }
}

// MARK: - C String Access

extension Path {
    /// Executes a closure with the null-terminated C string pointer.
    ///
    /// On POSIX, this provides a UTF-8 C string.
    /// On Windows, this provides a UTF-16 wide string (LPCWSTR).
    @inlinable
    public func withCString<R, E: Swift.Error>(
        _ body: (UnsafePointer<Char>) throws(E) -> R
    ) throws(E) -> R  {
        try _storage.buffer.withUnsafeBufferPointer { (ptr) throws(E) in
            try body(ptr.baseAddress!)
        }
    }
}

// MARK: - Kernel.Path Bridge

extension Path {
    /// Executes a closure with a borrowed `Kernel.Path` for syscall interop.
    ///
    /// This bridges the owned `Path` to the ephemeral `Kernel.Path` required
    /// by kernel primitives.
    ///
    /// ```swift
    /// let path = try Path("/tmp/file.txt")
    /// try path.withKernelPath { kernelPath in
    ///     try Kernel.File.Open.open(path: kernelPath, mode: .read)
    /// }
    /// ```
    @inlinable
    public func withKernelPath<R, E: Swift.Error>(
        _ body: (borrowing Kernel.Path) throws(E) -> R
    ) throws(E) -> R {
        // Use Result to bridge typed throws across non-typed-throws boundary
        var result: Result<R, E>!
        _storage.buffer.withUnsafeBufferPointer { ptr in
            let kernelPath = Kernel.Path(unsafeCString: ptr.baseAddress!)
            do throws(E) {
                result = .success(try body(kernelPath))
            } catch {
                result = .failure(error)
            }
        }
        return try result.get()
    }
}

// MARK: - CustomStringConvertible

extension Path: CustomStringConvertible {
    public var description: String {
        string
    }
}

// MARK: - CustomDebugStringConvertible

extension Path: CustomDebugStringConvertible {
    public var debugDescription: String {
        "Path(\"\(string)\")"
    }
}
