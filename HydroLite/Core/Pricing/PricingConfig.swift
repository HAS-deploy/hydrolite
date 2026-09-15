import Foundation

/// Single source of truth for pricing, product IDs, display copy, and the
/// 3.1.2(a) disclosure block. The paywall, `Configuration.storekit`, and
/// the ASC-side products must all agree with these constants.
///
/// Trial-determination model:
///   - Install-time Premium grant is **local** (14 days via `annualTrialDays`).
///     `PurchaseManager.computeTrialActive` / `installTrialDaysRemaining` read
///     that constant. This is not an App Store Connect introductory offer.
///   - Annual product display copy is renewal-only (`annualTrialDescription`);
///     do not advertise an ASC intro length here.
///   - Monthly product carries NO intro offer.
///   - Forfeiture sentence is rendered inline next to the yearly offer AND in
///     the disclosure block per the canonical 3.1.2 pattern.
enum PricingConfig {
    // Product IDs (legacy names kept for source-compat with existing call
    // sites; mirror `ProductIDs` enum for the canonical lookup).
    static let lifetimeProductID = ProductIDs.lifetime
    static let monthlyProductID  = ProductIDs.monthly
    static let annualProductID   = ProductIDs.yearly
    static let subscriptionGroupID = "hydrolite_premium"

    // Display-only fallbacks used when StoreKit `Product.displayPrice` is
    // unavailable (sandbox flake / cold launch). Real prices come from
    // runtime `Product.displayPrice`.
    static let fallbackLifetimeDisplayPrice = "$6.99"
    static let fallbackMonthlyDisplayPrice  = "$1.99"
    static let fallbackAnnualDisplayPrice   = "$14.99"

    static let monthlyDisplayPrice = "$1.99"
    static let annualDisplayPrice  = "$14.99"

    static let allProductIDs: [String] = ProductIDs.all

    static let paywallTitle = "Unlock HydroLite"
    static let paywallSubtitle = "Pick yearly, monthly, or one-time lifetime unlock."

    static let paywallBenefits: [String] = [
        "Electrolyte tracking",
        "Full history and 30-day trends",
        "Advanced reminders with quiet hours",
        "Saved goals and favorites"
    ]

    /// Local install-time Premium grant length (14 days). This is what
    /// `PurchaseManager.computeTrialActive` / `installTrialDaysRemaining`
    /// read. Not an ASC introductory offer.
    static let annualTrialDays: Int = 14
    static let annualTrialDescription: String = "$14.99/year, auto-renews"

    /// 3.1.2(a) disclosures rendered verbatim by the paywall.
    static let disclosurePaymentCharged =
        "Payment will be charged to your Apple ID account at confirmation of purchase."
    static let disclosureAutoRenew =
        "Subscription automatically renews unless canceled at least 24 hours before the end of the current period."
    static let disclosureRenewalCharge =
        "Your account will be charged for renewal within 24 hours prior to the end of the current period."
    static let disclosureManage =
        "Subscriptions may be managed and auto-renewal may be turned off by going to the user's Account Settings after purchase."
    static let disclosureFreeTrial =
        "If you start a free trial, any unused portion is forfeited if you purchase a subscription before the trial ends."

    /// URLs rendered as tappable links in the paywall and ASC metadata.
    static let privacyPolicyURL = "https://has-deploy.github.io/hydrolite/privacy-policy.html"
    static let appleStdEULAURL  = "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/"

    /// Free-tier caps.
    static let freeCustomPresetSlots = 0      // free users get the default set only
    static let freeReminderSlots = 8
    /// History window in days for free users; premium sees all.
    static let freeHistoryWindow = 3
}
