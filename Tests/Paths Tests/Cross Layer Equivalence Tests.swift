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

        /// Seeded pseudo-random fixtures. Generated once at load time via a
        /// SplitMix64 PRNG for reproducibility. Covers paths the hand-written
        /// set does not anticipate (runs of separators, non-ASCII printable
        /// bytes, long paths, paths with separators at varied positions).
        static let generatedFixtures: [Swift.String] = Self.generatePaths(count: 100, seed: 0xDEAD_BEEF_CAFE_BABE)

        /// Combined fixture set. Fixed fixtures provide readable regression
        /// anchors; generated fixtures provide stochastic coverage.
        static let allFixtures: [Swift.String] = fixtures + generatedFixtures

        @Test("parent content-bytes agree", arguments: allFixtures)
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
            // iterate the owned Path's .content (L1 convention: excludes NUL).
            var l1Bytes: [UInt8] = []
            do {
                let baseView = base.kernelPath
                let otherView = other.kernelPath
                let l1Path = baseView.appending(otherView)
                let span = l1Path.content
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

        // MARK: - Generator

        /// Generates `count` pseudo-random valid path strings using a
        /// SplitMix64 PRNG seeded at `seed` for reproducibility.
        ///
        /// Bytes are drawn from the ASCII printable range (0x20-0x7E),
        /// with `/` (0x2F) weighted at ~25% to ensure separator coverage.
        /// Length varies in [1, 64]. The result satisfies `Paths.Path`
        /// validation (non-empty, no control chars, no interior NUL).
        static func generatePaths(count: Int, seed: UInt64) -> [Swift.String] {
            var rng = SplitMix64(seed: seed)
            var result: [Swift.String] = []
            result.reserveCapacity(count)
            for _ in 0..<count {
                let length = Int(rng.next() % 64) + 1
                var bytes: [UInt8] = []
                bytes.reserveCapacity(length)
                for _ in 0..<length {
                    let roll = rng.next() % 4
                    if roll == 0 {
                        bytes.append(0x2F)  // '/'
                    } else {
                        // Printable ASCII excluding 0x2F (handled above)
                        // and excluding 0x20-0x2E (avoids spaces / dots / dashes
                        // at byte boundaries that would bias toward short
                        // components). Range 0x30-0x7E is digits + letters +
                        // symbols.
                        bytes.append(UInt8(rng.next() % 79) + 0x30)
                    }
                }
                result.append(Swift.String(decoding: bytes, as: UTF8.self))
            }
            return result
        }
    }

    /// Fixture pair for `appending(Path)` equivalence tests.
    struct AppendingFixture: Sendable, CustomStringConvertible {
        let base: Swift.String
        let other: Swift.String

        var description: Swift.String { "\"\(base)\" + \"\(other)\"" }
    }

    // MARK: - SplitMix64 PRNG

    /// Seeded 64-bit PRNG for reproducible fixture generation.
    ///
    /// SplitMix64 is the seeding generator used by xoshiro family PRNGs; it's
    /// small, fast, and has good statistical properties for test-data use.
    /// Not cryptographically secure; not for production use.
    struct SplitMix64 {
        private var state: UInt64

        init(seed: UInt64) {
            self.state = seed
        }

        mutating func next() -> UInt64 {
            state = state &+ 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }
#endif
