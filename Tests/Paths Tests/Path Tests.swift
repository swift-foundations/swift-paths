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

    @Test("Valid absolute path initialization")
    func initValidAbsolutePath() throws {
        let path = try Path("/Users/coen/Documents")
        #expect(path.string == "/Users/coen/Documents")
    }

    @Test("Valid relative path initialization")
    func initValidRelativePath() throws {
        let path = try Path("foo/bar/baz")
        #expect(path.string == "foo/bar/baz")
    }

    @Test("Single component path")
    func initSingleComponent() throws {
        let path = try Path("file.txt")
        #expect(path.string == "file.txt")
    }

    @Test("Root path")
    func initRootPath() throws {
        let path = try Path("/")
        #expect(path.string == "/")
        #if os(Windows)
        #expect(path.isAbsolute == false)
        #else
        #expect(path.isAbsolute == true)
        #endif
    }

    // MARK: - Navigation

    @Test("Parent of nested path")
    func parentOfNestedPath() throws {
        let path = try Path("/usr/local/bin")
        #expect(path.parent?.string == "/usr/local")
    }

    @Test("Parent of root path is nil")
    func parentOfRootIsNil() throws {
        let path = try Path("/")
        #expect(path.parent == nil)
    }

    @Test("Parent chain")
    func parentChain() throws {
        let path = try Path("/a/b/c")
        #expect(path.parent?.string == "/a/b")
        #expect(path.parent?.parent?.string == "/a")
        #expect(path.parent?.parent?.parent?.string == "/")
        #expect(path.parent?.parent?.parent?.parent == nil)
    }

    @Test("Path components")
    func pathComponents() throws {
        let path = try Path("/Users/coen/Documents")
        let components = path.components.map(\.string)
        #expect(components == ["Users", "coen", "Documents"])
    }

    @Test("Last component")
    func lastComponent() throws {
        let path = try Path("/usr/local/bin")
        #expect(path.lastComponent?.string == "bin")
    }

    @Test("Last component of single component path")
    func lastComponentOfSingleComponent() throws {
        let path = try Path("file.txt")
        #expect(path.lastComponent?.string == "file.txt")
    }

    // MARK: - Introspection

    @Test("Extension of file")
    func extensionOfFile() throws {
        let path = try Path("/tmp/file.txt")
        #expect(path.extension == "txt")
    }

    @Test("Extension with multiple dots")
    func extensionWithMultipleDots() throws {
        let path = try Path("/tmp/file.tar.gz")
        #expect(path.extension == "gz")
    }

    @Test("Extension of directory (none)")
    func extensionOfDirectory() throws {
        let path = try Path("/usr/local/bin")
        #expect(path.extension == nil)
    }

    @Test("Stem of file")
    func stemOfFile() throws {
        let path = try Path("/tmp/file.txt")
        #expect(path.stem == "file")
    }

    @Test("Stem with multiple dots")
    func stemWithMultipleDots() throws {
        let path = try Path("/tmp/file.tar.gz")
        #expect(path.stem == "file.tar")
    }

    @Test("isAbsolute for absolute path")
    func isAbsoluteForAbsolutePath() throws {
        let path = try Path("/usr/bin")
        #if os(Windows)
        #expect(path.isAbsolute == false)
        #else
        #expect(path.isAbsolute == true)
        #endif
    }

    @Test("isAbsolute for relative path")
    func isAbsoluteForRelativePath() throws {
        let path = try Path("usr/bin")
        #expect(path.isAbsolute == false)
    }

    // MARK: - Operators

    @Test("Slash operator with string")
    func slashOperatorWithString() throws {
        let path = try Path("/usr")
        let newPath = path / "local" / "bin"
        #expect(newPath.string == "/usr/local/bin")
    }

    @Test("Slash operator with Component")
    func slashOperatorWithComponent() throws {
        let path = try Path("/usr")
        let component = try Path.Component("local")
        let newPath = path / component
        #expect(newPath.string == "/usr/local")
    }

    @Test("Slash operator with chained components")
    func slashOperatorWithChainedComponents() throws {
        let dir = try Path("/Users/coen")
        let nested = dir / "Documents" / "Projects" / "readme.txt"
        #expect(nested.string == "/Users/coen/Documents/Projects/readme.txt")
    }

    @Test("Slash operator with relative path")
    func slashOperatorWithRelativePath() throws {
        let dir = try Path("/Users/coen")
        let rel = try Path("Documents/Projects/readme.txt")
        let nested = dir / rel
        #expect(nested.string == "/Users/coen/Documents/Projects/readme.txt")
    }

    // MARK: - Protocols

    @Test("ExpressibleByStringLiteral")
    func expressibleByStringLiteral() {
        let path: Path = "/usr/local/bin"
        #expect(path.string == "/usr/local/bin")
    }

    @Test("Hashable conformance")
    func hashableConformance() throws {
        let path1 = try Path("/usr/local")
        let path2 = try Path("/usr/local")
        let path3 = try Path("/usr/bin")

        #expect(path1.hashValue == path2.hashValue)
        #expect(path1.hashValue != path3.hashValue)
    }

    @Test("Equatable conformance")
    func equatableConformance() throws {
        let path1 = try Path("/usr/local")
        let path2 = try Path("/usr/local")
        let path3 = try Path("/usr/bin")

        #expect(path1 == path2)
        #expect(path1 != path3)
    }

    @Test("Use in Set")
    func useInSet() throws {
        let path1 = try Path("/usr/local")
        let path2 = try Path("/usr/local")
        let path3 = try Path("/usr/bin")

        let set: Set<Path> = [path1, path2, path3]
        #expect(set.count == 2)
    }

    @Test("Use as Dictionary key")
    func useAsDictionaryKey() throws {
        let path1 = try Path("/usr/local")
        let path2 = try Path("/usr/bin")

        var dict: [Path: Int] = [:]
        dict[path1] = 1
        dict[path2] = 2

        #expect(dict[path1] == 1)
        #expect(dict[path2] == 2)
    }

    @Test("String conversion")
    func stringConversion() throws {
        let path = try Path("/usr/local/bin")
        #expect(String(path) == "/usr/local/bin")
    }
}

