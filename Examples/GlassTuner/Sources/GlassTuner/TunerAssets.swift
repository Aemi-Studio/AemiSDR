import CoreGraphics
import Dispatch

/// CPU pattern generation runs away from the UI. A dedicated executor can also serve future image-file exports.
actor TunerAssets {
    private nonisolated let executor = DispatchSerialQueue(label: "studio.aemi.GlassTuner.assets", qos: .userInitiated)
    nonisolated var unownedExecutor: UnownedSerialExecutor { executor.asUnownedSerialExecutor() }

    func pattern(_ pattern: TunerPattern, scale: CGFloat) -> CGImage? {
        guard !Task.isCancelled else { return nil }
        return LabBackground.image(
            named: pattern.rawValue, width: Int(TunerSettings.canvasSize.width * scale),
            height: Int(TunerSettings.canvasSize.height * scale))
    }
}
