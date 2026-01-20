import SwiftUI

struct CalendarTimelineView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let memories: [Memory]
    var onMemorySelect: ((Memory) -> Void)?

    @State private var currentDate = Date()
    @State private var selectedDate: Date?

    private let calendar = Calendar.current
    private let daysOfWeek = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var currentMonth: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter.string(from: currentDate)
    }

    private var memoriesByDay: [Date: [Memory]] {
        let accessibleMemories = memories.filter { $0.isAccessible }
        return Dictionary(grouping: accessibleMemories) { memory -> Date in
            guard let captureDate = memory.captureDate else {
                return Date.distantPast
            }
            return calendar.startOfDay(for: captureDate)
        }
    }

    private var daysInMonth: [Date?] {
        var days: [Date?] = []

        guard let monthInterval = calendar.dateInterval(of: .month, for: currentDate) else {
            return days
        }

        // Add nil for days before the first day of the month
        let firstDayWeekday = calendar.component(.weekday, from: monthInterval.start)
        for _ in 1..<firstDayWeekday {
            days.append(nil)
        }

        // Add all days in the month
        var date = monthInterval.start
        while date < monthInterval.end {
            days.append(date)
            date = calendar.date(byAdding: .day, value: 1, to: date)!
        }

        return days
    }

    private var selectedDayMemories: [Memory] {
        guard let selected = selectedDate else { return [] }
        let dayStart = calendar.startOfDay(for: selected)
        return memoriesByDay[dayStart] ?? []
    }

    var body: some View {
        VStack(spacing: 0) {
            // Month navigation
            monthNavigation

            // Weekday headers
            weekdayHeaders

            // Calendar grid
            calendarGrid

            Divider()
                .padding(.vertical, 8)

            // Selected day memories
            selectedDaySection
        }
        .background(themeManager.theme.backgroundColor)
    }

    // MARK: - Month Navigation

    private var monthNavigation: some View {
        HStack {
            Button(action: previousMonth) {
                Image(systemName: "chevron.left")
                    .font(.title3)
                    .foregroundStyle(themeManager.theme.primaryColor)
            }

            Spacer()

            Text(currentMonth)
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            Spacer()

            Button(action: nextMonth) {
                Image(systemName: "chevron.right")
                    .font(.title3)
                    .foregroundStyle(themeManager.theme.primaryColor)
            }
        }
        .padding()
    }

    private func previousMonth() {
        if let newDate = calendar.date(byAdding: .month, value: -1, to: currentDate) {
            withAnimation {
                currentDate = newDate
                selectedDate = nil
            }
        }
    }

    private func nextMonth() {
        if let newDate = calendar.date(byAdding: .month, value: 1, to: currentDate) {
            withAnimation {
                currentDate = newDate
                selectedDate = nil
            }
        }
    }

    // MARK: - Weekday Headers

    private var weekdayHeaders: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 0) {
            ForEach(daysOfWeek, id: \.self) { day in
                Text(day)
                    .font(themeManager.theme.captionFont)
                    .foregroundStyle(themeManager.theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Calendar Grid

    private var calendarGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
            ForEach(Array(daysInMonth.enumerated()), id: \.offset) { index, date in
                if let date = date {
                    CalendarDayCell(
                        date: date,
                        isSelected: isSameDay(date, selectedDate),
                        isToday: isSameDay(date, Date()),
                        memoryCount: memoriesByDay[calendar.startOfDay(for: date)]?.count ?? 0,
                        theme: themeManager.theme
                    )
                    .onTapGesture {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isSameDay(date, selectedDate) {
                                selectedDate = nil
                            } else {
                                selectedDate = date
                            }
                        }
                    }
                } else {
                    Color.clear
                        .frame(height: 44)
                }
            }
        }
        .padding(.horizontal)
    }

    private func isSameDay(_ date1: Date?, _ date2: Date?) -> Bool {
        guard let d1 = date1, let d2 = date2 else { return false }
        return calendar.isDate(d1, inSameDayAs: d2)
    }

    // MARK: - Selected Day Section

    private var selectedDaySection: some View {
        VStack(alignment: .leading, spacing: themeManager.theme.spacingMedium) {
            if let selected = selectedDate {
                HStack {
                    Text(formattedDate(selected))
                        .font(themeManager.theme.headlineFont)
                        .foregroundStyle(themeManager.theme.textPrimary)

                    Spacer()

                    Text("\(selectedDayMemories.count) memories")
                        .font(themeManager.theme.captionFont)
                        .foregroundStyle(themeManager.theme.textSecondary)
                }
                .padding(.horizontal)

                if selectedDayMemories.isEmpty {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.largeTitle)
                            .foregroundStyle(themeManager.theme.textSecondary.opacity(0.5))

                        Text("No memories on this day")
                            .font(themeManager.theme.bodyFont)
                            .foregroundStyle(themeManager.theme.textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, themeManager.theme.spacingLarge)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(selectedDayMemories) { memory in
                                SafeMemoryNavigationLink(
                                    memory: memory,
                                    onSelect: { onMemorySelect?($0) }
                                ) {
                                    CalendarMemoryCard(memory: memory, theme: themeManager.theme)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "calendar")
                        .font(.largeTitle)
                        .foregroundStyle(themeManager.theme.textSecondary.opacity(0.5))

                    Text("Tap a day to see memories")
                        .font(themeManager.theme.bodyFont)
                        .foregroundStyle(themeManager.theme.textSecondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, themeManager.theme.spacingLarge)
            }

            Spacer()
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d, yyyy"
        return formatter.string(from: date)
    }
}

// MARK: - Calendar Day Cell

struct CalendarDayCell: View {
    let date: Date
    let isSelected: Bool
    let isToday: Bool
    let memoryCount: Int
    let theme: Theme

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }

    var body: some View {
        VStack(spacing: 2) {
            Text(dayNumber)
                .font(theme.bodyFont)
                .fontWeight(isToday ? .bold : .regular)
                .foregroundStyle(textColor)

            // Memory indicators (dots)
            if memoryCount > 0 {
                HStack(spacing: 2) {
                    ForEach(0..<min(memoryCount, 3), id: \.self) { _ in
                        Circle()
                            .fill(isSelected ? .white : theme.primaryColor)
                            .frame(width: 4, height: 4)
                    }
                    if memoryCount > 3 {
                        Text("+")
                            .font(.system(size: 8))
                            .foregroundStyle(isSelected ? .white : theme.primaryColor)
                    }
                }
            } else {
                Color.clear.frame(height: 4)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 44)
        .background(backgroundColor)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var textColor: Color {
        if isSelected {
            return .white
        } else if isToday {
            return theme.primaryColor
        } else {
            return theme.textPrimary
        }
    }

    private var backgroundColor: Color {
        if isSelected {
            return theme.primaryColor
        } else if isToday {
            return theme.primaryColor.opacity(0.1)
        } else {
            return .clear
        }
    }
}

// MARK: - Calendar Memory Card

struct CalendarMemoryCard: View {
    let memory: Memory
    let theme: Theme

    var body: some View {
        // Guard against inaccessible memories to prevent Core Data fault crashes.
        // This is critical because SwiftUI may evaluate this body AFTER a CloudKit sync
        // deletes the memory, even if the parent ForEach had a filter.
        if memory.isAccessible {
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
                        VStack(spacing: 4) {
                            Image(systemName: memory.memoryType.icon)
                                .font(.title)
                                .foregroundStyle(memory.memoryType.color.opacity(0.7))

                            Text(memory.memoryType.displayName)
                                .font(.caption2)
                                .foregroundStyle(theme.textSecondary)
                        }
                    }
                }
                .frame(width: 100, height: 100)
                .clipShape(RoundedRectangle(cornerRadius: theme.cornerRadiusSmall))

                // Title
                VStack(alignment: .leading, spacing: 2) {
                    Text(memory.title ?? "Memory")
                        .font(theme.captionFont)
                        .foregroundStyle(theme.textPrimary)
                        .lineLimit(1)

                    if let time = memory.captureDate {
                        Text(time, style: .time)
                            .font(.caption2)
                            .foregroundStyle(theme.textSecondary)
                    }
                }
            }
            .frame(width: 100)
        }
    }
}

#Preview {
    NavigationStack {
        CalendarTimelineView(memories: [])
            .environmentObject(ThemeManager())
    }
}
