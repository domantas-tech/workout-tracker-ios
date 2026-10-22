import Foundation

/// Orderings for the "All exercises" list.
enum ExerciseSort: String, CaseIterable, Hashable {
    case mostTrained
    case biggestGain
    case biggestDrop
    case name

    var label: String {
        switch self {
        case .mostTrained: return "Most trained"
        case .biggestGain: return "Biggest gain"
        case .biggestDrop: return "Biggest drop"
        case .name: return "A–Z"
        }
    }

    func sorted(_ exercises: [ExerciseProgress]) -> [ExerciseProgress] {
        switch self {
        case .mostTrained:
            // The report already lists the most trained first
            return exercises
        case .biggestGain:
            // Exercises without a baseline ("New") go last either way
            return exercises.stableSorted { lhs, rhs in
                switch (lhs.changePercent, rhs.changePercent) {
                case let (left?, right?): return left > right
                case (.some, nil): return true
                default: return false
                }
            }
        case .biggestDrop:
            return exercises.stableSorted { lhs, rhs in
                switch (lhs.changePercent, rhs.changePercent) {
                case let (left?, right?): return left < right
                case (.some, nil): return true
                default: return false
                }
            }
        case .name:
            return exercises.stableSorted { $0.name.lowercased() < $1.name.lowercased() }
        }
    }
}
