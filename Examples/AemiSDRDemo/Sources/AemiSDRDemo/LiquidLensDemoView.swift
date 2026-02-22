import AemiSDR
import SwiftUI

#if os(iOS)
    import UIKit

    struct LiquidLensDemoView: View {
        var body: some View {
            NavigationStack {
                DraggableLensScrollDemo()
            }
        }
    }

#else

    struct LiquidLensDemoView: View {
        var body: some View {
            NavigationStack {
                VStack(spacing: 16) {
                    Image(systemName: "drop.circle")
                        .font(.system(size: 48))
                        .foregroundStyle(.secondary)
                    Text("Liquid Lens is iOS-only")
                        .font(.title3.bold())
                    Text("The CAMetalLayer-backed renderer requires iOS.")
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle("Liquid Lens")
            }
        }
    }

#endif
