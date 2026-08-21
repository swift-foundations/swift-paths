extension Path {

    @inlinable
    public static func / (lhs: Path, rhs: Component) -> Path {
        lhs.appending(rhs)
    }

    @_disfavoredOverload
    @inlinable
    public static func / (lhs: Path, rhs: Path) -> Path {
        lhs.appending(rhs)
    }
}

extension Path: ExpressibleByStringLiteral {

    @inlinable
    public init(stringLiteral value: Swift.String) {
        do {
            try self.init(value)
        } catch {
            fatalError("Invalid path literal: \(value) (\(error))")
        }
    }
}

extension Path: ExpressibleByStringInterpolation {

}

extension Path.Component: ExpressibleByStringLiteral {

    @inlinable
    public init(stringLiteral value: Swift.String) {
        do {
            try self.init(value)
        } catch {
            fatalError("Invalid path component literal: \(value) (\(error))")
        }
    }
}

extension Path.Component: ExpressibleByStringInterpolation {

}
