import Foundation

/// Exercises where the load is (a share of) the user's own body weight, e.g. a pull-up moves
/// roughly 95% of it. Used to pre-fill the set weight when such an exercise is added.
enum BodyWeightExercises {

    // Keys are normalised with `normalize`
    private static let loadFractions: [String: Double] = [
        "pullup": 0.95,
        "chinup": 0.95,
        "dip": 0.95,
        "muscleup": 0.95,
        "pushup": 0.64,
        "kneepushup": 0.50,
        "invertedrow": 0.50,
        "bodyweightsquat": 0.80,
    ]

    /// Share of body weight lifted by `exerciseName`, or nil if it isn't a known body-weight exercise.
    static func loadFraction(_ exerciseName: String) -> Double? {
        loadFractions[normalize(exerciseName)]
    }

    /// Starting weight for a new set of `exerciseName`, rounded to 0.1 kg.
    /// 0 when the exercise isn't body-weight based or the body weight is unknown.
    static func initialWeightKg(_ exerciseName: String, bodyWeightKg: Double?) -> Double {
        guard let fraction = loadFraction(exerciseName) else { return 0 }
        guard let bodyWeightKg, bodyWeightKg > 0 else { return 0 }
        return Format.roundHalfUp(bodyWeightKg * fraction * 10) / 10
    }

    /// "Pull-Ups", "pull up", "Pullups" -> "pullup".
    static func normalize(_ name: String) -> String {
        var key = String(name.lowercased().filter { $0.isLetter || $0.isNumber })
        if key.hasSuffix("s") { key.removeLast() }
        return key
    }
}
