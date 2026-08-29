import Foundation
import SwiftData
import UIKit

/// Owns the session queue — a randomised, non-repeating cycle of incomplete tasks — and all
/// mutations to `FocalTask`/`SubTask` data. `MainView` reads `currentTask` and drives the queue
/// via `done()`/`notNow()`.
@Observable
final class TaskStore {
    private let modelContext: ModelContext
    /// IDs of incomplete tasks in the order they'll be shown, most-recent-`notNow` last.
    private var sessionQueue: [UUID] = []
    private(set) var currentTaskID: UUID?
    private(set) var pendingUndo: PendingUndoAction? = nil
    private var undoTask: Task<Void, Never>?

    /// A subtask's title and completion state, captured for undo after its parent task is deleted.
    struct SubtaskSnapshot: Equatable {
        let title: String
        let isCompleted: Bool
    }

    /// A snapshot of a deleted `FocalTask`, held for the undo window and used to recreate it in `undo()`.
    struct DeletedTaskSnapshot: Equatable {
        let title: String
        let note: String?
        let completedAt: Date?
        let dueDate: Date?
        let estimatedMinutes: Int?
        let recurrence: RecurrenceRule?
        let subtasks: [SubtaskSnapshot]
    }

    /// A just-completed `FocalTask`, held for the undo window. `taskID` still exists in the store
    /// (just marked complete); `spawnedTaskID` is the next occurrence `done(taskID:)` spawned for a
    /// recurring task, if any, which `undo()` deletes so undoing doesn't leave a duplicate behind.
    struct CompletedTaskInfo: Equatable {
        let taskID: UUID
        let title: String
        let spawnedTaskID: UUID?
    }

    /// A pending delete or complete action, held for the undo window and shown in the undo banner.
    enum PendingUndoAction: Equatable {
        case delete(DeletedTaskSnapshot)
        case complete(CompletedTaskInfo)

        /// The title of the task this pending action concerns, regardless of kind.
        var title: String {
            switch self {
            case .delete(let snapshot): return snapshot.title
            case .complete(let info): return info.title
            }
        }

        /// The undo banner's message, naming the action taken.
        var bannerTitle: String {
            switch self {
            case .delete: return String(localized: "Deleted \"\(title)\"")
            case .complete: return String(localized: "Completed \"\(title)\"")
            }
        }
    }

    private(set) var currentTask: FocalTask?
    /// Consecutive `notNow()` calls since the last `done()`, reset on completion or reordering.
    private(set) var notNowStreak: Int = 0
    /// Number of times the queue has been fully worked through to empty.
    private(set) var queueCleared: Int = 0

    /// True once every task currently in the queue has been passed over at least once this cycle.
    var hasCompletedCycle: Bool {
        !sessionQueue.isEmpty && notNowStreak >= sessionQueue.count
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        advance()
        seedHasCompletedTaskIfNeeded()
    }

    /// Completes the currently displayed task. No-op if there is none.
    func done() {
        guard let id = currentTaskID else {
            return
        }
        done(taskID: id)
    }

    /// Marks the given incomplete task as completed, spawning its next occurrence first if it
    /// recurs, then advances the queue to the next task. Records a `pendingUndo` so `undo()` can
    /// reverse this within the undo window, deleting the spawned occurrence if there was one.
    func done(taskID: UUID) {
        let incomplete = fetchIncomplete()
        guard let task = incomplete.first(where: { $0.id == taskID }) else {
            return
        }

        var spawnedTask: FocalTask?
        if let rule = task.recurrence {
            let today = Calendar.current.startOfDay(for: Date())
            let base = task.dueDate ?? today
            let nextDue = rule.nextDate(from: base, notBefore: today)
            let subtaskTitles = task.sortedSubtasks.map(\.title)
            spawnedTask = addTask(
                title: task.title,
                note: task.note,
                dueDate: nextDue,
                estimatedMinutes: task.estimatedMinutes,
                recurrence: rule,
                subtaskTitles: subtaskTitles
            )
        }

        let title = task.title
        task.completedAt = Date()
        notNowStreak = 0
        UserDefaults.standard.set(true, forKey: DefaultsKey.hasCompletedTask)
        try? modelContext.save()
        if let i = sessionQueue.firstIndex(of: taskID) {
            sessionQueue.remove(at: i)
        }
        if task.recurrence != nil {
            advance(with: fetchIncomplete())
        } else {
            advance(with: incomplete.filter { $0.id != taskID })
        }
        if currentTaskID == nil {
            queueCleared += 1
        }
        updateInactivityNotification()

        pendingUndo = .complete(CompletedTaskInfo(taskID: taskID, title: title, spawnedTaskID: spawnedTask?.id))
        scheduleUndoExpiry()
    }

