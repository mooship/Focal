import SwiftUI
import SwiftData

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
    @FocusState private var subtaskFieldFocused: Bool

    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    private struct SubtaskDraft: Identifiable, Equatable {
        var id: UUID
        var title: String
        var isCompleted: Bool
        var isNew: Bool
    }

    private var hasChanges: Bool {
        guard !title.trimmed.isEmpty else { return false }
        let currentDue: Date? = hasDueDate ? selectedDueDate : nil
        let dueDateChanged = currentDue != task.dueDate
        if title.trimmed != task.title
            || note.trimmed.nilIfEmpty != task.note
            || dueDateChanged
            || selectedEstimate != task.estimatedMinutes
            || selectedRecurrence != task.recurrence {
            return true
        }
        return subtaskDraftsChanged
    }

    private var subtaskDraftsChanged: Bool {
        let originalIDs = Set(task.subtasks.map(\.id))
        let draftExistingIDs = Set(subtaskDrafts.filter { !$0.isNew }.map(\.id))
        if originalIDs != draftExistingIDs { return true }
        if subtaskDrafts.contains(where: \.isNew) { return true }
        let originalByID = Dictionary(uniqueKeysWithValues: task.subtasks.map { ($0.id, $0) })
        for draft in subtaskDrafts where !draft.isNew {
            if let original = originalByID[draft.id],
               original.isCompleted != draft.isCompleted { return true }
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
        _subtaskDrafts = State(initialValue: task.subtasks
            .sorted { $0.createdAt < $1.createdAt }
            .map { SubtaskDraft(id: $0.id, title: $0.title, isCompleted: $0.isCompleted, isNew: false) }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
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
                                draft.isCompleted.toggle()
                            } label: {
                                Image(systemName: draft.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(draft.isCompleted ? .secondary : .primary)
                                    .imageScale(.large)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(draft.isCompleted ? "Mark incomplete" : "Mark complete")
                            Text(draft.title)
                                .strikethrough(draft.isCompleted)
                                .foregroundStyle(draft.isCompleted ? .secondary : .primary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .onDelete { offsets in
                        subtaskDrafts.remove(atOffsets: offsets)
                    }

                    HStack {
                        TextField("New subtask", text: $newSubtaskTitle)
                            .focused($subtaskFieldFocused)
                            .onSubmit { commitNewSubtask() }
                        if !newSubtaskTitle.trimmed.isEmpty {
                            Button {
                                commitNewSubtask()
                            } label: {
                                Image(systemName: "plus.circle.fill")
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 44, minHeight: 44)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add subtask")
                        }
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
    }

    private func commitNewSubtask() {
        let trimmed = newSubtaskTitle.trimmed
        guard !trimmed.isEmpty else { return }
        subtaskDrafts.append(SubtaskDraft(id: UUID(), title: trimmed, isCompleted: false, isNew: true))
        newSubtaskTitle = ""
    }

    private func saveChanges() {
        task.title = title.trimmed
        task.note = note.trimmed.nilIfEmpty
        task.dueDate = hasDueDate ? selectedDueDate : nil
        task.estimatedMinutes = selectedEstimate
        task.recurrence = selectedRecurrence

        let draftByID = Dictionary(uniqueKeysWithValues: subtaskDrafts.filter { !$0.isNew }.map { ($0.id, $0) })
        for existing in Array(task.subtasks) {
            if let draft = draftByID[existing.id] {
                existing.isCompleted = draft.isCompleted
            } else {
                modelContext.delete(existing)
            }
        }
        for draft in subtaskDrafts where draft.isNew {
            let sub = SubTask(title: draft.title)
            sub.task = task
            modelContext.insert(sub)
        }

        try? modelContext.save()
    }
}
