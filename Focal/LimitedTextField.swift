import SwiftUI

/// A `TextField` with a hard character `limit`: shows a live remaining-character counter once
/// within 20 characters of the limit (red once at it), and clamps `text` to the limit as the user types.
struct LimitedTextField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    let limit: Int
    var axis: Axis = .horizontal

    var body: some View {
        HStack {
            TextField(label, text: $text, axis: axis)
                .accessibilityHint(Text("Maximum \(limit) characters"))
            if text.count > limit - 20 {
                Text("\(limit - text.count)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(text.count >= limit ? .red : .secondary)
                    .accessibilityLabel(Text("\(limit - text.count) characters remaining"))
            }
        }
        .onChange(of: text) { _, new in
            if new.count > limit {
                text = String(new.prefix(limit))
            }
        }
    }
}
