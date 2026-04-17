import Foundation

/// Single source of truth for pricing.
enum PricingConfig {
    static let lifetimeProductID = "com.hydrolite.app.lifetime"
    static let fallbackLifetimeDisplayPrice = "$6.99"

    static let paywallTitle = "Unlock HydroLite"
    static let paywallSubtitle = "One-time purchase. No subscriptions."

    static let paywallBenefits: [String] = [
        "Custom drink presets",
        "Electrolyte tracking",
        "Full history and 30-day trends",
        "Advanced reminders with quiet hours",
        "Saved goals and favorites"
    ]

    /// Free-tier caps.
    static let freeCustomPresetSlots = 0      // free users get the default set only
    static let freeReminderSlots = 2
    /// History window in days for free users; premium sees all.
    static let freeHistoryWindow = 7
}
