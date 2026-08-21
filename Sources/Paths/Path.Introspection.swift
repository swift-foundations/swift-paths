extension Path {

    @inlinable
    public var isAbsolute: Bool {
        let count = _storage.count
        guard count > 0 else { return false }

        #if os(Windows)

            if count >= 2 {
                let b0 = _storage.buffer[0]
                let b1 = _storage.buffer[1]
                if (b0 == Self.separator && b1 == Self.separator)
                    || (b0 == Self.altSeparator && b1 == Self.altSeparator)
                {
                    return true
                }
            }

            if count >= 3 {
                let b0 = _storage.buffer[0]
                let isLetter = (b0 >= 0x41 && b0 <= 0x5A) || (b0 >= 0x61 && b0 <= 0x7A)
                let isColon = _storage.buffer[1] == 0x3A
                let b2 = _storage.buffer[2]
                let isSep = b2 == Self.separator || b2 == Self.altSeparator
                if isLetter && isColon && isSep {
                    return true
                }
            }
            return false
        #else
            return _storage.buffer[0] == Self.separator
        #endif
    }

    @inlinable
    public var isRelative: Bool {
        !isAbsolute
    }

    @inlinable
    public var isEmpty: Bool {
        _storage.isEmpty
    }

    @inlinable
    public var `extension`: Component.Extension? {
        get {
            components.last?.extension
        }
        set {
            guard let lastComp = components.last else { return }
            let stem = lastComp.stem

            let newName: Swift.String
            if let ext = newValue {
                newName = stem.string + "." + ext.string
            } else {
                newName = stem.string
            }

            let newComponent: Component
            do throws(Component.Error) {
                newComponent = try Component(newName)
            } catch {
                return
            }

            if let parentPath = parent {

                self._storage = parentPath.appending(newComponent)._storage
            } else {

                self._storage = newComponent._storage
            }
        }
    }

    @inlinable
    public var stem: Component.Stem? {
        components.last?.stem
    }

    @inlinable
    public var count: Int {
        components.count
    }
}

extension Path {

    @inlinable
    public var endsWithSeparator: Bool {
        let count = _storage.count
        guard count > 0 else { return false }
        let last = _storage.buffer[count - 1]
        #if os(Windows)
            return last == Self.separator || last == Self.altSeparator
        #else
            return last == Self.separator
        #endif
    }

    @inlinable
    public var isRoot: Bool {
        let count = _storage.count

        #if os(Windows)

            if count >= 2 {
                let b0 = _storage.buffer[0]
                let b1 = _storage.buffer[1]
                let isUNCPrefix =
                    (b0 == Self.separator && b1 == Self.separator)
                    || (b0 == Self.altSeparator && b1 == Self.altSeparator)
                if isUNCPrefix {
                    var extraSeparators = 0
                    var i = 2
                    while i < count {
                        let b = _storage.buffer[i]
                        if b == Self.separator || b == Self.altSeparator {
                            extraSeparators += 1
                            if extraSeparators > 1 { return false }
                        }
                        i += 1
                    }
                    return true
                }
            }

            if count == 3 {
                let b0 = _storage.buffer[0]
                let isLetter = (b0 >= 0x41 && b0 <= 0x5A) || (b0 >= 0x61 && b0 <= 0x7A)
                let isColon = _storage.buffer[1] == 0x3A
                let b2 = _storage.buffer[2]
                let isSep = b2 == Self.separator || b2 == Self.altSeparator
                return isLetter && isColon && isSep
            }
            return false
        #else
            return count == 1 && _storage.buffer[0] == Self.separator
        #endif
    }
}
