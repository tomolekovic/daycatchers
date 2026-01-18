import SwiftUI
import CoreData

/// View displaying all weekly digests
struct DigestsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \WeeklyDigest.weekStartDate, ascending: false)],
        animation: .default
    )
    private var digests: FetchedResults<WeeklyDigest>

    var body: some View {
        Group {
            if digests.isEmpty {
                emptyState
            } else {
                digestList
            }
        }
        .navigationTitle("Weekly Digests")
        .background(themeManager.theme.backgroundColor)
    }

    // MARK: - Digest List

    private var digestList: some View {
        List {
            ForEach(digests) { digest in
                NavigationLink(destination: DigestDetailView(digest: digest)) {
                    DigestRowView(digest: digest)
                }
                .listRowBackground(themeManager.theme.surfaceColor)
            }
        }
        .listStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: themeManager.theme.spacingLarge) {
            Spacer()

            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 60))
                .foregroundStyle(themeManager.theme.primaryColor.opacity(0.5))

            Text("No Digests Yet")
                .font(themeManager.theme.titleFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            Text("Weekly digests will appear here after you've captured memories for a full week.")
                .font(themeManager.theme.bodyFont)
                .foregroundStyle(themeManager.theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Digest Row View

struct DigestRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @ObservedObject var digest: WeeklyDigest

    var body: some View {
        HStack(spacing: themeManager.theme.spacingMedium) {
            // Week icon
            ZStack {
                RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusSmall)
                    .fill(themeManager.theme.primaryColor.opacity(digest.isRead ? 0.1 : 0.2))
                    .frame(width: 50, height: 50)

                VStack(spacing: 0) {
                    Text(weekDayLabel)
                        .font(.caption2)
                        .fontWeight(.medium)
                    Text(weekNumberLabel)
                        .font(.title3)
                        .fontWeight(.bold)
                }
                .foregroundStyle(themeManager.theme.primaryColor)
            }

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(digest.formattedWeekRange)
                        .font(themeManager.theme.headlineFont)
                        .foregroundStyle(themeManager.theme.textPrimary)

                    if !digest.isRead {
                        Circle()
                            .fill(themeManager.theme.primaryColor)
                            .frame(width: 8, height: 8)
                    }
                }

                Text(digest.summary ?? "No summary available")
                    .font(themeManager.theme.captionFont)
                    .foregroundStyle(themeManager.theme.textSecondary)
                    .lineLimit(2)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(themeManager.theme.textSecondary)
        }
        .padding(.vertical, 8)
    }

    private var weekDayLabel: String {
        "WEEK"
    }

    private var weekNumberLabel: String {
        guard let date = digest.weekStartDate else { return "?" }
        let weekOfYear = Calendar.current.component(.weekOfYear, from: date)
        return "\(weekOfYear)"
    }
}

#Preview {
    NavigationStack {
        DigestsView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(ThemeManager())
}
