import Foundation
import CoreData

/// Event represents a calendar event like a birthday, milestone, or custom event.
/// This entity is designed for CloudKit compatibility with optional properties.
@objc(Event)
public class Event: NSManagedObject {

    // MARK: - Convenience Accessors

    var eventTypeValue: EventType {
        get {
            EventType(rawValue: eventType ?? "") ?? .custom
        }
        set {
            eventType = newValue.rawValue
        }
    }

    var reminderOffsetValue: ReminderOffset? {
        get {
            guard let offset = reminderOffset else { return nil }
            return ReminderOffset(rawValue: offset)
        }
        set {
            reminderOffset = newValue?.rawValue
        }
    }

    // MARK: - Computed Properties

    /// Linked memories as an array
    var linkedMemoriesArray: [Memory] {
        let set = linkedMemories as? Set<Memory> ?? []
        return Array(set).sorted { ($0.captureDate ?? Date.distantPast) > ($1.captureDate ?? Date.distantPast) }
    }

    /// Number of linked memories
    var linkedMemoryCount: Int {
        linkedMemories?.count ?? 0
    }

    /// Check if event is today
    var isToday: Bool {
        guard let date = date else { return false }
        return Calendar.current.isDateInToday(date)
    }

    /// Check if event is in the past
    var isPast: Bool {
        guard let date = date else { return false }
        return date < Date() && !isToday
    }

    /// Check if event is upcoming (within next 7 days)
    var isUpcoming: Bool {
        guard let date = date else { return false }
        let now = Date()
        let sevenDaysFromNow = Calendar.current.date(byAdding: .day, value: 7, to: now)!
        return date > now && date <= sevenDaysFromNow
    }

    /// Days until event
    var daysUntil: Int? {
        guard let date = date else { return nil }
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: calendar.startOfDay(for: Date()), to: calendar.startOfDay(for: date))
        return components.day
    }

    /// Formatted date string
    var formattedDate: String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        if !isAllDay {
            formatter.timeStyle = .short
        }
        return formatter.string(from: date)
    }

    /// Short formatted date string
    var shortFormattedDate: String {
        guard let date = date else { return "" }
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    /// Reminder date based on offset
    var reminderDate: Date? {
        guard let eventDate = date, let offset = reminderOffsetValue else { return nil }
        return Calendar.current.date(byAdding: .day, value: -offset.days, to: eventDate)
    }
}

// MARK: - Core Data Properties Extension

extension Event {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<Event> {
        return NSFetchRequest<Event>(entityName: "Event")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var date: Date?
    @NSManaged public var isAllDay: Bool
    @NSManaged public var notes: String?
    @NSManaged public var eventType: String?
    @NSManaged public var reminderOffset: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var lovedOne: LovedOne?
    @NSManaged public var linkedMemories: NSSet?
}

// MARK: - Generated Accessors for LinkedMemories

extension Event {
    @objc(addLinkedMemoriesObject:)
    @NSManaged public func addToLinkedMemories(_ value: Memory)

    @objc(removeLinkedMemoriesObject:)
    @NSManaged public func removeFromLinkedMemories(_ value: Memory)

    @objc(addLinkedMemories:)
    @NSManaged public func addToLinkedMemories(_ values: NSSet)

    @objc(removeLinkedMemories:)
    @NSManaged public func removeFromLinkedMemories(_ values: NSSet)
}

extension Event: Identifiable { }