    /// Defers the currently displayed task to the end of the queue and shows the next one.
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

    /// Creates a new task (and any subtasks) and inserts it into the queue: shown immediately if
    /// nothing is currently displayed, otherwise slotted in at a random position. Returns the
    /// created task.
    @discardableResult
    func addTask(
        title: String,
        note: String?,
        dueDate: Date? = nil,
        estimatedMinutes: Int? = nil,
        recurrence: RecurrenceRule? = nil,
        subtaskTitles: [String] = []
    ) -> FocalTask {
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
            enqueueRandomly(task.id)
        }
        updateInactivityNotification()
        return task
    }

    /// Deletes the task, snapshotting it to `pendingUndo` so `undo()` can recreate it within the
    /// undo window.
    func deleteTask(_ task: FocalTask) {
        let snapshot = DeletedTaskSnapshot(
            title: task.title,
            note: task.note,
            completedAt: task.completedAt,
            dueDate: task.dueDate,
            estimatedMinutes: task.estimatedMinutes,
            recurrence: task.recurrence,
            subtasks: task.sortedSubtasks.map {
                SubtaskSnapshot(title: $0.title, isCompleted: $0.isCompleted)
            }
        )
        removeTask(task)
        notNowStreak = 0
        updateInactivityNotification()

        pendingUndo = .delete(snapshot)
        scheduleUndoExpiry()
    }

    /// Reverses the most recent delete or complete action, if the undo window hasn't expired.
    func undo() {
        guard let pending = pendingUndo else {
            return
        }
        undoTask?.cancel()
        undoTask = nil
        pendingUndo = nil

        switch pending {
        case .delete(let snapshot):
            undoDeleteTask(snapshot)
        case .complete(let info):
            undoCompleteTask(info)
        }
    }

    /// Recreates a deleted task (and its subtasks) from its snapshot. Recreated completed tasks
    /// are not re-added to the queue.
    private func undoDeleteTask(_ snapshot: DeletedTaskSnapshot) {
        let task = FocalTask(
            title: snapshot.title,
            note: snapshot.note.flatMap { $0.trimmed.nilIfEmpty },
            dueDate: snapshot.dueDate,
            estimatedMinutes: snapshot.estimatedMinutes,
            recurrence: snapshot.recurrence
        )
        if let completedAt = snapshot.completedAt {
            task.completedAt = completedAt
        }
        modelContext.insert(task)
        for subtask in snapshot.subtasks {
            let sub = SubTask(title: subtask.title)
            sub.isCompleted = subtask.isCompleted
            sub.task = task
            modelContext.insert(sub)
        }
        try? modelContext.save()

        if snapshot.completedAt == nil {
            if currentTaskID == nil {
                advance()
            } else {
                enqueueRandomly(task.id)
            }
        }
        updateInactivityNotification()
    }

    /// Un-completes the task that was just marked done, deleting the occurrence `done(taskID:)`
    /// spawned for it (if it was recurring) so the undo doesn't leave a duplicate behind.
    private func undoCompleteTask(_ info: CompletedTaskInfo) {
        var ids: Set<UUID> = [info.taskID]
        if let spawnedID = info.spawnedTaskID {
            ids.insert(spawnedID)
        }
        let tasks = fetchTasks(ids: ids)

        if let spawnedID = info.spawnedTaskID, let spawned = tasks.first(where: { $0.id == spawnedID }) {
            removeTask(spawned)
        }
        guard let task = tasks.first(where: { $0.id == info.taskID }) else {
            return
        }
        restoreTask(task)
    }

    /// Un-completes a previously completed task, resetting its subtasks if all were checked off,
    /// and re-inserts it into the queue at a random position.
    func restoreTask(_ task: FocalTask) {
        task.completedAt = nil
        if !task.subtasks.isEmpty && task.subtasks.allSatisfy(\.isCompleted) {
            task.subtasks.forEach { $0.isCompleted = false }
        }
        try? modelContext.save()
        guard !sessionQueue.contains(task.id) else {
            return
        }
        enqueueRandomly(task.id)
        if currentTaskID == nil {
            advance()
        }
        updateInactivityNotification()
    }

    /// Moves an incomplete task to the front of the queue and displays it immediately ("Focus now").
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

    func updateSubtask(_ subtask: SubTask, title: String, isCompleted: Bool) {
        subtask.title = title
        subtask.isCompleted = isCompleted
        try? modelContext.save()
    }

    /// Flips a subtask's completion state, then completes the parent task if this made every subtask done.
    func toggleSubtask(_ subtask: SubTask, in task: FocalTask) {
        subtask.isCompleted.toggle()
        try? modelContext.save()
        completeIfAllSubtasksDone(task)
    }

    /// Completes `task` via `done(taskID:)` if it's still incomplete, has subtasks, and all of them are checked off.
    func completeIfAllSubtasksDone(_ task: FocalTask) {
        guard task.completedAt == nil,
              !task.subtasks.isEmpty,
              task.subtasks.allSatisfy(\.isCompleted) else {
            return
        }
        done(taskID: task.id)
    }

    /// Cancels inactivity notifications while no task is displayed, otherwise reschedules them.
    func updateInactivityNotification() {
        if currentTaskID == nil {
            NotificationManager.shared.cancelAll()
        } else {
            NotificationManager.shared.reschedule(taskTitle: currentTask?.title)
        }
    }

    private func refreshIfNeeded() {
        if currentTaskID == nil {
            advance()
        }
    }

    /// How long `pendingUndo` stays available before it expires: longer while VoiceOver or Switch
    /// Control is running, since dismissing/reaching the undo banner takes more time.
    private var undoWindowSeconds: Double {
        UIAccessibility.isVoiceOverRunning || UIAccessibility.isSwitchControlRunning ? 12 : 6
    }

    /// Cancels any in-flight undo expiry and starts a fresh one for the current `pendingUndo`.
    private func scheduleUndoExpiry() {
        undoTask?.cancel()
        let window = undoWindowSeconds
        undoTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .seconds(window))
                self?.pendingUndo = nil
            } catch {}
        }
    }

    private func fetchTasks(ids: Set<UUID>) -> [FocalTask] {
        let descriptor = FetchDescriptor<FocalTask>(predicate: #Predicate { ids.contains($0.id) })
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    /// Removes `task` from the session queue and the store, then reconciles `currentTaskID`/
    /// `currentTask` if it was the task on screen. Leaves `pendingUndo`, `notNowStreak`, and
    /// `updateInactivityNotification()` to the caller.
    private func removeTask(_ task: FocalTask) {
        let id = task.id
        if let i = sessionQueue.firstIndex(of: id) {
            sessionQueue.remove(at: i)
        }
        modelContext.delete(task)
        try? modelContext.save()
        if currentTaskID == id {
            advance()
        } else {
            refreshIfNeeded()
        }
    }

    /// Inserts `id` at a random position in the queue, never at index 0 so it doesn't preempt the
    /// task currently on screen.
    private func enqueueRandomly(_ id: UUID) {
        let insertIndex = sessionQueue.isEmpty ? 0 : Int.random(in: 1...sessionQueue.count)
        sessionQueue.insert(id, at: insertIndex)
        notNowStreak = 0
    }

    /// Recomputes `currentTaskID`/`currentTask` from the queue, reshuffling a fresh cycle when the
    /// queue has run dry: due-today/overdue tasks first (shuffled among themselves), then the rest
    /// (also shuffled). Pass `preloaded` to reuse an already-fetched list instead of hitting the store again.
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

    /// One-time migration: if a task was already completed before `DefaultsKey.hasCompletedTask`
    /// existed, sets the flag retroactively instead of re-showing onboarding.
    private func seedHasCompletedTaskIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: DefaultsKey.hasCompletedTask) else {
            return
        }
        var descriptor = FetchDescriptor<FocalTask>(
            predicate: #Predicate { $0.completedAt != nil }
        )
        descriptor.fetchLimit = 1
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        if count > 0 {
            UserDefaults.standard.set(true, forKey: DefaultsKey.hasCompletedTask)
        }
    }

    private func fetchIncomplete() -> [FocalTask] {
        let descriptor = FetchDescriptor<FocalTask>(
            predicate: #Predicate { $0.completedAt == nil }
        )
        return (try? modelContext.fetch(descriptor)) ?? []
    }
}
