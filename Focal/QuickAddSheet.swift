import SwiftUI

struct QuickAddSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TaskStore.self) private var store
    @State private var title = ""
    @State private var note = ""
    @State private var showMoreOptions = false
    @State private var hasDueDate = false
    @State private var selectedDueDate = Calendar.current.startOfDay(for: Date())
    @State private var selectedEstimate: Int? = nil
    @State private var selectedRecurrence: RecurrenceRule? = nil
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var titleFocused: Bool
    @State private var showingDiscardConfirm = false
    @State private var addedTrigger = 0

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }
    private var hasChanges: Bool {
        !title.trimmed.isEmpty || !note.trimmed.isEmpty
            || hasDueDate || selectedEstimate != nil || selectedRecurrence != nil
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    LimitedTextField(label: "Task", text: $title, limit: TaskLimit.titleMax)
                        .focused($titleFocused)
                    LimitedTextField(label: "Note (optional)", text: $note, limit: TaskLimit.noteMax, axis: .vertical)
                }

                Section {
                    DisclosureGroup("More options", isExpanded: $showMoreOptions) {
                        Toggle("Due date", isOn: $hasDueDate.animation())
                        if hasDueDate {
                            DatePicker(
                                "Due date",
                                selection: $selectedDueDate,
                                displayedComponents: .date
                            )
                        }
                        EstimatePicker(selection: $selectedEstimate)
                        RecurrencePicker(selection: $selectedRecurrence)
                    }
                }
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
                        store.addTask(
                            title: title.trimmed,
                            note: note.trimmed,
                            dueDate: hasDueDate ? selectedDueDate : nil,
                            estimatedMinutes: selectedEstimate,
                            recurrence: selectedRecurrence
                        )
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
