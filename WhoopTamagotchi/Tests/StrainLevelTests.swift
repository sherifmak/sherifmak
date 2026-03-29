import XCTest
@testable import WhoopTamagotchi

final class StrainLevelTests: XCTestCase {

    // MARK: - Boundary Tests

    func testStrainZeroIsResting() {
        XCTAssertEqual(StrainLevel.from(strain: 0.0), .resting)
    }

    func testStrainJustBelow4IsResting() {
        XCTAssertEqual(StrainLevel.from(strain: 3.99), .resting)
    }

    func testStrainExactly4IsLight() {
        XCTAssertEqual(StrainLevel.from(strain: 4.0), .light)
    }

    func testStrainJustBelow8IsLight() {
        XCTAssertEqual(StrainLevel.from(strain: 7.99), .light)
    }

    func testStrainExactly8IsModerate() {
        XCTAssertEqual(StrainLevel.from(strain: 8.0), .moderate)
    }

    func testStrainJustBelow13IsModerate() {
        XCTAssertEqual(StrainLevel.from(strain: 12.99), .moderate)
    }

    func testStrainExactly13IsHigh() {
        XCTAssertEqual(StrainLevel.from(strain: 13.0), .high)
    }

    func testStrainJustBelow17IsHigh() {
        XCTAssertEqual(StrainLevel.from(strain: 16.99), .high)
    }

    func testStrainExactly17IsOverreach() {
        XCTAssertEqual(StrainLevel.from(strain: 17.0), .overreach)
    }

    func testStrainMaxIsOverreach() {
        XCTAssertEqual(StrainLevel.from(strain: 21.0), .overreach)
    }

    // MARK: - Mid-Range Values

    func testStrainMidResting() {
        XCTAssertEqual(StrainLevel.from(strain: 2.0), .resting)
    }

    func testStrainMidLight() {
        XCTAssertEqual(StrainLevel.from(strain: 6.0), .light)
    }

    func testStrainMidModerate() {
        XCTAssertEqual(StrainLevel.from(strain: 10.5), .moderate)
    }

    func testStrainMidHigh() {
        XCTAssertEqual(StrainLevel.from(strain: 15.0), .high)
    }

    func testStrainMidOverreach() {
        XCTAssertEqual(StrainLevel.from(strain: 19.5), .overreach)
    }

    // MARK: - Edge Cases

    func testNegativeStrainIsResting() {
        // API shouldn't return negative, but handle gracefully
        XCTAssertEqual(StrainLevel.from(strain: -1.0), .resting)
    }

    func testStrainAbove21IsOverreach() {
        // Shouldn't happen per API docs, but handle gracefully
        XCTAssertEqual(StrainLevel.from(strain: 25.0), .overreach)
    }

    // MARK: - Label Tests

    func testLabelsAreNonEmpty() {
        for level in StrainLevel.allCases {
            XCTAssertFalse(level.label.isEmpty, "\(level) has empty label")
        }
    }

    func testAllCasesCount() {
        XCTAssertEqual(StrainLevel.allCases.count, 5)
    }
}
