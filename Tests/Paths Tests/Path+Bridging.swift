// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-paths open source project
//
// Copyright (c) 2024-2026 Coen ten Thije Boonkkamp and the swift-paths project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

import Path_Primitives
import Testing

@testable import Paths

// The `Path_Primitives` import (needed to read `.span`/`.count` off the L1
// bridge type below) makes bare `Path` ambiguous in type position — the same
// ambiguity noted in `Cross Layer Equivalence Tests.swift`. Qualify as
// `Paths.Path` throughout this file.

// MARK: - F-001 regression: kernel-path / view pointer escape
//
// `Path.kernelPath` (a computed property) and `Path.Borrowed.init(borrowing:)`
// formerly obtained a raw pointer via `_storage.buffer.withUnsafeBufferPointer`
// and let it escape the closure, asserting extended validity via
// `_overrideLifetime` — a lifetime claim not backed by any compiler- or
// stdlib-verified guarantee. The fix replaces both with scoped
// `withKernelPath(_:)` / `withView(_:)` methods that keep the pointer inside
// the `withUnsafeBufferPointer` closure for its entire use.
//
// These tests exercise the new scoped API surface directly: against the
// pre-fix source (only the escaping `kernelPath` property / `view` property
// existed), this file fails to compile — `value of type 'Path' has no member
// 'withKernelPath'` / `'withView'`. Post-fix, it compiles and the assertions
// pass.

extension Paths.Path {
    @Suite
    struct Bridging {
        @Suite
        struct Unit {}
    }
}

extension Paths.Path.Bridging.Unit {
    @Test
    func `withKernelPath yields the same content bytes as the owning path`() throws {
        let path = try Paths.Path("/Users/coen/Documents/file.txt")

        let contentSpan = path.content
        var contentBytes: [Paths.Path.Char] = []
        contentBytes.reserveCapacity(contentSpan.count)
        for i in 0..<contentSpan.count {
            contentBytes.append(contentSpan[i])
        }

        var bridgedBytes: [Paths.Path.Char] = []
        path.withKernelPath { view in
            let span = view.span
            bridgedBytes.reserveCapacity(span.count)
            for i in 0..<span.count {
                bridgedBytes.append(span[i])
            }
        }

        #expect(bridgedBytes == contentBytes)
    }

    @Test
    func `withKernelPath supports nested calls on two distinct paths`() throws {
        let base = try Paths.Path("/Users")
        let other = try Paths.Path("coen")

        // `count` here is `Path_Primitives.Path.Borrowed.count` (the L1
        // bridge type), distinct from L2 `Paths.Path.Borrowed.length`.
        var combinedCount = -1
        base.withKernelPath { baseView in
            other.withKernelPath { otherView in
                combinedCount = baseView.count + otherView.count
            }
        }

        #expect(combinedCount == base.content.count + other.content.count)
    }

    @Test
    func `withView yields a view whose length matches the path's content`() throws {
        let path = try Paths.Path("/tmp/example.txt")

        var observedLength = -1
        path.withView { view in
            observedLength = view.length
        }

        #expect(observedLength == path.content.count)
    }
}
