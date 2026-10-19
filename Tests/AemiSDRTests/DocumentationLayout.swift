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

        private var lines: [Substring] {
            text.split(separator: "\n", omittingEmptySubsequences: false)
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
