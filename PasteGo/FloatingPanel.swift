import AppKit

/// Custom NSPanel for the floating clipboard window.
/// Behaves like a utility panel: floats above other windows, can become key (for keyboard input),
/// but never becomes main window. Visible on all Spaces.
final class FloatingPanel: NSPanel {
    init(contentRect: NSRect) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .closable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Floating behavior
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        // Transparent titlebar
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = true

        // Transparent background (SwiftUI provides the materials)
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true

        // Animation
        animationBehavior = .utilityWindow

        // Round corners
        if let contentView {
            contentView.wantsLayer = true
            contentView.layer?.cornerRadius = 12
            contentView.layer?.masksToBounds = true
        }
    }

    // Allow keyboard input (search, chat)
    override var canBecomeKey: Bool { true }

    // Never become main window
    override var canBecomeMain: Bool { false }

    // Close = hide, not terminate
    override func close() {
        orderOut(nil)
    }
}
