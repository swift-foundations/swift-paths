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

@testable import Paths

// MARK: - Platform Fixtures

extension Path {
    /// Platform facts the expectations in this test target are written against.
    ///
    /// `Path` is platform-native in two ways that a literal expectation cannot
    /// spell portably:
    ///
    /// - **Joining** inserts `Path.separator`, which is `\` on Windows and `/`
    ///   elsewhere. An expectation such as `"/usr/local/bin"` therefore only
    ///   describes the POSIX result; the Windows result is `"/usr\local\bin"`.
    /// - **Rootedness** on Windows requires a drive-letter or UNC prefix, so a
    ///   POSIX-shaped literal like `"/foo"` is *relative* on Windows. Tests
    ///   that turn on `isAbsolute` — `hasPrefix`, `relative(to:)`, `parent` —
    ///   need a fixture that is genuinely absolute on the host platform.
    ///
    /// Composing expectations from these values keeps one assertion per
    /// behaviour while letting each platform assert its own native form.
    enum Fixture {
        /// The separator `Path` inserts when joining two paths or components.
        #if os(Windows)
            static let separator: Swift.String = "\\"
        #else
            static let separator: Swift.String = "/"
        #endif

        /// An absolute root for this platform, including its trailing separator.
        ///
        /// Appending directly (`"\(root)foo"`) yields an absolute path on both
        /// POSIX (`/foo`) and Windows (`C:\foo`).
        #if os(Windows)
            static let root: Swift.String = "C:\\"
        #else
            static let root: Swift.String = "/"
        #endif
    }
}
