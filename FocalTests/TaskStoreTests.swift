import Testing
import SwiftData
import Foundation
@testable import Focal

struct TaskStoreTests {

    private func makeStore(tasks: [FocalTask] = []) throws -> (TaskStore, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: FocalTask.self, SubTask.self, configurations: config)
        let context = ModelContext(container)
        for task in tasks {
            context.insert(task)
        }
        try context.save()
        return (TaskStore(modelContext: context), context)
    }

    @Test func emptyStoreHasNoCurrentTask() throws {
        let (store, _) = try makeStore()
        #expect(store.currentTask == nil)
    }

    @Test func storeWithOneTaskShowsIt() throws {
        let (store, _) = try makeStore(tasks: [FocalTask(title: "Write tests")])
        #expect(store.currentTask?.title == "Write tests")
    }

    @Test func notNowWithOneTaskKeepsSameTask() throws {
        let task = FocalTask(title: "Only task")
        let (store, _) = try makeStore(tasks: [task])
        let id = store.currentTaskID
        store.notNow()
        #expect(store.currentTaskID == id)
    }

    @Test func doneSingleTaskLeavesEmptyState() throws {
        let (store, _) = try makeStore(tasks: [FocalTask(title: "Only task")])
        store.done()
        #expect(store.currentTask == nil)
    }

    @Test func doneMarksTaskCompletedAtAndAdvances() throws {
        let (store, context) = try makeStore(tasks: [FocalTask(title: "A"), FocalTask(title: "B")])
        let firstID = store.currentTaskID
        store.done()
        let all = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        #expect(all.first { $0.id == firstID }?.completedAt != nil)
        #expect(store.currentTaskID != firstID)
    }

    @Test func completingFinalTaskIncrementsQueueCleared() throws {
        let (store, _) = try makeStore(tasks: [FocalTask(title: "Only task")])
        #expect(store.queueCleared == 0)
        store.done()
        #expect(store.queueCleared == 1)
    }

    @Test func completingNonFinalTaskDoesNotIncrementQueueCleared() throws {
        let (store, _) = try makeStore(tasks: [FocalTask(title: "A"), FocalTask(title: "B")])
        store.done()
        #expect(store.queueCleared == 0)
        store.done()
        #expect(store.queueCleared == 1)
    }

    @Test func notNowChangesCurrentTaskWhenMultipleExist() throws {
        let (store, _) = try makeStore(tasks: [FocalTask(title: "A"), FocalTask(title: "B")])
        let firstID = store.currentTaskID
        store.notNow()
        #expect(store.currentTaskID != firstID)
    }

    @Test func notNowReturnsFirstTaskAfterCycle() throws {
        let (store, _) = try makeStore(tasks: [FocalTask(title: "A"), FocalTask(title: "B")])
        let firstID = store.currentTaskID
        store.notNow()
        store.notNow()
        #expect(store.currentTaskID == firstID)
    }

    @Test func addTaskWithNilNoteStoresNil() throws {
        let (store, context) = try makeStore()
        store.addTask(title: "Task", note: nil)
        let tasks = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        #expect(tasks.first?.note == nil)
    }

    @Test func addTaskWithEmptyStringNoteStoresNil() throws {
        let (store, context) = try makeStore()
        store.addTask(title: "Task", note: "")
        let tasks = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        #expect(tasks.first?.note == nil)
    }

    @Test func addTaskWithWhitespaceOnlyNoteStoresNil() throws {
        let (store, context) = try makeStore()
        store.addTask(title: "Task", note: "   ")
        let tasks = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        #expect(tasks.first?.note == nil)
    }

    @Test func addTaskWhenEmptyMakesItCurrent() throws {
        let (store, _) = try makeStore()
        #expect(store.currentTask == nil)
        store.addTask(title: "New task", note: nil)
        #expect(store.currentTask?.title == "New task")
    }

    @Test func deleteTaskAdvancesWhenCurrentTaskDeleted() throws {
        let t1 = FocalTask(title: "Task 1")
        let t2 = FocalTask(title: "Task 2")
        let (store, _) = try makeStore(tasks: [t1, t2])
        guard let current = store.currentTask else {
            Issue.record("Expected a current task")
            return
        }
        let deletedTitle = current.title
        store.deleteTask(current)
        #expect(store.currentTask != nil)
        #expect(store.currentTask?.title != deletedTitle)
    }

    @Test func addTaskWhenNonEmptyPreservesCurrentTask() throws {
        let (store, _) = try makeStore(tasks: [FocalTask(title: "Existing")])
        let originalID = store.currentTaskID
        store.addTask(title: "New", note: nil)
        #expect(store.currentTaskID == originalID)
    }

    @Test func doneWhenEmptyIsNoOp() throws {
        let (store, _) = try makeStore()
        store.done()
        #expect(store.currentTask == nil)
    }

    @Test func notNowCyclesAfterAddingTaskWhileNonEmpty() throws {
        let (store, _) = try makeStore(tasks: [FocalTask(title: "First")])
        store.addTask(title: "Second", note: nil)
        let firstID = store.currentTaskID
        store.notNow()
        #expect(store.currentTaskID != firstID)
    }

    @Test func deleteTaskSetsPendingUndo() throws {
        let (store, _) = try makeStore(tasks: [FocalTask(title: "Buy milk")])
        guard let task = store.currentTask else {
            Issue.record("Expected current task")
            return
        }
        store.deleteTask(task)
        #expect(store.pendingUndo?.title == "Buy milk")
    }

    @Test func deleteTaskPendingUndoPreservesNote() throws {
        let task = FocalTask(title: "Read book", note: "Chapter 3")
        let (store, _) = try makeStore(tasks: [task])
        store.deleteTask(task)
        #expect(store.pendingUndo?.note == "Chapter 3")
    }

    @Test func undoDeleteRestoresIncompleteTask() throws {
        let (store, context) = try makeStore(tasks: [FocalTask(title: "Walk dog")])
        guard let task = store.currentTask else {
            Issue.record("Expected current task")
            return
        }
        store.deleteTask(task)
        store.undoDelete()
        let all = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        #expect(all.contains { $0.title == "Walk dog" })
        #expect(store.currentTask?.title == "Walk dog")
    }

    @Test func undoDeleteRestoredTaskIsIncomplete() throws {
        let (store, context) = try makeStore(tasks: [FocalTask(title: "Call mum")])
        guard let task = store.currentTask else {
            Issue.record("Expected current task")
            return
        }
        store.deleteTask(task)
        store.undoDelete()
        let all = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        #expect(all.first { $0.title == "Call mum" }?.completedAt == nil)
    }

    @Test func undoDeleteCompletedTaskPreservesCompletedAt() throws {
        let task = FocalTask(title: "Done task")
        let completedDate = Date(timeIntervalSinceReferenceDate: 1_000_000)
        task.completedAt = completedDate
        let (store, context) = try makeStore(tasks: [task])
        store.deleteTask(task)
        store.undoDelete()
        let all = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        #expect(all.first { $0.title == "Done task" }?.completedAt == completedDate)
    }

    @Test func undoDeleteWhenNoPendingUndoIsNoOp() throws {
        let (store, context) = try makeStore(tasks: [FocalTask(title: "Existing")])
        store.undoDelete()
        let all = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        #expect(all.count == 1)
    }

    @Test func undoDeleteClearsPendingUndo() throws {
        let (store, _) = try makeStore(tasks: [FocalTask(title: "Gym")])
        guard let task = store.currentTask else {
            Issue.record("Expected current task")
            return
        }
        store.deleteTask(task)
        store.undoDelete()
        #expect(store.pendingUndo == nil)
    }

    @Test func restoreTaskMakesItIncomplete() throws {
        let task = FocalTask(title: "Old task")
        task.completedAt = Date()
        let (store, _) = try makeStore(tasks: [task])
        store.restoreTask(task)
        #expect(task.completedAt == nil)
    }

    @Test func restoreTaskBecomesCurrentWhenStoreWasEmpty() throws {
        let task = FocalTask(title: "Revived")
        task.completedAt = Date()
        let (store, _) = try makeStore(tasks: [task])
        #expect(store.currentTask == nil)
        store.restoreTask(task)
        #expect(store.currentTask?.title == "Revived")
    }

    @Test func restoreTaskDoesNotChangeCurrentWhenQueueActive() throws {
        let active = FocalTask(title: "Active")
        let completed = FocalTask(title: "Completed")
        completed.completedAt = Date()
        let (store, _) = try makeStore(tasks: [active, completed])
        let originalID = store.currentTaskID
        store.restoreTask(completed)
        #expect(store.currentTaskID == originalID)
    }

    @Test func prioritizeTaskBecomesCurrentImmediately() throws {
        let t1 = FocalTask(title: "A")
        let t2 = FocalTask(title: "B")
        let (store, _) = try makeStore(tasks: [t1, t2])
        let nonCurrent = store.currentTaskID == t1.id ? t2 : t1
        store.prioritizeTask(nonCurrent)
        #expect(store.currentTaskID == nonCurrent.id)
    }

    @Test func prioritizeTaskAlreadyCurrentIsNoOp() throws {
        let (store, _) = try makeStore(tasks: [FocalTask(title: "Only")])
        let id = store.currentTaskID
        guard let current = store.currentTask else {
            Issue.record("Expected current task")
            return
        }
        store.prioritizeTask(current)
        #expect(store.currentTaskID == id)
    }

    @Test func prioritizeTaskThenNotNowCyclesCorrectly() throws {
        let t1 = FocalTask(title: "A")
        let t2 = FocalTask(title: "B")
        let t3 = FocalTask(title: "C")
        let (store, _) = try makeStore(tasks: [t1, t2, t3])
        store.prioritizeTask(t3)
        #expect(store.currentTaskID == t3.id)
        store.notNow()
        #expect(store.currentTaskID != t3.id)
    }

    @Test func doneWithTaskIDCompletesCorrectTask() throws {
        let t1 = FocalTask(title: "A")
        let t2 = FocalTask(title: "B")
        let (store, context) = try makeStore(tasks: [t1, t2])
        let pinnedID = store.currentTaskID
        guard let pinnedID else {
            Issue.record("Expected a current task")
            return
        }
        store.done(taskID: pinnedID)
        let all = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        #expect(all.first { $0.id == pinnedID }?.completedAt != nil)
        #expect(store.currentTaskID != pinnedID)
    }

    @Test func doneWithTaskIDCompletesOriginalTaskAfterCurrentChanges() throws {
        let t1 = FocalTask(title: "A")
        let t2 = FocalTask(title: "B")
        let (store, context) = try makeStore(tasks: [t1, t2])
        let pinnedID = store.currentTaskID
        guard let pinnedID else {
            Issue.record("Expected a current task")
            return
        }
        let other = pinnedID == t1.id ? t2 : t1
        store.prioritizeTask(other)
        #expect(store.currentTaskID == other.id)
        store.done(taskID: pinnedID)
        let all = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        #expect(all.first { $0.id == pinnedID }?.completedAt != nil)
        #expect(all.first { $0.id == other.id }?.completedAt == nil)
    }

    @Test func doneWithTaskIDIsNoOpWhenTaskAlreadyDeleted() throws {
        let t1 = FocalTask(title: "A")
        let t2 = FocalTask(title: "B")
        let (store, context) = try makeStore(tasks: [t1, t2])
        let pinnedID = store.currentTaskID
        guard let pinnedID, let currentTask = store.currentTask else {
            Issue.record("Expected a current task")
            return
        }
        store.deleteTask(currentTask)
        store.done(taskID: pinnedID)
        let all = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        #expect(all.filter { $0.completedAt != nil }.isEmpty)
    }

    @Test func addTaskWithDueDateStoresDueDate() throws {
        let (store, context) = try makeStore()
        let due = Date(timeIntervalSinceNow: 86400)
        store.addTask(title: "Task", note: nil, dueDate: due)
        let tasks = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        #expect(tasks.first?.dueDate == due)
    }

    @Test func addTaskWithEstimateStoresEstimate() throws {
        let (store, context) = try makeStore()
        store.addTask(title: "Task", note: nil, estimatedMinutes: 30)
        let tasks = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        #expect(tasks.first?.estimatedMinutes == 30)
    }

    @Test func addTaskWithRecurrenceStoresRecurrence() throws {
        let (store, context) = try makeStore()
        store.addTask(title: "Daily standup", note: nil, recurrence: .daily)
        let tasks = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        #expect(tasks.first?.recurrence == .daily)
    }

    @Test func doneOnRecurringTaskMarksOriginalComplete() throws {
        let due = Calendar.current.startOfDay(for: Date())
        let task = FocalTask(title: "Standup", dueDate: due, recurrence: .daily)
        let (store, context) = try makeStore(tasks: [task])
        store.done()
        let all = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        #expect(all.first { $0.title == "Standup" && $0.completedAt != nil } != nil)
    }

    @Test func doneOnRecurringTaskCreatesNextOccurrence() throws {
        let due = Calendar.current.startOfDay(for: Date())
        let task = FocalTask(title: "Standup", dueDate: due, recurrence: .daily)
        let (store, context) = try makeStore(tasks: [task])
        store.done()
        let all = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        let next = all.first { $0.completedAt == nil && $0.title == "Standup" }
        #expect(next != nil)
        let expectedDue = Calendar.current.date(byAdding: .day, value: 1, to: due)!
        #expect(next?.dueDate == expectedDue)
    }

    @Test func doneOnOverdueRecurringTaskRollsNextOccurrenceForward() throws {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let overdue = cal.date(byAdding: .day, value: -5, to: todayStart)!
        let task = FocalTask(title: "Standup", dueDate: overdue, recurrence: .daily)
        let (store, context) = try makeStore(tasks: [task])
        store.done()
        let all = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        let next = all.first { $0.completedAt == nil && $0.title == "Standup" }
        #expect(next != nil)
        #expect(next?.dueDate == todayStart)
    }

    @Test func doneOnOverdueWeeklyRecurringTaskKeepsCadenceAnchor() throws {
        let cal = Calendar.current
        let todayStart = cal.startOfDay(for: Date())
        let overdue = cal.date(byAdding: .day, value: -10, to: todayStart)!
        let task = FocalTask(title: "Review", dueDate: overdue, recurrence: .weekly)
        let (store, context) = try makeStore(tasks: [task])
        store.done()
        let all = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        let next = all.first { $0.completedAt == nil && $0.title == "Review" }
        let expectedDue = cal.date(byAdding: .day, value: 4, to: todayStart)!
        #expect(next?.dueDate == expectedDue)
    }

    @Test func addSubtaskCreatesLinkedSubTask() throws {
        let task = FocalTask(title: "Project")
        let (store, context) = try makeStore(tasks: [task])
        store.addSubtask(to: task, title: "Research")
        let subs = (try? context.fetch(FetchDescriptor<SubTask>())) ?? []
        #expect(subs.count == 1)
        #expect(subs.first?.title == "Research")
        #expect(subs.first?.task?.id == task.id)
    }

    @Test func deleteSubtaskRemovesIt() throws {
        let task = FocalTask(title: "Project")
        let (store, context) = try makeStore(tasks: [task])
        store.addSubtask(to: task, title: "Research")
        let subs = (try? context.fetch(FetchDescriptor<SubTask>())) ?? []
        guard let sub = subs.first else {
            Issue.record("Expected a subtask")
            return
        }
        store.deleteSubtask(sub)
        let remaining = (try? context.fetch(FetchDescriptor<SubTask>())) ?? []
        #expect(remaining.isEmpty)
    }

    @Test func toggleSubtaskFlipsCompletion() throws {
        let task = FocalTask(title: "Project")
        let (store, _) = try makeStore(tasks: [task])
        store.addSubtask(to: task, title: "Research")
        guard let sub = task.subtasks.first else {
            Issue.record("Expected a subtask")
            return
        }
        #expect(sub.isCompleted == false)
        store.toggleSubtask(sub, in: task)
        #expect(sub.isCompleted == true)
        store.toggleSubtask(sub, in: task)
        #expect(sub.isCompleted == false)
    }

    @Test func toggleSubtaskAllCompleteAutoCompletesParent() throws {
        let task = FocalTask(title: "Project")
        let (store, _) = try makeStore(tasks: [task])
        store.addSubtask(to: task, title: "Step 1")
        store.addSubtask(to: task, title: "Step 2")
        let subs = task.subtasks.sorted { $0.createdAt < $1.createdAt }
        guard subs.count == 2 else {
            Issue.record("Expected 2 subtasks")
            return
        }
        store.toggleSubtask(subs[0], in: task)
        #expect(store.currentTask?.title == "Project")
        store.toggleSubtask(subs[1], in: task)
        #expect(task.completedAt != nil)
    }

    @Test func toggleSubtaskOneIncompleteDoesNotAutoCompleteParent() throws {
        let task = FocalTask(title: "Project")
        let (store, _) = try makeStore(tasks: [task])
        store.addSubtask(to: task, title: "Step 1")
        store.addSubtask(to: task, title: "Step 2")
        let subs = task.subtasks.sorted { $0.createdAt < $1.createdAt }
        guard subs.count == 2 else {
            Issue.record("Expected 2 subtasks")
            return
        }
        store.toggleSubtask(subs[0], in: task)
        #expect(task.completedAt == nil)
    }

    @Test func undoDeleteRestoresTaskWithSubtasks() throws {
        let task = FocalTask(title: "Project")
        let (store, context) = try makeStore(tasks: [task])
        store.addSubtask(to: task, title: "Research")
        store.addSubtask(to: task, title: "Write")
        store.deleteTask(task)
        store.undoDelete()
        let allTasks = (try? context.fetch(FetchDescriptor<FocalTask>())) ?? []
        let restored = allTasks.first { $0.title == "Project" && $0.completedAt == nil }
        #expect(restored != nil)
        let subs = (try? context.fetch(FetchDescriptor<SubTask>())) ?? []
        #expect(subs.count == 2)
    }
}
