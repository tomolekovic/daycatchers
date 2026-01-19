import SwiftUI
import CoreData

// MARK: - On This Day Card

struct OnThisDayCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext

    @State private var memories: [(year: Int, memories: [Memory])] = []
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: themeManager.theme.spacingMedium) {
            // Header
            HStack {
                Image(systemName: "clock.arrow.circlepath")
                    .font(.title3)
                    .foregroundStyle(themeManager.theme.primaryColor)

                Text("On This Day")
                    .font(themeManager.theme.headlineFont)
                    .foregroundStyle(themeManager.theme.textPrimary)

                Spacer()

                if !memories.isEmpty {
                    Text("\(totalCount) memories")
                        .font(themeManager.theme.captionFont)
                        .foregroundStyle(themeManager.theme.textSecondary)
                }
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if memories.isEmpty {
                emptyState
            } else {
                memoriesContent
            }
        }
        .padding()
        .background(themeManager.theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))
        .onAppear {
            loadMemories()
        }
    }

    private var totalCount: Int {
        memories.reduce(0) { $0 + $1.memories.count }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No memories from this date in previous years")
                .font(themeManager.theme.bodyFont)
                .foregroundStyle(themeManager.theme.textSecondary)
                .multilineTextAlignment(.center)

            Text("Keep capturing moments to build your history!")
                .font(themeManager.theme.captionFont)
                .foregroundStyle(themeManager.theme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, themeManager.theme.spacingSmall)
    }

    private var memoriesContent: some View {
        VStack(alignment: .leading, spacing: themeManager.theme.spacingMedium) {
            ForEach(memories, id: \.year) { yearGroup in
                VStack(alignment: .leading, spacing: 8) {
                    Text(yearsAgoText(yearGroup.year))
                        .font(themeManager.theme.captionFont)
                        .foregroundStyle(themeManager.theme.textSecondary)

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(yearGroup.memories.prefix(5)) { memory in
                                NavigationLink(destination: MemoryDetailView(memory: memory)) {
                                    OnThisDayMemoryThumbnail(memory: memory, theme: themeManager.theme)
                                }
                                .buttonStyle(.plain)
                            }

                            if yearGroup.memories.count > 5 {
                                Text("+\(yearGroup.memories.count - 5)")
                                    .font(themeManager.theme.captionFont)
                                    .foregroundStyle(themeManager.theme.primaryColor)
                                    .frame(width: 60, height: 60)
                                    .background(themeManager.theme.primaryColor.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusSmall))
                            }
                        }
                    }
                }
            }
        }
    }

    private func yearsAgoText(_ year: Int) -> String {
        let currentYear = Calendar.current.component(.year, from: Date())
        let yearsAgo = currentYear - year
        if yearsAgo == 1 {
            return "1 year ago"
        } else {
            return "\(yearsAgo) years ago"
        }
    }

    private func loadMemories() {
        isLoading = true
        DispatchQueue.main.async {
            memories = DiscoveryService.shared.onThisDay(in: viewContext)
            isLoading = false
        }
    }
}

// MARK: - On This Day Memory Thumbnail

struct OnThisDayMemoryThumbnail: View {
    let memory: Memory
    let theme: Theme

    var body: some View {
        if memory.isAccessible {
            ZStack {
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
                    theme.surfaceColor
                    Image(systemName: memory.memoryType.icon)
                        .foregroundStyle(memory.memoryType.color.opacity(0.5))
                }
            }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
    }
}

// MARK: - Rediscover Card

struct RediscoverCard: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext

    @State private var memory: Memory?
    @State private var isLoading = true

    var body: some View {
        VStack(alignment: .leading, spacing: themeManager.theme.spacingMedium) {
            // Header
            HStack {
                Image(systemName: "sparkles")
                    .font(.title3)
                    .foregroundStyle(themeManager.theme.primaryColor)

                Text("Rediscover")
                    .font(themeManager.theme.headlineFont)
                    .foregroundStyle(themeManager.theme.textPrimary)

                Spacer()

                Button(action: refreshMemory) {
                    Image(systemName: "arrow.clockwise")
                        .font(.body)
                        .foregroundStyle(themeManager.theme.primaryColor)
                }
            }

            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding()
            } else if let memory = memory {
                NavigationLink(destination: MemoryDetailView(memory: memory)) {
                    RediscoverMemoryContent(memory: memory, theme: themeManager.theme)
                }
                .buttonStyle(.plain)
            } else {
                emptyState
            }
        }
        .padding()
        .background(themeManager.theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))
        .onAppear {
            loadMemory()
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("No memories to rediscover yet")
                .font(themeManager.theme.bodyFont)
                .foregroundStyle(themeManager.theme.textSecondary)

            Text("Start capturing moments!")
                .font(themeManager.theme.captionFont)
                .foregroundStyle(themeManager.theme.textSecondary.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, themeManager.theme.spacingSmall)
    }

    private func loadMemory() {
        isLoading = true
        DispatchQueue.main.async {
            memory = DiscoveryService.shared.rediscoverMemory(in: viewContext)
            isLoading = false
        }
    }

    private func refreshMemory() {
        withAnimation {
            isLoading = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            memory = DiscoveryService.shared.rediscoverMemory(
                in: viewContext,
                excluding: memory?.id
            )
            withAnimation {
                isLoading = false
            }
        }
    }
}

// MARK: - Rediscover Memory Content

struct RediscoverMemoryContent: View {
    let memory: Memory
    let theme: Theme

    var body: some View {
        if memory.isAccessible {
            HStack(spacing: theme.spacingMedium) {
                // Thumbnail
                ZStack {
                    RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                        .fill(theme.backgroundColor)

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
                            .font(.title)
                            .foregroundStyle(memory.memoryType.color.opacity(0.5))
                    }
                }
                .frame(width: 80, height: 80)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

                // Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(memory.title ?? "Memory")
                        .font(theme.bodyFont)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(2)

                    if let lovedOne = memory.lovedOne {
                        Text(lovedOne.name ?? "")
                            .font(theme.captionFont)
                            .foregroundStyle(theme.textSecondary)
                    }

                    if let date = memory.captureDate {
                        Text(timeAgoText(from: date))
                            .font(theme.captionFont)
                            .foregroundStyle(theme.primaryColor)
                    }
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(theme.textSecondary)
            }
        }
    }

    private func timeAgoText(from date: Date) -> String {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day], from: date, to: Date())

        if let years = components.year, years > 0 {
            return years == 1 ? "1 year ago" : "\(years) years ago"
        } else if let months = components.month, months > 0 {
            return months == 1 ? "1 month ago" : "\(months) months ago"
        } else if let days = components.day, days > 0 {
            return days == 1 ? "Yesterday" : "\(days) days ago"
        } else {
            return "Today"
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        OnThisDayCard()
        RediscoverCard()
    }
    .padding()
    .background(Color.gray.opacity(0.1))
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(ThemeManager())
}
