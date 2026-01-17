import XCTest
import CoreData
@testable import Daycatcher

final class MediaSyncManagerTests: XCTestCase {

    var persistenceController: PersistenceController!
    var context: NSManagedObjectContext!

    override func setUpWithError() throws {
        // Use in-memory Core Data for testing
        persistenceController = PersistenceController(inMemory: true)
        context = persistenceController.viewContext
    }

    override func tearDownWithError() throws {
        context = nil
        persistenceController = nil
    }

    // MARK: - MediaSyncStatus Enum Tests

    func testMediaSyncStatusRawValues() {
        XCTAssertEqual(MediaSyncStatus.pending.rawValue, "pending")
        XCTAssertEqual(MediaSyncStatus.uploading.rawValue, "uploading")
        XCTAssertEqual(MediaSyncStatus.synced.rawValue, "synced")
        XCTAssertEqual(MediaSyncStatus.failed.rawValue, "failed")
        XCTAssertEqual(MediaSyncStatus.downloading.rawValue, "downloading")
        XCTAssertEqual(MediaSyncStatus.localOnly.rawValue, "local_only")
    }

    func testMediaSyncStatusDisplayNames() {
        XCTAssertEqual(MediaSyncStatus.pending.displayName, "Pending")
        XCTAssertEqual(MediaSyncStatus.uploading.displayName, "Uploading")
        XCTAssertEqual(MediaSyncStatus.synced.displayName, "Synced")
        XCTAssertEqual(MediaSyncStatus.failed.displayName, "Failed")
        XCTAssertEqual(MediaSyncStatus.downloading.displayName, "Downloading")
        XCTAssertEqual(MediaSyncStatus.localOnly.displayName, "Local Only")
    }

    func testMediaSyncStatusIcons() {
        XCTAssertEqual(MediaSyncStatus.pending.icon, "clock")
        XCTAssertEqual(MediaSyncStatus.uploading.icon, "arrow.up.circle")
        XCTAssertEqual(MediaSyncStatus.synced.icon, "checkmark.icloud")
        XCTAssertEqual(MediaSyncStatus.failed.icon, "exclamationmark.icloud")
        XCTAssertEqual(MediaSyncStatus.downloading.icon, "arrow.down.circle")
        XCTAssertEqual(MediaSyncStatus.localOnly.icon, "iphone")
    }

    func testMediaSyncStatusIsInProgress() {
        XCTAssertTrue(MediaSyncStatus.uploading.isInProgress)
        XCTAssertTrue(MediaSyncStatus.downloading.isInProgress)
        XCTAssertFalse(MediaSyncStatus.pending.isInProgress)
        XCTAssertFalse(MediaSyncStatus.synced.isInProgress)
        XCTAssertFalse(MediaSyncStatus.failed.isInProgress)
        XCTAssertFalse(MediaSyncStatus.localOnly.isInProgress)
    }

    func testMediaSyncStatusNeedsAction() {
        XCTAssertTrue(MediaSyncStatus.pending.needsAction)
        XCTAssertTrue(MediaSyncStatus.failed.needsAction)
        XCTAssertFalse(MediaSyncStatus.uploading.needsAction)
        XCTAssertFalse(MediaSyncStatus.synced.needsAction)
        XCTAssertFalse(MediaSyncStatus.downloading.needsAction)
        XCTAssertFalse(MediaSyncStatus.localOnly.needsAction)
    }

    func testMediaSyncStatusAllCases() {
        XCTAssertEqual(MediaSyncStatus.allCases.count, 6)
    }

    // MARK: - Memory Sync Status Property Tests

    func testMemorySyncStatusProperty() {
        let memory = Memory(context: context)
        memory.id = UUID()
        memory.type = MemoryType.photo.rawValue
        memory.createdAt = Date()

        // Test default
        XCTAssertEqual(memory.syncStatus, .pending)

        // Test setting via property
        memory.syncStatus = .uploading
        XCTAssertEqual(memory.syncStatus, .uploading)
        XCTAssertEqual(memory.mediaSyncStatus, "uploading")

        memory.syncStatus = .synced
        XCTAssertEqual(memory.syncStatus, .synced)
        XCTAssertEqual(memory.mediaSyncStatus, "synced")

        memory.syncStatus = .failed
        XCTAssertEqual(memory.syncStatus, .failed)
        XCTAssertEqual(memory.mediaSyncStatus, "failed")
    }

