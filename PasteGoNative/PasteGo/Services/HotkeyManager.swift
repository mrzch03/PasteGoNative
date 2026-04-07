import Carbon
import AppKit
import HotKey

/// Manages global keyboard shortcuts for the app
@MainActor
final class HotkeyManager {
    private var toggleHotKey: HotKey?
    private var templateHotKeys: [String: HotKey] = [:]

    var onToggle: (() -> Void)?
    var onTemplateShortcut: ((String) -> Void)?

    /// Register the main toggle shortcut (Cmd+Shift+V)
    func registerToggle() {
        toggleHotKey = HotKey(key: .v, modifiers: [.command, .shift])
        toggleHotKey?.keyDownHandler = { [weak self] in
            self?.onToggle?()
        }
    }

    /// Register shortcuts for all templates that have a shortcut defined
    func registerTemplateShortcuts(_ templates: [Template]) {
        // Remove old template hotkeys
        templateHotKeys.removeAll()

        for template in templates {
            guard let shortcutStr = template.shortcut, !shortcutStr.isEmpty else { continue }
            guard let hotKey = parseShortcut(shortcutStr) else { continue }

            let templateId = template.id
            hotKey.keyDownHandler = { [weak self] in
                self?.onTemplateShortcut?(templateId)
            }
            templateHotKeys[template.id] = hotKey
        }
    }

    /// Parse a shortcut string like "cmd+shift+t" into a HotKey
    private func parseShortcut(_ str: String) -> HotKey? {
        let parts = str.lowercased()
            .replacingOccurrences(of: "cmdorctrl", with: "cmd")
            .split(separator: "+")
            .map { $0.trimmingCharacters(in: .whitespaces) }

        var modifiers: NSEvent.ModifierFlags = []
        var keyStr = ""

        for part in parts {
            switch part {
            case "cmd", "command": modifiers.insert(.command)
            case "shift": modifiers.insert(.shift)
            case "alt", "option": modifiers.insert(.option)
            case "ctrl", "control": modifiers.insert(.control)
            default: keyStr = part
            }
        }

        guard !keyStr.isEmpty else { return nil }
        guard let key = keyFromString(keyStr) else { return nil }

        return HotKey(key: key, modifiers: modifiers)
    }

    /// Map a key string to a Key enum value
    private func keyFromString(_ str: String) -> Key? {
        // Single character keys
        if str.count == 1, let char = str.first {
            switch char {
            case "a": return .a; case "b": return .b; case "c": return .c
            case "d": return .d; case "e": return .e; case "f": return .f
            case "g": return .g; case "h": return .h; case "i": return .i
            case "j": return .j; case "k": return .k; case "l": return .l
            case "m": return .m; case "n": return .n; case "o": return .o
            case "p": return .p; case "q": return .q; case "r": return .r
            case "s": return .s; case "t": return .t; case "u": return .u
            case "v": return .v; case "w": return .w; case "x": return .x
            case "y": return .y; case "z": return .z
            case "0": return .zero; case "1": return .one; case "2": return .two
            case "3": return .three; case "4": return .four; case "5": return .five
            case "6": return .six; case "7": return .seven; case "8": return .eight
            case "9": return .nine
            default: return nil
            }
        }
        // Named keys
        switch str {
        case "space": return .space
        case "return", "enter": return .return
        case "backspace": return .delete
        case "delete": return .forwardDelete
        case "up": return .upArrow
        case "down": return .downArrow
        case "left": return .leftArrow
        case "right": return .rightArrow
        default: return nil
        }
    }
}
