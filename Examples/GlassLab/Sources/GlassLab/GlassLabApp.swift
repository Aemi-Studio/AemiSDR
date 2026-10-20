import SwiftUI

@main
struct GlassLabApp: App {
    var body: some Scene {
        WindowGroup {
            LabHost().ignoresSafeArea().statusBarHidden()
        }
    }
}

struct LabHost: UIViewControllerRepresentable {
    func makeUIViewController(context _: Context) -> LabViewController {
        LabViewController(arguments: LabArguments(ProcessInfo.processInfo.arguments))
    }

    func updateUIViewController(_: LabViewController, context _: Context) {}
}
