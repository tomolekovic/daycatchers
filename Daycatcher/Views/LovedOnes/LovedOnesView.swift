import SwiftUI
import CoreData

struct LovedOnesView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LovedOne.name, ascending: true)],
        animation: .default
    )
    private var lovedOnes: FetchedResults<LovedOne>

    @State private var searchText = ""
    @State private var showingAddSheet = false

    private var filteredLovedOnes: [LovedOne] {
        if searchText.isEmpty {
            return Array(lovedOnes)
        }
        return lovedOnes.filter { ($0.name ?? "").localizedCaseInsensitiveContains(searchText) }
    }

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if lovedOnes.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        LazyVGrid(columns: columns, spacing: 16) {
                            ForEach(filteredLovedOnes) { lovedOne in
                                NavigationLink(destination: LovedOneDetailView(lovedOne: lovedOne)) {
                                    LovedOneCard(lovedOne: lovedOne, theme: themeManager.theme)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding()
                    }
                    .searchable(text: $searchText, prompt: "Search")
                }
            }
            .background(themeManager.theme.backgroundColor)
            .navigationTitle("Loved Ones")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddLovedOneView()
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: themeManager.theme.spacingMedium) {
            Spacer()

            Image(systemName: "person.2.fill")
                .font(.system(size: 80))
                .foregroundStyle(themeManager.theme.primaryColor.opacity(0.3))

            Text("No Loved Ones Yet")
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            Text("Add someone special to start capturing memories together.")
                .font(themeManager.theme.bodyFont)
                .foregroundStyle(themeManager.theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: { showingAddSheet = true }) {
                Label("Add Someone Special", systemImage: "plus")
                    .font(themeManager.theme.headlineFont)
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(themeManager.theme.primaryColor)
                    .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))
            }
            .padding(.horizontal, 40)

            Spacer()
        }
    }
}

// MARK: - Loved One Card

struct LovedOneCard: View {
    let lovedOne: LovedOne
    let theme: Theme

    var body: some View {
        VStack(spacing: theme.spacingMedium) {
            // Profile Image
            profileImage

            // Info
            VStack(spacing: 4) {
                Text(lovedOne.name ?? "Unknown")
                    .font(theme.headlineFont)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                HStack(spacing: 4) {
                    Image(systemName: lovedOne.relationshipType.icon)
                        .font(.caption)

                    Text(lovedOne.relationshipType.displayName)
                        .font(theme.captionFont)
                }
                .foregroundStyle(theme.textSecondary)

                if let age = lovedOne.formattedAge {
                    Text(age)
                        .font(theme.captionFont)
                        .foregroundStyle(theme.textSecondary)
                }
            }

            // Stats
            HStack(spacing: theme.spacingMedium) {
                StatBadge(icon: "photo.fill", count: lovedOne.memoryCount, theme: theme)
                StatBadge(icon: "calendar", count: lovedOne.eventCount, theme: theme)
            }
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusMedium))
        .shadow(color: theme.shadowColor, radius: theme.shadowRadius, x: 0, y: 2)
    }

    @ViewBuilder
    private var profileImage: some View {
        if let imageURL = lovedOne.profileImageURL,
           let imageData = try? Data(contentsOf: imageURL),
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 80, height: 80)
                .clipShape(Circle())
        } else {
            // Initials placeholder
            Circle()
                .fill(theme.primaryColor.opacity(0.2))
                .frame(width: 80, height: 80)
                .overlay {
                    Text(initials)
                        .font(.title)
                        .fontWeight(.semibold)
                        .foregroundStyle(theme.primaryColor)
                }
        }
    }

    private var initials: String {
        let name = lovedOne.name ?? ""
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let icon: String
    let count: Int
    let theme: Theme

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text("\(count)")
                .font(theme.captionFont)
        }
        .foregroundStyle(theme.textSecondary)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(theme.backgroundColor)
        .clipShape(Capsule())
    }
}

#Preview {
    LovedOnesView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
