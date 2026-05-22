import SwiftUI

struct MainView: View {
    @Environment(TaskStore.self) private var store
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage(NotificationManager.Key.animationsEnabled) private var animationsEnabled = true
    @State private var showingQuickAdd = false
    @State private var showingAllTasks = false
    @State private var editingTask: FocalTask?

    private var shouldAnimate: Bool { animationsEnabled && !reduceMotion }

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
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("All Tasks") { showingAllTasks = true }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingQuickAdd = true } label: {
                        Image(systemName: "plus")
                    }
                }
            }
        }
        .sheet(isPresented: $showingQuickAdd) {
            QuickAddSheet()
        }
        .sheet(isPresented: $showingAllTasks) {
            AllTasksView()
        }
        .sheet(item: $editingTask) { task in
            EditTaskSheet(task: task)
        }
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
                .glassEffect(in: RoundedRectangle(cornerRadius: 24, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Spacer()

            HStack(alignment: .bottom) {
                Button {
                    store.notNow()
                } label: {
                    Text("Not now")
                        .font(.body)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .glassEffect(in: Capsule())

                Spacer()

                Button {
                    store.done()
                } label: {
                    Text("Done")
                        .font(.headline)
                        .padding(.horizontal, 32)
                        .padding(.vertical, 16)
                }
                .glassEffect(in: Capsule())
            }
            .padding(.horizontal, 24)
            .padding(.bottom, 40)
        }
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
