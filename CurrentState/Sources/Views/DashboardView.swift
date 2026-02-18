import SwiftUI

/// Renders all briefing sections in display order as a vertical stack of glass cards.
struct DashboardView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        GlassEffectContainer(spacing: 16) {
            VStack(spacing: 16) {
                ForEach(SectionID.displayOrder) { sectionId in
                    if let section = appState.sections[sectionId] {
                        if sectionId == .picture {
                            PictureCard(section: section) {
                                appState.refreshSection(sectionId)
                            }
                        } else {
                            SectionCard(section: section) {
                                appState.refreshSection(sectionId)
                            }
                        }
                    }
                }
            }
        }
    }
}
