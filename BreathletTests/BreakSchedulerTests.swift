import XCTest
@testable import Breathlet

final class BreakSchedulerTests: XCTestCase {
    func testStandupDisabledAlwaysReturnsEyeAndDoesNotCount() {
        let result = BreakScheduler.nextKind(
            completedEyeBreaks: 3,
            enableStandupBreak: false,
            standupEveryEyeBreaks: 2
        )
        XCTAssertEqual(result.kind, .eye)
        XCTAssertEqual(result.completedEyeBreaks, 3)
    }

    func testStandupEverySecondEyeBreak() {
        let first = BreakScheduler.nextKind(
            completedEyeBreaks: 0,
            enableStandupBreak: true,
            standupEveryEyeBreaks: 2
        )
        XCTAssertEqual(first.kind, .eye)
        XCTAssertEqual(first.completedEyeBreaks, 1)

        let second = BreakScheduler.nextKind(
            completedEyeBreaks: first.completedEyeBreaks,
            enableStandupBreak: true,
            standupEveryEyeBreaks: 2
        )
        XCTAssertEqual(second.kind, .standup)
        XCTAssertEqual(second.completedEyeBreaks, 2)

        let third = BreakScheduler.nextKind(
            completedEyeBreaks: second.completedEyeBreaks,
            enableStandupBreak: true,
            standupEveryEyeBreaks: 2
        )
        XCTAssertEqual(third.kind, .eye)
    }

    func testFrequencyClampedToOne() {
        let result = BreakScheduler.nextKind(
            completedEyeBreaks: 0,
            enableStandupBreak: true,
            standupEveryEyeBreaks: 0
        )
        XCTAssertEqual(result.kind, .standup)
        XCTAssertEqual(result.completedEyeBreaks, 1)
    }

    func testCountAccumulatesAcrossBreaks() {
        var count = 0
        for index in 1...5 {
            let result = BreakScheduler.nextKind(
                completedEyeBreaks: count,
                enableStandupBreak: true,
                standupEveryEyeBreaks: 3
            )
            count = result.completedEyeBreaks
            XCTAssertEqual(count, index)
            XCTAssertEqual(result.kind, index.isMultiple(of: 3) ? .standup : .eye)
        }
    }
}
