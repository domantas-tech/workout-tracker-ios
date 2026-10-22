import SwiftUI

/// A short message with an optional action ("Undo", "View"), like an Android snackbar.
struct ToastMessage: Identifiable, Equatable {
    let id = UUID()
    let text: String
    var actionLabel: String?
    var action: (() -> Void)?

    static func == (lhs: ToastMessage, rhs: ToastMessage) -> Bool { lhs.id == rhs.id }
}

private struct ToastView: View {
    let message: ToastMessage
    let onDismiss: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            Text(message.text)
                .font(AppFont.bodyMedium)
                .foregroundStyle(Palette.textPrimary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, alignment: .leading)
            if let label = message.actionLabel {
                Button {
                    message.action?()
                    onDismiss()
                } label: {
                    Text(label)
                        .font(AppFont.labelLarge)
                        .foregroundStyle(Palette.lime)
                        .padding(.horizontal, 8)
                        .frame(minHeight: 36)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 8)
        .padding(.vertical, 6)
        .frame(minHeight: 48)
        .background(Palette.surfaceHighest, in: RoundedRectangle(cornerRadius: Radius.medium, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 12, y: 4)
        .padding(.horizontal, 12)
        .accessibilityElement(children: .combine)
    }
}

private struct ToastModifier: ViewModifier {
    @Binding var message: ToastMessage?
    var bottomPadding: CGFloat

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            ZStack {
                if let current = message {
                    ToastView(message: current) { dismiss(current) }
                        .padding(.bottom, bottomPadding)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                        .task(id: current.id) {
                            // Short duration, like SnackbarDuration.Short
                            try? await Task.sleep(nanoseconds: 4_000_000_000)
                            dismiss(current)
                        }
                }
            }
            .animation(.spring(response: 0.35, dampingFraction: 0.9), value: message)
        }
    }

    private func dismiss(_ current: ToastMessage) {
        if message?.id == current.id { message = nil }
    }
}

extension View {
    /// Shows `message` at the bottom; a new message replaces the current one.
    func toast(_ message: Binding<ToastMessage?>, bottomPadding: CGFloat = 12) -> some View {
        modifier(ToastModifier(message: message, bottomPadding: bottomPadding))
    }
}
