import Foundation
import SwiftUI
import UserNotifications

struct ReminderManager {
    enum AuthStatus { case notDetermined, denied, authorized, provisional }

    func currentStatus() async -> AuthStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        switch settings.authorizationStatus {
        case .notDetermined: return .notDetermined
        case .denied: return .denied
        case .authorized, .ephemeral: return .authorized
        case .provisional: return .provisional
        @unknown default: return .denied
        }
    }

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch { return false }
    }

    /// Schedule a repeating daily reminder at a fixed time.
    func scheduleDailyReminder(identifier: String, title: String, body: String, hour: Int, minute: Int) async throws {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        var components = DateComponents(); components.hour = hour; components.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    /// Schedule multiple reminders across a waking window at a given interval in minutes.
    /// Skips any hour that falls inside the [quietStart, quietEnd) quiet window.
    func scheduleIntervalReminders(
        prefix: String,
        title: String,
        body: String,
        intervalMinutes: Int,
        quietStartHour: Int,
        quietEndHour: Int
    ) async throws -> Int {
        cancelAll(prefixedWith: prefix)
        let minutes = max(30, intervalMinutes)
        var scheduled = 0
        for totalMin in stride(from: 0, to: 24 * 60, by: minutes) {
            let hour = totalMin / 60
            let minute = totalMin % 60
            if inQuiet(hour: hour, start: quietStartHour, end: quietEndHour) { continue }
            let id = "\(prefix).\(hour).\(minute)"
            try await scheduleDailyReminder(identifier: id, title: title, body: body, hour: hour, minute: minute)
            scheduled += 1
        }
        return scheduled
    }

    private func inQuiet(hour: Int, start: Int, end: Int) -> Bool {
        if start == end { return false }
        if start < end { return hour >= start && hour < end }
        // Wraps midnight (e.g. 22..7)
        return hour >= start || hour < end
    }

    func cancel(identifier: String) {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    func cancelAll() {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
    }

    func cancelAll(prefixedWith prefix: String) {
        UNUserNotificationCenter.current().getPendingNotificationRequests { reqs in
            let ids = reqs.map(\.identifier).filter { $0.hasPrefix(prefix) }
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ids)
        }
    }

    func pendingIdentifiers() async -> [String] {
        let requests = await UNUserNotificationCenter.current().pendingNotificationRequests()
        return requests.map { $0.identifier }
    }
}

private struct ReminderManagerKey: EnvironmentKey {
    static let defaultValue = ReminderManager()
}

extension EnvironmentValues {
    var reminders: ReminderManager {
        get { self[ReminderManagerKey.self] }
        set { self[ReminderManagerKey.self] = newValue }
    }
}
