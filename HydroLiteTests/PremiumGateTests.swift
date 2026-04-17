import XCTest
@testable import HydroLite

final class PremiumGateTests: XCTestCase {
    func testFreeAllowsQuickLog() {
        XCTAssertTrue(PremiumGate(isPremium: false).isAllowed(.quickLog))
    }
    func testFreeBlocksPaid() {
        let g = PremiumGate(isPremium: false)
        XCTAssertFalse(g.isAllowed(.customPresets))
        XCTAssertFalse(g.isAllowed(.electrolyteTracking))
        XCTAssertFalse(g.isAllowed(.fullHistory))
        XCTAssertFalse(g.isAllowed(.advancedReminders))
    }
    func testPremiumAllowsAll() {
        let g = PremiumGate(isPremium: true)
        for f in [PremiumFeature.quickLog, .customPresets, .electrolyteTracking, .fullHistory, .advancedReminders] {
            XCTAssertTrue(g.isAllowed(f))
        }
    }
    func testFreeReminderCap() {
        let g = PremiumGate(isPremium: false)
        XCTAssertTrue(g.canEnableAnotherReminder(currentCount: 0))
        XCTAssertFalse(g.canEnableAnotherReminder(currentCount: PricingConfig.freeReminderSlots))
    }
    func testFreeCustomPresetCap() {
        let g = PremiumGate(isPremium: false)
        // Default slots = 0 for free, so we can never save a custom one.
        XCTAssertFalse(g.canSaveAnotherCustomPreset(currentCount: 0))
    }
}
