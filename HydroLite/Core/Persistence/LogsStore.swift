import Foundation
import Combine

final class LogsStore: ObservableObject {
    private enum Keys { static let logs = "logs.entries" }
    @Published private(set) var logs: [HydrationLog] = []
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.logs = Self.decode([HydrationLog].self, defaults: defaults, key: Keys.logs) ?? []
        self.logs.sort { $0.timestamp > $1.timestamp }
    }

    func add(_ log: HydrationLog) {
        logs.insert(log, at: 0)
        // Cap at 5000 entries to avoid unbounded growth. That's years of use.
        if logs.count > 5000 { logs = Array(logs.prefix(5000)) }
        persist()
    }

    func remove(id: UUID) {
        logs.removeAll { $0.id == id }
        persist()
    }

    /// Remove the most recent log (undo last quick-add).
    @discardableResult
    func undoLast() -> HydrationLog? {
        guard let first = logs.first else { return nil }
        logs.removeFirst()
        persist()
        return first
    }

    func clearAll() {
        logs.removeAll()
        persist()
    }

    // MARK: - Aggregations (pass-through to the pure calculator)

    func totalMl(on day: Date = Date()) -> Double {
        HydrationCalculator.totalMl(logs: logs, on: day)
    }

    func todayLogs() -> [HydrationLog] {
        let cal = Calendar.current
        return logs.filter { cal.isDate($0.timestamp, inSameDayAs: Date()) }
    }

    // MARK: - Persistence

    private func persist() {
        if let data = try? JSONEncoder().encode(logs) {
            defaults.set(data, forKey: Keys.logs)
        }
    }

    private static func decode<T: Decodable>(_ t: T.Type, defaults: UserDefaults, key: String) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(T.self, from: data)
    }
}
