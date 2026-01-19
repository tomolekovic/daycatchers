import Foundation
import CoreData
import Compression

/// BackupInfo contains metadata about a backup file
struct BackupInfo: Identifiable, Codable {
    let id: UUID
    let url: URL
    let date: Date
    let size: Int64
    let memoriesCount: Int
    let lovedOnesCount: Int
    let eventsCount: Int
    let tagsCount: Int

    enum CodingKeys: String, CodingKey {
        case id, date, size, memoriesCount, lovedOnesCount, eventsCount, tagsCount
    }

    init(id: UUID = UUID(), url: URL, date: Date, size: Int64, memoriesCount: Int, lovedOnesCount: Int, eventsCount: Int, tagsCount: Int) {
        self.id = id
        self.url = url
        self.date = date
        self.size = size
        self.memoriesCount = memoriesCount
        self.lovedOnesCount = lovedOnesCount
        self.eventsCount = eventsCount
        self.tagsCount = tagsCount
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        date = try container.decode(Date.self, forKey: .date)
        size = try container.decode(Int64.self, forKey: .size)
        memoriesCount = try container.decode(Int.self, forKey: .memoriesCount)
        lovedOnesCount = try container.decode(Int.self, forKey: .lovedOnesCount)
        eventsCount = try container.decode(Int.self, forKey: .eventsCount)
        tagsCount = try container.decode(Int.self, forKey: .tagsCount)
        url = URL(fileURLWithPath: "") // Will be set by the service
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(date, forKey: .date)
        try container.encode(size, forKey: .size)
        try container.encode(memoriesCount, forKey: .memoriesCount)
        try container.encode(lovedOnesCount, forKey: .lovedOnesCount)
        try container.encode(eventsCount, forKey: .eventsCount)
        try container.encode(tagsCount, forKey: .tagsCount)
    }
}

/// RestoreReport contains results of a restore operation
struct RestoreReport {
    let lovedOnesRestored: Int
    let memoriesRestored: Int
    let eventsRestored: Int
    let tagsRestored: Int
    let mediaFilesRestored: Int
    let warnings: [String]
}

/// BackupManifest contains metadata stored in the backup ZIP
struct BackupManifest: Codable {
    let version: Int
    let createdAt: Date
    let appVersion: String
    let lovedOnesCount: Int
    let memoriesCount: Int
    let eventsCount: Int
    let tagsCount: Int
    let digestsCount: Int

    static let currentVersion = 1
}

/// BackupService handles creating and restoring backups
@MainActor
final class BackupService: ObservableObject {
    static let shared = BackupService()

    @Published var isBackingUp = false
    @Published var isRestoring = false
    @Published var progress: Double = 0
    @Published var currentStep: String = ""

    private let fileManager = FileManager.default

    private init() {
        createBackupsDirectoryIfNeeded()
    }

    // MARK: - Directory Management

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var backupsDirectory: URL {
        documentsDirectory.appendingPathComponent("Backups", isDirectory: true)
    }

    private var daycatcherDirectory: URL {
        documentsDirectory.appendingPathComponent("Daycatcher", isDirectory: true)
    }

    private func createBackupsDirectoryIfNeeded() {
        if !fileManager.fileExists(atPath: backupsDirectory.path) {
            try? fileManager.createDirectory(at: backupsDirectory, withIntermediateDirectories: true)
        }
    }

    // MARK: - Create Backup

