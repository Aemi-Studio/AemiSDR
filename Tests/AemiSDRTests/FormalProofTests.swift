//
//  FormalProofTests.swift
//  AemiSDRTests
//
//  Machine-checked proofs of the mathematics the shaders and configuration rely on (ADR-0006). A proof is real only
//  if (1) the solver gives the answers it declares, (2) a false claim is refuted by the same harness, and (3) the
//  source function it models has not changed since it was proved.
//

#if os(macOS)
    import Foundation
    import Testing

    @Suite("Source functions are found and fingerprinted")
    struct SourceFunctionTests {
        private let metal = """
            inline float helper(float x) { return x * 2.0f; }
            // applyFalloff(t) is described here but this is a comment
            inline float applyFalloff(float t) {
                t = clamp(t, 0.0f, 1.0f);
                if (t > 0.5f) { return t * t; }
                return t;
            }
            inline float other() { return applyFalloff(0.5f); }
            """

        @Test func `a function is found by name and spans its nested braces`() throws {
            let body = try #require(SourceFunction.definition(named: "applyFalloff", in: metal))
            #expect(body.hasPrefix("inline float applyFalloff(float t) {"))
            #expect(body.hasSuffix("return t;\n}"))
            #expect(!body.contains("other"))
        }

        @Test func `a call to a function is not mistaken for its definition`() throws {
            let source =
                "inline float other() { return applyFalloff(0.5f); }\ninline float applyFalloff(float t) { return t; }\n"
            let body = try #require(SourceFunction.definition(named: "applyFalloff", in: source))
            #expect(body == "inline float applyFalloff(float t) { return t; }")
        }

        @Test func `a function that does not exist is nil`() {
            #expect(SourceFunction.definition(named: "nothing", in: metal) == nil)
        }

        @Test func `comments and spacing do not change a digest but an operator does`() {
            let a = "inline float f(float t) { return t * t; } // squared"
            let b = "inline   float f(float t)\n{\n    /* squared */ return t * t;\n}"
            let c = "inline float f(float t) { return t + t; }"
            #expect(SourceFunction.digest(of: a) == SourceFunction.digest(of: b))
            #expect(SourceFunction.digest(of: a) != SourceFunction.digest(of: c))
            #expect(SourceFunction.digest(of: a).count == 64)
        }
    }

    @Suite("A proof file declares what it proves")
    struct ProofSpecTests {
        @Test func `a header is read into its id, claim, sources and expected answers`() throws {
            let text = """
                ; id: falloff-curves
                ; claim: every curve maps [0,1] into [0,1]
                ; source: Sources/AemiSDR/Shaders/LiquidLens.metal#applyFalloff sha256:abc123
                ; source: Sources/AemiSDR/Shaders/AemiSDR.ci.metal#distance_to_alpha sha256:def456
                ; expect: unsat unsat sat
                (check-sat)
                """
            let spec = try #require(ProofSpec.parse(text))
            #expect(spec.id == "falloff-curves")
            #expect(spec.claim == "every curve maps [0,1] into [0,1]")
            #expect(
                spec.sources == [
                    .init(path: "Sources/AemiSDR/Shaders/LiquidLens.metal", function: "applyFalloff", sha256: "abc123"),
                    .init(
                        path: "Sources/AemiSDR/Shaders/AemiSDR.ci.metal", function: "distance_to_alpha",
                        sha256: "def456"),
                ])
            #expect(spec.expected == ["unsat", "unsat", "sat"])
        }

        @Test func `stale pins are rewritten to the current digest and nothing else changes`() {
            let text = """
                ; id: x
                ; source: a.metal#f sha256:old
                ; source: b.metal#gone sha256:keep
                ; expect: unsat
                (check-sat)
                """
            let repinned = ProofSpec.repinned(text) { path, function in
                path == "a.metal" && function == "f" ? "new" : nil
            }
            #expect(
                repinned == """
                    ; id: x
                    ; source: a.metal#f sha256:new
                    ; source: b.metal#gone sha256:keep
                    ; expect: unsat
                    (check-sat)
                    """)
        }

        @Test func `a file with no id or no expected answers is not a proof`() {
            #expect(ProofSpec.parse("; claim: x\n; expect: unsat\n") == nil)
            #expect(ProofSpec.parse("; id: x\n; claim: y\n") == nil)
        }
    }

    @Suite("The solver harness cannot pass a lie")
    struct SolverHarnessTests {
        private func write(_ smt: String) throws -> URL {
            let directory = try DocumentationLayout.fixtureDirectory().appending(path: "solver")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let url = directory.appending(path: "\(UUID().uuidString).smt2")
            try smt.write(to: url, atomically: true, encoding: .utf8)
            return url
        }

        @Test func `the solver is installed`() {
            #expect(Z3.executable() != nil, "Z3 is required to verify the proofs: brew install z3")
        }

        @Test func `answers come back in the order the checks were written`() throws {
            let url = try write(
                """
                (declare-const x Real)
                (push)(assert (and (> x 1.0) (< x 0.0)))(check-sat)(pop)
                (push)(assert (> x 1.0))(check-sat)(pop)
                """)
            defer { try? FileManager.default.removeItem(at: url) }
            #expect(try Z3.run(file: url).answers == ["unsat", "sat"])
        }

        @Test func `a false lemma is refuted rather than accepted`() throws {
            // Claim: x*x < x for every x in [0, 1]. False at x = 0 and x = 1, so its negation is satisfiable.
            let url = try write(
                """
                (declare-const x Real)
                (assert (and (<= 0.0 x) (<= x 1.0) (not (< (* x x) x))))
                (check-sat)
                """)
            defer { try? FileManager.default.removeItem(at: url) }
            #expect(try Z3.run(file: url).answers == ["sat"])
        }

        @Test func `a missing solver is an error and never an empty success`() throws {
            let url = try write("(check-sat)")
            defer { try? FileManager.default.removeItem(at: url) }
            #expect(throws: Z3.Failure.solverMissing) {
                try Z3.run(file: url, solver: nil)
            }
        }
    }

    @Suite("The repository's proofs hold and are current")
    struct RepositoryProofTests {
        private static let files: [URL] = (try? Proofs.files()) ?? []

        @Test func `there are proofs to check`() throws {
            #expect(!Self.files.isEmpty)
        }

        @Test(arguments: RepositoryProofTests.files)
        func `a proof gives exactly the answers it declares`(file: URL) throws {
            let text = try String(contentsOf: file, encoding: .utf8)
            let spec = try #require(ProofSpec.parse(text), "\(file.lastPathComponent) has no valid header")
            let outcome = try Z3.run(file: file)
            #expect(
                outcome.answers == spec.expected,
                "\(spec.id): expected \(spec.expected), solver said \(outcome.answers)\n\(outcome.raw)")
        }

        @Test func `the Sellmeier coefficients in the proof are the ones in the code`() throws {
            let root = DocumentationLayout.repositoryRoot
            let code = try String(
                contentsOf: root.appending(path: "Sources/AemiSDR/Effects/LiquidLens/LiquidLensConfiguration.swift"),
                encoding: .utf8)
            let function = try #require(SourceFunction.definition(named: "sellmeierCoefficients", in: code))
            let proof = try String(
                contentsOf: Proofs.directory.appending(path: "sellmeier-dispersion.smt2"), encoding: .utf8)
            let expression = try NSRegularExpression(pattern: #"\b[bc][1-4]:\s*([0-9]+\.[0-9]+)"#)
            let range = NSRange(function.startIndex..., in: function)
            let literals = expression.matches(in: function, range: range).compactMap { match -> String? in
                Range(match.range(at: 1), in: function).map { String(function[$0]) }
            }
            #expect(
                literals.count >= 28, "found only \(literals.count) coefficients; the extraction is not seeing the data"
            )
            for literal in literals where !proof.contains(literal) {
                Issue.record("the code uses \(literal) but sellmeier-dispersion.smt2 does not contain it")
            }
        }

        @Test(arguments: RepositoryProofTests.files)
        func `a proof models the source function as it is now`(file: URL) throws {
            var text = try String(contentsOf: file, encoding: .utf8)
            if ProcessInfo.processInfo.environment["AEMI_UPDATE_PINS"] == "1" {
                // Deliberate, visible re-pinning after the model has been re-checked against the changed source.
                let root = DocumentationLayout.repositoryRoot
                text = ProofSpec.repinned(text) { path, function in
                    guard let code = try? String(contentsOf: root.appending(path: path), encoding: .utf8),
                        let definition = SourceFunction.definition(named: function, in: code)
                    else { return nil }
                    return SourceFunction.digest(of: definition)
                }
                try text.write(to: file, atomically: true, encoding: .utf8)
            }
            let spec = try #require(ProofSpec.parse(text))
            for source in spec.sources {
                let url = DocumentationLayout.repositoryRoot.appending(path: source.path)
                let code = try String(contentsOf: url, encoding: .utf8)
                let definition = try #require(
                    SourceFunction.definition(named: source.function, in: code),
                    "\(source.function) no longer exists in \(source.path)")
                #expect(
                    SourceFunction.digest(of: definition) == source.sha256,
                    "\(spec.id) is STALE: \(source.function) changed. Re-check the model, then run: AEMI_UPDATE_PINS=1 swift test --filter 'a proof models the source function'"
                )
            }
        }
    }
#endif
