import Kernel_Core
import Testing

@testable import Paths

#if !os(Windows)
    @Suite
    struct `L1 ↔ L3 equivalence (POSIX)` {

        static let fixtures: [Swift.String] = [
            "/",
            "/foo",
            "/foo/bar",
            "/foo/bar/baz",
            "/a/b/c/d/e/f",
            "foo",
            "foo/bar",
            "foo/bar/baz",
            "/foo/",
            "foo/",
            ".",
            "..",
            "./foo",
            "../foo",
        ]

        static let generatedFixtures: [Swift.String] = Self.generatePaths(
            count: 100,
            seed: 0xDEAD_BEEF_CAFE_BABE
        )

        static let allFixtures: [Swift.String] = fixtures + generatedFixtures

        @Test(arguments: allFixtures)
        func `Parent content-bytes agree`(fixture: Swift.String) throws {
            let l3 = try Path(fixture)

            var l1Bytes: [UInt8]? = nil
            l3.withKernelPath { view in
                if let span = view.parent {
                    var bytes: [UInt8] = []
                    bytes.reserveCapacity(span.count)
                    for i in 0..<span.count {
                        bytes.append(span[i])
                    }
                    l1Bytes = bytes
                }
            }

            let l3Bytes: [UInt8]? = l3.parent.map { Self.contentBytes(of: $0) }

            #expect(
                l1Bytes == l3Bytes,
                """
                parent("\(fixture)") disagrees:
                  L1 = \(Self.format(l1Bytes))
                  L3 = \(Self.format(l3Bytes))
                """
            )
        }

        static let appendingFixtures: [AppendingFixture] = [
            .init(base: "/Users", other: "coen"),
            .init(base: "/Users", other: "coen/Documents"),
            .init(base: "foo", other: "bar"),
            .init(base: "/Users/", other: "coen"),
            .init(base: "foo/", other: "bar"),
            .init(base: "/", other: "foo"),
            .init(base: "/a", other: "b/c/d"),
            .init(base: "a/b", other: "c/d"),
        ]

        @Test(arguments: appendingFixtures)
        func `Appending(Path) relative content-bytes agree`(fixture: AppendingFixture) throws {
            let base = try Path(fixture.base)
            let other = try Path(fixture.other)

            let l3Result = base.appending(other)
            let l3Bytes = Self.contentBytes(of: l3Result)

            var l1Bytes: [UInt8] = []
            base.withKernelPath { baseView in
                other.withKernelPath { otherView in
                    let l1Path = baseView.appending(otherView)
                    let span = l1Path.content
                    l1Bytes.reserveCapacity(span.count)
                    for i in 0..<span.count {
                        l1Bytes.append(span[i])
                    }
                }
            }

            #expect(
                l1Bytes == l3Bytes,
                """
                "\(fixture.base)" + "\(fixture.other)" disagrees:
                  L1 = \(Self.format(l1Bytes))
                  L3 = \(Self.format(l3Bytes))
                """
            )
        }

        static func contentBytes(of path: Paths.Path) -> [UInt8] {
            let span = path.bytes
            var bytes: [UInt8] = []
            bytes.reserveCapacity(span.count - 1)
            for i in 0..<(span.count - 1) {
                bytes.append(span[i])
            }
            return bytes
        }

        static func format(_ bytes: [UInt8]?) -> Swift.String {
            guard let bytes else { return "nil" }
            return "\"\(Swift.String(decoding: bytes, as: UTF8.self))\""
        }

        static func format(_ bytes: [UInt8]) -> Swift.String {
            "\"\(Swift.String(decoding: bytes, as: UTF8.self))\""
        }

        static func generatePaths(count: Int, seed: UInt64) -> [Swift.String] {
            var rng = SplitMix64(seed: seed)
            var result: [Swift.String] = []
            result.reserveCapacity(count)
            for _ in 0..<count {
                let length = Int(rng.next() % 64) + 1
                var bytes: [UInt8] = []
                bytes.reserveCapacity(length)
                for _ in 0..<length {
                    let roll = rng.next() % 4
                    if roll == 0 {
                        bytes.append(0x2F)
                    } else {

                        bytes.append(UInt8(rng.next() % 79) + 0x30)
                    }
                }
                result.append(Swift.String(decoding: bytes, as: UTF8.self))
            }
            return result
        }
    }

    struct AppendingFixture: Sendable, CustomStringConvertible {
        let base: Swift.String
        let other: Swift.String

        var description: Swift.String { "\"\(base)\" + \"\(other)\"" }
    }

    struct SplitMix64 {
        private var state: UInt64

        init(seed: UInt64) {
            self.state = seed
        }

        mutating func next() -> UInt64 {
            state = state &+ 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }
#endif
