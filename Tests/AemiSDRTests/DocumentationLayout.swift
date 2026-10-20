//
//  DocumentationLayout.swift
//  AemiSDRTests
//
//  Adapted from TerminalKit's `DocumentationLayout`. It lives in the test target so that no shipping
//  binary links a documentation checker (white paper, ADR-0001).
//

import Foundation

/// Reads the shape of the repository's own documentation.
///
/// The rules this type polices are rules about writing, not running: a diary nobody reads to the end, a
/// roadmap whose entries grew into essays, and a white paper that turned into a log all fail silently. A
/// silent failure is the one kind of documentation defect worth a test.
enum DocumentationLayout {
    /// The most lines a diary file may hold before it rolls over to a new file.
    static let maximumDiaryLines = 256

    /// The most lines the white paper may hold: it is principles, not a log.
    static let maximumWhitePaperLines = 200

    /// A Markdown file and its line count.
    struct MeasuredFile: Equatable {
        var url: URL
        var lines: Int
    }

    /// One record (roadmap entry or ADR), read from its own file.
    struct Record: Equatable {
        var url: URL
        var text: String

        /// Whether the front matter declares a `status:` field.
        var declaresStatus: Bool {
            lines.contains { $0.hasPrefix("status:") }
        }

        /// Whether the file claims more than one record: a second top-level title or a second `status:`.
        /// Section headings do not count; a record may have `## Probes` and `## What lands`.
        var holdsMultipleRecords: Bool {
            lines.count { $0.hasPrefix("# ") } > 1 || lines.count { $0.hasPrefix("status:") } > 1
        }

        /// Whether the front matter declares `status: done`.
        var isDone: Bool { lines.contains { $0.trimmingCharacters(in: .whitespaces) == "status: done" } }

        /// The test names cited on a `Regression:` line, each in backticks: the tests that fail without the fix.
        var regressionTests: [String] {
            lines.filter { $0.hasPrefix("Regression:") }.flatMap { line in
                line.split(separator: "`", omittingEmptySubsequences: false).enumerated()
                    .filter { $0.offset % 2 == 1 }.map { String($0.element) }
            }
        }

        private var lines: [Substring] {
            text.split(separator: "\n", omittingEmptySubsequences: false)
        }
    }

    // MARK: - Regression evidence

    /// The names of the Swift Testing tests under `Tests/`, excluding this documentation checker itself.
    ///
    /// A name counts only when `@Test` is on the same line or the line before its `func`, so a helper function cannot stand in for a
    /// test. Both spellings are read: a sentence in backticks, or a plain identifier.
    static func testNames() throws -> Set<String> {
        let testsDirectory = repositoryRoot.appending(path: "Tests")
        guard
            let enumerator = FileManager.default.enumerator(
                at: testsDirectory, includingPropertiesForKeys: nil, options: [.skipsHiddenFiles])
        else { return [] }
        var names: Set<String> = []
        while let url = enumerator.nextObject() as? URL {
            guard url.pathExtension == "swift", url.lastPathComponent != "DocumentationLayout.swift" else { continue }
            names.formUnion(testNames(in: try String(contentsOf: url, encoding: .utf8)))
        }
        return names
    }

    /// The names of the `@Test` functions declared in one Swift source text.
    static func testNames(in source: String) -> Set<String> {
        var names: Set<String> = []
        var awaitingFunction = false
        for line in source.split(separator: "\n", omittingEmptySubsequences: false) {
            if line.contains("@Test") { awaitingFunction = true }
            guard awaitingFunction, let range = line.range(of: "func ") else { continue }
            awaitingFunction = false
            let rest = line[range.upperBound...]
            if rest.hasPrefix("`") {
                let body = rest.dropFirst()
                if let end = body.firstIndex(of: "`") { names.insert(String(body[..<end])) }
            } else {
                let identifier = rest.prefix { $0.isLetter || $0.isNumber || $0 == "_" }
                if !identifier.isEmpty { names.insert(String(identifier)) }
            }
        }
        return names
    }

