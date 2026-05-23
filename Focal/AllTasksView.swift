import SwiftUI
import SwiftData

struct AllTasksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TaskStore.self) private var store
    @Query(sort: \FocalTask.createdAt) private var allTasks: [FocalTask]
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @AppStorage(NotificationManager.Key.animationsEnabled) private var animationsEnabled = true
    @State private var showingSettings = false
    @State private var editingTask: FocalTask?
    @State private var impactTrigger = 0
    @State private var successTrigger = 0

    private var shouldAnimate: Bool { animationsEnabled }
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
                            Text(task.title)
                                .foregroundStyle(.primary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
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
                        let incomplete = allTasks.filter { $0.completedAt == nil }
                        for index in offsets {
                            store.deleteTask(incomplete[index])
                        }
                    }
                }

                if !groups.completed.isEmpty {
                    Section("Completed") {
                        ForEach(groups.completed) { task in
                            Text(task.title)
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
                            let completed = allTasks.filter { $0.completedAt != nil }
                            for index in offsets {
                                store.deleteTask(completed[index])
                            }
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
