import Foundation
import SwiftData

/// Logged workouts and their sets. Each public write is one saved transaction, followed by a
/// change notification. Inputs are sanitised here (trimmed names, reps/weight never negative), and
/// set numbers are kept contiguous (1…n).
@MainActor
final class WorkoutRepository {
    static let workoutsTable = "workouts"
    static let setsTable = "workout_sets"

    private unowned let store: DataStore
    private var context: ModelContext { store.context }

    init(store: DataStore) {
        self.store = store
    }

    // MARK: - Reads

    /// Workouts on `date` ("yyyy-MM-dd") in the order they were added.
    func workoutsWithSets(forDate date: String) -> [WorkoutWithSets] {
        let day = date
        let descriptor = FetchDescriptor<WorkoutModel>(
            predicate: #Predicate { $0.date == day },
            sortBy: [SortDescriptor(\.createdAt), SortDescriptor(\.id)]
        )
        return withSets(fetch(descriptor))
    }

    /// Workouts dated `start`…`end` inclusive (both "yyyy-MM-dd"; such strings sort chronologically).
    func workoutsWithSets(from start: String, through end: String) -> [WorkoutWithSets] {
        let first = start
        let last = end
        let descriptor = FetchDescriptor<WorkoutModel>(
            predicate: #Predicate { $0.date >= first && $0.date <= last },
            sortBy: [SortDescriptor(\.date), SortDescriptor(\.createdAt), SortDescriptor(\.id)]
        )
        return withSets(fetch(descriptor))
    }

    /// Every date that has at least one workout.
    func datesWithWorkouts() -> Set<String> {
        Set(fetch(FetchDescriptor<WorkoutModel>()).map(\.date))
    }

    /// Most recently used exercise names, offered as suggestions when adding a workout.
    func recentWorkoutNames(limit: Int = 8) -> [String] {
        let all = fetch(FetchDescriptor<WorkoutModel>()).map { (name: $0.name, createdAt: $0.createdAt) }
        return ExerciseSuggestions.recentNames(all, limit: limit)
    }

    func workout(id: Int64) -> Workout? {
        workoutModel(id: id)?.value
    }

    func sets(forWorkout workoutId: Int64) -> [WorkoutSet] {
        setModels(forWorkout: workoutId).map(\.value)
    }

    // MARK: - Workouts

    /// Adds a workout with `setsCount` identical, not-yet-completed sets. Returns its id.
    @discardableResult
    func createWorkout(name: String, date: String, setsCount: Int, defaultReps: Int, defaultWeight: Double = 0) -> Int64 {
        let workoutId = store.nextId(for: Self.workoutsTable)
        context.insert(WorkoutModel(id: workoutId, date: date, name: trimmed(name), notes: "", createdAt: Workout.nowMillis()))
        for number in 1...max(setsCount, 1) {
            context.insert(WorkoutSetModel(
                id: store.nextId(for: Self.setsTable),
                workoutId: workoutId,
                setNumber: number,
                reps: max(defaultReps, 1),
                weight: max(defaultWeight, 0),
                isCompleted: false
            ))
        }
        store.commit()
        return workoutId
    }

    func updateWorkoutName(_ workoutId: Int64, newName: String) {
        guard let workout = workoutModel(id: workoutId) else { return }
        workout.name = trimmed(newName)
        store.commit()
    }

    /// Deletes the workout and all of its sets.
    func deleteWorkout(_ workoutId: Int64) {
        for set in setModels(forWorkout: workoutId) { context.delete(set) }
        if let workout = workoutModel(id: workoutId) { context.delete(workout) }
        store.commit()
    }

    /// Undo for `deleteWorkout`: puts the workout and its sets back with their original ids and values.
    func restoreWorkout(_ workoutWithSets: WorkoutWithSets) {
        let workout = workoutWithSets.workout
        if let existing = workoutModel(id: workout.id) {
            existing.date = workout.date
            existing.name = workout.name
            existing.notes = workout.notes
            existing.createdAt = workout.createdAt
        } else {
            context.insert(WorkoutModel(id: workout.id, date: workout.date, name: workout.name, notes: workout.notes, createdAt: workout.createdAt))
        }
        store.reserveId(workout.id, for: Self.workoutsTable)
        for set in workoutWithSets.sets { upsert(set) }
        store.commit()
    }

    /// Copies the workout and its sets (not ticked off) to `targetDate`. Returns the new workout's id.
    @discardableResult
    func copyWorkoutToDate(_ workoutId: Int64, targetDate: String) -> Int64? {
        guard let original = workoutModel(id: workoutId) else { return nil }
        let originalSets = setModels(forWorkout: workoutId)
        let newId = store.nextId(for: Self.workoutsTable)
        context.insert(WorkoutModel(id: newId, date: targetDate, name: original.name, notes: original.notes, createdAt: Workout.nowMillis()))
        for set in originalSets {
            context.insert(WorkoutSetModel(
                id: store.nextId(for: Self.setsTable),
                workoutId: newId,
                setNumber: set.setNumber,
                reps: set.reps,
                weight: set.weight,
                isCompleted: false
            ))
        }
        store.commit()
        return newId
    }

