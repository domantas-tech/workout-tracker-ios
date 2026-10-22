import SwiftUI
import UIKit

/// The set being edited, and which field to focus.
struct EditingSet: Identifiable {
    let set: WorkoutSet
    let focusWeight: Bool

    var id: Int64 { self.set.id }
}

/// "Set N": type the exact weight and reps, or delete the set.
struct EditSetSheet: View {
    let set: WorkoutSet
    let focusWeight: Bool
    let onSave: (_ reps: Int, _ weight: Double) -> Void
    let onDelete: () -> Void

    private enum Field { case weight, reps }

    @Environment(\.dismiss) private var dismiss
    @State private var weightText: String
    @State private var repsText: String
    @FocusState private var focus: Field?

    init(set: WorkoutSet, focusWeight: Bool, onSave: @escaping (_ reps: Int, _ weight: Double) -> Void, onDelete: @escaping () -> Void) {
        self.set = set
        self.focusWeight = focusWeight
        self.onSave = onSave
        self.onDelete = onDelete
        _weightText = State(initialValue: set.weight > 0 ? Format.weight(set.weight) : "")
        _repsText = State(initialValue: "\(set.reps)")
    }

    private var isValid: Bool { !repsText.isEmpty }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top, spacing: 12) {
                    TextField("0", text: $weightText)
                        .keyboardType(.decimalPad)
                        .focused($focus, equals: .weight)
                        .inputBox(label: "Weight", suffix: "kg", isFocused: focus == .weight)
                    TextField("", text: $repsText)
                        .keyboardType(.numberPad)
                        .focused($focus, equals: .reps)
                        .inputBox(label: "Reps", isError: !isValid, isFocused: focus == .reps)
                }

                Button(role: .destructive) {
                    onDelete()
                    dismiss()
                } label: {
                    Label("Delete set", systemImage: "trash")
                        .font(AppFont.labelLarge)
                        .foregroundStyle(Palette.coral)
                        .frame(minHeight: 44)
                }
                .buttonStyle(.plain)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .navigationTitle("Set \(set.setNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Palette.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    if focus == .weight {
                        Button("Next") { focus = .reps }
                    } else {
                        Button("Done", action: save).disabled(!isValid)
                    }
                }
            }
        }
        .presentationDetents([.height(250)])
        .presentationBackground(Palette.surfaceHigh)
        .onChange(of: weightText) { oldValue, newValue in
            if !InputRules.isSetWeight(newValue) { weightText = oldValue }
        }
        .onChange(of: repsText) { _, newValue in
            let filtered = InputRules.reps(newValue)
            if filtered != newValue { repsText = filtered }
        }
        .onAppear { focus = focusWeight ? .weight : .reps }
        // Pre-select the current value so typing replaces it
        .onReceive(NotificationCenter.default.publisher(for: UITextField.textDidBeginEditingNotification)) { notification in
            guard let field = notification.object as? UITextField else { return }
            DispatchQueue.main.async {
                field.selectedTextRange = field.textRange(from: field.beginningOfDocument, to: field.endOfDocument)
            }
        }
    }

    private func save() {
        guard isValid else { return }
        onSave(Int(repsText) ?? 0, Format.parseDecimal(weightText) ?? 0)
        dismiss()
    }
}

/// "Your profile": body weight, height and gender, used for body-weight exercises.
struct ProfileSheet: View {
    let onSave: (_ weightKg: Double?, _ heightCm: Double?, _ gender: Gender?) -> Void

    private enum Field { case weight, height }

    @Environment(\.dismiss) private var dismiss
    @State private var weightText: String
    @State private var heightText: String
    @State private var gender: Gender?
    @FocusState private var focus: Field?

    init(profile: UserProfile, onSave: @escaping (_ weightKg: Double?, _ heightCm: Double?, _ gender: Gender?) -> Void) {
        self.onSave = onSave
        _weightText = State(initialValue: profile.weightKg.map(Format.weight) ?? "")
        _heightText = State(initialValue: profile.heightCm.map(Format.weight) ?? "")
        _gender = State(initialValue: profile.gender)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Used for body-weight exercises and estimates. Leave blank to skip.")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    TextField("", text: $weightText)
                        .keyboardType(.decimalPad)
                        .focused($focus, equals: .weight)
                        .inputBox(label: "Weight", suffix: "kg", isFocused: focus == .weight)
                    TextField("", text: $heightText)
                        .keyboardType(.decimalPad)
                        .focused($focus, equals: .height)
                        .inputBox(label: "Height", suffix: "cm", isFocused: focus == .height)
                }
                .padding(.top, 16)

