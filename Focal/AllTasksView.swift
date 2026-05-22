import SwiftUI
import SwiftData

struct AllTasksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(TaskStore.self) private var store
    @Query(sort: \FocalTask.createdAt) private var allTasks: [FocalTask]
    @State private var showingSettings = false
    @State private var editingTask: FocalTask?

    private var taskGroups: (incomplete: [FocalTask], completed: [FocalTask]) {
        allTasks.reduce(into: ([FocalTask](), [FocalTask]())) { acc, task in
            if task.completedAt == nil { acc.0.append(task) }
            else { acc.1.append(task) }
        }
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
                        for index in offsets { modelContext.delete(groups.incomplete[index]) }
                        try? modelContext.save()
                        store.refreshIfNeeded()
                    }
                }

                if !groups.completed.isEmpty {
                    Section("Completed") {
                        ForEach(groups.completed) { task in
                            Text(task.title)
                                .foregroundStyle(.secondary)
                        }
                        .onDelete { offsets in
                            for index in offsets { modelContext.delete(groups.completed[index]) }
                            try? modelContext.save()
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
