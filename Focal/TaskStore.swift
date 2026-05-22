import Foundation
import SwiftData
import Observation

@Observable
final class TaskStore {
    private let modelContext: ModelContext
    private var sessionQueue: [UUID] = []
    private(set) var currentTaskID: UUID?

    var currentTask: FocalTask? {
        guard let id = currentTaskID else { return nil }
        return fetchIncomplete().first { $0.id == id }
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        advance()
    }

    func done() {
        guard let id = currentTaskID, let task = currentTask else { return }
        task.completedAt = Date()
        try? modelContext.save()
        sessionQueue.removeAll { $0 == id }
        advance()
        NotificationManager.shared.reschedule()
    }

    func notNow() {
        guard let id = currentTaskID else { return }
        currentTask?.lastSkippedAt = Date()
        try? modelContext.save()
        sessionQueue.removeAll { $0 == id }
        sessionQueue.append(id)
        advance()
        NotificationManager.shared.reschedule()
    }

    func addTask(title: String, note: String?) {
        let task = FocalTask(title: title, note: note.flatMap { $0.isEmpty ? nil : $0 })
        modelContext.insert(task)
        try? modelContext.save()
        if currentTaskID == nil {
            advance()
        } else {
            let insertIndex = Int.random(in: 1...sessionQueue.count)
            sessionQueue.insert(task.id, at: insertIndex)
        }
    }

    func refreshIfNeeded() {
        if currentTaskID != nil && currentTask == nil {
            advance()
        }
    }

    private func advance() {
        let incomplete = fetchIncomplete()
        let incompleteIDs = Set(incomplete.map(\.id))
        sessionQueue = sessionQueue.filter { incompleteIDs.contains($0) }
        if sessionQueue.isEmpty {
            sessionQueue = incomplete.map(\.id).shuffled()
        }
        currentTaskID = sessionQueue.first
    }

    private func fetchIncomplete() -> [FocalTask] {
        let all = (try? modelContext.fetch(FetchDescriptor<FocalTask>())) ?? []
        return all.filter { $0.completedAt == nil }
    }
}
