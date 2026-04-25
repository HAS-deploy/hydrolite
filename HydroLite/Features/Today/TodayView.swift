import SwiftUI

struct TodayView: View {
    @EnvironmentObject var purchases: PurchaseManager
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var logs: LogsStore
    @EnvironmentObject var presets: PresetsStore
    @Environment(\.analytics) private var analytics

    let onGatedTap: (PremiumFeature) -> Void

    @State private var lastUndoAt: Date? = nil
    @State private var selectedType: DrinkType = .water

    private var gate: PremiumGate { PremiumGate(isPremium: purchases.isPremium) }

    private var total: Double { logs.totalMl() }
    private var goal: Double { settings.dailyGoalMl }
    private var progress: Double { HydrationCalculator.progress(total: total, goal: goal) }
    private var remaining: Double { HydrationCalculator.remaining(total: total, goal: goal) }

    private var displayPresets: [DrinkPreset] {
        var result = BuiltInPresets.set(for: settings.units)
        if purchases.isPremium { result.append(contentsOf: presets.customPresets) }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(spacing: Theme.stackSpacing) {
                progressRing
                drinkTypeToggle
                presetGrid
                recentCard
                if !purchases.isPremium { upsellCard }
                disclaimer
            }
            .padding()
            .padding(.bottom, 24)
        }
        .navigationTitle("Today")
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    if let removed = logs.undoLast() {
                        lastUndoAt = Date()
                        analytics.track(.waterLogged, properties: ["action": "undo", "ml": String(Int(removed.amountMl))])
                    }
                } label: {
                    Label("Undo", systemImage: "arrow.uturn.backward")
                }
                .disabled(logs.todayLogs().isEmpty)
            }
        }
    }

    // MARK: - Pieces

    private var progressRing: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .stroke(Color(.tertiarySystemFill), lineWidth: 18)
                Circle()
                    .trim(from: 0, to: CGFloat(progress))
                    .stroke(Theme.accent, style: StrokeStyle(lineWidth: 18, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.35), value: progress)
                VStack(spacing: 4) {
                    Text(Formatting.amount(total, unit: settings.units))
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("of \(Formatting.amount(goal, unit: settings.units))")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    if remaining > 0 {
                        Text("\(Formatting.amount(remaining, unit: settings.units)) to go")
                            .font(.caption)
                            .foregroundStyle(Theme.subtle)
                    } else {
                        Text("Goal reached — nice work.")
                            .font(.caption)
                            .foregroundStyle(Theme.accent)
                    }
                }
            }
            .frame(width: 240, height: 240)
        }
    }

    private var drinkTypeToggle: some View {
        Group {
            if gate.isAllowed(.electrolyteTracking) {
                Picker("Drink type", selection: $selectedType) {
                    ForEach(DrinkType.allCases, id: \.self) { t in
                        Label(t.displayName, systemImage: t.symbol).tag(t)
                    }
                }
                .pickerStyle(.segmented)
            } else {
                // Silent no-op for free users; electrolyte is behind the paywall.
                EmptyView()
            }
        }
    }

    private var presetGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(displayPresets) { preset in
                Button {
                    logAmount(preset.amountMl, type: selectedType, source: preset.isBuiltIn ? "preset" : "custom")
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: preset.drinkType.symbol)
                            .font(.title2)
                        Text(preset.displayAmount(in: settings.units))
                            .font(.title3.weight(.semibold))
                            .monospacedDigit()
                        Text(preset.label)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 18)
                    .background(Theme.accent)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var recentCard: some View {
        Card {
            VStack(alignment: .leading, spacing: 8) {
                Text("Recent").font(.headline)
                let today = logs.todayLogs().prefix(3)
                if today.isEmpty {
                    Text("No logs yet today. Tap a preset above to start.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(today), id: \.id) { log in
                        HStack {
                            Image(systemName: log.drinkType.symbol)
                                .foregroundStyle(Theme.accent)
                            Text(Formatting.amount(log.amountMl, unit: settings.units))
                                .font(.body.weight(.semibold))
                                .monospacedDigit()
                            Spacer()
                            Text(Formatting.relativeTime(log.timestamp))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var upsellCard: some View {
        UpsellCard(
            title: "Unlock HydroLite",
            message: "Custom presets, electrolyte tracking, full history, and advanced reminders.",
            feature: .customPresets,
            onTap: onGatedTap
        )
    }

    private var disclaimer: some View {
        Text("HydroLite helps you track water intake. It is not medical advice.")
            .font(.caption2)
            .foregroundStyle(Theme.subtle)
    }

    private func logAmount(_ ml: Double, type: DrinkType, source: String = "preset") {
        let previousTotal = logs.totalMl()
        let log = HydrationLog(amountMl: ml, drinkType: purchases.isPremium ? type : .water)
        logs.add(log)
        analytics.track(.waterLogged, properties: ["ml": String(Int(ml)), "type": log.drinkType.rawValue])

        let amountOz = Int((ml / VolumeUnit.ouncesToMl).rounded())
        PortfolioAnalytics.shared.track("hydration.logged", [
            "amount_oz": amountOz,
            "source": source,
        ])

        // Fire daily_goal_hit the moment we cross the goal line.
        let newTotal = logs.totalMl()
        if previousTotal < goal && newTotal >= goal {
            let goalOz = Int((goal / VolumeUnit.ouncesToMl).rounded())
            let hour = Calendar.current.component(.hour, from: Date())
            PortfolioAnalytics.shared.track("daily_goal_hit", [
                "goal_oz": goalOz,
                "at_hour": hour,
            ])
        }
    }
}

struct UpsellCard: View {
    let title: String
    let message: String
    let feature: PremiumFeature
    let onTap: (PremiumFeature) -> Void

    var body: some View {
        Button { onTap(feature) } label: {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: "lock.fill").font(.headline)
                Text(message).font(.subheadline).foregroundStyle(.secondary)
                Text("Unlock for a one-time purchase")
                    .font(.caption)
                    .foregroundStyle(Theme.accent)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: Theme.cornerRadius, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}
