//
//  ShaderTestPreview.swift
//  AemiSDR
//
//  Comprehensive visual test suite for Metal shader kernels.
//  This preview provides visual verification of all mask types and their parameters.
//

import SwiftUI

#if os(iOS)

// MARK: - Individual Mask Test Views

/// Visual test view for a single mask configuration
@available(iOS 15.0, *)
private struct MaskTestView: View {
    let title: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)

            Rectangle()
                .fill(color)
                .frame(width: 100, height: 100)
        }
    }
}

// MARK: - Rounded Rect vs Superellipse Comparison

@available(iOS 15.0, *)
private struct CornerComparisonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Corner Style Comparison")
                .font(.headline)

            HStack(spacing: 16) {
                // Circular corners (roundedRect)
                VStack(spacing: 4) {
                    Text("Circular")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Color.blue
                        .frame(width: 100, height: 100)
                        .roundedRectMask(.circular, cornerRadius: 24, fadeWidth: 8)
                }

                // Continuous corners (superellipse)
                VStack(spacing: 4) {
                    Text("Continuous")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Color.blue
                        .frame(width: 100, height: 100)
                        .roundedRectMask(.continuous, cornerRadius: 24, fadeWidth: 8)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Fade Width Comparison

@available(iOS 15.0, *)
private struct FadeWidthComparisonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Fade Width Comparison")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach([0, 4, 8, 16, 32], id: \.self) { fadeWidth in
                    VStack(spacing: 4) {
                        Text("\(fadeWidth)px")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Color.green
                            .frame(width: 60, height: 60)
                            .roundedRectMask(cornerRadius: 16, fadeWidth: CGFloat(fadeWidth))
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Corner Radius Comparison

@available(iOS 15.0, *)
private struct CornerRadiusComparisonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Corner Radius Comparison")
                .font(.headline)

            HStack(spacing: 12) {
                ForEach([0, 8, 16, 24, 40], id: \.self) { radius in
                    VStack(spacing: 4) {
                        Text("\(radius)px")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        Color.orange
                            .frame(width: 60, height: 60)
                            .roundedRectMask(cornerRadius: CGFloat(radius), fadeWidth: 8)
                    }
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Transition Algorithm Comparison

@available(iOS 15.0, *)
private struct TransitionComparisonView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Easing Comparison (Hermite vs Quadratic)")
                .font(.headline)

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("Linear")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Color.purple
                        .frame(width: 80, height: 80)
                        .roundedRectMask(cornerRadius: 20, fadeWidth: 16, transition: .linear)
                }

                VStack(spacing: 4) {
                    Text("Eased (Hermite)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Color.purple
                        .frame(width: 80, height: 80)
                        .roundedRectMask(cornerRadius: 20, fadeWidth: 16, transition: .eased)
                }
            }

            Text("Note: Hermite has smooth start/end, Quadratic has visible 'crease' at edge")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Vertical Edge Mask Test

@available(iOS 15.0, *)
private struct VerticalEdgeMaskTestView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Vertical Edge Masks")
                .font(.headline)

            HStack(spacing: 16) {
                VStack(spacing: 4) {
                    Text("Top Only")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Color.red
                        .frame(width: 60, height: 100)
                        .verticalEdgeMask(height: 40, edges: .top)
                }

                VStack(spacing: 4) {
                    Text("Bottom Only")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Color.red
                        .frame(width: 60, height: 100)
                        .verticalEdgeMask(height: 40, edges: .bottom)
                }

                VStack(spacing: 4) {
                    Text("Both Edges")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Color.red
                        .frame(width: 60, height: 100)
                        .verticalEdgeMask(height: 40, edges: .all)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Inversion Test

@available(iOS 15.0, *)
private struct InversionTestView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Mask Inversion (Normal vs Inverted)")
                .font(.headline)

            HStack(spacing: 24) {
                VStack(spacing: 4) {
                    Text("Normal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Color.cyan
                        .frame(width: 80, height: 80)
                        .roundedRectMask(cornerRadius: 20, fadeWidth: 16, inverted: false)
                }

                VStack(spacing: 4) {
                    Text("Inverted")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Color.cyan
                        .frame(width: 80, height: 80)
                        .roundedRectMask(cornerRadius: 20, fadeWidth: 16, inverted: true)
                }
            }

            Text("Normal: Inside transparent. Inverted: Outside transparent (cut-out)")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Combined Effects Test

@available(iOS 15.0, *)
private struct CombinedEffectsTestView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Combined Effects (Blur + Mask)")
                .font(.headline)

            Image(systemName: "photo.artframe")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 200, height: 150)
                .background(
                    LinearGradient(
                        colors: [.blue, .purple, .pink],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: 20))
                .roundedRectMask(cornerRadius: 20, fadeWidth: 16)
                .verticalEdgeMask(height: 32)
                .roundedRectBlur(cornerRadius: 20, fadeWidth: 16)
                .verticalEdgeBlur(height: 48, maxBlurRadius: 5)
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Main Test Preview

@available(iOS 15.0, *)
private struct ShaderTestPreview: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                Text("AemiSDR Shader Test Suite")
                    .font(.title2.bold())
                    .padding(.top)

                Text("Visual verification of Metal shader kernels")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                CornerComparisonView()
                FadeWidthComparisonView()
                CornerRadiusComparisonView()
                TransitionComparisonView()
                VerticalEdgeMaskTestView()
                InversionTestView()
                CombinedEffectsTestView()

                Spacer(minLength: 32)
            }
            .padding(.horizontal)
        }
    }
}

#Preview {
    if #available(iOS 15.0, *) {
        ShaderTestPreview()
    } else {
        Text("Requires iOS 15+")
    }
}

#endif
