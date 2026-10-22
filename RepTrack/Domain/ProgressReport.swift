import Foundation

/// Length of a reporting period, and how many of them the history chart shows.
enum ProgressPeriod: String, CaseIterable, Hashable {
    case week
    case month

    var historyCount: Int {
        switch self {
        case .week: return 8
        case .month: return 6
        }
    }

    /// "week" / "month", as used in labels.
    var unitName: String { rawValue }

    /// The period of this length that contains `date`. Weeks start on `firstDayOfWeek`.
    func rangeContaining(_ date: LocalDate, firstDayOfWeek: Weekday) -> DateRange {
        switch self {
        case .week:
            let start = date.startOfWeek(firstDayOfWeek)
            return DateRange(start: start, endInclusive: start.plusDays(6))
        case .month:
            return DateRange(start: date.firstDayOfMonth, endInclusive: date.lastDayOfMonth)
        }
    }

    /// Moves `date` by `count` periods (negative = back in time).
    func shift(_ date: LocalDate, by count: Int) -> LocalDate {
        switch self {
        case .week: return date.plusWeeks(count)
        case .month: return date.plusMonths(count)
        }
    }
}

struct DateRange: Hashable {
    let start: LocalDate
    let endInclusive: LocalDate

    func contains(_ date: LocalDate) -> Bool { date >= start && date <= endInclusive }
}

/// Totals over one period. Only completed (ticked-off) sets count as work done.
struct PeriodStats: Hashable {
    var trainingDays = 0
    var exercises = 0
    var sets = 0
    var reps = 0
    var volume = 0.0
}

/// One bar of the history chart.
struct PeriodPoint: Hashable {
    let range: DateRange
    let volume: Double
    let sets: Int
}

/// Best performance on one exercise within one period (completed sets only).
struct ExerciseStats: Hashable {
    let sets: Int
    let reps: Int
    let volume: Double
    let topWeight: Double
    let bestOneRepMax: Double
    let bestReps: Int

    /// Weighted lifts are compared on e1RM; unweighted ones (weight 0) on their best set's reps.
    var isWeighted: Bool { bestOneRepMax > 0 }
}

enum ProgressTrend: Hashable {
    case up, same, down, new
}

struct ExerciseProgress: Hashable {
    let name: String
    let current: ExerciseStats
    /// Nil when the exercise wasn't done in the previous period.
    let previous: ExerciseStats?

    /// True when both periods have a weighted best set, so progress is measured on e1RM.
    var comparesOneRepMax: Bool {
        current.isWeighted && (previous == nil || previous!.isWeighted)
    }

    /// Period-over-period change of the progress metric, in percent: best e1RM for weighted work,
    /// best-set reps for unweighted work. Nil for exercises not done in the previous period.
    var changePercent: Double? {
        guard let previous else { return nil }
        if comparesOneRepMax {
            return percentChange(current.bestOneRepMax, previous.bestOneRepMax)
        }
        return percentChange(Double(current.bestReps), Double(previous.bestReps))
    }

    /// Progressive overload check on `changePercent`.
    var trend: ProgressTrend {
        if previous == nil { return .new }
        guard let change = changePercent else { return .same }
        if change > ExerciseProgress.epsilonPercent { return .up }
        if change < -ExerciseProgress.epsilonPercent { return .down }
        return .same
    }

    // Ignore rounding noise (e.g. 0.1 kg on a 100 kg e1RM)
    private static let epsilonPercent = 0.1
}

struct ProgressReport: Hashable {
    let period: ProgressPeriod
    let current: DateRange
    let previous: DateRange
    let currentStats: PeriodStats
    let previousStats: PeriodStats
    /// Oldest first; the last point is `current`.
    let history: [PeriodPoint]
    /// Exercises done in `current`, most trained (completed sets, then volume) first.
    let exercises: [ExerciseProgress]

    /// Exercises that were also done in the previous period, so a comparison is possible.
    var comparableCount: Int { exercises.filter { $0.previous != nil }.count }

    var improvedCount: Int { exercises.filter { $0.trend == .up }.count }

    /// The date range `build` needs data for: the whole history window ending at `anchor`'s period.
    static func dataRange(period: ProgressPeriod, anchor: LocalDate, firstDayOfWeek: Weekday) -> DateRange {
        let current = period.rangeContaining(anchor, firstDayOfWeek: firstDayOfWeek)
        let oldest = period.rangeContaining(period.shift(anchor, by: -(period.historyCount - 1)), firstDayOfWeek: firstDayOfWeek)
        return DateRange(start: oldest.start, endInclusive: current.endInclusive)
    }

