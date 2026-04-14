import AppKit
import CoreGraphics

/// Manages the floating panel: show/hide/toggle and position near mouse cursor
@MainActor
final class WindowManager {
    private(set) var panel: FloatingPanel?
    private var previousApp: NSRunningApplication?
    private var hasPositionedPanel = false
    var isVisible: Bool { panel?.isVisible ?? false }
    var capturedFrontmostApp: NSRunningApplication? { previousApp }

    func setPanel(_ panel: FloatingPanel) {
        self.panel = panel
    }

    /// Save the currently frontmost app before showing our panel
    func savePreviousApp() {
        previousApp = NSWorkspace.shared.frontmostApplication
    }

    func captureCurrentFrontmostApp() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
            previousApp = frontmost
        }
    }

    /// Reactivate the previously saved frontmost app
    func reactivatePreviousApp() {
        previousApp?.activate()
    }

    /// Show the panel near the mouse, saving previous app first
    func show() {
        guard let panel else { return }
        savePreviousApp()
        if !hasPositionedPanel {
            positionNearMouse()
            hasPositionedPanel = true
        }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Bring the existing panel to the front without repositioning or overwriting previous app state
    func focusVisiblePanel() {
        guard let panel, panel.isVisible else { return }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Show the panel without moving it or overwriting previous app state
    func showPreservingFrame() {
        guard let panel else { return }
        panel.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    /// Show the panel at its current frame without activating the app
    func showWithoutActivation() {
        guard let panel else { return }
        if !hasPositionedPanel {
            positionNearMouse()
            hasPositionedPanel = true
        }
        panel.orderFrontRegardless()
    }

    /// Hide the panel
    func hide() {
        panel?.orderOut(nil)
    }

    /// Toggle panel visibility
    func toggle() {
        guard let panel else { return }
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    /// Position the panel near the current mouse cursor, staying within screen bounds
    func positionNearMouse() {
        guard let panel else { return }

        let mouseLocation = NSEvent.mouseLocation
        let panelSize = panel.frame.size

        // Find the screen containing the mouse
        let screen = NSScreen.screens.first { NSMouseInRect(mouseLocation, $0.frame, false) }
            ?? NSScreen.main ?? NSScreen.screens.first

        guard let screenFrame = screen?.visibleFrame else { return }

        let offset: CGFloat = 10

        // Start at mouse position with offset
        var x = mouseLocation.x + offset
        // NSScreen y is flipped (0 = bottom), mouse location is in screen coords
        var y = mouseLocation.y - panelSize.height - offset

        // Ensure within screen bounds
        if x + panelSize.width > screenFrame.maxX {
            x = mouseLocation.x - panelSize.width - offset
        }
        if y < screenFrame.minY {
            y = mouseLocation.y + offset
        }
        if x < screenFrame.minX {
            x = screenFrame.minX
        }
        if y + panelSize.height > screenFrame.maxY {
            y = screenFrame.maxY - panelSize.height
        }

        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
