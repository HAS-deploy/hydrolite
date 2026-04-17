import XCTest
@testable import HydroLite

final class PresetsStoreTests: XCTestCase {

    private func fresh() -> UserDefaults { UserDefaults(suiteName: "hydrolite.test.p.\(UUID().uuidString)")! }

    func testBuiltInSetsHaveExpectedCounts() {
        XCTAssertEqual(BuiltInPresets.ounceSet.count, 4)
        XCTAssertEqual(BuiltInPresets.metricSet.count, 4)
    }

    func testCustomAddPersists() {
        let d = fresh()
        let s = PresetsStore(defaults: d)
        s.addOrUpdate(DrinkPreset(label: "Bottle", amountMl: 600))
        let reloaded = PresetsStore(defaults: d)
        XCTAssertEqual(reloaded.customPresets.count, 1)
        XCTAssertEqual(reloaded.customPresets.first?.label, "Bottle")
    }

    func testAddOrUpdateReplacesById() {
        let s = PresetsStore(defaults: fresh())
        let id = UUID()
        s.addOrUpdate(DrinkPreset(id: id, label: "A", amountMl: 100))
        s.addOrUpdate(DrinkPreset(id: id, label: "A'", amountMl: 200))
        XCTAssertEqual(s.customPresets.count, 1)
        XCTAssertEqual(s.customPresets.first?.amountMl, 200)
    }

    func testRemoveAtOffsets() {
        let s = PresetsStore(defaults: fresh())
        s.addOrUpdate(DrinkPreset(label: "A", amountMl: 100))
        s.addOrUpdate(DrinkPreset(label: "B", amountMl: 200))
        s.addOrUpdate(DrinkPreset(label: "C", amountMl: 300))
        s.remove(at: IndexSet(integer: 1))
        XCTAssertEqual(s.customPresets.map(\.label), ["A", "C"])
    }
}
