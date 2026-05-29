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
    enum Key {
        static let notificationsEnabled = "notificationsEnabled"
        static let inactivityThreshold = "inactivityThreshold"
        static let animationsEnabled = "animationsEnabled"
        static let colorScheme = "colorScheme"
        static let colorSchemeLight = "light"
        static let colorSchemeDark = "dark"
        static let colorSchemeSystem = "system"
    }

    static let shared = NotificationManager()
    private let center = UNUserNotificationCenter.current()
    private init() {}

    func requestPermission() async -> Bool {
        (try? await center.requestAuthorization(options: [.alert])) ?? false
    }

    func reschedule() {
        guard UserDefaults.standard.bool(forKey: Key.notificationsEnabled) else {
            return
        }
        let raw = UserDefaults.standard.string(forKey: Key.inactivityThreshold)
            ?? InactivityThreshold.twoHours.rawValue
        let threshold = InactivityThreshold(rawValue: raw) ?? .twoHours
        cancelAll()
        guard threshold != .off else {
            return
        }
        let content = UNMutableNotificationContent()
        content.title = String(localized: "Time to focus")
        content.body = String(localized: "You've got tasks waiting.")
        content.interruptionLevel = .active
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: threshold.seconds, repeats: false)
        center.add(UNNotificationRequest(identifier: "inactivity", content: content, trigger: trigger)) { error in
            guard error == nil else {
                DispatchQueue.main.async {
                    UserDefaults.standard.set(false, forKey: Key.notificationsEnabled)
                }
                return
            }
        }
    }

    func cancelAll() {
        center.removeAllPendingNotificationRequests()
    }
}
