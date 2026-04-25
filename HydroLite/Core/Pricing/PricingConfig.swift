import Foundation

/// Single source of truth for pricing.
enum PricingConfig {
    static let lifetimeProductID = "com.hydrolite.app.lifetime"
    static let monthlyProductID  = "com.hydrolite.app.monthly"
    static let subscriptionGroupID = "hydrolite_premium"

    static let fallbackLifetimeDisplayPrice = "$6.99"
    static let fallbackMonthlyDisplayPrice  = "$1.99"

    static let allProductIDs: [String] = [monthlyProductID, lifetimeProductID]

    static let paywallTitle = "Unlock HydroLite"
    static let paywallSubtitle = "Choose monthly or one-time lifetime unlock."

    static let paywallBenefits: [String] = [
        "Custom drink presets",
        "Electrolyte tracking",
        "Full history and 30-day trends",
        "Advanced reminders with quiet hours",
        "Saved goals and favorites"
    ]

    /// Free-tier caps.
    static let freeCustomPresetSlots = 0      // free users get the default set only
    static let freeReminderSlots = 8
    /// History window in days for free users; premium sees all.
    static let freeHistoryWindow = 3
}
