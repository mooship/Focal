import Foundation
import SwiftUI

extension String {
    /// `nil` if the string is empty, otherwise the string unchanged.
    var nilIfEmpty: String? { isEmpty ? nil : self }
    /// Leading/trailing whitespace stripped; does not coerce an empty result to `nil` (see `nilIfEmpty`).
    var trimmed: String { trimmingCharacters(in: .whitespaces) }
}

/// Formats an estimate in minutes for display, using "hr" phrasing for the picker's hour-scale values.
func formatEstimateMinutes(_ minutes: Int) -> String {
    switch minutes {
    case 60: return String(localized: "1 hr")
    case 90: return String(localized: "1.5 hr")
    case 120: return String(localized: "2 hr")
    default: return String(localized: "\(minutes) min")
    }
}

/// A due-date badge's text and color, as computed by `formatDueDate(_:)`.
struct DueDateDisplay {
    let text: String
    let color: Color
}

/// Renders a due date relative to now: "Overdue" (red) if past and not today, "Due today"
/// (orange), "Tomorrow" (blue), or the abbreviated month/day (secondary) otherwise.
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

/// A small capsule badge used for estimate/due-date/recurrence meta on a task.
func metaBadge(_ text: String, color: Color) -> some View {
    Text(text)
        .font(.caption)
        .foregroundStyle(color)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.12), in: Capsule())
}

extension View {
    /// The standard accessibility label/hint for a button that marks `task` done directly.
    func markDoneAccessibility(for task: FocalTask) -> some View {
        self
            .accessibilityLabel(Text(String(localized: "Mark \(task.title) as done")))
            .accessibilityHint("Marks task as complete")
    }

    /// Marks this view as behaving like a button that opens the task editor, for VoiceOver users
    /// who navigate to it directly. The tappable region itself may extend beyond this view.
    func opensEditorAccessibility() -> some View {
        self
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Opens task editor")
    }
}

/// A checkbox-style icon (filled when completed) sized to the minimum 44×44 tap target, used by
/// task/subtask completion toggle buttons.
struct CheckboxIcon: View {
    let isCompleted: Bool

    var body: some View {
        Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
            .foregroundStyle(isCompleted ? .secondary : .primary)
            .imageScale(.large)
            .frame(minWidth: 44, minHeight: 44)
            .contentShape(Rectangle())
    }
}

/// A centered icon + title + subtitle layout for empty states. `bounceValue` optionally drives a
/// bounce animation on the icon when it changes (pass `nil` for a static icon).
struct EmptyStateView: View {
    let systemImage: String
    let iconStyle: AnyShapeStyle
    let title: LocalizedStringKey
    let subtitle: LocalizedStringKey
    var bounceValue: Int? = nil

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 52))
                .foregroundStyle(iconStyle)
                .symbolEffect(.bounce, value: bounceValue ?? 0)
                .accessibilityHidden(true)
                .padding(.bottom, 4)
            Text(title)
                .font(.title2.weight(.medium))
            Text(subtitle)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .multilineTextAlignment(.center)
        .padding()
        .accessibilityElement(children: .combine)
    }
}

/// Menu picker for a task's estimated duration, from a fixed set of preset minute values.
struct EstimatePicker: View {
    @Binding var selection: Int?
    var body: some View {
        Picker("Estimate", selection: $selection) {
            Text("None").tag(Optional<Int>.none)
            Text("5 min").tag(Optional(5))
            Text("10 min").tag(Optional(10))
            Text("15 min").tag(Optional(15))
            Text("30 min").tag(Optional(30))
            Text("45 min").tag(Optional(45))
            Text("1 hr").tag(Optional(60))
            Text("1.5 hr").tag(Optional(90))
            Text("2 hr").tag(Optional(120))
        }
        .pickerStyle(.menu)
    }
}

/// Menu picker for a task's `RecurrenceRule`.
struct RecurrencePicker: View {
    @Binding var selection: RecurrenceRule?
    var body: some View {
        Picker("Repeat", selection: $selection) {
            Text("None").tag(Optional<RecurrenceRule>.none)
            ForEach(RecurrenceRule.allCases, id: \.self) { rule in
                Text(rule.stringValue).tag(Optional(rule))
            }
        }
        .pickerStyle(.menu)
    }
}

/// Text field for typing a new subtask title; submitting (return, or the plus button once
/// non-empty) invokes `onCommit`, which is expected to append the draft and clear `text`.
struct SubtaskInputField: View {
    @Binding var text: String
    let onCommit: () -> Void

    var body: some View {
        HStack {
            TextField("New subtask", text: $text)
                .onSubmit(onCommit)
            if !text.trimmed.isEmpty {
                Button(action: onCommit) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.secondary)
                        .frame(minWidth: 44, minHeight: 44)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Add subtask")
            }
        }
    }
}

extension View {
    /// Attaches an `UndoBanner` as a bottom safe-area inset whenever `undo` is non-nil, animating
    /// its appearance/disappearance when `animate` is true.
    func undoBanner(_ undo: TaskStore.PendingUndoAction?, animate: Bool, onUndo: @escaping () -> Void) -> some View {
        safeAreaInset(edge: .bottom) {
            if let undo {
                UndoBanner(label: undo.bannerTitle, onUndo: onUndo)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(animate ? .spring(duration: 0.3) : nil, value: undo)
    }
}

/// Banner shown after deleting or completing a task, offering to undo it before `TaskStore`'s
/// undo window expires. Posts a VoiceOver announcement of `label` on appear.
struct UndoBanner: View {
    let label: String
    let onUndo: () -> Void

    var body: some View {
        HStack {
            Text(label)
                .lineLimit(1)
                .truncationMode(.middle)
            Spacer()
            Button("Undo", action: onUndo)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onAppear {
            AccessibilityNotification.Announcement(label).post()
        }
    }
}
