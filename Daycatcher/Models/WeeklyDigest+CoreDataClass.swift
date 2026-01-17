import Foundation
import CoreData

/// WeeklyDigest represents an AI-generated summary of memories for a given week.
@objc(WeeklyDigest)
public class WeeklyDigest: NSManagedObject {

    // MARK: - Computed Properties

    /// Highlighted memory IDs as an array
    var highlightedMemoryIDsArray: [UUID] {
        get {
            guard let data = highlightedMemoryIDs,
                  let ids = try? JSONDecoder().decode([UUID].self, from: data) else {
                return []
            }
            return ids
        }
        set {
            highlightedMemoryIDs = try? JSONEncoder().encode(newValue)
        }
    }

    /// Week end date
    var weekEndDate: Date? {
        guard let start = weekStartDate else { return nil }
        return Calendar.current.date(byAdding: .day, value: 6, to: start)
    }

    /// Formatted week range string
    var formattedWeekRange: String {
        guard let start = weekStartDate, let end = weekEndDate else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let startString = formatter.string(from: start)
        let endString = formatter.string(from: end)

        return "\(startString) - \(endString)"
    }

    /// Check if this is the current week's digest
    var isCurrentWeek: Bool {
        guard let start = weekStartDate else { return false }
        let calendar = Calendar.current
        let now = Date()
        let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now))!
        return calendar.isDate(start, inSameDayAs: currentWeekStart)
    }
}

// MARK: - Core Data Properties Extension

extension WeeklyDigest {
    @nonobjc public class func fetchRequest() -> NSFetchRequest<WeeklyDigest> {
        return NSFetchRequest<WeeklyDigest>(entityName: "WeeklyDigest")
    }

    @NSManaged public var id: UUID?
    @NSManaged public var weekStartDate: Date?
    @NSManaged public var summary: String?
    @NSManaged public var highlightedMemoryIDs: Data?
    @NSManaged public var isRead: Bool
    @NSManaged public var generatedAt: Date?
}

extension WeeklyDigest: Identifiable { }
