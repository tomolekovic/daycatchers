import SwiftUI
import CoreData

struct LovedOneDetailView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var lovedOne: LovedOne

    @State private var selectedSegment: DetailSegment = .memories
    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var captureType: MemoryType?

    enum DetailSegment: String, CaseIterable {
        case memories = "Memories"
        case events = "Events"
    }

    var body: some View {
        ScrollView {
            VStack(spacing: themeManager.theme.spacingLarge) {
                // Profile Header
                profileHeader

                // Quick Capture
                quickCaptureSection

                // Segmented Control
                Picker("View", selection: $selectedSegment) {
                    ForEach(DetailSegment.allCases, id: \.self) { segment in
                        Text(segment.rawValue).tag(segment)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                // Content
                switch selectedSegment {
                case .memories:
                    memoriesSection
                case .events:
                    eventsSection
                }
            }
            .padding(.bottom)
        }
        .background(themeManager.theme.backgroundColor)
        .navigationTitle(lovedOne.name ?? "Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showingEditSheet = true }) {
                        Label("Edit", systemImage: "pencil")
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
            EditLovedOneView(lovedOne: lovedOne)
        }
        .alert("Delete \(lovedOne.name ?? "this person")?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteLovedOne()
            }
        } message: {
            Text("This will permanently delete all memories and events associated with \(lovedOne.name ?? "this person").")
        }
        .sheet(item: $captureType) { type in
            CaptureFlowContainer(memoryType: type, lovedOne: lovedOne)
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: themeManager.theme.spacingMedium) {
            // Profile Image
            profileImage

            // Name and Relationship
            VStack(spacing: 4) {
                Text(lovedOne.name ?? "Unknown")
                    .font(themeManager.theme.titleFont)
                    .foregroundStyle(themeManager.theme.textPrimary)

                HStack(spacing: 6) {
                    Image(systemName: lovedOne.relationshipType.icon)
                    Text(lovedOne.relationshipType.displayName)
                }
                .font(themeManager.theme.bodyFont)
                .foregroundStyle(themeManager.theme.textSecondary)

                if let age = lovedOne.formattedAge {
                    Text(age)
                        .font(themeManager.theme.bodyFont)
                        .foregroundStyle(themeManager.theme.textSecondary)
                }
            }

            // Stats Row
            HStack(spacing: themeManager.theme.spacingLarge) {
                StatView(title: "Memories", count: lovedOne.memoryCount, theme: themeManager.theme)
                StatView(title: "Events", count: lovedOne.eventCount, theme: themeManager.theme)
            }
        }
        .padding()
    }

    @ViewBuilder
    private var profileImage: some View {
        if let imageURL = lovedOne.profileImageURL,
           let imageData = try? Data(contentsOf: imageURL),
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .shadow(color: themeManager.theme.shadowColor, radius: themeManager.theme.shadowRadius)
        } else {
            Circle()
                .fill(themeManager.theme.primaryColor.opacity(0.2))
                .frame(width: 120, height: 120)
                .overlay {
                    Text(initials)
                        .font(.system(size: 44, weight: .semibold))
                        .foregroundStyle(themeManager.theme.primaryColor)
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

    // MARK: - Quick Capture Section

    private var quickCaptureSection: some View {
        HStack(spacing: themeManager.theme.spacingMedium) {
            QuickCaptureButton(type: .photo, theme: themeManager.theme) {
                captureType = .photo
            }
            QuickCaptureButton(type: .video, theme: themeManager.theme) {
                captureType = .video
            }
            QuickCaptureButton(type: .audio, theme: themeManager.theme) {
                captureType = .audio
            }
            QuickCaptureButton(type: .text, theme: themeManager.theme) {
                captureType = .text
            }
        }
        .padding()
        .background(themeManager.theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))
        .padding(.horizontal)
    }

    // MARK: - Memories Section

    private var memoriesSection: some View {
        Group {
            if lovedOne.memoryCount == 0 {
                emptyMemoriesState
            } else {
                memoriesGrid
            }
        }
    }

    private var emptyMemoriesState: some View {
        VStack(spacing: themeManager.theme.spacingMedium) {
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 50))
                .foregroundStyle(themeManager.theme.textSecondary.opacity(0.5))

            Text("No memories yet")
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            Text("Capture your first memory using the buttons above.")
                .font(themeManager.theme.bodyFont)
                .foregroundStyle(themeManager.theme.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.vertical, 40)
    }

    private var memoriesGrid: some View {
        let memories = (lovedOne.memories?.allObjects as? [Memory] ?? [])
            .sorted { ($0.captureDate ?? Date.distantPast) > ($1.captureDate ?? Date.distantPast) }

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
        .padding(.horizontal)
    }

    // MARK: - Events Section

    private var eventsSection: some View {
        Group {
            if lovedOne.eventCount == 0 {
                emptyEventsState
            } else {
                eventsList
            }
        }
    }

    private var emptyEventsState: some View {
        VStack(spacing: themeManager.theme.spacingMedium) {
            Image(systemName: "calendar")
                .font(.system(size: 50))
                .foregroundStyle(themeManager.theme.textSecondary.opacity(0.5))

            Text("No events yet")
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            Text("Add birthdays, milestones, and special dates.")
                .font(themeManager.theme.bodyFont)
                .foregroundStyle(themeManager.theme.textSecondary)
                .multilineTextAlignment(.center)

            Button(action: {
                // TODO: Add event
            }) {
                Label("Add Event", systemImage: "plus")
                    .font(themeManager.theme.bodyFont)
                    .foregroundStyle(themeManager.theme.primaryColor)
            }
        }
        .padding(.vertical, 40)
    }

    private var eventsList: some View {
        let events = (lovedOne.events?.allObjects as? [Event] ?? [])
            .sorted { ($0.date ?? Date.distantPast) < ($1.date ?? Date.distantPast) }

        return LazyVStack(spacing: themeManager.theme.spacingMedium) {
            ForEach(events) { event in
                EventRowView(event: event)
            }
        }
        .padding(.horizontal)
    }

    // MARK: - Actions

    private func deleteLovedOne() {
        viewContext.delete(lovedOne)
        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error deleting loved one: \(error)")
        }
    }
}

