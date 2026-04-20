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

import Testing
@testable import Paths

// MARK: - Path Tests

@Suite("Path Tests")
struct PathTests {

    // MARK: - Initialization

    @Test
    func `Valid absolute path initialization`() throws {
        let path = try Path("/Users/coen/Documents")
        #expect(path.string == "/Users/coen/Documents")
    }

    @Test
    func `Valid relative path initialization`() throws {
        let path = try Path("foo/bar/baz")
        #expect(path.string == "foo/bar/baz")
    }

    @Test
    func `Single component path`() throws {
        let path = try Path("file.txt")
        #expect(path.string == "file.txt")
    }

    @Test
    func `Root path`() throws {
        let path = try Path("/")
        #expect(path.string == "/")
        #if os(Windows)
        #expect(path.isAbsolute == false)
        #else
        #expect(path.isAbsolute == true)
        #endif
    }

    // MARK: - Navigation

    @Test
    func `Parent of nested path`() throws {
        let path = try Path("/usr/local/bin")
        #expect(path.parent?.string == "/usr/local")
    }

    @Test
    func `Parent of root path is nil`() throws {
        let path = try Path("/")
        #expect(path.parent == nil)
    }

    @Test
    func `Parent chain`() throws {
        let path = try Path("/a/b/c")
        #expect(path.parent?.string == "/a/b")
        #expect(path.parent?.parent?.string == "/a")
        #expect(path.parent?.parent?.parent?.string == "/")
        #expect(path.parent?.parent?.parent?.parent == nil)
    }

    @Test
    func `Path components`() throws {
        let path = try Path("/Users/coen/Documents")
        let components = path.components.map(\.string)
        #expect(components == ["Users", "coen", "Documents"])
    }

    @Test
    func `components.last on multi-component path`() throws {
        let path = try Path("/usr/local/bin")
        #expect(path.components.last?.string == "bin")
    }

    @Test
    func `components.last on single-component path`() throws {
        let path = try Path("file.txt")
        #expect(path.components.last?.string == "file.txt")
    }

    // MARK: - Introspection

    @Test
    func `Extension of file`() throws {
        let path = try Path("/tmp/file.txt")
        #expect(path.extension == "txt")
    }

    @Test
    func `Extension with multiple dots`() throws {
        let path = try Path("/tmp/file.tar.gz")
        #expect(path.extension == "gz")
    }

    @Test
    func `Extension of directory (none)`() throws {
        let path = try Path("/usr/local/bin")
        #expect(path.extension == nil)
    }

    @Test
    func `Stem of file`() throws {
        let path = try Path("/tmp/file.txt")
        #expect(path.stem == "file")
    }

    @Test
    func `Stem with multiple dots`() throws {
        let path = try Path("/tmp/file.tar.gz")
        #expect(path.stem == "file.tar")
    }

    @Test
    func `isAbsolute for absolute path`() throws {
        let path = try Path("/usr/bin")
        #if os(Windows)
        #expect(path.isAbsolute == false)
        #else
        #expect(path.isAbsolute == true)
        #endif
    }

    @Test
    func `isAbsolute for relative path`() throws {
        let path = try Path("usr/bin")
        #expect(path.isAbsolute == false)
    }

    // MARK: - Operators

    @Test
    func `Slash operator with string`() throws {
        let path = try Path("/usr")
        let newPath = path / "local" / "bin"
        #expect(newPath.string == "/usr/local/bin")
    }

    @Test
    func `Slash operator with Component`() throws {
        let path = try Path("/usr")
        let component = try Path.Component("local")
        let newPath = path / component
        #expect(newPath.string == "/usr/local")
    }

    @Test
    func `Slash operator with chained components`() throws {
        let dir = try Path("/Users/coen")
        let nested = dir / "Documents" / "Projects" / "readme.txt"
        #expect(nested.string == "/Users/coen/Documents/Projects/readme.txt")
    }

    @Test
    func `Slash operator with relative path`() throws {
        let dir = try Path("/Users/coen")
        let rel = try Path("Documents/Projects/readme.txt")
        let nested = dir / rel
        #expect(nested.string == "/Users/coen/Documents/Projects/readme.txt")
    }

    // MARK: - hasPrefix

    @Test
    func `hasPrefix returns true for proper prefix`() throws {
        let path = try Path("/Users/coen/Documents")
        #expect(path.hasPrefix(try Path("/Users")))
        #expect(path.hasPrefix(try Path("/Users/coen")))
        #expect(path.hasPrefix(try Path("/Users/coen/Documents")))
    }

    @Test
    func `hasPrefix returns false for mismatch`() throws {
        let path = try Path("/Users/coen/Documents")
        #expect(!path.hasPrefix(try Path("/var")))
        #expect(!path.hasPrefix(try Path("/Users/bob")))
    }

    @Test
    func `hasPrefix returns false when other is longer`() throws {
        let path = try Path("/Users")
        #expect(!path.hasPrefix(try Path("/Users/coen/Documents")))
    }

