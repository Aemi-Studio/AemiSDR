import SwiftUI

struct ContentView: View {
    var body: some View {
        TabView {
            PresetsGalleryView()
                .tabItem {
                    Label("Presets", systemImage: "square.grid.2x2")
                }

            CustomBlurView()
                .tabItem {
                    Label("Playground", systemImage: "slider.horizontal.3")
                }

            ModifiersShowcaseView()
                .tabItem {
                    Label("Modifiers", systemImage: "paintbrush")
                }

            InteractiveDemoView()
                .tabItem {
                    Label("Interactive", systemImage: "hand.draw")
                }

            DebugDumpView()
                .tabItem {
                    Label("Debug", systemImage: "ladybug")
                }
        }
    }
}
