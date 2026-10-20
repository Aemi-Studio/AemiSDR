//
//  DisplayCornerRadiiLiveTests.swift
//  AemiSDRTests
//
//  Runs only where UIKit is, against whatever device the test runs on. Where the pure suite proves the choice among
//  sources, this proves the reading: that the real private API answers, through the real runtime, with values the
//  choice can use. On the iPhone Duo simulator it is also the only test that sees non-uniform corners.
//

#if os(iOS)
    import Abysm
    import UIKit
    import Testing

    @testable import AemiSDR

    @MainActor
    @Suite("Display corner radii on a live device")
    struct DisplayCornerRadiiLiveTests {
        @Test func `the screen's radii are valid and their largest equals the system's own scalar`() {
            let screen = UIScreen.main
            let radii = screen.displayCornerRadii
            #expect(radii.isValid)
            // The scalar is the largest corner on every display probed: 62 on the iPhone 18 Pro, 59 on the Duo.
            if let scalar = DisplayCornerSources.scalar(of: screen, getter: _InternedKeys.screenCornerRadiusKey) {
                #expect(radii.maximum == scalar)
            }
        }

        @Test func `the static scalar is the largest of the static corners`() {
            #expect(UIScreen.displayCornerRadius == UIScreen.displayCornerRadii.maximum)
        }

        @Test func `every private symbol the corner reading touches resolved, or is reported as the one that moved`() {
            PrivateAPI.resetResolutions()
            _ = UIScreen.main.displayCornerRadii
            // A canary in miniature: on a runtime where UIKit renamed one of these, this names it.
            let failed = PrivateAPI.failures.map(\.symbol)
            #expect(failed.filter { $0.contains("displayCornerRadius") }.isEmpty, "failed: \(failed)")
        }

        @Test func `a real corner configuration with the Duo's values reads back per corner, each in its own corner`()
            throws
        {
            // The test host has no window scene, so build the object the scene would hand us: the real
            // BSCornerRadiusConfiguration, through Abysm, with the Duo's values. Eight in both left corners, 59 in both
            // right ones, so a swapped getter (topRight read as bottomLeft) cannot hide behind symmetry: use four
            // distinct numbers.
            let configurationClass = try PrivateClass("BSCornerRadiusConfiguration", in: "BaseBoard")
            let allocate = try configurationClass.method("alloc", kind: .class, as: (() -> NSObject?).self)
            let initialise = try configurationClass.method(
                "initWithTopLeft:bottomLeft:bottomRight:topRight:",
                as: ((Double, Double, Double, Double) -> NSObject?).self)
            let raw = try #require(try allocate())
            let configuration = try #require(try initialise(on: raw, 1, 2, 3, 4))

            let radii = try #require(
                DisplayCornerSources.corners(
                    of: configuration,
                    names: (
                        _InternedKeys.cornerTopLeftKey, _InternedKeys.cornerTopRightKey,
                        _InternedKeys.cornerBottomLeftKey, _InternedKeys.cornerBottomRightKey
                    )))
            // Arguments were (topLeft: 1, bottomLeft: 2, bottomRight: 3, topRight: 4).
            #expect(radii == DisplayCornerRadii(topLeft: 1, topRight: 4, bottomLeft: 2, bottomRight: 3))
        }

        @Test func `the Duo's own values survive the same round trip`() throws {
            let configurationClass = try PrivateClass("BSCornerRadiusConfiguration", in: "BaseBoard")
            let allocate = try configurationClass.method("alloc", kind: .class, as: (() -> NSObject?).self)
            let initialise = try configurationClass.method(
                "initWithTopLeft:bottomLeft:bottomRight:topRight:",
                as: ((Double, Double, Double, Double) -> NSObject?).self)
            let raw = try #require(try allocate())
            let configuration = try #require(try initialise(on: raw, 8, 8, 59, 59))
            let radii = try #require(
                DisplayCornerSources.corners(
                    of: configuration,
                    names: (
                        _InternedKeys.cornerTopLeftKey, _InternedKeys.cornerTopRightKey,
                        _InternedKeys.cornerBottomLeftKey, _InternedKeys.cornerBottomRightKey
                    )))
            #expect(radii == DisplayCornerRadii(topLeft: 8, topRight: 59, bottomLeft: 8, bottomRight: 59))
            #expect(!radii.isUniform)
        }
    }
#endif
