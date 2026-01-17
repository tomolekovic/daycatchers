# Daycatcher

A privacy-first iOS app for capturing and preserving precious memories of loved ones.

## Overview

Daycatcher helps you capture, organize, and preserve moments with the people you love most—children, pets, grandparents, partners, and friends. All AI processing happens on-device, and your data stays in your control through iCloud.

## Features

- **Memory Capture** — Photos, videos, voice notes, and text journals
- **Loved Ones Profiles** — Dedicated profiles for each person or pet
- **Smart Organization** — Timeline view, calendar view, search, and filters
- **On-Device AI** — Smart tagging, OCR, and audio transcription without cloud processing
- **Family Sharing** — Share specific loved ones with family members via iCloud
- **PDF Memory Books** — Generate printable keepsakes
- **Privacy-First** — All data encrypted, no external servers

## Requirements

- iOS 18.0+
- Xcode 15.0+
- Apple Developer account (for CloudKit)

## Setup

1. Clone the repository
2. Open `Daycatcher.xcodeproj` in Xcode
3. Set your Development Team in Signing & Capabilities
4. Create CloudKit container `iCloud.com.tko.momentvault` in Apple Developer Portal
5. Build and run

## Architecture

- **UI**: SwiftUI
- **Data**: Core Data with NSPersistentCloudKitContainer
- **Sync**: CloudKit (private + shared databases)
- **Sharing**: CKShare + UICloudSharingController
- **AI/ML**: Vision, Natural Language, Speech frameworks (on-device)

## Project Structure

```
Daycatcher/
├── App/                    # App entry point, persistence
├── Models/                 # Core Data entities
├── Views/
│   ├── Home/
│   ├── LovedOnes/
│   ├── Timeline/
│   ├── Events/
│   └── Settings/
├── Services/               # MediaManager, etc.
└── Theme/                  # Theme system
```

## License

Private repository. All rights reserved.
