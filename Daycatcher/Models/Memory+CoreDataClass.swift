import Foundation
import CoreData
import CoreLocation

/// Memory represents a captured moment - photo, video, audio, or text note.
/// This entity is designed for CloudKit compatibility with optional properties.
@objc(Memory)
public class Memory: NSManagedObject {

    // MARK: - Convenience Accessors

    var memoryType: MemoryType {
        get {
            MemoryType(rawValue: type ?? "") ?? .text
        }
        set {
            type = newValue.rawValue
        }
    }

    // MARK: - Computed Properties

    /// Get location as CLLocationCoordinate2D if available
    var coordinate: CLLocationCoordinate2D? {
        guard latitude != 0, longitude != 0 else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }

    /// Set location from CLLocationCoordinate2D
    func setLocation(_ coordinate: CLLocationCoordinate2D?) {
        if let coordinate = coordinate {
            latitude = coordinate.latitude
            longitude = coordinate.longitude
        } else {
            latitude = 0
            longitude = 0
        }
    }

    /// Get the media file URL if it exists
    var mediaURL: URL? {
        guard let path = mediaPath else { return nil }
        return MediaManager.shared.mediaURL(filename: path, type: memoryType)
    }

    /// Get the thumbnail URL if it exists
    var thumbnailURL: URL? {
        guard let path = thumbnailPath else { return nil }
        return MediaManager.shared.thumbnailURL(filename: path)
    }

    /// Tags as an array
    var tagsArray: [Tag] {
        let set = tags as? Set<Tag> ?? []
        return Array(set)
    }

    /// Check if memory has media
    var hasMedia: Bool {
        mediaPath != nil
    }

    /// Formatted capture date
    var formattedDate: String {
        guard let date = captureDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    /// Season when memory was captured
    var season: Season? {
        guard let date = captureDate else { return nil }
        return Season.season(for: date)
    }

    // MARK: - Sync Status

    /// Get/set the media sync status as an enum
    var syncStatus: MediaSyncStatus {
        get {
            MediaSyncStatus(rawValue: mediaSyncStatus ?? "") ?? .pending
        }
        set {
            mediaSyncStatus = newValue.rawValue
        }
    }

    /// Get/set the thumbnail sync status as an enum
    var thumbnailSyncStatusValue: MediaSyncStatus {
        get {
            MediaSyncStatus(rawValue: thumbnailSyncStatus ?? "") ?? .pending
        }
        set {
            thumbnailSyncStatus = newValue.rawValue
        }
    }

    /// Check if media file is available locally
    var isMediaAvailableLocally: Bool {
        guard let path = mediaPath else { return memoryType == .text }
        let url = MediaManager.shared.mediaURL(filename: path, type: memoryType)
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Check if thumbnail is available locally
    var isThumbnailAvailableLocally: Bool {
        guard let path = thumbnailPath else { return true }
        let url = MediaManager.shared.thumbnailURL(filename: path)
        return FileManager.default.fileExists(atPath: url.path)
    }

    /// Check if media needs to be downloaded from CloudKit
    var needsMediaDownload: Bool {
        !isMediaAvailableLocally && cloudAssetRecordName != nil
    }

    /// Check if thumbnail needs to be downloaded from CloudKit
    var needsThumbnailDownload: Bool {
        !isThumbnailAvailableLocally && cloudThumbnailRecordName != nil
    }

    /// Check if media needs to be uploaded to CloudKit
    var needsMediaUpload: Bool {
        isMediaAvailableLocally && cloudAssetRecordName == nil && syncStatus != .localOnly
    }

    /// Whether any sync operation is in progress
    var isSyncing: Bool {
        syncStatus.isInProgress || thumbnailSyncStatusValue.isInProgress
    }
}

// MARK: - Core Data Properties Extension

extension Memory {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Memory> {
        return NSFetchRequest<Memory>(entityName: "Memory")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var type: String?
    @NSManaged public var title: String?
    @NSManaged public var notes: String?
    @NSManaged public var mediaPath: String?
    @NSManaged public var thumbnailPath: String?
    @NSManaged public var captureDate: Date?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var locationName: String?
    @NSManaged public var extractedText: String?
    @NSManaged public var transcription: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var lovedOne: LovedOne?
    @NSManaged public var linkedEvent: Event?
    @NSManaged public var tags: NSSet?

    // MARK: - Sync Properties
    @NSManaged public var mediaSyncStatus: String?
    @NSManaged public var thumbnailSyncStatus: String?
    @NSManaged public var thumbnailData: Data?  // Stored in Core Data with external storage for CloudKit sync
    @NSManaged public var cloudAssetRecordName: String?
    @NSManaged public var cloudThumbnailRecordName: String?
    @NSManaged public var lastSyncAttempt: Date?
    @NSManaged public var syncErrorMessage: String?
    @NSManaged public var mediaFileSize: Int64
    @NSManaged public var uploadProgress: Double
}

// MARK: - Generated Accessors for Tags

extension Memory {
    @objc(addTagsObject:)
    @NSManaged public func addToTags(_ value: Tag)

    @objc(removeTagsObject:)
    @NSManaged public func removeFromTags(_ value: Tag)

    @objc(addTags:)
    @NSManaged public func addToTags(_ values: NSSet)

    @objc(removeTags:)
    @NSManaged public func removeFromTags(_ values: NSSet)
}

extension Memory: Identifiable { }

// MARK: - Safe Accessibility Check

extension Memory {
    /// Check if this Memory object is accessible and its data can be read.
    /// Returns false for faults that cannot be fulfilled (e.g., deleted by CloudKit sync).
    ///
    /// This check handles the case where CloudKit syncs a deletion from another device.
    /// When that happens, the managed object still exists in memory (as a fault), but
    /// attempting to access its properties throws an NSObjectInaccessibleException
    /// which Swift CANNOT catch. We use ObjCExceptionCatcher to safely verify the
    /// fault can be fulfilled before accessing properties.
    var isAccessible: Bool {
        // First check if we have a context - this is safe and doesn't trigger fault fulfillment
        guard let context = managedObjectContext else { return false }

        // Check if the object ID has a valid persistent store
        // This is safe to access and doesn't trigger fault fulfillment
        guard objectID.persistentStore != nil else { return false }

        // Temporary objects are always accessible
        if objectID.isTemporaryID { return true }

        // Use existingObject(with:) which throws a Swift-catchable error
        // instead of an ObjC exception when the object can't be faulted.
        // This is more reliable than ObjC @try/@catch for iOS 18+
        do {
            let existingObject = try context.existingObject(with: objectID)
            // Verify it's not deleted and passes persistence checks
            guard !existingObject.isDeleted else { return false }
            guard PersistenceController.shared.isObjectAccessible(self) else { return false }
            return true
        } catch {
            // Object doesn't exist in store or fault couldn't be fulfilled
            return false
        }
    }
}