    /// Create a complete backup of all data and media
    func createBackup(context: NSManagedObjectContext) async throws -> URL {
        isBackingUp = true
        progress = 0
        currentStep = "Preparing backup..."

        defer {
            isBackingUp = false
            progress = 1.0
            currentStep = ""
        }

        // Create temp directory for backup contents
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Fetch all data
        currentStep = "Exporting data..."
        progress = 0.1

        let lovedOnes = try await fetchAllLovedOnes(context: context)
        let memories = try await fetchAllMemories(context: context)
        let events = try await fetchAllEvents(context: context)
        let tags = try await fetchAllTags(context: context)
        let digests = try await fetchAllDigests(context: context)

        progress = 0.2

        // Create manifest
        let manifest = BackupManifest(
            version: BackupManifest.currentVersion,
            createdAt: Date(),
            appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0",
            lovedOnesCount: lovedOnes.count,
            memoriesCount: memories.count,
            eventsCount: events.count,
            tagsCount: tags.count,
            digestsCount: digests.count
        )

        // Write manifest
        let manifestData = try JSONEncoder().encode(manifest)
        try manifestData.write(to: tempDir.appendingPathComponent("manifest.json"))

        progress = 0.25

        // Export entities to JSON
        currentStep = "Exporting entities..."

        let exportData = BackupData(
            lovedOnes: lovedOnes.map { LovedOneExport(from: $0) },
            memories: memories.map { MemoryExport(from: $0) },
            events: events.map { EventExport(from: $0) },
            tags: tags.map { TagExport(from: $0) },
            digests: digests.map { DigestExport(from: $0) }
        )

        let dataJSON = try JSONEncoder().encode(exportData)
        try dataJSON.write(to: tempDir.appendingPathComponent("data.json"))

        progress = 0.4

        // Copy media files
        currentStep = "Copying media files..."
        let mediaDir = tempDir.appendingPathComponent("media")
        try fileManager.createDirectory(at: mediaDir, withIntermediateDirectories: true)

        // Create media subdirectories
        let subdirs = ["photos", "videos", "audio", "thumbnails", "profiles"]
        for subdir in subdirs {
            try fileManager.createDirectory(
                at: mediaDir.appendingPathComponent(subdir),
                withIntermediateDirectories: true
            )
        }

        // Copy media files
        let sourceMediaDir = daycatcherDirectory
        var mediaFilesCopied = 0

        for subdir in subdirs {
            let sourceSubdir = sourceMediaDir.appendingPathComponent(subdir)
            let destSubdir = mediaDir.appendingPathComponent(subdir)

            if let files = try? fileManager.contentsOfDirectory(at: sourceSubdir, includingPropertiesForKeys: nil) {
                for file in files {
                    let destFile = destSubdir.appendingPathComponent(file.lastPathComponent)
                    try? fileManager.copyItem(at: file, to: destFile)
                    mediaFilesCopied += 1
                }
            }
        }

        progress = 0.7

        // Create ZIP archive
        currentStep = "Creating archive..."
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let backupFilename = "backup_\(dateFormatter.string(from: Date())).zip"
        let backupURL = backupsDirectory.appendingPathComponent(backupFilename)

        // Remove existing file if present
        try? fileManager.removeItem(at: backupURL)

        // Create ZIP using NSFileCoordinator approach
        try createZipArchive(from: tempDir, to: backupURL)

        progress = 1.0
        currentStep = "Backup complete!"

        return backupURL
    }

    // MARK: - Restore Backup

    /// Restore data from a backup file
    func restoreFromBackup(url: URL, context: NSManagedObjectContext) async throws -> RestoreReport {
        isRestoring = true
        progress = 0
        currentStep = "Preparing restore..."

        defer {
            isRestoring = false
            progress = 1.0
            currentStep = ""
        }

        // Create temp directory for extraction
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)

        defer {
            try? fileManager.removeItem(at: tempDir)
        }

        // Extract ZIP
        currentStep = "Extracting backup..."
        progress = 0.1

        try extractZipArchive(from: url, to: tempDir)

        progress = 0.2

        // Read manifest
        let manifestURL = tempDir.appendingPathComponent("manifest.json")
        guard fileManager.fileExists(atPath: manifestURL.path) else {
            throw BackupError.invalidBackup("Missing manifest.json")
        }

        let manifestData = try Data(contentsOf: manifestURL)
        let manifest = try JSONDecoder().decode(BackupManifest.self, from: manifestData)

        // Check version compatibility
        if manifest.version > BackupManifest.currentVersion {
            throw BackupError.incompatibleVersion(manifest.version)
        }

        progress = 0.25

        // Read data
        currentStep = "Reading backup data..."
        let dataURL = tempDir.appendingPathComponent("data.json")
        guard fileManager.fileExists(atPath: dataURL.path) else {
            throw BackupError.invalidBackup("Missing data.json")
        }

        let dataData = try Data(contentsOf: dataURL)
        let backupData = try JSONDecoder().decode(BackupData.self, from: dataData)

        progress = 0.3

