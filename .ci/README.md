# CI

`.github/workflows/ci.yml` calls the family's pinned swift-ci workflow, configured by `action.json`; run the same
checks locally with `.ci/swift-ci local`.

Each change runs quality (swift-format over the package layout and the analyzers) and the macOS debug tests on
Swift 6.4.1 and 6.3.3 (Xcode 26.6). Before the tests each leg downloads the Metal toolchain and installs Z3;
after them it builds the renderer for the iOS Simulator with the Xcode toolchain (swift.org toolchains carry no
Apple linker), as the previous workflow did. Release and sanitizer runs are nightly (when a commit landed) or
manual.

`baselines/` accepts the findings that predate the analyzers' adoption (deadwood 3, dolly 143); only a new one
fails. They are a recorded backlog, not a claim that the findings are wrong: shrink them by fixing the code.
