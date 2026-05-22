import SwiftUI
import SwiftData

struct EditTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(TaskStore.self) private var store
    let task: FocalTask
    @State private var title: String
    @State private var note: String
    @State private var showingDeleteConfirm = false

    init(task: FocalTask) {
        self.task = task
        _title = State(initialValue: task.title)
        _note = State(initialValue: task.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LimitedTextField(label: "Task", text: $title, limit: TaskLimit.titleMax)
                    LimitedTextField(label: "Note (optional)", text: $note, limit: TaskLimit.noteMax)
                }
                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Text("Delete Task")
                    }
                }
            }
            .navigationTitle("Edit Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        task.title = title.trimmed
                        task.note = note.nilIfEmpty
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(title.trimmed.isEmpty)
                }
            }
            .confirmationDialog(
                "Delete this task?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    store.deleteTask(task)
                    dismiss()
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
