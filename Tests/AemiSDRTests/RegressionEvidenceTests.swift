//
//  RegressionEvidenceTests.swift
//  AemiSDRTests
//
//  A fix that cannot name the test that fails without it is a claim, not a fix. The roadmap records this rule
//  (docs/WHITE-PAPER.md): a record may be marked done only when it cites regression tests that exist.
//

import Foundation
import Testing

@Suite("A fix names the test that guards it")
struct RegressionEvidenceTests {
    private func record(_ text: String) -> DocumentationLayout.Record {
        DocumentationLayout.Record(url: URL(fileURLWithPath: "/0099-x.md"), text: text)
    }

    @Test func `the tests cited on a regression line are read in order`() {
        let record = record(
            "---\nstatus: done\n---\n\n# 0099 — X\n\nRegression: `first test`, `second test`\n")
        #expect(record.isDone)
        #expect(record.regressionTests == ["first test", "second test"])
    }

    @Test func `a record that is not done is not asked for evidence`() {
        let pending = record("---\nstatus: pending\n---\n\n# 0099 — X\n")
        #expect(!pending.isDone)
        #expect(DocumentationLayout.unprovenDoneRecords([pending], knownTests: []).isEmpty)
    }

    @Test func `a done record with no regression line is reported`() {
        let unproven = record("---\nstatus: done\n---\n\n# 0099 — X\n")
        let problems = DocumentationLayout.unprovenDoneRecords([unproven], knownTests: ["anything"])
        #expect(problems.count == 1)
        #expect(problems.first?.problem.contains("no regression") == true)
    }

    @Test func `a done record citing a test that does not exist is reported with its name`() {
        let invented = record("---\nstatus: done\n---\n\n# 0099 — X\n\nRegression: `a test nobody wrote`\n")
        let problems = DocumentationLayout.unprovenDoneRecords([invented], knownTests: ["a real test"])
        #expect(problems.count == 1)
        #expect(problems.first?.problem.contains("a test nobody wrote") == true)
    }

    @Test func `a done record citing an existing test is accepted`() {
        let proven = record("---\nstatus: done\n---\n\n# 0099 — X\n\nRegression: `a real test`\n")
        #expect(DocumentationLayout.unprovenDoneRecords([proven], knownTests: ["a real test"]).isEmpty)
    }

    @Test func `test discovery finds tests written as sentences in backticks`() throws {
        let names = try DocumentationLayout.testNames()
        #expect(names.contains("the white paper stays within its budget"))
        #expect(names.contains("a number two records share is reported with both names"))
    }

    @Test func `every done record in the repository names regression tests that exist`() throws {
        let records = try DocumentationLayout.roadmapEntries() + DocumentationLayout.decisionRecords()
        let problems = DocumentationLayout.unprovenDoneRecords(records, knownTests: try DocumentationLayout.testNames())
        #expect(
            problems.isEmpty,
            "\(problems.map { "  - \($0.record.url.lastPathComponent): \($0.problem)" }.joined(separator: "\n"))")
    }
}
