import Foundation

enum PremiumFeature: String, Identifiable, Hashable {
    case quickLog
    case customPresets
    case electrolyteTracking
    case fullHistory
    case advancedReminders

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .quickLog: return "Quick Log"
        case .customPresets: return "Custom Presets"
        case .electrolyteTracking: return "Electrolyte Tracking"
        case .fullHistory: return "Full History"
        case .advancedReminders: return "Advanced Reminders"
        }
    }
}

struct PremiumGate {
    /// Effective entitlement: paid premium OR inside the install-time free
    /// trial. Call sites should pass `purchases.isEntitled`, not raw
    /// `isPremium`, so install-trial users get the full Premium experience.
    let isEntitled: Bool

    init(isEntitled: Bool) {
        self.isEntitled = isEntitled
    }

    /// Back-compat shim for older call sites that still pass `isPremium:`.
    /// Treats premium and entitled identically.
    init(isPremium: Bool) {
        self.isEntitled = isPremium
    }

    func isAllowed(_ feature: PremiumFeature) -> Bool {
        if isEntitled { return true }
        switch feature {
        case .quickLog:
            return true
        case .customPresets, .electrolyteTracking, .fullHistory, .advancedReminders:
            return false
        }
    }

    func canSaveAnotherCustomPreset(currentCount: Int) -> Bool {
        if isEntitled { return true }
        return currentCount < PricingConfig.freeCustomPresetSlots
    }

    func canEnableAnotherReminder(currentCount: Int) -> Bool {
        if isEntitled { return true }
        return currentCount < PricingConfig.freeReminderSlots
    }
}
