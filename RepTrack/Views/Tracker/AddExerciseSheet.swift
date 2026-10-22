import SwiftUI

/// "New exercise": name with suggestions (recent + popular, or "My list"), initial sets and reps.
struct AddExerciseSheet: View {
    let viewModel: WorkoutViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var initialSets = 3
    @State private var initialReps = 10
    /// Swaps the recent/popular chips for the saved "My list"; always starts on the default view.
    @State private var showMyList = false
    @State private var showSavedExercises = false
    @FocusState private var nameFocused: Bool

    private var isNameBlank: Bool { name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        let savedNames = viewModel.savedExercises.map(\.name)
        let suggestions = ExerciseSuggestions.suggestions(
            typed: name,
            recentNames: viewModel.recentWorkoutNames,
            savedNames: savedNames,
            showMyList: showMyList
        )

        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text("New exercise")
                        .font(AppFont.titleLarge)
                        .foregroundStyle(Palette.textPrimary)
                    Spacer()
                    Chip(label: "My list", systemImage: showMyList ? "star.fill" : "star", isSelected: showMyList) {
                        showMyList.toggle()
                    }
                }

                TextField("Exercise name", text: $name)
                    .textInputAutocapitalization(.words)
                    .autocorrectionDisabled()
                    .submitLabel(.done)
                    .focused($nameFocused)
                    .onSubmit(submit)
                    .accessibilityIdentifier("exerciseNameField")
                    .inputBox(isFocused: nameFocused)
                    .padding(.top, 16)

                if showMyList && savedNames.isEmpty {
                    Text("Save the exercises you do most for one-tap picks.")
                        .font(AppFont.bodyMedium)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.top, 12)
                }

                if !suggestions.isEmpty || showMyList {
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(suggestions, id: \.self) { suggestion in
                            Chip(label: suggestion.name, systemImage: suggestion.isRecent ? "clock.arrow.circlepath" : nil) {
                                name = suggestion.name
                            }
                            .accessibilityHint(suggestion.isRecent ? "Recent" : "")
                        }
                        if showMyList {
                            Chip(label: "Edit list", systemImage: "pencil", isMuted: true) {
                                showSavedExercises = true
                            }
                        }
                    }
                    .padding(.top, 12)
                }

                HStack(spacing: 12) {
                    CounterField(label: "Sets", value: $initialSets, range: 1...20)
                    CounterField(label: "Reps per set", value: $initialReps, range: 1...100)
                }
                .padding(.top, 20)

                Button(action: submit) {
                    Text("Add exercise")
                        .font(AppFont.labelLarge)
                        .foregroundStyle(isNameBlank ? Palette.textSecondary : Palette.onLime)
                        .frame(maxWidth: .infinity, minHeight: 52)
                        .background(isNameBlank ? Palette.surfaceHigh : Palette.lime, in: Capsule())
                }
                .buttonStyle(.plain)
                .disabled(isNameBlank)
                .accessibilityIdentifier("confirmAddExercise")
                .padding(.top, 24)
            }
            .padding(.horizontal, 24)
            .padding(.top, 24)
            .padding(.bottom, 16)
        }
        .scrollDismissesKeyboard(.interactively)
        .presentationDetents([.large])
        .presentationBackground(Palette.surface)
        .onAppear { nameFocused = true }
        // Opened from this sheet and drawn above it; this sheet stays open underneath
        .sheet(isPresented: $showSavedExercises) {
            SavedExercisesSheet(viewModel: viewModel)
        }
    }

    private func submit() {
        guard !isNameBlank else { return }
        viewModel.addWorkout(name: name.trimmingCharacters(in: .whitespacesAndNewlines), setsCount: initialSets, defaultReps: initialReps)
        dismiss()
    }
}

private struct CounterField: View {
    let label: String
    @Binding var value: Int
    let range: ClosedRange<Int>

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(label)
                .font(AppFont.labelMedium)
                .foregroundStyle(Palette.textSecondary)
            HStack(spacing: 2) {
                Text("\(value)")
                    .font(AppFont.headlineSmall)
                    .foregroundStyle(Palette.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button { value = min(max(value - 1, range.lowerBound), range.upperBound) } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .frame(width: 40, height: 40)
                        .contentShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Decrease \(label)")
                Button { value = min(max(value + 1, range.lowerBound), range.upperBound) } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .frame(width: 40, height: 40)
                        .background(Palette.surfaceHighest, in: Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Increase \(label)")
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 4)
        .padding(.top, 10)
        .padding(.bottom, 4)
        .frame(maxWidth: .infinity)
        .card(radius: Radius.medium, color: Palette.surfaceHigh)
        .accessibilityElement(children: .contain)
        .accessibilityValue("\(value)")
    }
}
