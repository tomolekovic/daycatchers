import SwiftUI
import CoreData

/// CaptureFlowContainer orchestrates the complete capture workflow.
/// It presents the appropriate capture view based on memory type and handles
/// saving the captured media to create a Memory record.
struct CaptureFlowContainer: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @AppStorage("smartTaggingEnabled") private var smartTaggingEnabled = true

    let memoryType: MemoryType
    let lovedOne: LovedOne?

    @State private var capturedMemory: Memory?
    @State private var capturedImage: UIImage?
    @State private var showMetadataEditor = false
    @State private var isProcessing = false
    @State private var processingMessage = "Saving..."
    @State private var errorMessage: String?
    @State private var showError = false

    var body: some View {
        Group {
            if showMetadataEditor, let memory = capturedMemory {
                EditMemoryView(memory: memory)
            } else {
                captureView
            }
        }
        .overlay {
            if isProcessing {
                processingOverlay
            }
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred while saving.")
        }
    }

    // MARK: - Capture Views

    @ViewBuilder
    private var captureView: some View {
        switch memoryType {
        case .photo:
            PhotoCaptureView(lovedOne: lovedOne) { image in
                savePhoto(image)
            }
        case .video:
            VideoCaptureView(lovedOne: lovedOne) { url in
                saveVideo(url)
            }
        case .audio:
            AudioCaptureView(lovedOne: lovedOne) { url in
                saveAudio(url)
            }
        case .text:
            TextCaptureView(lovedOne: lovedOne) { content, title in
                saveText(content: content, title: title)
            }
        }
    }

    // MARK: - Processing Overlay

    private var processingOverlay: some View {
        ZStack {
            Color.black.opacity(0.5)
                .ignoresSafeArea()

            VStack(spacing: themeManager.theme.spacingMedium) {
                ProgressView()
                    .scaleEffect(1.5)
                    .tint(.white)

                Text(processingMessage)
                    .font(themeManager.theme.headlineFont)
                    .foregroundStyle(.white)
            }
            .padding(themeManager.theme.spacingLarge)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))
        }
    }

    // MARK: - Save Operations

    private func savePhoto(_ image: UIImage) {
        isProcessing = true
        processingMessage = "Saving..."

        Task {
            do {
                let memory = try await savePhotoToMemory(image)

                // Run AI tagging if enabled
                if smartTaggingEnabled {
                    await MainActor.run {
                        processingMessage = "Analyzing..."
                    }
                    await AITaggingService.shared.tagMemory(memory, image: image, in: viewContext)
                }

                await MainActor.run {
                    capturedMemory = memory
                    capturedImage = image
                    isProcessing = false
                    showMetadataEditor = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isProcessing = false
                }
            }
        }
    }

    private func saveVideo(_ url: URL) {
        isProcessing = true
        processingMessage = "Saving..."

        Task {
            do {
                let (memory, thumbnail) = try await saveVideoToMemory(url)

                // Run AI tagging if enabled (use thumbnail for analysis)
                if smartTaggingEnabled, let thumbnail = thumbnail {
                    await MainActor.run {
                        processingMessage = "Analyzing..."
                    }
                    await AITaggingService.shared.tagMemory(memory, image: thumbnail, in: viewContext)
                }

                await MainActor.run {
                    capturedMemory = memory
                    isProcessing = false
                    showMetadataEditor = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isProcessing = false
                }
            }
        }
    }

    private func saveAudio(_ url: URL) {
        isProcessing = true
        processingMessage = "Saving..."

        Task {
            do {
                let memory = try await saveAudioToMemory(url)

                // Run AI tagging if enabled (no image, just metadata tags)
                if smartTaggingEnabled {
                    await MainActor.run {
                        processingMessage = "Analyzing..."
                    }
                    await AITaggingService.shared.tagMemory(memory, in: viewContext)
                }

                await MainActor.run {
                    capturedMemory = memory
                    isProcessing = false
                    showMetadataEditor = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isProcessing = false
                }
            }
        }
    }

    private func saveText(content: String, title: String?) {
        isProcessing = true
        processingMessage = "Saving..."

        Task {
            do {
                let memory = try await saveTextToMemory(content: content, title: title)

                // Run AI tagging if enabled (text analysis)
                if smartTaggingEnabled {
                    await MainActor.run {
                        processingMessage = "Analyzing..."
                    }
                    await AITaggingService.shared.tagMemory(memory, in: viewContext)
                }

                await MainActor.run {
                    capturedMemory = memory
                    isProcessing = false
                    showMetadataEditor = true
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    showError = true
                    isProcessing = false
                }
            }
        }
    }

    // MARK: - Memory Creation

    private func savePhotoToMemory(_ image: UIImage) async throws -> Memory {
        // Save the photo
        guard let filename = MediaManager.shared.savePhoto(image: image) else {
            throw CaptureError.saveFailed
        }

        // Generate and save thumbnail
        let thumbnailFilename = MediaManager.shared.saveThumbnail(image: image)

        // Generate thumbnail data for Core Data (enables CloudKit sync for shared memories)
        let thumbnailSize = CGSize(width: 300, height: 300)
        let resizedThumbnail = image.resized(to: thumbnailSize)
        let thumbnailData = resizedThumbnail.jpegData(compressionQuality: 0.7)

        // Create memory record
        return try await createMemory(
            type: .photo,
            mediaPath: filename,
            thumbnailPath: thumbnailFilename,
            thumbnailData: thumbnailData
        )
    }

    private func saveVideoToMemory(_ url: URL) async throws -> (Memory, UIImage?) {
        // Save the video first
        guard let filename = MediaManager.shared.saveVideo(from: url) else {
            throw CaptureError.saveFailed
        }

        // Generate thumbnail from the SAVED video (not temp file)
        let savedVideoURL = MediaManager.shared.mediaURL(filename: filename, type: .video)
        var thumbnailFilename: String?
        var thumbnailImage: UIImage?
        var thumbnailData: Data?
        if let thumbnail = MediaManager.shared.generateVideoThumbnail(from: savedVideoURL) {
            thumbnailFilename = MediaManager.shared.saveThumbnail(image: thumbnail)
            thumbnailImage = thumbnail

            // Generate thumbnail data for Core Data (enables CloudKit sync for shared memories)
            let thumbnailSize = CGSize(width: 300, height: 300)
            let resizedThumbnail = thumbnail.resized(to: thumbnailSize)
            thumbnailData = resizedThumbnail.jpegData(compressionQuality: 0.7)
        }

        // Clean up temp video file
        try? FileManager.default.removeItem(at: url)

        // Create memory record
        let memory = try await createMemory(
            type: .video,
            mediaPath: filename,
            thumbnailPath: thumbnailFilename,
            thumbnailData: thumbnailData
        )

        return (memory, thumbnailImage)
    }

    private func saveAudioToMemory(_ url: URL) async throws -> Memory {
        // Save the audio
        guard let filename = MediaManager.shared.saveAudio(from: url) else {
            throw CaptureError.saveFailed
        }

        // Clean up temp audio file
        try? FileManager.default.removeItem(at: url)

        // Create memory record (no thumbnail for audio)
        return try await createMemory(
            type: .audio,
            mediaPath: filename,
            thumbnailPath: nil
        )
    }

    private func saveTextToMemory(content: String, title: String?) async throws -> Memory {
        // Create memory record
        return try await createMemory(
            type: .text,
            mediaPath: nil,
            thumbnailPath: nil,
            title: title,
            notes: content
        )
    }

    private func createMemory(
        type: MemoryType,
        mediaPath: String?,
        thumbnailPath: String?,
        thumbnailData: Data? = nil,
        title: String? = nil,
        notes: String? = nil
    ) async throws -> Memory {
        let memory = try await viewContext.perform {
            let memory = Memory(context: self.viewContext)
            memory.id = UUID()
            memory.memoryType = type
            memory.mediaPath = mediaPath
            memory.thumbnailPath = thumbnailPath
            memory.thumbnailData = thumbnailData  // Store for CloudKit sync
            memory.title = title
            memory.notes = notes
            memory.captureDate = Date()
            memory.createdAt = Date()
            memory.lovedOne = self.lovedOne

            // Set initial sync status
            if mediaPath != nil && type != .text {
                memory.mediaSyncStatus = MediaSyncStatus.pending.rawValue
                if thumbnailPath != nil {
                    memory.thumbnailSyncStatus = MediaSyncStatus.pending.rawValue
                }

                // Calculate file size for progress tracking
                let url = MediaManager.shared.mediaURL(filename: mediaPath!, type: type)
                if let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
                   let size = attrs[.size] as? Int64 {
                    memory.mediaFileSize = size
                }
            }

            try self.viewContext.save()
            return memory
        }

        // Queue for upload in the background
        if mediaPath != nil && type != .text {
            Task {
                // If the LovedOne is already shared, upload media to the share zone
                // so recipients can access it
                if let lovedOne = self.lovedOne, lovedOne.isSharedWithFamily {
                    if let share = PersistenceController.shared.share(for: lovedOne) {
                        let shareZoneID = share.recordID.zoneID
                        await MediaSyncManager.shared.uploadMediaToSharedZone(for: memory, zoneID: shareZoneID)
                    } else {
                        // Fallback to normal upload if we can't get the share
                        await MediaSyncManager.shared.queueUpload(for: memory)
                    }
                } else {
                    // Normal upload to private zone for non-shared memories
                    await MediaSyncManager.shared.queueUpload(for: memory)
                }
            }
        }

        return memory
    }
}

// MARK: - Capture Error

enum CaptureError: LocalizedError {
    case saveFailed
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .saveFailed:
            return "Failed to save the captured media. Please try again."
        case .permissionDenied:
            return "Permission was denied. Please enable access in Settings."
        }
    }
}

// MARK: - Capture Sheet Modifier

extension View {
    func captureSheet(
        isPresented: Binding<Bool>,
        memoryType: MemoryType,
        lovedOne: LovedOne? = nil
    ) -> some View {
        sheet(isPresented: isPresented) {
            CaptureFlowContainer(memoryType: memoryType, lovedOne: lovedOne)
        }
    }
}

#Preview {
    CaptureFlowContainer(memoryType: .photo, lovedOne: nil)
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
