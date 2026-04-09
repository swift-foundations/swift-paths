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

public import Kernel_Path_Primitives

extension Path {
    /// Non-escapable view of a null-terminated path.
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
    /// let view = path.view  // Borrowed, non-escaping
    /// // Use view for syscalls or comparisons
    /// ```
    @safe
    public struct View: ~Copyable, ~Escapable {
        /// The underlying pointer to the null-terminated path.
        public let pointer: UnsafePointer<Path.Char>
    }
}

// MARK: - Initialization

extension Path.View {
    /// Creates a view from a pointer.
    ///
    /// The lifetime of this `View` value is tied to the lifetime of `pointer`.
    ///
    /// - Precondition: `pointer` must point to a null-terminated sequence.
    @inlinable
    @_lifetime(borrow pointer)
    public init(_ pointer: UnsafePointer<Path.Char>) {
        unsafe (self.pointer = pointer)
    }

    /// Creates a view borrowing from an owned `Path`.
    ///
    /// This is the primary way to get a `View` from a `Path`.
    /// The view's lifetime is tied to the path's lifetime.
    @inlinable
    @_lifetime(borrow path)
    public init(borrowing path: borrowing Path) {
        // Borrow directly from the path's internal buffer
        let ptr = unsafe path._storage.buffer.withUnsafeBufferPointer { $0.baseAddress! }
        unsafe (self.pointer = ptr)
    }
}

// MARK: - Access

extension Path.View {
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
    public var span: Span<Path.Char> {
        @_lifetime(copy self) borrowing get {
            let span = unsafe Span(_unsafeStart: pointer, count: length)
            return unsafe _overrideLifetime(span, copying: self)
        }
    }

    /// Returns a `Span` view including the null terminator.
    ///
    /// Useful for syscalls that expect null-terminated data.
    @inlinable
    public var spanWithTerminator: Span<Path.Char> {
        @_lifetime(copy self) borrowing get {
            let span = unsafe Span(_unsafeStart: pointer, count: length + 1)
            return unsafe _overrideLifetime(span, copying: self)
        }
    }
}

// MARK: - View Property

extension Path {
    /// A non-escaping view of this path.
    ///
    /// The view borrows from this path and cannot outlive it.
    @inlinable
    public var view: View {
        @_lifetime(borrow self) borrowing get {
            View(borrowing: self)
        }
    }
}

// MARK: - Kernel.Path Bridge

extension Path.View {
    /// A `Kernel.Path.View` for syscall interop.
    ///
    /// This bridges `Path.View` to `Kernel.Path.View` without allocation.
    @inlinable
    public var kernelPath: Kernel.Path.View {
        @_lifetime(copy self) borrowing get {
            let kv = unsafe Kernel.Path.View(self.pointer, count: self.length)
            return unsafe _overrideLifetime(kv, copying: self)
        }
    }
}
