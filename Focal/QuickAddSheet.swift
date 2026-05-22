import SwiftUI

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TaskStore.self) private var store
    @State private var title = ""
    @State private var note = ""
    @FocusState private var titleFocused: Bool

    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        NavigationStack {
            Form {
                HStack {
                    TextField("Task", text: $title)
                        .focused($titleFocused)
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
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        store.addTask(title: trimmedTitle, note: note)
                        dismiss()
                    }
                    .disabled(trimmedTitle.isEmpty)
                }
            }
        }
        .onAppear { titleFocused = true }
    }
}