    func testMemoryThumbnailSyncStatusProperty() {
        let memory = Memory(context: context)
        memory.id = UUID()
        memory.type = MemoryType.photo.rawValue
        memory.createdAt = Date()

        // Test default
        XCTAssertEqual(memory.thumbnailSyncStatusValue, .pending)

        // Test setting via property
        memory.thumbnailSyncStatusValue = .synced
        XCTAssertEqual(memory.thumbnailSyncStatusValue, .synced)
        XCTAssertEqual(memory.thumbnailSyncStatus, "synced")
    }

    func testMemoryNeedsMediaUpload() {
        let memory = Memory(context: context)
        memory.id = UUID()
        memory.type = MemoryType.photo.rawValue
        memory.mediaPath = "test.jpg"
        memory.createdAt = Date()
        memory.mediaSyncStatus = MediaSyncStatus.pending.rawValue

        // Memory has path but no cloud record - needs upload
        // Note: This will return false because the file doesn't actually exist
        // In real usage, the file would exist locally
        XCTAssertFalse(memory.needsMediaUpload) // File doesn't exist locally

        // Once we have a cloud record, shouldn't need upload
        memory.cloudAssetRecordName = "some-record-id"
        XCTAssertFalse(memory.needsMediaUpload)
    }

    func testMemoryNeedsMediaDownload() {
        let memory = Memory(context: context)
        memory.id = UUID()
        memory.type = MemoryType.photo.rawValue
        memory.mediaPath = "test.jpg"
        memory.createdAt = Date()

        // No cloud record - doesn't need download
        XCTAssertFalse(memory.needsMediaDownload)

        // Has cloud record but file doesn't exist locally - needs download
        memory.cloudAssetRecordName = "some-record-id"
        XCTAssertTrue(memory.needsMediaDownload)
    }

    func testMemoryIsSyncing() {
        let memory = Memory(context: context)
        memory.id = UUID()
        memory.type = MemoryType.photo.rawValue
        memory.createdAt = Date()

        memory.mediaSyncStatus = MediaSyncStatus.pending.rawValue
        XCTAssertFalse(memory.isSyncing)

        memory.mediaSyncStatus = MediaSyncStatus.uploading.rawValue
        XCTAssertTrue(memory.isSyncing)

        memory.mediaSyncStatus = MediaSyncStatus.synced.rawValue
        XCTAssertFalse(memory.isSyncing)

        memory.mediaSyncStatus = MediaSyncStatus.downloading.rawValue
        XCTAssertTrue(memory.isSyncing)
    }

    // MARK: - LovedOne Sync Status Property Tests

    func testLovedOneProfileSyncStatus() {
        let lovedOne = LovedOne(context: context)
        lovedOne.id = UUID()
        lovedOne.name = "Test"
        lovedOne.createdAt = Date()

        // Test default
        XCTAssertEqual(lovedOne.profileSyncStatus, .pending)

        // Test setting
        lovedOne.profileSyncStatus = .synced
        XCTAssertEqual(lovedOne.profileSyncStatus, .synced)
        XCTAssertEqual(lovedOne.profileImageSyncStatus, "synced")
    }

    func testLovedOneNeedsProfileImageUpload() {
        let lovedOne = LovedOne(context: context)
        lovedOne.id = UUID()
        lovedOne.name = "Test"
        lovedOne.profileImagePath = "profile.jpg"
        lovedOne.createdAt = Date()

        // Has path but no cloud record - but file doesn't exist so false
        XCTAssertFalse(lovedOne.needsProfileImageUpload)

        // Once we have a cloud record, shouldn't need upload
        lovedOne.cloudProfileImageRecordName = "some-record-id"
        XCTAssertFalse(lovedOne.needsProfileImageUpload)
    }

    func testLovedOneNeedsProfileImageDownload() {
        let lovedOne = LovedOne(context: context)
        lovedOne.id = UUID()
        lovedOne.name = "Test"
        lovedOne.profileImagePath = "profile.jpg"
        lovedOne.createdAt = Date()

        // No cloud record - doesn't need download
        XCTAssertFalse(lovedOne.needsProfileImageDownload)

        // Has cloud record but file doesn't exist - needs download
        lovedOne.cloudProfileImageRecordName = "some-record-id"
        XCTAssertTrue(lovedOne.needsProfileImageDownload)
    }

