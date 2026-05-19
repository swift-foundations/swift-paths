// ===----------------------------------------------------------------------===//
//
// This source file is part of the swift-path open source project
//
// Copyright (c) 2024 Coen ten Thije Boonkkamp and the swift-path project authors
// Licensed under Apache License v2.0
//
// See LICENSE for license information
//
// ===----------------------------------------------------------------------===//

public import Binary_Primitives

// MARK: - Binary.Serializable

extension Path: Binary.Serializable {
    /// Serializes the path as UTF-8 bytes.
    ///
    /// The serialized output is the UTF-8 encoding of the path string,
    /// suitable for cross-platform storage and transmission. The
    /// `String.UTF8View` (`UInt8` element) bridges to a `Buffer<Byte>`
    /// via the BSLI cross-domain `append(contentsOf:)` extension.
    ///
    /// ```swift
    /// let path = try Path("/Users/coen")
    /// let bytes = path.bytes
    /// // [47, 85, 115, 101, 114, 115, 47, 99, 111, 101, 110]
    /// //  /   U   s   e   r   s   /   c   o   e   n
    /// ```
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ path: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        // Always serialize as UTF-8 for cross-platform compatibility
        buffer.append(contentsOf: path.string.utf8)
    }
}

// MARK: - Binary.Serializable for Component

extension Path.Component: Binary.Serializable {
    /// Serializes the component as UTF-8 bytes.
    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ component: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.append(contentsOf: component.string.utf8)
    }
}
