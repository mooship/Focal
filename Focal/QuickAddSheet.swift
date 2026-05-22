import SwiftUI

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TaskStore.self) private var store
    @State private var title = ""
    @State private var note = ""
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var titleFocused: Bool

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    var body: some View {
        NavigationStack {
            Form {
                LimitedTextField(label: "Task", text: $title, limit: TaskLimit.titleMax)
                    .focused($titleFocused)
                LimitedTextField(label: "Note (optional)", text: $note, limit: TaskLimit.noteMax)
            }
            .frame(maxWidth: isRegularWidth ? 600 : .infinity)
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
        .presentationBackground(.regularMaterial)
        .onAppear { titleFocused = true }
    }
}
