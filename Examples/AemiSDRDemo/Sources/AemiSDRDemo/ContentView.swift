import SwiftUI

struct ContentView: View {
    var body: some View {
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
            Tab("Lens", systemImage: "drop.circle") {
                LiquidLensDemoView()
            }
        }
    }
}
