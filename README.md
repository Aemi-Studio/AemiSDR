# AemiSDR

A lightweight, App Store-safe library for adding dynamic, GPU-accelerated blurs and masks to your SwiftUI views.

AemiSDR is designed to work seamlessly with `ScrollView` and other dynamic content, providing high-performance effects with a simple, modifier-based API.

- **Variable Blur**: Apply blurs as a gradient.
- **Alpha Masks**: Fade view content with alpha masks.
- **Advanced Shapes**: Use standard rounded rectangles or iOS-style superellipses (squircles).
- **Optimized**: Effects are powered by Metal shaders (compiled automatically via build plugin) and cache their results to ensure smooth performance.


<details>

<summary><h2>Example</h2></summary>

https://github.com/user-attachments/assets/41c106cc-6c1d-4a43-bbaa-09cf44c9bfcc

</details>



## Requirements

- iOS 14+
- Swift 6.2 Toolchain
- SwiftUI


## Installation

Add the package in Xcode (`File` → `Add Package Dependencies…`) using the repository URL, or add it to your `Package.swift`:

```swift
.dependencies = [
    .package(url: "https://github.com/Aemi-Studio/AemiSDR.git", branch: "main")
]
```

## Example

Apply blurs and masks directly to your views. The library is perfect for fading the edges of a `ScrollView`, as shown in the project's preview:

```swift
import SwiftUI
import AemiSDR

struct AemiSDRPreview: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ForEach(1 ... 6, id: \.self) { index in
                    Image("Image_\(index)", bundle: .module)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(clippingShape)
                }
            }
            .padding(.horizontal)
        }
        .fancyBlur()
    }

    private var clippingShape: some Shape {
        .rect(cornerRadius: UIScreen.displayCornerRadius - 16)
    }
}

private extension View {
    @ViewBuilder func fancyBlur() -> some View {
        if #available(iOS 15.0, *) {
            roundedRectMask()
                .verticalEdgeMask(height: 32)
                .roundedRectBlur()
                .verticalEdgeBlur(height: 48, maxBlurRadius: 5)
        } else {
            self
        }
    }
}
```

## API

The library provides four main SwiftUI modifiers (iOS 15+):

- `roundedRectBlur(...)`: An overlay blur shaped like a rounded rectangle or superellipse.
- `verticalEdgeBlur(...)`: A blur applied only to the top and bottom edges of a view.
- `roundedRectMask(...)`: An alpha mask to fade content, shaped as a rounded rectangle or superellipse.
- `verticalEdgeMask(...)`: An alpha mask for the top and bottom edges, perfect for scroll views.

All modifiers come with sensible defaults and can be customized for corner style, transition smoothness, and more.


## Development

### Metal Shaders

The Metal shader source files are located in `Sources/AemiSDR/Shaders/`. The package uses a **Swift Package Manager build plugin** that automatically compiles shaders during the build process.

When you build the package (via `swift build` or Xcode), the `AemiSDRShaderPlugin` will:

1. Find all `.metal` files in the target
2. Compile them using `xcrun metal` with Core Image kernel flags (`-fcikernel`)
3. Generate platform-specific Metal libraries:
   - `AemiSDR.iOS.metallib` (iOS 14.0+)
   - `AemiSDR.macOS.metallib` (macOS 11.0+)

**No manual compilation is required.** Simply edit the `.metal` files and rebuild — the plugin handles the rest.

### Build Plugin Details

The plugin is located in `Plugins/AemiSDRShaderPlugin/` and uses `MetalCompilerTool` (in `Sources/MetalCompilerTool/`) to invoke the Metal toolchain. Key features:

- **Incremental builds**: Shaders are only recompiled when source files change
- **Xcode Cloud compatible**: Uses `-fmodules=none` to avoid sandbox issues
- **Cross-platform**: Generates libraries with correct deployment targets for each platform


## License

This software is provided under the Mozilla Public License 2.0.
