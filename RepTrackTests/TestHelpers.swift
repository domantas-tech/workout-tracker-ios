import Foundation
@testable import RepTrack

/// Builds workouts the same way the Android tests do: each set is (reps, weight).
final class WorkoutFactory {
    private var nextId: Int64 = 1

    func make(_ date: String, _ name: String, sets: [(Int, Double)], completed: Bool = true) -> WorkoutWithSets {
        let id = nextId
        nextId += 1
        return WorkoutWithSets(
            workout: Workout(id: id, date: date, name: name),
            sets: sets.enumerated().map { index, set in
                WorkoutSet(
                    id: id * 100 + Int64(index),
                    workoutId: id,
                    setNumber: index + 1,
                    reps: set.0,
                    weight: set.1,
                    isCompleted: completed
                )
            }
        )
    }
}

let english = Locale(identifier: "en_GB")