        // Clear existing data
        currentStep = "Clearing existing data..."
        try await clearAllData(context: context)

        progress = 0.4

        // Restore entities
        currentStep = "Restoring loved ones..."
        let warnings: [String] = []

        // Create ID mappings for relationships
        var lovedOneIDMap: [UUID: LovedOne] = [:]
        var tagIDMap: [UUID: Tag] = [:]
        var eventIDMap: [UUID: Event] = [:]

        // Restore Tags first (no dependencies)
        for tagExport in backupData.tags {
            let tag = Tag(context: context)
            tag.id = tagExport.id
            tag.name = tagExport.name
            tag.isAIGenerated = tagExport.isAIGenerated
            tag.createdAt = tagExport.createdAt
            tagIDMap[tagExport.id] = tag
        }

        progress = 0.45

        // Restore LovedOnes
        currentStep = "Restoring loved ones..."
        for lovedOneExport in backupData.lovedOnes {
            let lovedOne = LovedOne(context: context)
            lovedOne.id = lovedOneExport.id
            lovedOne.name = lovedOneExport.name
            lovedOne.birthDate = lovedOneExport.birthDate
            lovedOne.relationship = lovedOneExport.relationship
            lovedOne.gender = lovedOneExport.gender
            lovedOne.profileImagePath = lovedOneExport.profileImagePath
            lovedOne.isSharedWithFamily = lovedOneExport.isSharedWithFamily
            lovedOne.createdAt = lovedOneExport.createdAt
            lovedOne.profileImageSyncStatus = lovedOneExport.profileImageSyncStatus
            lovedOne.cloudProfileImageRecordName = lovedOneExport.cloudProfileImageRecordName
            lovedOneIDMap[lovedOneExport.id] = lovedOne
        }

        progress = 0.55

        // Restore Events
        currentStep = "Restoring events..."
        for eventExport in backupData.events {
            let event = Event(context: context)
            event.id = eventExport.id
            event.title = eventExport.title
            event.date = eventExport.date
            event.isAllDay = eventExport.isAllDay
            event.notes = eventExport.notes
            event.eventType = eventExport.eventType
            event.reminderOffset = eventExport.reminderOffset
            event.createdAt = eventExport.createdAt

            if let lovedOneID = eventExport.lovedOneID,
               let lovedOne = lovedOneIDMap[lovedOneID] {
                event.lovedOne = lovedOne
            }

            eventIDMap[eventExport.id] = event
        }

        progress = 0.65

        // Restore Memories
        currentStep = "Restoring memories..."
        for memoryExport in backupData.memories {
            let memory = Memory(context: context)
            memory.id = memoryExport.id
            memory.type = memoryExport.type
            memory.title = memoryExport.title
            memory.notes = memoryExport.notes
            memory.mediaPath = memoryExport.mediaPath
            memory.thumbnailPath = memoryExport.thumbnailPath
            memory.captureDate = memoryExport.captureDate
            memory.latitude = memoryExport.latitude
            memory.longitude = memoryExport.longitude
            memory.locationName = memoryExport.locationName
            memory.extractedText = memoryExport.extractedText
            memory.transcription = memoryExport.transcription
            memory.createdAt = memoryExport.createdAt
            memory.mediaSyncStatus = memoryExport.mediaSyncStatus
            memory.thumbnailSyncStatus = memoryExport.thumbnailSyncStatus
            memory.cloudAssetRecordName = memoryExport.cloudAssetRecordName
            memory.cloudThumbnailRecordName = memoryExport.cloudThumbnailRecordName
            memory.lastSyncAttempt = memoryExport.lastSyncAttempt
            memory.syncErrorMessage = memoryExport.syncErrorMessage
            memory.mediaFileSize = memoryExport.mediaFileSize
            memory.uploadProgress = memoryExport.uploadProgress

            if let lovedOneID = memoryExport.lovedOneID,
               let lovedOne = lovedOneIDMap[lovedOneID] {
                memory.lovedOne = lovedOne
            }

            if let eventID = memoryExport.linkedEventID,
               let event = eventIDMap[eventID] {
                memory.linkedEvent = event
            }

            // Restore tag relationships
            for tagID in memoryExport.tagIDs {
                if let tag = tagIDMap[tagID] {
                    memory.addToTags(tag)
                }
            }
        }

