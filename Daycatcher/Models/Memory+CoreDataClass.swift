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
