import Foundation
import SwiftUI
import Combine

final class SettingsStore: ObservableObject {
    private enum Keys {
        static let units = "settings.units"
        static let dailyGoalMl = "settings.dailyGoalMl"
        static let appearance = "settings.appearance"
        static let quietHoursStart = "settings.quietHoursStart"
        static let quietHoursEnd = "settings.quietHoursEnd"
    }

    enum Appearance: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: String { rawValue }
        var label: String { switch self { case .system: return "System"; case .light: return "Light"; case .dark: return "Dark" } }
    }

    @Published var units: VolumeUnit { didSet { defaults.set(units.rawValue, forKey: Keys.units) } }
    @Published var dailyGoalMl: Double { didSet { defaults.set(dailyGoalMl, forKey: Keys.dailyGoalMl) } }
    @Published var appearance: Appearance { didSet { defaults.set(appearance.rawValue, forKey: Keys.appearance) } }
    /// Hour of day (0-23) when quiet hours start.
    @Published var quietHoursStart: Int { didSet { defaults.set(quietHoursStart, forKey: Keys.quietHoursStart) } }
    @Published var quietHoursEnd: Int { didSet { defaults.set(quietHoursEnd, forKey: Keys.quietHoursEnd) } }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        // First-launch default follows the device's measurement system so users
        // in metric regions (everywhere outside US/Liberia/Myanmar) don't see
        // ounces on open. Stored value, once present, always wins.
        let defaultUnit: VolumeUnit = (Locale.current.measurementSystem == .us) ? .ounces : .milliliters
        self.units = VolumeUnit(rawValue: defaults.string(forKey: Keys.units) ?? defaultUnit.rawValue) ?? defaultUnit
        let storedGoal = defaults.object(forKey: Keys.dailyGoalMl) as? Double
        // Default daily goal: 64 oz (≈1.9 L) for US, 2000 mL for metric regions.
        let defaultGoalMl: Double = (Locale.current.measurementSystem == .us) ? (64.0 * VolumeUnit.ouncesToMl) : 2000.0
        self.dailyGoalMl = storedGoal ?? defaultGoalMl
        self.appearance = Appearance(rawValue: defaults.string(forKey: Keys.appearance) ?? "system") ?? .system
        self.quietHoursStart = (defaults.object(forKey: Keys.quietHoursStart) as? Int) ?? 22
        self.quietHoursEnd = (defaults.object(forKey: Keys.quietHoursEnd) as? Int) ?? 7
    }

    var forcedColorScheme: ColorScheme? {
        switch appearance { case .system: return nil; case .light: return .light; case .dark: return .dark }
    }

    /// Display-space goal value in the user's unit.
    var dailyGoalInUnits: Double {
        units == .ounces ? dailyGoalMl.mlToOunces() : dailyGoalMl
    }

    func setDailyGoal(inUnits value: Double) {
        dailyGoalMl = units == .ounces ? value.ouncesToMl() : value
    }
}
