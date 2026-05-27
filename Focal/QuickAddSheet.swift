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
                    LimitedTextField(label: "Note (optional)", text: $note, limit: TaskLimit.noteMax)
                }

                Section {
                    DisclosureGroup("More options", isExpanded: $showMoreOptions) {
                        Toggle("Due date", isOn: $hasDueDate.animation())
                        if hasDueDate {
                            DatePicker(
                                "Date",
                                selection: $selectedDueDate,
                                displayedComponents: .date
                            )
                        }
                        estimatePicker
                        recurrencePicker
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

    private var estimatePicker: some View {
        Picker("Estimate", selection: $selectedEstimate) {
            Text("None").tag(Optional<Int>.none)
            Text("~5 min").tag(Optional(5))
            Text("~10 min").tag(Optional(10))
            Text("~15 min").tag(Optional(15))
            Text("~30 min").tag(Optional(30))
            Text("~45 min").tag(Optional(45))
            Text("~1 hr").tag(Optional(60))
            Text("~1.5 hr").tag(Optional(90))
            Text("~2 hr").tag(Optional(120))
        }
        .pickerStyle(.menu)
    }

    private var recurrencePicker: some View {
        Picker("Repeat", selection: $selectedRecurrence) {
            Text("None").tag(Optional<RecurrenceRule>.none)
            ForEach(RecurrenceRule.allCases, id: \.self) { rule in
                Text(rule.localizedLabel).tag(Optional(rule))
            }
        }
        .pickerStyle(.menu)
    }
}
