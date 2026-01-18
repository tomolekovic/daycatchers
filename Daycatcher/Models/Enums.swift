import Foundation
import SwiftUI

// MARK: - Relationship Type

enum RelationshipType: String, CaseIterable, Identifiable {
    case child = "child"
    case partner = "partner"
    case parent = "parent"
    case grandparent = "grandparent"
    case sibling = "sibling"
    case friend = "friend"
    case pet = "pet"
    case other = "other"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .child: return "Child"
        case .partner: return "Partner"
        case .parent: return "Parent"
        case .grandparent: return "Grandparent"
        case .sibling: return "Sibling"
        case .friend: return "Friend"
        case .pet: return "Pet"
        case .other: return "Other"
        }
    }

    var icon: String {
        switch self {
        case .child: return "figure.child"
        case .partner: return "heart.fill"
        case .parent: return "figure.stand"
        case .grandparent: return "figure.stand.line.dotted.figure.stand"
        case .sibling: return "person.2.fill"
        case .friend: return "person.crop.circle.badge.checkmark"
        case .pet: return "pawprint.fill"
        case .other: return "star.fill"
        }
    }
}

// MARK: - Gender

enum Gender: String, CaseIterable, Identifiable {
    case male = "male"
    case female = "female"
    case other = "other"
    case preferNotToSay = "prefer_not_to_say"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .male: return "Male"
        case .female: return "Female"
        case .other: return "Other"
        case .preferNotToSay: return "Prefer not to say"
        }
    }
}

// MARK: - Memory Type

enum MemoryType: String, CaseIterable, Identifiable {
    case photo = "photo"
    case video = "video"
    case audio = "audio"
    case text = "text"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .photo: return "Photo"
        case .video: return "Video"
        case .audio: return "Audio"
        case .text: return "Note"
        }
    }

    var icon: String {
        switch self {
        case .photo: return "photo.fill"
        case .video: return "video.fill"
        case .audio: return "mic.fill"
        case .text: return "note.text"
        }
    }

    var color: Color {
        switch self {
        case .photo: return .blue
        case .video: return .purple
        case .audio: return .orange
        case .text: return .green
        }
    }
}

// MARK: - Event Type

enum EventType: String, CaseIterable, Identifiable {
    case birthday = "birthday"
    case anniversary = "anniversary"
    case milestone = "milestone"
    case custom = "custom"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .birthday: return "Birthday"
        case .anniversary: return "Anniversary"
        case .milestone: return "Milestone"
        case .custom: return "Custom"
        }
    }

    var icon: String {
        switch self {
        case .birthday: return "birthday.cake.fill"
        case .anniversary: return "heart.fill"
        case .milestone: return "star.fill"
        case .custom: return "calendar"
        }
    }
}

// MARK: - Reminder Offset

enum ReminderOffset: String, CaseIterable, Identifiable {
    case sameDay = "same_day"
    case oneDay = "one_day"
    case twoDays = "two_days"
    case threeDays = "three_days"
    case oneWeek = "one_week"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .sameDay: return "Same day"
        case .oneDay: return "1 day before"
        case .twoDays: return "2 days before"
        case .threeDays: return "3 days before"
        case .oneWeek: return "1 week before"
        }
    }

    var days: Int {
        switch self {
        case .sameDay: return 0
        case .oneDay: return 1
        case .twoDays: return 2
        case .threeDays: return 3
        case .oneWeek: return 7
        }
    }
}

// MARK: - Age Stage (for auto-tagging)

enum AgeStage: String, CaseIterable {
    case newborn = "newborn"       // 0-3 months
    case infant = "infant"         // 3-12 months
    case baby = "baby"             // 1-2 years
    case toddler = "toddler"       // 2-3 years
    case preschooler = "preschooler" // 3-5 years
    case child = "child"           // 5-12 years
    case teenager = "teenager"     // 13-19 years
    case adult = "adult"           // 20+ years

