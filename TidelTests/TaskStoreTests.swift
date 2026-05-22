import Testing
import SwiftData
@testable import Tidel

struct TaskStoreTests {

    private func makeStore(tasks: [TidelTask] = []) throws -> (TaskStore, ModelContext) {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: TidelTask.self, configurations: config)
        let context = ModelContext(container)
        for task in tasks { context.insert(task) }
        try context.save()
        return (TaskStore(modelContext: context), context)
    }

    @Test func emptyStoreHasNoCurrentTask() throws {
        let (store, _) = try makeStore()
        #expect(store.currentTask == nil)
    }

    @Test func storeWithOneTaskShowsIt() throws {
        let (store, _) = try makeStore(tasks: [TidelTask(title: "Write tests")])
        #expect(store.currentTask?.title == "Write tests")
    }

    @Test func notNowWithOneTaskKeepsSameTask() throws {
        let task = TidelTask(title: "Only task")
        let (store, _) = try makeStore(tasks: [task])
        let id = store.currentTaskID
        store.notNow()
        #expect(store.currentTaskID == id)
    }

    @Test func doneSingleTaskLeavesEmptyState() throws {
        let (store, _) = try makeStore(tasks: [TidelTask(title: "Only task")])
        store.done()
        #expect(store.currentTask == nil)
    }

    @Test func doneMarksTaskCompletedAtAndAdvances() throws {
        let (store, context) = try makeStore(tasks: [TidelTask(title: "A"), TidelTask(title: "B")])
        let firstID = store.currentTaskID
        store.done()
        let all = (try? context.fetch(FetchDescriptor<TidelTask>())) ?? []
        #expect(all.first { $0.id == firstID }?.completedAt != nil)
        #expect(store.currentTaskID != firstID)
    }

    @Test func notNowChangesCurrentTaskWhenMultipleExist() throws {
        let (store, _) = try makeStore(tasks: [TidelTask(title: "A"), TidelTask(title: "B")])
        let firstID = store.currentTaskID
        store.notNow()
        #expect(store.currentTaskID != firstID)
    }

    @Test func notNowReturnsFirstTaskAfterCycle() throws {
        let (store, _) = try makeStore(tasks: [TidelTask(title: "A"), TidelTask(title: "B")])
        let firstID = store.currentTaskID
        store.notNow()
        store.notNow()
        #expect(store.currentTaskID == firstID)
    }

    @Test func addTaskWithNilNoteStoresNil() throws {
        let (store, context) = try makeStore()
        store.addTask(title: "Task", note: nil)
        let tasks = (try? context.fetch(FetchDescriptor<TidelTask>())) ?? []
        #expect(tasks.first?.note == nil)
    }

    @Test func addTaskWithEmptyStringNoteStoresNil() throws {
        let (store, context) = try makeStore()
        store.addTask(title: "Task", note: "")
        let tasks = (try? context.fetch(FetchDescriptor<TidelTask>())) ?? []
        #expect(tasks.first?.note == nil)
    }

    @Test func addTaskWhenEmptyMakesItCurrent() throws {
        let (store, _) = try makeStore()
        #expect(store.currentTask == nil)
        store.addTask(title: "New task", note: nil)
        #expect(store.currentTask?.title == "New task")
    }

    @Test func deleteTaskAdvancesWhenCurrentTaskDeleted() throws {
        let t1 = TidelTask(title: "Task 1")
        let t2 = TidelTask(title: "Task 2")
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
        let (store, _) = try makeStore(tasks: [TidelTask(title: "Existing")])
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
        let (store, _) = try makeStore(tasks: [TidelTask(title: "First")])
        store.addTask(title: "Second", note: nil)
        let firstID = store.currentTaskID
        store.notNow()
        #expect(store.currentTaskID != firstID)
    }
}
