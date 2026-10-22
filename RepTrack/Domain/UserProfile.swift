import Foundation

enum Gender: String, CaseIterable, Hashable {
    case male = "MALE"
    case female = "FEMALE"
    case other = "OTHER"

    var label: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        }
    }
}

/// The user's body measurements. There is only ever one profile; unset values are nil so
/// features can tell "not entered" apart from a real number.
struct UserProfile: Hashable {
    var weightKg: Double?
    var heightCm: Double?
    var gender: Gender?

    var isEmpty: Bool { weightKg == nil && heightCm == nil && gender == nil }
}

/// An exercise name saved to "My list" for quick selection when adding a workout.
/// Independent of logged workouts; listed in the order added.
struct SavedExercise: Hashable, Identifiable {
    var id: Int64
    var name: String
}
