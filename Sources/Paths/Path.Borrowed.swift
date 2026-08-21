public import Path_Primitives

extension Path {

    @safe
    public struct Borrowed: ~Copyable, ~Escapable {

        public let pointer: UnsafePointer<Path.Char>
    }
}

extension Path.Borrowed {

    @inlinable
    @_lifetime(borrow pointer)
    public init(_ pointer: UnsafePointer<Path.Char>) {
        unsafe (self.pointer = pointer)
    }

}

extension Path.Borrowed {

    @unsafe
    @inlinable
    public borrowing func withUnsafePointer<R: ~Copyable, E: Swift.Error>(
        _ body: (UnsafePointer<Path.Char>) throws(E) -> R
    ) throws(E) -> R {
        try unsafe body(pointer)
    }

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

    @inlinable
    public var span: Swift.Span<Path.Char> {
        @_lifetime(copy self) borrowing get {
            let span = unsafe Span(_unsafeStart: pointer, count: length)
            return unsafe _overrideLifetime(span, copying: self)
        }
    }

    @inlinable
    public var spanWithTerminator: Swift.Span<Path.Char> {
        @_lifetime(copy self) borrowing get {
            let span = unsafe Span(_unsafeStart: pointer, count: length + 1)
            return unsafe _overrideLifetime(span, copying: self)
        }
    }
}

extension Path {

    @inlinable
    public func withView<R, E: Swift.Error>(
        _ body: (borrowing Borrowed) throws(E) -> R
    ) throws(E) -> R {
        try _storage.buffer.withUnsafeBufferPointer { ptr throws(E) in
            let view = unsafe Borrowed(ptr.baseAddress!)
            return try body(view)
        }
    }
}

extension Path.Borrowed {

    @inlinable
    public var kernelPath: Path_Primitives.Path.Borrowed {
        @_lifetime(copy self) borrowing get {
            let kv = unsafe Path_Primitives.Path.Borrowed(self.pointer, count: self.length)
            return unsafe _overrideLifetime(kv, copying: self)
        }
    }
}