    /// Builds the report for the period containing `anchor`, compared with the one before it.
    /// `workouts` should cover `dataRange`; workouts outside it are ignored.
    static func build(
        period: ProgressPeriod,
        anchor: LocalDate,
        workouts: [WorkoutWithSets],
        firstDayOfWeek: Weekday
    ) -> ProgressReport {
        let ranges = stride(from: period.historyCount - 1, through: 0, by: -1).map { back in
            period.rangeContaining(period.shift(anchor, by: -back), firstDayOfWeek: firstDayOfWeek)
        }
        let current = ranges[ranges.count - 1]
        let previous = period.rangeContaining(period.shift(anchor, by: -1), firstDayOfWeek: firstDayOfWeek)

        let dated: [(date: LocalDate, workout: WorkoutWithSets)] = workouts.compactMap { w in
            LocalDate.parse(w.workout.date).map { (date: $0, workout: w) }
        }
        func workoutsIn(_ range: DateRange) -> [(date: LocalDate, workout: WorkoutWithSets)] {
            dated.filter { range.contains($0.date) }
        }

        let currentWorkouts = workoutsIn(current)
        let previousWorkouts = workoutsIn(previous)

        let previousByExercise = exerciseStats(previousWorkouts.map(\.workout))
        let exercises = currentWorkouts
            .map(\.workout)
            .orderedGroups { exerciseKey($0.workout.name) }
            .compactMap { group -> ExerciseProgress? in
                guard let stats = statsFor(group.values) else { return nil }
                // Show the most recently used spelling of the name (first one wins on a tie)
                var latest = group.values[0]
                for w in group.values.dropFirst() where w.workout.date > latest.workout.date {
                    latest = w
                }
                return ExerciseProgress(name: latest.workout.name, current: stats, previous: previousByExercise[group.key])
            }
            .stableSorted { lhs, rhs in
                if lhs.current.sets != rhs.current.sets { return lhs.current.sets > rhs.current.sets }
                return lhs.current.volume > rhs.current.volume
            }

        return ProgressReport(
            period: period,
            current: current,
            previous: previous,
            currentStats: periodStats(currentWorkouts),
            previousStats: periodStats(previousWorkouts),
            history: ranges.map { range in
                let sets = workoutsIn(range).flatMap(\.workout.sets).filter(\.isCompleted)
                return PeriodPoint(range: range, volume: volume(of: sets), sets: sets.count)
            },
            exercises: exercises
        )
    }

    /// "Bench Press " and "bench press" are the same exercise.
    static func exerciseKey(_ name: String) -> String {
        name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private static func volume(of sets: [WorkoutSet]) -> Double {
        sets.reduce(0.0) { $0 + Double($1.reps) * $1.weight }
    }

    private static func periodStats(_ workouts: [(date: LocalDate, workout: WorkoutWithSets)]) -> PeriodStats {
        let done = workouts.filter { $0.workout.sets.contains(where: \.isCompleted) }
        let sets = done.flatMap(\.workout.sets).filter(\.isCompleted)
        return PeriodStats(
            trainingDays: Set(done.map(\.date)).count,
            exercises: Set(done.map { exerciseKey($0.workout.workout.name) }).count,
            sets: sets.count,
            reps: sets.reduce(0) { $0 + $1.reps },
            volume: volume(of: sets)
        )
    }

    private static func exerciseStats(_ workouts: [WorkoutWithSets]) -> [String: ExerciseStats] {
        var result: [String: ExerciseStats] = [:]
        for group in workouts.orderedGroups(by: { exerciseKey($0.workout.name) }) {
            if let stats = statsFor(group.values) { result[group.key] = stats }
        }
        return result
    }

    /// Nil when none of the sets were completed.
    private static func statsFor(_ workouts: [WorkoutWithSets]) -> ExerciseStats? {
        let sets = workouts.flatMap(\.sets).filter(\.isCompleted)
        guard !sets.isEmpty else { return nil }
        return ExerciseStats(
            sets: sets.count,
            reps: sets.reduce(0) { $0 + $1.reps },
            volume: volume(of: sets),
            topWeight: sets.map(\.weight).max() ?? 0,
            bestOneRepMax: WorkoutWithSets(workout: workouts[0].workout, sets: sets).estimatedOneRepMax,
            bestReps: sets.map(\.reps).max() ?? 0
        )
    }
}

/// Percentage change from `previous` to `current`; nil when there is no baseline.
func percentChange(_ current: Double, _ previous: Double) -> Double? {
    previous <= 0 ? nil : (current - previous) / previous * 100
}
