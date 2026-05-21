import Foundation
import UserNotifications

enum InactivityThreshold: String, CaseIterable, Identifiable {
    case off = "Off"
    case twoHours = "2 hours"
    case fourHours = "4 hours"
    case eightHours = "8 hours"

    var id: String { rawValue }

    var seconds: TimeInterval {
        switch self {
        case .off: return 0
        case .twoHours: return 2 * 3600
        case .fourHours: return 4 * 3600
        case .eightHours: return 8 * 3600
        }
    }
}

final class NotificationManager {
    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    private init() {}

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
    }

    func reschedule() {
        guard UserDefaults.standard.bool(forKey: "notificationsEnabled") else { return }
        let raw = UserDefaults.standard.string(forKey: "inactivityThreshold")
            ?? InactivityThreshold.twoHours.rawValue
        let threshold = InactivityThreshold(rawValue: raw) ?? .twoHours
        guard threshold != .off else { cancelAll(); return }
        cancelAll()
        let content = UNMutableNotificationContent()
        content.title = "Time to focus"
        content.body = "Pick up a task whenever you're ready."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: threshold.seconds, repeats: false)
        center.add(UNNotificationRequest(identifier: "inactivity", content: content, trigger: trigger))
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
