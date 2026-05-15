//
//  ZeroCopyTextureBridge.swift
//  AemiSDR
//

#if os(iOS)
    import CoreVideo
    import Foundation
    import Metal
    import OSLog
    import UIKit

    /// A texture handed back by `ZeroCopyTextureBridge.render(...)` along with a
    /// closure the GPU consumer must invoke (typically from
    /// `MTLCommandBuffer.addCompletedHandler`) when it has finished reading.
    struct ConsumableTexture: @unchecked Sendable {
        let texture: MTLTexture
        let onConsumed: @Sendable () -> Void
    }

    /// Bridges CPU drawing (`CGContext`) and GPU reading (`MTLTexture`) through shared
    /// IOSurface-backed `CVPixelBuffer`s, eliminating per-frame allocations and texture uploads.
    ///
    /// ## Slot ring
    ///
    /// The bridge holds a 3-slot ring. Each `render(...)` writes into the next slot
    /// that the GPU is not currently reading and returns a `ConsumableTexture`. The
    /// caller MUST fire its `onConsumed` closure (typically wired through
    /// `MTLCommandBuffer.addCompletedHandler`) so the slot becomes reclaimable.
    ///
    /// 3 slots are sufficient at any sustainable frame rate: at most one slot is
    /// in-flight on the GPU, one is being written by the CPU, and one is the safety
    /// fallback for spikes. If the GPU ever falls behind enough that all 3 slots
    /// are in-flight, the bridge returns `nil` and the caller can skip the frame.
    ///
    /// ## CGContext lifetime
    ///
    /// The `CGContext` over each slot's pixel data is built inside `render(...)`
    /// while the IOSurface base address is locked, then discarded when the lock
    /// drops. This avoids relying on the (technically undefined) behaviour of a
    /// `CGContext` over an unlocked `CVPixelBuffer`.
    @MainActor
    final class ZeroCopyTextureBridge {

        private static let logger = Logger(
            subsystem: "studio.aemi.AemiSDR",
            category: "ZeroCopyTextureBridge"
        )

        private let device: MTLDevice
        /// Display P3 tags the IOSurface's CPU-side context so backdrop content
        /// drawn into it preserves wide-gamut color rather than the older
        /// device-RGB fallback. The Metal side reads through the same color
        /// space tag via `CAMetalLayer.colorspace`.
        private let colorSpace: CGColorSpace =
            CGColorSpace(name: CGColorSpace.displayP3) ?? CGColorSpaceCreateDeviceRGB()
        private static let bitmapInfo =
            CGImageAlphaInfo.premultipliedFirst.rawValue
                | CGBitmapInfo.byteOrder32Little.rawValue

        private var textureCache: CVMetalTextureCache?

        // 3-slot ring. The GPU can be reading any one slot while the CPU writes
        // another; the third absorbs short scheduling bursts.
        private static let slotCount = 3
        private var slots: [BufferSlot] = Array(repeating: BufferSlot(), count: ZeroCopyTextureBridge.slotCount)
        private var nextWriteIndex: Int = 0
        private var currentWidth: Int = 0
        private var currentHeight: Int = 0

        // Slots currently held by the GPU. Mutated under `inFlightLock` from
        // arbitrary threads (Metal completion handlers) and from `@MainActor`
        // code that reads it under the same lock.
        private nonisolated let inFlightLock = NSLock()
        private nonisolated(unsafe) var inFlight = Set<Int>()

        // Bumped whenever the backing slots are reallocated. Each
        // `ConsumableTexture` captures the generation at the time it was
        // produced; `markCompleted` only releases the slot if the generation
        // still matches. This prevents an in-flight completion from a
        // previous-size frame from freeing a slot in the freshly-allocated
        // ring (where slot IDs would collide).
        private nonisolated(unsafe) var generation: UInt = 0

        private struct BufferSlot {
            var pixelBuffer: CVPixelBuffer?
            var cvTexture: CVMetalTexture?
            var texture: MTLTexture?
        }

        init(device: MTLDevice) {
            self.device = device

            var cache: CVMetalTextureCache?
            let status = unsafe CVMetalTextureCacheCreate(
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

        /// Ensures the ring's backing buffers match the requested dimensions,
        /// reallocating only when the size changes.
        private func ensureBuffers(width: Int, height: Int) {
            guard width != currentWidth || height != currentHeight else { return }

            for i in 0..<slots.count {
                slots[i] = createSlot(width: width, height: height)
            }
            // After a size change every previous in-flight slot is stale.
            // Bump the generation under the same lock so any concurrent
            // `markCompleted` either sees the old `inFlight` (its slot id is
            // still there and gets removed) or the new generation (its check
            // fails and it no-ops). The bump must happen with the lock held
            // so completion handlers can't see a half-updated state.
            inFlightLock.lock()
            inFlight.removeAll()
            generation &+= 1
            inFlightLock.unlock()
            nextWriteIndex = 0
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
            let status = unsafe CVPixelBufferCreate(
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
            let texStatus = unsafe CVMetalTextureCacheCreateTextureFromImage(
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

            return slot
        }

        /// Picks the next slot the GPU is not currently reading, advancing the
        /// ring pointer. Returns `nil` only when every slot is in-flight, which
        /// implies the GPU has fallen >2 frames behind the CPU.
        private func acquireWriteSlot() -> Int? {
            inFlightLock.lock()
            defer { inFlightLock.unlock() }
            for _ in 0..<slots.count {
                let candidate = nextWriteIndex
                nextWriteIndex = (nextWriteIndex + 1) % slots.count
                if !inFlight.contains(candidate) { return candidate }
            }
            return nil
        }

        /// Marks a slot as occupied by the GPU. Callers must invoke
        /// `markCompleted(_:)` from the matching `MTLCommandBuffer` completion
        /// handler so the slot can be reclaimed.
        private func markInFlight(_ slotID: Int) {
            inFlightLock.lock()
            inFlight.insert(slotID)
            inFlightLock.unlock()
        }

        /// Signals that the GPU has finished reading the given slot. Safe to call
        /// from any thread (`MTLCommandBuffer.addCompletedHandler` runs off the
        /// main thread).
        ///
        /// The `generation` argument is the value captured when the slot was
        /// handed out. A mismatch means the slot ring was reallocated since,
        /// so the slot ID no longer refers to the same physical buffer and
        /// the completion must no-op.
        nonisolated func markCompleted(_ slotID: Int, generation: UInt) {
            inFlightLock.lock()
            defer { inFlightLock.unlock() }
            guard self.generation == generation else { return }
            inFlight.remove(slotID)
        }

        /// Renders into the next available buffer via a `CGContext` and returns
        /// a `ConsumableTexture` that bundles the GPU-visible `MTLTexture` with
        /// the closure that releases the slot back to the ring. The caller MUST
        /// invoke `onConsumed` (typically from `MTLCommandBuffer.addCompletedHandler`)
        /// after the GPU finishes reading, or subsequent renders may stall.
        ///
        /// Returns `nil` if every slot is in-flight (GPU is more than two frames
        /// behind) — caller should skip this frame.
        func render(
            width: Int,
            height: Int,
            actions: (CGContext) -> Void
        ) -> ConsumableTexture? {
            guard width > 0, height > 0 else { return nil }
            guard textureCache != nil else { return nil }

            ensureBuffers(width: width, height: height)

            guard let slotID = acquireWriteSlot() else {
                Self.logger.debug("All slots in-flight; skipping frame")
                return nil
            }
            let slot = slots[slotID]
            guard let pixelBuffer = slot.pixelBuffer, let texture = slot.texture else { return nil }

            CVPixelBufferLockBaseAddress(pixelBuffer, [])
            defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, []) }

            // Build the CGContext while the IOSurface base address is locked;
            // the pointer is only guaranteed valid inside this lock/unlock pair.
            guard let baseAddress = unsafe CVPixelBufferGetBaseAddress(pixelBuffer) else { return nil }
            let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)
            guard let context = unsafe CGContext(
                data: baseAddress,
                width: width,
                height: height,
                bitsPerComponent: 8,
                bytesPerRow: bytesPerRow,
                space: colorSpace,
                bitmapInfo: Self.bitmapInfo
            ) else { return nil }

            actions(context)

            // Capture the current generation synchronously so the consumer
            // closure can detect a post-resize ring reallocation and no-op.
            let capturedGeneration = generation
            markInFlight(slotID)
            return ConsumableTexture(
                texture: texture,
                onConsumed: { [weak self] in
                    self?.markCompleted(slotID, generation: capturedGeneration)
                }
            )
        }
    }
#endif
