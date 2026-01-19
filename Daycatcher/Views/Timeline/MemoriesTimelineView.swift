import SwiftUI
import CoreData

struct MemoriesTimelineView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Memory.captureDate, ascending: false)],
        animation: .default
    )
    private var memories: FetchedResults<Memory>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LovedOne.name, ascending: true)],
        animation: .default
    )
    private var lovedOnes: FetchedResults<LovedOne>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Tag.name, ascending: true)],
        animation: .default
    )
    private var allTags: FetchedResults<Tag>

    @State private var searchText = ""
    @State private var selectedLovedOne: LovedOne?
    @State private var selectedType: MemoryType?
    @State private var showingFilters = false
    @State private var viewMode: ViewMode = .grid

    // Phase 4 additions
    @State private var sortOption: SortOption = .newestFirst
    @State private var groupingOption: GroupingOption = .byMonth
    @State private var startDate: Date?
    @State private var endDate: Date?
    @State private var selectedTags: Set<Tag> = []
    @State private var isSearchActive = false

    enum ViewMode: String, CaseIterable {
        case grid = "Grid"
        case calendar = "Calendar"

        var icon: String {
            switch self {
            case .grid: return "square.grid.2x2"
            case .calendar: return "calendar"
            }
        }
    }

    private var filteredMemories: [Memory] {
        // Filter to only accessible memories first (avoids Core Data fault crashes)
        var result = Array(memories).filter { $0.isAccessible }

        // Filter by loved one
        if let lovedOne = selectedLovedOne {
            result = result.filter { $0.lovedOne == lovedOne }
        }

        // Filter by type
        if let type = selectedType {
            result = result.filter { $0.memoryType == type }
        }

        // Filter by date range
        if let start = startDate {
            result = result.filter { memory in
                guard let captureDate = memory.captureDate else { return false }
                return captureDate >= start
            }
        }
        if let end = endDate {
            result = result.filter { memory in
                guard let captureDate = memory.captureDate else { return false }
                return captureDate <= end
            }
        }

        // Filter by selected tags
        if !selectedTags.isEmpty {
            result = result.filter { memory in
                let memoryTags = Set(memory.tagsArray)
                return !memoryTags.isDisjoint(with: selectedTags)
            }
        }

        // Filter by search
        if !searchText.isEmpty {
            result = result.filter { memory in
                let title = memory.title ?? ""
                let notes = memory.notes ?? ""
                let lovedOneName = memory.lovedOne?.name ?? ""
                let tags = memory.tagsArray.compactMap { $0.name }.joined(separator: " ")

                return title.localizedCaseInsensitiveContains(searchText) ||
                       notes.localizedCaseInsensitiveContains(searchText) ||
                       lovedOneName.localizedCaseInsensitiveContains(searchText) ||
                       tags.localizedCaseInsensitiveContains(searchText)
            }
        }

        // Apply sorting
        result = sortMemories(result)

        return result
    }

    private func sortMemories(_ memories: [Memory]) -> [Memory] {
        switch sortOption {
        case .newestFirst:
            return memories.sorted { ($0.captureDate ?? .distantPast) > ($1.captureDate ?? .distantPast) }
        case .oldestFirst:
            return memories.sorted { ($0.captureDate ?? .distantPast) < ($1.captureDate ?? .distantPast) }
        case .byPerson:
            return memories.sorted {
                let name0 = $0.lovedOne?.name ?? ""
                let name1 = $1.lovedOne?.name ?? ""
                if name0 == name1 {
                    return ($0.captureDate ?? .distantPast) > ($1.captureDate ?? .distantPast)
                }
                return name0 < name1
            }
        case .byType:
            return memories.sorted {
                if $0.memoryType == $1.memoryType {
                    return ($0.captureDate ?? .distantPast) > ($1.captureDate ?? .distantPast)
                }
                return $0.memoryType.rawValue < $1.memoryType.rawValue
            }
        }
    }

    private var groupedMemories: [(String, [Memory])] {
        let grouped: [(String, [Memory])]

        switch groupingOption {
        case .byMonth:
            grouped = groupByMonth(filteredMemories)
        case .bySeason:
            grouped = groupBySeason(filteredMemories)
        case .byYear:
            grouped = groupByYear(filteredMemories)
        case .byLocation:
            grouped = groupByLocation(filteredMemories)
        }

        // Sort groups based on sort option
        if sortOption == .oldestFirst {
            return grouped.reversed()
        }
        return grouped
    }

    private func groupByMonth(_ memories: [Memory]) -> [(String, [Memory])] {
        let grouped = Dictionary(grouping: memories) { memory -> String in
            guard let date = memory.captureDate else { return "Unknown" }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM yyyy"
            return formatter.string(from: date)
        }

        return grouped.sorted { first, second in
            guard let firstDate = first.value.first?.captureDate,
                  let secondDate = second.value.first?.captureDate else {
                return false
            }
            return firstDate > secondDate
        }
    }

    private func groupBySeason(_ memories: [Memory]) -> [(String, [Memory])] {
        let grouped = Dictionary(grouping: memories) { memory -> String in
            guard let date = memory.captureDate else { return "Unknown" }
            let season = Season.season(for: date)
            let year = Calendar.current.component(.year, from: date)
            return "\(season.displayName) \(year)"
        }

        return grouped.sorted { first, second in
            guard let firstDate = first.value.first?.captureDate,
                  let secondDate = second.value.first?.captureDate else {
                return false
            }
            return firstDate > secondDate
        }
    }

    private func groupByYear(_ memories: [Memory]) -> [(String, [Memory])] {
        let grouped = Dictionary(grouping: memories) { memory -> String in
            guard let date = memory.captureDate else { return "Unknown" }
            let year = Calendar.current.component(.year, from: date)
            return String(year)
        }

        return grouped.sorted { first, second in
            return (Int(first.0) ?? 0) > (Int(second.0) ?? 0)
        }
    }

    private func groupByLocation(_ memories: [Memory]) -> [(String, [Memory])] {
        let grouped = Dictionary(grouping: memories) { memory -> String in
            memory.locationName ?? "Unknown Location"
        }

        return grouped.sorted { first, second in
            if first.0 == "Unknown Location" { return false }
            if second.0 == "Unknown Location" { return true }
            return first.0 < second.0
        }
    }

    private var activeFilterCount: Int {
        var count = 0
        if selectedLovedOne != nil { count += 1 }
        if selectedType != nil { count += 1 }
        if startDate != nil || endDate != nil { count += 1 }
        if !selectedTags.isEmpty { count += 1 }
        return count
    }

    var body: some View {
        NavigationStack {
            Group {
                if memories.isEmpty {
                    emptyState
                } else {
                    mainContent
                }
            }
            .background(themeManager.theme.backgroundColor)
            .navigationTitle("Timeline")
            .searchable(text: $searchText, isPresented: $isSearchActive, prompt: "Search memories")
            .onSubmit(of: .search) {
                if !searchText.isEmpty {
                    SearchHistoryManager.shared.addSearch(searchText)
                }
            }
            .overlay {
                if isSearchActive && searchText.isEmpty {
                    SearchSuggestionsView(
                        lovedOnes: Array(lovedOnes),
                        tags: Array(allTags),
                        onSearchSelect: { term in
                            searchText = term
                            SearchHistoryManager.shared.addSearch(term)
                        },
                        onClearHistory: {}
                    )
                }
            }
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
                        // Sort & Group Menu
                        sortGroupMenu

                        // View Mode Toggle
                        Menu {
                            ForEach(ViewMode.allCases, id: \.self) { mode in
                                Button(action: { viewMode = mode }) {
                                    Label(mode.rawValue, systemImage: mode.icon)
                                }
                            }
                        } label: {
                            Image(systemName: viewMode.icon)
                        }

                        // Filter Button
                        Button(action: { showingFilters = true }) {
                            ZStack(alignment: .topTrailing) {
                                Image(systemName: "line.3.horizontal.decrease.circle")

                                if activeFilterCount > 0 {
                                    Circle()
                                        .fill(themeManager.theme.primaryColor)
                                        .frame(width: 12, height: 12)
                                        .offset(x: 4, y: -4)
                                }
                            }
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFilters) {
                FilterSheet(
                    lovedOnes: Array(lovedOnes),
                    allTags: Array(allTags),
                    selectedLovedOne: $selectedLovedOne,
                    selectedType: $selectedType,
                    startDate: $startDate,
                    endDate: $endDate,
                    selectedTags: $selectedTags
                )
                .presentationDetents([.large])
            }
        }
    }

    // MARK: - Sort & Group Menu

    private var sortGroupMenu: some View {
        Menu {
            Section("Sort By") {
                ForEach(SortOption.allCases) { option in
                    Button(action: { sortOption = option }) {
                        HStack {
                            Label(option.displayName, systemImage: option.icon)
                            if sortOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }

            Section("Group By") {
                ForEach(GroupingOption.allCases) { option in
                    Button(action: { groupingOption = option }) {
                        HStack {
                            Label(option.displayName, systemImage: option.icon)
                            if groupingOption == option {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            }
        } label: {
            Image(systemName: "arrow.up.arrow.down")
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        Group {
            switch viewMode {
            case .grid:
                gridView
            case .calendar:
                CalendarTimelineView(memories: filteredMemories)
            }
        }
    }

    // MARK: - Grid View

    private var gridView: some View {
        ScrollView {
            // Active Filters
            if activeFilterCount > 0 {
                activeFiltersChips
            }

            LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                ForEach(groupedMemories, id: \.0) { groupName, groupMemories in
                    Section {
                        memoryGrid(for: groupMemories)
                    } header: {
                        groupHeader(groupName, count: groupMemories.count)
                    }
                }
            }
        }
    }

    private func groupHeader(_ title: String, count: Int) -> some View {
        HStack {
            Text(title)
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            Spacer()

            Text("\(count)")
                .font(themeManager.theme.captionFont)
                .foregroundStyle(themeManager.theme.textSecondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(themeManager.theme.surfaceColor)
                .clipShape(Capsule())
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(themeManager.theme.backgroundColor)
    }

    private func memoryGrid(for memories: [Memory]) -> some View {
        let columns = [
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2),
            GridItem(.flexible(), spacing: 2)
        ]

        return LazyVGrid(columns: columns, spacing: 2) {
            ForEach(memories) { memory in
                SafeMemoryNavigationLink(memory: memory) {
                    MemoryThumbnail(memory: memory, theme: themeManager.theme)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Active Filters

    private var activeFiltersChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let lovedOne = selectedLovedOne {
                    FilterChip(
                        label: lovedOne.name ?? "Person",
                        onRemove: { selectedLovedOne = nil },
                        theme: themeManager.theme
                    )
                }

                if let type = selectedType {
                    FilterChip(
                        label: type.displayName,
                        onRemove: { selectedType = nil },
                        theme: themeManager.theme
                    )
                }

                if startDate != nil || endDate != nil {
                    FilterChip(
                        label: dateRangeLabel,
                        onRemove: {
                            startDate = nil
                            endDate = nil
                        },
                        theme: themeManager.theme
                    )
                }

                ForEach(Array(selectedTags)) { tag in
                    FilterChip(
                        label: tag.name ?? "Tag",
                        onRemove: { selectedTags.remove(tag) },
                        theme: themeManager.theme
                    )
                }

                Button("Clear All") {
                    clearAllFilters()
                }
                .font(themeManager.theme.captionFont)
                .foregroundStyle(themeManager.theme.primaryColor)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
    }

    private var dateRangeLabel: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short

        if let start = startDate, let end = endDate {
            return "\(formatter.string(from: start)) - \(formatter.string(from: end))"
        } else if let start = startDate {
            return "From \(formatter.string(from: start))"
        } else if let end = endDate {
            return "Until \(formatter.string(from: end))"
        }
        return "Date Range"
    }

    private func clearAllFilters() {
        selectedLovedOne = nil
        selectedType = nil
        startDate = nil
        endDate = nil
        selectedTags.removeAll()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: themeManager.theme.spacingMedium) {
            Spacer()

            Image(systemName: "clock.fill")
                .font(.system(size: 80))
                .foregroundStyle(themeManager.theme.primaryColor.opacity(0.3))

            Text("No Memories Yet")
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            Text("Your captured memories will appear here in chronological order.")
                .font(themeManager.theme.bodyFont)
                .foregroundStyle(themeManager.theme.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)

            Spacer()
        }
    }
}

// MARK: - Filter Chip

struct FilterChip: View {
    let label: String
    let onRemove: () -> Void
    let theme: Theme

    var body: some View {
        HStack(spacing: 4) {
            Text(label)
                .font(theme.captionFont)

            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption)
            }
        }
        .foregroundStyle(theme.primaryColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(theme.primaryColor.opacity(0.1))
        .clipShape(Capsule())
    }
}

// MARK: - Filter Sheet

struct FilterSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    let lovedOnes: [LovedOne]
    let allTags: [Tag]
    @Binding var selectedLovedOne: LovedOne?
    @Binding var selectedType: MemoryType?
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    @Binding var selectedTags: Set<Tag>

    @State private var showStartDatePicker = false
    @State private var showEndDatePicker = false
    @State private var tempStartDate = Date()
    @State private var tempEndDate = Date()

    var body: some View {
        NavigationStack {
            Form {
                Section("Person") {
                    Picker("Person", selection: $selectedLovedOne) {
                        Text("Everyone").tag(nil as LovedOne?)
                        ForEach(lovedOnes) { lovedOne in
                            Text(lovedOne.name ?? "Unknown").tag(lovedOne as LovedOne?)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Type") {
                    Picker("Type", selection: $selectedType) {
                        Text("All Types").tag(nil as MemoryType?)
                        ForEach(MemoryType.allCases) { type in
                            Label(type.displayName, systemImage: type.icon).tag(type as MemoryType?)
                        }
                    }
                    .pickerStyle(.inline)
                    .labelsHidden()
                }

                Section("Date Range") {
                    HStack {
                        Text("From")
                        Spacer()
                        if let start = startDate {
                            Text(start, style: .date)
                                .foregroundStyle(themeManager.theme.primaryColor)
                            Button {
                                startDate = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(themeManager.theme.textSecondary)
                            }
                        } else {
                            Button("Select") {
                                tempStartDate = Date()
                                showStartDatePicker = true
                            }
                            .foregroundStyle(themeManager.theme.primaryColor)
                        }
                    }

                    HStack {
                        Text("To")
                        Spacer()
                        if let end = endDate {
                            Text(end, style: .date)
                                .foregroundStyle(themeManager.theme.primaryColor)
                            Button {
                                endDate = nil
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundStyle(themeManager.theme.textSecondary)
                            }
                        } else {
                            Button("Select") {
                                tempEndDate = Date()
                                showEndDatePicker = true
                            }
                            .foregroundStyle(themeManager.theme.primaryColor)
                        }
                    }
                }

                if !allTags.isEmpty {
                    Section("Tags") {
                        ForEach(allTags) { tag in
                            Button {
                                if selectedTags.contains(tag) {
                                    selectedTags.remove(tag)
                                } else {
                                    selectedTags.insert(tag)
                                }
                            } label: {
                                HStack {
                                    Text(tag.name ?? "Unknown")
                                        .foregroundStyle(themeManager.theme.textPrimary)
                                    Spacer()
                                    if selectedTags.contains(tag) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(themeManager.theme.primaryColor)
                                    }
                                }
                            }
                        }
                    }
                }

                Section {
                    Button("Clear All Filters") {
                        selectedLovedOne = nil
                        selectedType = nil
                        startDate = nil
                        endDate = nil
                        selectedTags.removeAll()
                    }
                    .foregroundStyle(themeManager.theme.destructive)
                }
            }
            .navigationTitle("Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showStartDatePicker) {
                DatePickerSheet(
                    title: "Start Date",
                    date: $tempStartDate,
                    onSave: { startDate = tempStartDate }
                )
                .presentationDetents([.medium])
            }
            .sheet(isPresented: $showEndDatePicker) {
                DatePickerSheet(
                    title: "End Date",
                    date: $tempEndDate,
                    onSave: { endDate = tempEndDate }
                )
                .presentationDetents([.medium])
            }
        }
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var date: Date
    let onSave: () -> Void

    var body: some View {
        NavigationStack {
            VStack {
                DatePicker(title, selection: $date, displayedComponents: .date)
                    .datePickerStyle(.graphical)
                    .padding()

                Spacer()
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave()
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    MemoriesTimelineView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
