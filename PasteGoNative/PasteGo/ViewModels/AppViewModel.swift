import AppKit
import ApplicationServices
import Foundation

/// Shared app navigation state so services can switch the active panel view
@Observable
final class AppViewModel {
    var viewMode: AppView = .history
    var hasAccessibilityPermission = AXIsProcessTrusted()
    var isPinnedOnScreen = false {
        didSet {
            onPinStateChanged?(isPinnedOnScreen)
        }
    }
    var onPinStateChanged: ((Bool) -> Void)?
    var onTriggerQuickAction: ((String) -> Void)?

    func refreshAccessibilityPermission() {
        hasAccessibilityPermission = AXIsProcessTrusted()
    }

    func openAccessibilitySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func triggerQuickAction(templateId: String) {
        onTriggerQuickAction?(templateId)
    }
}
