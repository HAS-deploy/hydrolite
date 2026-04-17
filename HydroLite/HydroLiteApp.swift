import SwiftUI

@main
struct HydroLiteApp: App {
    @StateObject private var purchases = PurchaseManager()
    @StateObject private var settings = SettingsStore()
    @StateObject private var logs = LogsStore()
    @StateObject private var presets = PresetsStore()
    private let analytics: AnalyticsService = ConsoleAnalytics()
    private let reminders = ReminderManager()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(purchases)
                .environmentObject(settings)
                .environmentObject(logs)
                .environmentObject(presets)
                .environment(\.analytics, analytics)
                .environment(\.reminders, reminders)
                .task { await purchases.start() }
                .preferredColorScheme(settings.forcedColorScheme)
        }
    }
}
