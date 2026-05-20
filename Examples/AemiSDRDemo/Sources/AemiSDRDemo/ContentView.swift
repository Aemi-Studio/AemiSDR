import AemiSDR
import SwiftUI

struct ContentView: View {
    var body: some View {
        #if os(iOS)
            TabView {
                Tab("Blur", systemImage: "aqi.medium") {
                    VariableBlurDemo()
                }
                Tab("Mask", systemImage: "square.on.circle") {
                    AlphaMaskDemo()
                }
                Tab("Glass", systemImage: "rectangle.on.rectangle") {
                    VisualEffectDemo()
                }
                Tab("Liquid", systemImage: "drop.circle") {
                    LiquidLensDemoView()
                }
            }
        #else
            VStack(spacing: 16) {
                Image(systemName: "iphone")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("AemiSDR Demo is iOS-only")
                    .font(.title3.bold())
                Text("Open the workspace in Xcode and run the iOS scheme.")
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
    }
}
