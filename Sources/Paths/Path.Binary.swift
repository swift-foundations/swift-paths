public import Binary_Primitives
public import Binary_Serializable_Primitives

extension Path: Binary.Serializable {

    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ path: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {

        buffer.append(contentsOf: path.string.utf8)
    }
}

extension Path.Component: Binary.Serializable {

    @inlinable
    public static func serialize<Buffer: RangeReplaceableCollection>(
        _ component: Self,
        into buffer: inout Buffer
    ) where Buffer.Element == Byte {
        buffer.append(contentsOf: component.string.utf8)
    }
}
