//
//  FormalProofSupport.swift
//  AemiSDRTests
//
//  Support for machine-checked proofs (docs/adr/0006). Lives in the test target so that no shipping binary links a
//  proof harness. macOS only: it runs the Z3 solver as a subprocess.
//

#if os(macOS)
    import CryptoKit
    import Foundation

    /// Finds a named function in source text and fingerprints it, so a proof is tied to the code it models.
    enum SourceFunction {
        /// The text of the definition of `name`: from the start of the line holding its signature to its matching `}`.
        /// A call is not a definition: only an occurrence whose parameter list is followed by `{` counts.
        static func definition(named name: String, in source: String) -> String? {
            let original = Array(source)
            let masked = maskComments(original)
            let target = Array(name)
            var index = 0
            while index + target.count < masked.count {
                defer { index += 1 }
                guard masked[index] == target[0], Array(masked[index..<(index + target.count)]) == target else {
                    continue
                }
                // A whole identifier, opened by a parenthesis.
                if index > 0, isIdentifier(masked[index - 1]) { continue }
                var cursor = index + target.count
                while cursor < masked.count, masked[cursor] == " " { cursor += 1 }
                guard cursor < masked.count, masked[cursor] == "(" else { continue }
                // Something that declares a function precedes it (a return type or `func`), not a call.
                var before = index - 1
                while before >= 0, masked[before] == " " { before -= 1 }
                guard before >= 0, isIdentifier(masked[before]) || masked[before] == ">" || masked[before] == "*" else {
                    continue
                }
                if previousWord(masked, endingAt: before) == "return" { continue }
                guard let close = matching(masked, open: cursor, "(", ")") else { continue }
                // Between the parameters and the body: attributes, `throws`, `-> Type`; never a statement end.
                var brace = close + 1
                while brace < masked.count, masked[brace] != "{" {
                    if ";(),=".contains(masked[brace]) { break }
                    brace += 1
                }
                guard brace < masked.count, masked[brace] == "{", let end = matching(masked, open: brace, "{", "}")
                else { continue }
                var start = index
                while start > 0, masked[start - 1] != "\n" { start -= 1 }
                return String(original[start...end])
            }
            return nil
        }

        private static func isIdentifier(_ character: Character) -> Bool {
            character.isLetter || character.isNumber || character == "_"
        }

        private static func previousWord(_ text: [Character], endingAt end: Int) -> String {
            var start = end
            while start > 0, isIdentifier(text[start - 1]) { start -= 1 }
            return String(text[start...end])
        }

        private static func matching(_ text: [Character], open: Int, _ opener: Character, _ closer: Character) -> Int? {
            var depth = 0
            for position in open..<text.count {
                if text[position] == opener { depth += 1 }
                if text[position] == closer {
                    depth -= 1
                    if depth == 0 { return position }
                }
            }
            return nil
        }

        /// The same characters with every comment replaced by spaces (newlines kept), so indices still line up.
        private static func maskComments(_ text: [Character]) -> [Character] {
            var result = text
            var index = 0
            while index < text.count {
                if text[index] == "/", index + 1 < text.count, text[index + 1] == "/" {
                    while index < text.count, text[index] != "\n" {
                        result[index] = " "
                        index += 1
                    }
                } else if text[index] == "/", index + 1 < text.count, text[index + 1] == "*" {
                    while index < text.count {
                        let isEnd = text[index] == "*" && index + 1 < text.count && text[index + 1] == "/"
                        if text[index] != "\n" { result[index] = " " }
                        if isEnd {
                            result[index + 1] = " "
                            index += 2
                            break
                        }
                        index += 1
                    }
                } else {
                    index += 1
                }
            }
            return result
        }

        /// The text with comments removed and every run of whitespace collapsed to one space, so editing a comment
        /// or reformatting does not invalidate a proof but changing an operator does.
        static func normalized(_ text: String) -> String {
            let uncommented = String(maskComments(Array(text)))
            return uncommented.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        }

        /// The lowercase hexadecimal SHA-256 of the normalized text.
        static func digest(of text: String) -> String {
            SHA256.hash(data: Data(normalized(text).utf8)).map { String(format: "%02x", $0) }.joined()
        }
    }

    /// The machine-readable header of a proof file (`; key: value` comment lines).
    struct ProofSpec: Equatable {
        struct Source: Equatable {
            var path: String
            var function: String
            var sha256: String
        }

        var id: String
        var claim: String
        var sources: [Source]
        /// The answer each `(check-sat)` must give, in order.
        var expected: [String]

        /// The proof text with each `; source:` line's digest replaced by the current one. A source that cannot be resolved
        /// is left exactly as it was, so a deleted function still fails the pin check instead of being papered over.
        static func repinned(_ text: String, digest: (_ path: String, _ function: String) -> String?) -> String {
            text.split(separator: "\n", omittingEmptySubsequences: false).map { line -> String in
                guard line.hasPrefix("; source:") else { return String(line) }
                let fields = line.dropFirst("; source:".count).split(separator: " ")
                guard fields.count == 2, fields[1].hasPrefix("sha256:"), let hash = fields[0].firstIndex(of: "#"),
                    let current = digest(
                        String(fields[0][..<hash]), String(fields[0][fields[0].index(after: hash)...]))
                else { return String(line) }
                return "; source: \(fields[0]) sha256:\(current)"
            }.joined(separator: "\n")
        }

        static func parse(_ text: String) -> ProofSpec? {
            var id = ""
            var claim = ""
            var sources: [Source] = []
            var expected: [String] = []
            for line in text.split(separator: "\n") {
                guard line.hasPrefix(";") else { continue }
                let field = line.dropFirst().drop { $0 == " " }
                func value(of key: String) -> String? {
                    field.hasPrefix(key + ":")
                        ? String(field.dropFirst(key.count + 1)).trimmingCharacters(in: .whitespaces) : nil
                }
                if let found = value(of: "id") { id = found }
                if let found = value(of: "claim") { claim = found }
                if let found = value(of: "expect") { expected = found.split(separator: " ").map(String.init) }
                if let found = value(of: "source") {
                    let parts = found.split(separator: " ")
                    guard parts.count == 2, parts[1].hasPrefix("sha256:"), let hash = parts[0].firstIndex(of: "#")
                    else {
                        continue
                    }
                    sources.append(
                        Source(
                            path: String(parts[0][..<hash]), function: String(parts[0][parts[0].index(after: hash)...]),
                            sha256: String(parts[1].dropFirst("sha256:".count))))
                }
            }
            guard !id.isEmpty, !expected.isEmpty else { return nil }
            return ProofSpec(id: id, claim: claim, sources: sources, expected: expected)
        }
    }

    /// Runs Z3 on a proof file.
    enum Z3 {
        struct Outcome: Equatable {
            var answers: [String]
            var raw: String
        }

        enum Failure: Error, Equatable {
            case solverMissing
        }

        /// The solver, or nil when it is not installed. A missing solver is a failure of the test run, never a pass.
        static func executable() -> URL? {
            var candidates = ["/opt/homebrew/bin/z3", "/usr/local/bin/z3", "/usr/bin/z3"]
            candidates += (ProcessInfo.processInfo.environment["PATH"] ?? "").split(separator: ":").map { "\($0)/z3" }
            return candidates.first { FileManager.default.isExecutableFile(atPath: $0) }.map {
                URL(fileURLWithPath: $0)
            }
        }

        static func run(file: URL, seconds: Int = 120, solver: URL? = executable()) throws -> Outcome {
            guard let solver else { throw Failure.solverMissing }
            let process = Process()
            process.executableURL = solver
            process.arguments = ["-smt2", "-T:\(seconds)", file.path]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = pipe
            try process.run()
            // Drain before waiting: a solver that writes a lot would otherwise block on a full pipe.
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            let raw = String(decoding: data, as: UTF8.self)
            let verdicts: Set<String> = ["sat", "unsat", "unknown", "timeout"]
            let answers = raw.split(separator: "\n").map { $0.trimmingCharacters(in: .whitespaces) }.filter {
                verdicts.contains($0)
            }
            return Outcome(answers: answers, raw: raw)
        }
    }

    /// The repository's proofs.
    enum Proofs {
        static var directory: URL { DocumentationLayout.repositoryRoot.appending(path: "Verification/Proofs") }

        static func files() throws -> [URL] {
            guard FileManager.default.fileExists(atPath: directory.path) else { return [] }
            return try FileManager.default.contentsOfDirectory(atPath: directory.path)
                .filter { $0.hasSuffix(".smt2") }.sorted().map { directory.appending(path: $0) }
        }
    }
#endif
