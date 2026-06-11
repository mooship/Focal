import Foundation
import SwiftData
import UIKit

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

    private(set) var currentTask: FocalTask?
    private(set) var notNowStreak: Int = 0

    var hasCompletedCycle: Bool {
        !sessionQueue.isEmpty && notNowStreak >= sessionQueue.count
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        advance()
    }

    func done() {
        guard let id = currentTaskID else {
            return
        }
        done(taskID: id)
    }

    func done(taskID: UUID) {
        let incomplete = fetchIncomplete()
        guard let task = incomplete.first(where: { $0.id == taskID }) else {
            return
        }

        if let rule = task.recurrence {
            let base = task.dueDate ?? Date()
            var nextDue = rule.nextDate(from: base)
            let todayStart = Calendar.current.startOfDay(for: Date())
            while nextDue < todayStart {
                nextDue = rule.nextDate(from: nextDue)
            }
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
        notNowStreak = 0
        try? modelContext.save()
        if let i = sessionQueue.firstIndex(of: taskID) {
            sessionQueue.remove(at: i)
        }
        if task.recurrence != nil {
            advance(with: fetchIncomplete())
        } else {
            advance(with: incomplete.filter { $0.id != taskID })
        }
        updateInactivityNotification()
    }

    func notNow() {
        let incomplete = fetchIncomplete()
        guard let id = currentTaskID,
              incomplete.contains(where: { $0.id == id }) else {
            return
        }
        notNowStreak += 1
        if let i = sessionQueue.firstIndex(of: id) {
            sessionQueue.remove(at: i)
        }
        sessionQueue.append(id)
        advance(with: incomplete)
        updateInactivityNotification()
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
            notNowStreak = 0
        }
        updateInactivityNotification()
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
        notNowStreak = 0
        if currentTaskID == id {
            advance()
        } else {
            refreshIfNeeded()
        }
        updateInactivityNotification()

        undoTask?.cancel()
        pendingUndo = snapshot
        let undoWindow: Double = UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning ? 10 : 5
        undoTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(undoWindow))
                self?.pendingUndo = nil
            } catch {}
        }
    }

    func undoDelete() {
        undoTask?.cancel()
        undoTask = nil
        guard let undo = pendingUndo else {
            return
        }
        pendingUndo = nil

        let task = FocalTask(
            title: undo.title,
            note: undo.note.flatMap { $0.trimmed.nilIfEmpty },
            dueDate: undo.dueDate,
            estimatedMinutes: undo.estimatedMinutes,
            recurrence: undo.recurrence
        )
        if let completedAt = undo.completedAt {
            task.completedAt = completedAt
        }
        modelContext.insert(task)
        for snapshot in undo.subtasks {
            let sub = SubTask(title: snapshot.title)
            sub.isCompleted = snapshot.isCompleted
            sub.task = task
            modelContext.insert(sub)
        }
        try? modelContext.save()

        if undo.completedAt == nil {
            if currentTaskID == nil {
                advance()
            } else {
                let insertIndex = sessionQueue.isEmpty ? 0 : Int.random(in: 1...sessionQueue.count)
                sessionQueue.insert(task.id, at: insertIndex)
                notNowStreak = 0
            }
        }
        updateInactivityNotification()
    }

    func restoreTask(_ task: FocalTask) {
        task.completedAt = nil
        if !task.subtasks.isEmpty && task.subtasks.allSatisfy(\.isCompleted) {
            task.subtasks.forEach { $0.isCompleted = false }
        }
        try? modelContext.save()
        guard !sessionQueue.contains(task.id) else {
            return
        }
        let insertIndex = sessionQueue.isEmpty ? 0 : Int.random(in: 1...sessionQueue.count)
        sessionQueue.insert(task.id, at: insertIndex)
        notNowStreak = 0
        if currentTaskID == nil {
            advance()
        }
        updateInactivityNotification()
    }

    func prioritizeTask(_ task: FocalTask) {
        guard task.completedAt == nil else {
            return
        }
        if let i = sessionQueue.firstIndex(of: task.id) {
            sessionQueue.remove(at: i)
        }
        sessionQueue.insert(task.id, at: 0)
        currentTaskID = task.id
        currentTask = task
        notNowStreak = 0
        updateInactivityNotification()
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
        completeIfAllSubtasksDone(task)
    }

    func completeIfAllSubtasksDone(_ task: FocalTask) {
        guard task.completedAt == nil,
              !task.subtasks.isEmpty,
              task.subtasks.allSatisfy(\.isCompleted) else {
            return
        }
        done(taskID: task.id)
    }

    private func updateInactivityNotification() {
        if currentTaskID == nil {
            NotificationManager.shared.cancelAll()
        } else {
            NotificationManager.shared.reschedule()
        }
    }

    private func refreshIfNeeded() {
        if currentTaskID == nil {
            advance()
        }
    }

    private func advance(with preloaded: [FocalTask]? = nil) {
        let incomplete = preloaded ?? fetchIncomplete()
        let incompleteIDs = Set(incomplete.map(\.id))
        sessionQueue = sessionQueue.filter { incompleteIDs.contains($0) }
        if sessionQueue.isEmpty {
            let cal = Calendar.current
            let now = Date()
            let urgent = incomplete.filter { task in
                guard let due = task.dueDate else {
                    return false
                }
                return cal.isDateInToday(due) || due < now
            }
            let normal = incomplete.filter { task in
                guard let due = task.dueDate else {
                    return true
                }
                return !cal.isDateInToday(due) && due >= now
            }
            sessionQueue = urgent.map(\.id).shuffled() + normal.map(\.id).shuffled()
            notNowStreak = 0
        }
        currentTaskID = sessionQueue.first
        currentTask = currentTaskID.flatMap { id in incomplete.first { $0.id == id } }
    }

    private func fetchIncomplete() -> [FocalTask] {
        let descriptor = FetchDescriptor<FocalTask>(
            predicate: #Predicate { $0.completedAt == nil }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
