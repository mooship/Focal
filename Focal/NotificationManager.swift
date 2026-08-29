import Foundation
import UserNotifications

/// How long the app can sit untouched before an inactivity notification fires, as offered in Settings.
enum InactivityThreshold: String, CaseIterable, Identifiable {
    case twoHours = "2 hours"
    case fourHours = "4 hours"
    case eightHours = "8 hours"

    var id: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .twoHours: return 2 * 3600
        case .fourHours: return 4 * 3600
        case .eightHours: return 8 * 3600
        }
    }
}

/// Singleton that schedules the single "you've got tasks waiting" local notification. `TaskStore`
/// calls `reschedule()`/`cancelAll()` whenever the current task or queue state changes.
final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    /// Coalesces bursts of `reschedule()` calls (e.g. rapid queue-changing actions in `TaskStore`)
    /// into a single notification-center round trip.
    private var rescheduleTask: Task<Void, Never>?
    private init() {}

    /// Requests permission to show alerts; returns whether it was granted.
    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert])) ?? false
    }

    /// Debounces briefly, then cancels any pending inactivity notification and, if notifications
    /// are enabled in Settings, schedules a new one to fire after the configured threshold. Turns
    /// notifications off in Settings if scheduling fails.
    func reschedule() {
        rescheduleTask?.cancel()
        rescheduleTask = Task { @MainActor in
            do {
                try await Task.sleep(for: .milliseconds(300))
                self.performReschedule()
            } catch {}
        }
    }

    private func performReschedule() {
        guard UserDefaults.standard.bool(forKey: DefaultsKey.notificationsEnabled) else {
            return
        }
        let raw = UserDefaults.standard.string(forKey: DefaultsKey.inactivityThreshold)
            ?? InactivityThreshold.twoHours.rawValue
        let threshold = InactivityThreshold(rawValue: raw) ?? .twoHours
        cancelAll()
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time to focus")
        content.body = String(localized: "You've got tasks waiting.")
        content.interruptionLevel = .active
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: threshold.seconds, repeats: false)
        center.add(UNNotificationRequest(identifier: "inactivity", content: content, trigger: trigger)) { error in
            guard error == nil else {
                DispatchQueue.main.async {
                    UserDefaults.standard.set(false, forKey: DefaultsKey.notificationsEnabled)
                }
                return
            }
        }
    }

    /// Removes all pending (not yet delivered) inactivity notifications, including any debounced
    /// `reschedule()` that hasn't fired yet.
    func cancelAll() {
        rescheduleTask?.cancel()
        rescheduleTask = nil
        center.removeAllPendingNotificationRequests()
    }
}
