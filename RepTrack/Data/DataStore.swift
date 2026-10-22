import Foundation
import SwiftData

/// Owns the SwiftData container and the repositories. Every write goes through `commit()`, which
/// saves and then notifies observers — the view models reload from it, like Room's Flow invalidation,
/// so the UI is never updated by hand after a write.
@MainActor
final class DataStore {
    let container: ModelContainer
    let context: ModelContext

    private(set) lazy var workouts = WorkoutRepository(store: self)
    private(set) lazy var userProfile = UserProfileRepository(store: self)
    private(set) lazy var savedExercises = SavedExerciseRepository(store: self)

    private var observers: [() -> Void] = []
    private var sequences: [String: IdSequenceModel] = [:]

    static let modelTypes: [any PersistentModel.Type] = [
        WorkoutModel.self, WorkoutSetModel.self, UserProfileModel.self, SavedExerciseModel.self, IdSequenceModel.self,
    ]

    init(inMemory: Bool = false) throws {
        let name = inMemory ? "RepTrack-\(UUID().uuidString)" : "RepTrack"
        let configuration = ModelConfiguration(name, isStoredInMemoryOnly: inMemory)
        container = try ModelContainer(for: Schema(DataStore.modelTypes), configurations: [configuration])
        context = ModelContext(container)
        context.autosaveEnabled = false
    }

    /// The app's on-disk store; falls back to memory if the file can't be opened.
    static func makeDefault() -> DataStore {
        if let store = try? DataStore() { return store }
        // swiftlint:disable:next force_try
        return try! DataStore(inMemory: true)
    }

    /// Calls `handler` after every saved change.
    func observe(_ handler: @escaping () -> Void) {
        observers.append(handler)
    }

    /// Saves pending changes and notifies observers.
    func commit() {
        do {
            try context.save()
        } catch {
            context.rollback()
            sequences.removeAll()
            assertionFailure("Saving failed: \(error)")
        }
        observers.forEach { $0() }
    }

    /// The next unused id for `table` (1, 2, 3, …), never reusing one.
    func nextId(for table: String) -> Int64 {
        let sequence = idSequence(for: table)
        sequence.lastValue += 1
        return sequence.lastValue
    }

    /// Makes sure future ids for `table` are greater than `id` (used when restoring with an old id).
    func reserveId(_ id: Int64, for table: String) {
        let sequence = idSequence(for: table)
        if id > sequence.lastValue { sequence.lastValue = id }
    }

    private func idSequence(for table: String) -> IdSequenceModel {
        if let cached = sequences[table] { return cached }
        let name = table
        let descriptor = FetchDescriptor<IdSequenceModel>(predicate: #Predicate { $0.table == name })
        let sequence: IdSequenceModel
        if let existing = try? context.fetch(descriptor).first {
            sequence = existing
        } else {
            sequence = IdSequenceModel(table: table, lastValue: 0)
            context.insert(sequence)
        }
        sequences[table] = sequence
        return sequence
    }
}
