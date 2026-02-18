import SwiftUI

struct InputBar: View {
    let placeholder: String
    let onSend: (String) -> Void

    @State private var text = ""
    @FocusState private var isFocused: Bool

    init(placeholder: String = "Type a message...", onSend: @escaping (String) -> Void) {
        self.placeholder = placeholder
        self.onSend = onSend
    }

    var body: some View {
        HStack(spacing: 8) {
            TextField(placeholder, text: $text, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(1...5)
                .focused($isFocused)
                .onSubmit {
                    send()
                }

            Button(action: send) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
            }
            .buttonStyle(.glassProminent)
            .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(12)
        .glassEffect(in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .onAppear {
            isFocused = true
        }
    }

    private func send() {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSend(trimmed)
        text = ""
        isFocused = true
    }
}
