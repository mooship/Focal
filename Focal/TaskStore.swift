import Foundation
import SwiftData

@Observable
final class TaskStore {
    private let modelContext: ModelContext
    private var sessionQueue: [UUID] = []
    private(set) var currentTaskID: UUID?
    private(set) var pendingUndo: PendingUndo? = nil
    private var undoTask: Task<Void, Never>?

    struct SubtaskSnapshot: Equatable {
        let title: String
        let isCompleted: Bool
    }

    struct PendingUndo: Equatable {
        let title: String
        let note: String?
        let completedAt: Date?
        let dueDate: Date?
        let estimatedMinutes: Int?
        let recurrence: RecurrenceRule?
        let subtasks: [SubtaskSnapshot]
    }

    var currentTask: FocalTask? {
        guard let id = currentTaskID else { return nil }
        return fetchIncomplete().first { $0.id == id }
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        advance()
    }

    func done() {
        guard let id = currentTaskID else { return }
        done(taskID: id)
    }

    func done(taskID: UUID) {
        let incomplete = fetchIncomplete()
        guard let task = incomplete.first(where: { $0.id == taskID }) else { return }

        if let rule = task.recurrence {
            let base = task.dueDate ?? Date()
            let nextDue = rule.nextDate(from: base)
            let subtaskTitles = task.subtasks.sorted { $0.createdAt < $1.createdAt }.map(\.title)
            addTask(
                title: task.title,
                note: task.note,
                dueDate: nextDue,
                estimatedMinutes: task.estimatedMinutes,
                recurrence: rule,
                subtaskTitles: subtaskTitles
            )
        }

        task.completedAt = Date()
        try? modelContext.save()
        if let i = sessionQueue.firstIndex(of: taskID) {
            sessionQueue.remove(at: i)
        }
        advance(with: fetchIncomplete())
        NotificationManager.shared.reschedule()
    }

    func notNow() {
        let incomplete = fetchIncomplete()
        guard let id = currentTaskID,
              incomplete.contains(where: { $0.id == id }) else { return }
        if let i = sessionQueue.firstIndex(of: id) {
            sessionQueue.remove(at: i)
        }
        sessionQueue.append(id)
        advance(with: incomplete)
        NotificationManager.shared.reschedule()
    }

    func addTask(
        title: String,
        note: String?,
        dueDate: Date? = nil,
        estimatedMinutes: Int? = nil,
        recurrence: RecurrenceRule? = nil,
        subtaskTitles: [String] = []
    ) {
        let task = FocalTask(
            title: title,
            note: note.flatMap { $0.trimmed.nilIfEmpty },
            dueDate: dueDate,
            estimatedMinutes: estimatedMinutes,
            recurrence: recurrence
        )
        modelContext.insert(task)
        for stTitle in subtaskTitles {
            let sub = SubTask(title: stTitle)
            sub.task = task
            modelContext.insert(sub)
        }
        try? modelContext.save()
        if currentTaskID == nil {
            advance()
        } else {
            let insertIndex = sessionQueue.isEmpty ? 0 : Int.random(in: 1...sessionQueue.count)
            sessionQueue.insert(task.id, at: insertIndex)
        }
    }

    func deleteTask(_ task: FocalTask) {
        let id = task.id
        let snapshot = PendingUndo(
            title: task.title,
            note: task.note,
            completedAt: task.completedAt,
            dueDate: task.dueDate,
            estimatedMinutes: task.estimatedMinutes,
            recurrence: task.recurrence,
            subtasks: task.subtasks.sorted { $0.createdAt < $1.createdAt }.map {
                SubtaskSnapshot(title: $0.title, isCompleted: $0.isCompleted)
            }
        )
        modelContext.delete(task)
        try? modelContext.save()
        if let i = sessionQueue.firstIndex(of: id) {
            sessionQueue.remove(at: i)
        }
        refreshIfNeeded()

        undoTask?.cancel()
        pendingUndo = snapshot
        undoTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(5))
                self?.pendingUndo = nil
            } catch {}
        }
    }

    func undoDelete() {
        undoTask?.cancel()
        undoTask = nil
        guard let undo = pendingUndo else { return }
        pendingUndo = nil
        let subtaskTitles = undo.subtasks.map(\.title)
        if let completedAt = undo.completedAt {
            let task = FocalTask(
                title: undo.title,
                note: undo.note.flatMap { $0.trimmed.nilIfEmpty },
                dueDate: undo.dueDate,
                estimatedMinutes: undo.estimatedMinutes,
                recurrence: undo.recurrence
            )
            task.completedAt = completedAt
            modelContext.insert(task)
            for stTitle in subtaskTitles {
                let sub = SubTask(title: stTitle)
                sub.task = task
                modelContext.insert(sub)
            }
            try? modelContext.save()
        } else {
            addTask(
                title: undo.title,
                note: undo.note,
                dueDate: undo.dueDate,
                estimatedMinutes: undo.estimatedMinutes,
                recurrence: undo.recurrence,
                subtaskTitles: subtaskTitles
            )
        }
        NotificationManager.shared.reschedule()
    }

    func restoreTask(_ task: FocalTask) {
        task.completedAt = nil
        try? modelContext.save()
        guard !sessionQueue.contains(task.id) else { return }
        let insertIndex = sessionQueue.isEmpty ? 0 : Int.random(in: 1...sessionQueue.count)
        sessionQueue.insert(task.id, at: insertIndex)
        if currentTaskID == nil {
            advance()
        }
        NotificationManager.shared.reschedule()
    }

    func prioritizeTask(_ task: FocalTask) {
        guard task.completedAt == nil else { return }
        if let i = sessionQueue.firstIndex(of: task.id) {
            sessionQueue.remove(at: i)
        }
        sessionQueue.insert(task.id, at: 0)
        currentTaskID = task.id
        NotificationManager.shared.reschedule()
    }

    func addSubtask(to task: FocalTask, title: String) {
        let sub = SubTask(title: title.trimmed)
        sub.task = task
        modelContext.insert(sub)
        try? modelContext.save()
    }

    func deleteSubtask(_ subtask: SubTask) {
        modelContext.delete(subtask)
        try? modelContext.save()
    }

    func toggleSubtask(_ subtask: SubTask, in task: FocalTask) {
        subtask.isCompleted.toggle()
        try? modelContext.save()
        let allDone = !task.subtasks.isEmpty && task.subtasks.allSatisfy(\.isCompleted)
        if allDone {
            done(taskID: task.id)
        }
    }

    private func refreshIfNeeded() {
        if currentTaskID != nil && currentTask == nil {
            advance()
        }
    }

    private func advance(with preloaded: [FocalTask]? = nil) {
        let incomplete = preloaded ?? fetchIncomplete()
        let incompleteIDs = Set(incomplete.map(\.id))
        sessionQueue = sessionQueue.filter { incompleteIDs.contains($0) }
        if sessionQueue.isEmpty {
            sessionQueue = incomplete.map(\.id).shuffled()
        }
        currentTaskID = sessionQueue.first
    }

    private func fetchIncomplete() -> [FocalTask] {
        let descriptor = FetchDescriptor<FocalTask>(
            predicate: #Predicate { $0.completedAt == nil }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
