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
│   ├── DaycatcherApp.swift      # App entry point + background tasks
│   ├── ContentView.swift         # Main tab navigation
│   └── PersistenceController.swift # Core Data + CloudKit stack
├── Models/
│   ├── Daycatcher.xcdatamodeld/  # Core Data model (with sync attributes)
│   ├── LovedOne+CoreDataClass.swift
│   ├── Memory+CoreDataClass.swift
│   ├── Event+CoreDataClass.swift
│   ├── Tag+CoreDataClass.swift
│   ├── WeeklyDigest+CoreDataClass.swift
│   └── Enums.swift               # MemoryType, RelationshipType, MediaSyncStatus, etc.
├── Views/
│   ├── Home/                     # Home tab views
│   ├── LovedOnes/                # Loved ones management
│   ├── Timeline/                 # Memory timeline/grid
│   ├── Events/                   # Events and reminders
│   ├── Settings/                 # App settings (includes media sync UI)
│   ├── Capture/                  # Memory capture flows
│   │   ├── PhotoCaptureView.swift
│   │   ├── VideoCaptureView.swift
│   │   ├── AudioCaptureView.swift
│   │   ├── TextCaptureView.swift
│   │   └── CaptureFlowContainer.swift
│   └── Components/
│       └── SyncStatusBadge.swift # Sync status indicator component
├── Theme/
│   └── ThemeManager.swift        # Theme system (colors, fonts, spacing)
└── Services/
    ├── MediaManager.swift        # Photo/video/audio file management
    ├── MediaSyncManager.swift    # CloudKit CKAsset upload/download
    └── PermissionsManager.swift  # Camera/photo/microphone permissions
```

## Build Commands

```bash
# Build for iPhone 17 simulator
xcodebuild -scheme Daycatcher -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' build

# Clean build
xcodebuild -scheme Daycatcher -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' clean build

# Run tests
xcodebuild test -scheme Daycatcher -destination 'platform=iOS Simulator,name=iPhone 17,OS=26.2' -only-testing:DaycatcherTests
```

## Testing

Unit tests are in the `DaycatcherTests` target (63 tests):
- **EnumTests.swift** - Tests for all enums (MemoryType, RelationshipType, Gender, EventType, ReminderOffset, AgeStage, Season)
- **MediaManagerTests.swift** - Tests for MediaManager (save/load/delete operations, URL builders, storage calculation)
- **MediaSyncManagerTests.swift** - Tests for MediaSyncStatus enum, sync properties on Memory/LovedOne entities, Core Data persistence

## CloudKit Configuration

- **Container ID**: `iCloud.com.tko.momentvault`
- **Bundle ID**: `com.daycatcher.app`
- Uses NSPersistentCloudKitContainer for automatic Core Data sync
- MediaSyncManager handles CKAsset uploads for binary media files
- CKShare support for family sharing (Phase 4)

## Core Data Entities

| Entity | Description |
|--------|-------------|
| LovedOne | Person/pet being tracked (name, birthDate, relationship, profileImageSyncStatus) |
| Memory | Captured moment (photo, video, audio, text) with sync status tracking |
| Event | Upcoming events/milestones with reminders |
| Tag | Categories for memories (AI-generated or manual) |
| WeeklyDigest | Auto-generated weekly memory summaries |

### Memory Sync Attributes
- `mediaSyncStatus` - pending/uploading/synced/failed/downloading/local_only
- `thumbnailSyncStatus` - same as above
- `cloudAssetRecordName` - CKRecord ID for media in CloudKit
- `cloudThumbnailRecordName` - CKRecord ID for thumbnail
- `lastSyncAttempt` - Date of last sync attempt
- `syncErrorMessage` - Error details if sync failed
- `mediaFileSize` - Size in bytes for progress tracking
- `uploadProgress` - 0.0 to 1.0 for upload progress

## Key Patterns

### Environment Objects
```swift
@EnvironmentObject var themeManager: ThemeManager
@EnvironmentObject var syncManager: MediaSyncManager
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

### Media Sync Flow
```
Capture → MediaManager (local save) → Core Data save
                                           ↓
                               MediaSyncManager.queueUpload()
                                           ↓
                               CKRecord + CKAsset → CloudKit
```

## Implementation Phases

1. ✅ **Foundation** - Core Data model, CloudKit setup, basic navigation
2. ✅ **Memory Capture** - Photo/video/audio/text capture flows
   - PhotoCaptureView, VideoCaptureView, AudioCaptureView, TextCaptureView
   - CaptureFlowContainer orchestrates workflow
   - PermissionsManager for camera/photo/microphone access
3. ✅ **Media Sync** - CKAsset handling for media files
   - MediaSyncManager for CloudKit uploads/downloads
   - Sync status tracking on Memory and LovedOne entities
   - Background upload support via BGProcessingTask
   - Network monitoring with NWPathMonitor
   - SyncStatusBadge UI component
   - Settings UI for sync status and manual retry
   - Unit tests (63 total tests passing)
4. 🔲 **Family Sharing** - CKShare + UICloudSharingController
5. 🔲 **Timeline & Discovery** - Enhanced timeline, search, filtering
6. 🔲 **Events & Reminders** - Milestone tracking, notifications
7. 🔲 **Tags & AI** - Vision/NLP for auto-tagging
8. 🔲 **Weekly Digests** - Auto-generated memory summaries
9. 🔲 **Export & Backup** - PDF generation, local backup
10. 🔲 **Offline Mode** - Conflict resolution, sync status UI improvements
11. 🔲 **Themes & Polish** - Additional themes, animations
12. 🔲 **Testing & Launch** - UI tests, App Store prep

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

### Test Crashes with MediaSyncManager
MediaSyncManager skips network monitoring initialization when running in test environment (detects `XCTestConfigurationFilePath`).

## Git Repository

https://github.com/tomolekovic/daycatchers.git
