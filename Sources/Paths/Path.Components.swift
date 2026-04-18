// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-path open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-path project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

// MARK: - Paths.Path.Components

extension Path {
    /// A lazy `BidirectionalCollection` view over a `Paths.Path`'s components.
    ///
    /// Obtained via `path.components`. Does not allocate an array up-front —
    /// each Component is materialized on demand when the collection is
    /// subscripted or iterated. `.last` and `.first` from stdlib's
    /// `BidirectionalCollection` default implementations resolve to reverse /
    /// forward byte scans over the underlying path buffer, matching the perf
    /// of dedicated accessors without growing the API surface.
    ///
    /// ## Semantics
    ///
    /// Empty segments (runs of separators) are omitted — `"foo//bar/"`
    /// iterates as `["foo", "bar"]`, `"/foo"` as `["foo"]`, `"/"` as `[]`.
    /// Matches the behavior of POSIX basename(3), Rust `Path::components`,
    /// Go `filepath.Base`-style iteration, Python `pathlib.parts` sans root.
    ///
    /// ## Index Model
    ///
    /// `Index` is the byte position at which a component starts. `startIndex`
    /// is the first non-separator byte (or `endIndex` if the path has no
    /// segments). `index(after:)` advances past the current segment and any
    /// intervening separators. `index(before:)` walks backward past trailing
    /// separators, then to the preceding separator (or buffer start).
    ///
    /// Byte positions are stable within a given `Paths.Path` value. They are
    /// NOT stable across mutations — each mutated path produces a fresh buffer.
    public struct Components: BidirectionalCollection, Sendable {
        @usableFromInline
        internal let path: Path

        @inlinable
        internal init(_ path: Path) {
            self.path = path
        }

        // MARK: Collection

        public typealias Element = Component
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
        public subscript(position: Int) -> Component {
            let segmentEnd = path._firstSeparator(from: position) ?? endIndex
            return Component(
                storage: Storage(copying: path._storage.buffer[position..<segmentEnd])
            )
        }

        @inlinable
        public func index(after i: Int) -> Int {
            let segmentEnd = path._firstSeparator(from: i) ?? endIndex
            return path._firstNonSeparator(from: segmentEnd)
        }

        // MARK: BidirectionalCollection

        @inlinable
        public func index(before i: Int) -> Int {
            // Walk backward past any separators immediately preceding `i`
            // to find the end (exclusive) of the previous non-empty segment,
            // then backward to the preceding separator (or buffer start) to
            // find that segment's start.
            let priorSegmentEnd = path._lastNonSeparator(before: i)
            let priorSeparator = path._lastSeparator(before: priorSegmentEnd)
            return priorSeparator.map { $0 + 1 } ?? 0
        }
    }
}
