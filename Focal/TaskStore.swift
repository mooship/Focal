import Foundation
import SwiftData

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
        let incomplete = fetchIncomplete()
        guard let id = currentTaskID,
              let task = incomplete.first(where: { $0.id == id }) else { return }
        task.completedAt = Date()
        try? modelContext.save()
        if let i = sessionQueue.firstIndex(of: id) { sessionQueue.remove(at: i) }
        advance(with: incomplete.filter { $0.id != id })
        NotificationManager.shared.reschedule()
    }

    func notNow() {
        let incomplete = fetchIncomplete()
        guard let id = currentTaskID,
              incomplete.contains(where: { $0.id == id }) else { return }
        if let i = sessionQueue.firstIndex(of: id) { sessionQueue.remove(at: i) }
        sessionQueue.append(id)
        advance(with: incomplete)
        NotificationManager.shared.reschedule()
    }

    func addTask(title: String, note: String?) {
        let task = FocalTask(title: title, note: note?.nilIfEmpty)
        modelContext.insert(task)
        try? modelContext.save()
        if currentTaskID == nil {
            advance()
        } else {
            let insertIndex = sessionQueue.isEmpty ? 0 : Int.random(in: 1...sessionQueue.count)
            sessionQueue.insert(task.id, at: insertIndex)
        }
    }

    func deleteTask(_ task: FocalTask) {
        modelContext.delete(task)
        try? modelContext.save()
        refreshIfNeeded()
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
