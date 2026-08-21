import Path_Primitives
import Testing

@testable import Paths

extension Paths.Path {
    @Suite
    struct Bridging {
        @Suite
        struct Unit {}
    }
}

extension Paths.Path.Bridging.Unit {
    @Test
    func `withKernelPath yields the same content bytes as the owning path`() throws {
        let path = try Paths.Path("/Users/coen/Documents/file.txt")

        let contentSpan = path.content
        var contentBytes: [Paths.Path.Char] = []
        contentBytes.reserveCapacity(contentSpan.count)
        for i in 0..<contentSpan.count {
            contentBytes.append(contentSpan[i])
        }

        var bridgedBytes: [Paths.Path.Char] = []
        path.withKernelPath { view in
            let span = view.span
            bridgedBytes.reserveCapacity(span.count)
            for i in 0..<span.count {
                bridgedBytes.append(span[i])
            }
        }

        #expect(bridgedBytes == contentBytes)
    }

    @Test
    func `withKernelPath supports nested calls on two distinct paths`() throws {
        let base = try Paths.Path("/Users")
        let other = try Paths.Path("coen")

        var combinedCount = -1
        base.withKernelPath { baseView in
            other.withKernelPath { otherView in
                combinedCount = baseView.count + otherView.count
            }
        }

        #expect(combinedCount == base.content.count + other.content.count)
    }

    @Test
    func `withView yields a view whose length matches the path's content`() throws {
        let path = try Paths.Path("/tmp/example.txt")

        var observedLength = -1
        path.withView { view in
            observedLength = view.length
        }

        #expect(observedLength == path.content.count)
    }
}
