import AemiSDR
import CoreGraphics
import Testing

@testable import GlassTuner

@MainActor
struct TunerFrameDeliveryTests {
    @Test func `dragging publishes completed frames while a newer shape is pending`() async throws {
        let gate = GatedImageRenderer()
        let model = TunerModel(renderImage: { image, origin, size, scale, configuration in
            try await gate.render(image, origin: origin, size: size, scale: scale, configuration: configuration)
        })
        await model.load(scale: 1)
        _ = await gate.nextStarted()
        model.settings.radius = 42
        model.requestRender()
        try await gate.finish()
        _ = await gate.nextStarted()
        // First render is usable even though the next slider event has already arrived. Never freeze until release.
        #expect(model.rendered != nil)
        try await gate.finish()
        model.cancel()
    }

    @Test func `changing sources still rejects a completed frame from the old source`() async throws {
        let gate = GatedImageRenderer()
        let model = TunerModel(renderImage: { image, origin, size, scale, configuration in
            try await gate.render(image, origin: origin, size: size, scale: scale, configuration: configuration)
        })
        await model.load(scale: 1)
        _ = await gate.nextStarted()
        model.settings.pattern = .white
        await model.load(scale: 1)
        try await gate.finish()
        _ = await gate.nextStarted()
        #expect(model.rendered == nil)
        try await gate.finish()
        model.cancel()
    }
}

private actor GatedImageRenderer {
    private let renderer = ClearGlassImageRenderer()
    private var finishers: [CheckedContinuation<Void, Never>] = []
    private var starts: [ClearGlassConfiguration] = []
    private var observers: [CheckedContinuation<ClearGlassConfiguration, Never>] = []

    func render(
        _ image: CGImage, origin: CGPoint, size: CGSize, scale: CGFloat, configuration: ClearGlassConfiguration
    ) async throws -> ClearGlassRenderedImage {
        let result = try await renderer.render(
            source: image, origin: origin, size: size, scale: scale, configuration: configuration)
        await withCheckedContinuation { continuation in
            finishers.append(continuation)
            if observers.isEmpty {
                starts.append(configuration)
            } else {
                observers.removeFirst().resume(returning: configuration)
            }
        }
        return result
    }

    func nextStarted() async -> ClearGlassConfiguration {
        if !starts.isEmpty { return starts.removeFirst() }
        return await withCheckedContinuation { observers.append($0) }
    }

    func finish() throws {
        try #require(!finishers.isEmpty)
        finishers.removeFirst().resume()
    }
}
