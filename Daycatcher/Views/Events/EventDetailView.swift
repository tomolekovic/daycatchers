import SwiftUI
import CoreData

struct EventDetailView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var event: Event

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingLinkMemoriesSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: themeManager.theme.spacingLarge) {
                // Header
                headerSection

                // Details
                detailsSection

                // Notes
                if let notes = event.notes, !notes.isEmpty {
                    notesSection(notes)
                }

                // Linked Memories
                linkedMemoriesSection
            }
            .padding()
        }
        .background(themeManager.theme.backgroundColor)
        .navigationTitle(event.title ?? "Event")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showingEditSheet = true }) {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(action: { showingLinkMemoriesSheet = true }) {
                        Label("Link Memories", systemImage: "photo.on.rectangle")
                    }

                    Divider()

                    Button(role: .destructive, action: { showingDeleteAlert = true }) {
                        Label("Delete", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
            }
        }
        .sheet(isPresented: $showingEditSheet) {
            EditEventView(event: event)
        }
        .sheet(isPresented: $showingLinkMemoriesSheet) {
            LinkMemoriesSheet(event: event)
        }
        .alert("Delete Event?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteEvent()
            }
        } message: {
            Text("This event will be permanently deleted.")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: themeManager.theme.spacingMedium) {
            // Icon
            Image(systemName: event.eventTypeValue.icon)
                .font(.system(size: 50))
                .foregroundStyle(themeManager.theme.primaryColor)
                .frame(width: 100, height: 100)
                .background(themeManager.theme.primaryColor.opacity(0.1))
                .clipShape(Circle())

            // Title
            Text(event.title ?? "Event")
                .font(themeManager.theme.titleFont)
                .foregroundStyle(themeManager.theme.textPrimary)
                .multilineTextAlignment(.center)

            // Type badge
            Text(event.eventTypeValue.displayName)
                .font(themeManager.theme.captionFont)
                .foregroundStyle(themeManager.theme.secondaryColor)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(themeManager.theme.secondaryColor.opacity(0.1))
                .clipShape(Capsule())

            // Days countdown
            if let daysUntil = event.daysUntil {
                if daysUntil == 0 {
                    Text("Today!")
                        .font(themeManager.theme.headlineFont)
                        .foregroundStyle(themeManager.theme.primaryColor)
                } else if daysUntil > 0 {
                    HStack(spacing: 4) {
                        Text("\(daysUntil)")
                            .font(.system(size: 32, weight: .bold))
                        Text(daysUntil == 1 ? "day away" : "days away")
                            .font(themeManager.theme.bodyFont)
                    }
                    .foregroundStyle(themeManager.theme.textPrimary)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(themeManager.theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))
    }

    // MARK: - Details Section

    private var detailsSection: some View {
        VStack(spacing: 12) {
            // Date
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(themeManager.theme.primaryColor)
                    .frame(width: 24)

                Text(event.formattedDate)
                    .font(themeManager.theme.bodyFont)
                    .foregroundStyle(themeManager.theme.textPrimary)

                Spacer()

                if event.isAllDay {
                    Text("All Day")
                        .font(themeManager.theme.captionFont)
                        .foregroundStyle(themeManager.theme.textSecondary)
                }
            }

            Divider()

            // Loved One
            if let lovedOne = event.lovedOne {
                HStack {
                    Image(systemName: lovedOne.relationshipType.icon)
                        .foregroundStyle(themeManager.theme.primaryColor)
                        .frame(width: 24)

                    Text(lovedOne.name ?? "Unknown")
                        .font(themeManager.theme.bodyFont)
                        .foregroundStyle(themeManager.theme.textPrimary)

                    Spacer()
                }
            }

            // Reminder
            if let reminderOffset = event.reminderOffsetValue {
                Divider()

                HStack {
                    Image(systemName: "bell.fill")
                        .foregroundStyle(themeManager.theme.primaryColor)
                        .frame(width: 24)

                    Text("Reminder: \(reminderOffset.displayName)")
                        .font(themeManager.theme.bodyFont)
                        .foregroundStyle(themeManager.theme.textPrimary)

                    Spacer()
                }
            }
        }
        .padding()
        .background(themeManager.theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))
    }

    // MARK: - Notes Section

    private func notesSection(_ notes: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Notes")
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            Text(notes)
                .font(themeManager.theme.bodyFont)
                .foregroundStyle(themeManager.theme.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(themeManager.theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))
    }

    // MARK: - Linked Memories Section

    private var linkedMemoriesSection: some View {
        VStack(alignment: .leading, spacing: themeManager.theme.spacingMedium) {
            HStack {
                Text("Linked Memories")
                    .font(themeManager.theme.headlineFont)
                    .foregroundStyle(themeManager.theme.textPrimary)

                Spacer()

                Button(action: { showingLinkMemoriesSheet = true }) {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(themeManager.theme.primaryColor)
                }
            }

            if event.linkedMemoriesArray.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title)
                        .foregroundStyle(themeManager.theme.textSecondary.opacity(0.5))

                    Text("No memories linked yet")
                        .font(themeManager.theme.bodyFont)
                        .foregroundStyle(themeManager.theme.textSecondary)

                    Button("Link Memories") {
                        showingLinkMemoriesSheet = true
                    }
                    .font(themeManager.theme.captionFont)
                    .foregroundStyle(themeManager.theme.primaryColor)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(event.linkedMemoriesArray) { memory in
                            NavigationLink(destination: MemoryDetailView(memory: memory)) {
                                MemoryThumbnail(memory: memory, theme: themeManager.theme)
                                    .frame(width: 100, height: 100)
                                    .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusSmall))
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(themeManager.theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))
    }

    // MARK: - Actions

    private func deleteEvent() {
        viewContext.delete(event)

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error deleting event: \(error)")
        }
    }
}

