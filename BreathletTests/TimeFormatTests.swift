import XCTest
@testable import Breathlet

final class TimeFormatTests: XCTestCase {
    func testWholeMinutes() {
        XCTAssertEqual(TimeFormat.string(seconds: 1200), "20:00")
    }

    func testMinutesAndSeconds() {
        XCTAssertEqual(TimeFormat.string(seconds: 65), "01:05")
    }

    func testZero() {
        XCTAssertEqual(TimeFormat.string(seconds: 0), "00:00")
    }

    func testNegativeClampsToZero() {
        XCTAssertEqual(TimeFormat.string(seconds: -5), "00:00")
    }

    func testLargeValue() {
        XCTAssertEqual(TimeFormat.string(seconds: 359999), "5999:59")
    }
}
