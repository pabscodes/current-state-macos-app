@preconcurrency import MarkdownUI
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
        Markdown(message.content)
            .markdownTheme(.currentState)
            .textSelection(.enabled)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}
