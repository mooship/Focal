import Foundation
import SwiftData

enum TaskLimit {
    static let titleMax = 80
    static let noteMax = 300
}

@Model
final class TidelTask {
    var id: UUID
    var title: String
    var note: String?
    var createdAt: Date
    var completedAt: Date?

    init(title: String, note: String? = nil) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.createdAt = Date()
    }
}
