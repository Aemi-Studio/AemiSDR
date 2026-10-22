import AemiSDR
import Foundation
import Testing

@testable import GlassTuner

struct TunerSettingsTests {
    @Test(arguments: TunerShape.allCases)
    func `export and import preserve the complete configuration`(shape: TunerShape) throws {
        var settings = TunerSettings()
        settings.shape = shape
        settings.perCorner = true
        settings.topLeft = 0
        settings.bottomRight = 95
        settings.blur = .optical
        settings.edgeClarity = 0.7
        settings.veilBlue = 0.2
        settings.aberration = 0.07
        let decoded = try TunerSettings.decode(settings.json())
        #expect(decoded == settings)
        #expect(decoded.configuration == settings.configuration)
        #expect(decoded.size == settings.size)
    }

    @Test func `default tuning does not enable chromatic aberration`() {
        #expect(TunerSettings().configuration.chromatic == 0)
    }

    @Test func `removing the veil preserves refraction and blur`() {
        var settings = TunerSettings()
        let original = settings.configuration
        settings.veil = false
        #expect(settings.configuration.lift == 0)
        #expect(settings.configuration.rim == original.rim)
        #expect(settings.configuration.blur == original.blur)
    }

    @Test func `edge clarity preserves the interior kernel weights`() {
        var settings = TunerSettings()
        let original = settings.configuration.blur
        settings.edgeClarity = 1
        let result = settings.configuration.blur
        #expect(result.components.dropFirst().map(\.innerWeight) == original.components.map(\.innerWeight))
        #expect(result.components[0].edgeWeight == 1)
        #expect(result.components[0].innerWeight == 0)
    }

    @Test func `invalid exported geometry and nonfinite values are rejected`() {
        var settings = TunerSettings()
        settings.width = 1e20
        #expect(throws: (any Error).self) { try settings.json() }
        settings.width = .nan
        #expect(throws: (any Error).self) { try settings.json() }
    }

    @Test func `oversized settings and unsupported versions are rejected`() throws {
        #expect(throws: (any Error).self) { try TunerSettings.decode(Data(repeating: 32, count: 65_537)) }
        var settings = TunerSettings()
        settings.version = 2
        #expect(throws: (any Error).self) { try settings.validated() }
    }
}
