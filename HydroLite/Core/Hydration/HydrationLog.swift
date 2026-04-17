import Foundation

enum DrinkType: String, Codable, CaseIterable, Hashable {
    case water, electrolyte

    var displayName: String {
        switch self { case .water: return "Water"; case .electrolyte: return "Electrolyte" }
    }

    var symbol: String {
        switch self { case .water: return "drop.fill"; case .electrolyte: return "bolt.fill" }
    }
}

/// A single drink entry. Amount is stored in mL (canonical) so unit conversion is a display concern.
struct HydrationLog: Identifiable, Codable, Hashable {
    let id: UUID
    let timestamp: Date
    let amountMl: Double
    let drinkType: DrinkType

    init(id: UUID = UUID(), timestamp: Date = Date(), amountMl: Double, drinkType: DrinkType = .water) {
        self.id = id
        self.timestamp = timestamp
        self.amountMl = max(0, amountMl)
        self.drinkType = drinkType
    }
}

enum VolumeUnit: String, Codable, CaseIterable, Identifiable {
    case ounces, milliliters
    var id: String { rawValue }

    var displayName: String {
        switch self { case .ounces: return "Ounces (oz)"; case .milliliters: return "Milliliters (mL)" }
    }

    var shortLabel: String {
        switch self { case .ounces: return "oz"; case .milliliters: return "mL" }
    }

    static let ouncesToMl: Double = 29.5735
}

extension Double {
    func ouncesToMl() -> Double { self * VolumeUnit.ouncesToMl }
    func mlToOunces() -> Double { self / VolumeUnit.ouncesToMl }
}
