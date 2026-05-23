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
    @State private var showingConfetti = false
    @State private var pendingDoneID: UUID?
    @State private var confettiRunID = UUID()
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
                undoBanner(undo)
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
        .overlay {
            if showingConfetti {
                ConfettiView()
                    .id(confettiRunID)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.4), value: showingConfetti)
        .task(id: showingConfetti) {
            guard showingConfetti, let id = pendingDoneID else {
                return
            }
            do {
                try await Task.sleep(for: .seconds(0.7))
            } catch {
                showingConfetti = false
                return
            }
            store.done(taskID: id)
            do {
                try await Task.sleep(for: .seconds(1.5))
            } catch {}
            showingConfetti = false
        }
        .sensoryFeedback(.impact(weight: .light), trigger: lightImpactTrigger)
        .sensoryFeedback(.success, trigger: successTrigger)
    }

    @ViewBuilder
    private func taskView(_ task: FocalTask) -> some View {
        VStack(spacing: 0) {
            Spacer()

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
                .padding(32)
                .frame(maxWidth: .infinity)
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "pencil")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                        .padding(12)
                        .accessibilityHidden(true)
                }
                .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens task editor")
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
                    .disabled(showingConfetti)
                    .accessibilityHint("Skips to the next task")

                    Spacer()

                    Button {
                        successTrigger += 1
                        if shouldAnimate {
                            pendingDoneID = store.currentTaskID
                            confettiRunID = UUID()
                            showingConfetti = true
                        } else {
                            store.done()
                        }
                    } label: {
                        Text("Done")
                            .font(.headline)
                            .padding(.horizontal, 32)
                            .padding(.vertical, 16)
                    }
                    .glassEffect(in: Capsule())
                    .disabled(showingConfetti)
                    .accessibilityHint("Marks task as complete")
                }
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
        .frame(maxWidth: isRegularWidth ? 600 : .infinity)
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
