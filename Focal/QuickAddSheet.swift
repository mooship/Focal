import SwiftUI

/// Sheet for adding a new task: title/note, a "More options" disclosure for due date, estimate,
/// and recurrence, and a Subtasks section for checklist items. Guards accidental dismissal with a
/// discard confirmation once any field has been touched.
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
    @State private var subtaskDrafts: [SubtaskDraft] = []
    @State private var newSubtaskTitle = ""
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @FocusState private var titleFocused: Bool
    @State private var showingDiscardConfirm = false
    @State private var addedTrigger = 0

    private struct SubtaskDraft: Identifiable, Equatable {
        let id = UUID()
        var title: String
    }

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }
    /// Whether any field has been filled in; gates the discard confirmation and disables
    /// interactive (swipe-down) dismissal while true.
    private var hasChanges: Bool {
        !title.trimmed.isEmpty || !note.trimmed.isEmpty
            || hasDueDate || selectedEstimate != nil || selectedRecurrence != nil
            || !subtaskDrafts.isEmpty || !newSubtaskTitle.trimmed.isEmpty
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
                                in: Calendar.current.startOfDay(for: Date())...,
                                displayedComponents: .date
                            )
                        }
                        EstimatePicker(selection: $selectedEstimate)
                        RecurrencePicker(selection: $selectedRecurrence)
                    }
                }

                Section("Subtasks") {
                    ForEach($subtaskDrafts) { $draft in
                        TextField("Subtask", text: $draft.title)
                    }
                    .onDelete { offsets in
                        subtaskDrafts.remove(atOffsets: offsets)
                    }

                    SubtaskInputField(text: $newSubtaskTitle, onCommit: commitNewSubtask)
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
                        commitNewSubtask()
                        addedTrigger += 1
                        store.addTask(
                            title: title.trimmed,
                            note: note.trimmed,
                            dueDate: hasDueDate ? selectedDueDate : nil,
                            estimatedMinutes: selectedEstimate,
                            recurrence: selectedRecurrence,
                            subtaskTitles: subtaskDrafts.compactMap { $0.title.trimmed.nilIfEmpty }
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

    /// Appends the in-progress subtask title as a new draft row, if non-empty, then clears the input.
    /// Also called on "Add" so a typed-but-uncommitted subtask isn't lost.
    private func commitNewSubtask() {
        let trimmed = newSubtaskTitle.trimmed
        guard !trimmed.isEmpty else {
            return
        }
        subtaskDrafts.append(SubtaskDraft(title: trimmed))
        newSubtaskTitle = ""
    }

}
