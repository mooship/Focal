import SwiftUI

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TaskStore.self) private var store
    @State private var title = ""
    @State private var note = ""
    @FocusState private var titleFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                LimitedTextField(label: "Task", text: $title, limit: TaskLimit.titleMax)
                    .focused($titleFocused)
                LimitedTextField(label: "Note (optional)", text: $note, limit: TaskLimit.noteMax)
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addTask(title: title.trimmed, note: note)
                        dismiss()
                    }
                    .disabled(title.trimmed.isEmpty)
                }
            }
        }
        .presentationDetents([.medium, .large])
        .onAppear { titleFocused = true }
    }
}
