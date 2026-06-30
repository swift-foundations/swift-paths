# swift-paths

![Development Status](https://img.shields.io/badge/status-active--development-blue.svg)

Owned, validated, platform-native filesystem paths with component iteration, navigation, filename introspection, and borrowed views for syscall interop.

---

## Key Features

- **Validated construction** — `Path(_:)` rejects empty strings, interior NUL bytes, and control characters, throwing a typed `Path.Error`.
- **Platform-native encoding** — stores UTF-8 (`UInt8`) on POSIX and UTF-16 (`UInt16`) on Windows through the `Path.Char` alias, recognizing both `/` and `\` as separators on Windows.
- **Lazy component views** — `path.components` is a `BidirectionalCollection` that materializes each `Path.Component` on demand by scanning bytes, so `.first`, `.last`, and iteration avoid building an intermediate array.
- **Path navigation** — `parent`, `appending(_:)`, `relative(to:)`, `hasPrefix(_:)`, and the `/` operator compose paths and components.
- **Filename introspection** — `stem` and `extension` on both `Path` and `Path.Component`, with a settable `Path.extension` and validated `Stem` / `Extension` types.
- **Borrowed syscall interop** — `view` and `kernelPath` expose `~Escapable` borrowed views that bridge to `Path_Primitives.Path.Borrowed` without copying on POSIX; `bytes` and `content` give safe `Span<Path.Char>` access.
- **Binary serialization** — `Path` conforms to `Binary.Serializable`, emitting UTF-8 bytes for cross-platform storage regardless of the native encoding.
- **String-literal ergonomics** — `Path`, `Path.Component`, `Stem`, and `Extension` are all `ExpressibleByStringLiteral` for construction from literals.

---

## Quick Start

```swift
import Paths

// Paths validate on construction; the initializer throws Path.Error.
let dir = try Path("/Users/coen/Documents")

// Join with `/` — string literals become Path.Component.
let file = dir / "readme.txt"
print(file.string)              // "/Users/coen/Documents/readme.txt"
print(file.isAbsolute)          // true

// Walk components lazily — no array is materialized up front.
print(file.components.map(\.string))
// ["Users", "coen", "Documents", "readme.txt"]

// Filename introspection on the last component.
print(file.stem?.string)        // Optional("readme")
print(file.extension?.string)   // Optional("txt")

// Navigate to the parent directory.
print(file.parent?.string)      // Optional("/Users/coen/Documents")
```

---

## Installation

```swift
dependencies: [
    .package(url: "https://github.com/swift-foundations/swift-paths.git", branch: "main")
]
```

```swift
.target(
    name: "YourTarget",
    dependencies: [
        .product(name: "Paths", package: "swift-paths")
    ]
)
```

Requires Swift 6.3.1 and macOS 26 / iOS 26 / tvOS 26 / watchOS 26 / visionOS 26.

---

## Community

<!-- BEGIN: discussion -->
*Discussion thread will be created at first public flip.*
<!-- END: discussion -->

## License

Apache 2.0. See [LICENSE](LICENSE.md).
