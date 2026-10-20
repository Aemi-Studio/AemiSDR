//
//  DisplayCornerRadiiTests.swift
//  AemiSDRTests
//

import CoreGraphics
import Foundation
import Testing

@testable import AemiSDR

@Suite("Display corner radii")
struct DisplayCornerRadiiTests {
    /// What the iPhone Duo reports through `UIApplicationSceneSettings.cornerRadiusConfiguration` on the iOS 27.2
    /// simulator: the hinge-side corners are nearly square, the others round (diary 2026-10-20-02).
    private let duo = DisplayCornerRadii(topLeft: 8, topRight: 59, bottomLeft: 8, bottomRight: 59)

    @Test func `a uniform device has four equal corners and one maximum`() {
        let radii = DisplayCornerRadii(uniform: 62)
        #expect(radii.isUniform)
        #expect(radii.maximum == 62)
        #expect(radii == DisplayCornerRadii(topLeft: 62, topRight: 62, bottomLeft: 62, bottomRight: 62))
    }

    @Test func `a device with different corners is not uniform and its maximum is the largest`() {
        #expect(!duo.isUniform)
        #expect(duo.maximum == 59)
    }

    @Test func `per-corner values win over the scalar the system also reports, as on the Duo`() {
        // The Duo reports 59 as a scalar and 8/59/8/59 per corner. A scalar-only reading squares nothing: it rounds
        // the hinge-side corners that the hardware leaves nearly square.
        let sources = DisplayCornerSources(perCorner: duo, traitScalar: 59, screenScalar: 59)
        #expect(DisplayCornerRadii.resolve(sources, estimate: 42) == duo)
    }

    @Test func `the trait scalar is used when the scene reports no corners, then the screen's`() {
        #expect(
            DisplayCornerRadii.resolve(.init(traitScalar: 50, screenScalar: 40), estimate: 42) == .init(uniform: 50))
        #expect(DisplayCornerRadii.resolve(.init(screenScalar: 40), estimate: 42) == .init(uniform: 40))
    }

    @Test func `with nothing reported the estimate is used`() {
        #expect(DisplayCornerRadii.resolve(.init(), estimate: 42) == .init(uniform: 42))
    }

    @Test func `a corner that is negative or not a number is not believed`() {
        let bad = DisplayCornerRadii(topLeft: -1, topRight: 59, bottomLeft: .nan, bottomRight: 59)
        #expect(DisplayCornerRadii.resolve(.init(perCorner: bad, screenScalar: 30), estimate: 42) == .init(uniform: 30))
    }

    @Test func `a screenScalar of zero is a real value on a square-cornered display`() {
        #expect(DisplayCornerRadii.resolve(.init(screenScalar: 0), estimate: 42) == .init(uniform: 0))
    }

    @Test func `reading a getter an object lacks gives nil, where key-value coding would raise`() {
        // \`NSObject().value(forKey: "_displayCornerRadius")\` throws NSUnknownKeyException; the old reading did exactly that.
        #expect(DisplayCornerSources.scalar(of: NSObject(), getter: "_displayCornerRadius") == nil)
        #expect(DisplayCornerSources.object(of: NSObject(), getter: "_FBSScene") == nil)
    }

    @Test func `a getter of a different type than a scalar gives nil, not a reinterpreted number`() {
        // \`description\` returns an object; reading it as a Double must not reinterpret a pointer as a number.
        #expect(DisplayCornerSources.scalar(of: NSObject(), getter: "description") == nil)
    }
}
