import SwiftUI

/// Search input with magnifying glass icon and clear button
struct SearchBarView: View {
    @Binding var search: String
    var isFocused: FocusState<Bool>.Binding

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 13))
                .foregroundStyle(.tertiary)

            TextField("搜索...  \u{2318}F", text: $search)
                .textFieldStyle(.plain)
                .font(.system(size: 13))
                .focused(isFocused)

            if !search.isEmpty {
                Button {
                    search = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                }
                .buttonStyle(.plain)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .padding(.horizontal, 12)
        .padding(.top, 4)
        .animation(.easeInOut(duration: 0.15), value: search.isEmpty)
    }
}
