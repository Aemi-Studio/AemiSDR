#if os(iOS)
    import Metal
    import Synchronization
    import Testing
    import UIKit

    @testable import AemiSDR

    @MainActor
    @Suite("Capture ownership")
    struct CaptureOwnershipTests {
        @Test func `equal sizes share a bridge but unequal sizes never share a ring`() throws {
            let device = try #require(MTLCreateSystemDefaultDevice())
            let first = ZeroCopyTextureBridgePool.bridge(for: device, width: 257, height: 257)
            let equal = ZeroCopyTextureBridgePool.bridge(for: device, width: 257, height: 257)
            let different = ZeroCopyTextureBridgePool.bridge(for: device, width: 258, height: 257)
            #expect(first === equal)
            #expect(first !== different)
        }

        @Test func `unregistering does not permit an outstanding texture to be overwritten`() throws {
            let device = try #require(MTLCreateSystemDefaultDevice())
            let bridge = ZeroCopyTextureBridge(device: device)
            let departing = bridge.register()
            let held = try #require(bridge.render(consumer: departing, width: 16, height: 16) { _ in })
            bridge.unregister(departing)
            let arriving = bridge.register()
            var captures: [ConsumableTexture] = []
            for _ in 0..<8 {
                guard let capture = bridge.render(consumer: arriving, width: 16, height: 16, actions: { _ in }) else {
                    break
                }
                captures.append(capture)
            }
            #expect(!captures.isEmpty)
            #expect(!captures.contains { ObjectIdentifier($0.texture) == ObjectIdentifier(held.texture) })
            held.onConsumed()
            captures.forEach { $0.onConsumed() }
            bridge.unregister(arriving)
        }

        @Test(arguments: [false, true])
        func `an unknown or unregistered consumer cannot acquire a slot`(unregistered: Bool) throws {
            let device = try #require(MTLCreateSystemDefaultDevice())
            let bridge = ZeroCopyTextureBridge(device: device)
            let consumer = bridge.register()
            if unregistered { bridge.unregister(consumer) }
            let rejected = unregistered ? consumer : BridgeConsumerID(raw: .max)
            let capture = bridge.render(consumer: rejected, width: 16, height: 16) { _ in }
            #expect(capture == nil)
            capture?.onConsumed()
            bridge.unregister(consumer)
        }

        @Test func `a replaced source remains reserved until every GPU read finishes`() throws {
            let device = try #require(MTLCreateSystemDefaultDevice())
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm, width: 16, height: 16, mipmapped: false)
            let texture = try #require(device.makeTexture(descriptor: descriptor))
            let releases = ReleaseCounter()
            var source: TextureSourceLease? = TextureSourceLease(texture: texture, onConsumed: { releases.increment() })
            let first = try #require(source?.beginRead())
            let second = try #require(source?.beginRead())
            source = nil
            #expect(releases.value == 0)
            first.finish()
            #expect(releases.value == 0)
            second.finish()
            #expect(releases.value == 1)
            first.finish()
            second.finish()
            #expect(releases.value == 1)
        }

        @Test func `completion after a resize cannot release a new generation's slot`() throws {
            let device = try #require(MTLCreateSystemDefaultDevice())
            let bridge = ZeroCopyTextureBridge(device: device)
            let consumer = bridge.register()
            let old = try #require(bridge.render(consumer: consumer, width: 16, height: 16) { _ in })
            let current = try #require(bridge.render(consumer: consumer, width: 32, height: 32) { _ in })
            old.onConsumed()
            let second = try #require(bridge.render(consumer: consumer, width: 32, height: 32) { _ in })
            let third = try #require(bridge.render(consumer: consumer, width: 32, height: 32) { _ in })
            #expect(bridge.render(consumer: consumer, width: 32, height: 32) { _ in } == nil)
            current.onConsumed()
            second.onConsumed()
            third.onConsumed()
            bridge.unregister(consumer)
        }

        @Test func `a source that cannot render yet stays reserved until replacement or view destruction`() throws {
            let device = try #require(MTLCreateSystemDefaultDevice())
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(
                pixelFormat: .bgra8Unorm, width: 16, height: 16, mipmapped: false)
            let texture = try #require(device.makeTexture(descriptor: descriptor))
            let releases = ReleaseCounter()
            var view: LiquidLensUIView? = LiquidLensUIView()
            view?.setSourceTexture(texture, onConsumed: { releases.increment() })
            #expect(releases.value == 0)
            view?.layoutSubviews()
            #expect(releases.value == 0)
            view?.setSourceTexture(texture, onConsumed: { releases.increment() })
            #expect(releases.value == 1)
            view = nil
            #expect(releases.value == 2)
        }
    }

    private final class ReleaseCounter: Sendable {
        private let count = Mutex(0)
        var value: Int { count.withLock { $0 } }
        func increment() { count.withLock { $0 += 1 } }
    }
#endif