// MARK: - Stat View

struct StatView: View {
    let title: String
    let count: Int
    let theme: Theme

    var body: some View {
        VStack(spacing: 4) {
            Text("\(count)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundStyle(theme.textPrimary)

            Text(title)
                .font(theme.captionFont)
                .foregroundStyle(theme.textSecondary)
        }
    }
}

// MARK: - Memory Thumbnail

struct MemoryThumbnail: View {
    let memory: Memory
    let theme: Theme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(theme.surfaceColor)

                // Try to load the thumbnail image
                if let thumbnailPath = memory.thumbnailPath,
                   let image = MediaManager.shared.loadThumbnail(filename: thumbnailPath) {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.width)
                } else if memory.memoryType == .photo,
                          let mediaPath = memory.mediaPath,
                          let image = MediaManager.shared.loadImage(filename: mediaPath, type: .photo) {
                    // Fallback: load full image if thumbnail missing
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geometry.size.width, height: geometry.size.width)
                } else {
                    // Placeholder icon for non-image types or missing media
                    Image(systemName: memory.memoryType.icon)
                        .font(.title2)
                        .foregroundStyle(memory.memoryType.color.opacity(0.5))
                }

                // Type indicator
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Image(systemName: memory.memoryType.icon)
                            .font(.caption2)
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(memory.memoryType.color.opacity(0.8))
                            .clipShape(Circle())
                            .padding(4)
                    }
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.width)
            .clipped()
        }
        .aspectRatio(1, contentMode: .fit)
    }
}

#Preview {
    NavigationStack {
        LovedOneDetailView(lovedOne: {
            let context = PersistenceController.preview.container.viewContext
            let lovedOne = LovedOne(context: context)
            lovedOne.id = UUID()
            lovedOne.name = "Emma"
            lovedOne.birthDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
            lovedOne.relationship = RelationshipType.child.rawValue
            return lovedOne
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(ThemeManager())
}
