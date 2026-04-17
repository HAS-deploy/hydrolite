import Foundation

enum Formatting {
    /// Format a mL amount in the user's preferred unit.
    static func amount(_ ml: Double, unit: VolumeUnit) -> String {
        switch unit {
        case .ounces:
            let oz = ml.mlToOunces()
            // Round to nearest integer for ≥ 4 oz; show 1 decimal below.
            if oz >= 4 { return "\(Int(oz.rounded())) oz" }
            return String(format: "%.1f oz", oz)
        case .milliliters:
            if ml >= 1000 {
                let l = ml / 1000
                return String(format: "%.2f L", l)
            }
            return "\(Int(ml.rounded())) mL"
        }
    }

    static func relativeTime(_ date: Date, now: Date = Date()) -> String {
        let elapsed = Int(now.timeIntervalSince(date))
        if elapsed < 60 { return "just now" }
        if elapsed < 3600 { return "\(elapsed / 60) min ago" }
        if elapsed < 86400 { return "\(elapsed / 3600) h ago" }
        let f = DateFormatter(); f.dateStyle = .medium; f.timeStyle = .none
        return f.string(from: date)
    }

    static func formatDate(_ d: Date, long: Bool = false) -> String {
        let f = DateFormatter()
        f.dateStyle = long ? .medium : .short
        f.timeStyle = .none
        return f.string(from: d)
    }
}
