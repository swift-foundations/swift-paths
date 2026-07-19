// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-paths open source project
//
// Copyright (c) 2024-2025 Coen ten Thije Boonkkamp and the swift-paths project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Path_Primitives

extension Path {
    // WHY: Category D (SP-5) — pointer-backed value type; storage is
    // WHY: private/internal; the type's safe API never lets the raw pointer
    // WHY: escape, and lifetime invariants are enforced by init/deinit pairing.
    /// Non-escapable borrowed view of a null-terminated path.
    ///
    /// Does not own storage. Valid only for the duration of the borrowing scope.
    /// The referenced memory must remain valid and unmodified while borrowed.
    ///
    /// `~Escapable` enforces at compile time that this value cannot escape
    /// the scope where it was created — preventing use-after-free bugs.
    ///
    /// Invariant: Points to a null-terminated sequence of `Path.Char`.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let path = try Path("/tmp/file.txt")
    /// path.withView { view in
    ///     // Use view for syscalls or comparisons
    /// }
    /// ```
    @safe
    public struct Borrowed: ~Copyable, ~Escapable {
        /// The underlying pointer to the null-terminated path.
        public let pointer: UnsafePointer<Path.Char>
    }
}

// MARK: - Initialization

extension Path.Borrowed {
    /// Creates a borrowed view from a pointer.
    ///
    /// The lifetime of this `Borrowed` value is tied to the lifetime of `pointer`.
    ///
    /// - Precondition: `pointer` must point to a null-terminated sequence.
    @inlinable
    @_lifetime(borrow pointer)
    public init(_ pointer: UnsafePointer<Path.Char>) {
        unsafe (self.pointer = pointer)
    }

}

// MARK: - Access

extension Path.Borrowed {
    /// Executes a closure with the underlying pointer.
    @unsafe
    @inlinable
    public borrowing func withUnsafePointer<R: ~Copyable, E: Swift.Error>(
        _ body: (UnsafePointer<Path.Char>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(pointer)
    }

    /// The length in code units, excluding the null terminator.
    @inlinable
    public var length: Int {
        var count = 0
        var current = unsafe pointer
        while unsafe current.pointee != 0 {
            count += 1
            unsafe (current = current.successor())
        }
        return count
    }

    /// Returns a `Span` view of the path content, excluding the null terminator.
    @inlinable
    public var span: Swift.Span<Path.Char> {
        @_lifetime(copy self) borrowing get {
            let span = unsafe Span(_unsafeStart: pointer, count: length)
            return unsafe _overrideLifetime(span, copying: self)
        }
    }

    /// Returns a `Span` view including the null terminator.
    ///
    /// Useful for syscalls that expect null-terminated data.
    @inlinable
    public var spanWithTerminator: Swift.Span<Path.Char> {
        @_lifetime(copy self) borrowing get {
            let span = unsafe Span(_unsafeStart: pointer, count: length + 1)
            return unsafe _overrideLifetime(span, copying: self)
        }
    }
}

// MARK: - Borrowed Access

extension Path {
    /// Executes `body` with a non-escaping borrowed view of this path, valid
    /// only for the duration of the closure.
    ///
    /// Replaces a former `view` property + `Borrowed.init(borrowing:)` pair
    /// that escaped a pointer out of `withUnsafeBufferPointer` and asserted
    /// its extended validity via `_overrideLifetime` — an assertion not
    /// backed by any compiler- or stdlib-verified guarantee. Keeping the
    /// view's construction and use entirely inside the closure respects the
    /// stdlib's documented lifetime contract instead.
    @inlinable
    public func withView<R, E: Swift.Error>(
        _ body: (borrowing Borrowed) throws(E) -> R
    ) throws(E) -> R {
        try unsafe _storage.buffer.withUnsafeBufferPointer { ptr throws(E) in
            let view = unsafe Borrowed(ptr.baseAddress!)
            return try unsafe body(view)
        }
    }
}

// MARK: - Path Bridge

extension Path.Borrowed {
    /// A `Path_Primitives.Path.Borrowed` for syscall interop.
    ///
    /// This bridges this Foundation-level `Path.Borrowed` to the underlying
    /// L1 `Path_Primitives.Path.Borrowed` without allocation.
    @inlinable
    public var kernelPath: Path_Primitives.Path.Borrowed {
        @_lifetime(copy self) borrowing get {
            let kv = unsafe Path_Primitives.Path.Borrowed(self.pointer, count: self.length)
            return unsafe _overrideLifetime(kv, copying: self)
        }
    }
}
