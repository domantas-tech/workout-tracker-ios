import XCTest
@testable import RepTrack

final class WorkoutAggregationTests: XCTestCase {

    func testTotalReps_calculatesCorrectSumOfAllSets() {
        let workout = Workout(id: 1, date: "2026-10-04", name: "Bench Press")
        let sets = [
            WorkoutSet(id: 101, workoutId: 1, setNumber: 1, reps: 12, weight: 60),
            WorkoutSet(id: 102, workoutId: 1, setNumber: 2, reps: 10, weight: 70),
            WorkoutSet(id: 103, workoutId: 1, setNumber: 3, reps: 8, weight: 80),
            WorkoutSet(id: 104, workoutId: 1, setNumber: 4, reps: 8, weight: 80),
        ]
        let workoutWithSets = WorkoutWithSets(workout: workout, sets: sets)

        // Total Reps must equal 12 + 10 + 8 + 8 = 38
        XCTAssertEqual(workoutWithSets.totalReps, 38)
        XCTAssertEqual(workoutWithSets.totalSets, 4)
        // Total volume = 12*60 + 10*70 + 8*80 + 8*80 = 2700
        XCTAssertEqual(workoutWithSets.totalVolume, 2700, accuracy: 0.001)
    }

    func testTotalReps_handlesEmptySets() {
        let workoutWithSets = WorkoutWithSets(workout: Workout(id: 2, date: "2026-10-04", name: "Pull-ups"), sets: [])

        XCTAssertEqual(workoutWithSets.totalReps, 0)
        XCTAssertEqual(workoutWithSets.totalSets, 0)
        XCTAssertEqual(workoutWithSets.totalVolume, 0, accuracy: 0.001)
        XCTAssertEqual(workoutWithSets.completedSets, 0)
        XCTAssertEqual(workoutWithSets.estimatedOneRepMax, 0, accuracy: 0.001)
    }

    func testEstimatedOneRepMax_takesBestSetUsingEpley() {
        let sets = [
            // 60 * (1 + 12/30) = 84.0
            WorkoutSet(id: 1, workoutId: 5, setNumber: 1, reps: 12, weight: 60),
            // 80 * (1 + 6/30) = 96.0  <- best
            WorkoutSet(id: 2, workoutId: 5, setNumber: 2, reps: 6, weight: 80),
            // 85 * (1 + 3/30) = 93.5
            WorkoutSet(id: 3, workoutId: 5, setNumber: 3, reps: 3, weight: 85),
        ]
        let workoutWithSets = WorkoutWithSets(workout: Workout(id: 5, date: "2026-10-04", name: "Bench Press"), sets: sets)

        XCTAssertEqual(workoutWithSets.estimatedOneRepMax, 96, accuracy: 0.001)
    }

    func testEstimatedOneRepMax_ignoresBodyweightAndZeroRepSets() {
        let sets = [
            WorkoutSet(id: 1, workoutId: 6, setNumber: 1, reps: 10, weight: 0),
            WorkoutSet(id: 2, workoutId: 6, setNumber: 2, reps: 0, weight: 20),
        ]
        let workoutWithSets = WorkoutWithSets(workout: Workout(id: 6, date: "2026-10-04", name: "Pull-ups"), sets: sets)

        XCTAssertEqual(workoutWithSets.estimatedOneRepMax, 0, accuracy: 0.001)
    }

    func testCompletedSets_countsOnlyTickedSets() {
        let sets = [
            WorkoutSet(id: 1, workoutId: 4, setNumber: 1, reps: 5, isCompleted: true),
            WorkoutSet(id: 2, workoutId: 4, setNumber: 2, reps: 5, isCompleted: false),
            WorkoutSet(id: 3, workoutId: 4, setNumber: 3, reps: 5, isCompleted: true),
        ]
        let workoutWithSets = WorkoutWithSets(workout: Workout(id: 4, date: "2026-10-04", name: "Deadlift"), sets: sets)

        XCTAssertEqual(workoutWithSets.completedSets, 2)
        XCTAssertEqual(workoutWithSets.totalSets, 3)
    }

    func testTotalReps_updatesWhenSetRepsModified() {
        let workout = Workout(id: 3, date: "2026-10-04", name: "Squats")
        let initial = WorkoutWithSets(workout: workout, sets: [
            WorkoutSet(id: 1, workoutId: 3, setNumber: 1, reps: 10),
            WorkoutSet(id: 2, workoutId: 3, setNumber: 2, reps: 10),
        ])
        XCTAssertEqual(initial.totalReps, 20)

        // User edits set 2 from 10 to 15 reps
        let modified = WorkoutWithSets(workout: workout, sets: [
            WorkoutSet(id: 1, workoutId: 3, setNumber: 1, reps: 10),
            WorkoutSet(id: 2, workoutId: 3, setNumber: 2, reps: 15),
        ])
        XCTAssertEqual(modified.totalReps, 25)
    }

    func testOrderedSets_sortsBySetNumber() {
        let workoutWithSets = WorkoutWithSets(workout: Workout(id: 7, date: "2026-10-04", name: "Row"), sets: [
            WorkoutSet(id: 3, workoutId: 7, setNumber: 3, reps: 8),
            WorkoutSet(id: 1, workoutId: 7, setNumber: 1, reps: 10),
            WorkoutSet(id: 2, workoutId: 7, setNumber: 2, reps: 9),
        ])
        XCTAssertEqual(workoutWithSets.orderedSets.map(\.setNumber), [1, 2, 3])
    }
}
