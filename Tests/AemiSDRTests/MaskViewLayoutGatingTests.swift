#if os(iOS)
    import Testing
    import UIKit

    @testable import AemiSDR

    @MainActor
    @Suite("Mask views layout gating and filter assignment")
    struct MaskViewLayoutGatingTests {
        @Test func `variable blur does no filter reassignments on unchanged layout`() throws {
            let view = VariableBlurUIView(maxBlurRadius: 15, maskType: .linearTopToBottom)
            view.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
            view.layoutSubviews()
            let initialAssignments = view.filterAssignmentCount
            #expect(initialAssignments > 0, "initial layout must install filter")

            for _ in 0..<100 {
                view.layoutSubviews()
            }
            #expect(
                view.filterAssignmentCount == initialAssignments,
                "100 unchanged layoutSubviews() must not reassign filters (got \(view.filterAssignmentCount) vs \(initialAssignments))"
            )

            // Resizing the view must trigger a mask update for the new dimensions.
            view.frame = CGRect(x: 0, y: 0, width: 220, height: 110)
            view.layoutSubviews()
            #expect(
                view.filterAssignmentCount == initialAssignments,
                "cache hit on size change should not reassign filter array")
        }

        @Test func `alpha mask does not reapply mask on unchanged layout`() async throws {
            let view = AlphaMaskUIView(maskType: .linearTopToBottom)
            view.frame = CGRect(x: 0, y: 0, width: 200, height: 100)
            view.layoutSubviews()
            let initialApplications = view.maskApplicationCount
            #expect(initialApplications > 0, "initial layout must apply mask")

            for _ in 0..<100 {
                view.layoutSubviews()
            }
            #expect(
                view.maskApplicationCount == initialApplications,
                "100 unchanged layoutSubviews() must not reapply mask (got \(view.maskApplicationCount) vs \(initialApplications))"
            )

            // Resizing triggers background generation, then applies on main.
            view.frame = CGRect(x: 0, y: 0, width: 250, height: 120)
            view.layoutSubviews()

            for _ in 0..<50 {
                if view.maskApplicationCount > initialApplications { break }
                try await Task.sleep(for: .milliseconds(20))
            }
            #expect(view.maskApplicationCount > initialApplications, "resizing must apply mask with new dimensions")
        }
    }
#endif
