import XCTest
@testable import HydroLite

final class LogsStoreTests: XCTestCase {

    private func fresh() -> UserDefaults { UserDefaults(suiteName: "hydrolite.test.\(UUID().uuidString)")! }

    func testAddPersists() {
        let d = fresh()
        let s = LogsStore(defaults: d)
        s.add(HydrationLog(timestamp: Date(), amountMl: 500))
        let reloaded = LogsStore(defaults: d)
        XCTAssertEqual(reloaded.logs.count, 1)
        XCTAssertEqual(reloaded.logs.first?.amountMl, 500)
    }

    func testUndoLastRemovesNewest() {
        let s = LogsStore(defaults: fresh())
        s.add(HydrationLog(timestamp: Date(), amountMl: 100))
        s.add(HydrationLog(timestamp: Date(), amountMl: 200))
        XCTAssertEqual(s.logs.first?.amountMl, 200)
        let removed = s.undoLast()
        XCTAssertEqual(removed?.amountMl, 200)
        XCTAssertEqual(s.logs.count, 1)
    }

    func testUndoLastOnEmptyIsNoOp() {
        let s = LogsStore(defaults: fresh())
        XCTAssertNil(s.undoLast())
    }

    func testTodayLogsFiltersByDay() {
        let s = LogsStore(defaults: fresh())
        let cal = Calendar.current
        s.add(HydrationLog(timestamp: Date(), amountMl: 500))
        let yesterday = cal.date(byAdding: .day, value: -1, to: Date())!
        s.add(HydrationLog(timestamp: yesterday, amountMl: 999))
        XCTAssertEqual(s.todayLogs().count, 1)
        XCTAssertEqual(s.todayLogs().first?.amountMl, 500)
    }

    func testClearAll() {
        let s = LogsStore(defaults: fresh())
        s.add(HydrationLog(amountMl: 100))
        s.clearAll()
        XCTAssertTrue(s.logs.isEmpty)
    }
}
