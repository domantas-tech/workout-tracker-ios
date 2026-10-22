import Foundation

/// One exercise logged on a day (the Android `WorkoutEntity`).
struct Workout: Hashable, Identifiable {
    var id: Int64
    /// "yyyy-MM-dd"
    var date: String
    var name: String
    var notes: String = ""
    /// Epoch milliseconds; orders the exercises within a day.
    var createdAt: Int64 = Workout.nowMillis()

    static func nowMillis() -> Int64 { Int64((Date().timeIntervalSince1970 * 1000).rounded(.down)) }
}

/// One set of a workout (the Android `WorkoutSetEntity`).
struct WorkoutSet: Hashable, Identifiable {
    var id: Int64
    var workoutId: Int64
    var setNumber: Int
    var reps: Int
    var weight: Double = 0
    var isCompleted: Bool = true
}

/// A workout together with its sets. Owns the derived totals, which the unit tests cover.
struct WorkoutWithSets: Hashable, Identifiable {
    var workout: Workout
    var sets: [WorkoutSet] = []

    var id: Int64 { workout.id }

    /// Total reps across all sets.
    var totalReps: Int { sets.reduce(0) { $0 + $1.reps } }

    /// Number of sets.
    var totalSets: Int { sets.count }

    /// Number of sets ticked off as done.
    var completedSets: Int { sets.filter(\.isCompleted).count }

    /// Total volume (weight × reps).
    var totalVolume: Double { sets.reduce(0.0) { $0 + Double($1.reps) * $1.weight } }

    /// Best estimated one-rep max using the Epley formula e1RM = weight × (1 + reps / 30).
    /// 0 when no set has both weight and reps.
    var estimatedOneRepMax: Double {
        sets
            .filter { $0.weight > 0 && $0.reps > 0 }
            .map { $0.weight * (1 + Double($0.reps) / 30.0) }
            .max() ?? 0
    }

    /// Sets ordered by their set number.
    var orderedSets: [WorkoutSet] { sets.stableSorted { $0.setNumber < $1.setNumber } }
}
