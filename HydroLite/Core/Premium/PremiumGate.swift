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
    let isPremium: Bool

    func isAllowed(_ feature: PremiumFeature) -> Bool {
        if isPremium { return true }
        switch feature {
        case .quickLog:
            return true
        case .customPresets, .electrolyteTracking, .fullHistory, .advancedReminders:
            return false
        }
    }

    func canSaveAnotherCustomPreset(currentCount: Int) -> Bool {
        if isPremium { return true }
        return currentCount < PricingConfig.freeCustomPresetSlots
    }

    func canEnableAnotherReminder(currentCount: Int) -> Bool {
        if isPremium { return true }
        return currentCount < PricingConfig.freeReminderSlots
    }
}
