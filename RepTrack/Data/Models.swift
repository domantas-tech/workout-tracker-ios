import Foundation
import SwiftData

// SwiftData tables. They mirror the Android Room schema; the repositories convert them to the
// plain value types in Domain/ so the rest of the app (and the tests) never touch the database.

@Model
final class WorkoutModel {
    @Attribute(.unique) var id: Int64
    /// "yyyy-MM-dd"
    var date: String
    var name: String
    var notes: String
    var createdAt: Int64

    init(id: Int64, date: String, name: String, notes: String, createdAt: Int64) {
        self.id = id
        self.date = date
        self.name = name
        self.notes = notes
        self.createdAt = createdAt
    }

    var value: Workout {
        Workout(id: id, date: date, name: name, notes: notes, createdAt: createdAt)
    }
}

/// A set belongs to the workout with `workoutId`; deleting a workout deletes its sets (done by
/// `WorkoutRepository`, like Room's ON DELETE CASCADE).
@Model
final class WorkoutSetModel {
    @Attribute(.unique) var id: Int64
    var workoutId: Int64
    var setNumber: Int
    var reps: Int
    var weight: Double
    var isCompleted: Bool

    init(id: Int64, workoutId: Int64, setNumber: Int, reps: Int, weight: Double, isCompleted: Bool) {
        self.id = id
        self.workoutId = workoutId
        self.setNumber = setNumber
        self.reps = reps
        self.weight = weight
        self.isCompleted = isCompleted
    }

    var value: WorkoutSet {
        WorkoutSet(id: id, workoutId: workoutId, setNumber: setNumber, reps: reps, weight: weight, isCompleted: isCompleted)
    }
}

/// Single-row table holding the user's body measurements (`id` is always `singletonId`).
@Model
final class UserProfileModel {
    static let singletonId = 0

    @Attribute(.unique) var id: Int
    var weightKg: Double?
    var heightCm: Double?
    var genderRaw: String?

    init(weightKg: Double?, heightCm: Double?, genderRaw: String?) {
        self.id = UserProfileModel.singletonId
        self.weightKg = weightKg
        self.heightCm = heightCm
        self.genderRaw = genderRaw
    }
}

/// "My list" entry.
@Model
final class SavedExerciseModel {
    @Attribute(.unique) var id: Int64
    var name: String

    init(id: Int64, name: String) {
        self.id = id
        self.name = name
    }
}

/// Last id handed out per table, so ids are never reused (like SQLite AUTOINCREMENT). That keeps
/// "Undo" safe: a restored workout gets its old id back without clashing with a newer one.
@Model
final class IdSequenceModel {
    @Attribute(.unique) var table: String
    var lastValue: Int64

    init(table: String, lastValue: Int64) {
        self.table = table
        self.lastValue = lastValue
    }
}