        progress = 0.75

        // Restore Digests
        currentStep = "Restoring digests..."
        for digestExport in backupData.digests {
            let digest = WeeklyDigest(context: context)
            digest.id = digestExport.id
            digest.weekStartDate = digestExport.weekStartDate
            digest.summary = digestExport.summary
            digest.highlightedMemoryIDs = digestExport.highlightedMemoryIDs
            digest.isRead = digestExport.isRead
            digest.generatedAt = digestExport.generatedAt
        }

        progress = 0.8

        // Restore media files
        currentStep = "Restoring media files..."
        let sourceMediaDir = tempDir.appendingPathComponent("media")
        var mediaFilesRestored = 0

        let subdirs = ["photos", "videos", "audio", "thumbnails", "profiles"]
        for subdir in subdirs {
            let sourceSubdir = sourceMediaDir.appendingPathComponent(subdir)
            let destSubdir = daycatcherDirectory.appendingPathComponent(subdir)

            // Create destination directory if needed
            try? fileManager.createDirectory(at: destSubdir, withIntermediateDirectories: true)

            if let files = try? fileManager.contentsOfDirectory(at: sourceSubdir, includingPropertiesForKeys: nil) {
                for file in files {
                    let destFile = destSubdir.appendingPathComponent(file.lastPathComponent)
                    try? fileManager.removeItem(at: destFile)
                    try? fileManager.copyItem(at: file, to: destFile)
                    mediaFilesRestored += 1
                }
            }
        }

        progress = 0.95

        // Save context
        currentStep = "Saving changes..."
        try context.save()

        progress = 1.0
        currentStep = "Restore complete!"

