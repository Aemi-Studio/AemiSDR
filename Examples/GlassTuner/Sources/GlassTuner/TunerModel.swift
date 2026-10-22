import AemiSDR
import Observation

#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

@MainActor @Observable
final class TunerModel {
    var settings = TunerSettings()
    private(set) var sourceImage: CGImage?
    private(set) var rendered: ClearGlassRenderedImage?
    private(set) var errorText: String?
    private(set) var scale: CGFloat = 2
    var isRendering: Bool { renderTask != nil }

    typealias RenderImage =
        @Sendable (CGImage, CGPoint, CGSize, CGFloat, ClearGlassConfiguration) async throws -> ClearGlassRenderedImage
    private let renderImage: RenderImage
    private let assets = TunerAssets()
    private var pending: Request?
    private var renderTask: Task<Void, Never>?
    private var generation: UInt64 = 0
    private var sourceEpoch: UInt64 = 0
    private var suspended = false
    private var sourcePattern: TunerPattern?

    init(renderImage: RenderImage? = nil, arguments: [String] = CommandLine.arguments) {
        let renderer = ClearGlassImageRenderer()
        self.renderImage =
            renderImage ?? { image, origin, size, scale, configuration in
                try await renderer.render(
                    source: image, origin: origin, size: size, scale: scale, configuration: configuration)
            }
        if let index = arguments.firstIndex(of: "--settings-json"), index + 1 < arguments.count {
            do { settings = try TunerSettings.decode(Data(arguments[index + 1].utf8)) } catch {
                errorText = error.localizedDescription
            }
        } else if let index = arguments.firstIndex(of: "--settings-base64"), index + 1 < arguments.count {
            if let data = Data(base64Encoded: arguments[index + 1]) {
                do { settings = try TunerSettings.decode(data) } catch {
                    errorText = error.localizedDescription
                }
            }
        }
    }

    struct SourceKey: Hashable {
        let pattern: TunerPattern
        let scale: CGFloat
    }

    private struct Request {
        let image: CGImage
        let configuration: ClearGlassConfiguration
        let origin: CGPoint
        let size: CGSize
        let scale: CGFloat
        let generation: UInt64
        let sourceEpoch: UInt64
    }

    func load(scale newScale: CGFloat) async {
        cancel()
        suspended = false
        sourceImage = nil
        rendered = nil
        errorText = nil
        guard newScale.isFinite, (0.25...4).contains(newScale) else {
            errorText = "Unsupported display scale."
            return
        }
        scale = newScale
        let pattern = settings.pattern
        let image = await assets.pattern(pattern, scale: newScale)
        guard !Task.isCancelled, pattern == settings.pattern, scale == newScale else { return }
        guard let image else {
            errorText = "Could not generate the background."
            return
        }
        sourceImage = image
        sourcePattern = pattern
        requestRender()
    }

    func requestRender() {
        guard !suspended, sourcePattern == settings.pattern, let sourceImage else { return }
        generation &+= 1
        pending = Request(
            image: sourceImage, configuration: settings.configuration, origin: settings.origin, size: settings.size,
            scale: scale, generation: generation, sourceEpoch: sourceEpoch)
        if renderTask == nil { startPump() }
    }

    private func startPump() {
        let renderImage = renderImage
        // One active render and one replaceable pending request: dragging never queues an unbounded frame backlog.
        renderTask = Task { [weak self, renderImage] in
            defer { self?.pumpFinished() }
            while !Task.isCancelled, let request = self?.takePending() {
                do {
                    let result = try await renderImage(
                        request.image, request.origin, request.size, request.scale, request.configuration)
                    guard !Task.isCancelled else { return }
                    self?.publish(result, sourceEpoch: request.sourceEpoch)
                } catch {
                    guard !Task.isCancelled else { return }
                    self?.publish(error, generation: request.generation)
                }
            }
        }
    }

    private func takePending() -> Request? {
        defer { pending = nil }
        return pending
    }

    private func publish(_ result: ClearGlassRenderedImage, sourceEpoch: UInt64) {
        // New controls may already be queued. Present this completed frame instead of starving throughout a drag.
        guard sourceEpoch == self.sourceEpoch, !suspended else { return }
        rendered = result
        errorText = nil
    }

    private func publish(_ error: Error, generation: UInt64) {
        guard generation == self.generation else { return }
        errorText = error.localizedDescription
    }

    private func pumpFinished() {
        renderTask = nil
        if !suspended, pending != nil { startPump() }
    }

    func cancel() {
        suspended = true
        sourceEpoch &+= 1
        generation &+= 1
        pending = nil
        renderTask?.cancel()
    }

    func copySettings() {
        do {
            let data = try settings.json()
            try copyToClipboard(String(decoding: data, as: UTF8.self))
            errorText = nil
        } catch { errorText = error.localizedDescription }
    }

    func copySwift() {
        do {
            try copyToClipboard(settings.swiftCode())
            errorText = nil
        } catch { errorText = error.localizedDescription }
    }

    private func copyToClipboard(_ text: String) throws {
        #if os(macOS)
            NSPasteboard.general.clearContents()
            guard NSPasteboard.general.setString(text, forType: .string) else { throw ClipboardError.unavailable }
        #else
            UIPasteboard.general.string = text
        #endif
    }

    private enum ClipboardError: Error { case unavailable }

    func pasteSettings() {
        #if os(macOS)
            let text = NSPasteboard.general.string(forType: .string)
        #else
            let text = UIPasteboard.general.string
        #endif
        guard let text else {
            errorText = "The clipboard contains no settings text."
            return
        }
        do {
            settings = try TunerSettings.decode(Data(text.utf8))
            errorText = nil
        } catch { errorText = error.localizedDescription }
    }
}
