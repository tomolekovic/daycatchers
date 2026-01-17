import SwiftUI
import CoreData

struct HomeView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Memory.captureDate, ascending: false)],
        predicate: nil,
        animation: .default
    )
    private var recentMemories: FetchedResults<Memory>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Event.date, ascending: true)],
        predicate: NSPredicate(format: "date >= %@", Date() as NSDate),
        animation: .default
    )
    private var upcomingEvents: FetchedResults<Event>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LovedOne.name, ascending: true)],
        animation: .default
    )
    private var lovedOnes: FetchedResults<LovedOne>

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: themeManager.theme.spacingLarge) {
                    // Greeting
                    greetingSection

                    // Quick Capture
                    quickCaptureSection

                    // Upcoming Events
                    if !upcomingEvents.isEmpty {
                        upcomingEventsSection
                    }

                    // Recent Memories
                    if !recentMemories.isEmpty {
                        recentMemoriesSection
                    }

                    // Empty State
                    if lovedOnes.isEmpty {
                        emptyStateSection
                    }
                }
                .padding()
            }
            .background(themeManager.theme.backgroundColor)
            .navigationTitle("Home")
        }
    }

    // MARK: - Greeting Section

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greeting)
                .font(themeManager.theme.titleFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            Text(dateString)
                .font(themeManager.theme.bodyFont)
                .foregroundStyle(themeManager.theme.textSecondary)
        }
    }

    private var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        default: return "Good evening"
        }
    }

    private var dateString: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }

    // MARK: - Quick Capture Section

    private var quickCaptureSection: some View {
        VStack(alignment: .leading, spacing: themeManager.theme.spacingMedium) {
            Text("Quick Capture")
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            HStack(spacing: themeManager.theme.spacingMedium) {
                QuickCaptureButton(type: .photo, theme: themeManager.theme)
                QuickCaptureButton(type: .video, theme: themeManager.theme)
                QuickCaptureButton(type: .audio, theme: themeManager.theme)
                QuickCaptureButton(type: .text, theme: themeManager.theme)
            }
        }
        .padding()
        .background(themeManager.theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))
    }

    // MARK: - Upcoming Events Section

    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: themeManager.theme.spacingMedium) {
            HStack {
                Text("Upcoming Events")
                    .font(themeManager.theme.headlineFont)
                    .foregroundStyle(themeManager.theme.textPrimary)

                Spacer()

                NavigationLink(destination: EventsView()) {
                    Text("See All")
                        .font(themeManager.theme.captionFont)
                        .foregroundStyle(themeManager.theme.primaryColor)
                }
            }

            ForEach(Array(upcomingEvents.prefix(3))) { event in
                EventRowView(event: event)
            }
        }
    }

    // MARK: - Recent Memories Section

    private var recentMemoriesSection: some View {
        VStack(alignment: .leading, spacing: themeManager.theme.spacingMedium) {
            HStack {
                Text("Recent Memories")
                    .font(themeManager.theme.headlineFont)
                    .foregroundStyle(themeManager.theme.textPrimary)

                Spacer()

                NavigationLink(destination: MemoriesTimelineView()) {
                    Text("See All")
                        .font(themeManager.theme.captionFont)
                        .foregroundStyle(themeManager.theme.primaryColor)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: themeManager.theme.spacingMedium) {
                    ForEach(Array(recentMemories.prefix(10))) { memory in
                        RecentMemoryCard(memory: memory, theme: themeManager.theme)
                    }
                }
            }
        }
    }

    // MARK: - Empty State Section

    private var emptyStateSection: some View {
        VStack(spacing: themeManager.theme.spacingMedium) {
            Image(systemName: "heart.fill")
                .font(.system(size: 60))
                .foregroundStyle(themeManager.theme.primaryColor.opacity(0.5))

            Text("Welcome to Daycatcher")
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            Text("Start by adding someone special to capture memories of.")
                .font(themeManager.theme.bodyFont)
                .foregroundStyle(themeManager.theme.textSecondary)
                .multilineTextAlignment(.center)

            NavigationLink(destination: AddLovedOneView()) {
                Text("Add Someone Special")
                    .font(themeManager.theme.headlineFont)
                    .foregroundStyle(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(themeManager.theme.primaryColor)
                    .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))
            }
        }
        .padding(.vertical, themeManager.theme.spacingLarge)
    }
}

// MARK: - Quick Capture Button

struct QuickCaptureButton: View {
    let type: MemoryType
    let theme: Theme

    var body: some View {
        Button(action: {
            // TODO: Implement capture action
        }) {
            VStack(spacing: theme.spacingSmall) {
                Image(systemName: type.icon)
                    .font(.title2)
                    .foregroundStyle(type.color)

                Text(type.displayName)
                    .font(theme.captionFont)
                    .foregroundStyle(theme.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, theme.spacingMedium)
            .background(theme.backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Event Row View

struct EventRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let event: Event

    var body: some View {
        HStack(spacing: themeManager.theme.spacingMedium) {
            Image(systemName: event.eventTypeValue.icon)
                .font(.title3)
                .foregroundStyle(themeManager.theme.primaryColor)
                .frame(width: 40, height: 40)
                .background(themeManager.theme.primaryColor.opacity(0.1))
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(event.title ?? "Event")
                    .font(themeManager.theme.bodyFont)
                    .foregroundStyle(themeManager.theme.textPrimary)

                Text(event.shortFormattedDate)
                    .font(themeManager.theme.captionFont)
                    .foregroundStyle(themeManager.theme.textSecondary)
            }

            Spacer()

            if let daysUntil = event.daysUntil {
                Text(daysUntil == 0 ? "Today" : "\(daysUntil)d")
                    .font(themeManager.theme.captionFont)
                    .foregroundStyle(daysUntil == 0 ? themeManager.theme.primaryColor : themeManager.theme.textSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(daysUntil == 0 ? themeManager.theme.primaryColor.opacity(0.1) : themeManager.theme.surfaceColor)
                    .clipShape(Capsule())
            }
        }
        .padding()
        .background(themeManager.theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusSmall))
    }
}

// MARK: - Recent Memory Card

struct RecentMemoryCard: View {
    let memory: Memory
    let theme: Theme

    var body: some View {
        VStack(alignment: .leading, spacing: theme.spacingSmall) {
            // Thumbnail placeholder
            ZStack {
                RoundedRectangle(cornerRadius: theme.cornerRadiusSmall)
                    .fill(theme.surfaceColor)

                Image(systemName: memory.memoryType.icon)
                    .font(.largeTitle)
                    .foregroundStyle(memory.memoryType.color.opacity(0.5))
            }
            .frame(width: 120, height: 120)

            VStack(alignment: .leading, spacing: 2) {
                Text(memory.title ?? "Memory")
                    .font(theme.captionFont)
                    .foregroundStyle(theme.textPrimary)
                    .lineLimit(1)

                if let lovedOne = memory.lovedOne {
                    Text(lovedOne.name ?? "")
                        .font(theme.captionFont)
                        .foregroundStyle(theme.textSecondary)
                }
            }
        }
        .frame(width: 120)
    }
}

#Preview {
    HomeView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
