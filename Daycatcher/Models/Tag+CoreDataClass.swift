import Foundation
import CoreData

/// Tag represents a label that can be applied to memories for organization.
/// Tags can be user-created or AI-generated.
@objc(Tag)
public class Tag: NSManagedObject {

    // MARK: - Computed Properties

    /// Number of memories with this tag
    var memoryCount: Int {
        memories?.count ?? 0
    }

    /// Memories as an array
    var memoriesArray: [Memory] {
        let set = memories as? Set<Memory> ?? []
        return Array(set).sorted { ($0.captureDate ?? Date.distantPast) > ($1.captureDate ?? Date.distantPast) }
    }
}

// MARK: - Core Data Properties Extension

extension Tag {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Tag> {
        return NSFetchRequest<Tag>(entityName: "Tag")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var isAIGenerated: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var memories: NSSet?
}

// MARK: - Generated Accessors for Memories

extension Tag {
    @objc(addMemoriesObject:)
    @NSManaged public func addToMemories(_ value: Memory)

    @objc(removeMemoriesObject:)
    @NSManaged public func removeFromMemories(_ value: Memory)

    @objc(addMemories:)
    @NSManaged public func addToMemories(_ values: NSSet)

    @objc(removeMemories:)
    @NSManaged public func removeFromMemories(_ values: NSSet)
}

extension Tag: Identifiable { }

// MARK: - Tag Helpers

extension Tag {
    /// Find or create a tag with the given name
    static func findOrCreate(name: String, isAIGenerated: Bool = false, in context: NSManagedObjectContext) -> Tag {
        let request: NSFetchRequest<Tag> = Tag.fetchRequest()
        request.predicate = NSPredicate(format: "name ==[c] %@", name)
        request.fetchLimit = 1

        if let existing = try? context.fetch(request).first {
            return existing
        }

        let tag = Tag(context: context)
        tag.id = UUID()
        tag.name = name
        tag.isAIGenerated = isAIGenerated
        tag.createdAt = Date()

        return tag
    }
}
