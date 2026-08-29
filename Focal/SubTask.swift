import Foundation
import SwiftData

/// A single checklist item belonging to a `FocalTask`.
@Model
final class SubTask {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    /// The owning task; the inverse side of `FocalTask.subtasks`.
    var task: FocalTask?

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.createdAt = Date()
    }
}
