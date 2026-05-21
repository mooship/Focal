import Foundation
import SwiftData

@Model
final class FocalTask {
    var id: UUID
    var title: String
    var note: String?
    var createdAt: Date
    var completedAt: Date?
    var lastSkippedAt: Date?

    init(title: String, note: String? = nil) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.createdAt = Date()
    }
}
