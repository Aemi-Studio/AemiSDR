//
//  MetalCompilerCoreTests.swift
//  MetalCompilerCoreTests
//
//  Regression tests for the shader build tool: a long compiler error cascade must not deadlock the build, shaders
//  compile for the package's real deployment floor, and outputs stay inside the work directory.
//

#if os(macOS)
    import Foundation
    import Testing

    @testable import MetalCompilerCore

    /// Runs `body` on its own thread and gives up after `seconds`, so a deadlock fails the test instead of hanging the run.
    private func finishes<T: Sendable>(within seconds: Double, _ body: @escaping @Sendable () throws -> T) -> T? {
        let box = ResultBox<T>()
        let done = DispatchSemaphore(value: 0)
        Thread.detachNewThread {
            box.value = try? body()
            done.signal()
        }
        guard done.wait(timeout: .now() + seconds) == .success else { return nil }
        return box.value
    }

    private final class ResultBox<T: Sendable>: @unchecked Sendable {
        // Written once by the worker before it signals, read once by the test after the signal.
        var value: T?
    }

    @Suite("The shader tool does not hang on long compiler output")
    struct ProcessRunnerTests {
        private func run(printing bytes: Int) -> (output: String, exitCode: Int32)? {
            finishes(within: 20) {
                try ProcessRunner.execute(
                    "/bin/sh", arguments: ["-c", "head -c \(bytes) /dev/zero | tr '\\0' x"], environment: [:])
            }
        }

        @Test(arguments: [65_536, 65_537, 200_000, 1_000_000])
        func `output at and beyond the 64 KiB pipe buffer is drained, never deadlocked`(bytes: Int) throws {
            let result = try #require(run(printing: bytes), "execute did not return: deadlocked on a full pipe")
            #expect(result.output.count == bytes)
            #expect(result.exitCode == 0)
        }

        @Test func `a failing command reports its exit status and what it printed`() throws {
            let result = try #require(
                finishes(within: 20) {
                    try ProcessRunner.execute(
                        "/bin/sh", arguments: ["-c", "echo oops; exit 3"], environment: [:])
                })
            #expect(result.exitCode == 3)
            #expect(result.output.contains("oops"))
        }
    }

    @Suite("An invalid DEVELOPER_DIR is dropped and a valid one is kept")
    struct DeveloperEnvironmentTests {
        @Test func `a toolchain path that xcrun would reject is removed`() {
            let environment = ["DEVELOPER_DIR": "/Library/Developer/Toolchains/swift-6.4.xctoolchain", "HOME": "/h"]
            let cleaned = DeveloperEnvironment.sanitized(environment) { _ in false }
            #expect(cleaned["DEVELOPER_DIR"] == nil)
            #expect(cleaned["HOME"] == "/h")
        }

        @Test(arguments: ["/usr/bin/xcrun", "/Contents/Developer/usr/bin/xcrun"])
        func `a developer directory of either valid shape is kept`(suffix: String) {
            let environment = ["DEVELOPER_DIR": "/Applications/Xcode.app"]
            let cleaned = DeveloperEnvironment.sanitized(environment) { $0 == "/Applications/Xcode.app" + suffix }
            #expect(cleaned["DEVELOPER_DIR"] == "/Applications/Xcode.app")
        }

        @Test func `an environment without the variable is unchanged`() {
            let environment = ["PATH": "/usr/bin"]
            #expect(DeveloperEnvironment.sanitized(environment) { _ in false } == environment)
        }
    }

    @Suite("Outputs stay inside the allowed root")
    struct OutputRootTests {
        @Test func `a path inside the root, and the root itself, are permitted`() {
            #expect(OutputRoot.permits("/tmp/work/a.metallib", within: "/tmp/work"))
            #expect(OutputRoot.permits("/tmp/work", within: "/tmp/work"))
        }

        @Test func `a sibling that merely shares the root's prefix is refused`() {
            #expect(!OutputRoot.permits("/tmp/work-evil/a.metallib", within: "/tmp/work"))
        }

        @Test func `parent traversal out of the root is refused`() {
            #expect(!OutputRoot.permits("/tmp/work/../elsewhere/a.metallib", within: "/tmp/work"))
        }

        @Test func `the two spellings of one location are the same location`() {
            #expect(OutputRoot.permits("/private/tmp/work/a.metallib", within: "/tmp/work"))
            #expect(OutputRoot.permits("/tmp/work/a.metallib", within: "/private/tmp/work"))
        }
    }

    @Suite("Arguments are read, defaulted and confined")
    struct InvocationTests {
        private let required = [
            "tool", "--input", "/s/Shader.metal", "--ios-output", "/w/a.iOS.metallib", "--macos-output",
            "/w/a.macOS.metallib",
        ]

        @Test func `a missing required argument is named`() {
            #expect(throws: CompilerError.self) { try Invocation.parse(["tool", "--input", "/s/x.metal"]) }
        }

        @Test func `the optional simulator output is read when given`() throws {
            let parsed = try Invocation.parse(required + ["--ios-simulator-output", "/w/a.sim.metallib"])
            #expect(parsed.iosSimulatorOutput == "/w/a.sim.metallib")
        }

        @Test func `an output outside the allowed root is rejected`() {
            do {
                _ = try Invocation.parse(required + ["--allowed-root", "/elsewhere"])
                Issue.record("an output outside the root was accepted")
            } catch let CompilerError.outputOutsideAllowedRoot(path, root) {
                #expect(path.hasPrefix("/w/"))
                #expect(root == "/elsewhere")
            } catch {
                Issue.record("wrong error, a misuse of another case: \(error)")
            }
            #expect((try? Invocation.parse(required + ["--allowed-root", "/w"])) != nil)
        }

        @Test func `a file name ending in dot ci dot metal is a Core Image kernel`() {
            #expect(Invocation.resolveMode(inputPath: "/s/AemiSDR.ci.metal", explicit: nil) == .ci)
            #expect(Invocation.resolveMode(inputPath: "/s/LiquidLens.metal", explicit: nil) == .standard)
        }

        @Test func `an explicit recognised mode wins and an unknown one falls back to the file name`() {
            #expect(Invocation.resolveMode(inputPath: "/s/AemiSDR.ci.metal", explicit: "standard") == .standard)
            #expect(Invocation.resolveMode(inputPath: "/s/AemiSDR.ci.metal", explicit: "bogus") == .ci)
        }
    }

    @Suite("Shaders compile for the package's real deployment floor")
    struct DeploymentFloorTests {
        private static let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()

        private func floors() throws -> (ios: String, macos: String) {
            let manifest = try String(contentsOf: Self.root.appending(path: "Package.swift"), encoding: .utf8)
            func major(_ platform: String) throws -> String {
                let expression = try NSRegularExpression(pattern: "\\.\(platform)\\(\\.v(\\d+)\\)")
                let match = try #require(
                    expression.firstMatch(in: manifest, range: NSRange(manifest.startIndex..., in: manifest)))
                return String(manifest[try #require(Range(match.range(at: 1), in: manifest))]) + ".0"
            }
            return (try major("iOS"), try major("macOS"))
        }

        @Test func `the tool's default floor is the floor declared in Package dot swift`() throws {
            let declared = try floors()
            #expect(DeploymentFloor.ios == declared.ios)
            #expect(DeploymentFloor.macos == declared.macos)
        }

        @Test func `with no version arguments a run compiles for that floor`() throws {
            let parsed = try Invocation.parse([
                "tool", "--input", "/s/x.metal", "--ios-output", "/w/a", "--macos-output", "/w/b",
            ])
            #expect(parsed.iosMinVersion == DeploymentFloor.ios)
            #expect(parsed.macosMinVersion == DeploymentFloor.macos)
        }

        @Test func `the build plugin does not override the tested floor`() throws {
            let plugin = try String(
                contentsOf: Self.root.appending(path: "Plugins/MetalShaderBuildPlugin/plugin.swift"), encoding: .utf8)
            #expect(
                !plugin.contains("--ios-min-version"),
                "the plugin passes its own iOS version; the tool's default is the tested one")
            #expect(
                !plugin.contains("--macos-min-version"),
                "the plugin passes its own macOS version; the tool's default is the tested one")
        }
    }

    @Suite("The compiler is given the deployment target for each destination")
    struct CompilerArgumentsTests {
        private func config(sdk: String, flag: String, version: String, mode: CompilationMode = .standard)
            -> PlatformConfig
        {
            PlatformConfig(
                name: sdk, sdk: sdk, minVersionFlag: flag, minVersion: version, outputPath: "/w/out.metallib",
                mode: mode)
        }

        @Test func `a device build passes the iOS floor to the compiler`() {
            let arguments = MetalCompilerMain.metalArguments(
                config(sdk: "iphoneos", flag: "-mios-version-min=", version: DeploymentFloor.ios),
                inputPath: "/s/x.metal", airPath: "/w/out.air")
            #expect(arguments.contains("-mios-version-min=\(DeploymentFloor.ios)"))
            #expect(arguments.starts(with: ["--sdk", "iphoneos", "metal", "-c"]))
        }

        @Test func `a simulator build passes the simulator form of the flag`() {
            let arguments = MetalCompilerMain.metalArguments(
                config(sdk: "iphonesimulator", flag: "-mios-simulator-version-min=", version: "18.0"),
                inputPath: "/s/x.metal", airPath: "/w/out.air")
            #expect(arguments.contains("-mios-simulator-version-min=18.0"))
        }

        @Test func `a Core Image kernel adds the kernel flag and a standard shader does not`() {
            let ci = MetalCompilerMain.metalArguments(
                config(sdk: "macosx", flag: "-mmacos-version-min=", version: "15.0", mode: .ci),
                inputPath: "/s/x.ci.metal", airPath: "/w/out.air")
            let standard = MetalCompilerMain.metalArguments(
                config(sdk: "macosx", flag: "-mmacos-version-min=", version: "15.0"),
                inputPath: "/s/x.metal", airPath: "/w/out.air")
            #expect(ci.contains("-fcikernel"))
            #expect(!standard.contains("-fcikernel"))
        }

        @Test func `the input and the intermediate output are the last arguments`() {
            let arguments = MetalCompilerMain.metalArguments(
                config(sdk: "macosx", flag: "-mmacos-version-min=", version: "15.0"),
                inputPath: "/s/x.metal", airPath: "/w/out.air")
            #expect(arguments.suffix(3) == ["/s/x.metal", "-o", "/w/out.air"])
        }
    }
#endif
