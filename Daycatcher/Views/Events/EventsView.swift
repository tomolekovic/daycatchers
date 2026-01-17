import SwiftUI
import CoreData

struct EventsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Event.date, ascending: true)],
        animation: .default
    )
    private var events: FetchedResults<Event>

    @State private var selectedDate = Date()
    @State private var showingAddSheet = false

    private var eventsForSelectedDate: [Event] {
        let calendar = Calendar.current
        return events.filter { event in
            guard let eventDate = event.date else { return false }
            return calendar.isDate(eventDate, inSameDayAs: selectedDate)
        }
    }

    private var upcomingEvents: [Event] {
        let now = Date()
        return events.filter { event in
            guard let eventDate = event.date else { return false }
            return eventDate >= now
        }
    }

    private var pastEvents: [Event] {
        let now = Date()
        return events.filter { event in
            guard let eventDate = event.date else { return false }
            return eventDate < now
        }.reversed()
    }

    var body: some View {
        NavigationStack {
            Group {
                if events.isEmpty {
                    emptyState
                } else {
                    eventsList
                }
            }
            .background(themeManager.theme.backgroundColor)
            .navigationTitle("Events")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button(action: { showingAddSheet = true }) {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingAddSheet) {
                AddEventView()
            }
        }
    }

    // MARK: - Events List

    private var eventsList: some View {
        ScrollView {
            VStack(spacing: themeManager.theme.spacingLarge) {
                // Calendar
                calendarSection

                // Upcoming Events
                if !upcomingEvents.isEmpty {
                    eventSection(title: "Upcoming", events: Array(upcomingEvents.prefix(10)))
                }

                // Past Events
                if !pastEvents.isEmpty {
                    eventSection(title: "Past", events: Array(pastEvents.prefix(5)))
                }
            }
            .padding()
        }
    }

    // MARK: - Calendar Section

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: themeManager.theme.spacingMedium) {
            DatePicker(
                "Select Date",
                selection: $selectedDate,
                displayedComponents: .date
            )
            .datePickerStyle(.graphical)
            .tint(themeManager.theme.primaryColor)

            if !eventsForSelectedDate.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Events on \(formattedSelectedDate)")
                        .font(themeManager.theme.headlineFont)
                        .foregroundStyle(themeManager.theme.textPrimary)

                    ForEach(eventsForSelectedDate) { event in
                        NavigationLink(destination: EventDetailView(event: event)) {
                            EventCard(event: event, theme: themeManager.theme)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .padding()
        .background(themeManager.theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))
    }

    private var formattedSelectedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: selectedDate)
    }

    // MARK: - Event Section

    private func eventSection(title: String, events: [Event]) -> some View {
        VStack(alignment: .leading, spacing: themeManager.theme.spacingMedium) {
            Text(title)
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            ForEach(events) { event in
                NavigationLink(destination: EventDetailView(event: event)) {
                    EventCard(event: event, theme: themeManager.theme)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: themeManager.theme.spacingMedium) {
            Spacer()

            Image(systemName: "calendar")
                .font(.system(size: 80))
                .foregroundStyle(themeManager.theme.primaryColor.opacity(0.3))

            Text("No Events Yet")
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            Text("Add birthdays, milestones, and special dates to remember.")
                .font(themeManager.theme.bodyFont)
                .foregroundStyle(themeManager.theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Button(action: { showingAddSheet = true }) {
                Label("Add Event", systemImage: "plus")
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

// MARK: - Event Card

struct EventCard: View {
    let event: Event
    let theme: Theme

    var body: some View {
        HStack(spacing: theme.spacingMedium) {
            // Icon
            Image(systemName: event.eventTypeValue.icon)
                .font(.title3)
                .foregroundStyle(theme.primaryColor)
                .frame(width: 44, height: 44)
                .background(theme.primaryColor.opacity(0.1))
                .clipShape(Circle())

            // Info
            VStack(alignment: .leading, spacing: 4) {
                Text(event.title ?? "Event")
                    .font(theme.bodyFont)
                    .foregroundStyle(theme.textPrimary)

                HStack(spacing: 8) {
                    Text(event.shortFormattedDate)

                    if let lovedOne = event.lovedOne {
                        Text("•")
                        Text(lovedOne.name ?? "")
                    }
                }
                .font(theme.captionFont)
                .foregroundStyle(theme.textSecondary)
            }

            Spacer()

            // Days indicator
            if let daysUntil = event.daysUntil, daysUntil >= 0 {
                VStack(spacing: 2) {
                    if daysUntil == 0 {
                        Text("Today")
                            .font(theme.captionFont)
                            .fontWeight(.semibold)
                            .foregroundStyle(theme.primaryColor)
                    } else {
                        Text("\(daysUntil)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundStyle(theme.textPrimary)
                        Text("days")
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(theme.textSecondary)
        }
        .padding()
        .background(theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusMedium))
    }
}

#Preview {
    EventsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
