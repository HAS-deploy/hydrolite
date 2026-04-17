import SwiftUI

struct HistoryView: View {
    @EnvironmentObject var logs: LogsStore
    @EnvironmentObject var settings: SettingsStore
    @EnvironmentObject var purchases: PurchaseManager

    let onGatedTap: (PremiumFeature) -> Void

    private var windowDays: Int {
        purchases.isPremium ? 30 : PricingConfig.freeHistoryWindow
    }

    private var dailyTotals: [(date: Date, totalMl: Double)] {
        HydrationCalculator.dailyTotals(windowDays, logs: logs.logs)
    }

    var body: some View {
        List {
            Section {
                weeklyBars
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } header: {
                Text("Last \(windowDays) days")
            }

            Section("Recent logs") {
                let recent = Array(logs.logs.prefix(50))
                if recent.isEmpty {
                    Text("No logs yet.").foregroundStyle(.secondary)
                } else {
                    ForEach(recent) { log in logRow(log) }
                        .onDelete { offsets in
                            let ids = offsets.map { recent[$0].id }
                            ids.forEach { logs.remove(id: $0) }
                        }
                }
            }

            if !purchases.isPremium {
                Section {
                    UpsellCard(
                        title: "See your full history",
                        message: "Premium unlocks every log and a 30-day trend, not just \(PricingConfig.freeHistoryWindow) days.",
                        feature: .fullHistory,
                        onTap: onGatedTap
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }
            }
        }
        .navigationTitle("History")
    }

    private func logRow(_ log: HydrationLog) -> some View {
        HStack {
            Image(systemName: log.drinkType.symbol).foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text(Formatting.amount(log.amountMl, unit: settings.units))
                    .font(.body.weight(.semibold))
                    .monospacedDigit()
                Text(log.drinkType.displayName)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatting.relativeTime(log.timestamp))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(Formatting.formatDate(log.timestamp))
                    .font(.caption2)
                    .foregroundStyle(Theme.subtle)
            }
        }
    }

    private var weeklyBars: some View {
        let max = dailyTotals.map(\.totalMl).max() ?? 1
        return HStack(alignment: .bottom, spacing: 6) {
            ForEach(dailyTotals, id: \.date) { pair in
                VStack(spacing: 6) {
                    GeometryReader { geo in
                        let fraction = max > 0 ? CGFloat(pair.totalMl / max) : 0
                        ZStack(alignment: .bottom) {
                            Rectangle().fill(Color(.tertiarySystemFill))
                            Rectangle().fill(Theme.accent).frame(height: geo.size.height * fraction)
                        }
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                    }
                    Text(dayLabel(pair.date))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(height: 140)
        .padding()
    }

    private func dayLabel(_ date: Date) -> String {
        let f = DateFormatter(); f.dateFormat = "EEE"; return String(f.string(from: date).prefix(1))
    }
}
