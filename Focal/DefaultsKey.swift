import Foundation

/// Single source of truth for all `UserDefaults`/`@AppStorage` key strings and color scheme value constants.
enum DefaultsKey {
    static let notificationsEnabled = "notificationsEnabled"
    static let inactivityThreshold = "inactivityThreshold"
    static let animationsEnabled = "animationsEnabled"
    static let appLockEnabled = "appLockEnabled"
    static let hasCompletedTask = "hasCompletedTask"
    static let colorScheme = "colorScheme"
    static let colorSchemeLight = "light"
    static let colorSchemeDark = "dark"
    static let colorSchemeSystem = "system"
}
