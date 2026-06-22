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

public import Path_Primitives

/// A platform-native owned file path.
///
/// `Path` provides a validated, owned representation of filesystem paths that:
/// - Is Copyable, Sendable, and Hashable
/// - Stores data in platform-native encoding (UTF-8 on POSIX, UTF-16 on Windows)
/// - Validates on construction (non-empty, no control characters, no interior NUL)
/// - Provides path manipulation (parent, components, joining via `/`)
/// - Bridges to `Path` for syscall interop via `withKernelPath(_:)`
///
/// ## Platform Encoding
///
/// - **POSIX (macOS, Linux, BSD):** UTF-8 (`UInt8`)
/// - **Windows:** UTF-16LE (`UInt16`)
///
/// ## Usage
///
/// ```swift
/// let path = try Path("/Users/coen/Documents")
/// let file = path / "readme.txt"
/// print(file.components.last?.string)  // "readme.txt"
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
    public init(_ string: Swift.String) throws(Error) {
        self._storage = try Storage(string)
    }

    /// Creates a path by copying from a span of platform-native code units.
    ///
    /// This initializer enables zero-intermediate-allocation patterns when
    /// constructing a path from borrowed data (e.g., from a syscall buffer).
    ///
    /// - Parameter bytes: The path bytes. Must NOT include a NUL terminator.
    /// - Throws: `Path.Error` if validation fails.
    public init(copying bytes: Swift.Span<Char>) throws(Error) {
        guard bytes.count > 0 else {
            throw .empty
        }

        var buffer: [Char] = []
        buffer.reserveCapacity(bytes.count + 1)

        for i in 0..<bytes.count {
            let byte = bytes[i]
            // Check for interior NUL
            if byte == 0 {
                throw .containsInteriorNUL
            }
            // Check for control characters (0x00-0x1F, 0x7F)
            if byte < 0x20 || byte == 0x7F {
                throw .containsControlCharacters
            }
            buffer.append(byte)
        }

        buffer.append(0)  // NUL terminator
        self._storage = Storage(buffer: buffer)
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
    /// Aliases `Path_Primitives.Path.Char`:
    /// - POSIX (macOS, Linux): `UInt8` (UTF-8 code units)
    /// - Windows: `UInt16` (UTF-16 code units)
    ///
    /// Uses pure Swift types, not C interop types (CChar/WCHAR).
    public typealias Char = Path_Primitives.Path.Char

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

// MARK: - Storage

extension Path {
    /// Internal storage for path bytes.
    @usableFromInline
    internal struct Storage: Copyable, Sendable, Hashable {
        /// Platform-native code units, null-terminated.
        /// UTF-8 (`[UInt8]`) on POSIX, UTF-16 (`[UInt16]`) on Windows.
        @usableFromInline
        internal var buffer: [Char]

        /// Creates storage from a string.
        @usableFromInline
        internal init(_ string: Swift.String) throws(Path.Error) {
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
                var buffer: [Char] = []
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
                    buffer.append(byte)  // Char is UInt8 on POSIX
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
    public var string: Swift.String {
        #if os(Windows)
            // Exclude null terminator
            let units = _storage.buffer.dropLast()
            return Swift.String(decoding: units, as: UTF16.self)
        #else
            // Exclude null terminator; Char is UInt8 on POSIX
            let bytes = _storage.buffer.dropLast()
            return Swift.String(decoding: bytes, as: UTF8.self)
        #endif
    }
}

extension Swift.String {
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
        try unsafe _storage.buffer.withUnsafeBufferPointer { (ptr) throws(E) in
            try unsafe body(ptr.baseAddress!)
        }
    }
}

// MARK: - Path Bridge

extension Path {
    /// A `Path_Primitives.Path.Borrowed` for syscall interop.
    ///
    /// ## Zero-Allocation on POSIX
    ///
    /// On POSIX systems, both `Path` and `Path_Primitives.Path` store UTF-8 bytes,
    /// so this property borrows directly from the internal buffer without allocation.
    @inlinable
    public var kernelPath: Path_Primitives.Path.Borrowed {
        @_lifetime(borrow self) borrowing get {
            let ptr = unsafe _storage.buffer.withUnsafeBufferPointer { $0.baseAddress! }
            let view = unsafe Path_Primitives.Path.Borrowed(ptr, count: _storage.buffer.count - 1)
            return unsafe _overrideLifetime(view, borrowing: self)
        }
    }
}

// MARK: - CustomStringConvertible

extension Path: CustomStringConvertible {
    public var description: Swift.String {
        string
    }
}

// MARK: - CustomDebugStringConvertible

extension Path: CustomDebugStringConvertible {
    public var debugDescription: Swift.String {
        "Path(\"\(string)\")"
    }
}

// MARK: - Span Access

extension Path {
    /// Safe span access to NUL-terminated path bytes.
    ///
    /// Returns a span of the entire path buffer including the NUL terminator.
    /// This span is suitable for passing to Kernel APIs that expect NUL-terminated paths
    /// (the raw-storage view per SE-0456 convention).
    ///
    /// For the content-only view (excluding NUL, aligned with the L1
    /// `Path_Primitives.Path.content` convention), use `.content`.
    ///
    /// - Complexity: O(1) - the span borrows directly from owned storage.
    ///
    /// ```swift
    /// let path = try Path("/tmp/file.txt")
    /// let stats = try Kernel.File.Stats.get(path: path.bytes)  // Safe - no `unsafe` needed
    /// ```
    @inlinable
    public var bytes: Swift.Span<Char> {
        @_lifetime(borrow self)
        borrowing get {
            _storage.buffer.span
        }
    }

    /// Safe span access to path content, excluding the NUL terminator.
    ///
    /// Returns a span of the path's semantic content — the meaningful bytes
    /// without the storage-framing NUL. Cross-layer consistent with L1
    /// `Path_Primitives.Path.content`.
    ///
    /// For the NUL-including raw-storage view suitable for syscall hand-off,
    /// use `.bytes`.
    ///
    /// - Complexity: O(1) - sub-span of owned storage.
    @inlinable
    public var content: Swift.Span<Char> {
        @_lifetime(borrow self)
        borrowing get {
            _storage.buffer.span.extracting(0..<_storage.count)
        }
    }
}
