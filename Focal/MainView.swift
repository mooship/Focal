import SwiftUI
import SwiftData

struct MainView: View {
    @Environment(TaskStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(NotificationManager.Key.animationsEnabled) private var animationsEnabled = true
    @State private var showingQuickAdd = false
    @State private var showingAllTasks = false
    @State private var editingTask: FocalTask?
    @State private var lightImpactTrigger = 0
    @State private var successTrigger = 0
    @Query(filter: #Predicate<FocalTask> { $0.completedAt == nil }) private var incompleteTasks: [FocalTask]

    private var shouldAnimate: Bool { animationsEnabled && !reduceMotion }
    private var isRegularWidth: Bool { horizontalSizeClass == .regular }

    var body: some View {
        NavigationStack {
            ZStack {
                if let task = store.currentTask {
                    taskView(task)
                        .id(task.id)
                        .transition(.asymmetric(
                            insertion: .move(edge: .trailing),
                            removal: .move(edge: .leading)
                        ))
                } else {
                    emptyStateView
                        .transition(.opacity)
                }
            }
            .animation(shouldAnimate ? .spring(duration: 0.3) : nil, value: store.currentTaskID)
            .navigationTitle("Focal")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingQuickAdd = true } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Add Task")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingAllTasks = true } label: {
                        Image(systemName: "list.bullet")
                    }
                    .accessibilityLabel("All Tasks")
                }
            }
        }
        .overlay(alignment: .bottom) {
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
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddSheet()
        }
        .sheet(isPresented: $showingAllTasks) {
            AllTasksView()
        }
        .sheet(item: $editingTask) { task in
            EditTaskSheet(task: task)
        }
        .sensoryFeedback(.impact(weight: .light), trigger: lightImpactTrigger)
        .sensoryFeedback(.success, trigger: successTrigger)
    }

    @ViewBuilder
    private func taskView(_ task: FocalTask) -> some View {
        let sortedSubtasks = task.subtasks.sorted { $0.createdAt < $1.createdAt }
        let hasSubtasks = !sortedSubtasks.isEmpty
        let hasMeta = task.estimatedMinutes != nil || task.dueDate != nil || task.recurrence != nil

        VStack(spacing: 0) {
            Spacer()

            VStack(spacing: 0) {
                Button { editingTask = task } label: {
                    VStack(spacing: 12) {
                        Text(task.title)
                            .font(.largeTitle.weight(.semibold))
                            .multilineTextAlignment(.center)
                        if let note = task.note, !note.isEmpty {
                            Text(note)
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .padding(.horizontal, 8)
                    .frame(maxWidth: .infinity)
                    .overlay(alignment: .topTrailing) {
                        Image(systemName: "pencil")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .padding(8)
                            .accessibilityHidden(true)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityHint("Opens task editor")
                .padding(.top, 24)
                .padding(.horizontal, 24)
                .padding(.bottom, hasSubtasks || hasMeta ? 16 : 24)

                if hasSubtasks {
                    Divider()
                        .padding(.horizontal, 24)
                    VStack(spacing: 2) {
                        ForEach(sortedSubtasks) { subtask in
                            Button {
                                let wasCompleted = subtask.isCompleted
                                store.toggleSubtask(subtask, in: task)
                                if wasCompleted { lightImpactTrigger += 1 } else { successTrigger += 1 }
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: subtask.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                                    Text(subtask.title)
                                        .strikethrough(subtask.isCompleted)
                                        .foregroundStyle(subtask.isCompleted ? .secondary : .primary)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .font(.subheadline)
                                .padding(.vertical, 8)
                                .padding(.horizontal, 24)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(subtask.isCompleted
                                ? Text("\(subtask.title), completed")
                                : Text(subtask.title)
                            )
                            .accessibilityHint(subtask.isCompleted
                                ? "Mark as incomplete"
                                : "Mark as complete"
                            )
                        }
                    }
                    .padding(.top, 8)
                    .padding(.bottom, hasMeta ? 0 : 16)
                }

                if hasMeta {
                    metaBadgeRow(for: task)
                        .padding(.horizontal, 24)
                        .padding(.top, hasSubtasks ? 12 : 8)
                        .padding(.bottom, 20)
                }
            }
            .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            .padding(.horizontal, 24)

            Spacer()

            VStack(spacing: 8) {
                let count = incompleteTasks.count
                Text("\(count) tasks")
                    .font(.caption)
                    .foregroundStyle(.tertiary)

                HStack(alignment: .bottom) {
                    Button {
                        lightImpactTrigger += 1
                        store.notNow()
                    } label: {
                        Text("Not now")
                            .font(.body)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                    }
                    .glassEffect(in: Capsule())
                    .accessibilityHint("Skips to the next task")

                    Spacer()

                    Button {
                        successTrigger += 1
                        store.done()
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                    }
                    .glassEffect(in: Capsule())
                    .accessibilityHint("Marks task as complete")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: isRegularWidth ? 600 : .infinity)
    }

    @ViewBuilder
    private func metaBadgeRow(for task: FocalTask) -> some View {
        HStack(spacing: 8) {
            if let mins = task.estimatedMinutes {
                metaBadge(formatEstimateMinutes(mins), color: .secondary)
            }
            if let due = task.dueDate {
                let badge = formatDueDate(due)
                metaBadge(badge.text, color: badge.color)
            }
            if let rule = task.recurrence {
                metaBadge(rule.stringValue, color: .secondary)
            }
            Spacer()
        }
    }

    private func metaBadge(_ text: String, color: Color) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(color)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(color.opacity(0.12), in: Capsule())
    }

    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Text("Nice, nothing left.")
                .font(.title2.weight(.medium))
            Text("Add something when you're ready.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding()
    }

}
