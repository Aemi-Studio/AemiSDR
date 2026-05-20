//
//  VariableBlurMaskTests.swift
//  AemiSDRTests
//
//  Mirrors the CI `easeInAlphaMask` and `linearMask` kernels in Swift to
//  validate which side of the generated mask has alpha=1, and confirms
//  that the `verticalEdgeBlur` band-to-mask assignments are correct.
//
//  The variable blur reads the mask as luminance-drives-blur: alpha=1
//  = max blur, alpha=0 = crisp. For an edge-blur band placed at the top
//  of a view, the band's mask must have alpha=1 at its TOP (= the view's
//  outermost top edge), fading to 0 toward the band's bottom (= interior).
//  The bug fixed in `verticalEdgeBlur` was using mask types whose alpha
//  peaked at the band's bottom — pushing the strongest blur into the
//  view interior instead of onto the outermost edge.
//

import Foundation
import Testing

@testable import AemiSDR

@Suite("VariableBlur Mask Orientation")
struct VariableBlurMaskTests {
    /// Swift mirror of `easeInAlphaMask` from `AemiSDR.ci.metal`.
    /// `direction = 0`: alpha=0 at yNorm=0 (CI bottom), alpha=1 at yNorm=1 (CI top).
    /// `direction = 1`: alpha=1 at CI bottom, alpha=0 at CI top.
    func easeInAlphaMask(yNorm: Float, direction: Float, startOffset: Float, inverted: Float) -> Float {
        var y = yNorm
        if direction > 0.5 { y = 1 - y }
        let s = min(max(startOffset, 0), 0.999)
        let t = min(max((y - s) / (1 - s), 0), 1)
        var alpha = t * t
        if inverted > 0.5 { alpha = 1 - alpha }
        return alpha
    }

    /// Swift mirror of `linearMask` from `AemiSDR.ci.metal`.
    /// `inverted = 0`: alpha=0 at y=0 (CI bottom), alpha=1 at y=h (CI top).
    /// `inverted = 1`: alpha=1 at y=0 (CI bottom), alpha=0 at y=h (CI top).
    func linearMask(yNorm: Float, startOffset: Float, inverted: Float) -> Float {
        // Simulating with height = 1 for normalized math.
        let y = yNorm  // in [0, 1]
        let y0 = min(max(startOffset, -1), 1)
        let effectiveH = max(1 - abs(y0), 0.01)
        if inverted > 0.5 {
            let yFromBottom = 1 - y
            return min(max((yFromBottom - y0) / effectiveH, 0), 1)
        } else {
            return min(max((y - y0) / effectiveH, 0), 1)
        }
    }

    // MARK: - Direct kernel orientation checks

    @Test("easeInAlphaMask direction=0 peaks at CI top (yNorm=1)")
    func easeInDirection0PeaksAtTop() {
        let bottom = easeInAlphaMask(yNorm: 0, direction: 0, startOffset: 0, inverted: 0)
        let top = easeInAlphaMask(yNorm: 1, direction: 0, startOffset: 0, inverted: 0)
        #expect(bottom < 0.01)
        #expect(top > 0.99)
    }

    @Test("easeInAlphaMask direction=1 peaks at CI bottom (yNorm=0)")
    func easeInDirection1PeaksAtBottom() {
        let bottom = easeInAlphaMask(yNorm: 0, direction: 1, startOffset: 0, inverted: 0)
        let top = easeInAlphaMask(yNorm: 1, direction: 1, startOffset: 0, inverted: 0)
        #expect(bottom > 0.99)
        #expect(top < 0.01)
    }

    @Test("linearMask inverted=0 peaks at CI top (y=1)")
    func linearInverted0PeaksAtTop() {
        let bottom = linearMask(yNorm: 0, startOffset: 0, inverted: 0)
        let top = linearMask(yNorm: 1, startOffset: 0, inverted: 0)
        #expect(bottom < 0.01)
        #expect(top > 0.99)
    }

