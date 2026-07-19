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

import Testing

@testable import Paths

// MARK: - F-002 regression: rootedness agreement in hasPrefix / relative(to:)
//
// `Components` strips the leading separator (POSIX) or UNC prefix (Windows)
// that marks a path as absolute, so an absolute path's leading component(s)
// were textually indistinguishable from a relative path's leading
// component(s). `hasPrefix`/`relative(to:)` walked components without first
// checking that `self`/`other` agree on `isAbsolute`, so containment checks
// could spuriously succeed across mismatched roots (e.g. relative "foo" read
// as a "prefix" of absolute "/foo/bar").

extension Path {
    @Suite
    struct Navigation {
        @Suite
        struct `Edge Case` {}
    }
}

extension Path.Navigation.`Edge Case` {
    // MARK: hasPrefix

    @Test
    func `hasPrefix is false when self is absolute and other is relative with the same leading component`() throws {
        let path = try Path("/foo/bar")
        let other = try Path("foo")
        #expect(path.hasPrefix(other) == false)
    }

    @Test
    func `hasPrefix is false when self is relative and other is the absolute root`() throws {
        let path = try Path("foo")
        let other = try Path("/")
        #expect(path.hasPrefix(other) == false)
    }

    @Test
    func `hasPrefix is false when self is relative and other is absolute with the same leading component`() throws {
        let path = try Path("foo/etc")
        let other = try Path("/foo")
        #expect(path.hasPrefix(other) == false)
    }

    @Test
    func `hasPrefix still returns true for a genuine absolute prefix`() throws {
        let path = try Path("/Users/coen/Documents/file.txt")
        let other = try Path("/Users/coen")
        #expect(path.hasPrefix(other))
    }

    @Test
    func `hasPrefix still returns true for a genuine relative prefix`() throws {
        let path = try Path("foo/bar/baz")
        let other = try Path("foo/bar")
        #expect(path.hasPrefix(other))
    }

    // MARK: relative(to:)

    @Test
    func `relative(to:) is nil when self is absolute and base is relative with the same leading component`() throws {
        let path = try Path("/foo/bar")
        let base = try Path("foo")
        #expect(path.relative(to: base) == nil)
    }

    @Test
    func `relative(to:) is nil when self is relative and base is the absolute root`() throws {
        let path = try Path("foo")
        let base = try Path("/")
        #expect(path.relative(to: base) == nil)
    }

    @Test
    func `relative(to:) is nil when self is relative and base is absolute with the same leading component`() throws {
        let path = try Path("foo/etc")
        let base = try Path("/foo")
        #expect(path.relative(to: base) == nil)
    }

    @Test
    func `relative(to:) still strips a genuine absolute base`() throws {
        let path = try Path("/Users/coen/Documents/file.txt")
        let base = try Path("/Users/coen")
        #expect(path.relative(to: base)?.string == "Documents/file.txt")
    }

    // MARK: Windows drive / UNC rootedness
    //
    // Windows-specific absolute-path detection (`isAbsolute`) only compiles
    // its Windows branch under `#if os(Windows)`; on POSIX hosts `isAbsolute`
    // takes the POSIX branch regardless of the string's shape, so these
    // cases cannot be meaningfully asserted outside a Windows host. They are
    // compiled (and will run) only in Windows CI.
    #if os(Windows)
        @Test
        func `hasPrefix is false across differing Windows drive-letter roots`() throws {
            let path = try Path("D:\\Users\\foo")
            let other = try Path("C:\\")
            #expect(path.hasPrefix(other) == false)
        }

        @Test
        func `hasPrefix is false between a drive-absolute path and a UNC-absolute root`() throws {
            let path = try Path("C:\\Users\\foo")
            let other = try Path("\\\\server\\Users")
            #expect(path.hasPrefix(other) == false)
        }

        @Test
        func `hasPrefix still returns true for a genuine Windows drive-letter prefix`() throws {
            let path = try Path("C:\\Users\\coen\\file.txt")
            let other = try Path("C:\\Users\\coen")
            #expect(path.hasPrefix(other))
        }
    #endif
}
