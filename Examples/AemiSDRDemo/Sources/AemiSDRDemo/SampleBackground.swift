import SwiftUI

/// A colorful gradient background used across the demo screens.
struct SampleBackground: View {
    var body: some View {
        MeshGradient(
            width: 3, height: 3,
            points: [
                [0, 0], [0.5, 0], [1, 0],
                [0, 0.5], [0.5, 0.5], [1, 0.5],
                [0, 1], [0.5, 1], [1, 1],
            ],
            colors: [
                .red, .orange, .yellow,
                .purple, .pink, .mint,
                .blue, .indigo, .cyan,
            ]
        )
        .ignoresSafeArea()
    }
}