    @Test
    func `hasPrefix with relative paths`() throws {
        let path = try Path("foo/bar/baz")
        #expect(path.hasPrefix(try Path("foo")))
        #expect(path.hasPrefix(try Path("foo/bar")))
        #expect(!path.hasPrefix(try Path("bar")))
    }

    // MARK: - relative(to:)

    @Test
    func `relative(to:) strips the base prefix`() throws {
        let full = try Path("/Users/coen/Documents/file.txt")
        let base = try Path("/Users/coen")
        let rel = full.relative(to: base)
        #expect(rel?.string == "Documents/file.txt")
    }

    @Test("relative(to:) returns `.` for equal paths")
    func relativeEqualPaths() throws {
        let p = try Path("/Users/coen")
        let rel = p.relative(to: p)
        #expect(rel?.string == ".")
    }

    @Test
    func `relative(to:) returns nil when base isn't a prefix`() throws {
        let full = try Path("/Users/coen/Documents")
        let base = try Path("/var/log")
        #expect(full.relative(to: base) == nil)
    }

    // MARK: - Components lazy view

    @Test
    func `components.last with trailing separator omits empty`() throws {
        #expect(try Path("backup/").components.last?.string == "backup")
        #expect(try Path("/foo/").components.last?.string == "foo")
        #expect(try Path("/").components.last == nil)
    }

    @Test
    func `components.first returns the first non-empty segment`() throws {
        #expect(try Path("/foo/bar").components.first?.string == "foo")
        #expect(try Path("//foo").components.first?.string == "foo")
        #expect(try Path("foo/bar").components.first?.string == "foo")
    }

    @Test
    func `components iteration omits empty segments`() throws {
        let path = try Path("/foo//bar/")
        let names = path.components.map(\.string)
        #expect(names == ["foo", "bar"])
    }

    @Test
    func `components.count matches eager materialization`() throws {
        let path = try Path("/a/b/c/d/e")
        #expect(path.components.count == 5)
    }

    // MARK: - Protocols

    @Test
    func `ExpressibleByStringLiteral`() {
        let path: Path = "/usr/local/bin"
        #expect(path.string == "/usr/local/bin")
    }

    @Test
    func `Hashable conformance`() throws {
        let path1 = try Path("/usr/local")
        let path2 = try Path("/usr/local")
        let path3 = try Path("/usr/bin")

        #expect(path1.hashValue == path2.hashValue)
        #expect(path1.hashValue != path3.hashValue)
    }

    @Test
    func `Equatable conformance`() throws {
        let path1 = try Path("/usr/local")
        let path2 = try Path("/usr/local")
        let path3 = try Path("/usr/bin")

        #expect(path1 == path2)
        #expect(path1 != path3)
    }

    @Test
    func `Use in Set`() throws {
        let path1 = try Path("/usr/local")
        let path2 = try Path("/usr/local")
        let path3 = try Path("/usr/bin")

        let set: Set<Path> = [path1, path2, path3]
        #expect(set.count == 2)
    }

    @Test
    func `Use as Dictionary key`() throws {
        let path1 = try Path("/usr/local")
        let path2 = try Path("/usr/bin")

        var dict: [Path: Int] = [:]
        dict[path1] = 1
        dict[path2] = 2

        #expect(dict[path1] == 1)
        #expect(dict[path2] == 2)
    }

    @Test
    func `String conversion`() throws {
        let path = try Path("/usr/local/bin")
        #expect(String(path) == "/usr/local/bin")
    }
}

// MARK: - Path.Error Tests

@Suite("Path.Error Tests")
struct PathErrorTests {

    @Test
    func `Empty path throws empty error`() {
        #expect(throws: Path.Error.empty) {
            try Path.init("")
        }
    }

    @Test
    func `Interior NUL byte throws containsInteriorNUL`() {
        #expect(throws: Path.Error.containsInteriorNUL) {
            try Path.init("/tmp/file\0.txt")
        }
    }

    @Test
    func `Newline character throws containsControlCharacters`() {
        #expect(throws: Path.Error.containsControlCharacters) {
            try Path.init("/tmp/file\n.txt")
        }
    }

    @Test
    func `Carriage return throws containsControlCharacters`() {
        #expect(throws: Path.Error.containsControlCharacters) {
            try Path.init("/tmp/file\r.txt")
        }
    }

    @Test
    func `Tab character throws containsControlCharacters`() {
        #expect(throws: Path.Error.containsControlCharacters) {
            try Path.init("/tmp/file\t.txt")
        }
    }

    @Test
    func `Bell character throws containsControlCharacters`() {
        #expect(throws: Path.Error.containsControlCharacters) {
            try Path.init("/tmp/file\u{07}.txt")
        }
    }

    @Test
    func `Error cases are equatable`() {
        #expect(Path.Error.empty == Path.Error.empty)
        #expect(Path.Error.containsControlCharacters == Path.Error.containsControlCharacters)
        #expect(Path.Error.containsInteriorNUL == Path.Error.containsInteriorNUL)
        #expect(Path.Error.empty != Path.Error.containsControlCharacters)
        #expect(Path.Error.containsControlCharacters != Path.Error.containsInteriorNUL)
    }

    @Test
    func `Error is Sendable`() async {
        let error = Path.Error.empty

        await Task {
            #expect(error == .empty)
        }.value
    }

    @Test
    func `Error descriptions`() {
        #expect(Path.Error.empty.description.contains("empty"))
        #expect(Path.Error.containsControlCharacters.description.contains("control"))
        #expect(Path.Error.containsInteriorNUL.description.contains("NUL"))
    }
}

