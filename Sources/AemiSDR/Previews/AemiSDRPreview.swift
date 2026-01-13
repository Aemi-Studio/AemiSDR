//
//  AemiSDRPreview.swift
//  AemiSDR
//
//  Created by Guillaume Coquard on 20.09.25.
//

import SwiftUI

private struct AemiSDRPreview: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: paddingAndSpacing) {
                ForEach(1...6, id: \.self) { index in
                    Image("Image_\(index)", bundle: .module)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(clippingShape)
                        .glass(clippingShape)
                }
            }
            .padding(.horizontal, paddingAndSpacing)
            #if os(macOS)
                .padding(.bottom, paddingAndSpacing)
            #endif
        }
        .fancyBlur()
    }

    private var paddingAndSpacing: CGFloat {
        #if os(iOS)
            16
        #else
            12
        #endif
    }

    private var cornerRadius: CGFloat {
        #if os(iOS)
            UIScreen.displayCornerRadius - paddingAndSpacing
        #else
            4
        #endif
    }

    private var clippingShape: some Shape {
        .rect(cornerRadius: cornerRadius)
    }
}

extension View {
    @ViewBuilder fileprivate func fancyBlur() -> some View {
        #if os(iOS)
            if #available(iOS 15.0, *) {
                roundedRectMask(fadeWidth: 32)
                .verticalEdgeMask(height: 32)
                .roundedRectBlur(fadeWidth: 32)
                    .verticalEdgeBlur(height: 32, maxBlurRadius: 5)
            } else {
                self
            }
        #else
            self
        #endif
    }

    @ViewBuilder fileprivate func glass(_ shape: some Shape) -> some View {
        if #available(iOS 26.0, macOS 26.0, *) {
            glassEffect(.regular, in: shape)
        } else {
            self
        }
    }
}

#Preview {
    AemiSDRPreview()
}
