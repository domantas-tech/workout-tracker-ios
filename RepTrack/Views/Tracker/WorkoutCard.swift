import SwiftUI

/// What a workout card can ask the screen to do.
struct WorkoutCardActions {
    var onToggleCollapsed: () -> Void
    var onRename: () -> Void
    var onCopyToToday: (() -> Void)?
    var onDelete: () -> Void
    var onAddSet: () -> Void
    var onIncrementReps: (WorkoutSet, Int) -> Void
    var onDecrementReps: (WorkoutSet, Int) -> Void
    var onToggleCompleted: (WorkoutSet, Bool) -> Void
    /// The Bool is true to focus the weight field, false for reps.
    var onEditSet: (WorkoutSet, Bool) -> Void
    var onDeleteSet: (WorkoutSet) -> Void
}

private enum SetColumns {
    static let number: CGFloat = 28
    static let stepper: CGFloat = 120
    static let check: CGFloat = 40
}

/// One exercise with its sets.
struct WorkoutCard: View {
    let workoutWithSets: WorkoutWithSets
    let isCollapsed: Bool
    let actions: WorkoutCardActions

    private var workout: Workout { workoutWithSets.workout }
    private var sets: [WorkoutSet] { workoutWithSets.orderedSets }
    private var allDone: Bool { !sets.isEmpty && workoutWithSets.completedSets == sets.count }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header

            if !isCollapsed {
                if !sets.isEmpty {
                    columnHeaders
                        .padding(.top, 12)
                }
                ForEach(sets) { set in
                    SwipeToDelete(accessibilityActionName: "Delete set \(set.setNumber)", onDelete: { actions.onDeleteSet(set) }) {
                        SetRow(
                            set: set,
                            onWeightTap: { actions.onEditSet(set, true) },
                            onRepsTap: { actions.onEditSet(set, false) },
                            onIncrement: { actions.onIncrementReps(set, $0) },
                            onDecrement: { actions.onDecrementReps(set, $0) },
                            onToggleCompleted: { actions.onToggleCompleted(set, $0) }
                        )
                    }
                }

                Button(action: actions.onAddSet) {
                    HStack(spacing: 6) {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .semibold))
                        Text("Add set")
                            .font(AppFont.labelLarge)
                    }
                    .foregroundStyle(Palette.lime)
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 12)
            }
        }
        .padding(.top, isCollapsed ? 12 : 16)
        .padding(.bottom, isCollapsed ? 12 : 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .card()
        .clipShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: Radius.large, style: .continuous))
        .onTapGesture {
            if isCollapsed { actions.onToggleCollapsed() }
        }
        .accessibilityAction(named: isCollapsed ? "Expand \(workout.name)" : "Collapse \(workout.name)", actions.onToggleCollapsed)
    }

    private var header: some View {
        HStack(spacing: 4) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 8) {
                    Text(workout.name)
                        .font(AppFont.titleMedium)
                        .foregroundStyle(Palette.textPrimary)
                        .lineLimit(1)
                    if allDone {
                        Image(systemName: "checkmark")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(Palette.lime)
                            .accessibilityLabel("All sets done")
                    }
                }
                Text(metaLine)
                    .font(AppFont.labelMedium)
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                Button { actions.onRename() } label: { Label("Rename", systemImage: "pencil") }
                Button { actions.onToggleCollapsed() } label: {
                    Label(isCollapsed ? "Expand" : "Collapse", systemImage: isCollapsed ? "chevron.down" : "chevron.up")
                }
                if let copy = actions.onCopyToToday {
                    Button { copy() } label: { Label("Copy to today", systemImage: "doc.on.doc") }
                }
                Button(role: .destructive) { actions.onDelete() } label: { Label("Delete", systemImage: "trash") }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Options for \(workout.name)")
        }
        .padding(.leading, 20)
        .padding(.trailing, 8)
    }

    /// "2/3 sets  ·  30 reps  ·  1,800 kg  ·  e1RM 80 kg"
    private var metaLine: String {
        var parts = ["\(workoutWithSets.completedSets)/\(workoutWithSets.totalSets) sets", "\(workoutWithSets.totalReps) reps"]
        if workoutWithSets.totalVolume > 0 { parts.append("\(Format.volume(workoutWithSets.totalVolume)) kg") }
        if workoutWithSets.estimatedOneRepMax > 0 { parts.append("e1RM \(Format.volume(workoutWithSets.estimatedOneRepMax)) kg") }
        return parts.joined(separator: "  ·  ")
    }

    private var columnHeaders: some View {
        HStack(spacing: 0) {
            columnLabel("SET").frame(width: SetColumns.number, alignment: .leading)
            Spacer().frame(width: 12)
            columnLabel("KG").frame(maxWidth: .infinity, alignment: .leading)
            Spacer().frame(width: 8)
            columnLabel("REPS").frame(width: SetColumns.stepper)
            Spacer().frame(width: 12)
            columnLabel("DONE").frame(width: SetColumns.check)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 4)
        .accessibilityHidden(true)
    }

    private func columnLabel(_ text: String) -> some View {
        Text(text)
            .font(AppFont.labelSmall)
            .tracking(0.8)
            .foregroundStyle(Palette.textSecondary)
    }
}

