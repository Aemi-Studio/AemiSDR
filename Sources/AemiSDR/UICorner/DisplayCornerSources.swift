//
//  DisplayCornerSources.swift
//  AemiSDR
//

import Abysm
import CoreGraphics
import Foundation

/// What each system source reported for the display's corners, before choosing among them.
///
/// Kept apart from the reading so the choice is a pure function a test can drive with the iPhone Duo's values on any
/// machine, and the reading — the private API — is the only part that needs a device.
struct DisplayCornerSources: Equatable {
    /// `UIApplicationSceneSettings.cornerRadiusConfiguration`: four values, the only source that can say a display is
    /// not uniform.
    var perCorner: DisplayCornerRadii?
    /// `UITraitCollection.displayCornerRadius`: one value.
    var traitScalar: CGFloat?
    /// `UIScreen._displayCornerRadius`: one value.
    var screenScalar: CGFloat?

    init(perCorner: DisplayCornerRadii? = nil, traitScalar: CGFloat? = nil, screenScalar: CGFloat? = nil) {
        self.perCorner = perCorner
        self.traitScalar = traitScalar
        self.screenScalar = screenScalar
    }
}

extension DisplayCornerRadii {
    /// The best available radii: per-corner values, then the trait's scalar, then the screen's, then `estimate`.
    /// A value that is negative or not a number is not believed and the next source is tried.
    static func resolve(_ sources: DisplayCornerSources, estimate: CGFloat) -> DisplayCornerRadii {
        if let perCorner = sources.perCorner, perCorner.isValid { return perCorner }
        for scalar in [sources.traitScalar, sources.screenScalar] {
            if let scalar, scalar.isFinite, scalar >= 0 { return DisplayCornerRadii(uniform: scalar) }
        }
        return DisplayCornerRadii(uniform: estimate)
    }
}

extension DisplayCornerSources {
    /// A `Double` property read through its getter with the signature checked. An object that lacks the getter, or has
    /// one of another type, gives `nil` — where `value(forKey:)` raises `NSUnknownKeyException`, which no Swift code
    /// can catch and which the iOS 27.0 and 18.6 simulators were probed to throw (diary 2026-10-20-01).
    static func scalar(of object: AnyObject, getter: String) -> CGFloat? {
        (try? PrivateObject(object).read(getter, as: Double.self)).map { CGFloat($0) }
    }

    /// An object-valued property, `nil` when missing or nil.
    static func object(of object: AnyObject, getter: String) -> NSObject? {
        (try? PrivateObject(object).read(getter, as: NSObject?.self)) ?? nil
    }

    /// The four corners of a `BSCornerRadiusConfiguration`, or `nil` unless all four can be read.
    static func corners(of configuration: AnyObject, names: (String, String, String, String)) -> DisplayCornerRadii? {
        guard
            let topLeft = scalar(of: configuration, getter: names.0),
            let topRight = scalar(of: configuration, getter: names.1),
            let bottomLeft = scalar(of: configuration, getter: names.2),
            let bottomRight = scalar(of: configuration, getter: names.3)
        else { return nil }
        return DisplayCornerRadii(
            topLeft: topLeft, topRight: topRight, bottomLeft: bottomLeft, bottomRight: bottomRight)
    }
}
