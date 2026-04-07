import AppKit
import SwiftUI

/// App delegate managing the system tray, floating panel, and core services
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private var panel: FloatingPanel!
    private var windowManager: WindowManager!
    private var clipboardMonitor: ClipboardMonitor!
    private var hotkeyManager: HotkeyManager!

    // Core data
    private var databaseManager: DatabaseManager!
    private var clipRepo: ClipRepository!
    private var providerRepo: ProviderRepository!
    private var templateRepo: TemplateRepository!

    // View models (shared across views)
    private(set) var clipboardVM: ClipboardViewModel!
    private(set) var generateVM: GenerateViewModel!
    private(set) var settingsVM: SettingsViewModel!
    private(set) var pasteService: PasteService!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Agent mode: hide from Dock
        NSApp.setActivationPolicy(.accessory)

        // Initialize database
        do {
            databaseManager = try DatabaseManager()
        } catch {
            fatalError("Failed to initialize database: \(error)")
        }

        // Repositories
        clipRepo = ClipRepository(db: databaseManager)
        providerRepo = ProviderRepository(db: databaseManager)
        templateRepo = TemplateRepository(db: databaseManager)

        // Window manager
        windowManager = WindowManager()

        // Paste service
        pasteService = PasteService(windowManager: windowManager)

        // View models
        clipboardVM = ClipboardViewModel(clipRepo: clipRepo)
        generateVM = GenerateViewModel(templateRepo: templateRepo, providerRepo: providerRepo)
        settingsVM = SettingsViewModel(providerRepo: providerRepo, templateRepo: templateRepo)

        // Load initial data
        clipboardVM.fetchClips()
        generateVM.fetchTemplates()
        generateVM.fetchProviders()
        settingsVM.fetchAll()

        // Create floating panel
        panel = FloatingPanel(contentRect: NSRect(
            x: 0, y: 0,
            width: Constants.windowWidth,
            height: Constants.windowHeight
        ))

        // Host SwiftUI content in the panel
        let contentView = MainContentView(
            clipboardVM: clipboardVM,
            generateVM: generateVM,
            settingsVM: settingsVM,
            pasteService: pasteService
        )

        panel.contentView = NSHostingView(rootView: contentView)
        windowManager.setPanel(panel)

        // Start clipboard monitor
        clipboardMonitor = ClipboardMonitor(clipRepo: clipRepo)
        clipboardMonitor.onNewClip = { [weak self] _ in
            self?.clipboardVM.fetchClips()
        }
        clipboardMonitor.start()

        // Setup hotkeys
        hotkeyManager = HotkeyManager()
        hotkeyManager.onToggle = { [weak self] in
            self?.windowManager.toggle()
        }
        hotkeyManager.onTemplateShortcut = { [weak self] templateId in
            self?.handleTemplateShortcut(templateId: templateId)
        }
        hotkeyManager.registerToggle()
        hotkeyManager.registerTemplateShortcuts(settingsVM.templates)

        // Re-register shortcuts when templates change
        settingsVM.onTemplatesChanged = { [weak self] in
            guard let self else { return }
            self.hotkeyManager.registerTemplateShortcuts(self.settingsVM.templates)
            self.generateVM.fetchTemplates()
        }

        // Setup system tray
        setupStatusItem()

        // Clean up old clips on launch
        clipboardVM.clearOldClips(keepDays: 30)
    }

    // MARK: - Template Shortcut Handler

    private func handleTemplateShortcut(templateId: String) {
        // Hide window so target app regains focus
        windowManager.hide()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self else { return }

            // Simulate Cmd+C to copy selection
            PasteService.simulateCmdC()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self else { return }

                // Read clipboard
                let text = NSPasteboard.general.string(forType: .string) ?? ""

                // Show window
                self.windowManager.show()

                // Find template and generate
                let template = self.generateVM.templates.first { $0.id == templateId }

                let virtualItem = ClipItem(
                    id: "quick-template",
                    content: text,
                    contentHash: ""
                )

                self.generateVM.reset()

                if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    self.generateVM.error = "剪贴板为空，请先复制一些文本"
                } else if let template {
                    self.generateVM.generate(items: [virtualItem], template: template, customPrompt: "")
                }

                // Switch to generate view
                if let hostingView = self.panel.contentView as? NSHostingView<MainContentView> {
                    // The view model state change triggers the view update
                    _ = hostingView
                }
            }
        }
    }

    // MARK: - System Tray

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clipboard", accessibilityDescription: "PasteGo")
            button.image?.size = NSSize(width: 16, height: 16)
            button.action = #selector(statusItemClicked)
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let menu = NSMenu()
        menu.addItem(withTitle: "显示 PasteGo  \u{2318}\u{21E7}V", action: #selector(showPanel), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "退出", action: #selector(quitApp), keyEquivalent: "q")

        statusItem.menu = nil // We handle clicks manually
    }

    @objc private func statusItemClicked() {
        guard let event = NSApp.currentEvent else { return }

        if event.type == .rightMouseUp {
            // Show context menu on right click
            let menu = NSMenu()
            menu.addItem(withTitle: "显示 PasteGo", action: #selector(showPanel), keyEquivalent: "")
            menu.addItem(.separator())
            menu.addItem(withTitle: "退出", action: #selector(quitApp), keyEquivalent: "")
            statusItem.menu = menu
            statusItem.button?.performClick(nil)
            statusItem.menu = nil // Reset so left click works again
        } else {
            // Toggle on left click
            windowManager.toggle()
        }
    }

    @objc private func showPanel() {
        windowManager.show()
    }

    @objc private func quitApp() {
        clipboardMonitor.stop()
        NSApp.terminate(nil)
    }

    func applicationWillTerminate(_ notification: Notification) {
        clipboardMonitor?.stop()
    }
}
