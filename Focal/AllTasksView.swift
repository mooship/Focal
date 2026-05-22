import SwiftUI
import SwiftData

struct AllTasksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(TaskStore.self) private var store
    @Query(sort: \FocalTask.createdAt) private var allTasks: [FocalTask]
    @State private var showingSettings = false
    @State private var editingTask: FocalTask?

    private var incomplete: [FocalTask] { allTasks.filter { $0.completedAt == nil } }
    private var completed: [FocalTask] { allTasks.filter { $0.completedAt != nil } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(incomplete) { task in
                        Button(task.title) { editingTask = task }
                            .foregroundStyle(.primary)
                    }
                    .onDelete { offsets in
                        for index in offsets { modelContext.delete(incomplete[index]) }
                        try? modelContext.save()
                        store.refreshIfNeeded()
                    }
                }

                if !completed.isEmpty {
                    Section("Completed") {
                        ForEach(completed) { task in
                            Text(task.title)
                                .foregroundStyle(.secondary)
                        }
                        .onDelete { offsets in
                            for index in offsets { modelContext.delete(completed[index]) }
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
