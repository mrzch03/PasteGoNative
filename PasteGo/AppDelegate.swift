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
    private(set) var appVM: AppViewModel!
    private(set) var clipboardVM: ClipboardViewModel!
    private(set) var generateVM: GenerateViewModel!
    private(set) var settingsVM: SettingsViewModel!
    private(set) var pasteService: PasteService!
    private var suppressHideOnDeactivate = false

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
        appVM = AppViewModel()
        appVM.refreshAccessibilityPermission()
        appVM.onTriggerQuickAction = { [weak self] templateId in
            self?.handleTemplateShortcut(templateId: templateId)
        }
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
            appVM: appVM,
            clipboardVM: clipboardVM,
            generateVM: generateVM,
            settingsVM: settingsVM,
            pasteService: pasteService
        )

        panel.contentView = NSHostingView(rootView: contentView)
        windowManager.setPanel(panel)
        panel.hidesOnDeactivate = !appVM.isPinnedOnScreen
        appVM.onPinStateChanged = { [weak self] isPinnedOnScreen in
            self?.panel?.hidesOnDeactivate = !isPinnedOnScreen
        }

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
        settingsVM.onProvidersChanged = { [weak self] in
            self?.generateVM.fetchProviders()
        }
        settingsVM.onProviderSaved = { [weak self] in
            self?.appVM.viewMode = .generate
        }

        // Setup system tray
        setupStatusItem()

        // Clean up old clips on launch
        clipboardVM.clearOldClips(keepDays: 30)
    }

    // MARK: - Template Shortcut Handler

    private func handleTemplateShortcut(templateId: String) {
        let wasVisible = windowManager.isVisible
        let sourceApp = activeSourceApplication()
        suppressHideOnDeactivate = true

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            self.captureTemplateSourceText(preferredApp: sourceApp) { [weak self] result in
                self?.presentTemplateResult(
                    templateId: templateId,
                    result: result,
                    wasVisible: wasVisible
                )
            }
        }
    }

    private func captureTemplateSourceText(
        preferredApp: NSRunningApplication?,
        completion: @escaping (AccessibilitySelectionReader.Result) -> Void
    ) {
        guard let preferredApp else {
            completion(.init(text: nil, diagnostics: ["No source application"]))
            return
        }

        let pasteboard = NSPasteboard.general
        let originalSnapshot = PasteboardSnapshot.capture(from: pasteboard)
        let originalChangeCount = pasteboard.changeCount

        clipboardMonitor.suppressNextChanges(2)
        preferredApp.activate()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            PasteService.simulateCmdC()
        }

        pollForCopiedText(
            originalChangeCount: originalChangeCount,
            attemptsRemaining: 8,
            originalSnapshot: originalSnapshot,
            preferredApp: preferredApp,
            completion: completion
        )
    }

    private func pollForCopiedText(
        originalChangeCount: Int,
        attemptsRemaining: Int,
        originalSnapshot: PasteboardSnapshot,
        preferredApp: NSRunningApplication,
        completion: @escaping (AccessibilitySelectionReader.Result) -> Void
    ) {
        let pasteboard = NSPasteboard.general
        let currentText = pasteboard.string(forType: .string)?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if pasteboard.changeCount != originalChangeCount,
           let currentText,
           !currentText.isEmpty {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.clipboardMonitor.suppressNextChanges(1)
                originalSnapshot.restore(to: pasteboard)
            }

            completion(.init(
                text: currentText,
                diagnostics: ["App=\(preferredApp.localizedName ?? "<unknown>")", "Cmd+C capture hit"]
            ))
            return
        }

        guard attemptsRemaining > 0 else {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                self.clipboardMonitor.suppressNextChanges(1)
                originalSnapshot.restore(to: pasteboard)
            }

            completion(.init(
                text: nil,
                diagnostics: ["App=\(preferredApp.localizedName ?? "<unknown>")", "Cmd+C capture miss"]
            ))
            return
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            self.pollForCopiedText(
                originalChangeCount: originalChangeCount,
                attemptsRemaining: attemptsRemaining - 1,
                originalSnapshot: originalSnapshot,
                preferredApp: preferredApp,
                completion: completion
            )
        }
    }

    private func presentTemplateResult(
        templateId: String,
        result: AccessibilitySelectionReader.Result,
        wasVisible: Bool
    ) {
        if wasVisible {
            windowManager.showPreservingFrame()
        } else {
            windowManager.showPreservingFrame()
        }

        suppressHideOnDeactivate = false

        let template = generateVM.templates.first { $0.id == templateId }

        appVM.viewMode = .generate
        generateVM.resetShortcuts()
        generateVM.activeTemplateId = templateId
        generateVM.isCustomMode = false
        let text = result.text ?? ""

        if text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            generateVM.setQuickActionSource(text: "")
            generateVM.setShortcutError("未检测到选中文字。")
        } else if let template {
            generateVM.setQuickActionSource(text: text)
            let items = [ClipItem(
                content: text,
                contentHash: UUID().uuidString,
                clipType: ContentTypeDetector.detect(text)
            )]
            generateVM.generate(items: items, template: template, customPrompt: "")
        }
    }

    // MARK: - System Tray

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            button.image = makeStatusBarIcon()
            button.imageScaling = .scaleProportionallyDown
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

    private func makeStatusBarIcon() -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.isTemplate = true
        image.lockFocus()

        NSColor.labelColor.setStroke()

        let transform = NSAffineTransform()
        transform.translateX(by: 0.0, yBy: 0.6)
        transform.scaleX(by: 18.0 / 22.0, yBy: 18.0 / 22.0)

        let bowl = NSBezierPath()
        bowl.move(to: NSPoint(x: 5.0, y: 2.5))
        bowl.line(to: NSPoint(x: 7.1, y: 2.5))
        bowl.curve(to: NSPoint(x: 8.5, y: 3.9), controlPoint1: NSPoint(x: 7.87, y: 2.5), controlPoint2: NSPoint(x: 8.5, y: 3.13))
        bowl.line(to: NSPoint(x: 8.5, y: 5.8))
        bowl.line(to: NSPoint(x: 11.8, y: 5.8))
        bowl.curve(to: NSPoint(x: 17.0, y: 10.3), controlPoint1: NSPoint(x: 15.16, y: 5.8), controlPoint2: NSPoint(x: 17.0, y: 7.64))
        bowl.curve(to: NSPoint(x: 11.8, y: 15.2), controlPoint1: NSPoint(x: 17.0, y: 13.26), controlPoint2: NSPoint(x: 14.91, y: 15.2))
        bowl.line(to: NSPoint(x: 8.5, y: 15.2))
        bowl.line(to: NSPoint(x: 8.5, y: 16.1))
        bowl.curve(to: NSPoint(x: 7.1, y: 17.5), controlPoint1: NSPoint(x: 8.5, y: 16.87), controlPoint2: NSPoint(x: 7.87, y: 17.5))
        bowl.line(to: NSPoint(x: 5.0, y: 17.5))
        bowl.curve(to: NSPoint(x: 3.6, y: 16.1), controlPoint1: NSPoint(x: 4.23, y: 17.5), controlPoint2: NSPoint(x: 3.6, y: 16.87))
        bowl.line(to: NSPoint(x: 3.6, y: 3.9))
        bowl.curve(to: NSPoint(x: 5.0, y: 2.5), controlPoint1: NSPoint(x: 3.6, y: 3.13), controlPoint2: NSPoint(x: 4.23, y: 2.5))
        bowl.lineWidth = 1.8
        bowl.lineJoinStyle = .round
        bowl.transform(using: transform as AffineTransform)
        bowl.stroke()

        let slash = NSBezierPath()
        slash.move(to: NSPoint(x: 11.7, y: 11.3))
        slash.line(to: NSPoint(x: 14.9, y: 14.0))
        slash.lineWidth = 1.8
        slash.lineCapStyle = .round
        slash.transform(using: transform as AffineTransform)
        slash.stroke()

        image.unlockFocus()
        return image
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

    func applicationDidResignActive(_ notification: Notification) {
        windowManager?.captureCurrentFrontmostApp()
        if suppressHideOnDeactivate {
            return
        }
        if !(appVM?.isPinnedOnScreen ?? false) {
            windowManager?.hide()
        }
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        appVM?.refreshAccessibilityPermission()
    }

    private func activeSourceApplication() -> NSRunningApplication? {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
            return frontmost
        }

        if let capturedApp = windowManager.capturedFrontmostApp,
           capturedApp.bundleIdentifier != Bundle.main.bundleIdentifier {
            return capturedApp
        }

        return nil
    }
}
