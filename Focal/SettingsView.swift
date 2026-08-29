import SwiftUI

/// Settings screen: inactivity reminder toggle and threshold, appearance (color scheme), and an
/// animations toggle.
struct SettingsView: View {
    @Environment(TaskStore.self) private var store
    @AppStorage(DefaultsKey.notificationsEnabled) private var notificationsEnabled = false
    @AppStorage(DefaultsKey.inactivityThreshold) private var inactivityThreshold =
        InactivityThreshold.twoHours.rawValue
    @AppStorage(DefaultsKey.animationsEnabled) private var animationsEnabled = true
    @AppStorage(DefaultsKey.colorScheme) private var colorSchemeRaw = DefaultsKey.colorSchemeSystem
    @AppStorage(DefaultsKey.appLockEnabled) private var appLockEnabled = false
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    var body: some View {
        Form {
            Section {
                Toggle("Inactivity reminder", isOn: $notificationsEnabled)
                    .onChange(of: notificationsEnabled) { _, enabled in
                        if enabled {
                            Task {
                                let granted = await NotificationManager.shared.requestPermission()
                                if !granted {
                                    notificationsEnabled = false
                                } else {
                                    store.updateInactivityNotification()
                                }
                            }
                        } else {
                            NotificationManager.shared.cancelAll()
                        }
                    }

                if notificationsEnabled {
                    Picker("Remind after", selection: $inactivityThreshold) {
                        ForEach(InactivityThreshold.allCases) { t in
                            Text(LocalizedStringKey(t.rawValue)).tag(t.rawValue)
                        }
                    }
                    .onChange(of: inactivityThreshold) { _, _ in
                        store.updateInactivityNotification()
                    }
                }
            } footer: {
                Text("One gentle nudge if no task is completed within the chosen period.")
            }

            Section {
                Picker("Appearance", selection: $colorSchemeRaw) {
                    Text("System").tag(DefaultsKey.colorSchemeSystem)
                    Text("Light").tag(DefaultsKey.colorSchemeLight)
                    Text("Dark").tag(DefaultsKey.colorSchemeDark)
                }
                Toggle("Animations", isOn: $animationsEnabled)
            }

            Section {
                Toggle("App Lock", isOn: $appLockEnabled)
            } footer: {
                Text("Require Face ID, Touch ID, or your device passcode to open Focal.")
            }
        }
        .frame(maxWidth: isRegularWidth ? 600 : .infinity)
        .navigationTitle("Settings")
        .navigationBarTitleDisplayMode(.inline)
    }
}
