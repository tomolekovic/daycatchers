import SwiftUI
import CoreData

struct MemoryDetailView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var memory: Memory

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: themeManager.theme.spacingLarge) {
                // Media
                mediaView

                // Info Section
                VStack(alignment: .leading, spacing: themeManager.theme.spacingMedium) {
                    // Title
                    if let title = memory.title, !title.isEmpty {
                        Text(title)
                            .font(themeManager.theme.titleFont)
                            .foregroundStyle(themeManager.theme.textPrimary)
                    }

                    // Metadata
                    metadataSection

                    // Notes
                    if let notes = memory.notes, !notes.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Notes")
                                .font(themeManager.theme.headlineFont)
                                .foregroundStyle(themeManager.theme.textPrimary)

                            Text(notes)
                                .font(themeManager.theme.bodyFont)
                                .foregroundStyle(themeManager.theme.textSecondary)
                        }
                    }

                    // Tags
                    if !memory.tagsArray.isEmpty {
                        tagsSection
                    }

                    // Extracted Text
                    if let extractedText = memory.extractedText, !extractedText.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Extracted Text")
                                .font(themeManager.theme.headlineFont)
                                .foregroundStyle(themeManager.theme.textPrimary)

                            Text(extractedText)
                                .font(themeManager.theme.bodyFont)
                                .foregroundStyle(themeManager.theme.textSecondary)
                                .padding()
                                .background(themeManager.theme.surfaceColor)
                                .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusSmall))
                        }
                    }

                    // Transcription
                    if let transcription = memory.transcription, !transcription.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Transcription")
                                .font(themeManager.theme.headlineFont)
                                .foregroundStyle(themeManager.theme.textPrimary)

                            Text(transcription)
                                .font(themeManager.theme.bodyFont)
                                .foregroundStyle(themeManager.theme.textSecondary)
                                .padding()
                                .background(themeManager.theme.surfaceColor)
                                .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusSmall))
                        }
                    }

                    // Linked Event
                    if let event = memory.linkedEvent {
                        linkedEventSection(event)
                    }
                }
                .padding(.horizontal)
            }
        }
        .background(themeManager.theme.backgroundColor)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button(action: { showingEditSheet = true }) {
                        Label("Edit", systemImage: "pencil")
                    }

                    Button(action: { showingShareSheet = true }) {
                        Label("Share", systemImage: "square.and.arrow.up")
                    }

                    if memory.memoryType == .photo {
                        Button(action: extractText) {
                            Label("Extract Text", systemImage: "doc.text.viewfinder")
                        }
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
            EditMemoryView(memory: memory)
        }
        .alert("Delete Memory?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                deleteMemory()
            }
        } message: {
            Text("This memory will be permanently deleted.")
        }
    }

    // MARK: - Media View

    @ViewBuilder
    private var mediaView: some View {
        switch memory.memoryType {
        case .photo:
            photoView
        case .video:
            videoView
        case .audio:
            audioView
        case .text:
            textView
        }
    }

    private var photoView: some View {
        ZStack {
            Rectangle()
                .fill(themeManager.theme.surfaceColor)

            // Placeholder - would load actual image
            Image(systemName: "photo.fill")
                .font(.system(size: 60))
                .foregroundStyle(themeManager.theme.textSecondary.opacity(0.3))
        }
        .aspectRatio(4/3, contentMode: .fit)
    }

    private var videoView: some View {
        ZStack {
            Rectangle()
                .fill(themeManager.theme.surfaceColor)

            VStack(spacing: 12) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(themeManager.theme.primaryColor)

                Text("Tap to play")
                    .font(themeManager.theme.captionFont)
                    .foregroundStyle(themeManager.theme.textSecondary)
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
    }

    private var audioView: some View {
        VStack(spacing: themeManager.theme.spacingMedium) {
            Image(systemName: "waveform")
                .font(.system(size: 40))
                .foregroundStyle(themeManager.theme.primaryColor)

            HStack(spacing: themeManager.theme.spacingMedium) {
                Button(action: {}) {
                    Image(systemName: "play.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(themeManager.theme.primaryColor)
                        .clipShape(Circle())
                }

                // Progress placeholder
                Capsule()
                    .fill(themeManager.theme.surfaceColor)
                    .frame(height: 6)

                Text("0:00")
                    .font(themeManager.theme.captionFont)
                    .foregroundStyle(themeManager.theme.textSecondary)
            }
        }
        .padding()
        .background(themeManager.theme.surfaceColor)
    }

    private var textView: some View {
        VStack {
            Image(systemName: "note.text")
                .font(.system(size: 40))
                .foregroundStyle(themeManager.theme.secondaryColor)
        }
        .frame(height: 120)
        .frame(maxWidth: .infinity)
        .background(themeManager.theme.surfaceColor)
    }

    // MARK: - Metadata Section

    private var metadataSection: some View {
        VStack(spacing: 12) {
            // Person
            if let lovedOne = memory.lovedOne {
                HStack {
                    Image(systemName: lovedOne.relationshipType.icon)
                        .foregroundStyle(themeManager.theme.primaryColor)
                    Text(lovedOne.name ?? "Unknown")
                    Spacer()
                }
                .font(themeManager.theme.bodyFont)
                .foregroundStyle(themeManager.theme.textPrimary)
            }

            // Date
            HStack {
                Image(systemName: "calendar")
                    .foregroundStyle(themeManager.theme.primaryColor)
                Text(memory.formattedDate)
                Spacer()
            }
            .font(themeManager.theme.bodyFont)
            .foregroundStyle(themeManager.theme.textSecondary)

            // Location
            if let locationName = memory.locationName, !locationName.isEmpty {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundStyle(themeManager.theme.primaryColor)
                    Text(locationName)
                    Spacer()
                }
                .font(themeManager.theme.bodyFont)
                .foregroundStyle(themeManager.theme.textSecondary)
            }

            // Type badge
            HStack {
                Image(systemName: memory.memoryType.icon)
                Text(memory.memoryType.displayName)
            }
            .font(themeManager.theme.captionFont)
            .foregroundStyle(memory.memoryType.color)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(memory.memoryType.color.opacity(0.1))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
        .background(themeManager.theme.surfaceColor)
        .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))
    }

    // MARK: - Tags Section

    private var tagsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Tags")
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            FlowLayout(spacing: 8) {
                ForEach(memory.tagsArray) { tag in
                    HStack(spacing: 4) {
                        if tag.isAIGenerated {
                            Image(systemName: "sparkles")
                                .font(.caption2)
                        }
                        Text(tag.name ?? "")
                    }
                    .font(themeManager.theme.captionFont)
                    .foregroundStyle(themeManager.theme.secondaryColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(themeManager.theme.secondaryColor.opacity(0.1))
                    .clipShape(Capsule())
                }
            }
        }
    }

    // MARK: - Linked Event Section

    private func linkedEventSection(_ event: Event) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Linked Event")
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            HStack {
                Image(systemName: event.eventTypeValue.icon)
                    .foregroundStyle(themeManager.theme.primaryColor)

                VStack(alignment: .leading) {
                    Text(event.title ?? "Event")
                        .font(themeManager.theme.bodyFont)
                        .foregroundStyle(themeManager.theme.textPrimary)

                    Text(event.shortFormattedDate)
                        .font(themeManager.theme.captionFont)
                        .foregroundStyle(themeManager.theme.textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .foregroundStyle(themeManager.theme.textSecondary)
            }
            .padding()
            .background(themeManager.theme.surfaceColor)
            .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusSmall))
        }
    }

    // MARK: - Actions

    private func extractText() {
        // TODO: Implement OCR
    }

    private func deleteMemory() {
        // Delete associated media files
        if let mediaPath = memory.mediaPath {
            MediaManager.shared.deleteMedia(filename: mediaPath, type: memory.memoryType)
        }
        if let thumbnailPath = memory.thumbnailPath {
            MediaManager.shared.deleteThumbnail(filename: thumbnailPath)
        }

        viewContext.delete(memory)

        do {
            try viewContext.save()
            dismiss()
        } catch {
            print("Error deleting memory: \(error)")
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.positions[index].x,
                                      y: bounds.minY + result.positions[index].y),
                         proposal: .unspecified)
        }
    }

    struct FlowResult {
        var size: CGSize = .zero
        var positions: [CGPoint] = []

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var currentX: CGFloat = 0
            var currentY: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if currentX + size.width > maxWidth, currentX > 0 {
                    currentX = 0
                    currentY += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: currentX, y: currentY))
                lineHeight = max(lineHeight, size.height)
                currentX += size.width + spacing
                self.size.width = max(self.size.width, currentX)
            }

            self.size.height = currentY + lineHeight
        }
    }
}

#Preview {
    NavigationStack {
        MemoryDetailView(memory: {
            let context = PersistenceController.preview.container.viewContext
            let memory = Memory(context: context)
            memory.id = UUID()
            memory.title = "First Steps"
            memory.notes = "Emma took her first steps today! She was so excited and proud of herself."
            memory.type = MemoryType.photo.rawValue
            memory.captureDate = Date()
            return memory
        }())
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(ThemeManager())
}