// MARK: - Link Memories Sheet

struct LinkMemoriesSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var event: Event

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Memory.captureDate, ascending: false)],
        animation: .default
    )
    private var memories: FetchedResults<Memory>

    private var filteredMemories: [Memory] {
        if let lovedOne = event.lovedOne {
            return memories.filter { $0.lovedOne == lovedOne }
        }
        return Array(memories)
    }

    private var linkedMemoryIDs: Set<UUID> {
        Set(event.linkedMemoriesArray.compactMap { $0.id })
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredMemories) { memory in
                    HStack {
                        // Thumbnail
                        MemoryThumbnail(memory: memory, theme: themeManager.theme)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        // Info
                        VStack(alignment: .leading, spacing: 4) {
                            Text(memory.title ?? "Memory")
                                .font(themeManager.theme.bodyFont)
                                .foregroundStyle(themeManager.theme.textPrimary)

                            Text(memory.formattedDate)
                                .font(themeManager.theme.captionFont)
                                .foregroundStyle(themeManager.theme.textSecondary)
                        }

                        Spacer()

                        // Selection
                        if let memoryID = memory.id, linkedMemoryIDs.contains(memoryID) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(themeManager.theme.primaryColor)
                        } else {
                            Image(systemName: "circle")
                                .foregroundStyle(themeManager.theme.textSecondary)
                        }
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleMemory(memory)
                    }
                }
            }
            .navigationTitle("Link Memories")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        save()
                    }
                }
            }
        }
    }

    private func toggleMemory(_ memory: Memory) {
        if let memoryID = memory.id, linkedMemoryIDs.contains(memoryID) {
            event.removeFromLinkedMemories(memory)
        } else {
            event.addToLinkedMemories(memory)
        }
    }

    private func save() {
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error saving linked memories: \(error)")
        }
    }
}

#Preview {
    NavigationStack {
        EventDetailView(event: {
            let context = PersistenceController.preview.container.viewContext
            let event = Event(context: context)
            event.id = UUID()
            event.title = "Emma's Birthday"
            event.eventType = EventType.birthday.rawValue
            event.date = Calendar.current.date(byAdding: .day, value: 7, to: Date())
            event.isAllDay = true
            event.reminderOffset = ReminderOffset.oneDay.rawValue
            return event
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(ThemeManager())
}