                Text("Gender")
                    .font(AppFont.labelLarge)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 16)

                GenderSelector(selection: $gender)
                    .padding(.top, 8)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .navigationTitle("Your profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Palette.textSecondary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save", action: save)
                        .fontWeight(.semibold)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    if focus == .weight {
                        Button("Next") { focus = .height }
                    } else {
                        Button("Done") { focus = nil }
                    }
                }
            }
        }
        .presentationDetents([.height(330)])
        .presentationBackground(Palette.surfaceHigh)
        .onChange(of: weightText) { oldValue, newValue in
            if !InputRules.isProfileMeasurement(newValue) { weightText = oldValue }
        }
        .onChange(of: heightText) { oldValue, newValue in
            if !InputRules.isProfileMeasurement(newValue) { heightText = oldValue }
        }
    }

    private func save() {
        onSave(Format.parseDecimal(weightText), Format.parseDecimal(heightText), gender)
        dismiss()
    }
}

/// Male / Female / Other; tapping the selected option again clears it.
private struct GenderSelector: View {
    @Binding var selection: Gender?

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(Gender.allCases.enumerated()), id: \.element) { index, option in
                let isSelected = selection == option
                Button {
                    selection = isSelected ? nil : option
                } label: {
                    HStack(spacing: 6) {
                        if isSelected {
                            Image(systemName: "checkmark")
                                .font(.system(size: 13, weight: .bold))
                        }
                        Text(option.label)
                            .font(.system(size: 14, weight: .medium))
                    }
                    .foregroundStyle(isSelected ? Palette.onLime : Palette.textPrimary)
                    .frame(maxWidth: .infinity, minHeight: 40)
                    .background(isSelected ? Palette.lime : Color.clear)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
                if index < Gender.allCases.count - 1 {
                    Rectangle().fill(Palette.outline).frame(width: 1, height: 40)
                }
            }
        }
        .clipShape(Capsule())
        .overlay(Capsule().stroke(Palette.outline, lineWidth: 1))
        .animation(.easeInOut(duration: 0.15), value: selection)
    }
}

/// "My list": add or remove saved exercise names. Changes are saved straight away.
struct SavedExercisesSheet: View {
    let viewModel: WorkoutViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var newName = ""
    @FocusState private var fieldFocused: Bool

    private var canAdd: Bool { !newName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                Text("Exercises you do often, ready to tap when adding one.")
                    .font(AppFont.bodyMedium)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 4) {
                    TextField("Exercise name", text: $newName)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($fieldFocused)
                        .onSubmit(add)
                    Button(action: add) {
                        Image(systemName: "plus")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(canAdd ? Palette.lime : Palette.textSecondary)
                            .frame(width: 32, height: 32)
                    }
                    .buttonStyle(.plain)
                    .disabled(!canAdd)
                    .accessibilityLabel("Add to list")
                }
                .inputBox(isFocused: fieldFocused)
                .padding(.top, 16)

                if !viewModel.savedExercises.isEmpty {
                    ScrollView {
                        VStack(spacing: 8) {
                            ForEach(viewModel.savedExercises) { exercise in
                                HStack {
                                    Text(exercise.name)
                                        .font(AppFont.bodyLarge)
                                        .foregroundStyle(Palette.textPrimary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                    Button { viewModel.removeSavedExercise(exercise.id) } label: {
                                        Image(systemName: "xmark")
                                            .font(.system(size: 14, weight: .semibold))
                                            .foregroundStyle(Palette.textSecondary)
                                            .frame(width: 44, height: 44)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Remove \(exercise.name)")
                                }
                                .padding(.leading, 16)
                                .card(radius: Radius.medium, color: Palette.surfaceHighest)
                            }
                        }
                    }
                    .frame(maxHeight: 280)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 12)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .navigationTitle("My list")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Palette.surfaceHigh)
        .onChange(of: newName) { oldValue, newValue in
            if newValue.count > SavedExerciseRepository.maxNameLength { newName = oldValue }
        }
    }

    private func add() {
        guard canAdd else { return }
        viewModel.addSavedExercise(newName)
        newName = ""
    }
}
