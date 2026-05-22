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

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespaces) }

    init(task: FocalTask) {
        self.task = task
        _title = State(initialValue: task.title)
        _note = State(initialValue: task.note ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        TextField("Task", text: $title)
                        if title.count > TaskLimit.titleMax - 20 {
                            Text("\(TaskLimit.titleMax - title.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(title.count >= TaskLimit.titleMax ? .red : .secondary)
                        }
                    }
                    .onChange(of: title) { _, new in
                        if new.count > TaskLimit.titleMax { title = String(new.prefix(TaskLimit.titleMax)) }
                    }
                    HStack {
                        TextField("Note (optional)", text: $note)
                        if note.count > TaskLimit.noteMax - 20 {
                            Text("\(TaskLimit.noteMax - note.count)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(note.count >= TaskLimit.noteMax ? .red : .secondary)
                        }
                    }
                    .onChange(of: note) { _, new in
                        if new.count > TaskLimit.noteMax { note = String(new.prefix(TaskLimit.noteMax)) }
                    }
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
                        task.title = trimmedTitle
                        task.note = note.isEmpty ? nil : note
                        try? modelContext.save()
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
            }
            .confirmationDialog(
                "Delete this task?",
                isPresented: $showingDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Delete", role: .destructive) {
                    modelContext.delete(task)
                    try? modelContext.save()
                    store.refreshIfNeeded()
                    dismiss()
                }
            }
        }
    }
}