// MARK: - Path.Error Tests

@Suite("Path.Error Tests")
struct PathErrorTests {

    @Test("Empty path throws empty error")
    func emptyPathThrowsError() {
        #expect(throws: Path.Error.empty) {
            try Path.init("")
        }
    }

    @Test("Interior NUL byte throws containsInteriorNUL")
    func interiorNULThrowsError() {
        #expect(throws: Path.Error.containsInteriorNUL) {
            try Path.init("/tmp/file\0.txt")
        }
    }

    @Test("Newline character throws containsControlCharacters")
    func newlineThrowsError() {
        #expect(throws: Path.Error.containsControlCharacters) {
            try Path.init("/tmp/file\n.txt")
        }
    }

    @Test("Carriage return throws containsControlCharacters")
    func carriageReturnThrowsError() {
        #expect(throws: Path.Error.containsControlCharacters) {
            try Path.init("/tmp/file\r.txt")
        }
    }

    @Test("Tab character throws containsControlCharacters")
    func tabThrowsError() {
        #expect(throws: Path.Error.containsControlCharacters) {
            try Path.init("/tmp/file\t.txt")
        }
    }

    @Test("Bell character throws containsControlCharacters")
    func bellThrowsError() {
        #expect(throws: Path.Error.containsControlCharacters) {
            try Path.init("/tmp/file\u{07}.txt")
        }
    }

    @Test("Error cases are equatable")
    func errorEquatable() {
        #expect(Path.Error.empty == Path.Error.empty)
        #expect(Path.Error.containsControlCharacters == Path.Error.containsControlCharacters)
        #expect(Path.Error.containsInteriorNUL == Path.Error.containsInteriorNUL)
        #expect(Path.Error.empty != Path.Error.containsControlCharacters)
        #expect(Path.Error.containsControlCharacters != Path.Error.containsInteriorNUL)
    }

    @Test("Error is Sendable")
    func errorIsSendable() async {
        let error = Path.Error.empty

        await Task {
            #expect(error == .empty)
        }.value
    }

    @Test("Error descriptions")
    func errorDescriptions() {
        #expect(Path.Error.empty.description.contains("empty"))
        #expect(Path.Error.containsControlCharacters.description.contains("control"))
        #expect(Path.Error.containsInteriorNUL.description.contains("NUL"))
    }
}

// MARK: - Path.Component Tests

@Suite("Path.Component Tests")
struct PathComponentTests {

    // MARK: - Initialization

    @Test("Valid component initialization")
    func validComponent() throws {
        let component = try Path.Component("file.txt")
        #expect(component.string == "file.txt")
    }

    @Test("Component with special characters")
    func componentWithSpecialCharacters() throws {
        let component = try Path.Component("file-name_v2.0.txt")
        #expect(component.string == "file-name_v2.0.txt")
    }