/// Set number · weight · reps stepper · done toggle.
struct SetRow: View {
    let set: WorkoutSet
    let onWeightTap: () -> Void
    let onRepsTap: () -> Void
    let onIncrement: (Int) -> Void
    let onDecrement: (Int) -> Void
    let onToggleCompleted: (Bool) -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text("\(set.setNumber)")
                .font(AppFont.titleSmall)
                .foregroundStyle(set.isCompleted ? Palette.lime : Palette.textSecondary)
                .frame(width: SetColumns.number, alignment: .leading)

            Spacer().frame(width: 12)

            // Weight – tap to edit. A muted "0" rather than a dash, which would read like a minus button.
            Button(action: onWeightTap) {
                Text(Format.weight(set.weight))
                    .font(AppFont.titleSmall)
                    .foregroundStyle(set.weight > 0 ? Palette.textPrimary : Palette.textSecondary)
                    .lineLimit(1)
                    .padding(.horizontal, 4)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Weight \(Format.weight(set.weight)) kg")
            .accessibilityIdentifier("setWeight-\(set.setNumber)")
            .accessibilityHint("Edit weight")

            Spacer().frame(width: 8)

            RepsStepper(reps: set.reps, onIncrement: onIncrement, onDecrement: onDecrement, onTap: onRepsTap)

            Spacer().frame(width: 12)

            CompleteToggle(isOn: set.isCompleted, setNumber: set.setNumber, onChange: onToggleCompleted)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 6)
        // Opaque base so the swipe background only shows once the row moves
        .background(
            ZStack {
                Palette.surface
                Palette.lime.opacity(set.isCompleted ? 0.07 : 0)
            }
            .animation(.easeInOut(duration: 0.2), value: set.isCompleted)
        )
    }
}

private struct RepsStepper: View {
    let reps: Int
    let onIncrement: (Int) -> Void
    let onDecrement: (Int) -> Void
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            StepperButton(systemImage: "minus", label: "Decrease reps (hold for −5)", onTap: { onDecrement(1) }, onLongPress: { onDecrement(5) })
            Button(action: onTap) {
                Text("\(reps)")
                    .font(.system(size: 15, weight: .bold).monospacedDigit())
                    .foregroundStyle(Palette.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("\(reps) reps")
            .accessibilityHint("Edit reps")
            StepperButton(systemImage: "plus", label: "Increase reps (hold for +5)", onTap: { onIncrement(1) }, onLongPress: { onIncrement(5) })
        }
        .frame(width: SetColumns.stepper, height: 40)
        .background(Palette.surfaceHigh, in: Capsule())
    }
}

/// Tap for ±1, long-press for ±5 (with a haptic).
private struct StepperButton: View {
    let systemImage: String
    let label: String
    let onTap: () -> Void
    let onLongPress: () -> Void

    var body: some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(Palette.textSecondary)
            .frame(width: 40, height: 40)
            .contentShape(Circle())
            .onTapGesture(perform: onTap)
            .onLongPressGesture(minimumDuration: 0.45) {
                Haptics.longPress()
                onLongPress()
            }
            .accessibilityElement()
            .accessibilityLabel(label)
            .accessibilityAddTraits(.isButton)
            .accessibilityAction { onTap() }
    }
}

private struct CompleteToggle: View {
    let isOn: Bool
    let setNumber: Int
    let onChange: (Bool) -> Void

    var body: some View {
        Button {
            Haptics.toggle(on: !isOn)
            onChange(!isOn)
        } label: {
            Image(systemName: "checkmark")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(isOn ? Palette.onLime : Palette.outline)
                .frame(width: SetColumns.check, height: SetColumns.check)
                .background(isOn ? Palette.lime : Palette.surface, in: Circle())
                .overlay(Circle().stroke(isOn ? Color.clear : Palette.outline, lineWidth: 1.5))
                .contentShape(Circle())
                .animation(.easeInOut(duration: 0.15), value: isOn)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Set \(setNumber) done")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }
}
