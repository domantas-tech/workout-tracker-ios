import XCTest
@testable import RepTrack

final class BodyWeightExercisesTests: XCTestCase {

    func testInitialWeight_pullUpIs95PercentOfBodyWeight() {
        XCTAssertEqual(BodyWeightExercises.initialWeightKg("Pull up", bodyWeightKg: 100), 95, accuracy: 0.001)
    }

    func testLoadFraction_matchesCommonSpellings() throws {
        for name in ["Pull up", "pull-up", "Pull-Ups", "pullups", " PULLUP "] {
            XCTAssertEqual(try XCTUnwrap(BodyWeightExercises.loadFraction(name), name), 0.95, accuracy: 0.001, name)
        }
        XCTAssertEqual(try XCTUnwrap(BodyWeightExercises.loadFraction("Dips")), 0.95, accuracy: 0.001)
    }

    func testInitialWeight_coversPartialBodyWeightExercises() {
        XCTAssertEqual(BodyWeightExercises.initialWeightKg("Knee push-up", bodyWeightKg: 100), 50, accuracy: 0.001)
        XCTAssertEqual(BodyWeightExercises.initialWeightKg("Inverted rows", bodyWeightKg: 100), 50, accuracy: 0.001)
        XCTAssertEqual(BodyWeightExercises.initialWeightKg("Bodyweight squat", bodyWeightKg: 100), 80, accuracy: 0.001)
        XCTAssertEqual(BodyWeightExercises.initialWeightKg("Body weight squats", bodyWeightKg: 100), 80, accuracy: 0.001)
    }

    func testInitialWeight_roundsToOneDecimal() {
        // 82.5 * 0.95 = 78.375
        XCTAssertEqual(BodyWeightExercises.initialWeightKg("Chin-up", bodyWeightKg: 82.5), 78.4, accuracy: 0.001)
    }

    func testInitialWeight_isZeroForUnknownExerciseOrMissingBodyWeight() {
        XCTAssertNil(BodyWeightExercises.loadFraction("Bench Press"))
        XCTAssertEqual(BodyWeightExercises.initialWeightKg("Bench Press", bodyWeightKg: 100), 0, accuracy: 0.001)
        XCTAssertEqual(BodyWeightExercises.initialWeightKg("Pull up", bodyWeightKg: nil), 0, accuracy: 0.001)
        XCTAssertEqual(BodyWeightExercises.initialWeightKg("Pull up", bodyWeightKg: 0), 0, accuracy: 0.001)
    }
}
