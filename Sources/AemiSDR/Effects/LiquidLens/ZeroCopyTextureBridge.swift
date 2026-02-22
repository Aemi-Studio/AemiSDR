//
//  ZeroCopyTextureBridge.swift
//  AemiSDR
//

#if os(iOS)
    import CoreVideo
    import Metal
    import OSLog
    import UIKit

    /// Bridges CPU drawing (`CGContext`) and GPU reading (`MTLTexture`) through shared
    /// IOSurface-backed `CVPixelBuffer`s, eliminating per-frame allocations and texture uploads.
    ///
    /// Uses double-buffering: the CPU draws into one buffer while the GPU reads from the
    /// other, preventing read/write races that cause flicker.
    @MainActor
    final class ZeroCopyTextureBridge {

        private static let logger = Logger(
            subsystem: "studio.aemi.AemiSDR",
            category: "ZeroCopyTextureBridge"
        )

        private let device: MTLDevice
        private let colorSpace = CGColorSpaceCreateDeviceRGB()
        private static let bitmapInfo =
            CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue

        private var textureCache: CVMetalTextureCache?

        // Double-buffered slots
        private var slots: [BufferSlot] = [BufferSlot(), BufferSlot()]
        private var writeIndex: Int = 0
        private var currentWidth: Int = 0
        private var currentHeight: Int = 0

        private struct BufferSlot {
            var pixelBuffer: CVPixelBuffer?
            var cvTexture: CVMetalTexture?
            var context: CGContext?
            var texture: MTLTexture?
        }

        init(device: MTLDevice) {
            self.device = device

            var cache: CVMetalTextureCache?
            let status = CVMetalTextureCacheCreate(
                kCFAllocatorDefault,
                nil,
                device,
                nil,
                &cache
            )
            if status != kCVReturnSuccess {
                Self.logger.error("Failed to create CVMetalTextureCache: \(status)")
            }
            self.textureCache = cache
        }

        /// Ensures both backing buffer slots match the requested dimensions,
        /// reallocating only when the size changes.
        private func ensureBuffers(width: Int, height: Int) {
            guard width != currentWidth || height != currentHeight else { return }

            for i in 0..<slots.count {
                slots[i] = createSlot(width: width, height: height)
            }
            currentWidth = width
            currentHeight = height
        }

        private func createSlot(width: Int, height: Int) -> BufferSlot {
            var slot = BufferSlot()
            guard let textureCache else { return slot }

            let attributes: [String: Any] = [
                kCVPixelBufferMetalCompatibilityKey as String: true,
                kCVPixelBufferIOSurfacePropertiesKey as String: [:] as [String: Any],
            ]

            var buffer: CVPixelBuffer?
            let status = CVPixelBufferCreate(
                kCFAllocatorDefault,
                width,
                height,
                kCVPixelFormatType_32BGRA,
                attributes as CFDictionary,
                &buffer
            )

            guard status == kCVReturnSuccess, let buffer else {
                Self.logger.error("Failed to create CVPixelBuffer: \(status)")
                return slot
            }
            slot.pixelBuffer = buffer

            // Create CVMetalTexture wrapping this buffer
            var metalTexture: CVMetalTexture?
            let texStatus = CVMetalTextureCacheCreateTextureFromImage(
                kCFAllocatorDefault,
                textureCache,
                buffer,
                nil,
                .bgra8Unorm,
                width,
                height,
                0,
                &metalTexture
            )

            if texStatus == kCVReturnSuccess {
                slot.cvTexture = metalTexture
                if let metalTexture {
                    slot.texture = CVMetalTextureGetTexture(metalTexture)
                }
            } else {
                Self.logger.error("Failed to create CVMetalTexture: \(texStatus)")
            }

            // Create CGContext pointing at the buffer's memory
            CVPixelBufferLockBaseAddress(buffer, [])
            if let baseAddress = CVPixelBufferGetBaseAddress(buffer) {
                let bytesPerRow = CVPixelBufferGetBytesPerRow(buffer)
                slot.context = CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: Self.bitmapInfo
                )
            }
            CVPixelBufferUnlockBaseAddress(buffer, [])

            return slot
        }

        /// Renders into the next available buffer via a `CGContext` and returns the GPU-visible `MTLTexture`.
        ///
        /// Double-buffered: each call writes to a different backing buffer than the previous one,
        /// so the GPU can safely read the last-returned texture while the CPU draws the next frame.
        func render(width: Int, height: Int, actions: (CGContext) -> Void) -> MTLTexture? {
            guard width > 0, height > 0 else { return nil }
            guard textureCache != nil else { return nil }

            ensureBuffers(width: width, height: height)

            let slot = slots[writeIndex]
            guard let pixelBuffer = slot.pixelBuffer, let context = slot.context else { return nil }

            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            actions(context)
            CVPixelBufferUnlockBaseAddress(pixelBuffer, [])

            // Flip to the other buffer for the next frame
            writeIndex = (writeIndex + 1) % slots.count

            return slot.texture
        }
    }
#endif
