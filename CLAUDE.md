# Daycatcher - Claude Code Guide

## Project Overview

Daycatcher is a privacy-first iOS app for capturing and preserving memories of loved ones (children, pets, family members). Built with SwiftUI and Core Data with CloudKit integration for family sharing.

## Tech Stack

- **Language**: Swift 5
- **UI Framework**: SwiftUI
- **Data Persistence**: Core Data with NSPersistentCloudKitContainer
- **Cloud Sync**: CloudKit (private + shared databases)
- **Minimum iOS**: 18.0
- **Architecture**: MVVM with environment-based dependency injection

## Project Structure

```
Daycatcher/
├── App/
│   ├── DaycatcherApp.swift      # App entry point
│   ├── ContentView.swift         # Main tab navigation
│   └── PersistenceController.swift # Core Data + CloudKit stack
├── Models/
│   ├── Daycatcher.xcdatamodeld/  # Core Data model
│   ├── LovedOne+CoreDataClass.swift
│   ├── Memory+CoreDataClass.swift
│   ├── Event+CoreDataClass.swift
│   ├── Tag+CoreDataClass.swift
│   ├── WeeklyDigest+CoreDataClass.swift
│   └── Enums.swift               # MemoryType, RelationshipType, etc.
├── Views/
│   ├── Home/                     # Home tab views
│   ├── LovedOnes/                # Loved ones management
│   ├── Timeline/                 # Memory timeline/grid
│   ├── Events/                   # Events and reminders
│   └── Settings/                 # App settings
├── Theme/
│   └── ThemeManager.swift        # Theme system (colors, fonts, spacing)
└── Services/
    └── MediaManager.swift        # Photo/video/audio file management
```

## Build Commands

```bash
# Build for iPhone 17 simulator
xcodebuild -scheme Daycatcher -destination 'platform=iOS Simulator,name=iPhone 17' build

# Clean build
xcodebuild -scheme Daycatcher -destination 'platform=iOS Simulator,name=iPhone 17' clean build

# Run tests (when available)
xcodebuild -scheme Daycatcher -destination 'platform=iOS Simulator,name=iPhone 17' test
```

## CloudKit Configuration

- **Container ID**: `iCloud.com.tko.momentvault`
- **Bundle ID**: `com.daycatcher.app`
- Uses NSPersistentCloudKitContainer for automatic sync
- CKShare support for family sharing (Phase 4)

## Core Data Entities

| Entity | Description |
|--------|-------------|
| LovedOne | Person/pet being tracked (name, birthDate, relationship) |
| Memory | Captured moment (photo, video, audio, text) |
| Event | Upcoming events/milestones with reminders |
| Tag | Categories for memories (AI-generated or manual) |
| WeeklyDigest | Auto-generated weekly memory summaries |

## Key Patterns

### Environment Objects
```swift
@EnvironmentObject var themeManager: ThemeManager
@Environment(\.managedObjectContext) private var viewContext
```

### Fetch Requests
```swift
@FetchRequest(
    sortDescriptors: [NSSortDescriptor(keyPath: \Memory.captureDate, ascending: false)],
    animation: .default
)
private var memories: FetchedResults<Memory>
```

### Core Data Class Naming
All Core Data classes use `@objc(EntityName)` annotation to match the model.

## Implementation Phases

1. ✅ **Foundation** - Core Data model, CloudKit setup, basic navigation
2. 🔲 **Memory Capture** - Photo/video/audio/text capture flows
3. 🔲 **Media Sync** - CKAsset handling for media files
4. 🔲 **Family Sharing** - CKShare + UICloudSharingController
5. 🔲 **Timeline & Discovery** - Enhanced timeline, search, filtering
6. 🔲 **Events & Reminders** - Milestone tracking, notifications
7. 🔲 **Tags & AI** - Vision/NLP for auto-tagging
8. 🔲 **Weekly Digests** - Auto-generated memory summaries
9. 🔲 **Export & Backup** - PDF generation, local backup
10. 🔲 **Offline Mode** - Conflict resolution, sync status
11. 🔲 **Themes & Polish** - Additional themes, animations
12. 🔲 **Testing & Launch** - Unit tests, UI tests, App Store prep

## Common Issues

### White Screen on Launch
Usually caused by Core Data model not loading. Check:
1. `.xccurrentversion` file exists in `Daycatcher.xcdatamodeld/`
2. `XCVersionGroup` in project.pbxproj has correct `currentVersion` reference
3. Clean build folder and rebuild

### CloudKit Errors in Simulator
The simulator doesn't have an iCloud account, so CloudKit sync errors are expected. The app stores data locally and sync works on real devices.

### SwiftUI TimelineView Conflict
SwiftUI has a built-in `TimelineView` type. Our timeline is named `MemoriesTimelineView` to avoid conflicts.

## Git Repository

https://github.com/tomolekovic/daycatchers.git
