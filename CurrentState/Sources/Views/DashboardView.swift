import SwiftUI

/// Renders all briefing sections in display order as a vertical stack of SectionCards.
struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            ForEach(SectionID.displayOrder) { sectionId in
                if let section = appState.sections[sectionId] {
                    SectionCard(section: section) {
                        appState.refreshSection(sectionId)
                    }

                    // Add a subtle divider between sections (not after last)
                    if sectionId != lastVisibleSection {
                        Divider()
                            .padding(.vertical, 4)
                    }
                }
            }
        }
    }

    /// The last section ID that actually has content, for divider logic.
    private var lastVisibleSection: SectionID? {
        SectionID.displayOrder.last { appState.sections[$0] != nil }
    }
}
