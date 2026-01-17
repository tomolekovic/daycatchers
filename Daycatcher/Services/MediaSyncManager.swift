import Foundation
import CloudKit
import CoreData
import Combine
import UIKit
import Network

/// MediaSyncManager handles CloudKit media asset synchronization.
/// Since NSPersistentCloudKitContainer only syncs Core Data records (not binary files),
/// this manager handles uploading/downloading actual media files as CKAssets.
final class MediaSyncManager: ObservableObject {
    static let shared = MediaSyncManager()

    // MARK: - Published State

    @Published var isUploading = false
    @Published var isDownloading = false
    @Published var pendingUploads: Int = 0
    @Published var pendingDownloads: Int = 0
    @Published var currentUploadProgress: Double = 0.0
    @Published var currentDownloadProgress: Double = 0.0
    @Published var syncError: Error?
    @Published var isNetworkAvailable = true

    // MARK: - CloudKit Configuration

    private let container: CKContainer
    private let privateDatabase: CKDatabase

    // MARK: - Dependencies

    private let persistenceController: PersistenceController
    private let mediaManager: MediaManager

    // MARK: - Network Monitoring

    private let networkMonitor = NWPathMonitor()
    private let networkQueue = DispatchQueue(label: "com.daycatcher.networkMonitor")

    // MARK: - Operation Queues

    private let uploadQueue = OperationQueue()
    private let downloadQueue = OperationQueue()

    // MARK: - Configuration

    private let maxConcurrentUploads = 2
    private let maxConcurrentDownloads = 3
    private let maxRetryAttempts = 3
    private let retryDelayBase: TimeInterval = 2.0

    // MARK: - CloudKit Record Types

    static let mediaAssetRecordType = "MediaAsset"
    static let thumbnailAssetRecordType = "ThumbnailAsset"
    static let profileImageAssetRecordType = "ProfileImageAsset"

    // MARK: - Initialization

