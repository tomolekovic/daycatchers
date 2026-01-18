import SwiftUI

/// View displaying search suggestions including recent searches, people, and tags
struct SearchSuggestionsView: View {
    @EnvironmentObject var themeManager: ThemeManager

    let lovedOnes: [LovedOne]
    let tags: [Tag]
    let onSearchSelect: (String) -> Void
    let onClearHistory: () -> Void

    @State private var recentSearches: [String] = []

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: themeManager.theme.spacingLarge) {
                // Recent Searches
                if !recentSearches.isEmpty {
                    recentSearchesSection
                }

                // People Suggestions
                if !lovedOnes.isEmpty {
                    peopleSuggestionsSection
                }

                // Tag Suggestions
                if !tags.isEmpty {
                    tagSuggestionsSection
                }
            }
            .padding()
        }
        .background(themeManager.theme.backgroundColor)
        .onAppear {
            recentSearches = SearchHistoryManager.shared.recentSearches
        }
    }

    // MARK: - Recent Searches Section

    private var recentSearchesSection: some View {
        VStack(alignment: .leading, spacing: themeManager.theme.spacingMedium) {
            HStack {
                Label("Recent", systemImage: "clock")
                    .font(themeManager.theme.captionFont)
                    .foregroundStyle(themeManager.theme.textSecondary)

                Spacer()

                Button("Clear") {
                    SearchHistoryManager.shared.clearHistory()
                    recentSearches = []
                    onClearHistory()
                }
                .font(themeManager.theme.captionFont)
                .foregroundStyle(themeManager.theme.primaryColor)
            }

            ForEach(recentSearches, id: \.self) { search in
                HStack {
                    Button {
                        onSearchSelect(search)
                    } label: {
                        HStack {
                            Image(systemName: "magnifyingglass")
                                .foregroundStyle(themeManager.theme.textSecondary)

                            Text(search)
                                .font(themeManager.theme.bodyFont)
                                .foregroundStyle(themeManager.theme.textPrimary)

                            Spacer()
                        }
                    }

                    Button {
                        SearchHistoryManager.shared.removeSearch(search)
                        recentSearches = SearchHistoryManager.shared.recentSearches
                    } label: {
                        Image(systemName: "xmark")
                            .font(.caption)
                            .foregroundStyle(themeManager.theme.textSecondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - People Suggestions Section

    private var peopleSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: themeManager.theme.spacingMedium) {
            Label("People", systemImage: "person.2")
                .font(themeManager.theme.captionFont)
                .foregroundStyle(themeManager.theme.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(lovedOnes) { lovedOne in
                        Button {
                            onSearchSelect(lovedOne.name ?? "")
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: lovedOne.relationshipType.icon)
                                    .font(.caption)

                                Text(lovedOne.name ?? "Unknown")
                                    .font(themeManager.theme.captionFont)
                            }
                            .foregroundStyle(themeManager.theme.primaryColor)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(themeManager.theme.primaryColor.opacity(0.1))
                            .clipShape(Capsule())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Tag Suggestions Section

    private var tagSuggestionsSection: some View {
        VStack(alignment: .leading, spacing: themeManager.theme.spacingMedium) {
            Label("Tags", systemImage: "tag")
                .font(themeManager.theme.captionFont)
                .foregroundStyle(themeManager.theme.textSecondary)

            TagFlowLayout(spacing: 8) {
                ForEach(tags) { tag in
                    Button {
                        onSearchSelect(tag.name ?? "")
                    } label: {
                        Text(tag.name ?? "Unknown")
                            .font(themeManager.theme.captionFont)
                            .foregroundStyle(themeManager.theme.textPrimary)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(themeManager.theme.surfaceColor)
                            .clipShape(Capsule())
                    }
                }
            }
        }
    }
}

// MARK: - Tag Flow Layout

/// A simple flow layout for arranging tags
struct TagFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? .infinity, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: ProposedViewSize(result.sizes[index])
            )
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var sizes: [CGSize] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0
            var maxWidth: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth, currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                sizes.append(size)

                currentX += size.width + spacing
                lineHeight = max(lineHeight, size.height)
                maxWidth = max(maxWidth, currentX)
            }

            size = CGSize(width: maxWidth, height: currentY + lineHeight)
        }
    }
}

#Preview {
    SearchSuggestionsView(
        lovedOnes: [],
        tags: [],
        onSearchSelect: { _ in },
        onClearHistory: {}
    )
    .environmentObject(ThemeManager())
}
