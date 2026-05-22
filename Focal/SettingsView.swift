import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("notificationsEnabled") private var notificationsEnabled = false
    @AppStorage("inactivityThreshold") private var inactivityThreshold =
        InactivityThreshold.twoHours.rawValue

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
