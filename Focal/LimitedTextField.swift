import SwiftUI

struct LimitedTextField: View {
    let label: LocalizedStringKey
    @Binding var text: String
    let limit: Int

    var body: some View {
        HStack {
            TextField(label, text: $text)
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
