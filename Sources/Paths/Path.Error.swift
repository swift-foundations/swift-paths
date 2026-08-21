extension Path {

    public enum Error: Swift.Error, Sendable, Equatable {

        case empty

        case containsControlCharacters

        case containsInteriorNUL
    }
}

extension Path.Error: CustomStringConvertible {
    public var description: Swift.String {
        switch self {
        case .empty:
            return "Path is empty"

        case .containsControlCharacters:
            return "Path contains control characters"

        case .containsInteriorNUL:
            return "Path contains interior NUL byte"
        }
    }
}
