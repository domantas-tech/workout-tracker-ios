import Foundation
import SwiftData

/// The user's "My list" of frequent exercises, offered as quick picks in the add-exercise sheet.
@MainActor
final class SavedExerciseRepository {
    static let table = "saved_exercises"
    static let maxNameLength = 50

    /// Trimmed, single-spaced and capped at `maxNameLength`; nil when blank.
    nonisolated static func sanitizeName(_ name: String) -> String? {
        let collapsed = name
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "[ \\t\\n\\u000B\\f\\r]+", with: " ", options: .regularExpression)
        var capped = String(collapsed.prefix(maxNameLength))
        while let last = capped.last, last.isWhitespace { capped.removeLast() }
        return capped.isEmpty ? nil : capped
    }

    nonisolated static func isDuplicate(_ name: String, savedNames: [String]) -> Bool {
        let lowered = name.lowercased()
        return savedNames.contains { $0.lowercased() == lowered }
    }

    private unowned let store: DataStore

    init(store: DataStore) {
        self.store = store
    }

    /// Saved exercises in the order they were added.
    func exercises() -> [SavedExercise] {
        let descriptor = FetchDescriptor<SavedExerciseModel>(sortBy: [SortDescriptor(\.id)])
        return ((try? store.context.fetch(descriptor)) ?? []).map { SavedExercise(id: $0.id, name: $0.name) }
    }

    /// Adds `name` unless it is blank or already saved (case-insensitive).
    func add(_ name: String) {
        guard let clean = Self.sanitizeName(name) else { return }
        guard !Self.isDuplicate(clean, savedNames: exercises().map(\.name)) else { return }
        store.context.insert(SavedExerciseModel(id: store.nextId(for: Self.table), name: clean))
        store.commit()
    }

    func remove(id: Int64) {
        let wanted = id
        let descriptor = FetchDescriptor<SavedExerciseModel>(predicate: #Predicate { $0.id == wanted })
        for model in (try? store.context.fetch(descriptor)) ?? [] { store.context.delete(model) }
        store.commit()
    }
}
