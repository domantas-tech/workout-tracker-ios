import Foundation

/// Name suggestions in the add-exercise sheet.
enum ExerciseSuggestions {

    static let popular = [
        "Bench Press", "Squats", "Deadlift", "Pull-ups", "Push-ups", "Shoulder Press",
        "Barbell Rows", "Bicep Curls", "Tricep Dips", "Leg Press", "Lateral Raises", "Lunges",
    ]

    /// Most suggestions shown in the default (recent + popular) view.
    static let maxDefaultSuggestions = 10

    struct Suggestion: Hashable {
        let name: String
        /// Shown with a "recent" icon.
        let isRecent: Bool
    }

    /// Recent exercises first, then popular ones (or just "My list"); narrowed down while typing.
    /// While typing, a suggestion is shown when it contains the text but isn't exactly it.
    static func suggestions(typed: String, recentNames: [String], savedNames: [String], showMyList: Bool) -> [Suggestion] {
        let query = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        func matches(_ name: String) -> Bool {
            query.isEmpty || (name.range(of: query, options: .caseInsensitive) != nil && name.lowercased() != query.lowercased())
        }
        if showMyList {
            return savedNames.filter(matches).map { Suggestion(name: $0, isRecent: false) }
        }
        let recentSet = Set(recentNames)
        let combined = recentNames.map { Suggestion(name: $0, isRecent: true) }
            + popular.filter { !recentSet.contains($0) }.map { Suggestion(name: $0, isRecent: false) }
        return Array(combined.filter { matches($0.name) }.prefix(maxDefaultSuggestions))
    }

    /// Names ordered by when they were last used, newest first (exact-name grouping, like
    /// `GROUP BY name ORDER BY MAX(createdAt) DESC LIMIT n`).
    static func recentNames(_ workouts: [(name: String, createdAt: Int64)], limit: Int = 8) -> [String] {
        var latest: [String: Int64] = [:]
        for workout in workouts {
            latest[workout.name] = max(latest[workout.name] ?? .min, workout.createdAt)
        }
        return latest
            .sorted { lhs, rhs in lhs.value != rhs.value ? lhs.value > rhs.value : lhs.key < rhs.key }
            .prefix(limit)
            .map(\.key)
    }
}
