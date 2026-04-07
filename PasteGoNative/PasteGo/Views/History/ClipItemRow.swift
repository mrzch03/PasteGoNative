import SwiftUI

/// A single clipboard item row with 3 zones: select | body | actions
struct ClipItemRow: View {
    let clip: ClipItem
    let isSelected: Bool
    let isFocused: Bool
    let isExpanded: Bool
    var onToggleSelect: () -> Void
    var onCopyAndPaste: () -> Void
    var onTogglePin: () -> Void
    var onDelete: () -> Void
    var onToggleExpand: () -> Void
    var onPreviewImage: () -> Void

    @State private var isHovering = false

    var body: some View {
        HStack(spacing: 0) {
            // Select zone
            selectZone

            // Body zone (click to paste)
            bodyZone

            // Action buttons zone
            actionsZone
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(rowBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 8)
        .onHover { isHovering = $0 }
        .animation(.easeInOut(duration: 0.12), value: isHovering)
        .animation(.easeInOut(duration: 0.12), value: isSelected)
    }

    // MARK: - Select Zone

    private var selectZone: some View {
        Button(action: onToggleSelect) {
            ZStack {
                RoundedRectangle(cornerRadius: 4)
                    .strokeBorder(isSelected ? Color.accentColor : Color.secondary.opacity(0.3), lineWidth: 1.5)
                    .frame(width: 18, height: 18)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(isSelected ? Color.accentColor : .clear)
                    )

                if isSelected {
                    Image(systemName: "checkmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.white)
                }
            }
        }
        .buttonStyle(.plain)
        .padding(.trailing, 10)
    }

    // MARK: - Body Zone

    private var bodyZone: some View {
        Button(action: onCopyAndPaste) {
            VStack(alignment: .leading, spacing: 4) {
                // Meta row: type badge + source app + time + pin
                HStack(spacing: 6) {
                    typeBadge
                    if let app = clip.sourceApp {
                        Text(app)
                            .font(.system(size: 10))
                            .foregroundStyle(.tertiary)
                    }
                    Text(RelativeTimeFormatter.format(clip.createdAt))
                        .font(.system(size: 10))
                        .foregroundStyle(.tertiary)
                    if clip.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.orange)
                    }
                    Spacer()
                }

                // Content
                if clip.clipType == .image, let imagePath = clip.imagePath {
                    imagePreview(path: imagePath)
                } else {
                    textContent
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var typeBadge: some View {
        Text(clip.clipType.label)
            .font(.system(size: 9, weight: .semibold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(badgeColor.opacity(0.12))
            .foregroundStyle(badgeColor)
            .clipShape(Capsule())
    }

    private var badgeColor: Color {
        switch clip.clipType {
        case .text: .blue
        case .code: .green
        case .url: .orange
        case .image: .pink
        }
    }

    private var textContent: some View {
        let text: String = {
            if clip.content.count > Constants.textTruncateLimit && !isExpanded {
                return String(clip.content.prefix(Constants.textTruncateLimit)) + "..."
            }
            return clip.content
        }()

        return Text(text)
            .font(.system(size: 12, design: clip.clipType == .code ? .monospaced : .default))
            .foregroundStyle(.primary)
            .lineLimit(isExpanded ? nil : 4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func imagePreview(path: String) -> some View {
        Group {
            if let nsImage = NSImage(contentsOfFile: path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxHeight: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .onTapGesture(perform: onPreviewImage)
            } else {
                Text("[图片加载失败]")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
    }

    // MARK: - Actions Zone

    private var actionsZone: some View {
        VStack(spacing: 4) {
            if clip.clipType != .image && clip.content.count > Constants.textTruncateLimit {
                actionButton(
                    icon: isExpanded ? "chevron.up" : "chevron.down",
                    action: onToggleExpand
                )
            }

            actionButton(
                icon: clip.isPinned ? "pin.slash.fill" : "pin",
                tint: clip.isPinned ? .orange : nil,
                action: onTogglePin
            )

            actionButton(icon: "trash", tint: .red, action: onDelete)
        }
        .opacity(isHovering || isSelected ? 1 : 0.3)
        .padding(.leading, 6)
    }

    private func actionButton(icon: String, tint: Color? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(tint ?? .secondary)
                .frame(width: 24, height: 24)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Background

    private var rowBackground: some ShapeStyle {
        if isFocused {
            return AnyShapeStyle(Color.accentColor.opacity(0.08))
        } else if isSelected {
            return AnyShapeStyle(Color.accentColor.opacity(0.05))
        } else if isHovering {
            return AnyShapeStyle(Color.primary.opacity(0.03))
        } else {
            return AnyShapeStyle(.clear)
        }
    }
}
