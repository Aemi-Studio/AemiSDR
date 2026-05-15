//
//  AemiSDRPreview.swift
//  AemiSDR
//

import SwiftUI

#if os(iOS)
    @available(iOS 15.0, *)
    private struct AemiSDRPreview: View {
        var body: some View {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    liquidBackgroundSection
                    liquidOverlaySection
                    capsuleAutoRadiusSection
                    backdropBlurSection
                    uniformBlurSection
                    variableBlurSection
                    centerBlurSection
                    alphaMaskSection
                    stackedEffectsSection
                    stackedStickyHeaderSection
                }
                .padding(16)
            }
            .background(
                LinearGradient(
                    colors: [Color.black, Color.blue.opacity(0.55), Color.indigo.opacity(0.6)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            )
        }

        private var liquidBackgroundSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Background Surface")
                    .font(.headline)
                    .foregroundStyle(.white)

                LiquidDemoControlsContent(title: "Music Queue Controls")
                    .padding(10)
                    .liquidBackground(
                        .regular,
                        shape: LiquidLensClipShape.roundedRect(cornerRadius: 26)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
            }
        }

        private var liquidOverlaySection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Overlay Surface")
                    .font(.headline)
                    .foregroundStyle(.white)

                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.mint, .cyan, .blue, .indigo],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(spacing: 14) {
                        Image(systemName: "sparkles.rectangle.stack.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.white)
                        Text("Overlay Refraction")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text(
                            "Use `.liquidOverlay` when content should stay untouched and only the top layer refracts."
                        )
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.horizontal, 22)
                    }
                }
                .frame(height: 220)
                .liquidOverlay(
                    .subtle,
                    shape: LiquidLensClipShape.roundedRect(cornerRadius: 24)
                )
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
        }

        private var capsuleAutoRadiusSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Capsule Auto Radius")
                    .font(.headline)
                    .foregroundStyle(.white)

                HStack(spacing: 14) {
                    Label("Home", systemImage: "house.fill")
                    Label("Search", systemImage: "magnifyingglass")
                    Label("Profile", systemImage: "person.fill")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .liquidBackground(.subtle, shape: LiquidLensClipShape.capsule)
                .clipShape(Capsule())
            }
        }

        private var backdropBlurSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Backdrop Blur")
                    .font(.headline)
                    .foregroundStyle(.white)

                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            AngularGradient(
                                colors: [.orange, .pink, .purple, .blue, .cyan, .orange],
                                center: .center
                            )
                        )

                    VStack(spacing: 12) {
                        Text("Floating Controls")
                            .font(.headline)
                            .foregroundStyle(.white)
                        HStack(spacing: 14) {
                            Image(systemName: "house.fill")
                            Image(systemName: "magnifyingglass")
                            Image(systemName: "plus.circle.fill")
                            Image(systemName: "heart.fill")
                        }
                        .font(.title3)
                        .padding(.horizontal, 22)
                        .padding(.vertical, 10)
                        .backdropBlurBackground(
                            BackdropBlurConfiguration(
                                blurRadius: 26,
                                colorTint: .white,
                                colorTintAlpha: 0.16,
                                saturationDeltaFactor: 1.8
                            ),
                            ignoreSafeArea: false
                        )
                        .clipShape(Capsule())
                    }
                }
                .frame(height: 180)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }

        private var uniformBlurSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Uniform Blur")
                    .font(.headline)
                    .foregroundStyle(.white)

                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.red, .orange, .yellow, .green],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(spacing: 12) {
                        Image(systemName: "circle.hexagongrid.fill")
                            .font(.system(size: 34))
                            .foregroundStyle(.white)
                        Text("Even Blur")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text("Constant blur intensity across the entire surface.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 22)
                    }
                }
                .frame(height: 200)
                .uniformBlur(maxBlurRadius: 6)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }

        private var variableBlurSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Variable Blur")
                    .font(.headline)
                    .foregroundStyle(.white)

                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.indigo, .purple, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(spacing: 12) {
                        Image(systemName: "aqi.medium")
                            .font(.system(size: 34))
                            .foregroundStyle(.white)
                        Text("Edge Blur")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text("Smooth directional blur that fades content at vertical edges.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 22)
                    }
                }
                .frame(height: 200)
                .verticalEdgeBlur(height: 80, maxBlurRadius: 4)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }

        private var centerBlurSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Center Blur")
                    .font(.headline)
                    .foregroundStyle(.white)

                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.teal, .blue, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(spacing: 12) {
                        Image(systemName: "circle.dashed.inset.filled")
                            .font(.system(size: 34))
                            .foregroundStyle(.white)
                        Text("Center Focus")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text("Blur peaks at the center while edges stay sharp.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 22)
                    }
                }
                .frame(height: 200)
                .verticalCenterBlur(maxBlurRadius: 4)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }

        private var alphaMaskSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Alpha Mask")
                    .font(.headline)
                    .foregroundStyle(.white)

                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.green, .teal, .cyan],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(spacing: 12) {
                        Image(systemName: "square.on.circle")
                            .font(.system(size: 34))
                            .foregroundStyle(.white)
                        Text("Edge Mask")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text("Alpha mask that fades content to transparent at vertical edges.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 22)
                    }
                }
                .frame(height: 200)
                .verticalEdgeMask(height: 80)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }

        private var stackedEffectsSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Stacked Effects")
                    .font(.headline)
                    .foregroundStyle(.white)

                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [.purple, .blue, .teal],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )

                    VStack(spacing: 12) {
                        Image(systemName: "square.3.layers.3d")
                            .font(.system(size: 34))
                            .foregroundStyle(.white)
                        Text("Blur + Liquid Lens")
                            .font(.title3.bold())
                            .foregroundStyle(.white)
                        Text("Uniform blur and liquid lens composed on the same content.")
                            .font(.caption)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 22)
                    }
                }
                .frame(height: 200)
                .uniformBlur(maxBlurRadius: 20)
                .liquidOverlay(
                    .subtle,
                    shape: LiquidLensClipShape.roundedRect(cornerRadius: 22)
                )
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            }
        }

        private var stackedStickyHeaderSection: some View {
            VStack(alignment: .leading, spacing: 10) {
                Text("Sticky Header Stack")
                    .font(.headline)
                    .foregroundStyle(.white)

                VStack(spacing: 0) {
                    HStack(spacing: 10) {
                        Image(systemName: "wave.3.right.circle.fill")
                            .font(.title3)
                        Text("Pinned Stack Header")
                            .font(.headline)
                        Spacer()
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 12)
                    .backdropBlurBackground(
                        BackdropBlurConfiguration(
                            blurRadius: 20,
                            colorTint: .white,
                            colorTintAlpha: 0.12,
                            saturationDeltaFactor: 1.8
                        ),
                        ignoreSafeArea: false
                    )
                    .liquidBackground(
                        .regular,
                        shape: LiquidLensClipShape.roundedRect(cornerRadius: 18),
                        cornerRadius: .points(18),
                        ignoreSafeArea: false
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))

                    VStack(spacing: 8) {
                        ForEach(0..<4, id: \.self) { i in
                            HStack {
                                Text("Playlist \(i + 1)")
                                    .font(.subheadline.weight(.semibold))
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(Color(.tertiarySystemGroupedBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        }
                    }
                    .padding(10)
                }
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            }
        }
    }

    @available(iOS 15.0, *)
    private struct LiquidDemoControlsContent: View {
        let title: String

        @State private var wiFiEnabled = true
        @State private var bluetoothEnabled = false
        @State private var brightness = 0.55
        @State private var selection = 0

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                Text(title)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)

                VStack(spacing: 0) {
                    row { Toggle("Wi-Fi", isOn: $wiFiEnabled) }
                    Divider().padding(.leading, 12)
                    row { Toggle("Bluetooth", isOn: $bluetoothEnabled) }
                    Divider().padding(.leading, 12)
                    row {
                        HStack {
                            Text("Brightness")
                            Slider(value: $brightness)
                        }
                    }
                }
                .background(Color(.tertiarySystemGroupedBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                Picker("Mode", selection: $selection) {
                    Text("Auto").tag(0)
                    Text("Manual").tag(1)
                    Text("Hybrid").tag(2)
                }
                .pickerStyle(.segmented)

                HStack(spacing: 10) {
                    Button("Primary") {}
                        .buttonStyle(.borderedProminent)
                    Button("Secondary") {}
                        .buttonStyle(.bordered)
                }
            }
        }

        private func row<V: View>(@ViewBuilder _ content: () -> V) -> some View {
            content()
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
        }
    }

    #Preview {
        if #available(iOS 15.0, *) {
            AemiSDRPreview()
        } else {
            Text("Requires iOS 15+")
        }
    }
#else
    #Preview {
        Text("AemiSDR previews are currently focused on iOS effects.")
    }
#endif
