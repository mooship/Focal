import SwiftUI
import SwiftData

/// Sheet for editing or deleting an existing task, including its scheduling fields and subtasks.
/// Saves via `@Environment(\.modelContext)` for task fields and `TaskStore` for subtask mutations;
/// guards unsaved changes with a discard confirmation.
struct EditTaskSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(TaskStore.self) private var store
    let task: FocalTask

    @State private var title: String
    @State private var note: String
    @State private var hasDueDate: Bool
    @State private var selectedDueDate: Date
    @State private var selectedEstimate: Int?
    @State private var selectedRecurrence: RecurrenceRule?
    @State private var subtaskDrafts: [SubtaskDraft]
    @State private var newSubtaskTitle = ""

    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showingDeleteConfirm = false
    @State private var showingDiscardConfirm = false
    @State private var savedTrigger = 0
    @State private var subtaskCompleteTrigger = 0
    @State private var subtaskUncompleteTrigger = 0

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    /// The earliest selectable due date: today, unless the task already has a past due date, in
    /// which case that date's day-start so the existing overdue value stays selectable.
    private var dueDateLowerBound: Date {
        let todayStart = Calendar.current.startOfDay(for: Date())
        if let existing = task.dueDate, existing < todayStart {
            return Calendar.current.startOfDay(for: existing)
        }
        return todayStart
    }

    private struct SubtaskDraft: Identifiable, Equatable {
        var id: UUID
        var title: String
        var isCompleted: Bool
        var isNew: Bool
    }

    /// Whether any field differs from the task's saved state; gates the discard confirmation and
    /// disables interactive (swipe-down) dismissal while true.
    private var hasChanges: Bool {
        let currentDue: Date? = hasDueDate ? selectedDueDate : nil
        return title.trimmed != task.title
            || note.trimmed.nilIfEmpty != task.note
            || currentDue != task.dueDate
            || selectedEstimate != task.estimatedMinutes
            || selectedRecurrence != task.recurrence
            || !newSubtaskTitle.trimmed.isEmpty
            || subtaskDraftsChanged
    }

    /// Whether the subtask drafts differ from `task.subtasks`: added, removed, retitled, or
    /// toggled completion.
    private var subtaskDraftsChanged: Bool {
        let originalIDs = Set(task.subtasks.map(\.id))
        let draftExistingIDs = Set(subtaskDrafts.filter { !$0.isNew }.map(\.id))
        if originalIDs != draftExistingIDs {
            return true
        }
        if subtaskDrafts.contains(where: \.isNew) {
            return true
        }
        let originalByID = Dictionary(uniqueKeysWithValues: task.subtasks.map { ($0.id, $0) })
        for draft in subtaskDrafts where !draft.isNew {
            guard let original = originalByID[draft.id] else {
                continue
            }
            if original.isCompleted != draft.isCompleted {
                return true
            }
            if original.title != draft.title.trimmed {
                return true
            }
        }
        return false
    }

    init(task: FocalTask) {
        self.task = task
        _title = State(initialValue: task.title)
        _note = State(initialValue: task.note ?? "")
        _hasDueDate = State(initialValue: task.dueDate != nil)
        _selectedDueDate = State(initialValue: task.dueDate ?? Calendar.current.startOfDay(for: Date()))
        _selectedEstimate = State(initialValue: task.estimatedMinutes)
        _selectedRecurrence = State(initialValue: task.recurrence)
        _subtaskDrafts = State(initialValue: task.sortedSubtasks
            .map { SubtaskDraft(id: $0.id, title: $0.title, isCompleted: $0.isCompleted, isNew: false) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                if task.completedAt != nil {
                    Section {
                        HStack(spacing: 12) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("Completed")
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Restore") {
                                store.restoreTask(task)
                                dismiss()
                            }
                        }
                        .accessibilityElement(children: .combine)
                    }
                }

                Section {
                    LimitedTextField(label: "Task", text: $title, limit: TaskLimit.titleMax)
                    LimitedTextField(label: "Note (optional)", text: $note, limit: TaskLimit.noteMax, axis: .vertical)
                }

                Section("Scheduling") {
                    Toggle("Due date", isOn: $hasDueDate.animation())
                    if hasDueDate {
                        DatePicker(
                            "Due date",
                            selection: $selectedDueDate,
                            in: dueDateLowerBound...,
                            displayedComponents: .date
                        )
                    }
                    EstimatePicker(selection: $selectedEstimate)
                    RecurrencePicker(selection: $selectedRecurrence)
                }

                Section("Subtasks") {
                    ForEach($subtaskDrafts) { $draft in
                        HStack(spacing: 12) {
                            Button {
                                let wasCompleted = draft.isCompleted
                                draft.isCompleted.toggle()
                                if wasCompleted {
                                    subtaskUncompleteTrigger += 1
                                } else {
                                    subtaskCompleteTrigger += 1
                                }
                            } label: {
                                CheckboxIcon(isCompleted: draft.isCompleted)
                            }
                            .buttonStyle(.plain)
                            .accessibilityAddTraits(.isToggle)
                            .accessibilityLabel(draft.isCompleted
                                ? Text(String(localized: "\(draft.title), completed"))
                                : Text(draft.title)
                            )
                            .accessibilityHint(draft.isCompleted
                                ? "Mark as incomplete"
                                : "Mark as complete"
                            )

                            if draft.isCompleted {
                                Text(draft.title)
                                    .strikethrough()
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            } else {
                                TextField("Subtask", text: $draft.title)
                            }
                        }
                    }
                    .onDelete { offsets in
                        subtaskDrafts.remove(atOffsets: offsets)
                    }

                    SubtaskInputField(text: $newSubtaskTitle, onCommit: commitNewSubtask)
                }

                Section {
                    Button(role: .destructive) {
                        showingDeleteConfirm = true
                    } label: {
                        Text("Delete Task")
                    }
                }
            }
            .frame(maxWidth: isRegularWidth ? 600 : .infinity)
            .navigationTitle("Edit Task")
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
                    Button("Save") {
                        saveChanges()
                        savedTrigger += 1
                        Task { @MainActor in dismiss() }
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
            .confirmationDialog(
                "Discard changes?",
                isPresented: $showingDiscardConfirm,
                titleVisibility: .visible
            ) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            }
        }
        .presentationDetents([.large])
        .presentationBackground(.regularMaterial)
        .sensoryFeedback(.success, trigger: savedTrigger)
        .sensoryFeedback(.success, trigger: subtaskCompleteTrigger)
        .sensoryFeedback(.impact(weight: .light), trigger: subtaskUncompleteTrigger)
    }

    /// Appends the in-progress subtask title as a new draft row, if non-empty, then clears the input.
    /// Also called on "Save" so a typed-but-uncommitted subtask isn't lost.
    private func commitNewSubtask() {
        let trimmed = newSubtaskTitle.trimmed
        guard !trimmed.isEmpty else {
            return
        }
        subtaskDrafts.append(SubtaskDraft(id: UUID(), title: trimmed, isCompleted: false, isNew: true))
        newSubtaskTitle = ""
    }

    /// Writes the edited fields back to `task`, reconciles the subtask drafts against
    /// `task.subtasks` (update, delete, or insert as needed), then auto-completes the task if that
    /// reconciliation left every subtask checked off.
    private func saveChanges() {
        commitNewSubtask()
        task.title = title.trimmed
        task.note = note.trimmed.nilIfEmpty
        task.dueDate = hasDueDate ? selectedDueDate : nil
        task.estimatedMinutes = selectedEstimate
        task.recurrence = selectedRecurrence
        try? modelContext.save()

        let draftByID = Dictionary(uniqueKeysWithValues: subtaskDrafts.filter { !$0.isNew }.map { ($0.id, $0) })
        for existing in Array(task.subtasks) {
            if let draft = draftByID[existing.id], !draft.title.trimmed.isEmpty {
                store.updateSubtask(existing, title: draft.title.trimmed, isCompleted: draft.isCompleted)
            } else {
                store.deleteSubtask(existing)
            }
        }
        for draft in subtaskDrafts where draft.isNew {
            let trimmed = draft.title.trimmed
            guard !trimmed.isEmpty else {
                continue
            }
            store.addSubtask(to: task, title: trimmed)
        }

        store.completeIfAllSubtasksDone(task)
    }
}