    // MARK: - Sets

    /// Adds a set after the last one, copying its reps and weight (or the defaults for the first set).
    @discardableResult
    func addSetToWorkout(_ workoutId: Int64, defaultReps: Int = 10, defaultWeight: Double = 0) -> Int64? {
        guard workoutModel(id: workoutId) != nil else { return nil }
        let current = setModels(forWorkout: workoutId)
        let reps = current.last?.reps ?? defaultReps
        let weight = current.last?.weight ?? defaultWeight
        let nextNumber = (current.map(\.setNumber).max() ?? 0) + 1
        let setId = store.nextId(for: Self.setsTable)
        context.insert(WorkoutSetModel(id: setId, workoutId: workoutId, setNumber: nextNumber, reps: reps, weight: weight, isCompleted: false))
        store.commit()
        return setId
    }

    func updateSetReps(_ setId: Int64, newReps: Int) {
        guard let set = setModel(id: setId) else { return }
        set.reps = max(newReps, 0)
        store.commit()
    }

    func updateSetWeight(_ setId: Int64, newWeight: Double) {
        guard let set = setModel(id: setId) else { return }
        set.weight = max(newWeight, 0)
        store.commit()
    }

    /// Reps and weight in a single write, so neither overwrites the other.
    func updateSet(_ setId: Int64, newReps: Int, newWeight: Double) {
        guard let set = setModel(id: setId) else { return }
        set.reps = max(newReps, 0)
        set.weight = max(newWeight, 0)
        store.commit()
    }

    func toggleSetCompleted(_ setId: Int64, completed: Bool) {
        guard let set = setModel(id: setId) else { return }
        set.isCompleted = completed
        store.commit()
    }

    /// Deletes the set and renumbers the remaining ones 1…n.
    func deleteSet(_ setId: Int64) {
        guard let set = setModel(id: setId) else { return }
        let workoutId = set.workoutId
        context.delete(set)
        let remaining = setModels(forWorkout: workoutId).filter { $0.id != setId }
        for (index, other) in remaining.enumerated() where other.setNumber != index + 1 {
            other.setNumber = index + 1
        }
        store.commit()
    }

    /// Undo for `deleteSet`: re-inserts the set at its original position, moving later sets back down.
    /// Does nothing if its workout has been deleted in the meantime.
    func restoreSet(_ set: WorkoutSet) {
        guard workoutModel(id: set.workoutId) != nil else { return }
        for other in setModels(forWorkout: set.workoutId) where other.id != set.id && other.setNumber >= set.setNumber {
            other.setNumber += 1
        }
        upsert(set)
        store.commit()
    }

    // MARK: - Helpers

    private func upsert(_ set: WorkoutSet) {
        if let existing = setModel(id: set.id) {
            existing.workoutId = set.workoutId
            existing.setNumber = set.setNumber
            existing.reps = set.reps
            existing.weight = set.weight
            existing.isCompleted = set.isCompleted
        } else {
            context.insert(WorkoutSetModel(
                id: set.id,
                workoutId: set.workoutId,
                setNumber: set.setNumber,
                reps: set.reps,
                weight: set.weight,
                isCompleted: set.isCompleted
            ))
        }
        store.reserveId(set.id, for: Self.setsTable)
    }

    private func withSets(_ workouts: [WorkoutModel]) -> [WorkoutWithSets] {
        guard !workouts.isEmpty else { return [] }
        let ids = workouts.map(\.id)
        let descriptor = FetchDescriptor<WorkoutSetModel>(
            predicate: #Predicate { ids.contains($0.workoutId) },
            sortBy: [SortDescriptor(\.setNumber), SortDescriptor(\.id)]
        )
        let byWorkout = Dictionary(grouping: fetch(descriptor).map(\.value), by: \.workoutId)
        return workouts.map { WorkoutWithSets(workout: $0.value, sets: byWorkout[$0.id] ?? []) }
    }

    private func workoutModel(id: Int64) -> WorkoutModel? {
        let wanted = id
        var descriptor = FetchDescriptor<WorkoutModel>(predicate: #Predicate { $0.id == wanted })
        descriptor.fetchLimit = 1
        return fetch(descriptor).first
    }

    private func setModel(id: Int64) -> WorkoutSetModel? {
        let wanted = id
        var descriptor = FetchDescriptor<WorkoutSetModel>(predicate: #Predicate { $0.id == wanted })
        descriptor.fetchLimit = 1
        return fetch(descriptor).first
    }

    /// The workout's sets ordered by set number.
    private func setModels(forWorkout workoutId: Int64) -> [WorkoutSetModel] {
        let wanted = workoutId
        let descriptor = FetchDescriptor<WorkoutSetModel>(
            predicate: #Predicate { $0.workoutId == wanted },
            sortBy: [SortDescriptor(\.setNumber), SortDescriptor(\.id)]
        )
        return fetch(descriptor)
    }

    private func fetch<Model: PersistentModel>(_ descriptor: FetchDescriptor<Model>) -> [Model] {
        (try? context.fetch(descriptor)) ?? []
    }

    private func trimmed(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
