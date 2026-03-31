import SwiftUI

struct MessageComposer: View {
    @Binding var text: String
    let isDisabled: Bool
    let onSend: () -> Void

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: Theme.Spacing.md) {
            // Text field pill
            TextField("Message", text: $text, axis: .vertical)
                .font(Theme.Typography.body)
                .foregroundStyle(Theme.Colors.textPrimary)
                .tint(Theme.Colors.accent)
                .textFieldStyle(.plain)
                .lineLimit(1...6)
                .focused($isFocused)
                .onSubmit {
                    guard canSend else { return }
                    onSend()
                }
                .padding(.horizontal, Theme.Spacing.md)
                .padding(.vertical, Theme.Spacing.md)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: Theme.Radius.xl))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.xl)
                        .strokeBorder(
                            isFocused
                                ? Theme.Colors.accent.opacity(0.5)
                                : Theme.Colors.borderSubtle,
                            lineWidth: 1
                        )
                        .animation(Theme.Anim.smooth, value: isFocused)
                )

            // Send button
            Button(action: onSend) {
                ZStack {
                    Circle()
                        .fill(canSend ? Theme.Colors.accent : Theme.Colors.surface3)
                        .frame(width: 36, height: 36)

                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(canSend ? .white : Theme.Colors.textTertiary)
                }
            }
            .disabled(!canSend)
            .animation(Theme.Anim.spring, value: canSend)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.md)
        .padding(.bottom, Theme.Spacing.xs)
        .background(.ultraThinMaterial)
        .liquidGlass()
    }

    private var canSend: Bool {
        !isDisabled && !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}