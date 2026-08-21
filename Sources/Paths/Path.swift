public import Path_Primitives

public struct Path: Copyable, Sendable, Hashable {

    @usableFromInline
    internal var _storage: Storage

    @inlinable
    public init(_ string: Swift.String) throws(Error) {
        self._storage = try Storage(string)
    }

    public init(copying bytes: Swift.Span<Char>) throws(Error) {
        guard bytes.count > 0 else {
            throw .empty
        }

        var buffer: [Char] = []
        buffer.reserveCapacity(bytes.count + 1)

        for i in 0..<bytes.count {
            let byte = bytes[i]

            if byte == 0 {
                throw .containsInteriorNUL
            }

            if byte < 0x20 || byte == 0x7F {
                throw .containsControlCharacters
            }
            buffer.append(byte)
        }

        buffer.append(0)
        self._storage = Storage(buffer: buffer)
    }

    @usableFromInline
    internal init(storage: Storage) {
        self._storage = storage
    }
}

extension Path {

    public typealias Char = Path_Primitives.Path.Char

    #if os(Windows)
        @usableFromInline
        internal static let separator: Char = 0x5C
        @usableFromInline
        internal static let altSeparator: Char = 0x2F
    #else
        @usableFromInline
        internal static let separator: Char = 0x2F
    #endif
}

extension Path {

    @usableFromInline
    internal struct Storage: Copyable, Sendable, Hashable {

        @usableFromInline
        internal var buffer: [Char]

        @usableFromInline
        internal init(_ string: Swift.String) throws(Path.Error) {

            guard !string.isEmpty else {
                throw Path.Error.empty
            }

            #if os(Windows)
                let units = string.utf16
                var buffer: [UInt16] = []
                buffer.reserveCapacity(units.count + 1)

                for unit in units {

                    if unit == 0 {
                        throw Path.Error.containsInteriorNUL
                    }

                    if unit < 0x20 || unit == 0x7F {
                        throw Path.Error.containsControlCharacters
                    }
                    buffer.append(unit)
                }
                buffer.append(0)
                self.buffer = buffer
            #else
                let bytes = string.utf8
                var buffer: [Char] = []
                buffer.reserveCapacity(bytes.count + 1)

                for byte in bytes {

                    if byte == 0 {
                        throw Path.Error.containsInteriorNUL
                    }

                    if byte < 0x20 || byte == 0x7F {
                        throw Path.Error.containsControlCharacters
                    }
                    buffer.append(byte)
                }
                buffer.append(0)
                self.buffer = buffer
            #endif
        }

        @usableFromInline
        internal init(buffer: [Char]) {
            self.buffer = buffer
        }
    }
}

extension Path.Storage {

    @usableFromInline
    internal var count: Int {
        buffer.count - 1
    }

    @usableFromInline
    internal var isEmpty: Bool {
        count == 0
    }
}

extension Path {

    @inlinable
    public var string: Swift.String {
        #if os(Windows)

            let units = _storage.buffer.dropLast()
            return Swift.String(decoding: units, as: UTF16.self)
        #else

            let bytes = _storage.buffer.dropLast()
            return Swift.String(decoding: bytes, as: UTF8.self)
        #endif
    }
}

extension Swift.String {

    @inlinable
    public init(_ path: Path) {
        self = path.string
    }
}

extension Path {

    @inlinable
    public func withCString<R, E: Swift.Error>(
        _ body: (UnsafePointer<Char>) throws(E) -> R
    ) throws(E) -> R {
        try _storage.buffer.withUnsafeBufferPointer { ptr throws(E) in
            try unsafe body(ptr.baseAddress!)
        }
    }
}

extension Path {

    @inlinable
    public func withKernelPath<R, E: Swift.Error>(
        _ body: (borrowing Path_Primitives.Path.Borrowed) throws(E) -> R
    ) throws(E) -> R {
        try _storage.buffer.withUnsafeBufferPointer { ptr throws(E) in
            let view = unsafe Path_Primitives.Path.Borrowed(
                ptr.baseAddress!,
                count: _storage.buffer.count - 1
            )
            return try body(view)
        }
    }
}

extension Path: CustomStringConvertible {
    public var description: Swift.String {
        string
    }
}

extension Path: CustomDebugStringConvertible {
    public var debugDescription: Swift.String {
        "Path(\"\(string)\")"
    }
}

extension Path {

    @inlinable
    public var bytes: Swift.Span<Char> {
        @_lifetime(borrow self)
        borrowing get {
            _storage.buffer.span
        }
    }

    @inlinable
    public var content: Swift.Span<Char> {
        @_lifetime(borrow self)
        borrowing get {
            _storage.buffer.span.extracting(0..<_storage.count)
        }
    }
}
