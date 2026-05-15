# AemiSDR

A lightweight, App Store-safe SwiftUI library for GPU-accelerated blurs, masks, backdrop effects, and physics-based liquid distortion.

AemiSDR works seamlessly with `ScrollView` and dynamic content, providing high-performance effects through a modifier-based API.

- **Variable Blur**: Gradient-driven blur with rounded rectangle and superellipse shapes (iOS)
- **Alpha Masks**: Fade content edges with configurable mask shapes (iOS)
- **Backdrop Blur**: Customizable backdrop blur with tint, saturation, and system material presets (iOS + macOS)
- **Liquid Background**: Physics-based refraction with chromatic aberration and Sellmeier dispersion (iOS)
- **Display Corner Radius**: Retrieve the device's actual screen corner radius (iOS)
- **Optimized**: Metal shaders compiled automatically via SPM build plugin, with result caching and zero-copy texture bridging


<details>

<summary><h2>Example</h2></summary>

https://github.com/user-attachments/assets/41c106cc-6c1d-4a43-bbaa-09cf44c9bfcc

</details>



## Requirements

- iOS 14+ / macOS 11+
- Swift 6.2 Toolchain
- SwiftUI


## Installation

Add the package in Xcode (`File` → `Add Package Dependencies…`) using the repository URL, or add it to your `Package.swift`:

```swift
.dependencies = [
    .package(url: "https://github.com/Aemi-Studio/AemiSDR.git", branch: "main")
]
```

## Usage

### Scroll View Edge Fade

Combine blurs and masks to fade the edges of a `ScrollView`:

```swift
import SwiftUI
import AemiSDR

struct ContentView: View {
    var body: some View {
        ScrollView {
            // your content
        }
        .roundedRectMask()
        .verticalEdgeMask(height: 32)
        .roundedRectBlur()
        .verticalEdgeBlur(height: 48, maxBlurRadius: 5)
    }
}
```

### Frosted Glass Background

```swift
Text("Hello")
    .padding()
    .frostedBackdropBackground(blurRadius: 20, tintOpacity: 0.15)
```

### System Material Blur

```swift
// Use a system material preset
BackdropBlurView(configuration: .ultraThinMaterial)

// Or customize fully
Text("Overlay")
    .padding()
    .backdropBlurBackground(blurRadius: 25, colorTint: .blue, colorTintAlpha: 0.1)
```

### Liquid Background Effect

```swift
VStack {
    // your content
}
.padding()
.liquidBackground(
    .regular,
    shape: RoundedRectangle(cornerRadius: 24, style: .continuous)
)
```

Or use the shorthand modifier:

```swift
ScrollView {
    // content
}
.liquidBackground(
    .subtle,
    shape: Capsule(style: .continuous),
    ignoreSafeArea: false
)
```


## API

### Variable Blur (iOS 15+)

| Modifier | Description |
|---|---|
| `roundedRectBlur(...)` | Overlay blur shaped as a rounded rectangle or superellipse |
| `verticalEdgeBlur(...)` | Blur applied to the top and/or bottom edges of a view |

### Alpha Mask (iOS 15+)

| Modifier | Description |
|---|---|
| `roundedRectMask(...)` | Alpha mask shaped as a rounded rectangle or superellipse |
| `verticalEdgeMask(...)` | Alpha mask for vertical edges, ideal for scroll views |

### Backdrop Blur (iOS 15+ / macOS 12+)

| Modifier | Description |
|---|---|
| `backdropBlurBackground(...)` | Customizable blur as a background layer |
| `backdropBlurOverlay(...)` | Customizable blur as an overlay layer |
| `frostedBackdropBackground(...)` | Convenience frosted blur effect |
| `tintedBackdropBackground(...)` | Colored blur background |

Configuration-based API with system presets:

```swift
// System presets (iOS): .light, .dark, .extraLight, .ultraThinMaterial,
//                       .thinMaterial, .material, .thickMaterial, .chromeMaterial
BackdropBlurView(configuration: .material)

// Custom configuration
var config = BackdropBlurConfiguration()
config.blurRadius = 20
config.saturationDeltaFactor = 1.8
config.colorTint = .blue
config.colorTintAlpha = 0.1
BackdropBlurView(configuration: config)
```

### Liquid Background (iOS 15+)

| Modifier | Description |
|---|---|
| `liquid(...)` | Shorthand for applying liquid glass as a background |
| `liquidBackground(...)` | Applies liquid glass as a background layer |
| `liquidOverlay(...)` | Applies liquid glass as an overlay layer |

Key configuration options:

- **Materials**: `.crownGlass`, `.flintGlass`, `.water`, `.acrylic`, `.diamond` — each with physically-based Sellmeier dispersion coefficients
- **Falloff curves**: `.linear`, `.easeIn`, `.easeOut`, `.easeInOut`, `.cubic`, `.exponential`
- **Corner radius**: `.proportional(Float)` or `.points(Float)` when you need explicit overrides
- **Clip shapes**: Any SwiftUI `Shape` (iOS 16+) with automatic corner-radius inference via `Mirror`

### Display Corner Radius (iOS)

```swift
// Static accessor
let radius = UIScreen.displayCornerRadius

// From a specific view context
let radius = myView.screenCornerRadius
```

All modifiers come with sensible defaults and can be customized for corner style, transition smoothness, and more.

## Demo App

A full demo app is included in `Examples/AemiSDRDemo/` with tabbed views showcasing each effect:

- **Blur**: Variable blur configurations
- **Mask**: Alpha mask examples
- **Glass**: Backdrop blur presets and custom blurs
- **Liquid**: Liquid background surface controls

For Xcode development with both the package and demo app in one window, open `AemiSDR.xcworkspace` at the repository root.


## Development

### Metal Shaders

The Metal shader source files are located in `Sources/AemiSDR/Shaders/`. The package uses a **Swift Package Manager build plugin** that automatically compiles shaders during the build process.

When you build the package (via `swift build` or Xcode), the `MetalShaderBuildPlugin` will:

1. Find all `.metal` files in the target
2. Compile `.ci.metal` files in Core Image mode (`-fcikernel`) and other `.metal` files in standard Metal mode
3. Generate platform-specific Metal libraries:
   - `AemiSDR.iOS.metallib` (iOS 14.0+)
   - `AemiSDR.macOS.metallib` (macOS 11.0+)

**No manual compilation is required.** Simply edit the `.metal` files and rebuild — the plugin handles the rest.

### Build Plugin Details

The plugin is located in `Plugins/MetalShaderBuildPlugin/` and uses `MetalCompilerTool` (in `Sources/MetalCompilerTool/`) to invoke the Metal toolchain. Key features:

- **Incremental builds**: Shaders are only recompiled when source files change
- **Xcode Cloud compatible**: Uses `-fmodules=none` to avoid sandbox issues
- **Cross-platform**: Generates libraries with correct deployment targets for each platform


## License

This software is provided under the Mozilla Public License 2.0.
