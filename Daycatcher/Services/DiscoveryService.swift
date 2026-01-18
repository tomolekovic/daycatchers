import Foundation
import CoreData

/// Service for discovering and surfacing memories in interesting ways
class DiscoveryService {
    static let shared = DiscoveryService()

    private let calendar = Calendar.current

    private init() {}

    // MARK: - On This Day

    /// Returns memories from the same date (month and day) in previous years
    /// - Parameters:
    ///   - context: The managed object context
    ///   - date: The reference date (defaults to today)
    /// - Returns: Array of memories from this day in previous years, grouped by year
    func onThisDay(in context: NSManagedObjectContext, date: Date = Date()) -> [(year: Int, memories: [Memory])] {
        let components = calendar.dateComponents([.month, .day], from: date)
        guard let month = components.month, let day = components.day else { return [] }

        let request: NSFetchRequest<Memory> = Memory.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.captureDate, ascending: false)]

        guard let allMemories = try? context.fetch(request) else { return [] }

        // Filter memories from the same month and day
        let matchingMemories = allMemories.filter { memory in
            guard let captureDate = memory.captureDate else { return false }
            let memoryComponents = calendar.dateComponents([.month, .day, .year], from: captureDate)
            let currentYear = calendar.component(.year, from: date)

            return memoryComponents.month == month &&
                   memoryComponents.day == day &&
                   memoryComponents.year != currentYear
        }

        // Group by year
        let grouped = Dictionary(grouping: matchingMemories) { memory -> Int in
            guard let captureDate = memory.captureDate else { return 0 }
            return calendar.component(.year, from: captureDate)
        }

        return grouped.map { (year: $0.key, memories: $0.value) }
            .sorted { $0.year > $1.year }
    }

    /// Returns the total count of "On This Day" memories
    func onThisDayCount(in context: NSManagedObjectContext, date: Date = Date()) -> Int {
        onThisDay(in: context, date: date).reduce(0) { $0 + $1.memories.count }
    }

    // MARK: - Random Memory (Rediscover)

    /// Returns a random memory for rediscovery
    /// - Parameters:
    ///   - context: The managed object context
    ///   - excluding: Optional memory ID to exclude (e.g., currently shown)
    /// - Returns: A random memory, or nil if none exist
    func randomMemory(in context: NSManagedObjectContext, excluding excludedId: UUID? = nil) -> Memory? {
        let request: NSFetchRequest<Memory> = Memory.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.captureDate, ascending: false)]

        guard var allMemories = try? context.fetch(request), !allMemories.isEmpty else {
            return nil
        }

        // Exclude specified memory
        if let excludedId = excludedId {
            allMemories = allMemories.filter { $0.id != excludedId }
        }

        guard !allMemories.isEmpty else { return nil }

        // Pick a random memory
        let randomIndex = Int.random(in: 0..<allMemories.count)
        return allMemories[randomIndex]
    }

    /// Returns a random memory from at least a specified number of days ago
    /// - Parameters:
    ///   - context: The managed object context
    ///   - minimumDaysAgo: Minimum age of memory in days (default 30)
    ///   - excluding: Optional memory ID to exclude
    /// - Returns: A random old memory, or nil if none qualify
    func rediscoverMemory(in context: NSManagedObjectContext, minimumDaysAgo: Int = 30, excluding excludedId: UUID? = nil) -> Memory? {
        let request: NSFetchRequest<Memory> = Memory.fetchRequest()

        // Calculate the cutoff date
        let cutoffDate = calendar.date(byAdding: .day, value: -minimumDaysAgo, to: Date()) ?? Date()
        request.predicate = NSPredicate(format: "captureDate < %@", cutoffDate as NSDate)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.captureDate, ascending: false)]

        guard var memories = try? context.fetch(request), !memories.isEmpty else {
            // Fall back to any random memory if no old memories exist
            return randomMemory(in: context, excluding: excludedId)
        }

        // Exclude specified memory
        if let excludedId = excludedId {
            memories = memories.filter { $0.id != excludedId }
        }

        guard !memories.isEmpty else { return nil }

        let randomIndex = Int.random(in: 0..<memories.count)
        return memories[randomIndex]
    }

    // MARK: - Seasonal Memories

    /// Returns memories from a specific season
    /// - Parameters:
    ///   - season: The season to filter by
    ///   - context: The managed object context
    /// - Returns: Array of memories from that season, sorted by date
    func memoriesFromSeason(_ season: Season, in context: NSManagedObjectContext) -> [Memory] {
        let request: NSFetchRequest<Memory> = Memory.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.captureDate, ascending: false)]

        guard let allMemories = try? context.fetch(request) else { return [] }

        return allMemories.filter { memory in
            guard let captureDate = memory.captureDate else { return false }
            return Season.season(for: captureDate) == season
        }
    }

    /// Returns memories from the current season in previous years
    func memoriesFromCurrentSeasonPreviousYears(in context: NSManagedObjectContext) -> [(year: Int, memories: [Memory])] {
        let currentSeason = Season.season(for: Date())
        let currentYear = calendar.component(.year, from: Date())

        let seasonMemories = memoriesFromSeason(currentSeason, in: context)

        // Filter to previous years only
        let previousYearMemories = seasonMemories.filter { memory in
            guard let captureDate = memory.captureDate else { return false }
            return calendar.component(.year, from: captureDate) != currentYear
        }

        // Group by year
        let grouped = Dictionary(grouping: previousYearMemories) { memory -> Int in
            guard let captureDate = memory.captureDate else { return 0 }
            return calendar.component(.year, from: captureDate)
        }

        return grouped.map { (year: $0.key, memories: $0.value) }
            .sorted { $0.year > $1.year }
    }

    // MARK: - Memory Stats

    /// Returns the date of the oldest memory
    func oldestMemoryDate(in context: NSManagedObjectContext) -> Date? {
        let request: NSFetchRequest<Memory> = Memory.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.captureDate, ascending: true)]
        request.fetchLimit = 1

        return try? context.fetch(request).first?.captureDate
    }

    /// Returns the total number of memories
    func totalMemoryCount(in context: NSManagedObjectContext) -> Int {
        let request: NSFetchRequest<Memory> = Memory.fetchRequest()
        return (try? context.count(for: request)) ?? 0
    }

    /// Returns the time span description (e.g., "2 years of memories")
    func memoryTimeSpan(in context: NSManagedObjectContext) -> String? {
        guard let oldest = oldestMemoryDate(in: context) else { return nil }

        let components = calendar.dateComponents([.year, .month], from: oldest, to: Date())

        if let years = components.year, years > 0 {
            return years == 1 ? "1 year of memories" : "\(years) years of memories"
        } else if let months = components.month, months > 0 {
            return months == 1 ? "1 month of memories" : "\(months) months of memories"
        } else {
            return "Just getting started"
        }
    }
}
