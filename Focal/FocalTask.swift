import Foundation
import SwiftData

/// Character limits enforced on `FocalTask` text fields by `LimitedTextField`.
enum TaskLimit {
    static let titleMax = 80
    static let noteMax = 300
}

/// How often a completed `FocalTask` recurs. Completing a recurring task spawns its next occurrence via `TaskStore`.
enum RecurrenceRule: String, Codable, CaseIterable {
    case daily
    case weekdays
    case weekly
    case monthly

    /// Localized display name shown in recurrence pickers.
    var stringValue: String {
        switch self {
        case .daily: return String(localized: "Daily")
        case .weekdays: return String(localized: "Weekdays")
        case .weekly: return String(localized: "Weekly")
        case .monthly: return String(localized: "Monthly")
        }
    }

    /// The next occurrence on or after `minimum`, stepping forward by this rule until the minimum is reached.
    /// Used when a recurring task's due date has already passed, so the spawned occurrence isn't immediately overdue.
    func nextDate(from date: Date, notBefore minimum: Date) -> Date {
        var next = nextDate(from: date)
        while next < minimum {
            next = nextDate(from: next)
        }
        return next
    }

    /// The single next occurrence after `date` according to this rule (weekdays skips weekends).
    /// Falls back to a fixed-interval offset on the (practically unreachable) case that `Calendar`
    /// can't add the component, rather than crashing.
    func nextDate(from date: Date) -> Date {
        let cal = Calendar.current
        switch self {
        case .daily:
            return cal.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86400)
        case .weekdays:
            var next = cal.date(byAdding: .day, value: 1, to: date) ?? date.addingTimeInterval(86400)
            while cal.isDateInWeekend(next) {
                next = cal.date(byAdding: .day, value: 1, to: next) ?? next.addingTimeInterval(86400)
            }
            return next
        case .weekly:
            return cal.date(byAdding: .weekOfYear, value: 1, to: date) ?? date.addingTimeInterval(7 * 86400)
        case .monthly:
            return cal.date(byAdding: .month, value: 1, to: date) ?? date.addingTimeInterval(30 * 86400)
        }
    }
}

/// A single to-do item. `TaskStore` manages the session queue over incomplete instances of this model.
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
    /// Checklist items belonging to this task; deleted along with it.
    @Relationship(deleteRule: .cascade, inverse: \SubTask.task)
    var subtasks: [SubTask] = []

    /// `subtasks` in the order they were added, for stable display in the checklist UI.
    var sortedSubtasks: [SubTask] {
        subtasks.sorted { $0.createdAt < $1.createdAt }
    }

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
