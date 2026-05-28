import Foundation
import SwiftData

enum TaskLimit {
    static let titleMax = 80
    static let noteMax = 300
}

enum RecurrenceRule: String, Codable, CaseIterable {
    case daily
    case weekdays
    case weekly
    case monthly

    var stringValue: String {
        switch self {
        case .daily: return String(localized: "Daily")
        case .weekdays: return String(localized: "Weekdays")
        case .weekly: return String(localized: "Weekly")
        case .monthly: return String(localized: "Monthly")
        }
    }

    func nextDate(from date: Date) -> Date {
        let cal = Calendar.current
        switch self {
        case .daily:
            return cal.date(byAdding: .day, value: 1, to: date)!
        case .weekdays:
            var next = cal.date(byAdding: .day, value: 1, to: date)!
            while cal.isDateInWeekend(next) {
                next = cal.date(byAdding: .day, value: 1, to: next)!
            }
            return next
        case .weekly:
            return cal.date(byAdding: .weekOfYear, value: 1, to: date)!
        case .monthly:
            return cal.date(byAdding: .month, value: 1, to: date)!
        }
    }
}

@Model
final class FocalTask {
    var id: UUID
    var title: String
    var note: String?
    var createdAt: Date
    var completedAt: Date?
    var dueDate: Date?
    var estimatedMinutes: Int?
    var recurrence: RecurrenceRule?
    @Relationship(deleteRule: .cascade, inverse: \SubTask.task)
    var subtasks: [SubTask] = []

    init(title: String, note: String? = nil, dueDate: Date? = nil, estimatedMinutes: Int? = nil, recurrence: RecurrenceRule? = nil) {
        self.id = UUID()
        self.title = title
        self.note = note
        self.createdAt = Date()
        self.dueDate = dueDate
        self.estimatedMinutes = estimatedMinutes
        self.recurrence = recurrence
    }
}
