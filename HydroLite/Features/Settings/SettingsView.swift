import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var purchases: PurchaseManager
    @EnvironmentObject var logs: LogsStore
    @Environment(\.analytics) private var analytics
    @Environment(\.reminders) private var reminders

    @State private var showPaywall = false
    @State private var remindersEnabled = false
    @State private var intervalMinutes: Int = 120
    @State private var reminderAuthStatus: ReminderManager.AuthStatus = .notDetermined

    private let reminderPrefix = "hydrolite.reminder"

    var body: some View {
        Form {
            premiumSection
            remindersSection
            goalSection
            unitsSection
            dataSection
            aboutSection
            #if DEBUG
            debugSection
            #endif
        }
        .navigationTitle("Settings")
        .task {
            reminderAuthStatus = await reminders.currentStatus()
            let pending = await reminders.pendingIdentifiers()
            remindersEnabled = pending.contains(where: { $0.hasPrefix(reminderPrefix) })
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(triggeringFeature: .advancedReminders)
                .environmentObject(purchases)
        }
    }

    private var premiumSection: some View {
        Section {
            if purchases.isPremium {
                Label("Premium unlocked", systemImage: "checkmark.seal.fill").foregroundStyle(Theme.accent)
            } else {
                Button { showPaywall = true } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("Unlock everything").font(.headline)
                            Text("One-time \(purchases.lifetimeDisplayPrice). No subscription.")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right").foregroundStyle(.secondary)
                    }
                }
                Button("Restore purchases") {
                    analytics.track(.restorePurchasesTapped)
                    Task { await purchases.restorePurchases() }
                }
            }
        } header: { Text("HydroLite Premium") }
    }

    @ViewBuilder
    private var remindersSection: some View {
        Section {
            Toggle("Hourly water reminders", isOn: $remindersEnabled)
                .onChange(of: remindersEnabled) { enabled in
                    Task { await handleRemindersToggle(enabled) }
                }
            if remindersEnabled {
                Stepper("Every \(intervalMinutes) min", value: $intervalMinutes, in: 30...240, step: 30)
                    .onChange(of: intervalMinutes) { _ in Task { await reschedule() } }
                quietHoursControls
            }
            if reminderAuthStatus == .denied {
                Text("Notifications are disabled for HydroLite. Enable them in iOS Settings to use reminders.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        } header: { Text("Reminders") } footer: {
            Text("Reminders fire at the chosen interval during waking hours only.")
        }
    }

    private var quietHoursControls: some View {
        VStack(alignment: .leading) {
            Stepper("Quiet start: \(formattedHour(settings.quietHoursStart))", value: $settings.quietHoursStart, in: 0...23)
                .onChange(of: settings.quietHoursStart) { _ in Task { await reschedule() } }
            Stepper("Quiet end: \(formattedHour(settings.quietHoursEnd))", value: $settings.quietHoursEnd, in: 0...23)
                .onChange(of: settings.quietHoursEnd) { _ in Task { await reschedule() } }
        }
    }

    private func formattedHour(_ h: Int) -> String {
        var c = Calendar.current.dateComponents([.year,.month,.day], from: Date())
        c.hour = h; c.minute = 0
        let d = Calendar.current.date(from: c) ?? Date()
        let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short
        return f.string(from: d)
    }

    private var goalSection: some View {
        Section {
            Stepper(
                value: Binding(
                    get: { settings.dailyGoalInUnits },
                    set: { settings.setDailyGoal(inUnits: $0); analytics.track(.goalChanged) }
                ),
                in: settings.units == .ounces ? 20.0...160.0 : 500.0...5000.0,
                step: settings.units == .ounces ? 4.0 : 100.0
            ) {
                Text("Daily goal: \(Formatting.amount(settings.dailyGoalMl, unit: settings.units))")
            }
        } header: { Text("Goal") } footer: {
            Text("General default; adjust to what works for you. Not medical advice.")
        }
    }

    private var unitsSection: some View {
        Section {
            Picker("Units", selection: $settings.units) {
                ForEach(VolumeUnit.allCases) { u in Text(u.displayName).tag(u) }
            }
            Picker("Appearance", selection: $settings.appearance) {
                ForEach(SettingsStore.Appearance.allCases) { a in Text(a.label).tag(a) }
            }
        } header: { Text("Display") }
    }

    private var dataSection: some View {
        Section {
            Button(role: .destructive) { logs.clearAll() } label: {
                Label("Clear all logs", systemImage: "trash")
            }
        } header: { Text("Data") } footer: {
            Text("Clears logs on this device. Cannot be undone.")
        }
    }

    private var aboutSection: some View {
        Section {
            Link("Privacy policy", destination: URL(string: "https://has-deploy.github.io/hydrolite/privacy-policy.html")!)
            Link("Support", destination: URL(string: "https://has-deploy.github.io/hydrolite/support.html")!)
            LabeledContent("Version", value: Bundle.main.marketingVersion)
            LabeledContent("Total logs", value: "\(logs.logs.count)")
        } header: { Text("About") } footer: {
            Text("HydroLite is a simple hydration logger. Not medical advice.")
        }
    }

    #if DEBUG
    private var debugSection: some View {
        Section("Developer (DEBUG only)") {
            Button(purchases.isPremium ? "Disable premium (debug)" : "Enable premium (debug)") {
                purchases.debugTogglePremium()
            }
        }
    }
    #endif

    private func handleRemindersToggle(_ enabled: Bool) async {
        guard enabled else {
            reminders.cancelAll(prefixedWith: reminderPrefix); return
        }
        if reminderAuthStatus == .notDetermined {
            let granted = await reminders.requestAuthorization()
            reminderAuthStatus = granted ? .authorized : .denied
            if !granted { remindersEnabled = false; return }
        } else if reminderAuthStatus == .denied {
            remindersEnabled = false; return
        }
        let gate = PremiumGate(isPremium: purchases.isPremium)
        // Free users: cap at max PricingConfig.freeReminderSlots reminders.
        // If interval would produce more slots than allowed, bump the user to paywall.
        let waking = 24 - (settings.quietHoursEnd >= settings.quietHoursStart ? (settings.quietHoursEnd - settings.quietHoursStart) : (24 - settings.quietHoursStart + settings.quietHoursEnd))
        let predicted = max(1, (waking * 60) / intervalMinutes)
        if !gate.canEnableAnotherReminder(currentCount: predicted - 1) {
            remindersEnabled = false
            showPaywall = true
            return
        }
        await reschedule()
        analytics.track(.reminderEnabled, properties: ["interval": "\(intervalMinutes)"])
    }

    private func reschedule() async {
        do {
            _ = try await reminders.scheduleIntervalReminders(
                prefix: reminderPrefix,
                title: "Hydrate",
                body: "Time for a quick sip of water.",
                intervalMinutes: intervalMinutes,
                quietStartHour: settings.quietHoursStart,
                quietEndHour: settings.quietHoursEnd
            )
        } catch {
            remindersEnabled = false
        }
    }
}

private extension Bundle {
    var marketingVersion: String {
        (infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }
}
