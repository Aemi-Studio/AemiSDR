//
//  MPSBlurUIView.swift
//  AemiSDR
//

#if os(iOS)
    import Metal
    import MetalPerformanceShaders
    import OSLog
    import QuartzCore
    import UIKit

    /// A `UIView` backed by `CAMetalLayer` that renders an MPS Gaussian blur
    /// on a captured backdrop texture.
    ///
    /// Unlike `LiquidLensUIView`, this view sets `framebufferOnly = false`
    /// because MPS kernels need read-write access to the drawable.
    @MainActor
    final class MPSBlurUIView: UIView {

        nonisolated private static let logger = Logger(
            subsystem: "studio.aemi.AemiSDR",
            category: "MPSBlurUIView"
        )

        private let device: MTLDevice
        private let commandQueue: MTLCommandQueue
        private var blurKernel: MPSImageGaussianBlur
        private var scaleKernel: MPSImageBilinearScale

        override class var layerClass: AnyClass { CAMetalLayer.self }
        private var metalLayer: CAMetalLayer { layer as! CAMetalLayer }

        // MARK: - Initialization

        init?(blurRadius: Float = 20) {
            guard let device = MTLCreateSystemDefaultDevice(),
                  let commandQueue = device.makeCommandQueue()
            else {
                Self.logger.error("Metal is not available on this device.")
                return nil
            }

            self.device = device
            self.commandQueue = commandQueue
            self.blurKernel = MPSImageGaussianBlur(device: device, sigma: blurRadius)
            self.scaleKernel = MPSImageBilinearScale(device: device)

            super.init(frame: .zero)

            metalLayer.device = device
            metalLayer.pixelFormat = .bgra8Unorm
            metalLayer.isOpaque = false
            metalLayer.framebufferOnly = false

            isUserInteractionEnabled = false
        }

        @available(*, unavailable)
        required init?(coder _: NSCoder) {
            fatalError("init(coder:) has not been implemented")
        }

        // MARK: - Configuration

        func updateBlurRadius(_ sigma: Float) {
            guard blurKernel.sigma != sigma else { return }
            blurKernel = MPSImageGaussianBlur(device: device, sigma: sigma)
        }

        // MARK: - UIView Lifecycle

        override func layoutSubviews() {
            super.layoutSubviews()
            metalLayer.contentsScale = displayScale
            metalLayer.drawableSize = CGSize(
                width: bounds.width * displayScale,
                height: bounds.height * displayScale
            )
        }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            metalLayer.contentsScale = displayScale
            metalLayer.drawableSize = CGSize(
                width: bounds.width * displayScale,
                height: bounds.height * displayScale
            )
        }

        // MARK: - Rendering

        /// Renders the source texture with Gaussian blur into the drawable.
        ///
        /// If the source size differs from the drawable size, an upscale pass runs
        /// first via `MPSImageBilinearScale`, followed by in-place blur.
        func renderBlurred(sourceTexture: MTLTexture) {
            guard bounds.width > 0, bounds.height > 0 else { return }
            guard let drawable = metalLayer.nextDrawable() else { return }
            guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }
            commandBuffer.label = "AemiSDR.MPSBlur.CommandBuffer"

            let drawableTexture = drawable.texture
            let needsScale = sourceTexture.width != drawableTexture.width
                || sourceTexture.height != drawableTexture.height

            if needsScale {
                // Upscale source → intermediate at drawable size, then blur into drawable
                let desc = MTLTextureDescriptor.texture2DDescriptor(
                    pixelFormat: drawableTexture.pixelFormat,
                    width: drawableTexture.width,
                    height: drawableTexture.height,
                    mipmapped: false
                )
                desc.usage = [.shaderRead, .shaderWrite]
                guard let intermediate = device.makeTexture(descriptor: desc) else { return }

                scaleKernel.encode(
                    commandBuffer: commandBuffer,
                    sourceTexture: sourceTexture,
                    destinationTexture: intermediate
                )
                blurKernel.encode(
                    commandBuffer: commandBuffer,
                    sourceTexture: intermediate,
                    destinationTexture: drawableTexture
                )
            } else {
                // Direct blur: source → drawable
                blurKernel.encode(
                    commandBuffer: commandBuffer,
                    sourceTexture: sourceTexture,
                    destinationTexture: drawableTexture
                )
            }

            commandBuffer.present(drawable)

            #if DEBUG
                commandBuffer.addCompletedHandler { buffer in
                    if let error = buffer.error {
                        Self.logger.error("GPU command buffer error: \(error.localizedDescription)")
                    }
                }
            #endif

            commandBuffer.commit()
        }
    }
#endif
