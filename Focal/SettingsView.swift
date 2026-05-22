import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(NotificationManager.Key.notificationsEnabled) private var notificationsEnabled = false
    @AppStorage(NotificationManager.Key.inactivityThreshold) private var inactivityThreshold =
        InactivityThreshold.twoHours.rawValue
    @AppStorage(NotificationManager.Key.animationsEnabled) private var animationsEnabled = true
    @AppStorage(NotificationManager.Key.colorScheme) private var colorSchemeRaw = "system"

    var body: some View {
        NavigationStack {
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
                                        NotificationManager.shared.reschedule()
                                    }
                                }
                            } else {
                                NotificationManager.shared.cancelAll()
                            }
                        }

                    if notificationsEnabled {
                        Picker("Remind after", selection: $inactivityThreshold) {
                            ForEach(InactivityThreshold.allCases.filter { $0 != .off }) { t in
                                Text(t.rawValue).tag(t.rawValue)
                            }
                        }
                        .onChange(of: inactivityThreshold) { _, _ in
                            NotificationManager.shared.reschedule()
                        }
                    }
                } footer: {
                    Text("One gentle nudge if no task is completed within the chosen period.")
                }

                Section {
                    Picker("Appearance", selection: $colorSchemeRaw) {
                        Text("System").tag(NotificationManager.Key.colorSchemeSystem)
                        Text("Light").tag(NotificationManager.Key.colorSchemeLight)
                        Text("Dark").tag(NotificationManager.Key.colorSchemeDark)
                    }
                    Toggle("Animations", isOn: $animationsEnabled)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