    private init(
        persistenceController: PersistenceController = .shared,
        mediaManager: MediaManager = .shared
    ) {
        self.persistenceController = persistenceController
        self.mediaManager = mediaManager

        // Initialize CloudKit container
        // Note: CloudKit operations will fail gracefully in simulator/test environments
        self.container = CKContainer(identifier: PersistenceController.cloudKitContainerIdentifier)
        self.privateDatabase = container.privateCloudDatabase

        uploadQueue.maxConcurrentOperationCount = maxConcurrentUploads
        uploadQueue.qualityOfService = .userInitiated

        downloadQueue.maxConcurrentOperationCount = maxConcurrentDownloads
        downloadQueue.qualityOfService = .userInitiated

        // Only set up network monitoring if not in unit test environment
        if ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] == nil {
            setupNetworkMonitoring()
        }
    }

    // MARK: - Network Monitoring

    private func setupNetworkMonitoring() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                let wasAvailable = self?.isNetworkAvailable ?? false
                self?.isNetworkAvailable = path.status == .satisfied

                // If network was restored, retry pending uploads
                if !wasAvailable && path.status == .satisfied {
                    Task {
                        await self?.retryFailedUploads()
                    }
                }
            }
        }
        networkMonitor.start(queue: networkQueue)
    }

    // MARK: - Upload Operations

    /// Queue a memory for media upload
    func queueUpload(for memory: Memory) async {
        guard memory.hasMedia else { return }
        guard memory.memoryType != .text else { return }
        guard memory.syncStatus != .synced else { return }
        guard memory.syncStatus != .localOnly else { return }

        await updateSyncStatus(for: memory, status: .pending)
        await updatePendingCount()

        // Start upload if network is available
        if isNetworkAvailable {
            await uploadMedia(for: memory)
        }
    }

    /// Upload media file as CKAsset to CloudKit
    func uploadMedia(for memory: Memory) async {
        guard let mediaPath = memory.mediaPath else { return }
        guard memory.syncStatus != .synced else { return }

        let memoryType = memory.memoryType
        let mediaURL = mediaManager.mediaURL(filename: mediaPath, type: memoryType)

        guard FileManager.default.fileExists(atPath: mediaURL.path) else {
            await updateSyncStatus(for: memory, status: .failed, error: "Local file not found")
            return
        }

        await updateSyncStatus(for: memory, status: .uploading)

        await MainActor.run {
            isUploading = true
        }

        do {
            // Create the CKRecord with CKAsset
            let recordID = CKRecord.ID(recordName: UUID().uuidString)
            let record = CKRecord(recordType: Self.mediaAssetRecordType, recordID: recordID)

            record["memoryID"] = memory.id?.uuidString as CKRecordValue?
            record["mediaType"] = memoryType.rawValue as CKRecordValue
            record["asset"] = CKAsset(fileURL: mediaURL)

            // Calculate and store file size
            if let fileSize = try? FileManager.default.attributesOfItem(atPath: mediaURL.path)[.size] as? Int64 {
                record["fileSize"] = fileSize as CKRecordValue
            }

            // Calculate checksum for integrity
            if let data = try? Data(contentsOf: mediaURL) {
                let checksum = data.md5Hash
                record["checksum"] = checksum as CKRecordValue
            }

            record["originalFilename"] = mediaPath as CKRecordValue

            // Upload to CloudKit with progress tracking
            let savedRecord = try await uploadRecord(record, for: memory)

            // Update memory with cloud record reference
            await updateMemoryWithCloudRecord(memory: memory, recordName: savedRecord.recordID.recordName)

            // Also upload thumbnail if exists
            if let thumbnailPath = memory.thumbnailPath {
                await uploadThumbnail(for: memory, thumbnailPath: thumbnailPath)
            }

            await updateSyncStatus(for: memory, status: .synced)
            await updatePendingCount()

        } catch {
            await handleUploadError(error, for: memory)
        }

        await MainActor.run {
            isUploading = pendingUploads > 0
        }
    }

    /// Upload thumbnail as CKAsset
    private func uploadThumbnail(for memory: Memory, thumbnailPath: String) async {
        let thumbnailURL = mediaManager.thumbnailURL(filename: thumbnailPath)

        guard FileManager.default.fileExists(atPath: thumbnailURL.path) else { return }

        do {
            let recordID = CKRecord.ID(recordName: UUID().uuidString)
            let record = CKRecord(recordType: Self.thumbnailAssetRecordType, recordID: recordID)

            record["memoryID"] = memory.id?.uuidString as CKRecordValue?
            record["asset"] = CKAsset(fileURL: thumbnailURL)
            record["originalFilename"] = thumbnailPath as CKRecordValue

            let savedRecord = try await privateDatabase.save(record)

            await updateMemoryWithThumbnailRecord(memory: memory, recordName: savedRecord.recordID.recordName)

        } catch {
            // Thumbnail upload failure is non-critical
            print("Failed to upload thumbnail: \(error)")
        }
    }

    /// Upload a CKRecord with progress tracking
    private func uploadRecord(_ record: CKRecord, for memory: Memory) async throws -> CKRecord {
        return try await withCheckedThrowingContinuation { continuation in
            let operation = CKModifyRecordsOperation(recordsToSave: [record], recordIDsToDelete: nil)

            operation.perRecordProgressBlock = { [weak self] _, progress in
                Task { @MainActor in
                    self?.currentUploadProgress = progress
                    // Update memory's upload progress
                    await self?.updateUploadProgress(for: memory, progress: progress)
                }
            }

            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    // Get the saved record from the operation
                    continuation.resume(returning: record)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            operation.qualityOfService = .userInitiated
            privateDatabase.add(operation)
        }
    }

    // MARK: - Download Operations

    /// Download media for a memory if not locally available
    func downloadMediaIfNeeded(for memory: Memory) async throws -> URL? {
        guard memory.needsMediaDownload else {
            return memory.mediaURL
        }

        guard let cloudRecordName = memory.cloudAssetRecordName else {
            return nil
        }

        await updateSyncStatus(for: memory, status: .downloading)

        await MainActor.run {
            isDownloading = true
        }

        do {
            let recordID = CKRecord.ID(recordName: cloudRecordName)
            let record = try await privateDatabase.record(for: recordID)

            guard let asset = record["asset"] as? CKAsset,
                  let assetURL = asset.fileURL else {
                throw MediaSyncError.assetNotFound
            }

            // Copy asset to local storage
            let filename = record["originalFilename"] as? String ?? "\(UUID().uuidString).\(memory.memoryType.fileExtension)"
            let localURL = mediaManager.mediaURL(filename: filename, type: memory.memoryType)

            try FileManager.default.copyItem(at: assetURL, to: localURL)

            // Update memory with local path
            await updateMemoryWithLocalPath(memory: memory, path: filename)
            await updateSyncStatus(for: memory, status: .synced)

            await MainActor.run {
                isDownloading = false
            }

            return localURL

        } catch {
            await updateSyncStatus(for: memory, status: .failed, error: error.localizedDescription)
            await MainActor.run {
                isDownloading = false
            }
            throw error
        }
    }

    /// Download thumbnail if not locally available
    func downloadThumbnailIfNeeded(for memory: Memory) async throws -> URL? {
        guard memory.needsThumbnailDownload else {
            return memory.thumbnailURL
        }

        guard let cloudRecordName = memory.cloudThumbnailRecordName else {
            return nil
        }

        do {
            let recordID = CKRecord.ID(recordName: cloudRecordName)
            let record = try await privateDatabase.record(for: recordID)

            guard let asset = record["asset"] as? CKAsset,
                  let assetURL = asset.fileURL else {
                throw MediaSyncError.assetNotFound
            }

            let filename = record["originalFilename"] as? String ?? "\(UUID().uuidString)_thumb.jpg"
            let localURL = mediaManager.thumbnailURL(filename: filename)

            try FileManager.default.copyItem(at: assetURL, to: localURL)

            // Update memory with local thumbnail path
            await updateMemoryWithThumbnailPath(memory: memory, path: filename)

            return localURL

        } catch {
            print("Failed to download thumbnail: \(error)")
            throw error
        }
    }

    // MARK: - Retry Logic

    /// Retry all failed uploads
    func retryFailedUploads() async {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let fetchRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "mediaSyncStatus == %@ OR mediaSyncStatus == %@",
                MediaSyncStatus.failed.rawValue,
                MediaSyncStatus.pending.rawValue
            )

            do {
                let memories = try context.fetch(fetchRequest)

                for memory in memories {
                    Task {
                        await self.uploadMedia(for: memory)
                    }
                }
            } catch {
                print("Failed to fetch memories for retry: \(error)")
            }
        }
    }

    // MARK: - Sync Status Updates

    /// Check sync status and update pending counts
    func checkSyncStatus() async {
        await updatePendingCount()
    }

    /// Get memories needing upload
    func memoriesNeedingUpload() -> [Memory] {
        let context = persistenceController.viewContext
        let fetchRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
        fetchRequest.predicate = NSPredicate(
            format: "cloudAssetRecordName == nil AND mediaPath != nil AND mediaSyncStatus != %@",
            MediaSyncStatus.localOnly.rawValue
        )

        do {
            return try context.fetch(fetchRequest)
        } catch {
            print("Failed to fetch memories needing upload: \(error)")
            return []
        }
    }

    // MARK: - Cleanup Operations

    /// Delete cloud assets for a memory
    func deleteCloudAssets(for memory: Memory) async throws {
        var recordIDsToDelete: [CKRecord.ID] = []

        if let mediaRecordName = memory.cloudAssetRecordName {
            recordIDsToDelete.append(CKRecord.ID(recordName: mediaRecordName))
        }

        if let thumbnailRecordName = memory.cloudThumbnailRecordName {
            recordIDsToDelete.append(CKRecord.ID(recordName: thumbnailRecordName))
        }

        guard !recordIDsToDelete.isEmpty else { return }

        let operation = CKModifyRecordsOperation(recordsToSave: nil, recordIDsToDelete: recordIDsToDelete)

        return try await withCheckedThrowingContinuation { continuation in
            operation.modifyRecordsResultBlock = { result in
                switch result {
                case .success:
                    continuation.resume()
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            privateDatabase.add(operation)
        }
    }

    // MARK: - Private Helpers

    private func updateSyncStatus(for memory: Memory, status: MediaSyncStatus, error: String? = nil) async {
        let context = persistenceController.viewContext

        await context.perform {
            memory.syncStatus = status
            memory.lastSyncAttempt = Date()
            if let error = error {
                memory.syncErrorMessage = error
            }
            try? context.save()
        }
    }

    private func updateUploadProgress(for memory: Memory, progress: Double) async {
        let context = persistenceController.viewContext

        await context.perform {
            memory.uploadProgress = progress
            try? context.save()
        }
    }

    private func updateMemoryWithCloudRecord(memory: Memory, recordName: String) async {
        let context = persistenceController.viewContext

        await context.perform {
            memory.cloudAssetRecordName = recordName
            try? context.save()
        }
    }

    private func updateMemoryWithThumbnailRecord(memory: Memory, recordName: String) async {
        let context = persistenceController.viewContext

        await context.perform {
            memory.cloudThumbnailRecordName = recordName
            memory.thumbnailSyncStatusValue = .synced
            try? context.save()
        }
    }

    private func updateMemoryWithLocalPath(memory: Memory, path: String) async {
        let context = persistenceController.viewContext

        await context.perform {
            memory.mediaPath = path
            try? context.save()
        }
    }

    private func updateMemoryWithThumbnailPath(memory: Memory, path: String) async {
        let context = persistenceController.viewContext

        await context.perform {
            memory.thumbnailPath = path
            try? context.save()
        }
    }

    private func updatePendingCount() async {
        let context = persistenceController.newBackgroundContext()

        await context.perform {
            let fetchRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
            fetchRequest.predicate = NSPredicate(
                format: "(mediaSyncStatus == %@ OR mediaSyncStatus == %@) AND mediaPath != nil",
                MediaSyncStatus.pending.rawValue,
                MediaSyncStatus.failed.rawValue
            )

            do {
                let count = try context.count(for: fetchRequest)
                Task { @MainActor in
                    self.pendingUploads = count
                }
            } catch {
                print("Failed to count pending uploads: \(error)")
            }
        }
    }

    private func handleUploadError(_ error: Error, for memory: Memory) async {
        if let ckError = error as? CKError {
            switch ckError.code {
            case .networkUnavailable, .networkFailure:
                // Keep as pending for automatic retry
                await updateSyncStatus(for: memory, status: .pending, error: "Network unavailable")
            case .quotaExceeded:
                await updateSyncStatus(for: memory, status: .failed, error: "iCloud storage full")
            case .serverRecordChanged:
                // Conflict - may need manual resolution
                await updateSyncStatus(for: memory, status: .failed, error: "Sync conflict")
            default:
                await updateSyncStatus(for: memory, status: .failed, error: ckError.localizedDescription)
            }
        } else {
            await updateSyncStatus(for: memory, status: .failed, error: error.localizedDescription)
        }

        await MainActor.run {
            syncError = error
        }
    }

    /// Cancel all pending operations
    func cancelPendingOperations() {
        uploadQueue.cancelAllOperations()
        downloadQueue.cancelAllOperations()
    }
}

// MARK: - MediaSyncError

enum MediaSyncError: LocalizedError {
    case assetNotFound
    case localFileNotFound
    case uploadFailed(String)
    case downloadFailed(String)
    case networkUnavailable

    var errorDescription: String? {
        switch self {
        case .assetNotFound:
            return "Media asset not found in CloudKit"
        case .localFileNotFound:
            return "Local media file not found"
        case .uploadFailed(let reason):
            return "Upload failed: \(reason)"
        case .downloadFailed(let reason):
            return "Download failed: \(reason)"
        case .networkUnavailable:
            return "Network is not available"
        }
    }
}

// MARK: - MemoryType Extension

extension MemoryType {
    var fileExtension: String {
        switch self {
        case .photo: return "jpg"
        case .video: return "mov"
        case .audio: return "m4a"
        case .text: return "txt"
        }
    }
}

// MARK: - Data Extension for MD5

extension Data {
    var md5Hash: String {
        // Simple hash using Swift's built-in hasher
        // In production, use CryptoKit for proper MD5
        var hasher = Hasher()
        hasher.combine(self)
        let hash = hasher.finalize()
        return String(format: "%08x", hash)
    }
}
