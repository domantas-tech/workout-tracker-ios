import SwiftUI

/// Swipe the content right-to-left to delete it, revealing a red background with a trash icon
/// (like Compose's SwipeToDismissBox). Also offers a VoiceOver action.
struct SwipeToDelete<Content: View>: View {
    let accessibilityActionName: String
    let onDelete: () -> Void
    @ViewBuilder let content: Content

    @State private var offset: CGFloat = 0
    @State private var width: CGFloat = 0
    @State private var isHorizontalDrag: Bool?

    var body: some View {
        content
            .offset(x: offset)
            .background(alignment: .trailing) {
                ZStack(alignment: .trailing) {
                    Palette.coral
                    Image(systemName: "trash")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(Palette.background)
                        .padding(.trailing, 24)
                }
                .opacity(offset < 0 ? 1 : 0)
            }
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { width = geometry.size.width }
                        .onChange(of: geometry.size.width) { _, newWidth in width = newWidth }
                }
            )
            .clipped()
            .simultaneousGesture(
                DragGesture(minimumDistance: 20)
                    .onChanged { value in
                        if isHorizontalDrag == nil {
                            isHorizontalDrag = abs(value.translation.width) > abs(value.translation.height)
                        }
                        guard isHorizontalDrag == true else { return }
                        offset = min(0, value.translation.width)
                    }
                    .onEnded { value in
                        defer { isHorizontalDrag = nil }
                        guard isHorizontalDrag == true else { return }
                        let distance = -value.translation.width
                        let flung = -value.predictedEndTranslation.width > width * 0.9
                        if offset < 0 && (distance > width * 0.4 || flung) {
                            withAnimation(.easeOut(duration: 0.18)) { offset = -width }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                                onDelete()
                                offset = 0
                            }
                        } else {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) { offset = 0 }
                        }
                    }
            )
            .accessibilityAction(named: accessibilityActionName, onDelete)
    }
}
