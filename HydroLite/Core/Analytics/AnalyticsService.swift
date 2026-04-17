import Foundation
import SwiftUI

enum AnalyticsEvent: String {
    case waterLogged = "water_logged"
    case goalChanged = "goal_changed"
    case reminderEnabled = "reminder_enabled"
    case paywallViewed = "paywall_viewed"
    case purchaseStarted = "purchase_started"
    case purchaseCompleted = "purchase_completed"
    case restorePurchasesTapped = "restore_purchases_tapped"
}

protocol AnalyticsService {
    func track(_ event: AnalyticsEvent, properties: [String: String])
}

extension AnalyticsService {
    func track(_ event: AnalyticsEvent) { track(event, properties: [:]) }
}

struct ConsoleAnalytics: AnalyticsService {
    func track(_ event: AnalyticsEvent, properties: [String: String]) {
        #if DEBUG
        let props = properties.isEmpty ? "" : " " + properties.map { "\($0)=\($1)" }.joined(separator: " ")
        print("📊 \(event.rawValue)\(props)")
        #endif
    }
}

struct NoopAnalytics: AnalyticsService {
    func track(_ event: AnalyticsEvent, properties: [String: String]) {}
}

private struct AnalyticsKey: EnvironmentKey {
    static let defaultValue: AnalyticsService = NoopAnalytics()
}

extension EnvironmentValues {
    var analytics: AnalyticsService {
        get { self[AnalyticsKey.self] }
        set { self[AnalyticsKey.self] = newValue }
    }
}