    /// The done records that do not name at least one regression test that exists, each with what is wrong.
    static func unprovenDoneRecords(_ records: [Record], knownTests: Set<String>) -> [(record: Record, problem: String)]
    {
        records.filter(\.isDone).compactMap { record in
            let cited = record.regressionTests
            guard !cited.isEmpty else { return (record, "marked done with no regression tests cited") }
            let missing = cited.filter { !knownTests.contains($0) }
            guard missing.isEmpty else {
                return (record, "cites tests that do not exist: \(missing.map { "`\($0)`" }.joined(separator: ", "))")
            }
            return nil
        }
    }

    // MARK: - Roots

    /// The repository root: three levels above this file (`Tests/AemiSDRTests/…`), checked by the
    /// presence of `Package.swift`.
    static let repositoryRoot: URL = {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()  // AemiSDRTests
            .deletingLastPathComponent()  // Tests
            .deletingLastPathComponent()  // repository root
        precondition(
            FileManager.default.fileExists(atPath: directory.appending(path: "Package.swift").path),
            "could not locate the repository root above \(#filePath)"
        )
        return directory
    }()

    static func whitePaperURL() -> URL { repositoryRoot.appending(path: "docs/WHITE-PAPER.md") }
    static func diaryDirectory() -> URL { repositoryRoot.appending(path: "docs/diary") }
    static func roadmapDirectory() -> URL { repositoryRoot.appending(path: "docs/roadmap") }
    static func adrDirectory() -> URL { repositoryRoot.appending(path: "docs/adr") }

    /// A scratch directory for fixtures the tests write and remove.
    static func fixtureDirectory() throws -> URL {
        let directory = repositoryRoot.appending(path: ".build/documentation-fixtures")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    // MARK: - Reading

    static func whitePaperLineCount() throws -> Int { try lineCount(of: whitePaperURL()) }

    /// The Markdown files in `directory` past `limit` lines, longest first.
    static func filesExceedingLines(in directory: URL, limit: Int) throws -> [MeasuredFile] {
        try markdownFiles(in: directory)
            .map { MeasuredFile(url: $0, lines: try lineCount(of: $0)) }
            .filter { $0.lines > limit }
            .sorted { $0.lines > $1.lines }
    }

    static func roadmapEntries() throws -> [Record] { try records(in: roadmapDirectory()) }
    static func decisionRecords() throws -> [Record] { try records(in: adrDirectory()) }
    static func diaryFiles() throws -> [URL] { try markdownFiles(in: diaryDirectory()) }

    /// The record numbers more than one filename uses, each with those filenames. A record is cited by
    /// its number alone ("ADR-0002"), so two files sharing one make every citation ambiguous.
    static func repeatedNumbers(in filenames: [String]) -> [String: [String]] {
        Dictionary(grouping: filenames) { String($0.prefix { $0 != "-" }) }
            .filter { $0.value.count > 1 }
            .mapValues { $0.sorted() }
    }

    /// The number of lines in a text file, counted the way a reader would: an empty file has none, and a
    /// trailing newline does not add an empty last line.
    static func lineCount(of url: URL) throws -> Int {
        let contents = try String(contentsOf: url, encoding: .utf8)
        guard !contents.isEmpty else { return 0 }
        return contents.split(separator: "\n", omittingEmptySubsequences: false).count
            - (contents.hasSuffix("\n") ? 1 : 0)
    }

    // MARK: - Files

    private static func records(in directory: URL) throws -> [Record] {
        try markdownFiles(in: directory).map { Record(url: $0, text: try String(contentsOf: $0, encoding: .utf8)) }
    }

    /// The `.md` files directly inside `directory`, sorted by name. A missing directory yields none.
    private static func markdownFiles(in directory: URL) throws -> [URL] {
        guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
        return try FileManager.default.contentsOfDirectory(atPath: directory.path)
            .filter { $0.hasSuffix(".md") }
            .sorted()
            .map { directory.appending(path: $0) }
    }
}
