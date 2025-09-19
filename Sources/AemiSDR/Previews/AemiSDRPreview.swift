//
//  AemiSDRPreview.swift
//  AemiSDR
//
//  Created by Gigi on 20.09.25.
//

import SwiftUI

private struct AemiSDRPreview: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 16) {
                ForEach(1 ... 6, id: \.self) { index in
                    Image("Image_\(index)", bundle: .module)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(clippingShape)
                        .glass(clippingShape)
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

    @ViewBuilder func glass(_ shape: some Shape) -> some View {
        if #available(iOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            self
        }
    }
}

#Preview {
    AemiSDRPreview()
}
