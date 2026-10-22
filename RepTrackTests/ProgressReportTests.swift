import XCTest
@testable import RepTrack

final class ProgressReportTests: XCTestCase {

    private var factory = WorkoutFactory()

    override func setUp() {
        super.setUp()
        factory = WorkoutFactory()
    }

    // Wednesday; with Monday weeks the current week is 19–25 Oct, the previous 12–18 Oct
    private let anchor = LocalDate(2026, 10, 21)

    private func weekly(_ workouts: WorkoutWithSets...) -> ProgressReport {
        ProgressReport.build(period: .week, anchor: anchor, workouts: workouts, firstDayOfWeek: .monday)
    }

    private func w(_ date: String, _ name: String, _ sets: (Int, Double)..., completed: Bool = true) -> WorkoutWithSets {
        factory.make(date, name, sets: sets, completed: completed)
    }

    func testRanges_respectWeekStartAndMonthBounds() {
        XCTAssertEqual(
            ProgressPeriod.week.rangeContaining(anchor, firstDayOfWeek: .monday),
            DateRange(start: LocalDate(2026, 10, 19), endInclusive: LocalDate(2026, 10, 25))
        )
        XCTAssertEqual(
            ProgressPeriod.week.rangeContaining(anchor, firstDayOfWeek: .sunday),
            DateRange(start: LocalDate(2026, 10, 18), endInclusive: LocalDate(2026, 10, 24))
        )
        XCTAssertEqual(
            ProgressPeriod.month.rangeContaining(LocalDate(2026, 2, 14), firstDayOfWeek: .monday),
            DateRange(start: LocalDate(2026, 2, 1), endInclusive: LocalDate(2026, 2, 28))
        )
        // 8 weeks of history ending with the current one
        XCTAssertEqual(
            ProgressReport.dataRange(period: .week, anchor: anchor, firstDayOfWeek: .monday),
            DateRange(start: LocalDate(2026, 8, 31), endInclusive: LocalDate(2026, 10, 25))
        )
    }

    func testPeriodStats_countOnlyCompletedSets() {
        let report = weekly(
            w("2026-10-19", "Bench Press", (10, 60), (8, 70)),
            w("2026-10-21", "Squat", (5, 100)),
            w("2026-10-21", "Deadlift", (5, 140), completed: false),
            w("2026-10-14", "Bench Press", (10, 60))
        )

        let cur = report.currentStats
        XCTAssertEqual(cur.trainingDays, 2)
        XCTAssertEqual(cur.exercises, 2)
        XCTAssertEqual(cur.sets, 3)
        XCTAssertEqual(cur.reps, 23)
        XCTAssertEqual(cur.volume, 600 + 560 + 500, accuracy: 0.001)

        XCTAssertEqual(report.previousStats.sets, 1)
        XCTAssertEqual(report.previousStats.volume, 600, accuracy: 0.001)
        // Deadlift had no completed sets, so it isn't listed
        XCTAssertEqual(Set(report.exercises.map(\.name)), ["Squat", "Bench Press"])
    }

    func testTrend_heavierBestSetIsProgress() throws {
        let report = weekly(
            w("2026-10-14", "Bench Press", (8, 80)),
            w("2026-10-20", "bench press ", (8, 82.5))
        )
        XCTAssertEqual(report.exercises.count, 1)
        let bench = try XCTUnwrap(report.exercises.first)
        XCTAssertEqual(bench.trend, .up)
        XCTAssertEqual(report.comparableCount, 1)
        XCTAssertEqual(report.improvedCount, 1)
    }

    func testTrend_isJudgedOnE1rmOnly_soExtraVolumeAloneIsHeld() throws {
        let report = weekly(
            w("2026-10-14", "Squat", (5, 100), (5, 100)),
            w("2026-10-20", "Squat", (5, 100), (5, 100), (5, 100))
        )
        let squat = try XCTUnwrap(report.exercises.first)
        XCTAssertEqual(report.exercises.count, 1)
        XCTAssertEqual(squat.trend, .same)
        XCTAssertEqual(try XCTUnwrap(squat.changePercent), 0, accuracy: 0.001)
    }

    func testChangePercent_isE1rmChangeWeekToWeek() throws {
        // e1RM = weight × (1 + reps / 30): 80 × 1.5 = 120 -> 88 × 1.5 = 132 (+10%)
        // 60 × 1.5 = 90 -> 54 × 1.5 = 81 (−10%)
        let report = weekly(
            w("2026-10-13", "Pull Up", (15, 80)),
            w("2026-10-13", "Push Up", (15, 60)),
            w("2026-10-20", "Pull Up", (15, 88)),
            w("2026-10-20", "Push Up", (15, 54))
        )
        let byName = Dictionary(uniqueKeysWithValues: report.exercises.map { ($0.name, $0) })
        let pullUp = try XCTUnwrap(byName["Pull Up"])
        let pushUp = try XCTUnwrap(byName["Push Up"])
        XCTAssertEqual(try XCTUnwrap(pullUp.changePercent), 10, accuracy: 0.001)
        XCTAssertEqual(pullUp.trend, .up)
        XCTAssertEqual(try XCTUnwrap(pushUp.changePercent), -10, accuracy: 0.001)
        XCTAssertEqual(pushUp.trend, .down)
    }

