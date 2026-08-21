extension Path.Component {

    public enum Error: Swift.Error, Sendable, Equatable {

        case empty

        case containsPathSeparator

        case containsControlCharacters

        case containsInteriorNUL

        case invalidUTF8
    }
}

extension Path.Component.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .empty:
            return "Component is empty"

        case .containsPathSeparator:
            return "Component contains path separator"

        case .containsControlCharacters:
            return "Component contains control characters"

        case .containsInteriorNUL:
            return "Component contains interior NUL byte"

        case .invalidUTF8:
            return "Component contains invalid UTF-8"
        }
    }
}
