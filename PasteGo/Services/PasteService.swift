import AppKit
import CoreGraphics

/// Handles writing to the system pasteboard and simulating keyboard shortcuts
@MainActor
final class PasteService {
    private let windowManager: WindowManager

    init(windowManager: WindowManager) {
        self.windowManager = windowManager
    }

    /// Copy content to pasteboard, hide window, switch to previous app, simulate Cmd+V
    func copyAndPaste(content: String) {
        // Write to system pasteboard
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(content, forType: .string)

        // Hide panel
        windowManager.hide()

        // Reactivate previous app and paste
        windowManager.reactivatePreviousApp()

        // Delay to allow app activation, then simulate Cmd+V
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            Self.simulateCmdV()
        }
    }

    /// Simulate Cmd+V keypress via CGEvent
    static func simulateCmdV() {
        let keyV: CGKeyCode = 0x09 // 'V' key code

        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)
        else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }

    /// Simulate Cmd+C keypress via CGEvent
    static func simulateCmdC() {
        let keyC: CGKeyCode = 0x08 // 'C' key code

        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        guard let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: true),
              let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyC, keyDown: false)
        else { return }

        keyDown.flags = .maskCommand
        keyUp.flags = .maskCommand

        keyDown.post(tap: .cghidEventTap)
        keyUp.post(tap: .cghidEventTap)
    }
}
