extension Path {

    @inlinable
    public var components: Components { Components(self) }

    @inlinable
    public var parent: Path? {
        guard let lastSep = _lastSeparator else {
            return nil
        }
        #if os(Windows)

            if lastSep == 0 {
                return nil
            }

            if lastSep == 2 && _storage.count == 3 && _storage.buffer[1] == 0x3A {
                return nil
            }

            if lastSep == 2 && _storage.buffer[1] == 0x3A {
                return Path(storage: Storage(driveLetter: _storage.buffer[0]))
            }
            return Path(storage: Storage(copying: _storage.buffer[..<lastSep]))
        #else

            if lastSep == 0 && _storage.count == 1 {
                return nil
            }

            if lastSep == 0 {
                return Path(storage: Storage(root: Self.separator))
            }
            return Path(storage: Storage(copying: _storage.buffer[..<lastSep]))
        #endif
    }
}

extension Path {

    @inlinable
    public func appending(_ component: Component) -> Path {
        Path(
            storage: Storage(
                joining: _storage.buffer[..<_storage.count],
                component._storage.buffer[..<component._storage.count]
            )
        )
    }

    @inlinable
    public func appending(_ string: Swift.String) throws(Component.Error) -> Path {
        let component = try Component(string)
        return appending(component)
    }

    @inlinable
    public func appending(_ other: consuming Path) -> Path {
        if other.isAbsolute {
            return other
        }
        return Path(
            storage: Storage(
                joining: _storage.buffer[..<_storage.count],
                other._storage.buffer[..<other._storage.count]
            )
        )
    }
}

extension Path {

    @inlinable
    public func hasPrefix(_ other: Path) -> Bool {

        guard isAbsolute == other.isAbsolute else { return false }

        let selfComponents = components
        let otherComponents = other.components

        var selfIter = selfComponents.makeIterator()
        var otherIter = otherComponents.makeIterator()
        while let otherComp = otherIter.next() {
            guard let selfComp = selfIter.next() else { return false }
            if selfComp != otherComp { return false }
        }
        return true
    }

    @inlinable
    public func relative(to base: Path) -> Path? {

        guard isAbsolute == base.isAbsolute else { return nil }

        var selfIter = components.makeIterator()
        var baseIter = base.components.makeIterator()
        while let baseComp = baseIter.next() {
            guard let selfComp = selfIter.next(), selfComp == baseComp else {
                return nil
            }
        }

        var remainder: [Component] = []
        while let comp = selfIter.next() {
            remainder.append(comp)
        }
        if remainder.isEmpty {

            do throws(Self.Error) {
                return try Path(".")
            } catch {
                fatalError("\".\" is a statically valid Path literal: \(error)")
            }
        }

        var total = 0
        for comp in remainder {
            total += comp._storage.count
        }
        total += remainder.count - 1

        var buffer: [Char] = []
        buffer.reserveCapacity(total + 1)
        var first = true
        for comp in remainder {
            if !first {
                buffer.append(Self.separator)
            }
            first = false
            let cCount = comp._storage.count
            buffer.append(contentsOf: comp._storage.buffer[0..<cCount])
        }
        buffer.append(0)
        return Path(storage: Storage(buffer: buffer))
    }
}

extension Path {

    @inlinable
    package static func _isSeparator(_ byte: Char) -> Bool {
        #if os(Windows)
            return byte == Self.separator || byte == Self.altSeparator
        #else
            return byte == Self.separator
        #endif
    }

    @usableFromInline
    internal func _firstSeparator(from start: Int) -> Int? {
        let count = _storage.count
        var i = start
        while i < count {
            if Self._isSeparator(_storage.buffer[i]) { return i }
            i += 1
        }
        return nil
    }

    @usableFromInline
    internal func _firstNonSeparator(from start: Int) -> Int {
        let count = _storage.count
        var i = start
        while i < count {
            if !Self._isSeparator(_storage.buffer[i]) { return i }
            i += 1
        }
        return count
    }

    @usableFromInline
    internal func _lastSeparator(before end: Int) -> Int? {
        var i = end - 1
        while i >= 0 {
            if Self._isSeparator(_storage.buffer[i]) { return i }
            i -= 1
        }
        return nil
    }

    @usableFromInline
    internal func _lastNonSeparator(before end: Int) -> Int {
        var i = end - 1
        while i >= 0 {
            if !Self._isSeparator(_storage.buffer[i]) { return i + 1 }
            i -= 1
        }
        return 0
    }

    @usableFromInline
    internal var _lastSeparator: Int? {
        _lastSeparator(before: _storage.count)
    }
}

extension Path.Storage {

    @usableFromInline
    internal init(copying slice: ArraySlice<Path.Char>) {
        var out: [Path.Char] = []
        out.reserveCapacity(slice.count + 1)
        out.append(contentsOf: slice)
        out.append(0)
        self.buffer = out
    }

    @usableFromInline
    internal init(root separator: Path.Char) {
        self.buffer = [separator, 0]
    }

    #if os(Windows)

        @usableFromInline
        internal init(driveLetter: Path.Char) {
            self.buffer = [driveLetter, 0x3A, Path.separator, 0]
        }
    #endif

    @usableFromInline
    internal init(
        joining prefix: ArraySlice<Path.Char>,
        _ suffix: ArraySlice<Path.Char>
    ) {
        let endsWithSep: Bool
        if let last = prefix.last {
            #if os(Windows)
                endsWithSep = last == Path.separator || last == Path.altSeparator
            #else
                endsWithSep = last == Path.separator
            #endif
        } else {
            endsWithSep = false
        }
        let needsSep = !prefix.isEmpty && !endsWithSep
        let total = prefix.count + (needsSep ? 1 : 0) + suffix.count

        var out: [Path.Char] = []
        out.reserveCapacity(total + 1)
        out.append(contentsOf: prefix)
        if needsSep {
            out.append(Path.separator)
        }
        out.append(contentsOf: suffix)
        out.append(0)
        self.buffer = out
    }
}
