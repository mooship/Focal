import SwiftUI
import SwiftData

struct AllTasksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TaskStore.self) private var store
    @Query(sort: \FocalTask.createdAt) private var allTasks: [FocalTask]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(NotificationManager.Key.animationsEnabled) private var animationsEnabled = true
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var showingSettings = false
    @State private var editingTask: FocalTask?
    @State private var impactTrigger = 0
    @State private var successTrigger = 0

    private var shouldAnimate: Bool { animationsEnabled && !reduceMotion }
    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    private var taskGroups: (incomplete: [FocalTask], completed: [FocalTask]) {
        (
            incomplete: allTasks.filter { $0.completedAt == nil },
            completed: allTasks.filter { $0.completedAt != nil }
        )
    }

    private let rowInsets = EdgeInsets(top: 3, leading: 16, bottom: 3, trailing: 16)

    var body: some View {
        let groups = taskGroups
        NavigationStack {
            List {
                Section {
                    ForEach(groups.incomplete) { task in
                        Button {
                            editingTask = task
                        } label: {
                            incompleteRow(for: task)
                        }
                        .accessibilityHint("Opens task editor")
                        .glassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .listRowInsets(rowInsets)
                        .contextMenu {
                            Button {
                                impactTrigger += 1
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
                        } preview: {
                            Text(task.title)
                                .font(.headline)
                                .multilineTextAlignment(.center)
                                .padding()
                                .frame(minWidth: 200)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button {
                                impactTrigger += 1
                                store.prioritizeTask(task)
                                dismiss()
                            } label: {
                                Label("Focus now", systemImage: "arrow.up.to.line")
                            }
                            .tint(.blue)
                        }
                    }
                    .onDelete { offsets in
                        let tasks = offsets.map { groups.incomplete[$0] }
                        tasks.forEach { store.deleteTask($0) }
                    }
                }

                if !groups.completed.isEmpty {
                    Section("Completed") {
                        ForEach(groups.completed) { task in
                            Text(task.title)
                                .strikethrough()
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassEffect(in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                                .listRowBackground(Color.clear)
                                .listRowSeparator(.hidden)
                                .listRowInsets(rowInsets)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        successTrigger += 1
                                        store.restoreTask(task)
                                    } label: {
                                        Label("Restore", systemImage: "arrow.uturn.backward")
                                    }
                                    .tint(.green)
                                }
                        }
                        .onDelete { offsets in
                            let tasks = offsets.map { groups.completed[$0] }
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
        .overlay(alignment: .bottom) {
            if let undo = store.pendingUndo {
                undoBanner(undo)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(shouldAnimate ? .spring(duration: 0.3) : nil, value: store.pendingUndo)
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(item: $editingTask) { task in
            EditTaskSheet(task: task)
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: impactTrigger)
        .sensoryFeedback(.success, trigger: successTrigger)
    }

    @ViewBuilder
    private func incompleteRow(for task: FocalTask) -> some View {
        HStack(alignment: .center, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(task.title)
                    .foregroundStyle(.primary)
                if let meta = metaLine(for: task) {
                    Text(meta)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 10)
            .padding(.leading, 12)

            ageBadge(for: task)
                .padding(.trailing, 12)
        }
    }

    private func metaLine(for task: FocalTask) -> String? {
        var parts: [String] = []
        if let mins = task.estimatedMinutes {
            parts.append(estimateString(mins))
        }
        if let due = task.dueDate {
            parts.append(dueDateString(for: due))
        }
        if let rule = task.recurrence {
            parts.append(rule.stringValue)
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func estimateString(_ minutes: Int) -> String {
        switch minutes {
        case 60: return String(localized: "~1 hr")
        case 90: return String(localized: "~1.5 hr")
        case 120: return String(localized: "~2 hr")
        default: return String(localized: "~\(minutes) min")
        }
    }

    private func dueDateString(for due: Date) -> String {
        let cal = Calendar.current
        if !cal.isDateInToday(due) && due < Date() {
            return String(localized: "Overdue")
        }
        if cal.isDateInToday(due) { return String(localized: "Due today") }
        if cal.isDateInTomorrow(due) { return String(localized: "Tomorrow") }
        return due.formatted(.dateTime.month(.abbreviated).day())
    }

    @ViewBuilder
    private func ageBadge(for task: FocalTask) -> some View {
        let days = Calendar.current.dateComponents([.day], from: task.createdAt, to: Date()).day ?? 0
        let color: Color = days <= 7 ? .secondary : days <= 30 ? .orange : .red
        if days > 0 {
            Text("\(days)d")
                .font(.caption2)
                .foregroundStyle(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(color.opacity(0.12), in: Capsule())
        }
    }

    private func undoBanner(_ undo: TaskStore.PendingUndo) -> some View {
        HStack {
            Text("Deleted \"\(undo.title)\"")
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button("Undo") {
                successTrigger += 1
                store.undoDelete()
            }
            .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

