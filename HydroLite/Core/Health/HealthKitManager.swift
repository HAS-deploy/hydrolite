import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

struct HealthKitManager {
    enum HKStatus { case unavailable, notDetermined, authorized, denied }

    #if canImport(HealthKit)
    private let store: HKHealthStore? = HKHealthStore.isHealthDataAvailable() ? HKHealthStore() : nil
    #endif

    var isAvailable: Bool {
        #if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
        #else
        return false
        #endif
    }

    func requestWaterAuthorization() async -> HKStatus {
        #if canImport(HealthKit)
        guard let store, isAvailable else { return .unavailable }
        let waterType = HKQuantityType(.dietaryWater)
        do {
            try await store.requestAuthorization(toShare: [waterType], read: [waterType])
            return .authorized
        } catch {
            return .denied
        }
        #else
        return .unavailable
        #endif
    }

    /// Write a single water sample to the Health app. Silently no-ops if unavailable/unauthorized.
    func writeWater(amountMl: Double, date: Date = Date()) async {
        #if canImport(HealthKit)
        guard let store, isAvailable, amountMl > 0 else { return }
        let type = HKQuantityType(.dietaryWater)
        let quantity = HKQuantity(unit: .literUnit(with: .milli), doubleValue: amountMl)
        let sample = HKQuantitySample(type: type, quantity: quantity, start: date, end: date)
        _ = try? await store.save(sample)
        #endif
    }
}
