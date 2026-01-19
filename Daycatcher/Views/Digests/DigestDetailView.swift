import SwiftUI
import CoreData

/// Detailed view of a single weekly digest
struct DigestDetailView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext

    @ObservedObject var digest: WeeklyDigest

    @State private var highlightedMemories: [Memory] = []
    @State private var allMemories: [Memory] = []
    @State private var isLoading = true

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: themeManager.theme.spacingLarge) {
                // Header
                headerSection

                // Summary
                summarySection

                // Stats
                statsSection

                // Highlighted Memories
                if !highlightedMemories.isEmpty {
                    highlightedSection
                }

                // All Memories Grid
                if !allMemories.isEmpty {
                    allMemoriesSection
                }
            }
            .padding()
        }
        .background(themeManager.theme.backgroundColor)
        .navigationTitle("Week \(weekNumber)")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadMemories()
            markAsRead()
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(digest.formattedWeekRange)
                .font(themeManager.theme.titleFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            if let generatedAt = digest.generatedAt {
                Text("Generated \(generatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(themeManager.theme.captionFont)
                    .foregroundStyle(themeManager.theme.textSecondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Summary

    private var summarySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Summary", systemImage: "text.quote")
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            Text(digest.summary ?? "No summary available")
                .font(themeManager.theme.bodyFont)
                .foregroundStyle(themeManager.theme.textSecondary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(themeManager.theme.surfaceColor)
                .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))
        }
    }

    // MARK: - Stats

    private var statsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("This Week", systemImage: "chart.bar")
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            HStack(spacing: themeManager.theme.spacingMedium) {
                StatCard(
                    icon: "photo",
                    value: "\(photoCount)",
                    label: "Photos",
                    color: MemoryType.photo.color,
                    theme: themeManager.theme
                )

                StatCard(
                    icon: "video",
                    value: "\(videoCount)",
                    label: "Videos",
                    color: MemoryType.video.color,
                    theme: themeManager.theme
                )

                StatCard(
                    icon: "waveform",
                    value: "\(audioCount)",
                    label: "Audio",
                    color: MemoryType.audio.color,
                    theme: themeManager.theme
                )

                StatCard(
                    icon: "doc.text",
                    value: "\(textCount)",
                    label: "Notes",
                    color: MemoryType.text.color,
                    theme: themeManager.theme
                )
            }
        }
    }

    // MARK: - Highlighted Section

    private var highlightedSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Highlights", systemImage: "star.fill")
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: themeManager.theme.spacingMedium) {
                    ForEach(highlightedMemories.filter { $0.isAccessible }) { memory in
                        NavigationLink(destination: MemoryDetailView(memory: memory)) {
                            HighlightedMemoryCard(memory: memory, theme: themeManager.theme)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    // MARK: - All Memories Section

    private var accessibleMemories: [Memory] {
        allMemories.filter { $0.isAccessible }
    }

    private var allMemoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("All Memories (\(accessibleMemories.count))", systemImage: "square.grid.2x2")
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: themeManager.theme.spacingSmall) {
                ForEach(accessibleMemories) { memory in
                    NavigationLink(destination: MemoryDetailView(memory: memory)) {
                        MemoryGridItem(memory: memory, theme: themeManager.theme)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Computed Properties

    private var weekNumber: String {
        guard let date = digest.weekStartDate else { return "?" }
        return "\(Calendar.current.component(.weekOfYear, from: date))"
    }

    private var photoCount: Int {
        accessibleMemories.filter { $0.memoryType == .photo }.count
    }

    private var videoCount: Int {
        accessibleMemories.filter { $0.memoryType == .video }.count
    }

    private var audioCount: Int {
        accessibleMemories.filter { $0.memoryType == .audio }.count
    }

    private var textCount: Int {
        accessibleMemories.filter { $0.memoryType == .text }.count
    }

    // MARK: - Actions

    private func loadMemories() async {
        highlightedMemories = await DigestService.shared.getHighlightedMemories(for: digest, in: viewContext)
        allMemories = await DigestService.shared.getWeekMemories(for: digest, in: viewContext)
        isLoading = false
    }

    private func markAsRead() {
        if !digest.isRead {
            DigestService.shared.markAsRead(digest, in: viewContext)
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let icon: String
    let value: String
    let label: String
    let color: Color
    let theme: Theme

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)

            Text(value)
                .font(theme.headlineFont)
                .foregroundStyle(theme.textPrimary)

            Text(label)
                .font(theme.captionFont)
                .foregroundStyle(theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, theme.spacingMedium)
        .background(theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }
}

// MARK: - Highlighted Memory Card

struct HighlightedMemoryCard: View {
    let memory: Memory
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSmall) {
            // Thumbnail
            ZStack {
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                    .fill(theme.surfaceColor)

                if let thumbnailPath = memory.thumbnailPath,
                   let image = MediaManager.shared.loadThumbnail(filename: thumbnailPath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else if memory.memoryType == .photo,
                          let mediaPath = memory.mediaPath,
                          let image = MediaManager.shared.loadImage(filename: mediaPath, type: .photo) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: memory.memoryType.icon)
                        .font(.largeTitle)
                        .foregroundStyle(memory.memoryType.color.opacity(0.5))
                }

                // Type badge
                VStack {
                    HStack {
                        Spacer()
                        Image(systemName: memory.memoryType.icon)
                            .font(.caption)
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(memory.memoryType.color)
                            .clipShape(Circle())
                            .padding(6)
                    }
                    Spacer()
                }
            }
            .frame(width: 150, height: 150)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(memory.title ?? memory.memoryType.displayName)
                    .font(theme.captionFont)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                if let lovedOne = memory.lovedOne {
                    Text(lovedOne.name ?? "")
                        .font(theme.captionFont)
                        .foregroundStyle(theme.textSecondary)
                        .lineLimit(1)
                }
            }
        }
        .frame(width: 150)
    }
}

// MARK: - Memory Grid Item

struct MemoryGridItem: View {
    let memory: Memory
    let theme: Theme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                .fill(theme.surfaceColor)

            if let thumbnailPath = memory.thumbnailPath,
               let image = MediaManager.shared.loadThumbnail(filename: thumbnailPath) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else if memory.memoryType == .photo,
                      let mediaPath = memory.mediaPath,
                      let image = MediaManager.shared.loadImage(filename: mediaPath, type: .photo) {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: memory.memoryType.icon)
                    .font(.title2)
                    .foregroundStyle(memory.memoryType.color.opacity(0.5))
            }

            // Type indicator
            VStack {
                HStack {
                    Spacer()
                    Image(systemName: memory.memoryType.icon)
                        .font(.caption2)
                        .foregroundStyle(.white)
                        .padding(3)
                        .background(memory.memoryType.color.opacity(0.8))
                        .clipShape(Circle())
                        .padding(4)
                }
                Spacer()
            }
        }
        .aspectRatio(1, contentMode: .fill)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
    }
}

#Preview {
    NavigationStack {
        DigestDetailView(digest: {
            let context = PersistenceController.preview.container.viewContext
            let digest = WeeklyDigest(context: context)
            digest.id = UUID()
            digest.weekStartDate = Calendar.current.date(byAdding: .weekOfYear, value: -1, to: Date())
            digest.summary = "You captured 12 memories this week: 8 photos, 2 videos, 1 audio note, 1 text note. Featuring Emma. Highlights include: Birthday, First steps."
            digest.isRead = false
            digest.generatedAt = Date()
            return digest
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(ThemeManager())
}
