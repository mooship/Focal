import Foundation
import SwiftUI

extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
    var trimmed: String { trimmingCharacters(in: .whitespaces) }
}

func formatEstimateMinutes(_ minutes: Int) -> String {
    switch minutes {
    case 60: return String(localized: "~1 hr")
    case 90: return String(localized: "~1.5 hr")
    case 120: return String(localized: "~2 hr")
    default: return String(localized: "~\(minutes) min")
    }
}

struct DueDateDisplay {
    let text: String
    let color: Color
}

func formatDueDate(_ due: Date) -> DueDateDisplay {
    let cal = Calendar.current
    if !cal.isDateInToday(due) && due < Date() {
        return DueDateDisplay(text: String(localized: "Overdue"), color: .red)
    }
    if cal.isDateInToday(due) {
        return DueDateDisplay(text: String(localized: "Due today"), color: .orange)
    }
    if cal.isDateInTomorrow(due) {
        return DueDateDisplay(text: String(localized: "Tomorrow"), color: .blue)
    }
    return DueDateDisplay(text: due.formatted(.dateTime.month(.abbreviated).day()), color: .secondary)
}

struct EstimatePicker: View {
    @Binding var selection: Int?
    var body: some View {
        Picker("Estimate", selection: $selection) {
            Text("None").tag(Optional<Int>.none)
            Text("~5 min").tag(Optional(5))
            Text("~10 min").tag(Optional(10))
            Text("~15 min").tag(Optional(15))
            Text("~30 min").tag(Optional(30))
            Text("~45 min").tag(Optional(45))
            Text("~1 hr").tag(Optional(60))
            Text("~1.5 hr").tag(Optional(90))
            Text("~2 hr").tag(Optional(120))
        }
        .pickerStyle(.menu)
    }
}

struct RecurrencePicker: View {
    @Binding var selection: RecurrenceRule?
    var body: some View {
        Picker("Repeat", selection: $selection) {
            Text("None").tag(Optional<RecurrenceRule>.none)
            ForEach(RecurrenceRule.allCases, id: \.self) { rule in
                Text(rule.localizedLabel).tag(Optional(rule))
            }
        }
        .pickerStyle(.menu)
    }
}
