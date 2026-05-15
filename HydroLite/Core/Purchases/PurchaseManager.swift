import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var isPremium: Bool = false
    /// True while the install-time free-trial window (PricingConfig.annualTrialDays)
    /// is still open. Purely time-based off `firstLaunchAt`; independent of
    /// `isPremium` and unaffected by `setPremium(false)`.
    @Published private(set) var installTrialActive: Bool = false
    @Published private(set) var lifetimeProduct: Product?
    @Published private(set) var monthlyProduct: Product?
    @Published private(set) var yearlyProduct: Product?
    @Published private(set) var isPurchasing: Bool = false
    @Published var lastError: String?
    /// Distinguish user-cancel / pending / errors for the analytics layer.
    @Published private(set) var lastFailureReason: String?

    private var updatesTask: Task<Void, Never>?
    private let premiumKey = "hydrolite.isPremium"
    private let firstLaunchKey = "hydrolite.firstLaunchAt"
    private let defaults: UserDefaults
    private let clock: () -> Date

    /// Effective entitlement: paid premium OR inside the install-time trial.
    var isEntitled: Bool { isPremium || installTrialActive }

    init(defaults: UserDefaults = .standard, clock: @escaping () -> Date = Date.init) {
        self.defaults = defaults
        self.clock = clock
        var initial = defaults.bool(forKey: premiumKey)
        #if DEBUG
        if ProcessInfo.processInfo.environment["HYDROLITE_FORCE_PREMIUM"] == "1"
            || defaults.bool(forKey: "HYDROLITE_FORCE_PREMIUM") {
            initial = true
        }
        #endif
        self.isPremium = initial

        // Anchor the install-trial clock on first ever launch.
        let now = clock()
        if defaults.object(forKey: firstLaunchKey) as? Date == nil {
            defaults.set(now, forKey: firstLaunchKey)
        }
        self.installTrialActive = Self.computeTrialActive(
            firstLaunch: defaults.object(forKey: firstLaunchKey) as? Date,
            now: now
        )
    }

    deinit { updatesTask?.cancel() }

    func start() async {
        refreshInstallTrial()
        await loadProducts()
        await refreshEntitlements()
        observeTransactionUpdates()
    }

    /// Recompute `installTrialActive` against the current clock. Safe to call
    /// any time; does not mutate `firstLaunchAt` once it's been anchored.
    func refreshInstallTrial() {
        let stored = defaults.object(forKey: firstLaunchKey) as? Date
        let anchored: Date
        if let stored {
            anchored = stored
        } else {
            anchored = clock()
            defaults.set(anchored, forKey: firstLaunchKey)
        }
        let active = Self.computeTrialActive(firstLaunch: anchored, now: clock())
        if active != self.installTrialActive {
            self.installTrialActive = active
        }
    }

    /// Pure trial-window math, factored out so tests can drive it with a fake
    /// clock without touching UserDefaults timing.
    nonisolated static func computeTrialActive(firstLaunch: Date?, now: Date) -> Bool {
        guard let firstLaunch else { return true }
        let trialEnd = firstLaunch.addingTimeInterval(
            TimeInterval(PricingConfig.annualTrialDays) * 24 * 60 * 60
        )
        return now < trialEnd
    }

    /// Whole days remaining in the install-time trial window (rounded up, min 0).
    /// Returns 0 once the trial has elapsed. Read-only convenience for UI copy
    /// in paywall / Settings disclosure of the install-trial state.
    var installTrialDaysRemaining: Int {
        guard let firstLaunch = defaults.object(forKey: firstLaunchKey) as? Date else {
            return PricingConfig.annualTrialDays
        }
        let trialEnd = firstLaunch.addingTimeInterval(
            TimeInterval(PricingConfig.annualTrialDays) * 24 * 60 * 60
        )
        let remaining = trialEnd.timeIntervalSince(clock())
        guard remaining > 0 else { return 0 }
        return max(0, Int(ceil(remaining / 86400)))
    }

    var lifetimeDisplayPrice: String {
        lifetimeProduct?.displayPrice ?? PricingConfig.fallbackLifetimeDisplayPrice
    }

    var monthlyDisplayPrice: String {
        monthlyProduct?.displayPrice ?? PricingConfig.fallbackMonthlyDisplayPrice
    }

    var yearlyDisplayPrice: String {
        yearlyProduct?.displayPrice ?? PricingConfig.fallbackAnnualDisplayPrice
    }

    func loadProducts() async {
        do {
            let products = try await Product.products(for: PricingConfig.allProductIDs)
            self.lifetimeProduct = products.first { $0.id == PricingConfig.lifetimeProductID }
            self.monthlyProduct  = products.first { $0.id == PricingConfig.monthlyProductID }
            self.yearlyProduct   = products.first { $0.id == PricingConfig.annualProductID }
        } catch {
            self.lastError = "Couldn't load the store. Check your connection and try again."
        }
    }

    func purchaseLifetime() async {
        guard let product = lifetimeProduct else {
            self.lastError = "Product unavailable. Try again in a moment."
            return
        }
        await purchase(product)
    }

    func purchaseMonthly() async {
        guard let product = monthlyProduct else {
            self.lastError = "Product unavailable. Try again in a moment."
            return
        }
        await purchase(product)
    }

    func purchaseYearly() async {
        guard let product = yearlyProduct else {
            self.lastError = "Product unavailable. Try again in a moment."
            return
        }
        await purchase(product)
    }

    private func purchase(_ product: Product) async {
        isPurchasing = true
        defer { isPurchasing = false }
        lastFailureReason = nil
        do {
            let result = try await product.purchase()
            try await handle(result: result, product: product)
        } catch {
            self.lastError = error.localizedDescription
            self.lastFailureReason = error.localizedDescription
            PortfolioAnalytics.shared.trackPaywallFailure(productId: product.id, error: error)
        }
    }

    private func handle(result: Product.PurchaseResult, product: Product) async throws {
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            setPremium(true)
            await transaction.finish()
        case .userCancelled:
            lastFailureReason = "user_cancelled"
            PortfolioAnalytics.shared.trackPaywallFailure(productId: product.id, reason: .userCanceled)
        case .pending:
            self.lastError = "Purchase is pending approval."
            lastFailureReason = "pending_approval"
            PortfolioAnalytics.shared.trackPaywallFailure(productId: product.id, reason: .pending)
        @unknown default:
            lastFailureReason = "storekit_unknown_case"
            PortfolioAnalytics.shared.trackPaywallFailure(productId: product.id, reason: .unknown)
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
            if !isPremium { self.lastError = "No previous purchases found on this Apple ID." }
        } catch {
            self.lastError = error.localizedDescription
            self.lastFailureReason = error.localizedDescription
        }
    }

    private func refreshEntitlements() async {
        #if DEBUG
        if ProcessInfo.processInfo.environment["HYDROLITE_FORCE_PREMIUM"] == "1"
            || defaults.bool(forKey: "HYDROLITE_FORCE_PREMIUM") {
            setPremium(true); return
        }
        #endif
        var entitled = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               PricingConfig.allProductIDs.contains(transaction.productID),
               transaction.revocationDate == nil {
                entitled = true
            }
        }
        setPremium(entitled)
    }

    private func observeTransactionUpdates() {
        updatesTask?.cancel()
        updatesTask = Task.detached { [weak self] in
            for await result in Transaction.updates {
                guard let self else { return }
                if case .verified(let transaction) = result {
                    await self.handleVerifiedUpdate(transaction)
                }
            }
        }
    }

    private func handleVerifiedUpdate(_ transaction: Transaction) async {
        if PricingConfig.allProductIDs.contains(transaction.productID),
           transaction.revocationDate == nil {
            setPremium(true)
        } else if transaction.revocationDate != nil {
            // Refresh in case another active entitlement remains.
            await refreshEntitlements()
        }
        await transaction.finish()
    }

    private func setPremium(_ value: Bool) {
        self.isPremium = value
        defaults.set(value, forKey: premiumKey)
        // NOTE: do NOT touch `firstLaunchAt` or `installTrialActive` here.
        // Install trial is purely time-based; toggling premium off (refund,
        // revocation, debug toggle) must not extend or reset the trial.
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified: throw PurchaseError.failedVerification
        case .verified(let value): return value
        }
    }

    enum PurchaseError: LocalizedError {
        case failedVerification
        var errorDescription: String? { "Purchase could not be verified." }
    }

    #if DEBUG
    func debugTogglePremium() { setPremium(!isPremium) }
    #endif
}
