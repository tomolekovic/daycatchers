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

    @State private var searchText = ""
    @State private var selectedLovedOne: LovedOne?
    @State private var selectedType: MemoryType?
    @State private var showingFilters = false
    @State private var viewMode: ViewMode = .grid

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
        var result = Array(memories)

        // Filter by loved one
        if let lovedOne = selectedLovedOne {
            result = result.filter { $0.lovedOne == lovedOne }
        }

        // Filter by type
        if let type = selectedType {
            result = result.filter { $0.memoryType == type }
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

        return result
    }

    private var memoriesByMonth: [(String, [Memory])] {
        let grouped = Dictionary(grouping: filteredMemories) { memory -> String in
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

    private var activeFilterCount: Int {
        var count = 0
        if selectedLovedOne != nil { count += 1 }
        if selectedType != nil { count += 1 }
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
            .searchable(text: $searchText, prompt: "Search memories")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    HStack(spacing: 12) {
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
                    selectedLovedOne: $selectedLovedOne,
                    selectedType: $selectedType
                )
                .presentationDetents([.medium])
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        Group {
            switch viewMode {
            case .grid:
                gridView
            case .calendar:
                calendarView
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
                ForEach(memoriesByMonth, id: \.0) { month, monthMemories in
                    Section {
                        memoryGrid(for: monthMemories)
                    } header: {
                        monthHeader(month)
                    }
                }
            }
        }
    }

    private func monthHeader(_ month: String) -> some View {
        Text(month)
            .font(themeManager.theme.headlineFont)
            .foregroundStyle(themeManager.theme.textPrimary)
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
                NavigationLink(destination: MemoryDetailView(memory: memory)) {
                    MemoryThumbnail(memory: memory, theme: themeManager.theme)
                }
            }
        }
        .padding(.horizontal, 2)
    }

    // MARK: - Calendar View

    private var calendarView: some View {
        VStack {
            Text("Calendar view coming soon")
                .font(themeManager.theme.bodyFont)
                .foregroundStyle(themeManager.theme.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
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

                Button("Clear All") {
                    selectedLovedOne = nil
                    selectedType = nil
                }
                .font(themeManager.theme.captionFont)
                .foregroundStyle(themeManager.theme.primaryColor)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
        }
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
    @Binding var selectedLovedOne: LovedOne?
    @Binding var selectedType: MemoryType?

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

                Section {
                    Button("Clear Filters") {
                        selectedLovedOne = nil
                        selectedType = nil
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
        }
    }
}

#Preview {
    MemoriesTimelineView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
