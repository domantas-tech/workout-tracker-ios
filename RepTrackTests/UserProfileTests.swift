import XCTest
@testable import RepTrack

final class UserProfileTests: XCTestCase {

    func testSanitize_keepsValidValues() throws {
        XCTAssertEqual(try XCTUnwrap(UserProfileRepository.sanitize(82.5, max: UserProfileRepository.maxWeightKg)), 82.5, accuracy: 0.001)
    }

    func testSanitize_treatsMissingOrNonPositiveAsUnset() {
        XCTAssertNil(UserProfileRepository.sanitize(nil, max: UserProfileRepository.maxWeightKg))
        XCTAssertNil(UserProfileRepository.sanitize(0, max: UserProfileRepository.maxWeightKg))
        XCTAssertNil(UserProfileRepository.sanitize(-5, max: UserProfileRepository.maxWeightKg))
        XCTAssertNil(UserProfileRepository.sanitize(.nan, max: UserProfileRepository.maxWeightKg))
        XCTAssertNil(UserProfileRepository.sanitize(.infinity, max: UserProfileRepository.maxWeightKg))
    }

    func testSanitize_capsAtMaximum() throws {
        XCTAssertEqual(
            try XCTUnwrap(UserProfileRepository.sanitize(999, max: UserProfileRepository.maxHeightCm)),
            UserProfileRepository.maxHeightCm,
            accuracy: 0.001
        )
    }

    func testIsEmpty_onlyWhenNothingIsSet() {
        XCTAssertTrue(UserProfile().isEmpty)
        XCTAssertFalse(UserProfile(gender: .female).isEmpty)
        XCTAssertFalse(UserProfile(weightKg: 70).isEmpty)
    }
}
