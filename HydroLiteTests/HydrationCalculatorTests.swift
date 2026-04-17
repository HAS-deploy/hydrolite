import XCTest
@testable import HydroLite

final class HydrationCalculatorTests: XCTestCase {

    private let cal = Calendar(identifier: .gregorian)
    private func d(_ offsetDays: Int, _ hour: Int = 12) -> Date {
        let now = Date()
        let today = cal.startOfDay(for: now)
        return cal.date(byAdding: .day, value: offsetDays, to: today)!.addingTimeInterval(TimeInterval(hour * 3600))
    }

    func testTotalMlFiltersByDay() {
        let logs = [
            HydrationLog(timestamp: d(0, 9), amountMl: 250),
            HydrationLog(timestamp: d(0, 13), amountMl: 500),
            HydrationLog(timestamp: d(-1, 8), amountMl: 1000),
        ]
        XCTAssertEqual(HydrationCalculator.totalMl(logs: logs, on: d(0)), 750, accuracy: 0.01)
        XCTAssertEqual(HydrationCalculator.totalMl(logs: logs, on: d(-1)), 1000, accuracy: 0.01)
    }

    func testProgressClamps() {
        XCTAssertEqual(HydrationCalculator.progress(total: 0, goal: 2000), 0)
        XCTAssertEqual(HydrationCalculator.progress(total: 1000, goal: 2000), 0.5)
        XCTAssertEqual(HydrationCalculator.progress(total: 4000, goal: 2000), 1.0)
        XCTAssertEqual(HydrationCalculator.progress(total: 500, goal: 0), 0)
    }

    func testRemainingClampsAtZero() {
        XCTAssertEqual(HydrationCalculator.remaining(total: 500, goal: 2000), 1500)
        XCTAssertEqual(HydrationCalculator.remaining(total: 2500, goal: 2000), 0)
    }

    func testLastNDays() {
        let logs = [
            HydrationLog(timestamp: d(0), amountMl: 500),
            HydrationLog(timestamp: d(-3), amountMl: 500),
            HydrationLog(timestamp: d(-10), amountMl: 500),
        ]
        XCTAssertEqual(HydrationCalculator.last(7, logs: logs).count, 2)
    }

    func testDailyTotalsOrderedOldestFirst() {
        let logs = [
            HydrationLog(timestamp: d(-2), amountMl: 100),
            HydrationLog(timestamp: d(-1), amountMl: 200),
            HydrationLog(timestamp: d(0), amountMl: 300),
        ]
        let totals = HydrationCalculator.dailyTotals(3, logs: logs)
        XCTAssertEqual(totals.count, 3)
        XCTAssertEqual(totals[0].totalMl, 100, accuracy: 0.01)
        XCTAssertEqual(totals[1].totalMl, 200, accuracy: 0.01)
        XCTAssertEqual(totals[2].totalMl, 300, accuracy: 0.01)
    }

    func testVolumeConversions() {
        XCTAssertEqual((16 as Double).ouncesToMl(), 16 * 29.5735, accuracy: 0.01)
        XCTAssertEqual((500 as Double).mlToOunces(), 500 / 29.5735, accuracy: 0.01)
    }
}
