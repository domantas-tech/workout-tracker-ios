import XCTest
@testable import RepTrack

final class ExerciseSortTests: XCTestCase {

    private let factory = WorkoutFactory()

    /// Pull Up +10%, Push Up −10%, Row held, Curl new; Curl and Row tie on sets with Pull Up/Push Up.
    private func report() -> ProgressReport {
        let workouts = [
            factory.make("2026-10-13", "Pull Up", sets: [(15, 80)]),
            factory.make("2026-10-13", "Push Up", sets: [(15, 60)]),
            factory.make("2026-10-13", "row", sets: [(10, 50)]),
            factory.make("2026-10-20", "Pull Up", sets: [(15, 88)]),
            factory.make("2026-10-20", "Push Up", sets: [(15, 54)]),
            factory.make("2026-10-20", "row", sets: [(10, 50)]),
            factory.make("2026-10-20", "Curl", sets: [(12, 15)]),
        ]
        return ProgressReport.build(period: .week, anchor: LocalDate(2026, 10, 21), workouts: workouts, firstDayOfWeek: .monday)
    }

    func testMostTrained_keepsReportOrder() {
        let report = report()
        XCTAssertEqual(ExerciseSort.mostTrained.sorted(report.exercises).map(\.name), report.exercises.map(\.name))
    }

    func testBiggestGain_newLast() {
        XCTAssertEqual(ExerciseSort.biggestGain.sorted(report().exercises).map(\.name), ["Pull Up", "row", "Push Up", "Curl"])
    }

    func testBiggestDrop_newLast() {
        XCTAssertEqual(ExerciseSort.biggestDrop.sorted(report().exercises).map(\.name), ["Push Up", "row", "Pull Up", "Curl"])
    }

    func testName_caseInsensitive() {
        XCTAssertEqual(ExerciseSort.name.sorted(report().exercises).map(\.name), ["Curl", "Pull Up", "Push Up", "row"])
    }
}
