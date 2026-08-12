import XCTest
@testable import Breathlet

final class VersionTests: XCTestCase {
    func testNewerPatch() {
        XCTAssertTrue(UpdateChecker.isNewer("1.5.1", than: "1.5.0"))
    }

    func testNewerMinor() {
        XCTAssertTrue(UpdateChecker.isNewer("1.6.0", than: "1.5.9"))
    }

    func testNewerMajor() {
        XCTAssertTrue(UpdateChecker.isNewer("2.0.0", than: "1.99.99"))
    }

    func testNewerWithExtraSegment() {
        XCTAssertTrue(UpdateChecker.isNewer("1.5.0.1", than: "1.5.0"))
    }

    func testEqualIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer("1.5.0", than: "1.5.0"))
    }

    func testOlderIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer("1.4.9", than: "1.5.0"))
    }

    func testShorterVersionWithMissingSegmentIsNotNewer() {
        XCTAssertFalse(UpdateChecker.isNewer("1.5", than: "1.5.0"))
    }

    func testNonNumericSegmentsAreIgnored() {
        XCTAssertFalse(UpdateChecker.isNewer("1.5.beta", than: "1.5.0"))
    }
}
