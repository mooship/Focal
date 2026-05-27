import SwiftUI

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TaskStore.self) private var store
    @State private var title = ""
    @State private var note = ""
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var titleFocused: Bool
    @State private var showingDiscardConfirm = false
    @State private var addedTrigger = 0

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }
    private var hasChanges: Bool { !title.trimmed.isEmpty || !note.trimmed.isEmpty }

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
            .interactiveDismissDisabled(hasChanges)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        if hasChanges {
                            showingDiscardConfirm = true
                        } else {
                            dismiss()
                        }
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addedTrigger += 1
                        store.addTask(title: title.trimmed, note: note.trimmed)
                        Task { @MainActor in dismiss() }
                    }
                    .disabled(title.trimmed.isEmpty)
                }
            }
            .confirmationDialog(
                "Discard new task?",
                isPresented: $showingDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.regularMaterial)
        .onAppear { titleFocused = true }
        .sensoryFeedback(.success, trigger: addedTrigger)
    }
}
