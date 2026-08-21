extension Path {

    public struct Component: Copyable, Sendable, Hashable {

        @usableFromInline
        internal var _storage: Path.Storage

        @inlinable
        public init(_ string: Swift.String) throws(Error) {

            guard !string.isEmpty else {
                throw .empty
            }

            #if os(Windows)
                let units = string.utf16
                var buffer: [Path.Char] = []
                buffer.reserveCapacity(units.count + 1)

                for unit in units {

                    if unit == 0 {
                        throw .containsInteriorNUL
                    }

                    if unit == Path.separator || unit == Path.altSeparator {
                        throw .containsPathSeparator
                    }

                    if unit < 0x20 || unit == 0x7F {
                        throw .containsControlCharacters
                    }
                    buffer.append(unit)
                }
                buffer.append(0)
                self._storage = Path.Storage(buffer: buffer)
            #else
                let bytes = string.utf8
                var buffer: [Path.Char] = []
                buffer.reserveCapacity(bytes.count + 1)

                for byte in bytes {

                    if byte == 0 {
                        throw .containsInteriorNUL
                    }

                    if byte == UInt8(ascii: "/") {
                        throw .containsPathSeparator
                    }

                    if byte < 0x20 || byte == 0x7F {
                        throw .containsControlCharacters
                    }
                    buffer.append(byte)
                }
                buffer.append(0)
                self._storage = Path.Storage(buffer: buffer)
            #endif
        }

        @usableFromInline
        internal init(storage: Path.Storage) {
            self._storage = storage
        }
    }
}

extension Path.Component {

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
    public init(_ component: Path.Component) {
        self = component.string
    }
}

extension Path.Component {

    @inlinable
    public var `extension`: Extension? {
        let s = string
        guard let dotIndex = s.lastIndex(of: ".") else {
            return nil
        }

        if dotIndex == s.startIndex {
            return nil
        }

        let afterDot = s.index(after: dotIndex)
        if afterDot == s.endIndex {
            return nil
        }
        return Extension(unchecked: Swift.String(s[afterDot...]))
    }

    @inlinable
    public var stem: Stem {
        let s = string
        guard let dotIndex = s.lastIndex(of: ".") else {
            return Stem(unchecked: s)
        }

        if dotIndex == s.startIndex {
            return Stem(unchecked: s)
        }

        let afterDot = s.index(after: dotIndex)
        if afterDot == s.endIndex {
            return Stem(unchecked: s)
        }
        return Stem(unchecked: Swift.String(s[..<dotIndex]))
    }
}

extension Path.Component: CustomStringConvertible {
    public var description: Swift.String {
        string
    }
}

extension Path.Component: CustomDebugStringConvertible {
    public var debugDescription: Swift.String {
        "Path.Component(\"\(string)\")"
    }
}
