import CoreGraphics
import Testing

@testable import AemiSDR

@Suite("Glass shape owns its path snapshot")
struct GlassShapeOwnershipTests {
    @Test func `mutating a caller path does not change a previously constructed shape`() {
        let input = CGMutablePath()
        input.addRect(CGRect(x: 3, y: 5, width: 30, height: 40))
        let shape = GlassShape.path(input)
        let expected = GlassShape.path(CGPath(rect: CGRect(x: 3, y: 5, width: 30, height: 40), transform: nil))
        #expect(shape == expected)
        input.addRect(CGRect(x: 90, y: 90, width: 10, height: 10))
        #expect(shape == expected)
    }

    @Test func `exporting a path cannot expose mutable snapshot storage`() throws {
        let shape = GlassShape.path(CGPath(rect: CGRect(x: 1, y: 2, width: 20, height: 30), transform: nil))
        let expected = shape
        guard case .path(let snapshot) = shape else {
            Issue.record("expected a path")
            return
        }
        let exported = snapshot.copyCGPath()
        exported.addRect(CGRect(x: 80, y: 80, width: 10, height: 10))
        #expect(shape == expected)
        #expect(snapshot.copyCGPath().boundingBox == CGRect(x: 1, y: 2, width: 20, height: 30))
    }
}
