import SwiftUI

/// Home screen: day header, day summary, workout cards, "Exercise" button and rest timer.
struct WorkoutTrackerScreen: View {
    let viewModel: WorkoutViewModel
    let onOpenProgress: () -> Void

    @State private var showAddSheet = false
    @State private var showProfile = false
    @State private var toast: ToastMessage?
    /// UI-only, per workout
    @State private var collapsedWorkouts: Set<Int64> = []
    @State private var editingSet: EditingSet?
    @State private var renamingWorkout: Workout?
    @State private var renameText = ""
    @State private var isScrolledPastTop = false

    private let firstDayOfWeek = Weekday.localeFirstDay

    var body: some View {
        let today = LocalDate.today()
        let workouts = viewModel.workouts

        VStack(spacing: 0) {
            TrackerHeader(
                selectedDate: viewModel.selectedDate,
                today: today,
                datesWithWorkouts: viewModel.datesWithWorkouts,
                firstDayOfWeek: firstDayOfWeek,
                onDateSelected: { viewModel.selectDate($0) },
                onTodayTapped: { viewModel.goToToday() }
            ) {
                HeaderIconButton(systemImage: "chart.line.uptrend.xyaxis", label: "Progress", action: onOpenProgress)
                RestTimerMenu(timer: viewModel.restTimer)
                HeaderIconButton(systemImage: "person", label: "Profile") { showProfile = true }
            }

            ZStack(alignment: .bottomTrailing) {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        if workouts.isEmpty {
                            EmptyDayView(isToday: viewModel.selectedDate == today)
                        } else {
                            DaySummaryCard(
                                totalVolume: viewModel.totalVolumeToday,
                                totalReps: viewModel.totalRepsToday,
                                completedSets: viewModel.completedSetsToday,
                                totalSets: viewModel.totalSetsToday
                            )
                            ForEach(workouts) { workoutWithSets in
                                WorkoutCard(
                                    workoutWithSets: workoutWithSets,
                                    isCollapsed: collapsedWorkouts.contains(workoutWithSets.id),
                                    actions: cardActions(for: workoutWithSets, today: today)
                                )
                                .transition(.opacity.combined(with: .scale(scale: 0.97)))
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 4)
                    .padding(.bottom, 96)
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(key: ScrollOffsetKey.self, value: geometry.frame(in: .named("trackerScroll")).minY)
                        }
                    )
                    .animation(.easeInOut(duration: 0.25), value: workouts.map(\.id))
                }
                .coordinateSpace(name: "trackerScroll")
                .onPreferenceChange(ScrollOffsetKey.self) { offset in
                    // Like the Android FAB: collapses once the first item scrolls away
                    let scrolled = offset < -140
                    if scrolled != isScrolledPastTop {
                        withAnimation(.easeInOut(duration: 0.2)) { isScrolledPastTop = scrolled }
                    }
                }

                ExerciseButton(expanded: !isScrolledPastTop || workouts.isEmpty) { showAddSheet = true }
                    .padding(16)
                    .padding(.bottom, toast == nil ? 0 : 64)
                    .animation(.easeInOut(duration: 0.2), value: toast == nil)
            }
            .toast($toast)

            if viewModel.restTimer.isRunning {
                RestTimerBar(timer: viewModel.restTimer)
                    .transition(.move(edge: .bottom))
            }
        }
        .animation(.easeInOut(duration: 0.25), value: viewModel.restTimer.isRunning)
        .background(Palette.background.ignoresSafeArea())
        .sheet(isPresented: $showAddSheet) {
            AddExerciseSheet(viewModel: viewModel)
        }
        .sheet(isPresented: $showProfile) {
            ProfileSheet(profile: viewModel.userProfile) { weight, height, gender in
                viewModel.updateProfile(weightKg: weight, heightCm: height, gender: gender)
            }
        }
        .sheet(item: $editingSet) { editing in
            EditSetSheet(
                set: editing.set,
                focusWeight: editing.focusWeight,
                onSave: { reps, weight in viewModel.updateSet(editing.set.id, newReps: reps, newWeight: weight) },
                onDelete: { deleteSet(editing.set) }
            )
        }
        .alert("Rename exercise", isPresented: renameAlertBinding) {
            TextField("Name", text: $renameText)
                .textInputAutocapitalization(.words)
            Button("Cancel", role: .cancel) { renamingWorkout = nil }
            Button("Save") {
                if let workout = renamingWorkout {
                    viewModel.renameWorkout(workout.id, newName: renameText)
                }
                renamingWorkout = nil
            }
            .disabled(renameText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
    }

    private var renameAlertBinding: Binding<Bool> {
        Binding(
            get: { renamingWorkout != nil },
            set: { if !$0 { renamingWorkout = nil } }
        )
    }

    private func cardActions(for workoutWithSets: WorkoutWithSets, today: LocalDate) -> WorkoutCardActions {
        let workoutId = workoutWithSets.id
        return WorkoutCardActions(
            onToggleCollapsed: {
                withAnimation(.easeInOut(duration: 0.25)) {
                    if collapsedWorkouts.contains(workoutId) {
                        collapsedWorkouts.remove(workoutId)
                    } else {
                        collapsedWorkouts.insert(workoutId)
                    }
                }
            },
            onRename: {
                renameText = workoutWithSets.workout.name
                renamingWorkout = workoutWithSets.workout
            },
            onCopyToToday: viewModel.selectedDate == today ? nil : {
                viewModel.copyWorkoutToDate(workoutId, targetDate: today)
                toast = ToastMessage(text: "Copied to today", actionLabel: "View") { viewModel.goToToday() }
            },
            onDelete: {
                viewModel.deleteWorkout(workoutId)
                toast = ToastMessage(text: "\(workoutWithSets.workout.name) deleted", actionLabel: "Undo") {
                    viewModel.restoreWorkout(workoutWithSets)
                }
            },
            onAddSet: { viewModel.addSet(workoutId) },
            onIncrementReps: { set, amount in viewModel.incrementReps(set.id, currentReps: set.reps, amount: amount) },
            onDecrementReps: { set, amount in viewModel.decrementReps(set.id, currentReps: set.reps, amount: amount) },
            onToggleCompleted: { set, done in viewModel.toggleSetCompleted(set.id, isCompleted: done) },
            onEditSet: { set, focusWeight in editingSet = EditingSet(set: set, focusWeight: focusWeight) },
            onDeleteSet: { set in deleteSet(set) }
        )
    }

    private func deleteSet(_ set: WorkoutSet) {
        viewModel.deleteSet(set.id)
        toast = ToastMessage(text: "Set \(set.setNumber) deleted", actionLabel: "Undo") {
            viewModel.restoreSet(set)
        }
    }
}

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

/// Lime "+ Exercise" button; shrinks to just the icon while scrolled down.
private struct ExerciseButton: View {
    let expanded: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 20, weight: .semibold))
                if expanded {
                    Text("Exercise")
                        .font(AppFont.labelLarge)
                        .transition(.opacity)
                }
            }
            .foregroundStyle(Palette.onLime)
            .padding(.horizontal, expanded ? 20 : 0)
            .frame(minWidth: 56, minHeight: 56)
            .background(Palette.lime, in: Capsule())
            .shadow(color: .black.opacity(0.35), radius: 8, y: 4)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Add exercise")
    }
}
