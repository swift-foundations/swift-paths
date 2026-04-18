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

            // L3 parent via Phase 4b byte-scan. `.bytes` includes NUL, so
            // exclude the last element to compare content-only.
            let l3Bytes: [UInt8]? = l3.parent.map { parent in
                let span = parent.bytes
                var bytes: [UInt8] = []
                bytes.reserveCapacity(span.count - 1)
                for i in 0..<(span.count - 1) {
                    bytes.append(span[i])
                }
                return bytes
            }

            #expect(
                l1Bytes == l3Bytes,
                """
                parent("\(fixture)") disagrees:
                  L1 = \(Self.format(l1Bytes))
                  L3 = \(Self.format(l3Bytes))
                """
            )
        }

        // MARK: - Helpers

        static func format(_ bytes: [UInt8]?) -> Swift.String {
            guard let bytes else { return "nil" }
            return "\"\(Swift.String(decoding: bytes, as: UTF8.self))\""
        }
    }
#endif
