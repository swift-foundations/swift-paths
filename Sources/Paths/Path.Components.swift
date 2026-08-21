extension Path {

    public struct Components: BidirectionalCollection, Sendable {
        @usableFromInline
        internal let path: Path

        @inlinable
        package init(_ path: Path) {
            self.path = path
        }
    }
}

extension Path.Components {
    public typealias Element = Path.Component
    public typealias Index = Int

    @inlinable
    public var startIndex: Int {
        path._firstNonSeparator(from: 0)
    }

    @inlinable
    public var endIndex: Int {
        path._storage.count
    }

    @inlinable
    public subscript(position: Int) -> Path.Component {
        let segmentEnd = path._firstSeparator(from: position) ?? endIndex
        return Path.Component(
            storage: Path.Storage(copying: path._storage.buffer[position..<segmentEnd])
        )
    }

    @inlinable
    public func index(after i: Int) -> Int {
        let segmentEnd = path._firstSeparator(from: i) ?? endIndex
        return path._firstNonSeparator(from: segmentEnd)
    }
}

extension Path.Components {
    @inlinable
    public func index(before i: Int) -> Int {

        let priorSegmentEnd = path._lastNonSeparator(before: i)
        let priorSeparator = path._lastSeparator(before: priorSegmentEnd)
        return priorSeparator.map { $0 + 1 } ?? 0
    }
}
