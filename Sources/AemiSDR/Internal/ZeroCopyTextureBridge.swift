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

    /// Opaque token identifying a consumer of a shared `ZeroCopyTextureBridge`.
    ///
    /// Multiple `BackdropCaptureCoordinator`s can share a single bridge (and
    /// therefore a single IOSurface ring) when their target capture dimensions
    /// are exactly equal. Each consumer tracks its own in-flight set
    /// and generation independently, so completion handlers from different
    /// consumers don't interfere.
    struct BridgeConsumerID: Hashable, Sendable {
        let raw: UInt
    }

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
    /// ## Multi-consumer slot ring
    ///
    /// The bridge holds a bounded ring with at least three slots, growing as consumers register.
    /// A frame is skipped when every slot is reserved. Each `render(consumer:...)` writes content into
    /// a slot not held by any consumer, marks it in-flight on behalf of the
    /// consumer, and returns a `ConsumableTexture` whose `onConsumed` closure
    /// releases it back when the GPU finishes.
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

        // Slot ring. Sized dynamically: `max(registeredConsumers + 2, 3)`.
        // The +2 buffer absorbs short scheduling spikes (one slot in CPU draw,
        // one freshly returned to GPU but not yet completed) on top of the per-
        // consumer in-flight allowance.
        private var slots: [BufferSlot] = []
        private var nextWriteIndex: Int = 0
        private var currentWidth: Int = 0
        private var currentHeight: Int = 0

        // Per-consumer state. Mutated under `stateLock` from arbitrary threads
        // (Metal completion handlers) and from `@MainActor` code that reads
        // under the same lock.
        private nonisolated let stateLock = NSLock()
        private nonisolated(unsafe) var inFlight: [BridgeConsumerID: Set<Int>] = [:]
        private nonisolated(unsafe) var generation: [BridgeConsumerID: UInt] = [:]
        private nonisolated(unsafe) var retiredConsumers: Set<BridgeConsumerID> = []
        nonisolated(unsafe) private static var nextConsumerID: UInt = 0

        // Completion closures retain a value copy of this metadata; they never read or write pixel memory.
        // Keeping all three wrappers alive is required even after resize/unregister releases the ring.
        private struct BufferSlot: @unchecked Sendable {
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

        // MARK: - Consumer Lifecycle

        /// Registers a new consumer of this bridge. The returned ID must be
        /// passed to subsequent `render(consumer:...)` calls and to
        /// `unregister(_:)` when the consumer is torn down.
        func register() -> BridgeConsumerID {
            stateLock.lock()
            defer { stateLock.unlock() }
            unsafe Self.nextConsumerID &+= 1
            let id = unsafe BridgeConsumerID(raw: Self.nextConsumerID)
            unsafe inFlight[id] = []
            unsafe generation[id] = 0
            // Give an additional consumer capacity; a delayed GPU can still exhaust the ring, in which case
            // render skips a frame rather than overwriting a reservation.
            let target = max(unsafe inFlight.count + 2, 3)
            if slots.count < target {
                let needed = target - slots.count
                let blank = (0..<needed).map { _ in BufferSlot() }
                slots.append(contentsOf: blank)
                // Re-create the just-added slots if dimensions are already set.
                if currentWidth > 0, currentHeight > 0 {
                    for i in (slots.count - needed)..<slots.count {
                        slots[i] = createSlot(width: currentWidth, height: currentHeight)
                    }
                }
            }
            return id
        }

        /// Rejects new captures for this consumer. Outstanding reservations remain until completion;
        /// unregistering a view does not mean the GPU has finished reading its last source.
        func unregister(_ consumer: BridgeConsumerID) {
            stateLock.lock()
            defer { stateLock.unlock() }
            guard let pending = unsafe inFlight[consumer] else { return }
            if pending.isEmpty {
                unsafe inFlight.removeValue(forKey: consumer)
                unsafe generation.removeValue(forKey: consumer)
            } else {
                unsafe retiredConsumers.insert(consumer)
            }
        }

        // MARK: - Slot ring

        /// Ensures the ring's backing buffers match the requested dimensions,
        /// reallocating only when the size changes.
        private func ensureBuffers(width: Int, height: Int) {
            guard width != currentWidth || height != currentHeight else { return }

            for i in 0..<slots.count {
                slots[i] = createSlot(width: width, height: height)
            }
            // After a size change every previous in-flight slot is stale.
            // Bump every consumer's generation under the lock so any concurrent
            // `markCompleted` either sees the old `inFlight` (its slot id is
            // still there and gets removed) or the new generation (its check
            // fails and it no-ops).
            stateLock.lock()
            defer { stateLock.unlock() }
            // Retired consumers only refer to old physical buffers, retained by their completion closures.
            for id in unsafe retiredConsumers {
                unsafe inFlight.removeValue(forKey: id)
                unsafe generation.removeValue(forKey: id)
            }
            unsafe retiredConsumers.removeAll()
            for (id, _) in unsafe inFlight {
                unsafe inFlight[id] = []
                unsafe generation[id] = unsafe (generation[id] ?? 0) &+ 1
            }
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

        /// Picks a slot not currently in-flight on behalf of ANY consumer.
        /// Returns `nil` when every slot is in-flight (the GPU has fallen
        /// further behind than the ring can absorb).
        ///
        /// Also skips slots whose backing storage is permanently broken
        /// (initial CVPixelBuffer/MTLTexture allocation failed).
        private func acquireWriteSlot() -> Int? {
            stateLock.lock()
            defer { stateLock.unlock() }
            // Union of every consumer's in-flight set: the slot is unavailable
            // for write if any consumer's GPU might still be reading it.
            var globallyInFlight = Set<Int>()
            for set in unsafe inFlight.values {
                globallyInFlight.formUnion(set)
            }
            for offset in 0..<slots.count {
                let candidate = (nextWriteIndex + offset) % slots.count
                if globallyInFlight.contains(candidate) { continue }
                let slot = slots[candidate]
                if slot.pixelBuffer == nil || slot.texture == nil { continue }
                nextWriteIndex = (candidate + 1) % slots.count
                return candidate
            }
            return nil
        }

        /// Signals that the GPU has finished reading the given slot. Safe to
        /// call from any thread (`MTLCommandBuffer.addCompletedHandler` runs
        /// off the main thread).
        ///
        /// The `generation` argument is the value captured when the slot was
        /// handed out. A mismatch means the slot ring was reallocated since,
        /// so the slot ID no longer refers to the same physical buffer.
        nonisolated func markCompleted(
            _ slotID: Int,
            generation: UInt,
            consumer: BridgeConsumerID
        ) {
            stateLock.lock()
            defer { stateLock.unlock() }
            guard unsafe self.generation[consumer] == generation else { return }
            unsafe inFlight[consumer]?.remove(slotID)
            if unsafe retiredConsumers.contains(consumer), unsafe inFlight[consumer]?.isEmpty == true {
                unsafe inFlight.removeValue(forKey: consumer)
                unsafe self.generation.removeValue(forKey: consumer)
                unsafe retiredConsumers.remove(consumer)
            }
        }

        // MARK: - Render

        /// Renders into the next available buffer via a `CGContext` and returns
        /// a `ConsumableTexture` that bundles the GPU-visible `MTLTexture` with
        /// the closure that releases the slot back to the ring. The caller MUST
        /// invoke `onConsumed` (typically from `MTLCommandBuffer.addCompletedHandler`)
        /// after the GPU finishes reading, or subsequent renders may stall.
        ///
        /// Returns `nil` if every slot is in-flight — caller should skip this
        /// frame.
        func render(
            consumer: BridgeConsumerID,
            width: Int,
            height: Int,
            actions: (CGContext) -> Void
        ) -> ConsumableTexture? {
            guard width > 0, height > 0 else { return nil }
            guard textureCache != nil else { return nil }
            let registered = stateLock.withLock {
                unsafe generation[consumer] != nil && !retiredConsumers.contains(consumer)
            }
            guard registered else { return nil }

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
            guard
                let context = unsafe CGContext(
                    data: baseAddress,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: colorSpace,
                    bitmapInfo: Self.bitmapInfo
                )
            else { return nil }

            actions(context)

            // Capture this consumer's current generation so the consumer's
            // completion can detect a post-resize ring reallocation and no-op.
            stateLock.lock()
            let capturedGeneration = unsafe generation[consumer] ?? 0
            unsafe inFlight[consumer, default: []].insert(slotID)
            stateLock.unlock()

            return ConsumableTexture(
                texture: texture,
                onConsumed: { [weak self, slot] in
                    withExtendedLifetime(slot) {
                        self?.markCompleted(slotID, generation: capturedGeneration, consumer: consumer)
                    }
                }
            )
        }
    }

    // MARK: - Bridge Pool

    /// Process-wide pool of `ZeroCopyTextureBridge` instances keyed on
    /// `(device, exact-size)`. Coordinators capturing at equal dimensions reuse the same physical IOSurface ring.
    /// Unequal dimensions must not share: each render sizes the ring exactly, so rounded keys cause alternating
    /// captures to reallocate each other's buffers and invalidate every outstanding generation.
    ///
    /// Storage is `weak`-referenced: a bridge is released when no consumer
    /// holds a strong reference, freeing its IOSurface ring.
    @MainActor
    enum ZeroCopyTextureBridgePool {
        private struct Key: Hashable {
            let device: ObjectIdentifier
            let width: Int
            let height: Int
        }

        private final class WeakBridge {
            weak var bridge: ZeroCopyTextureBridge?
        }

        private static var pool: [Key: WeakBridge] = [:]

        /// Returns a bridge sized for the given dimensions on the given
        /// device. The bridge may be freshly constructed or reused.
        static func bridge(for device: MTLDevice, width: Int, height: Int) -> ZeroCopyTextureBridge {
            let key = Key(
                device: ObjectIdentifier(device),
                width: width,
                height: height
            )
            if let existing = pool[key]?.bridge { return existing }
            let fresh = ZeroCopyTextureBridge(device: device)
            let box = WeakBridge()
            box.bridge = fresh
            pool[key] = box
            return fresh
        }
    }
#endif