// MARK: - Path.Component Tests

@Suite("Path.Component Tests")
struct PathComponentTests {

    // MARK: - Initialization

    @Test
    func `Valid component initialization`() throws {
        let component = try Path.Component("file.txt")
        #expect(component.string == "file.txt")
    }

    @Test
    func `Component with special characters`() throws {
        let component = try Path.Component("file-name_v2.0.txt")
        #expect(component.string == "file-name_v2.0.txt")
    }

    @Test
    func `Component with spaces`() throws {
        let component = try Path.Component("my file.txt")
        #expect(component.string == "my file.txt")
    }

    // MARK: - Properties

    @Test
    func `Extension of component`() throws {
        let component = try Path.Component("readme.txt")
        #expect(component.extension == "txt")
    }

    @Test
    func `Extension of dotfile (none)`() throws {
        let component = try Path.Component(".gitignore")
        #expect(component.extension == nil)
    }

    @Test
    func `Extension with multiple dots`() throws {
        let component = try Path.Component("file.tar.gz")
        #expect(component.extension == "gz")
    }

    @Test
    func `Extension when none`() throws {
        let component = try Path.Component("Makefile")
        #expect(component.extension == nil)
    }

    @Test
    func `Stem of component`() throws {
        let component = try Path.Component("readme.txt")
        #expect(component.stem == "readme")
    }

    @Test
    func `Stem of dotfile`() throws {
        let component = try Path.Component(".gitignore")
        #expect(component.stem == ".gitignore")
    }

    @Test
    func `Stem with multiple dots`() throws {
        let component = try Path.Component("archive.tar.gz")
        #expect(component.stem == "archive.tar")
    }

    @Test
    func `Stem when no extension`() throws {
        let component = try Path.Component("Makefile")
        #expect(component.stem == "Makefile")
    }

    // MARK: - Protocols

    @Test
    func `ExpressibleByStringLiteral`() {
        let component: Path.Component = "file.txt"
        #expect(component.string == "file.txt")
    }

    @Test
    func `Hashable conformance`() throws {
        let comp1 = try Path.Component("file.txt")
        let comp2 = try Path.Component("file.txt")
        let comp3 = try Path.Component("other.txt")

        #expect(comp1.hashValue == comp2.hashValue)
        #expect(comp1.hashValue != comp3.hashValue)
    }

    @Test
    func `Equatable conformance`() throws {
        let comp1 = try Path.Component("file.txt")
        let comp2 = try Path.Component("file.txt")
        let comp3 = try Path.Component("other.txt")

        #expect(comp1 == comp2)
        #expect(comp1 != comp3)
    }

    @Test
    func `String conversion`() throws {
        let component = try Path.Component("file.txt")
        #expect(String(component) == "file.txt")
    }

    // MARK: - Integration with Path

    @Test
    func `Component can be appended to path`() throws {
        let path = try Path("/usr/local")
        let component = try Path.Component("bin")
        let newPath = path / component
        #expect(newPath.string == "/usr/local/bin")
    }
}

// MARK: - Path.Component.Error Tests

@Suite("Path.Component.Error Tests")
struct PathComponentErrorTests {

    @Test
    func `Empty component throws empty error`() {
        #expect(throws: Path.Component.Error.empty) {
            try Path.Component.init("")
        }
    }

    @Test
    func `Component with path separator throws error`() {
        #expect(throws: Path.Component.Error.containsPathSeparator) {
            try Path.Component.init("foo/bar")
        }
    }

    @Test
    func `Interior NUL byte throws containsInteriorNUL`() {
        #expect(throws: Path.Component.Error.containsInteriorNUL) {
            try Path.Component.init("file\0.txt")
        }
    }

    @Test
    func `Control character throws containsControlCharacters`() {
        #expect(throws: Path.Component.Error.containsControlCharacters) {
            try Path.Component.init("file\n.txt")
        }
    }

    @Test
    func `Error cases are equatable`() {
        #expect(Path.Component.Error.empty == Path.Component.Error.empty)
        #expect(Path.Component.Error.containsPathSeparator == Path.Component.Error.containsPathSeparator)
        #expect(Path.Component.Error.empty != Path.Component.Error.containsPathSeparator)
    }

    @Test
    func `Error descriptions`() {
        #expect(Path.Component.Error.empty.description.contains("empty"))
        #expect(Path.Component.Error.containsPathSeparator.description.contains("separator"))
        #expect(Path.Component.Error.containsControlCharacters.description.contains("control"))
        #expect(Path.Component.Error.containsInteriorNUL.description.contains("NUL"))
    }
}
