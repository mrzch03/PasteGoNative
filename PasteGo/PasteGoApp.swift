import SwiftUI

@main
struct PasteGoApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // The app's UI is hosted in a FloatingPanel managed by AppDelegate.
        // We use Settings as a required placeholder scene.
        Settings {
            EmptyView()
        }
    }
}
