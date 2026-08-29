import SwiftUI
import SwiftData

/// Sheet listing all incomplete and completed tasks. Incomplete rows: tap to edit, long-press
/// context menu for Done / "Focus Now" / Edit / Delete, swipe-right for "Focus now", swipe-left
/// for Done / Delete. Completed rows: swipe-right to restore, swipe-left to delete. Opens
/// Settings via the gear icon.
struct AllTasksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TaskStore.self) private var store
    @Query(filter: #Predicate<FocalTask> { $0.completedAt == nil }, sort: \FocalTask.createdAt)
    private var incompleteTasks: [FocalTask]
    @Query(filter: #Predicate<FocalTask> { $0.completedAt != nil }, sort: [SortDescriptor(\FocalTask.completedAt, order: .reverse)])
    private var completedTasks: [FocalTask]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(DefaultsKey.animationsEnabled) private var animationsEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingSettings = false
    @State private var editingTask: FocalTask?
    @State private var selectionTrigger = 0
    @State private var successTrigger = 0

    private var shouldAnimate: Bool { animationsEnabled && !reduceMotion }
    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    private let rowInsets = EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16)

    var body: some View {
        NavigationStack {
            Group {
                if incompleteTasks.isEmpty && completedTasks.isEmpty {
                    emptyStateView
                } else {
                    taskList
                }
            }
            .frame(maxWidth: isRegularWidth ? 600 : .infinity)
            .navigationTitle("All Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .presentationDragIndicator(.visible)
            .presentationBackground(.regularMaterial)
            .navigationDestination(isPresented: $showingSettings) {
                SettingsView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gear")
                    }
                    .accessibilityLabel("Settings")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .undoBanner(store.pendingUndo, animate: shouldAnimate) {
            successTrigger += 1
            store.undo()
        }
        .sheet(item: $editingTask) { task in
            EditTaskSheet(task: task)
        }
        .sensoryFeedback(.selection, trigger: selectionTrigger)
        .sensoryFeedback(.success, trigger: successTrigger)
    }

    private var taskList: some View {
        List {
            Section {
                ForEach(sortedIncompleteTasks) { task in
                    incompleteRow(for: task)
                        .glassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(rowInsets)
                        .contextMenu {
                            completeButton(for: task)
                            Button {
                                selectionTrigger += 1
                                store.prioritizeTask(task)
                                dismiss()
                            } label: {
                                Label("Focus now", systemImage: "arrow.up.to.line")
                            }
                            Button {
                                Task { @MainActor in editingTask = task }
                            } label: {
                                Label("Edit", systemImage: "pencil")
                            }
                            deleteButton(for: task)
                        } preview: {
                            Text(task.title)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .padding()
                                .frame(minWidth: 200)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                selectionTrigger += 1
                                store.prioritizeTask(task)
                                dismiss()
                            } label: {
                                Label("Focus now", systemImage: "arrow.up.to.line")
                            }
                            .tint(.blue)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            completeButton(for: task)
                                .tint(.green)
                            deleteButton(for: task)
                        }
                }
            }

            if !completedTasks.isEmpty {
                Section("Completed") {
                    ForEach(completedTasks) { task in
                        Button {
                            editingTask = task
                        } label: {
                            Text(task.title)
                                .strikethrough()
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .accessibilityLabel(task.title)
                        .accessibilityHint("Opens task editor")
                        .glassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(rowInsets)
                        .contextMenu {
                            Button { restore(task) } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            deleteButton(for: task)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button { restore(task) } label: {
                                Label("Restore", systemImage: "arrow.uturn.backward")
                            }
                            .tint(.green)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            deleteButton(for: task)
                        }
                    }
                }
            }
        }
        .listStyle(.plain)
    }

    /// `incompleteTasks` ordered by due-date urgency (overdue/soonest first), then tasks without a
    /// due date, oldest-created first — so the list surfaces what's due soon instead of just
    /// insertion order.
    private var sortedIncompleteTasks: [FocalTask] {
        incompleteTasks.sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?):
                return l != r ? l < r : lhs.createdAt < rhs.createdAt
            case (nil, nil):
                return lhs.createdAt < rhs.createdAt
            case (nil, _):
                return false
            case (_, nil):
                return true
            }
        }
    }

    /// Shown when there are no tasks at all, incomplete or completed.
    private var emptyStateView: some View {
        EmptyStateView(
            systemImage: "tray",
            iconStyle: AnyShapeStyle(HierarchicalShapeStyle.tertiary),
            title: "No tasks yet.",
            subtitle: "Tasks you add will show up here."
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    /// A row for an incomplete task: a leading checkbox that completes it directly, and a tappable
    /// title/meta area that opens the editor.
    @ViewBuilder
    private func incompleteRow(for task: FocalTask) -> some View {
        let isCurrent = task.id == store.currentTaskID
        HStack(spacing: 12) {
            Button {
                complete(task)
            } label: {
                CheckboxIcon(isCompleted: false)
            }
            .buttonStyle(.plain)
            .markDoneAccessibility(for: task)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 8) {
                    Text(task.title)
                        .foregroundStyle(.primary)
                    if isCurrent {
                        metaBadge(String(localized: "Now"), color: .accentColor)
                    }
                }
                if let meta = metaLine(for: task) {
                    Text(meta)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { editingTask = task }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(accessibilityLabel(for: task))
            .opensEditorAccessibility()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }

    /// The task's title plus a "current focus" suffix (if it's the task on `MainView`) and its
    /// meta line, combined into a single accessibility label for the row.
    private func accessibilityLabel(for task: FocalTask) -> Text {
        var label = task.title
        if task.id == store.currentTaskID {
            label = String(localized: "\(label), current focus")
        }
        if let meta = metaLine(for: task) {
            label += ", " + meta
        }
        return Text(label)
    }

    /// Estimate, due date, and recurrence joined with " · ", or `nil` if the task has none of those set.
    private func metaLine(for task: FocalTask) -> String? {
        var parts: [String] = []
        if let mins = task.estimatedMinutes {
            parts.append(formatEstimateMinutes(mins))
        }
        if let due = task.dueDate {
            parts.append(formatDueDate(due).text)
        }
        if let rule = task.recurrence {
            parts.append(rule.stringValue)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func deleteButton(for task: FocalTask) -> some View {
        Button(role: .destructive) {
            store.deleteTask(task)
        } label: {
            Label("Delete", systemImage: "trash")
        }
    }

    private func completeButton(for task: FocalTask) -> some View {
        Button {
            complete(task)
        } label: {
            Label("Done", systemImage: "checkmark")
        }
    }

    private func restore(_ task: FocalTask) {
        successTrigger += 1
        store.restoreTask(task)
    }

    private func complete(_ task: FocalTask) {
        successTrigger += 1
        store.done(taskID: task.id)
    }

}
