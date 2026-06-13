import SwiftUI
import SwiftData

struct AllTasksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TaskStore.self) private var store
    @Query(filter: #Predicate<FocalTask> { $0.completedAt == nil }, sort: \FocalTask.createdAt)
    private var incompleteTasks: [FocalTask]
    @Query(filter: #Predicate<FocalTask> { $0.completedAt != nil }, sort: [SortDescriptor(\FocalTask.completedAt, order: .reverse)])
    private var completedTasks: [FocalTask]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(NotificationManager.Key.animationsEnabled) private var animationsEnabled = true
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
            List {
                Section {
                    ForEach(incompleteTasks) { task in
                        Button {
                            editingTask = task
                        } label: {
                            incompleteRow(for: task)
                        }
                        .accessibilityLabel(task.id == store.currentTaskID
                            ? Text("\(task.title), current focus")
                            : Text(task.title)
                        )
                        .accessibilityHint("Opens task editor")
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
                        }
                        .onDelete { offsets in
                            let tasks = offsets.map { completedTasks[$0] }
                            tasks.forEach { store.deleteTask($0) }
                        }
                    }
                }
            }
            .listStyle(.plain)
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
        .safeAreaInset(edge: .bottom) {
            if let undo = store.pendingUndo {
                UndoBanner(undo: undo) {
                    successTrigger += 1
                    store.undoDelete()
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(shouldAnimate ? .spring(duration: 0.3) : nil, value: store.pendingUndo)
        .sheet(item: $editingTask) { task in
            EditTaskSheet(task: task)
        }
        .sensoryFeedback(.selection, trigger: selectionTrigger)
        .sensoryFeedback(.success, trigger: successTrigger)
    }

    @ViewBuilder
    private func incompleteRow(for task: FocalTask) -> some View {
        let isCurrent = task.id == store.currentTaskID
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
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
    }

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
