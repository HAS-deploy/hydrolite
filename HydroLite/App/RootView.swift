import SwiftUI

struct RootView: View {
    @EnvironmentObject var purchases: PurchaseManager
    @State private var selection: Tab = RootView.initialTab()
    @State private var paywallTrigger: PremiumFeature?

    enum Tab: Hashable { case today, history, settings }

    static func initialTab() -> Tab {
        #if DEBUG
        switch UserDefaults.standard.string(forKey: "HYDROLITE_INITIAL_TAB")
            ?? ProcessInfo.processInfo.environment["HYDROLITE_INITIAL_TAB"] {
        case "history": return .history
        case "settings": return .settings
        default: return .today
        }
        #else
        return .today
        #endif
    }

    var body: some View {
        TabView(selection: $selection) {
            NavigationStack {
                TodayView(onGatedTap: { paywallTrigger = $0 })
                    .trackScreen("today")
            }
            .tabItem { Label("Today", systemImage: "drop.fill") }
            .tag(Tab.today)

            NavigationStack {
                HistoryView(onGatedTap: { paywallTrigger = $0 })
                    .trackScreen("history")
            }
            .tabItem { Label("History", systemImage: "chart.bar") }
            .tag(Tab.history)

            NavigationStack {
                SettingsView()
                    .trackScreen("settings")
            }
            .tabItem { Label("Settings", systemImage: "gearshape") }
            .tag(Tab.settings)
        }
        .tint(Theme.accent)
        .sheet(item: $paywallTrigger) { feature in
            PaywallView(triggeringFeature: feature)
                .environmentObject(purchases)
        }
        .onAppear {
            #if DEBUG
            if UserDefaults.standard.bool(forKey: "HYDROLITE_SHOW_PAYWALL") {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.4) {
                    paywallTrigger = .customPresets
                }
            }
            #endif
        }
    }
}