        return RestoreReport(
            lovedOnesRestored: backupData.lovedOnes.count,
            memoriesRestored: backupData.memories.count,
            eventsRestored: backupData.events.count,
            tagsRestored: backupData.tags.count,
            mediaFilesRestored: mediaFilesRestored,
            warnings: warnings
        )
    }

    // MARK: - Backup Management

    /// List all available backups
    func listAvailableBackups() -> [BackupInfo] {
        guard let files = try? fileManager.contentsOfDirectory(
            at: backupsDirectory,
            includingPropertiesForKeys: [.fileSizeKey, .creationDateKey],
            options: .skipsHiddenFiles
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "zip" }
            .compactMap { url -> BackupInfo? in
                guard let resourceValues = try? url.resourceValues(forKeys: [.fileSizeKey, .creationDateKey]),
                      let size = resourceValues.fileSize,
                      let date = resourceValues.creationDate else {
                    return nil
                }

                // Try to read manifest from ZIP to get counts
                if let manifest = readManifestFromBackup(url: url) {
                    return BackupInfo(
                        url: url,
                        date: manifest.createdAt,
                        size: Int64(size),
                        memoriesCount: manifest.memoriesCount,
                        lovedOnesCount: manifest.lovedOnesCount,
                        eventsCount: manifest.eventsCount,
                        tagsCount: manifest.tagsCount
                    )
                } else {
                    return BackupInfo(
                        url: url,
                        date: date,
                        size: Int64(size),
                        memoriesCount: 0,
                        lovedOnesCount: 0,
                        eventsCount: 0,
                        tagsCount: 0
                    )
                }
            }
            .sorted { $0.date > $1.date }
    }

    /// Delete a backup
    func deleteBackup(_ backup: BackupInfo) throws {
        try fileManager.removeItem(at: backup.url)
    }

    /// Get total size of all backups
    func getBackupsSize() -> Int64 {
        var totalSize: Int64 = 0

        if let enumerator = fileManager.enumerator(at: backupsDirectory, includingPropertiesForKeys: [.fileSizeKey]) {
            for case let fileURL as URL in enumerator {
                if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    totalSize += Int64(fileSize)
                }
            }
        }

        return totalSize
    }

    /// Get formatted backup size string
    func formattedBackupsSize() -> String {
        let bytes = getBackupsSize()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Private Helpers

    private func fetchAllLovedOnes(context: NSManagedObjectContext) async throws -> [LovedOne] {
        let request: NSFetchRequest<LovedOne> = LovedOne.fetchRequest()
        return try context.fetch(request)
    }

    private func fetchAllMemories(context: NSManagedObjectContext) async throws -> [Memory] {
        let request: NSFetchRequest<Memory> = Memory.fetchRequest()
        return try context.fetch(request)
    }

    private func fetchAllEvents(context: NSManagedObjectContext) async throws -> [Event] {
        let request: NSFetchRequest<Event> = Event.fetchRequest()
        return try context.fetch(request)
    }

    private func fetchAllTags(context: NSManagedObjectContext) async throws -> [Tag] {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        return try context.fetch(request)
    }

    private func fetchAllDigests(context: NSManagedObjectContext) async throws -> [WeeklyDigest] {
        let request: NSFetchRequest<WeeklyDigest> = WeeklyDigest.fetchRequest()
        return try context.fetch(request)
    }

    private func clearAllData(context: NSManagedObjectContext) async throws {
        let entityNames = ["Memory", "Event", "Tag", "WeeklyDigest", "LovedOne"]

        for entityName in entityNames {
            let fetchRequest = NSFetchRequest<NSFetchRequestResult>(entityName: entityName)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetchRequest)
            try context.execute(deleteRequest)
        }

        context.reset()
    }

    private func readManifestFromBackup(url: URL) -> BackupManifest? {
        // Extract just the manifest from the ZIP
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString)

        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            defer { try? fileManager.removeItem(at: tempDir) }

            try extractZipArchive(from: url, to: tempDir)

            let manifestURL = tempDir.appendingPathComponent("manifest.json")
            let data = try Data(contentsOf: manifestURL)
            return try JSONDecoder().decode(BackupManifest.self, from: data)
        } catch {
            return nil
        }
    }

    // MARK: - ZIP Archive Helpers

    private func createZipArchive(from sourceDir: URL, to destURL: URL) throws {
        let coordinator = NSFileCoordinator()
        var coordinatorError: NSError?
        var copyError: Error?

        coordinator.coordinate(readingItemAt: sourceDir, options: [.forUploading], error: &coordinatorError) { zipURL in
            do {
                try self.fileManager.copyItem(at: zipURL, to: destURL)
            } catch {
                copyError = error
            }
        }

        if let error = coordinatorError {
            throw error
        }
        if let error = copyError {
            throw error
        }
    }

    private func extractZipArchive(from sourceURL: URL, to destDir: URL) throws {
        // On iOS, we use NSFileCoordinator to extract the ZIP
        // The system will automatically handle ZIP extraction when we coordinate
        // reading with the appropriate options

        var accessGranted = false
        if sourceURL.startAccessingSecurityScopedResource() {
            accessGranted = true
        }
        defer {
            if accessGranted {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        // Copy the ZIP to temp location
        let tempZipURL = fileManager.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".zip")
        try? fileManager.removeItem(at: tempZipURL)
        try fileManager.copyItem(at: sourceURL, to: tempZipURL)

        // Read the ZIP and manually extract using compression
        let zipData = try Data(contentsOf: tempZipURL)

        // For ZIP extraction on iOS, we'll use a simplified approach:
        // Parse the ZIP file structure and extract files
        try extractZipData(zipData, to: destDir)

        // Clean up temp file
        try? fileManager.removeItem(at: tempZipURL)
    }

    /// Simple ZIP extraction for iOS
    /// This handles standard ZIP files created by NSFileCoordinator
    private func extractZipData(_ data: Data, to destDir: URL) throws {
        // ZIP file format:
        // Local file headers start with signature 0x04034b50 (little endian: 50 4b 03 04)
        // Central directory starts with 0x02014b50

        var offset = 0
        let bytes = [UInt8](data)

        while offset + 30 < bytes.count {
            // Check for local file header signature: PK\x03\x04
            guard bytes[offset] == 0x50,
                  bytes[offset + 1] == 0x4B,
                  bytes[offset + 2] == 0x03,
                  bytes[offset + 3] == 0x04 else {
                // Not a local file header, might be central directory or end
                break
            }

            // Parse local file header
            let generalPurposeBitFlag = UInt16(bytes[offset + 6]) | (UInt16(bytes[offset + 7]) << 8)
            let compressionMethod = UInt16(bytes[offset + 8]) | (UInt16(bytes[offset + 9]) << 8)
            let compressedSize = UInt32(bytes[offset + 18]) | (UInt32(bytes[offset + 19]) << 8) |
                                 (UInt32(bytes[offset + 20]) << 16) | (UInt32(bytes[offset + 21]) << 24)
            let uncompressedSize = UInt32(bytes[offset + 22]) | (UInt32(bytes[offset + 23]) << 8) |
                                   (UInt32(bytes[offset + 24]) << 16) | (UInt32(bytes[offset + 25]) << 24)
            let fileNameLength = UInt16(bytes[offset + 26]) | (UInt16(bytes[offset + 27]) << 8)
            let extraFieldLength = UInt16(bytes[offset + 28]) | (UInt16(bytes[offset + 29]) << 8)

            // Get file name
            let fileNameStart = offset + 30
            let fileNameEnd = fileNameStart + Int(fileNameLength)
            guard fileNameEnd <= bytes.count else { break }

            let fileNameBytes = Array(bytes[fileNameStart..<fileNameEnd])
            guard let fileName = String(bytes: fileNameBytes, encoding: .utf8) else {
                offset = fileNameEnd + Int(extraFieldLength) + Int(compressedSize)
                continue
            }

            // Data starts after file name and extra field
            let dataStart = fileNameEnd + Int(extraFieldLength)

            // Handle data descriptor (bit 3 of general purpose flag)
            if (generalPurposeBitFlag & 0x08) != 0 {
                // Sizes are in data descriptor after the data
                // We need to find the data descriptor
                // For simplicity, skip files with data descriptors in this implementation
                offset = dataStart
                continue
            }

            let dataEnd = dataStart + Int(compressedSize)
            guard dataEnd <= bytes.count else { break }

            // Create file path
            let filePath = destDir.appendingPathComponent(fileName)

            // Check if it's a directory
            if fileName.hasSuffix("/") {
                try fileManager.createDirectory(at: filePath, withIntermediateDirectories: true)
            } else {
                // Create parent directories
                try fileManager.createDirectory(at: filePath.deletingLastPathComponent(), withIntermediateDirectories: true)

                // Extract file data
                let compressedData = Data(bytes[dataStart..<dataEnd])

                let fileData: Data
                if compressionMethod == 0 {
                    // Stored (no compression)
                    fileData = compressedData
                } else if compressionMethod == 8 {
                    // Deflate compression
                    fileData = try decompressDeflate(compressedData, uncompressedSize: Int(uncompressedSize))
                } else {
                    // Unsupported compression method, skip
                    offset = dataEnd
                    continue
                }

                try fileData.write(to: filePath)
            }

            offset = dataEnd
        }
    }

    /// Decompress deflate-compressed data
    private func decompressDeflate(_ data: Data, uncompressedSize: Int) throws -> Data {
        // Use Compression framework for zlib decompression
        // Note: ZIP uses raw deflate, not zlib wrapped

        var decompressed = Data(count: uncompressedSize)
        let result = decompressed.withUnsafeMutableBytes { destBuffer in
            data.withUnsafeBytes { sourceBuffer in
                compression_decode_buffer(
                    destBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    uncompressedSize,
                    sourceBuffer.bindMemory(to: UInt8.self).baseAddress!,
                    data.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard result > 0 else {
            throw BackupError.restoreFailed("Failed to decompress file data")
        }

        return Data(decompressed.prefix(result))
    }
}

// MARK: - Errors

enum BackupError: LocalizedError {
    case invalidBackup(String)
    case incompatibleVersion(Int)
    case restoreFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidBackup(let reason):
            return "Invalid backup: \(reason)"
        case .incompatibleVersion(let version):
            return "Backup version \(version) is not compatible with this version of the app"
        case .restoreFailed(let reason):
            return "Restore failed: \(reason)"
        }
    }
}

// MARK: - Export Models

private struct BackupData: Codable {
    let lovedOnes: [LovedOneExport]
    let memories: [MemoryExport]
    let events: [EventExport]
    let tags: [TagExport]
    let digests: [DigestExport]
}

private struct LovedOneExport: Codable {
    let id: UUID
    let name: String?
    let birthDate: Date?
    let relationship: String?
    let gender: String?
    let profileImagePath: String?
    let isSharedWithFamily: Bool
    let createdAt: Date?
    let profileImageSyncStatus: String?
    let cloudProfileImageRecordName: String?

    init(from lovedOne: LovedOne) {
        self.id = lovedOne.id ?? UUID()
        self.name = lovedOne.name
        self.birthDate = lovedOne.birthDate
        self.relationship = lovedOne.relationship
        self.gender = lovedOne.gender
        self.profileImagePath = lovedOne.profileImagePath
        self.isSharedWithFamily = lovedOne.isSharedWithFamily
        self.createdAt = lovedOne.createdAt
        self.profileImageSyncStatus = lovedOne.profileImageSyncStatus
        self.cloudProfileImageRecordName = lovedOne.cloudProfileImageRecordName
    }
}

private struct MemoryExport: Codable {
    let id: UUID
    let type: String?
    let title: String?
    let notes: String?
    let mediaPath: String?
    let thumbnailPath: String?
    let captureDate: Date?
    let latitude: Double
    let longitude: Double
    let locationName: String?
    let extractedText: String?
    let transcription: String?
    let createdAt: Date?
    let mediaSyncStatus: String?
    let thumbnailSyncStatus: String?
    let cloudAssetRecordName: String?
    let cloudThumbnailRecordName: String?
    let lastSyncAttempt: Date?
    let syncErrorMessage: String?
    let mediaFileSize: Int64
    let uploadProgress: Double
    let lovedOneID: UUID?
    let linkedEventID: UUID?
    let tagIDs: [UUID]

    init(from memory: Memory) {
        self.id = memory.id ?? UUID()
        self.type = memory.type
        self.title = memory.title
        self.notes = memory.notes
        self.mediaPath = memory.mediaPath
        self.thumbnailPath = memory.thumbnailPath
        self.captureDate = memory.captureDate
        self.latitude = memory.latitude
        self.longitude = memory.longitude
        self.locationName = memory.locationName
        self.extractedText = memory.extractedText
        self.transcription = memory.transcription
        self.createdAt = memory.createdAt
        self.mediaSyncStatus = memory.mediaSyncStatus
        self.thumbnailSyncStatus = memory.thumbnailSyncStatus
        self.cloudAssetRecordName = memory.cloudAssetRecordName
        self.cloudThumbnailRecordName = memory.cloudThumbnailRecordName
        self.lastSyncAttempt = memory.lastSyncAttempt
        self.syncErrorMessage = memory.syncErrorMessage
        self.mediaFileSize = memory.mediaFileSize
        self.uploadProgress = memory.uploadProgress
        self.lovedOneID = memory.lovedOne?.id
        self.linkedEventID = memory.linkedEvent?.id
        self.tagIDs = memory.tagsArray.compactMap { $0.id }
    }
}

private struct EventExport: Codable {
    let id: UUID
    let title: String?
    let date: Date?
    let isAllDay: Bool
    let notes: String?
    let eventType: String?
    let reminderOffset: String?
    let createdAt: Date?
    let lovedOneID: UUID?

    init(from event: Event) {
        self.id = event.id ?? UUID()
        self.title = event.title
        self.date = event.date
        self.isAllDay = event.isAllDay
        self.notes = event.notes
        self.eventType = event.eventType
        self.reminderOffset = event.reminderOffset
        self.createdAt = event.createdAt
        self.lovedOneID = event.lovedOne?.id
    }
}

private struct TagExport: Codable {
    let id: UUID
    let name: String?
    let isAIGenerated: Bool
    let createdAt: Date?

    init(from tag: Tag) {
        self.id = tag.id ?? UUID()
        self.name = tag.name
        self.isAIGenerated = tag.isAIGenerated
        self.createdAt = tag.createdAt
    }
}

private struct DigestExport: Codable {
    let id: UUID
    let weekStartDate: Date?
    let summary: String?
    let highlightedMemoryIDs: Data?
    let isRead: Bool
    let generatedAt: Date?

    init(from digest: WeeklyDigest) {
        self.id = digest.id ?? UUID()
        self.weekStartDate = digest.weekStartDate
        self.summary = digest.summary
        self.highlightedMemoryIDs = digest.highlightedMemoryIDs
        self.isRead = digest.isRead
        self.generatedAt = digest.generatedAt
    }
}
