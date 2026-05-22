import SwiftUI
import SwiftData

struct AllTasksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(TaskStore.self) private var store
    @Query(sort: \FocalTask.createdAt) private var allTasks: [FocalTask]
    @State private var showingSettings = false
    @State private var editingTask: FocalTask?

    private var taskGroups: (incomplete: [FocalTask], completed: [FocalTask]) {
        (
            incomplete: allTasks.filter { $0.completedAt == nil },
            completed: allTasks.filter { $0.completedAt != nil }
        )
    }

    var body: some View {
        let groups = taskGroups
        NavigationStack {
            List {
                Section {
                    ForEach(groups.incomplete) { task in
                        Button(task.title) { editingTask = task }
                            .foregroundStyle(.primary)
                    }
                    .onDelete { offsets in
                        for index in offsets { store.deleteTask(groups.incomplete[index]) }
                    }
                }

                if !groups.completed.isEmpty {
                    Section("Completed") {
                        ForEach(groups.completed) { task in
                            Text(task.title)
                                .foregroundStyle(.secondary)
                        }
                        .onDelete { offsets in
                            for index in offsets { store.deleteTask(groups.completed[index]) }
                        }
                    }
                }
            }
            .navigationTitle("All Tasks")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingSettings = true } label: {
                        Image(systemName: "gear")
                    }
                }
            }
        }
        .sheet(isPresented: $showingSettings) {
            SettingsView()
        }
        .sheet(item: $editingTask) { task in
            EditTaskSheet(task: task)
        }
    }
}
