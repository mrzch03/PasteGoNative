import SwiftUI

/// The app's navigation state
enum AppView {
    case history
    case generate
    case settings
}

/// Root view containing the titlebar and main content area
struct MainContentView: View {
    @State var viewMode: AppView = .history

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
                TitleBarView(viewMode: $viewMode)

                // Main content
                ZStack {
                    switch viewMode {
                    case .history:
                        HistoryView(
                            clipboardVM: clipboardVM,
                            pasteService: pasteService,
                            onStartGenerate: {
                                generateVM.reset()
                                viewMode = .generate
                            }
                        )
                        .transition(.opacity)

                    case .generate:
                        GenerateView(
                            generateVM: generateVM,
                            selectedItems: clipboardVM.getSelectedItems(),
                            onBack: { viewMode = .history },
                            onNavigateSettings: { viewMode = .settings }
                        )
                        .transition(.move(edge: .trailing).combined(with: .opacity))

                    case .settings:
                        SettingsView(settingsVM: settingsVM, onBack: { viewMode = .history })
                            .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: viewMode)
            }
        }
        .frame(width: Constants.windowWidth, height: Constants.windowHeight)
        .onKeyPress(.escape) {
            if viewMode != .history {
                withAnimation { viewMode = .history }
                return .handled
            }
            return .ignored
        }
    }
}

/// Custom title bar with close button and navigation
struct TitleBarView: View {
    @Binding var viewMode: AppView

    var body: some View {
        HStack(spacing: 8) {
            // Close button (red circle like macOS)
            Button {
                NSApp.keyWindow?.orderOut(nil)
            } label: {
                Circle()
                    .fill(Color.red.opacity(0.8))
                    .frame(width: 12, height: 12)
                    .overlay {
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.black.opacity(0.5))
                    }
            }
            .buttonStyle(.plain)

            Text("PasteGo")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)

            Spacer()

            // Navigation buttons
            HStack(spacing: 4) {
                navButton(icon: "list.clipboard", view: .history)
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
                viewMode = view
            }
        } label: {
            Image(systemName: icon)
                .font(.system(size: 13))
                .foregroundStyle(viewMode == view ? Color.accentColor : .secondary)
                .frame(width: 28, height: 28)
                .background(viewMode == view ? Color.accentColor.opacity(0.12) : .clear)
                .clipShape(RoundedRectangle(cornerRadius: 6))
        }
        .buttonStyle(.plain)
    }
}
