import SwiftUI

struct MessageBubble: View {
    let message: Message

    var body: some View {
        switch message.role {
        case .user:
            userBubble
        case .assistant:
            assistantBubble
        }
    }

    private var userBubble: some View {
        HStack {
            Spacer()
            Text(message.content)
                .padding(12)
                .background(Color.accentColor.opacity(0.15))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .frame(maxWidth: 400, alignment: .trailing)
        }
    }

    private var assistantBubble: some View {
        // TODO: Replace with proper Markdown rendering
        // For MVP, using Text with basic formatting
        Text(message.content)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