    var displayName: String {
        rawValue.capitalized
    }

    static func stage(forAgeInMonths months: Int) -> AgeStage {
        switch months {
        case 0..<3: return .newborn
        case 3..<12: return .infant
        case 12..<24: return .baby
        case 24..<36: return .toddler
        case 36..<60: return .preschooler
        case 60..<144: return .child
        case 144..<240: return .teenager
        default: return .adult
        }
    }
}

// MARK: - Media Sync Status

enum MediaSyncStatus: String, CaseIterable, Identifiable {
    case pending = "pending"           // Queued for upload
    case uploading = "uploading"       // Currently uploading
    case synced = "synced"             // Successfully in CloudKit
    case failed = "failed"             // Upload failed
    case downloading = "downloading"   // Downloading from CloudKit
    case localOnly = "local_only"      // Explicitly kept local (no cloud sync)

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .uploading: return "Uploading"
        case .synced: return "Synced"
        case .failed: return "Failed"
        case .downloading: return "Downloading"
        case .localOnly: return "Local Only"
        }
    }

    var icon: String {
        switch self {
        case .pending: return "clock"
        case .uploading: return "arrow.up.circle"
        case .synced: return "checkmark.icloud"
        case .failed: return "exclamationmark.icloud"
        case .downloading: return "arrow.down.circle"
        case .localOnly: return "iphone"
        }
    }

    var color: Color {
        switch self {
        case .pending: return .orange
        case .uploading: return .blue
        case .synced: return .green
        case .failed: return .red
        case .downloading: return .blue
        case .localOnly: return .gray
        }
    }

    /// Whether this status indicates the sync is in progress
    var isInProgress: Bool {
        self == .uploading || self == .downloading
    }

    /// Whether this status indicates an action is needed
    var needsAction: Bool {
        self == .pending || self == .failed
    }
}

// MARK: - Sort Option (for Timeline)

enum SortOption: String, CaseIterable, Identifiable {
    case newestFirst = "newest_first"
    case oldestFirst = "oldest_first"
    case byPerson = "by_person"
    case byType = "by_type"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .newestFirst: return "Newest First"
        case .oldestFirst: return "Oldest First"
        case .byPerson: return "By Person"
        case .byType: return "By Type"
        }
    }

    var icon: String {
        switch self {
        case .newestFirst: return "arrow.down"
        case .oldestFirst: return "arrow.up"
        case .byPerson: return "person.fill"
        case .byType: return "square.grid.2x2"
        }
    }
}

// MARK: - Grouping Option (for Timeline)

enum GroupingOption: String, CaseIterable, Identifiable {
    case byMonth = "by_month"
    case bySeason = "by_season"
    case byYear = "by_year"
    case byLocation = "by_location"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .byMonth: return "By Month"
        case .bySeason: return "By Season"
        case .byYear: return "By Year"
        case .byLocation: return "By Location"
        }
    }

    var icon: String {
        switch self {
        case .byMonth: return "calendar"
        case .bySeason: return "leaf.fill"
        case .byYear: return "calendar.badge.clock"
        case .byLocation: return "mappin"
        }
    }
}

// MARK: - Season (for auto-tagging)

enum Season: String, CaseIterable {
    case spring = "spring"
    case summer = "summer"
    case fall = "fall"
    case winter = "winter"

    var displayName: String {
        rawValue.capitalized
    }

    var icon: String {
        switch self {
        case .spring: return "leaf.fill"
        case .summer: return "sun.max.fill"
        case .fall: return "leaf.arrow.triangle.circlepath"
        case .winter: return "snowflake"
        }
    }

    static func season(for date: Date) -> Season {
        let month = Calendar.current.component(.month, from: date)
        switch month {
        case 3, 4, 5: return .spring
        case 6, 7, 8: return .summer
        case 9, 10, 11: return .fall
        default: return .winter
        }
    }
}