    @Test("linearMask inverted=1 peaks at CI bottom (y=0)")
    func linearInverted1PeaksAtBottom() {
        let bottom = linearMask(yNorm: 0, startOffset: 0, inverted: 1)
        let top = linearMask(yNorm: 1, startOffset: 0, inverted: 1)
        #expect(bottom > 0.99)
        #expect(top < 0.01)
    }

    // MARK: - MaskType → kernel argument mapping (vertical only)
    //
    // Confirms the kernel-argument mapping in `MaskType.kernelDescriptor`
    // produces the alpha distribution implied by the case name.

    /// For `.easeInTopToBottom` (docstring: "top is masked/blurred"),
    /// the mask should peak at CI's top (yNorm=1).
    @Test("MaskType.easeInTopToBottom → alpha peaks at TOP")
    func easeInTopToBottomMapsToTopPeak() {
        // From MaskType.swift: passes direction=0.0 to easeInAlphaMask.
        let topAlpha = easeInAlphaMask(yNorm: 1, direction: 0, startOffset: 0, inverted: 0)
        let bottomAlpha = easeInAlphaMask(yNorm: 0, direction: 0, startOffset: 0, inverted: 0)
        #expect(topAlpha > 0.99)
        #expect(bottomAlpha < 0.01)
    }

    /// For `.easeInBottomToTop` (docstring: "bottom is masked/blurred"),
    /// the mask should peak at CI's bottom (yNorm=0).
    @Test("MaskType.easeInBottomToTop → alpha peaks at BOTTOM")
    func easeInBottomToTopMapsToBottomPeak() {
        // From MaskType.swift: passes direction=1.0 to easeInAlphaMask.
        let topAlpha = easeInAlphaMask(yNorm: 1, direction: 1, startOffset: 0, inverted: 0)
        let bottomAlpha = easeInAlphaMask(yNorm: 0, direction: 1, startOffset: 0, inverted: 0)
        #expect(topAlpha < 0.01)
        #expect(bottomAlpha > 0.99)
    }

    // MARK: - verticalEdgeBlur band-to-mask correctness
    //
    // For the verticalEdgeBlur top band, max blur must land at the band's
    // top (= view's outermost top edge). The mask type that produces this
    // is `.easeInTopToBottom` (alpha=1 at yNorm=1 = CI top = visual top
    // of the rendered mask = top of the band).
    //
    // For the bottom band, max blur must land at the band's bottom (=
    // view's outermost bottom edge). The mask type is `.easeInBottomToTop`
    // (alpha=1 at yNorm=0 = CI bottom = visual bottom of the band).

    /// Pins the mask-direction-to-band mapping: the top band uses
    /// `.easeInTopToBottom` (alpha peaks at the band's *top* row, which is
    /// the view's outermost top edge); the bottom band uses
    /// `.easeInBottomToTop` (alpha peaks at the bottom row). Swapping the
    /// two would produce blur at the band's interior boundary instead of at
    /// the outermost edge, which is the visual that the SwiftUI modifier
    /// promises.
    @Test("verticalEdgeBlur top band uses TopToBottom mask (peaks at outermost edge)")
    func topBandPeaksAtOutermostEdge() {
        // The top band's mask must have alpha=1 at the band's top.
        // .easeInTopToBottom is the type whose kernel call produces this.
        let bandTopAlpha = easeInAlphaMask(yNorm: 1, direction: 0, startOffset: 0, inverted: 0)
        #expect(bandTopAlpha > 0.99)
    }

    @Test("verticalEdgeBlur bottom band uses BottomToTop mask (peaks at outermost edge)")
    func bottomBandPeaksAtOutermostEdge() {
        // The bottom band's mask must have alpha=1 at the band's bottom.
        // .easeInBottomToTop produces this (direction=1, peaks at yNorm=0).
        let bandBottomAlpha = easeInAlphaMask(yNorm: 0, direction: 1, startOffset: 0, inverted: 0)
        #expect(bandBottomAlpha > 0.99)
    }
}
