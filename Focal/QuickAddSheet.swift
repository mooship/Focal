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
                TextField("Task", text: $title)
                    .focused($titleFocused)
                TextField("Note (optional)", text: $note)
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addTask(
                            title: title.trimmingCharacters(in: .whitespaces),
                            note: note.isEmpty ? nil : note
                        )
                        dismiss()
                    }
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .onAppear { titleFocused = true }
    }
}
