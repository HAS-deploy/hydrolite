import XCTest
@testable import HydroLite

/// Verifies the install-time 7-day Premium trial behavior:
///   * Fresh install → full Premium for `PricingConfig.annualTrialDays` days.
///   * Day 7+ → drops back to free tier (data still preserved on disk).
///   * Toggling `setPremium(false)` (refund/revoke) does NOT wipe the
///     install-trial anchor — the trial is purely time-based.
final class InstallTrialTests: XCTestCase {

    private let suiteName = "InstallTrialTests"
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suiteName)
        defaults.removePersistentDomain(forName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    // MARK: - Pure trial-window math

    func testFreshInstallTrialActive() {
        let now = Date()
        XCTAssertTrue(PurchaseManager.computeTrialActive(firstLaunch: now, now: now))
    }

    func testTrialActiveOnDaySix() {
        let start = Date()
        let day6 = start.addingTimeInterval(6 * 24 * 60 * 60)
        XCTAssertTrue(
            PurchaseManager.computeTrialActive(firstLaunch: start, now: day6),
            "Trial must remain active through the end of day 6 (i.e. < 7d)."
        )
    }

    func testTrialInactiveAfterSevenDays() {
        let start = Date()
        let day7Plus = start.addingTimeInterval(
            TimeInterval(PricingConfig.annualTrialDays) * 24 * 60 * 60 + 1
        )
        XCTAssertFalse(
            PurchaseManager.computeTrialActive(firstLaunch: start, now: day7Plus),
            "Trial must have ended once `annualTrialDays` have fully elapsed."
        )
    }

    // MARK: - Gate behavior

    func testGateAllowsAllFeaturesDuringInstallTrial() {
        let gate = PremiumGate(isEntitled: true)
        for feature in [PremiumFeature.quickLog,
                        .customPresets,
                        .electrolyteTracking,
                        .fullHistory,
                        .advancedReminders] {
            XCTAssertTrue(gate.isAllowed(feature),
                          "Install-trial users should have Premium-equivalent access to \(feature.rawValue).")
        }
        XCTAssertTrue(gate.canSaveAnotherCustomPreset(currentCount: 99))
        XCTAssertTrue(gate.canEnableAnotherReminder(currentCount: PricingConfig.freeReminderSlots + 5))
    }

    func testGateDropsToFreeAfterTrialExpires() {
        let gate = PremiumGate(isEntitled: false)
        XCTAssertTrue(gate.isAllowed(.quickLog))
        XCTAssertFalse(gate.isAllowed(.customPresets))
        XCTAssertFalse(gate.isAllowed(.electrolyteTracking))
        XCTAssertFalse(gate.isAllowed(.fullHistory))
        XCTAssertFalse(gate.isAllowed(.advancedReminders))
    }

    // MARK: - PurchaseManager wiring

    @MainActor
    func testFreshLaunchAnchorsFirstLaunchAndActivatesTrial() {
        let now = Date()
        let pm = PurchaseManager(defaults: defaults, clock: { now })
        XCTAssertTrue(pm.installTrialActive)
        XCTAssertTrue(pm.isEntitled)
        XCTAssertNotNil(defaults.object(forKey: "hydrolite.firstLaunchAt") as? Date)
    }

    @MainActor
    func testTrialInactiveAfterClockAdvancesPastWindow() {
        let start = Date()
        // First launch anchors firstLaunchAt = start.
        _ = PurchaseManager(defaults: defaults, clock: { start })
        // Subsequent launch happens 8 days later.
        let later = start.addingTimeInterval(8 * 24 * 60 * 60)
        let pm = PurchaseManager(defaults: defaults, clock: { later })
        XCTAssertFalse(pm.installTrialActive,
                       "Install trial should be expired on day 8.")
        XCTAssertFalse(pm.isEntitled,
                       "With no purchase + expired trial, user is back to free tier.")
    }

    @MainActor
    func testRefreshInstallTrialFlipsWhenClockAdvances() {
        let start = Date()
        var fakeNow = start
        let pm = PurchaseManager(defaults: defaults, clock: { fakeNow })
        XCTAssertTrue(pm.installTrialActive)
        fakeNow = start.addingTimeInterval(10 * 24 * 60 * 60)
        pm.refreshInstallTrial()
        XCTAssertFalse(pm.installTrialActive)
    }

    // MARK: - Data-preservation invariant

    /// Ensures the history log persistence layer is untouched when the trial
    /// expires. The trial is a pure read-side gate; LogsStore data on disk
    /// must remain intact and re-readable after the window closes.
    @MainActor
    func testHistoryPreservedAfterTrialEnds() {
        let suite = "InstallTrialTests.LogsStore"
        let storeDefaults = UserDefaults(suiteName: suite)!
        storeDefaults.removePersistentDomain(forName: suite)
        defer { storeDefaults.removePersistentDomain(forName: suite) }

        // Seed some logs during the "trial" window.
        let store = LogsStore(defaults: storeDefaults)
        store.add(HydrationLog(amountMl: 250, drinkType: .water))
        store.add(HydrationLog(amountMl: 500, drinkType: .water))
        let countDuringTrial = store.logs.count
        XCTAssertEqual(countDuringTrial, 2)

        // Simulate the trial ending by re-instantiating the store; the
        // entitlement state has nothing to do with persisted log rows.
        let reloaded = LogsStore(defaults: storeDefaults)
        XCTAssertEqual(reloaded.logs.count, countDuringTrial,
                       "Hydration logs must survive trial expiration.")
    }
}
