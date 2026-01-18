import Foundation
import CoreData

/// Service for generating and managing weekly memory digests
@MainActor
class DigestService: ObservableObject {
    static let shared = DigestService()

    @Published var isGenerating = false
    @Published var latestUnreadDigest: WeeklyDigest?

    private init() {}

    // MARK: - Digest Generation

    /// Check and generate digests for any weeks that don't have one
    func generateMissingDigests(in context: NSManagedObjectContext) async {
        isGenerating = true
        defer { isGenerating = false }

        // Get the range of weeks we have memories for
        let memoryWeeks = await getWeeksWithMemories(in: context)

        for weekStart in memoryWeeks {
            // Check if digest already exists for this week
            if await digestExists(for: weekStart, in: context) {
                continue
            }

            // Generate digest for this week
            await generateDigest(for: weekStart, in: context)
        }

        // Update latest unread digest
        await refreshLatestUnreadDigest(in: context)
    }

    /// Generate a digest for the previous week (call this weekly)
    func generateLastWeekDigest(in context: NSManagedObjectContext) async {
        let calendar = Calendar.current
        let now = Date()

        // Get start of current week
        guard let currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: now)),
              let lastWeekStart = calendar.date(byAdding: .weekOfYear, value: -1, to: currentWeekStart) else {
            return
        }

        // Check if we already have a digest for last week
        if await digestExists(for: lastWeekStart, in: context) {
            return
        }

        // Generate digest for last week
        await generateDigest(for: lastWeekStart, in: context)

        // Update latest unread
        await refreshLatestUnreadDigest(in: context)
    }

    /// Generate a digest for a specific week
    private func generateDigest(for weekStart: Date, in context: NSManagedObjectContext) async {
        let calendar = Calendar.current
        guard let weekEnd = calendar.date(byAdding: .day, value: 7, to: weekStart) else {
            return
        }

        // Fetch memories for this week
        let memories = await fetchMemories(from: weekStart, to: weekEnd, in: context)

        guard !memories.isEmpty else {
            return // Don't create digest if no memories
        }

        // Generate summary
        let summary = generateSummary(for: memories, weekStart: weekStart)

        // Select highlighted memories (most interesting ones)
        let highlightedIds = selectHighlightedMemories(from: memories)

        // Create digest record
        await context.perform {
            let digest = WeeklyDigest(context: context)
            digest.id = UUID()
            digest.weekStartDate = weekStart
            digest.summary = summary
            digest.highlightedMemoryIDsArray = highlightedIds
            digest.isRead = false
            digest.generatedAt = Date()

            do {
                try context.save()
            } catch {
                print("Error saving digest: \(error)")
            }
        }
    }

    // MARK: - Summary Generation

    /// Generate a summary text for the week's memories
    private func generateSummary(for memories: [Memory], weekStart: Date) -> String {
        let calendar = Calendar.current

        // Count by type
        let photoCount = memories.filter { $0.memoryType == .photo }.count
        let videoCount = memories.filter { $0.memoryType == .video }.count
        let audioCount = memories.filter { $0.memoryType == .audio }.count
        let textCount = memories.filter { $0.memoryType == .text }.count

        // Get unique loved ones
        let lovedOneNames = Set(memories.compactMap { $0.lovedOne?.name })

        // Get unique tags
        var allTags: Set<String> = []
        for memory in memories {
            for tag in memory.tagsArray {
                if let name = tag.name {
                    allTags.insert(name)
                }
            }
        }

        // Build summary
        var summaryParts: [String] = []

        // Opening with date range
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        let weekEndDisplay = calendar.date(byAdding: .day, value: 6, to: weekStart) ?? weekStart
        let dateRange = "\(formatter.string(from: weekStart)) - \(formatter.string(from: weekEndDisplay))"

        // Memory count summary
        var typeCounts: [String] = []
        if photoCount > 0 { typeCounts.append("\(photoCount) photo\(photoCount == 1 ? "" : "s")") }
        if videoCount > 0 { typeCounts.append("\(videoCount) video\(videoCount == 1 ? "" : "s")") }
        if audioCount > 0 { typeCounts.append("\(audioCount) audio note\(audioCount == 1 ? "" : "s")") }
        if textCount > 0 { typeCounts.append("\(textCount) text note\(textCount == 1 ? "" : "s")") }

        let totalCount = memories.count
        summaryParts.append("You captured \(totalCount) memor\(totalCount == 1 ? "y" : "ies") this week: \(typeCounts.joined(separator: ", ")).")

        // People mentioned
        if !lovedOneNames.isEmpty {
            let names = lovedOneNames.sorted().joined(separator: ", ")
            summaryParts.append("Featuring \(names).")
        }

        // Highlight interesting tags
        let interestingTags = allTags.filter { tag in
            let lowerTag = tag.lowercased()
            return ["birthday", "first", "milestone", "holiday", "vacation", "celebration", "funny", "sweet moment"].contains(lowerTag)
        }

        if !interestingTags.isEmpty {
            let tagList = interestingTags.prefix(3).joined(separator: ", ")
            summaryParts.append("Highlights include: \(tagList).")
        }

        // Add seasonal or activity context
        if allTags.contains("Outdoors") || allTags.contains("Park") || allTags.contains("Beach") {
            summaryParts.append("Looks like you enjoyed some outdoor time!")
        } else if allTags.contains("Home") || allTags.contains("Indoors") {
            summaryParts.append("A cozy week at home.")
        }

        return summaryParts.joined(separator: " ")
    }

    /// Select the most interesting memories to highlight
    private func selectHighlightedMemories(from memories: [Memory], maxCount: Int = 5) -> [UUID] {
        // Score each memory based on interestingness
        let scored = memories.compactMap { memory -> (Memory, Int)? in
            guard let id = memory.id else { return nil }

            var score = 0

            // Photos and videos are more visual
            if memory.memoryType == .photo { score += 3 }
            if memory.memoryType == .video { score += 4 }

            // Has thumbnail = better visual
            if memory.thumbnailPath != nil { score += 2 }

            // Has title = more intentional
            if memory.title != nil && !memory.title!.isEmpty { score += 1 }

            // Has notes = more context
            if memory.notes != nil && !memory.notes!.isEmpty { score += 1 }

            // Special tags boost score
            let specialTags = ["Birthday", "First", "Milestone", "Holiday", "Funny", "Sweet Moment"]
            for tag in memory.tagsArray {
                if let name = tag.name, specialTags.contains(name) {
                    score += 3
                }
            }

            return (memory, score)
        }

        // Sort by score descending, take top ones
        let sorted = scored.sorted { $0.1 > $1.1 }
        return sorted.prefix(maxCount).compactMap { $0.0.id }
    }

    // MARK: - Data Fetching

    /// Get all weeks that have memories
    private func getWeeksWithMemories(in context: NSManagedObjectContext) async -> [Date] {
        await context.perform {
            let request: NSFetchRequest<Memory> = Memory.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.captureDate, ascending: true)]

            guard let memories = try? context.fetch(request),
                  let earliest = memories.first?.captureDate,
                  let latest = memories.last?.captureDate else {
                return []
            }

            let calendar = Calendar.current
            var weeks: [Date] = []

            // Get start of earliest week
            guard var currentWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: earliest)) else {
                return []
            }

            // Get start of current week (don't include current week - it's not complete)
            guard let thisWeekStart = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())) else {
                return []
            }

            // Iterate through weeks up to (but not including) current week
            while currentWeekStart < thisWeekStart && currentWeekStart <= latest {
                weeks.append(currentWeekStart)
                guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: 1, to: currentWeekStart) else {
                    break
                }
                currentWeekStart = nextWeek
            }

            return weeks
        }
    }

    /// Check if a digest exists for a specific week
    private func digestExists(for weekStart: Date, in context: NSManagedObjectContext) async -> Bool {
        await context.perform {
            let request: NSFetchRequest<WeeklyDigest> = WeeklyDigest.fetchRequest()
            request.predicate = NSPredicate(format: "weekStartDate == %@", weekStart as NSDate)
            request.fetchLimit = 1

            let count = (try? context.count(for: request)) ?? 0
            return count > 0
        }
    }

    /// Fetch memories for a date range
    private func fetchMemories(from startDate: Date, to endDate: Date, in context: NSManagedObjectContext) async -> [Memory] {
        await context.perform {
            let request: NSFetchRequest<Memory> = Memory.fetchRequest()
            request.predicate = NSPredicate(
                format: "captureDate >= %@ AND captureDate < %@",
                startDate as NSDate,
                endDate as NSDate
            )
            request.sortDescriptors = [NSSortDescriptor(keyPath: \Memory.captureDate, ascending: true)]

            return (try? context.fetch(request)) ?? []
        }
    }

    // MARK: - Digest Access

    /// Refresh the latest unread digest
    func refreshLatestUnreadDigest(in context: NSManagedObjectContext) async {
        latestUnreadDigest = await context.perform {
            let request: NSFetchRequest<WeeklyDigest> = WeeklyDigest.fetchRequest()
            request.predicate = NSPredicate(format: "isRead == NO")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \WeeklyDigest.weekStartDate, ascending: false)]
            request.fetchLimit = 1

            return try? context.fetch(request).first
        }
    }

    /// Mark a digest as read
    func markAsRead(_ digest: WeeklyDigest, in context: NSManagedObjectContext) {
        digest.isRead = true
        do {
            try context.save()
        } catch {
            print("Error marking digest as read: \(error)")
        }

        // Update latest unread
        Task {
            await refreshLatestUnreadDigest(in: context)
        }
    }

    /// Get all digests sorted by date
    func fetchAllDigests(in context: NSManagedObjectContext) async -> [WeeklyDigest] {
        await context.perform {
            let request: NSFetchRequest<WeeklyDigest> = WeeklyDigest.fetchRequest()
            request.sortDescriptors = [NSSortDescriptor(keyPath: \WeeklyDigest.weekStartDate, ascending: false)]

            return (try? context.fetch(request)) ?? []
        }
    }

    /// Get highlighted memories for a digest
    func getHighlightedMemories(for digest: WeeklyDigest, in context: NSManagedObjectContext) async -> [Memory] {
        let ids = digest.highlightedMemoryIDsArray

        return await context.perform {
            let request: NSFetchRequest<Memory> = Memory.fetchRequest()
            request.predicate = NSPredicate(format: "id IN %@", ids)

            return (try? context.fetch(request)) ?? []
        }
    }

    /// Get all memories for a digest's week
    func getWeekMemories(for digest: WeeklyDigest, in context: NSManagedObjectContext) async -> [Memory] {
        guard let weekStart = digest.weekStartDate,
              let weekEnd = Calendar.current.date(byAdding: .day, value: 7, to: weekStart) else {
            return []
        }

        return await fetchMemories(from: weekStart, to: weekEnd, in: context)
    }

    /// Get count of unread digests
    func getUnreadCount(in context: NSManagedObjectContext) async -> Int {
        await context.perform {
            let request: NSFetchRequest<WeeklyDigest> = WeeklyDigest.fetchRequest()
            request.predicate = NSPredicate(format: "isRead == NO")

            return (try? context.count(for: request)) ?? 0
        }
    }
}