    @Test("Component with spaces")
    func componentWithSpaces() throws {
        let component = try Path.Component("my file.txt")
        #expect(component.string == "my file.txt")
    }

    // MARK: - Properties

    @Test("Extension of component")
    func extensionOfComponent() throws {
        let component = try Path.Component("readme.txt")
        #expect(component.extension == "txt")
    }

    @Test("Extension of dotfile (none)")
    func extensionOfDotfile() throws {
        let component = try Path.Component(".gitignore")
        #expect(component.extension == nil)
    }

    @Test("Extension with multiple dots")
    func extensionWithMultipleDots() throws {
        let component = try Path.Component("file.tar.gz")
        #expect(component.extension == "gz")
    }

    @Test("Extension when none")
    func extensionWhenNone() throws {
        let component = try Path.Component("Makefile")
        #expect(component.extension == nil)
    }

    @Test("Stem of component")
    func stemOfComponent() throws {
        let component = try Path.Component("readme.txt")
        #expect(component.stem == "readme")
    }

    @Test("Stem of dotfile")
    func stemOfDotfile() throws {
        let component = try Path.Component(".gitignore")
        #expect(component.stem == ".gitignore")
    }

    @Test("Stem with multiple dots")
    func stemWithMultipleDots() throws {
        let component = try Path.Component("archive.tar.gz")
        #expect(component.stem == "archive.tar")
    }

    @Test("Stem when no extension")
    func stemWhenNoExtension() throws {
        let component = try Path.Component("Makefile")
        #expect(component.stem == "Makefile")
    }

    // MARK: - Protocols

    @Test("ExpressibleByStringLiteral")
    func expressibleByStringLiteral() {
        let component: Path.Component = "file.txt"
        #expect(component.string == "file.txt")
    }

    @Test("Hashable conformance")
    func hashableConformance() throws {
        let comp1 = try Path.Component("file.txt")
        let comp2 = try Path.Component("file.txt")
        let comp3 = try Path.Component("other.txt")

        #expect(comp1.hashValue == comp2.hashValue)
        #expect(comp1.hashValue != comp3.hashValue)
    }

    @Test("Equatable conformance")
    func equatableConformance() throws {
        let comp1 = try Path.Component("file.txt")
        let comp2 = try Path.Component("file.txt")
        let comp3 = try Path.Component("other.txt")

        #expect(comp1 == comp2)
        #expect(comp1 != comp3)
    }

    @Test("String conversion")
    func stringConversion() throws {
        let component = try Path.Component("file.txt")
        #expect(String(component) == "file.txt")
    }

    // MARK: - Integration with Path

    @Test("Component can be appended to path")
    func componentAppendedToPath() throws {
        let path = try Path("/usr/local")
        let component = try Path.Component("bin")
        let newPath = path / component
        #expect(newPath.string == "/usr/local/bin")
    }
}

// MARK: - Path.Component.Error Tests

@Suite("Path.Component.Error Tests")
struct PathComponentErrorTests {

    @Test("Empty component throws empty error")
    func emptyComponentThrowsError() {
        #expect(throws: Path.Component.Error.empty) {
            try Path.Component.init("")
        }
    }

    @Test("Component with path separator throws error")
    func pathSeparatorThrowsError() {
        #expect(throws: Path.Component.Error.containsPathSeparator) {
            try Path.Component.init("foo/bar")
        }
    }

    @Test("Interior NUL byte throws containsInteriorNUL")
    func interiorNULThrowsError() {
        #expect(throws: Path.Component.Error.containsInteriorNUL) {
            try Path.Component.init("file\0.txt")
        }
    }

    @Test("Control character throws containsControlCharacters")
    func controlCharacterThrowsError() {
        #expect(throws: Path.Component.Error.containsControlCharacters) {
            try Path.Component.init("file\n.txt")
        }
    }

    @Test("Error cases are equatable")
    func errorEquatable() {
        #expect(Path.Component.Error.empty == Path.Component.Error.empty)
        #expect(Path.Component.Error.containsPathSeparator == Path.Component.Error.containsPathSeparator)
        #expect(Path.Component.Error.empty != Path.Component.Error.containsPathSeparator)
    }

    @Test("Error descriptions")
    func errorDescriptions() {
        #expect(Path.Component.Error.empty.description.contains("empty"))
        #expect(Path.Component.Error.containsPathSeparator.description.contains("separator"))
        #expect(Path.Component.Error.containsControlCharacters.description.contains("control"))
        #expect(Path.Component.Error.containsInteriorNUL.description.contains("NUL"))
    }
}
