import Foundation
import Combine

struct DrinkPreset: Identifiable, Codable, Hashable {
    let id: UUID
    var label: String
    /// Amount in mL (canonical).
    var amountMl: Double
    var drinkType: DrinkType
    var isBuiltIn: Bool

    init(id: UUID = UUID(), label: String, amountMl: Double, drinkType: DrinkType = .water, isBuiltIn: Bool = false) {
        self.id = id
        self.label = label
        self.amountMl = max(1, amountMl)
        self.drinkType = drinkType
        self.isBuiltIn = isBuiltIn
    }

    func displayAmount(in unit: VolumeUnit) -> String {
        switch unit {
        case .ounces:
            let oz = amountMl.mlToOunces()
            let rounded = Int(oz.rounded())
            return "\(rounded) oz"
        case .milliliters:
            return "\(Int(amountMl.rounded())) mL"
        }
    }
}

/// Built-in drink presets shown to every user. Free users can only use these.
enum BuiltInPresets {
    static let ounceSet: [DrinkPreset] = [
        DrinkPreset(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B1")!, label: "8 oz", amountMl: (8 as Double).ouncesToMl(), isBuiltIn: true),
        DrinkPreset(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B2")!, label: "12 oz", amountMl: (12 as Double).ouncesToMl(), isBuiltIn: true),
        DrinkPreset(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B3")!, label: "16 oz", amountMl: (16 as Double).ouncesToMl(), isBuiltIn: true),
        DrinkPreset(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B4")!, label: "20 oz", amountMl: (20 as Double).ouncesToMl(), isBuiltIn: true),
    ]
    static let metricSet: [DrinkPreset] = [
        DrinkPreset(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B5")!, label: "250 mL", amountMl: 250, isBuiltIn: true),
        DrinkPreset(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B6")!, label: "500 mL", amountMl: 500, isBuiltIn: true),
        DrinkPreset(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B7")!, label: "750 mL", amountMl: 750, isBuiltIn: true),
        DrinkPreset(id: UUID(uuidString: "00000000-0000-0000-0000-0000000000B8")!, label: "1 L", amountMl: 1000, isBuiltIn: true),
    ]
    static func set(for unit: VolumeUnit) -> [DrinkPreset] {
        unit == .ounces ? ounceSet : metricSet
    }
}

final class PresetsStore: ObservableObject {
    private enum Keys { static let presets = "presets.custom" }
    @Published private(set) var customPresets: [DrinkPreset] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.customPresets = Self.decode([DrinkPreset].self, defaults: defaults, key: Keys.presets) ?? []
    }

    func addOrUpdate(_ preset: DrinkPreset) {
        if let idx = customPresets.firstIndex(where: { $0.id == preset.id }) {
            customPresets[idx] = preset
        } else {
            customPresets.append(preset)
        }
        persist()
    }

    func remove(id: UUID) {
        customPresets.removeAll { $0.id == id }
        persist()
    }

    func remove(at offsets: IndexSet) {
        for i in offsets.sorted(by: >) where customPresets.indices.contains(i) {
            customPresets.remove(at: i)
        }
        persist()
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(customPresets) {
            defaults.set(data, forKey: Keys.presets)
        }
    }

    private static func decode<T: Decodable>(_ t: T.Type, defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
