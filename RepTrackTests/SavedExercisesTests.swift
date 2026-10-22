import XCTest
@testable import RepTrack

final class SavedExercisesTests: XCTestCase {

    func testSanitizeName_trimsAndCollapsesWhitespace() {
        XCTAssertEqual(SavedExerciseRepository.sanitizeName("  Incline   DB\tPress "), "Incline DB Press")
    }

    func testSanitizeName_rejectsBlank() {
        XCTAssertNil(SavedExerciseRepository.sanitizeName(""))
        XCTAssertNil(SavedExerciseRepository.sanitizeName("   "))
    }

    func testSanitizeName_capsLength() throws {
        let long = String(repeating: "x", count: SavedExerciseRepository.maxNameLength + 20)
        XCTAssertEqual(try XCTUnwrap(SavedExerciseRepository.sanitizeName(long)).count, SavedExerciseRepository.maxNameLength)
    }

    func testIsDuplicate_ignoresCase() {
        let saved = ["Bench Press", "Pull-ups"]
        XCTAssertTrue(SavedExerciseRepository.isDuplicate("bench press", savedNames: saved))
        XCTAssertFalse(SavedExerciseRepository.isDuplicate("Bench", savedNames: saved))
    }
}
