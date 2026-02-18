import Foundation

/// Events emitted by the SectionStreamParser as it processes streamed text.
enum SectionEvent: Equatable, Sendable {
    case sectionStarted(SectionID)
    case sectionContent(SectionID, String)
    case sectionCompleted(SectionID, String)
    case passthrough(String)
}

/// Accumulates raw `assistantText` chunks and extracts section boundaries
/// using `<<<SECTION:id>>>` / `<<</SECTION:id>>>` delimiters.
///
/// Handles delimiters split across chunk boundaries by retaining a buffer
/// of recent characters.
final class SectionStreamParser {
    private static let openPattern = "<<<SECTION:"
    private static let closePattern = "<<</SECTION:"
    private static let closingTag = ">>>"

    // Mutable state — only accessed via feed/flush/reset which are
    // called sequentially from AppState on the main actor.
    private var buffer = ""
    private var currentSectionId: SectionID?
    private var currentSectionContent = ""

    /// Process an incoming text chunk and return any events produced.
    func feed(_ text: String) -> [SectionEvent] {
        buffer += text
        return extractEvents()
    }

    /// Finalize the stream. Emits any remaining buffered content.
    func flush() -> [SectionEvent] {
        var events: [SectionEvent] = []

        if let sectionId = currentSectionId {
            // Stream ended without a closing delimiter — emit what we have
            let content = currentSectionContent + buffer
            if !content.isEmpty {
                events.append(.sectionCompleted(sectionId, content.trimmingCharacters(in: .newlines)))
            }
        } else if !buffer.isEmpty {
            events.append(.passthrough(buffer))
        }

        buffer = ""
        currentSectionId = nil
        currentSectionContent = ""
        return events
    }

    /// Clear all state for a new stream.
    func reset() {
        buffer = ""
        currentSectionId = nil
        currentSectionContent = ""
    }

    // MARK: - Private

    private func extractEvents() -> [SectionEvent] {
        var events: [SectionEvent] = []

        while true {
            if currentSectionId != nil {
                // We're inside a section — look for the closing delimiter
                if let closeRange = buffer.range(of: Self.closePattern) {
                    // Find the matching >>> after the close pattern
                    let afterClose = buffer[closeRange.upperBound...]
                    guard let tagEnd = afterClose.range(of: Self.closingTag) else {
                        // Incomplete closing tag — might be split across chunks.
                        // Keep the buffer and wait for more data.
                        break
                    }

                    // Extract the section ID from the closing tag to validate
                    let closingSectionRaw = String(afterClose[afterClose.startIndex..<tagEnd.lowerBound])
                    // Content before the closing delimiter belongs to the section
                    let contentBeforeClose = String(buffer[buffer.startIndex..<closeRange.lowerBound])
                    currentSectionContent += contentBeforeClose

                    let finalContent = currentSectionContent.trimmingCharacters(in: .newlines)

                    // Validate the closing section ID matches (defensive)
                    if let closingId = SectionID(rawValue: closingSectionRaw),
                       closingId == currentSectionId
                    {
                        events.append(.sectionCompleted(currentSectionId!, finalContent))
                    } else {
                        // Mismatched close tag — still emit what we have
                        events.append(.sectionCompleted(currentSectionId!, finalContent))
                    }

                    currentSectionId = nil
                    currentSectionContent = ""

                    // Advance buffer past the closing tag
                    let afterTagEnd = buffer[tagEnd.upperBound...]
                    buffer = String(afterTagEnd)
                } else {
                    // No closing delimiter found yet.
                    // To handle split delimiters, keep the last ~40 chars in the buffer
                    // and emit the rest as incremental content.
                    let safeThreshold = 40
                    if buffer.count > safeThreshold {
                        let splitIndex = buffer.index(buffer.endIndex, offsetBy: -safeThreshold)
                        let emittable = String(buffer[buffer.startIndex..<splitIndex])
                        currentSectionContent += emittable
                        events.append(.sectionContent(currentSectionId!, emittable))
                        buffer = String(buffer[splitIndex...])
                    }
                    break
                }
            } else {
                // We're outside a section — look for an opening delimiter
                if let openRange = buffer.range(of: Self.openPattern) {
                    // Find the matching >>> after the section ID
                    let afterOpen = buffer[openRange.upperBound...]
                    guard let tagEnd = afterOpen.range(of: Self.closingTag) else {
                        // Incomplete opening tag — wait for more data.
                        // But first, emit any passthrough text before the potential tag.
                        let beforeOpen = String(buffer[buffer.startIndex..<openRange.lowerBound])
                        if !beforeOpen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            events.append(.passthrough(beforeOpen))
                        }
                        // Keep only from the opening pattern onward
                        buffer = String(buffer[openRange.lowerBound...])
                        break
                    }

                    let sectionRaw = String(afterOpen[afterOpen.startIndex..<tagEnd.lowerBound])

                    // Emit any passthrough text before this delimiter
                    let beforeOpen = String(buffer[buffer.startIndex..<openRange.lowerBound])
                    if !beforeOpen.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        events.append(.passthrough(beforeOpen))
                    }

                    if let sectionId = SectionID(rawValue: sectionRaw) {
                        currentSectionId = sectionId
                        currentSectionContent = ""
                        events.append(.sectionStarted(sectionId))
                    }
                    // else: unknown section ID — skip the delimiter and continue

                    // Advance buffer past the opening tag
                    buffer = String(buffer[tagEnd.upperBound...])
                } else {
                    // No opening delimiter found.
                    // Keep last ~40 chars in case a delimiter is split across chunks.
                    let safeThreshold = 40
                    if buffer.count > safeThreshold {
                        let splitIndex = buffer.index(buffer.endIndex, offsetBy: -safeThreshold)
                        let emittable = String(buffer[buffer.startIndex..<splitIndex])
                        if !emittable.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            events.append(.passthrough(emittable))
                        }
                        buffer = String(buffer[splitIndex...])
                    }
                    break
                }
            }
        }

        return events
    }
}
