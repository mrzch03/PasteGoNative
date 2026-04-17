import SwiftUI

/// The app's navigation state
enum AppView {
    case history
    case generate
    case settings
}

/// Root view containing the titlebar and main content area
struct MainContentView: View {
    let appVM: AppViewModel
    let clipboardVM: ClipboardViewModel
    let generateVM: GenerateViewModel
    let settingsVM: SettingsViewModel
    let pasteService: PasteService

    var body: some View {
        ZStack {
            // Background vibrancy
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Title bar
                TitleBarView(appVM: appVM)

                if !appVM.hasAccessibilityPermission {
                    AccessibilityPermissionBanner(appVM: appVM)
                }

                // Main content
                ZStack {
                    switch appVM.viewMode {
                    case .history:
                        HistoryView(
                            clipboardVM: clipboardVM,
                            pasteService: pasteService,
                            onStartGenerate: {
                                generateVM.prepareWorkbench()
                                generateVM.resetWorkbench()
                                appVM.viewMode = .generate
                            }
                        )
                        .transition(.opacity)

                    case .generate:
                        GenerateView(
                            generateVM: generateVM,
                            selectedItems: clipboardVM.getSelectedItems(),
                            onRemoveMaterial: { clipboardVM.deselect($0) },
                            onNavigateSettings: { appVM.viewMode = .settings }
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))

                    case .settings:
                        SettingsView(settingsVM: settingsVM, onBack: { appVM.viewMode = .history })
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: appVM.viewMode)
            }
        }
        .frame(width: Constants.windowWidth, height: Constants.windowHeight)
        .onKeyPress(.escape) {
            if appVM.viewMode != .history {
                withAnimation { appVM.viewMode = .history }
                return .handled
            }
            return .ignored
        }
    }
}

struct AccessibilityPermissionBanner: View {
    let appVM: AppViewModel

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "hand.raised.fill")
                .font(.system(size: 13))
                .foregroundStyle(.orange)

            Text("未开启“辅助功能”权限，选中文本翻译和自动粘贴可能无法工作。")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            Button("去开启") {
                appVM.openAccessibilitySettings()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(Color.accentColor)

            Button("刷新") {
                appVM.refreshAccessibilityPermission()
            }
            .buttonStyle(.plain)
            .font(.system(size: 11, weight: .semibold))
            .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .background(Color.orange.opacity(0.08))
        .overlay(alignment: .bottom) {
            Divider().opacity(0.35)
        }
    }
}

/// Custom title bar with close button and navigation
struct TitleBarView: View {
    let appVM: AppViewModel

    var body: some View {
        HStack(spacing: 8) {
            HStack(spacing: 8) {
                if let brandMark = BrandAssets.brandMark {
                    Image(nsImage: brandMark)
                        .resizable()
                        .interpolation(.high)
                        .frame(width: 24, height: 24)
                }

                Text("PasteGo")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            Spacer()

            // Navigation buttons
            HStack(spacing: 4) {
                pinButton
                navButton(icon: "list.clipboard") {
                    appVM.viewMode = .history
                }
                navButton(icon: "sparkles", view: .generate)
                navButton(icon: "gearshape", view: .settings)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }

    @ViewBuilder
    private func navButton(icon: String, view: AppView) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                appVM.viewMode = view
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(appVM.viewMode == view ? Color.accentColor : .secondary)
                .frame(width: 28, height: 28)
                .background(appVM.viewMode == view ? Color.accentColor.opacity(0.12) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func navButton(icon: String, action: @escaping () -> Void) -> some View {
        Button {
            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                action()
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(iconIsActive(icon) ? Color.accentColor : .secondary)
                .frame(width: 28, height: 28)
                .background(iconIsActive(icon) ? Color.accentColor.opacity(0.12) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }

    private var pinButton: some View {
        Button {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                appVM.isPinnedOnScreen.toggle()
            }
        } label: {
            Image(systemName: appVM.isPinnedOnScreen ? "pin.fill" : "pin.slash")
                .font(.system(size: 13))
                .foregroundStyle(appVM.isPinnedOnScreen ? Color.accentColor : .secondary)
                .frame(width: 28, height: 28)
                .background(appVM.isPinnedOnScreen ? Color.accentColor.opacity(0.12) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
        .help(appVM.isPinnedOnScreen ? "已钉在屏幕上" : "未钉在屏幕上")
    }

    private func iconIsActive(_ icon: String) -> Bool {
        switch icon {
        case "list.clipboard":
            appVM.viewMode == .history
        case "sparkles":
            appVM.viewMode == .generate
        case "gearshape":
            appVM.viewMode == .settings
        default:
            false
        }
    }
}
