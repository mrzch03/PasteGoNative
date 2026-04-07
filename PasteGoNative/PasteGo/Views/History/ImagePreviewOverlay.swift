import SwiftUI

/// Fullscreen image preview overlay
struct ImagePreviewOverlay: View {
    let imagePath: String
    var onDismiss: () -> Void

    var body: some View {
        ZStack {
            // Dimmed background
            Color.black.opacity(0.6)
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            // Image
            if let nsImage = NSImage(contentsOfFile: imagePath) {
                VStack {
                    Image(nsImage: nsImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 20)
                        .padding(32)

                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 16)
                }
            }
        }
        .transition(.opacity)
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }
}
