@testable import Paths

extension Path {

    enum Fixture {

        #if os(Windows)
            static let separator: Swift.String = "\\"
        #else
            static let separator: Swift.String = "/"
        #endif

        #if os(Windows)
            static let root: Swift.String = "C:\\"
        #else
            static let root: Swift.String = "/"
        #endif
    }
}
