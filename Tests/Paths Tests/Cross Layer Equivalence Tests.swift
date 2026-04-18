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

import Testing

// Test-only import. Reaches the L2 POSIX `Path.View: @retroactive Path.Protocol`
// conformance via the L3 Kernel unification chain per [PLAT-ARCH-006]:
//   Kernel_Core → POSIX_Kernel → POSIX_Kernel_File → ISO_9945_Kernel_File.
// Production swift-paths does NOT depend on this — byte-scan is duplicated at L3
// to avoid inflating the production dep graph.
import Kernel_Core

@testable import Paths

// MARK: - L1 ↔ L3 equivalence (POSIX)

/// Asserts that L3 `Paths.Path` byte-scan decomposition produces the same
/// content bytes as the L1 algorithm reached via `Path.Protocol` on the
/// shared kernel view.
///
/// This safeguards Waves 1–5 of the correction cycle: any future divergence
/// between the L1 reference algorithm and L3's duplicated byte-scan surfaces
/// here before reaching downstream consumers.
///
/// Windows is excluded until Phase 4a Windows lands the corresponding
/// `Path.View: Path.Protocol` conformance in swift-windows-standard.
#if !os(Windows)
    @Suite("L1 ↔ L3 equivalence (POSIX)")
    struct CrossLayerPathEquivalencePOSIX {

        /// POSIX fixture set. Covers root, nested, trailing separator,
        /// bare filename, dot-components, and deeply nested shapes.
        static let fixtures: [Swift.String] = [
            "/",
            "/foo",
            "/foo/bar",
            "/foo/bar/baz",
            "/a/b/c/d/e/f",
            "foo",
            "foo/bar",
            "foo/bar/baz",
            "/foo/",
            "foo/",
            ".",
            "..",
            "./foo",
            "../foo",
        ]

        @Test("parent content-bytes agree", arguments: fixtures)
        func parentEquivalence(fixture: Swift.String) throws {
            let l3 = try Path(fixture)

            // L1 parent via the kernel view (routes through Path.Protocol).
            // Scoped: the ~Escapable view + span die with this `do` block.
            var l1Bytes: [UInt8]? = nil
            do {
                let view = l3.kernelPath
                if let span = view.parent {
                    var bytes: [UInt8] = []
                    bytes.reserveCapacity(span.count)
                    for i in 0..<span.count {
                        bytes.append(span[i])
                    }
                    l1Bytes = bytes
                }
            }

            // L3 parent via Phase 4b byte-scan.
            let l3Bytes: [UInt8]? = l3.parent.map { Self.contentBytes(of: $0) }

            #expect(
                l1Bytes == l3Bytes,
                """
                parent("\(fixture)") disagrees:
                  L1 = \(Self.format(l1Bytes))
                  L3 = \(Self.format(l3Bytes))
                """
            )
        }

        // MARK: - appending(Path) — relative-other only
        //
        // L3 `appending(Path)` short-circuits when `other.isAbsolute`,
        // returning `other` unchanged. L1 `Path.Protocol.appending` has
        // no such short-circuit — it concatenates unconditionally,
        // producing a doubled-separator path. This is intentional
        // divergence at the L3 layer, so the equivalence test restricts
        // to relative-other fixtures where both layers agree.

        /// Relative-other fixtures for `appending(Path)`. Covers trailing
        /// separator on base (dedup case), root base, nested other.
        static let appendingFixtures: [AppendingFixture] = [
            .init(base: "/Users", other: "coen"),
            .init(base: "/Users", other: "coen/Documents"),
            .init(base: "foo", other: "bar"),
            .init(base: "/Users/", other: "coen"),
            .init(base: "foo/", other: "bar"),
            .init(base: "/", other: "foo"),
            .init(base: "/a", other: "b/c/d"),
            .init(base: "a/b", other: "c/d"),
        ]

        @Test("appending(Path) relative content-bytes agree", arguments: appendingFixtures)
        func appendingPathRelativeEquivalence(fixture: AppendingFixture) throws {
            let base = try Path(fixture.base)
            let other = try Path(fixture.other)

            // L3 result via Phase 4b byte-scan.
            let l3Result = base.appending(other)
            let l3Bytes = Self.contentBytes(of: l3Result)

            // L1 result: concat via Path.Protocol on kernel views, then
            // iterate the owned Path's .bytes (L1 convention: excludes NUL).
            var l1Bytes: [UInt8] = []
            do {
                let baseView = base.kernelPath
                let otherView = other.kernelPath
                let l1Path = baseView.appending(otherView)
                let span = l1Path.bytes
                l1Bytes.reserveCapacity(span.count)
                for i in 0..<span.count {
                    l1Bytes.append(span[i])
                }
            }

            #expect(
                l1Bytes == l3Bytes,
                """
                "\(fixture.base)" + "\(fixture.other)" disagrees:
                  L1 = \(Self.format(l1Bytes))
                  L3 = \(Self.format(l3Bytes))
                """
            )
        }

        // MARK: - Helpers

        /// Extract content bytes (excluding NUL) from an owned `Paths.Path`.
        ///
        /// L3's `.bytes` includes NUL per its syscall-hand-off convention;
        /// this helper slices it off to align with L1's "content length" semantics.
        ///
        /// The parameter type is qualified because `Kernel_Core` re-exports
        /// `Path_Primitives.Path` via the platform stack, making bare `Path`
        /// ambiguous in type position.
        static func contentBytes(of path: Paths.Path) -> [UInt8] {
            let span = path.bytes
            var bytes: [UInt8] = []
            bytes.reserveCapacity(span.count - 1)
            for i in 0..<(span.count - 1) {
                bytes.append(span[i])
            }
            return bytes
        }

        static func format(_ bytes: [UInt8]?) -> Swift.String {
            guard let bytes else { return "nil" }
            return "\"\(Swift.String(decoding: bytes, as: UTF8.self))\""
        }

        static func format(_ bytes: [UInt8]) -> Swift.String {
            "\"\(Swift.String(decoding: bytes, as: UTF8.self))\""
        }
    }

    /// Fixture pair for `appending(Path)` equivalence tests.
    struct AppendingFixture: Sendable, CustomStringConvertible {
        let base: Swift.String
        let other: Swift.String

        var description: Swift.String { "\"\(base)\" + \"\(other)\"" }
    }
#endif
