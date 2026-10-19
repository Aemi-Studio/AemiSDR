//
//  DocumentationLayoutTests.swift
//  AemiSDRTests
//
//  The documentation law of docs/WHITE-PAPER.md §7, enforced rather than requested (ADR-0001).
//

import Foundation
import Testing

@Suite("The diary stays within its line budget")
struct DiaryLineBudgetTests {
    @Test func `there is a diary to police`() throws {
        #expect(try !DocumentationLayout.diaryFiles().isEmpty)
    }

    @Test func `every diary file is within the line budget`() throws {
        let over = try DocumentationLayout.filesExceedingLines(
            in: DocumentationLayout.diaryDirectory(), limit: DocumentationLayout.maximumDiaryLines)
        #expect(
            over.isEmpty,
            """
            These diary files exceed \(DocumentationLayout.maximumDiaryLines) lines and must roll over:
            \(over.map { "  - \($0.url.lastPathComponent): \($0.lines) lines" }.joined(separator: "\n"))
            """
        )
    }

    @Test func `a file exactly at the budget is allowed and one line more is not`() throws {
        // The ceiling is inclusive. An off-by-one here means a file can never reach its own limit.
        let limit = DocumentationLayout.maximumDiaryLines
        let directory = try DocumentationLayout.fixtureDirectory().appending(path: "diary-budget")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let atBudget = directory.appending(path: "at-budget.md")
        try "#\n".appending(String(repeating: "x\n", count: limit - 1)).write(
            to: atBudget, atomically: true, encoding: .utf8)
        #expect(try DocumentationLayout.lineCount(of: atBudget) == limit)
        #expect(try DocumentationLayout.filesExceedingLines(in: directory, limit: limit).isEmpty)

        try "x\n".appending(String(repeating: "x\n", count: limit)).write(
            to: directory.appending(path: "over-budget.md"), atomically: true, encoding: .utf8)
        #expect(try DocumentationLayout.filesExceedingLines(in: directory, limit: limit).count == 1)
    }
}

@Suite("The white paper stays a core document")
struct WhitePaperTests {
    @Test func `the white paper stays within its budget`() throws {
        let lines = try DocumentationLayout.whitePaperLineCount()
        #expect(
            lines <= DocumentationLayout.maximumWhitePaperLines,
            "docs/WHITE-PAPER.md is \(lines) lines; probe history belongs in the diary, not here."
        )
    }

    @Test func `the white paper does not carry a probe ledger`() throws {
        let text = try String(contentsOf: DocumentationLayout.whitePaperURL(), encoding: .utf8)
        #expect(!text.contains("## Probe ledger"), "the probe history belongs in the diary")
    }
}

@Suite("A record is one file with a status")
struct RecordGranularityTests {
    @Test func `the roadmap and the decision records are not empty`() throws {
        #expect(try !DocumentationLayout.roadmapEntries().isEmpty)
        #expect(try !DocumentationLayout.decisionRecords().isEmpty)
    }

    @Test func `every roadmap entry and decision record declares its status`() throws {
        let records = try DocumentationLayout.roadmapEntries() + DocumentationLayout.decisionRecords()
        for record in records where !record.declaresStatus {
            Issue.record("\(record.url.lastPathComponent) does not declare a `status:` field")
        }
    }

    @Test func `no file holds more than one record`() throws {
        let records = try DocumentationLayout.roadmapEntries() + DocumentationLayout.decisionRecords()
        for record in records where record.holdsMultipleRecords {
            Issue.record("\(record.url.lastPathComponent) holds more than one record")
        }
    }

    @Test func `two titles in one file are reported as two records`() {
        let record = DocumentationLayout.Record(
            url: URL(fileURLWithPath: "/0001-a.md"),
            text: "---\nstatus: pending\n---\n\n# 0001 — A\n\n## Probes\n\n# 0002 — B\n"
        )
        #expect(record.declaresStatus)
        #expect(record.holdsMultipleRecords)
    }
}

@Suite("A record number names one record")
struct RecordNumberingTests {
    @Test func `a number two records share is reported with both names`() {
        let names = ["0001-a.md", "0002-b.md", "0002-c.md"]
        #expect(DocumentationLayout.repeatedNumbers(in: names) == ["0002": ["0002-b.md", "0002-c.md"]])
    }

    @Test func `no two decision records share a number`() throws {
        let names = try DocumentationLayout.decisionRecords().map(\.url.lastPathComponent)
        #expect(DocumentationLayout.repeatedNumbers(in: names).isEmpty, "repeated ADR numbers")
    }

    @Test func `no two roadmap entries share a number`() throws {
        let names = try DocumentationLayout.roadmapEntries().map(\.url.lastPathComponent)
        #expect(DocumentationLayout.repeatedNumbers(in: names).isEmpty, "repeated roadmap numbers")
    }
}
