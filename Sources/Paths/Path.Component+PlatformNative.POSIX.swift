#if !os(Windows)

    extension Path.Component {

        @inlinable
        public init(platformNative codeUnits: [Path.Char]) throws(Error) {
            guard let string = Swift.String(validating: codeUnits, as: UTF8.self) else {
                throw .invalidUTF8
            }
            try self.init(string)
        }
    }

#endif