    // MARK: - MemoryType Extension Tests

    func testMemoryTypeFileExtension() {
        XCTAssertEqual(MemoryType.photo.fileExtension, "jpg")
        XCTAssertEqual(MemoryType.video.fileExtension, "mov")
        XCTAssertEqual(MemoryType.audio.fileExtension, "m4a")
        XCTAssertEqual(MemoryType.text.fileExtension, "txt")
    }

    // MARK: - MediaSyncError Tests

    func testMediaSyncErrorDescriptions() {
        let assetNotFound = MediaSyncError.assetNotFound
        XCTAssertEqual(assetNotFound.errorDescription, "Media asset not found in CloudKit")

        let localNotFound = MediaSyncError.localFileNotFound
        XCTAssertEqual(localNotFound.errorDescription, "Local media file not found")

        let uploadFailed = MediaSyncError.uploadFailed("Network error")
        XCTAssertEqual(uploadFailed.errorDescription, "Upload failed: Network error")

        let downloadFailed = MediaSyncError.downloadFailed("Timeout")
        XCTAssertEqual(downloadFailed.errorDescription, "Download failed: Timeout")

        let networkUnavailable = MediaSyncError.networkUnavailable
        XCTAssertEqual(networkUnavailable.errorDescription, "Network is not available")
    }

    // MARK: - Data MD5 Extension Tests

    func testDataMD5Hash() {
        let data1 = "Hello, World!".data(using: .utf8)!
        let data2 = "Hello, World!".data(using: .utf8)!
        let data3 = "Different content".data(using: .utf8)!

        // Same data should produce same hash
        XCTAssertEqual(data1.md5Hash, data2.md5Hash)

        // Different data should produce different hash
        XCTAssertNotEqual(data1.md5Hash, data3.md5Hash)

        // Hash should be non-empty
        XCTAssertFalse(data1.md5Hash.isEmpty)
    }

    // MARK: - Core Data Sync Attribute Persistence Tests

    func testMemorySyncAttributesPersistence() throws {
        let memory = Memory(context: context)
        memory.id = UUID()
        memory.type = MemoryType.photo.rawValue
        memory.mediaPath = "test.jpg"
        memory.mediaSyncStatus = MediaSyncStatus.synced.rawValue
        memory.cloudAssetRecordName = "record-123"
        memory.lastSyncAttempt = Date()
        memory.mediaFileSize = 1024 * 1024 // 1 MB
        memory.uploadProgress = 0.75
        memory.createdAt = Date()

        try context.save()

        // Fetch and verify
        let fetchRequest: NSFetchRequest<Memory> = Memory.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", memory.id! as CVarArg)
        let results = try context.fetch(fetchRequest)

        XCTAssertEqual(results.count, 1)
        let fetchedMemory = results[0]
        XCTAssertEqual(fetchedMemory.mediaSyncStatus, "synced")
        XCTAssertEqual(fetchedMemory.cloudAssetRecordName, "record-123")
        XCTAssertEqual(fetchedMemory.mediaFileSize, 1024 * 1024)
        XCTAssertEqual(fetchedMemory.uploadProgress, 0.75)
        XCTAssertNotNil(fetchedMemory.lastSyncAttempt)
    }

    func testLovedOneSyncAttributesPersistence() throws {
        let lovedOne = LovedOne(context: context)
        lovedOne.id = UUID()
        lovedOne.name = "Test Person"
        lovedOne.profileImagePath = "profile.jpg"
        lovedOne.profileImageSyncStatus = MediaSyncStatus.synced.rawValue
        lovedOne.cloudProfileImageRecordName = "profile-record-456"
        lovedOne.createdAt = Date()

        try context.save()

        // Fetch and verify
        let fetchRequest: NSFetchRequest<LovedOne> = LovedOne.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", lovedOne.id! as CVarArg)
        let results = try context.fetch(fetchRequest)

        XCTAssertEqual(results.count, 1)
        let fetchedLovedOne = results[0]
        XCTAssertEqual(fetchedLovedOne.profileImageSyncStatus, "synced")
        XCTAssertEqual(fetchedLovedOne.cloudProfileImageRecordName, "profile-record-456")
    }
}