    func testChangePercent_isNullForNewExercises() {
        let report = weekly(w("2026-10-20", "Curl", (12, 15)))
        XCTAssertEqual(report.exercises.count, 1)
        XCTAssertNil(report.exercises.first?.changePercent)
    }

    func testExercises_mostTrainedFirst() {
        let report = weekly(
            w("2026-10-20", "Curl", (12, 15)),
            w("2026-10-20", "Deadlift", (5, 180)),
            w("2026-10-21", "Pull Up", (8, 80), (8, 80), (6, 80))
        )
        XCTAssertEqual(report.exercises.map(\.name), ["Pull Up", "Deadlift", "Curl"])
    }

    func testTrend_weakerBestSetIsDrop_evenWithMoreVolume() {
        let report = weekly(
            w("2026-10-14", "Squat", (5, 110)),
            w("2026-10-20", "Squat", (5, 100), (5, 100), (5, 100))
        )
        XCTAssertEqual(report.exercises.count, 1)
        XCTAssertEqual(report.exercises.first?.trend, .down)
    }

    func testTrend_identicalWorkIsHeld_andUnseenExerciseIsNew() throws {
        let report = weekly(
            w("2026-10-14", "Row", (10, 50)),
            w("2026-10-20", "Row", (10, 50)),
            w("2026-10-20", "Curl", (12, 15))
        )
        let byName = Dictionary(uniqueKeysWithValues: report.exercises.map { ($0.name, $0) })
        XCTAssertEqual(try XCTUnwrap(byName["Row"]).trend, .same)
        XCTAssertEqual(try XCTUnwrap(byName["Curl"]).trend, .new)
        XCTAssertEqual(report.comparableCount, 1)
        XCTAssertEqual(report.improvedCount, 0)
    }

    func testTrend_unweightedExercisesCompareBestReps() {
        let report = weekly(
            w("2026-10-14", "Pull-ups", (8, 0), (6, 0)),
            w("2026-10-20", "Pull-ups", (9, 0))
        )
        XCTAssertEqual(report.exercises.count, 1)
        XCTAssertEqual(report.exercises.first?.trend, .up)
    }

    func testHistory_hasOneBarPerPeriod_oldestFirst() {
        let report = weekly(
            w("2026-08-31", "Squat", (5, 100)),
            w("2026-10-20", "Squat", (5, 120))
        )
        XCTAssertEqual(report.history.count, 8)
        XCTAssertEqual(report.history.first?.range.start, LocalDate(2026, 8, 31))
        XCTAssertEqual(report.history.first?.volume ?? -1, 500, accuracy: 0.001)
        XCTAssertEqual(report.history.last?.volume ?? -1, 600, accuracy: 0.001)
        XCTAssertEqual(report.history[3].volume, 0, accuracy: 0.001)
    }

    func testPercentChange_needsBaseline() throws {
        XCTAssertEqual(try XCTUnwrap(percentChange(150, 100)), 50, accuracy: 0.001)
        XCTAssertNil(percentChange(10, 0))
    }

    // Extra iOS checks for behaviour Kotlin gives for free

    func testExerciseName_usesLatestSpelling_firstOnTie() {
        let report = weekly(
            w("2026-10-19", "bench press", (5, 80)),
            w("2026-10-21", "Bench Press", (5, 80)),
            w("2026-10-21", "BENCH PRESS", (5, 80))
        )
        XCTAssertEqual(report.exercises.map(\.name), ["Bench Press"])
    }

    func testExercises_equalSetsAndVolumeKeepFirstSeenOrder() {
        let report = weekly(
            w("2026-10-20", "Zebra Curl", (10, 10)),
            w("2026-10-20", "Alpha Curl", (10, 10)),
            w("2026-10-20", "Mid Curl", (10, 10))
        )
        XCTAssertEqual(report.exercises.map(\.name), ["Zebra Curl", "Alpha Curl", "Mid Curl"])
    }

    func testUnparseableDatesAreIgnored() {
        let report = weekly(w("not-a-date", "Squat", (5, 100)), w("2026-10-20", "Squat", (5, 100)))
        XCTAssertEqual(report.currentStats.sets, 1)
    }

    func testMonthlyHistoryHasSixMonths() {
        let report = ProgressReport.build(period: .month, anchor: LocalDate(2026, 3, 31), workouts: [], firstDayOfWeek: .monday)
        XCTAssertEqual(report.history.map(\.range.start), [
            LocalDate(2025, 10, 1), LocalDate(2025, 11, 1), LocalDate(2025, 12, 1),
            LocalDate(2026, 1, 1), LocalDate(2026, 2, 1), LocalDate(2026, 3, 1),
        ])
        XCTAssertEqual(report.previous, DateRange(start: LocalDate(2026, 2, 1), endInclusive: LocalDate(2026, 2, 28)))
    }
}
