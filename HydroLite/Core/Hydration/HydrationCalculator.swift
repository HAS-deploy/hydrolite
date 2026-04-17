import Foundation

/// Pure aggregation math over `HydrationLog` sequences. No UI, no persistence.
struct HydrationCalculator {

    /// Total mL from logs matching the given calendar day.
    static func totalMl(logs: [HydrationLog], on day: Date, calendar: Calendar = .current) -> Double {
        logs
            .filter { calendar.isDate($0.timestamp, inSameDayAs: day) }
            .reduce(0) { $0 + $1.amountMl }
    }

    /// Progress fraction 0..1 toward the goal. Returns 0 if goal is zero.
    static func progress(total: Double, goal: Double) -> Double {
        guard goal > 0 else { return 0 }
        return min(1.0, max(0.0, total / goal))
    }

    /// Remaining mL to hit the goal. Clamped at zero.
    static func remaining(total: Double, goal: Double) -> Double {
        max(0, goal - total)
    }

    /// Logs for the last N days (inclusive of today), newest first.
    static func last(_ days: Int, logs: [HydrationLog], now: Date = Date(), calendar: Calendar = .current) -> [HydrationLog] {
        guard let cutoff = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) else {
            return []
        }
        return logs
            .filter { $0.timestamp >= cutoff }
            .sorted { $0.timestamp > $1.timestamp }
    }

    /// Totals for each of the last N days (oldest first), suitable for charts.
    static func dailyTotals(_ days: Int, logs: [HydrationLog], now: Date = Date(), calendar: Calendar = .current) -> [(date: Date, totalMl: Double)] {
        let today = calendar.startOfDay(for: now)
        return (0..<days).reversed().compactMap { offset in
            guard let date = calendar.date(byAdding: .day, value: -offset, to: today) else { return nil }
            let total = totalMl(logs: logs, on: date, calendar: calendar)
            return (date, total)
        }
    }
}
