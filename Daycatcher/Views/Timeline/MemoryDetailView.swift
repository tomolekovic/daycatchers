import SwiftUI
import CoreData
import AVKit
import CoreMedia

struct MemoryDetailView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @ObservedObject var memory: Memory

    @State private var showingEditSheet = false
    @State private var showingDeleteAlert = false
    @State private var showingShareSheet = false
    @State private var showingAddTagSheet = false
    @State private var newTagName = ""
    @State private var isRetagging = false

    var body: some View {
        Group {
            if memory.isAccessible {
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

                            // Tags (always show to allow adding)
                            tagsSection

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
            } else {
                ContentUnavailableView(
                    "Memory Unavailable",
                    systemImage: "exclamationmark.icloud",
                    description: Text("This memory is not available on this device.")
                )
            }
        }
        .background(themeManager.theme.backgroundColor)
        .navigationTitle(memory.isAccessible ? (memory.title ?? "Memory") : "Memory")
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
        .onReceive(NotificationCenter.default.publisher(for: .coreDataRemoteChangeProcessed)) { _ in
            // If the memory becomes inaccessible (e.g., deleted by CloudKit sync),
            // dismiss this view to avoid crashes when accessing its properties.
            if !memory.isAccessible {
                dismiss()
            }
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

    @State private var loadedPhoto: UIImage?
    @State private var isLoadingPhoto = false

    private var photoView: some View {
        Group {
            if let image = loadedPhoto {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if isLoadingPhoto {
                ZStack {
                    Rectangle()
                        .fill(themeManager.theme.surfaceColor)

                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading...")
                            .font(themeManager.theme.captionFont)
                            .foregroundStyle(themeManager.theme.textSecondary)
                    }
                }
                .aspectRatio(4/3, contentMode: .fit)
            } else {
                ZStack {
                    Rectangle()
                        .fill(themeManager.theme.surfaceColor)

                    Image(systemName: "photo.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(themeManager.theme.textSecondary.opacity(0.3))
                }
                .aspectRatio(4/3, contentMode: .fit)
            }
        }
        .task {
            await loadPhoto()
        }
    }

    private func loadPhoto() async {
        // First try synchronous loading (local media)
        if let mediaPath = memory.mediaPath,
           let image = MediaManager.shared.loadImage(filename: mediaPath, type: .photo) {
            loadedPhoto = image
            return
        }

        // Try async loading (for shared media)
        isLoadingPhoto = true
        defer { isLoadingPhoto = false }

        if let image = await MediaManager.shared.loadImage(for: memory) {
            loadedPhoto = image
        }
    }

    @State private var showVideoPlayer = false
    @State private var loadedVideoThumbnail: UIImage?
    @State private var loadedVideoURL: URL?
    @State private var isLoadingVideo = false

    private var videoView: some View {
        ZStack {
            // Show thumbnail or placeholder
            if let image = loadedVideoThumbnail {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
            } else if isLoadingVideo {
                ZStack {
                    Rectangle()
                        .fill(themeManager.theme.surfaceColor)
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Loading video...")
                            .font(themeManager.theme.captionFont)
                            .foregroundStyle(themeManager.theme.textSecondary)
                    }
                }
            } else {
                Rectangle()
                    .fill(themeManager.theme.surfaceColor)
            }

            // Play button overlay (only show if not loading)
            if !isLoadingVideo {
                VStack(spacing: 12) {
                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 60))
                        .foregroundStyle(.white.opacity(0.9))
                        .shadow(radius: 4)

                    Text("Tap to play")
                        .font(themeManager.theme.captionFont)
                        .foregroundStyle(.white)
                        .shadow(radius: 2)
                }
            }
        }
        .aspectRatio(16/9, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))
        .onTapGesture {
            Task {
                await playVideo()
            }
        }
        .fullScreenCover(isPresented: $showVideoPlayer) {
            if let videoURL = loadedVideoURL {
                VideoPlayerView(videoURL: videoURL)
            }
        }
        .task {
            await loadVideoThumbnail()
        }
    }

    private func loadVideoThumbnail() async {
        // Priority 1: Check Core Data thumbnailData (works for shared memories via CloudKit sync)
        if let thumbnailData = memory.thumbnailData, let image = UIImage(data: thumbnailData) {
            loadedVideoThumbnail = image
            return
        }

        // Priority 2: Try synchronous loading from local file
        if let thumbnailPath = memory.thumbnailPath,
           let image = MediaManager.shared.loadThumbnail(filename: thumbnailPath) {
            loadedVideoThumbnail = image
            return
        }

        // Priority 3: Try async loading (for shared media, CloudKit fallback)
        if let image = await MediaManager.shared.loadThumbnail(for: memory) {
            loadedVideoThumbnail = image
        }
    }

    private func playVideo() async {
        // Check if we already have the video URL
        if let mediaPath = memory.mediaPath {
            let localURL = MediaManager.shared.mediaURL(filename: mediaPath, type: .video)
            if FileManager.default.fileExists(atPath: localURL.path) {
                loadedVideoURL = localURL
                showVideoPlayer = true
                return
            }
        }

        // Need to fetch from CloudKit
        isLoadingVideo = true
        defer { isLoadingVideo = false }

        if let videoURL = await MediaManager.shared.loadVideoURL(for: memory) {
            loadedVideoURL = videoURL
            showVideoPlayer = true
        }
    }

    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlayingAudio = false
    @State private var audioProgress: Double = 0
    @State private var audioDuration: TimeInterval = 0
    @State private var audioTimer: Timer?

    private var audioView: some View {
        VStack(spacing: themeManager.theme.spacingMedium) {
            Image(systemName: "waveform")
                .font(.system(size: 40))
                .foregroundStyle(themeManager.theme.primaryColor)

            // Duration display
            Text(formatTime(audioDuration))
                .font(.system(size: 32, weight: .light, design: .monospaced))
                .foregroundStyle(themeManager.theme.textPrimary)

            HStack(spacing: themeManager.theme.spacingMedium) {
                Button(action: toggleAudioPlayback) {
                    Image(systemName: isPlayingAudio ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundStyle(.white)
                        .frame(width: 50, height: 50)
                        .background(themeManager.theme.primaryColor)
                        .clipShape(Circle())
                }

                // Progress bar
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(themeManager.theme.surfaceColor.opacity(0.5))
                            .frame(height: 6)

                        Capsule()
                            .fill(themeManager.theme.primaryColor)
                            .frame(width: geometry.size.width * audioProgress, height: 6)
                    }
                }
                .frame(height: 6)

                // Current time / Total time
                Text("\(formatTime(audioDuration * audioProgress)) / \(formatTime(audioDuration))")
                    .font(themeManager.theme.captionFont)
                    .foregroundStyle(themeManager.theme.textSecondary)
                    .frame(width: 80)
            }
        }
        .padding()
        .background(themeManager.theme.surfaceColor)
        .onAppear(perform: loadAudioDuration)
        .onDisappear(perform: stopAudioPlayback)
    }

    private func toggleAudioPlayback() {
        if isPlayingAudio {
            stopAudioPlayback()
        } else {
            startAudioPlayback()
        }
    }

    private func startAudioPlayback() {
        guard let mediaPath = memory.mediaPath else { return }
        let url = MediaManager.shared.mediaURL(filename: mediaPath, type: .audio)

        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            isPlayingAudio = true

            audioDuration = audioPlayer?.duration ?? 0

            // Start timer for progress updates
            audioTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                if let player = audioPlayer {
                    if player.isPlaying {
                        audioProgress = player.currentTime / player.duration
                    } else {
                        stopAudioPlayback()
                    }
                }
            }
        } catch {
            print("Failed to play audio: \(error)")
        }
    }

    private func stopAudioPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlayingAudio = false
        audioTimer?.invalidate()
        audioTimer = nil
        audioProgress = 0
    }

    private func loadAudioDuration() {
        guard let mediaPath = memory.mediaPath, memory.memoryType == .audio else {
            print("loadAudioDuration: No media path or not audio type")
            return
        }
        let url = MediaManager.shared.mediaURL(filename: mediaPath, type: .audio)
        print("loadAudioDuration: Loading from \(url.path)")

        // Check if file exists and its size
        guard FileManager.default.fileExists(atPath: url.path) else {
            print("loadAudioDuration: File does not exist!")
            return
        }

        // Use AVURLAsset to get duration - more reliable than AVAudioPlayer
        let asset = AVURLAsset(url: url)
        Task {
            do {
                let duration = try await asset.load(.duration)
                let seconds = CMTimeGetSeconds(duration)
                await MainActor.run {
                    if seconds.isFinite && seconds > 0 {
                        audioDuration = seconds
                        print("loadAudioDuration: Duration = \(seconds) seconds")
                    } else {
                        print("loadAudioDuration: Invalid duration: \(seconds)")
                    }
                }
            } catch {
                print("Failed to load audio duration: \(error)")
            }
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%d:%02d", minutes, seconds)
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
            HStack {
                Text("Tags")
                    .font(themeManager.theme.headlineFont)
                    .foregroundStyle(themeManager.theme.textPrimary)

                Spacer()

                // Re-analyze button
                if memory.memoryType == .photo || memory.memoryType == .video {
                    Button {
                        reanalyzeWithAI()
                    } label: {
                        if isRetagging {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else {
                            Image(systemName: "sparkles")
                        }
                    }
                    .disabled(isRetagging)
                }

                // Add tag button
                Button {
                    showingAddTagSheet = true
                } label: {
                    Image(systemName: "plus.circle")
                }
            }

            if memory.tagsArray.isEmpty {
                Text("No tags yet. Tap + to add tags.")
                    .font(themeManager.theme.captionFont)
                    .foregroundStyle(themeManager.theme.textSecondary)
                    .padding(.vertical, 8)
            } else {
                FlowLayout(spacing: 8) {
                    ForEach(memory.tagsArray) { tag in
                        tagChip(tag)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAddTagSheet) {
            addTagSheet
        }
    }

    private func tagChip(_ tag: Tag) -> some View {
        HStack(spacing: 4) {
            if tag.isAIGenerated {
                Image(systemName: "sparkles")
                    .font(.caption2)
            }
            Text(tag.name ?? "")

            // Remove button
            Button {
                removeTag(tag)
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.caption2)
            }
        }
        .font(themeManager.theme.captionFont)
        .foregroundStyle(tag.isAIGenerated ? themeManager.theme.primaryColor : themeManager.theme.secondaryColor)
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background((tag.isAIGenerated ? themeManager.theme.primaryColor : themeManager.theme.secondaryColor).opacity(0.1))
        .clipShape(Capsule())
    }

    private var addTagSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Tag name", text: $newTagName)
                        .autocorrectionDisabled()
                }

                Section {
                    suggestedTagsView
                } header: {
                    Text("Suggestions")
                }
            }
            .navigationTitle("Add Tag")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        newTagName = ""
                        showingAddTagSheet = false
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        addTag()
                    }
                    .disabled(newTagName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
    }

    private var suggestedTagsView: some View {
        let suggestions = ["Birthday", "Holiday", "Vacation", "First", "Milestone", "Funny", "Sweet Moment", "Family", "Outdoors", "School"]

        return FlowLayout(spacing: 8) {
            ForEach(suggestions, id: \.self) { suggestion in
                Button {
                    newTagName = suggestion
                } label: {
                    Text(suggestion)
                        .font(themeManager.theme.captionFont)
                        .foregroundStyle(themeManager.theme.textPrimary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(themeManager.theme.surfaceColor)
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func addTag() {
        let trimmed = newTagName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        AITaggingService.shared.addTag(trimmed, to: memory, in: viewContext)
        newTagName = ""
        showingAddTagSheet = false
    }

    private func removeTag(_ tag: Tag) {
        AITaggingService.shared.removeTag(tag, from: memory, in: viewContext)
    }

    private func reanalyzeWithAI() {
        guard memory.memoryType == .photo || memory.memoryType == .video else { return }

        isRetagging = true

        Task {
            // Load the image
            var image: UIImage?

            if memory.memoryType == .photo, let mediaPath = memory.mediaPath {
                image = MediaManager.shared.loadImage(filename: mediaPath, type: .photo)
            } else if memory.memoryType == .video, let thumbnailPath = memory.thumbnailPath {
                image = MediaManager.shared.loadThumbnail(filename: thumbnailPath)
            }

            await AITaggingService.shared.tagMemory(memory, image: image, in: viewContext)

            await MainActor.run {
                isRetagging = false
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

    @State private var isExtractingText = false

    private func extractText() {
        guard memory.memoryType == .photo,
              let mediaPath = memory.mediaPath,
              let image = MediaManager.shared.loadImage(filename: mediaPath, type: .photo) else {
            return
        }

        isExtractingText = true

        Task {
            if let extractedText = await AITaggingService.shared.extractText(from: image) {
                await MainActor.run {
                    memory.extractedText = extractedText
                    try? viewContext.save()
                    isExtractingText = false
                }
            } else {
                await MainActor.run {
                    isExtractingText = false
                }
            }
        }
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

// MARK: - Video Player View

struct VideoPlayerView: View {
    @Environment(\.dismiss) private var dismiss
    let videoURL: URL

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VideoPlayer(player: AVPlayer(url: videoURL))
                .ignoresSafeArea()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
        }
        .background(Color.black)
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
