import SwiftUI

/// Pill-shaped chip, used for suggestions, "My list" and sort options.
struct Chip: View {
    let label: String
    var systemImage: String?
    var isSelected = false
    var isMuted = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let systemImage {
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(isSelected ? Palette.lime : Palette.textSecondary)
                }
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(isSelected ? Palette.lime : (isMuted ? Palette.textSecondary : Palette.textPrimary))
                    .lineLimit(1)
            }
            .padding(.horizontal, 14)
            .frame(height: 34)
            .background(isSelected ? Palette.limeContainer : Palette.surfaceHigh, in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Lays children out left to right, wrapping onto new lines (like Compose's FlowRow).
struct FlowLayout: Layout {
    var spacing: CGFloat = 8
    var lineSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(subviews: subviews, maxWidth: proposal.width ?? .infinity)
        let height = rows.last.map { $0.y + $0.height } ?? 0
        let width = proposal.width ?? rows.map(\.width).max() ?? 0
        return CGSize(width: width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let rows = arrange(subviews: subviews, maxWidth: bounds.width)
        for row in rows {
            for item in row.items {
                subviews[item.index].place(
                    at: CGPoint(x: bounds.minX + item.x, y: bounds.minY + row.y),
                    proposal: ProposedViewSize(item.size)
                )
            }
        }
    }

    private struct Row {
        var items: [(index: Int, x: CGFloat, size: CGSize)] = []
        var y: CGFloat = 0
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(subviews: Subviews, maxWidth: CGFloat) -> [Row] {
        var rows: [Row] = []
        var current = Row()
        for index in subviews.indices {
            var size = subviews[index].sizeThatFits(.unspecified)
            size.width = min(size.width, maxWidth)
            let x = current.items.isEmpty ? 0 : current.width + spacing
            if !current.items.isEmpty && x + size.width > maxWidth {
                let nextY = current.y + current.height + lineSpacing
                rows.append(current)
                current = Row(y: nextY)
                current.items.append((index, 0, size))
                current.width = size.width
                current.height = size.height
            } else {
                current.items.append((index, x, size))
                current.width = x + size.width
                current.height = max(current.height, size.height)
            }
        }
        if !current.items.isEmpty { rows.append(current) }
        return rows
    }
}

/// Thin rounded progress bar.
struct ProgressBar: View {
    let progress: Double
    var height: CGFloat = 6
    var rounded = true
    var fill: Color = Palette.lime
    var track: Color = Palette.surfaceHighest

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Rectangle().fill(track)
                Rectangle()
                    .fill(fill)
                    .frame(width: geometry.size.width * min(max(progress, 0), 1))
            }
            .clipShape(RoundedRectangle(cornerRadius: rounded ? height / 2 : 0))
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityValue("\(Int(Format.roundHalfUp(min(max(progress, 0), 1) * 100))) percent")
    }
}

/// Round icon on a surface-coloured circle, used by the empty states.
struct EmptyStateIcon: View {
    let systemImage: String
    var size: CGFloat = 72

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: size * 0.42, weight: .regular))
            .foregroundStyle(Palette.lime)
            .frame(width: size, height: size)
            .background(Palette.surface, in: Circle())
            .accessibilityHidden(true)
    }
}

/// Header icon button with a comfortable touch target.
struct HeaderIconButton: View {
    let systemImage: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HeaderIcon(systemImage: systemImage)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct HeaderIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 19, weight: .regular))
            .foregroundStyle(Palette.textSecondary)
            .frame(width: 40, height: 44)
            .contentShape(Rectangle())
    }
}

/// Labelled input box with an optional unit suffix, used in the sheets (like Material's outlined field).
struct InputBox: ViewModifier {
    let label: String?
    var suffix: String?
    var isError = false
    var isFocused = false

    func body(content: Content) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if let label {
                Text(label)
                    .font(AppFont.labelMedium)
                    .foregroundStyle(isError ? Palette.coral : (isFocused ? Palette.lime : Palette.textSecondary))
            }
            HStack(spacing: 6) {
                content
                    .font(AppFont.titleMedium)
                    .foregroundStyle(Palette.textPrimary)
                if let suffix {
                    Text(suffix)
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.surfaceHighest.opacity(0.6), in: RoundedRectangle(cornerRadius: Radius.small, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: Radius.small, style: .continuous)
                .stroke(isError ? Palette.coral : (isFocused ? Palette.lime : Palette.outline), lineWidth: isFocused || isError ? 1.5 : 1)
        )
    }
}

extension View {
    func inputBox(label: String? = nil, suffix: String? = nil, isError: Bool = false, isFocused: Bool = false) -> some View {
        modifier(InputBox(label: label, suffix: suffix, isError: isError, isFocused: isFocused))
    }
}

/// Text-field input rules shared by the sheets.
enum InputRules {
    /// Weight in the edit-set sheet: digits with at most one "." or "," separator.
    static func isSetWeight(_ text: String) -> Bool {
        text.range(of: "^[0-9]*[.,]?[0-9]*$", options: .regularExpression) != nil
    }

    /// Profile weight / height: up to 3 digits and one decimal.
    static func isProfileMeasurement(_ text: String) -> Bool {
        text.range(of: "^[0-9]{0,3}([.,][0-9]?)?$", options: .regularExpression) != nil
    }

    /// Reps: digits only, at most 4.
    static func reps(_ text: String) -> String {
        String(text.filter { ("0"..."9").contains($0) }.prefix(4))
    }
}
