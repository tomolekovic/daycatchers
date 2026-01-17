import Foundation
import CoreData

/// LovedOne represents a person or pet being tracked in Daycatcher.
/// This entity is designed for CloudKit compatibility with optional properties.
@objc(LovedOne)
public class LovedOne: NSManagedObject {

    // MARK: - Convenience Accessors

    var relationshipType: RelationshipType {
        get {
            RelationshipType(rawValue: relationship ?? "") ?? .other
        }
        set {
            relationship = newValue.rawValue
        }
    }

    var genderType: Gender? {
        get {
            guard let gender = gender else { return nil }
            return Gender(rawValue: gender)
        }
        set {
            gender = newValue?.rawValue
        }
    }

    // MARK: - Computed Properties

    /// Calculate age based on birth date
    var age: Int? {
        guard let birthDate = birthDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year], from: birthDate, to: Date())
        return components.year
    }

    /// Calculate age in months (useful for babies)
    var ageInMonths: Int? {
        guard let birthDate = birthDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.month], from: birthDate, to: Date())
        return components.month
    }

    /// Get age stage for auto-tagging
    var ageStage: AgeStage? {
        guard let months = ageInMonths else { return nil }
        return AgeStage.stage(forAgeInMonths: months)
    }

    /// Formatted age string (e.g., "3 years" or "8 months")
    var formattedAge: String? {
        guard let birthDate = birthDate else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month], from: birthDate, to: Date())

        if let years = components.year, years >= 1 {
            return years == 1 ? "1 year" : "\(years) years"
        } else if let months = components.month {
            return months == 1 ? "1 month" : "\(months) months"
        }
        return nil
    }

    /// Memory count for this loved one
    var memoryCount: Int {
        memories?.count ?? 0
    }

    /// Event count for this loved one
    var eventCount: Int {
        events?.count ?? 0
    }

    // MARK: - Profile Image

    /// Get the profile image URL if it exists
    var profileImageURL: URL? {
        guard let path = profileImagePath else { return nil }
        return MediaManager.shared.profileImageURL(filename: path)
    }
}

// MARK: - Core Data Properties Extension

extension LovedOne {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<LovedOne> {
        return NSFetchRequest<LovedOne>(entityName: "LovedOne")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var birthDate: Date?
    @NSManaged public var relationship: String?
    @NSManaged public var gender: String?
    @NSManaged public var profileImagePath: String?
    @NSManaged public var isSharedWithFamily: Bool
    @NSManaged public var createdAt: Date?
    @NSManaged public var memories: NSSet?
    @NSManaged public var events: NSSet?
}

// MARK: - Generated Accessors for Memories

extension LovedOne {
    @objc(addMemoriesObject:)
    @NSManaged public func addToMemories(_ value: Memory)

    @objc(removeMemoriesObject:)
    @NSManaged public func removeFromMemories(_ value: Memory)

    @objc(addMemories:)
    @NSManaged public func addToMemories(_ values: NSSet)

    @objc(removeMemories:)
    @NSManaged public func removeFromMemories(_ values: NSSet)
}

// MARK: - Generated Accessors for Events

extension LovedOne {
    @objc(addEventsObject:)
    @NSManaged public func addToEvents(_ value: Event)

    @objc(removeEventsObject:)
    @NSManaged public func removeFromEvents(_ value: Event)

    @objc(addEvents:)
    @NSManaged public func addToEvents(_ values: NSSet)

    @objc(removeEvents:)
    @NSManaged public func removeFromEvents(_ values: NSSet)
}

extension LovedOne: Identifiable { }
