import Foundation
import Observation

/// State and actions for the tracker screen. Reads come from the repositories; after every write
/// the data store notifies this view model, which reloads — the UI is never patched by hand.
@Observable
@MainActor
final class WorkoutViewModel {
    private let store: DataStore
    let restTimer: RestTimer

    /// The day being viewed.
    private(set) var selectedDate: LocalDate

    /// Workouts on the selected date, in the order they were added.
    private(set) var workouts: [WorkoutWithSets] = []
    /// Dates ("yyyy-MM-dd") that have at least one workout logged.
    private(set) var datesWithWorkouts: Set<String> = []
    /// Most recently used exercise names, offered as suggestions when adding a workout.
    private(set) var recentWorkoutNames: [String] = []
    /// The user's "My list" of frequent exercises.
    private(set) var savedExercises: [SavedExercise] = []
    private(set) var userProfile = UserProfile()

    init(store: DataStore, restTimer: RestTimer? = nil, today: LocalDate = .today()) {
        self.store = store
        self.restTimer = restTimer ?? RestTimer()
        self.selectedDate = today
        reload()
        store.observe { [weak self] in self?.reload() }
    }

    // MARK: - Day totals

    var totalRepsToday: Int { workouts.reduce(0) { $0 + $1.totalReps } }
    var totalSetsToday: Int { workouts.reduce(0) { $0 + $1.totalSets } }
    var completedSetsToday: Int { workouts.reduce(0) { $0 + $1.completedSets } }
    var totalVolumeToday: Double { workouts.reduce(0.0) { $0 + $1.totalVolume } }

    // MARK: - Date selection

    func selectDate(_ date: LocalDate) {
        guard date != selectedDate else { return }
        selectedDate = date
        workouts = store.workouts.workoutsWithSets(forDate: date.isoString)
    }

    func goToToday() { selectDate(.today()) }
    func goToPreviousDay() { selectDate(selectedDate.plusDays(-1)) }
    func goToNextDay() { selectDate(selectedDate.plusDays(1)) }

    // MARK: - Workouts

    func addWorkout(name: String, setsCount: Int = 3, defaultReps: Int = 10) {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.workouts.createWorkout(
            name: trimmed,
            date: selectedDate.isoString,
            setsCount: max(setsCount, 1),
            defaultReps: max(defaultReps, 1),
            defaultWeight: BodyWeightExercises.initialWeightKg(name, bodyWeightKg: store.userProfile.bodyWeightKg())
        )
    }

    func renameWorkout(_ workoutId: Int64, newName: String) {
        let trimmed = newName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        store.workouts.updateWorkoutName(workoutId, newName: trimmed)
    }

    func deleteWorkout(_ workoutId: Int64) { store.workouts.deleteWorkout(workoutId) }

    func restoreWorkout(_ workoutWithSets: WorkoutWithSets) { store.workouts.restoreWorkout(workoutWithSets) }

    func copyWorkoutToDate(_ workoutId: Int64, targetDate: LocalDate) {
        store.workouts.copyWorkoutToDate(workoutId, targetDate: targetDate.isoString)
    }

    // MARK: - Sets

    func addSet(_ workoutId: Int64) { store.workouts.addSetToWorkout(workoutId) }

    func updateSetReps(_ setId: Int64, newReps: Int) {
        store.workouts.updateSetReps(setId, newReps: max(newReps, 0))
    }

    /// Reps and weight in a single write, so neither overwrites the other.
    func updateSet(_ setId: Int64, newReps: Int, newWeight: Double) {
        store.workouts.updateSet(setId, newReps: max(newReps, 0), newWeight: max(newWeight, 0))
    }

    func incrementReps(_ setId: Int64, currentReps: Int, amount: Int = 1) {
        updateSetReps(setId, newReps: currentReps + amount)
    }

    func decrementReps(_ setId: Int64, currentReps: Int, amount: Int = 1) {
        updateSetReps(setId, newReps: max(currentReps - amount, 0))
    }

    func updateSetWeight(_ setId: Int64, newWeight: Double) {
        store.workouts.updateSetWeight(setId, newWeight: max(newWeight, 0))
    }

    /// Ticking a set off also starts the rest timer when auto-start is on.
    func toggleSetCompleted(_ setId: Int64, isCompleted: Bool) {
        store.workouts.toggleSetCompleted(setId, completed: isCompleted)
        if isCompleted && restTimer.autoStartRest {
            restTimer.start(restTimer.restDurationSeconds)
        }
    }

    func deleteSet(_ setId: Int64) { store.workouts.deleteSet(setId) }

    func restoreSet(_ set: WorkoutSet) { store.workouts.restoreSet(set) }

    // MARK: - Profile and "My list"

    func updateProfile(weightKg: Double?, heightCm: Double?, gender: Gender?) {
        store.userProfile.updateProfile(weightKg: weightKg, heightCm: heightCm, gender: gender)
    }

    func addSavedExercise(_ name: String) { store.savedExercises.add(name) }

    func removeSavedExercise(_ id: Int64) { store.savedExercises.remove(id: id) }

    // MARK: - Loading

    private func reload() {
        workouts = store.workouts.workoutsWithSets(forDate: selectedDate.isoString)
        datesWithWorkouts = store.workouts.datesWithWorkouts()
        recentWorkoutNames = store.workouts.recentWorkoutNames()
        savedExercises = store.savedExercises.exercises()
        userProfile = store.userProfile.profile()
    }
}
