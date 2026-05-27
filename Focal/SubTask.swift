import Foundation
import SwiftData

@Model
final class SubTask {
    var id: UUID
    var title: String
    var isCompleted: Bool
    var createdAt: Date
    var task: FocalTask?

    init(title: String) {
        self.id = UUID()
        self.title = title
        self.isCompleted = false
        self.createdAt = Date()
    }
}
