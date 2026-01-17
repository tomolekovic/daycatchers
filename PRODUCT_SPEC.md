# Daycatcher Product Specification

> A comprehensive guide to the user stories, functionality, and product vision for Daycatcher - a privacy-first iOS app for capturing and preserving precious memories of loved ones.

---

## Table of Contents

1. [Product Vision](#product-vision)
2. [Target Users](#target-users)
3. [Core Value Proposition](#core-value-proposition)
4. [User Personas](#user-personas)
5. [Feature Overview](#feature-overview)
6. [User Stories](#user-stories)
7. [User Journeys](#user-journeys)
8. [Screen-by-Screen Breakdown](#screen-by-screen-breakdown)
9. [Design Principles](#design-principles)
10. [Privacy & Security Philosophy](#privacy--security-philosophy)

---

## Product Vision

Daycatcher exists to help people capture, organize, and preserve the precious moments of their loved ones' lives. Whether it's a child's first steps, a pet's silly antics, or cherished moments with grandparents, Daycatcher provides a beautiful, private, and intelligent way to build a digital memory collection that can be treasured for generations.

### Mission Statement

*"Every moment matters. Daycatcher helps you capture, organize, and preserve the precious memories of the people you love most."*

### What Makes Daycatcher Different

- **Privacy-First**: All AI processing happens on-device. Your memories never leave your control.
- **Flexible Relationships**: Not just for parents - track anyone special: children, pets, grandparents, partners, friends.
- **Intelligent Organization**: AI-powered tagging and discovery without cloud processing.
- **Family Collaboration**: Share specific loved ones with family members through native iCloud sharing.
- **Beautiful Preservation**: Generate printable PDF memory books for physical keepsakes.

---

## Target Users

### Primary Market

- **Parents** capturing daily moments of their children's lives
- **Couples** collaboratively documenting their children together
- **Grandparents** wanting to stay connected with grandchildren's milestones

### Secondary Market

- **Pet owners** documenting their pets' lives
- **Caregivers** tracking moments with elderly parents
- **Anyone** wanting an organized, private way to preserve memories of loved ones

### User Demographics

- iOS users (iPhone/iPad)
- Privacy-conscious individuals
- Ages 25-65 (primary: 28-45)
- Comfortable with smartphone photography
- Value organization and family connection

---

## Core Value Proposition

| User Need | Daycatcher Solution |
|-----------|---------------------|
| "I take thousands of photos but can't find them later" | Organized by person, searchable, filterable timeline |
| "I want to remember what my child was like at each age" | Automatic age-based tagging, milestone tracking |
| "I worry about privacy with cloud AI services" | 100% on-device AI processing |
| "I want to share with my partner but no one else" | Fine-grained family sharing - share specific loved ones |
| "I want physical keepsakes, not just digital" | PDF memory book generation for printing |
| "I capture photos but forget the stories behind them" | Voice notes, text notes, and notes on every memory |

---

## User Personas

### Persona 1: Sarah - The Busy Parent

**Demographics**: 34, marketing manager, mother of two (ages 2 and 5)

**Goals**:
- Capture daily moments quickly without friction
- Keep memories organized automatically
- Share with her husband who travels for work
- Create printed photo books for grandparents

**Pain Points**:
- Camera roll is chaos with 20,000 photos
- Can't find specific photos when she wants them
- Feels guilty not printing or organizing photos
- Worried about privacy with cloud photo services

**How Daycatcher Helps**:
- Quick capture with one-tap access
- AI auto-tags by child and context
- Family sharing with husband only
- PDF export for grandparents

---

### Persona 2: Robert - The Engaged Grandparent

**Demographics**: 67, retired teacher, grandfather of four

**Goals**:
- See grandchildren grow up despite distance
- Contribute his own photos when visiting
- Browse chronologically to see progression
- Print memories for his home

**Pain Points**:
- Lives 3 hours from grandchildren
- Daughter sends photos sporadically via text
- Photos get lost in text threads
- Wants organized way to review growth over time

**How Daycatcher Helps**:
- Family sharing shows grandchildren's memories automatically
- Can add his own memories when visiting
- Timeline view shows growth over time
- Calendar view for "what happened on this date"

---

### Persona 3: Maya - The Privacy-Conscious Parent

**Demographics**: 29, software engineer, mother of one (age 1)

**Goals**:
- Document every milestone
- Never have photos analyzed by big tech
- Keep complete control over data
- Use AI features without privacy trade-offs

**Pain Points**:
- Doesn't trust cloud AI services
- Wants smart features but not at privacy cost
- Current solutions require cloud processing
- Concerned about where baby photos end up

**How Daycatcher Helps**:
- All AI runs on-device (Vision, Natural Language frameworks)
- Data encrypted end-to-end in iCloud
- No external servers for core features
- Optional backend for face recognition (self-hosted)

---

### Persona 4: Alex - The Pet Parent

**Demographics**: 31, graphic designer, owner of dog (Luna, 3) and cat (Mochi, 5)

**Goals**:
- Document pets' lives and personalities
- Track vet visits and milestones
- Share cute moments with partner
- Remember pets after they're gone

**Pain Points**:
- Pet photos mixed with everything else
- No good way to organize by pet
- Calendar apps don't feel right for this
- Wants something more personal than social media

**How Daycatcher Helps**:
- "Pet" relationship type designed for this
- Separate profiles for each pet
- Milestone tracking for pet events
- Voice notes to capture personality

---

## Feature Overview

### Memory Capture

| Feature | Description |
|---------|-------------|
| **Photo Capture** | Take or select photos, batch select up to 20, automatic location from metadata |
| **Video Capture** | Record or select videos, supports long-form content |
| **Audio Recording** | Voice memos with optional transcription |
| **Text Notes** | Journal-style written memories |
| **Handwriting Recognition** | Extract text from photos of handwritten notes or cards |

### Organization

| Feature | Description |
|---------|-------------|
| **Loved Ones Profiles** | Dedicated profiles for each person/pet being tracked |
| **Timeline View** | Chronological grid of all memories, grouped by month |
| **Calendar View** | Date picker to see what happened on specific days |
| **Smart Search** | Search by title, notes, tags, or person name |
| **Multi-Filter** | Filter by person, type, and date range simultaneously |
| **Tags** | User-created and AI-suggested tags for categorization |

### Intelligence (On-Device)

| Feature | Description |
|---------|-------------|
| **Smart Tagging** | AI suggests relevant tags based on photo content and context |
| **Age Tagging** | Automatic tags like "newborn," "baby," "toddler" based on birth date |
| **Season Tagging** | Contextual tags like "summer," "winter" based on capture date |
| **Weekly Digests** | Auto-generated summaries every Sunday |
| **Text Extraction** | OCR for handwritten notes and printed text in photos |
| **Audio Transcription** | Convert voice notes to searchable text |

### Family Sharing

| Feature | Description |
|---------|-------------|
| **Family Creation** | Create a family group and invite members |
| **Invite by Email** | Send invitations via Apple ID email |
| **Selective Sharing** | Choose which loved ones to share (not all-or-nothing) |
| **Collaborative Adding** | Family members can add memories to shared profiles |
| **Automatic Sync** | Changes sync automatically via iCloud |

### Events & Reminders

| Feature | Description |
|---------|-------------|
| **Event Calendar** | Track birthdays, anniversaries, special events |
| **Birthday Auto-Creation** | Birthdays created automatically from birth dates |
| **Memory-Event Linking** | Connect memories to events for context |
| **Reminders** | Notifications before important dates |
| **Configurable Timing** | Same day, 1/2/3 days, or 1 week before |

### Export & Preservation

| Feature | Description |
|---------|-------------|
| **PDF Memory Book** | Beautiful formatted PDF for printing |
| **Media Export** | Save to Files or Photos library |
| **Full Backup** | Complete encrypted backup of all data |
| **Restore** | Restore from backup file |

### Customization

| Feature | Description |
|---------|-------------|
| **Classic Theme** | Bright coral and lavender colors |
| **Modern Scrapbook Theme** | Warm cream and terracotta aesthetic |
| **Reminder Settings** | Toggle and configure reminder timing |
| **AI Feature Toggles** | Enable/disable individual AI features |

---

## User Stories

### Epic: Memory Capture

```
As a parent,
I want to quickly capture a photo of my child,
So that I don't miss precious moments while fumbling with the app.
```

```
As a user,
I want to select multiple photos from my library at once,
So that I can add a batch of memories from an event efficiently.
```

```
As a user,
I want to record voice notes about my memories,
So that I can capture context and emotions that photos alone can't convey.
```

```
As a parent,
I want to extract text from photos of my child's drawings or cards,
So that I can preserve their early writing as searchable memories.
```

```
As a user,
I want to add custom tags to my memories,
So that I can categorize them in ways meaningful to me.
```

```
As a user,
I want the app to suggest relevant tags automatically,
So that I can organize memories without extra effort.
```

---

### Epic: Loved Ones Management

```
As a new user,
I want to add my first loved one with basic information,
So that I can start capturing memories right away.
```

```
As a pet owner,
I want to create a profile for my pet with "Pet" as the relationship type,
So that the app understands this isn't a human.
```

```
As a user,
I want to see a photo and age for each loved one,
So that I can quickly identify them at a glance.
```

```
As a user,
I want to see statistics about each loved one (memory count, events),
So that I can understand how much I've captured for them.
```

```
As a user,
I want to delete a loved one and optionally their memories,
So that I can manage profiles that are no longer relevant.
```

---

### Epic: Memory Discovery

```
As a user,
I want to browse memories in a timeline view,
So that I can see what I've captured chronologically.
```

```
As a user,
I want to filter memories by specific loved one,
So that I can focus on one person's history.
```

```
As a user,
I want to search memories by keyword,
So that I can find specific moments quickly.
```

```
As a user,
I want to view memories on a calendar,
So that I can see what happened on specific dates.
```

```
As a grandparent,
I want to see memories grouped by month,
So that I can watch my grandchild grow over time.
```

---

### Epic: Family Sharing

```
As a parent,
I want to invite my spouse to share our children's memories,
So that we both can capture and view the same collection.
```

```
As a user,
I want to choose which loved ones to share with family,
So that I maintain control over my private memories.
```

```
As an invited family member,
I want to see shared memories automatically sync,
So that I don't have to manually request updates.
```

```
As a family member,
I want to add my own memories to shared profiles,
So that I can contribute to the family collection.
```

```
As a family owner,
I want to see who has access to each shared loved one,
So that I know exactly what's being shared with whom.
```

---

### Epic: Events & Reminders

```
As a parent,
I want birthdays to be created automatically from birth dates,
So that I don't have to enter them manually.
```

```
As a user,
I want to create custom events like "First Day of School,"
So that I can track important milestones beyond birthdays.
```

```
As a user,
I want to link memories to events,
So that I can see all photos from a specific occasion together.
```

```
As a forgetful parent,
I want reminders before important dates,
So that I never forget a birthday or anniversary.
```

```
As a user,
I want to configure how far in advance I receive reminders,
So that I have time to prepare gifts or celebrations.
```

---

### Epic: Export & Preservation

```
As a grandparent,
I want to generate a printable PDF memory book,
So that I can have a physical keepsake to display.
```

```
As a user,
I want to export my photos and videos to the Files app,
So that I can back them up to other services.
```

```
As a privacy-conscious user,
I want to create an encrypted backup of all my data,
So that I can restore it if I lose my phone.
```

```
As a user switching phones,
I want to restore from a backup file,
So that I don't lose any memories.
```

---

### Epic: Privacy & Security

```
As a privacy-conscious user,
I want all AI processing to happen on my device,
So that my photos are never sent to external servers.
```

```
As a user,
I want my data encrypted both locally and in iCloud,
So that my memories are protected from unauthorized access.
```

```
As a user,
I want to understand what data is being stored and how,
So that I can trust the app with my precious memories.
```

---

### Epic: Personalization

```
As a user,
I want to choose between different visual themes,
So that the app matches my personal aesthetic.
```

```
As a user,
I want to toggle individual AI features on or off,
So that I have control over automatic behaviors.
```

```
As a user,
I want the app to remember my preferences,
So that I don't have to reconfigure settings each time.
```

---

## User Journeys

### Journey 1: First-Time User Onboarding

```
┌─────────────────────────────────────────────────────────────────────┐
│                     FIRST-TIME USER JOURNEY                         │
└─────────────────────────────────────────────────────────────────────┘

1. DOWNLOAD & OPEN
   └─> User downloads Daycatcher from App Store
   └─> Opens app for first time

2. EMPTY STATE
   └─> Sees "Loved Ones" tab with friendly empty state
   └─> Clear call-to-action: "Add Someone Special"

3. ADD FIRST LOVED ONE
   └─> Enters name (e.g., "Emma")
   └─> Selects birth date
   └─> Chooses relationship type: "Child"
   └─> Optionally adds profile photo
   └─> Saves

4. FIRST MEMORY PROMPT
   └─> Returns to profile showing Emma
   └─> Sees quick-capture buttons: Photo, Video, Audio, Note
   └─> Taps "Photo"

5. CAPTURE FIRST MEMORY
   └─> Camera opens (or photo picker)
   └─> Takes photo of Emma
   └─> Adds title: "Morning smile"
   └─> AI suggests tags: "baby", "morning", "happy"
   └─> Accepts suggestions
   └─> Saves

6. SUCCESS & EXPLORATION
   └─> Memory appears in Emma's profile
   └─> Memory appears in Timeline tab
   └─> Memory appears in Home tab as "Recent"
   └─> User explores other tabs

7. ONGOING ENGAGEMENT
   └─> App feels personal and useful
   └─> Clear path to continue adding memories
```

---

### Journey 2: Daily Memory Capture

```
┌─────────────────────────────────────────────────────────────────────┐
│                     DAILY CAPTURE JOURNEY                           │
└─────────────────────────────────────────────────────────────────────┘

1. TRIGGER
   └─> User witnesses cute moment with child
   └─> Opens Daycatcher quickly

2. HOME SCREEN
   └─> Sees personalized greeting
   └─> Quick-capture buttons prominently displayed
   └─> Taps "Photo" button

3. SELECT CHILD
   └─> Person picker shows loved ones
   └─> Taps on "Emma"

4. CAPTURE
   └─> Camera opens
   └─> Takes photo of moment
   └─> Reviews photo

5. ADD CONTEXT
   └─> Title field (optional)
   └─> Notes field for story behind photo
   └─> AI-suggested tags appear
   └─> Accepts some, adds custom tag "park"

6. SAVE
   └─> Taps "Save"
   └─> Brief success feedback
   └─> Returns to home

7. BACKGROUND SYNC
   └─> Memory automatically syncs to iCloud
   └─> Available on other devices
   └─> Shared with family if Emma is shared

Total time: 30-60 seconds
```

---

### Journey 3: Browsing Memories

```
┌─────────────────────────────────────────────────────────────────────┐
│                     MEMORY BROWSING JOURNEY                         │
└─────────────────────────────────────────────────────────────────────┘

1. INTENT
   └─> User wants to find photos from beach trip last summer

2. NAVIGATE TO TIMELINE
   └─> Taps Timeline tab
   └─> Sees grid of all memories

3. APPLY FILTERS
   └─> Taps filter icon
   └─> Selects "Emma" from person filter
   └─> Selects "Photo" from type filter
   └─> Active filters shown as removable chips

4. SEARCH
   └─> Types "beach" in search bar
   └─> Results narrow to beach-related memories

5. BROWSE RESULTS
   └─> Scrolls through matching photos
   └─> Sees memories grouped by month
   └─> July 2024 section shows beach trip photos

6. VIEW DETAIL
   └─> Taps on specific photo
   └─> Full-screen view with title, notes
   └─> Sees tags: "beach", "summer", "toddler"
   └─> Sees location: "Santa Monica Beach"

7. ACTIONS
   └─> Can edit memory details
   └─> Can save to Photos library
   └─> Can delete if needed
   └─> Swipes to next/previous memory
```

---

### Journey 4: Setting Up Family Sharing

```
┌─────────────────────────────────────────────────────────────────────┐
│                    FAMILY SHARING SETUP JOURNEY                     │
└─────────────────────────────────────────────────────────────────────┘

1. NAVIGATE
   └─> Goes to Settings tab
   └─> Taps "Family Sharing"

2. CREATE FAMILY
   └─> No family exists yet
   └─> Taps "Create Family"
   └─> Enters family name: "The Smiths"
   └─> Saves

3. INVITE SPOUSE
   └─> Taps "Invite Member"
   └─> Enters spouse's name and email (Apple ID)
   └─> Confirmation dialog
   └─> Sends invitation

4. SPOUSE RECEIVES INVITE
   └─> Spouse receives email/notification
   └─> Taps to accept
   └─> Opens their Daycatcher app
   └─> Family sharing is now active

5. SHARE Loved One
   └─> Back to main app
   └─> Goes to Emma's profile
   └─> Taps "Edit"
   └─> Toggles "Share with Family" ON
   └─> Saves

6. VERIFICATION
   └─> Returns to Family Settings
   └─> Sees spouse's name listed as member
   └─> Sees Emma listed as shared

7. SPOUSE EXPERIENCE
   └─> Spouse opens their app
   └─> Sees Emma in their Loved Ones
   └─> Can view all Emma's memories
   └─> Can add new memories to Emma
```

---

### Journey 5: Generating a Memory Book

```
┌─────────────────────────────────────────────────────────────────────┐
│                    MEMORY BOOK GENERATION JOURNEY                   │
└─────────────────────────────────────────────────────────────────────┘

1. NAVIGATE
   └─> Goes to Settings tab
   └─> Taps "Export & Backup"
   └─> Taps "Generate PDF Memory Book"

2. CONFIGURE
   └─> Selects child: "Emma"
   └─> Selects date range: "2024"
   └─> Toggles: Include Photos ✓
   └─> Toggles: Include Milestones ✓

3. GENERATE
   └─> Taps "Generate"
   └─> Progress indicator shows generation
   └─> "Processing 127 memories..."

4. PREVIEW
   └─> PDF preview appears
   └─> Scrolls through pages
   └─> Beautiful formatting with photos and captions

5. SHARE/SAVE
   └─> Taps share button
   └─> Options: Save to Files, Print, Send to...
   └─> Selects "Print"
   └─> Sends to printer

6. PHYSICAL KEEPSAKE
   └─> Prints memory book
   └─> Gives to grandparents as gift
   └─> Or keeps on coffee table
```

---

### Journey 6: Extracting Text from Child's Drawing

```
┌─────────────────────────────────────────────────────────────────────┐
│                    HANDWRITING EXTRACTION JOURNEY                   │
└─────────────────────────────────────────────────────────────────────┘

1. CAPTURE
   └─> Child draws picture with writing
   └─> User photographs it

2. ADD AS MEMORY
   └─> Creates new photo memory
   └─> Assigns to child
   └─> Saves

3. EXTRACT TEXT
   └─> Views memory detail
   └─> Taps "Extract Text"
   └─> Processing indicator

4. REVIEW RESULTS
   └─> Sheet appears with extracted text
   └─> Shows confidence level (High/Medium/Low)
   └─> Text: "I love mommy"

5. EDIT IF NEEDED
   └─> Can correct any OCR errors
   └─> Edits to fix "mommy" → "Mommy"

6. SAVE
   └─> Taps "Save to Notes"
   └─> Text appended to memory notes
   └─> Now searchable by "I love Mommy"

7. FUTURE DISCOVERY
   └─> Years later, searches "I love"
   └─> Finds this precious memory
```

---

## Screen-by-Screen Breakdown

### Tab Bar Navigation

| Tab | Icon | Purpose |
|-----|------|---------|
| Home | House | Daily hub with greeting, quick capture, recent memories |
| Loved Ones | People | Grid of all tracked people/pets |
| Timeline | Clock | Chronological memory browser |
| Events | Calendar | Event calendar and reminders |
| Settings | Gear | App configuration |

---

### Home Tab

**Purpose**: Central hub for daily app usage

**Elements**:
- Personalized greeting with time of day
- Upcoming events card (next 7 days)
- Recent memories carousel
- Quick-capture buttons (Photo, Video, Audio, Note)
- Weekly digest card (if new)

**User Actions**:
- Tap quick-capture to add memory
- Tap event to view details
- Tap memory to view full detail
- Tap digest to read summary

---

### Loved Ones Tab

**Purpose**: Manage and browse loved ones

**Main View**:
- Grid of profile cards
- Each card shows: photo/initials, name, relationship badge, age
- "Add" button in navigation
- Search bar (when multiple profiles exist)

**Profile Detail View**:
- Large profile photo/initials
- Name and relationship badge
- Age (calculated from birth date)
- Stats row: memories count, events count
- Segmented control: Memories | Events
- Quick-capture buttons
- Edit and Share buttons

**Add/Edit View**:
- Photo picker (camera or library)
- Name text field
- Birth date picker
- Relationship picker (Child, Partner, Pet, etc.)
- Gender picker (optional)
- Share toggle (if family exists)
- Delete button (edit mode only)

---

### Timeline Tab

**Purpose**: Browse and search all memories

**Main View**:
- Toggle: Grid View | Calendar View
- Search bar
- Filter button (shows active filter count)
- Memory grid grouped by month
- Month headers as sticky sections

**Filter Sheet**:
- Person picker (Everyone or specific)
- Type picker (All, Photo, Video, Audio, Note)
- Date range picker (All Time, Past Week, Month, Year)
- Clear Filters button
- Apply button

**Memory Detail View**:
- Full-screen media (photo/video/audio player)
- Title
- Notes (expandable)
- Metadata: Person, Date, Location
- Tags (user and AI)
- Linked event (if any)
- Edit button
- Delete button
- Extract Text (photos only)

---

### Events Tab

**Purpose**: Calendar of important dates

**Main View**:
- Month/week calendar grid
- Dots indicate dates with events
- List of events for selected date/range
- "Add" button in navigation

**Event Detail View**:
- Event title
- Date and time
- Associated person
- Notes
- Linked memories carousel
- Edit and Delete buttons

**Add/Edit Event View**:
- Title text field
- Date picker
- Time picker (optional)
- All-day toggle
- Person picker
- Notes text field
- Link memories button
- Delete button (edit mode)

---

### Settings Tab

**Purpose**: App configuration and data management

**Sections**:

**Appearance**
- Theme picker (Classic, Modern Scrapbook)
- Theme preview

**iCloud & Sync**
- Sync status indicator
- Last sync timestamp
- Manual sync button

**Family Sharing**
- Family name (if exists)
- Family members list
- Shared loved ones list
- Create/Join Family button
- Invite Member button
- Leave Family button

**Reminders**
- Birthday reminders toggle
- Anniversary reminders toggle
- Reminder timing picker

**AI Features**
- Smart tagging toggle
- Inline suggestions toggle
- Weekly digests toggle
- Face recognition settings (advanced)
- Privacy information

**Export & Backup**
- Generate PDF Memory Book
- Export All Media
- Create Backup
- Restore from Backup

**Data & Storage**
- Data summary (counts)
- Storage used
- Available space

**About**
- Version info
- Privacy policy link
- Terms of service link

---

## Design Principles

### 1. Speed Over Perfection

Memories happen fast. Capture should be faster.
- One-tap access to camera
- Optional fields, never required
- Quick save, detailed edit later

### 2. Organized by Default

No folder management required.
- Automatic date organization
- Automatic person association
- Smart tagging does the work

### 3. Privacy Without Compromise

Intelligence without surveillance.
- All AI on-device
- Encrypted everywhere
- User controls sharing

### 4. Flexible for All Relationships

Not everyone is a parent.
- Multiple relationship types
- No assumptions about family structure
- Works for pets, grandparents, friends

### 5. Preservation as a Feature

Digital memories should become physical keepsakes.
- PDF generation for printing
- Export options for backup
- Professional-quality output

---

## Privacy & Security Philosophy

### Data Ownership

- **Your data is yours**: Everything stored on your device or your iCloud
- **No external servers required**: Core app works completely offline
- **Optional features are opt-in**: Face recognition backend is self-hosted

### AI Privacy

- **On-device processing**: Vision and Natural Language frameworks
- **No cloud AI**: Photos never sent to external ML services
- **Transparent features**: Each AI feature can be toggled individually

### Encryption Layers

| Layer | Protection |
|-------|------------|
| Device Storage | iOS Data Protection (AES-256) |
| iCloud Sync | End-to-end encryption |
| Local Backup | Optional AES-GCM encryption |
| Family Sharing | CloudKit encryption |

### Trust Model

```
┌─────────────────────────────────────────────────────────────────────┐
│                         TRUST BOUNDARIES                            │
└─────────────────────────────────────────────────────────────────────┘

TRUSTED (Your Control):
  ├─ Your iPhone/iPad
  ├─ Your iCloud account
  ├─ Your local backups
  └─ Family members you explicitly invite

NOT TRUSTED (External):
  ├─ No third-party analytics
  ├─ No external AI services
  ├─ No advertising networks
  └─ No data monetization
```

---

## Appendix: Relationship Types

| Type | Icon | Example Use |
|------|------|-------------|
| Child | 👶 | Sons, daughters |
| Partner | 💑 | Spouse, significant other |
| Parent | 👨‍👩‍👧 | Mom, dad |
| Grandparent | 👴👵 | Grandma, grandpa |
| Sibling | 👫 | Brother, sister |
| Friend | 🤝 | Close friends |
| Pet | 🐾 | Dogs, cats, any pets |
| Other | ⭐ | Any other relationship |

---

## Appendix: Memory Types

| Type | File Format | Storage Location | Features |
|------|-------------|------------------|----------|
| Photo | JPEG | Documents/Daycatcher/photos/ | OCR, AI tagging, location |
| Video | MOV | Documents/Daycatcher/videos/ | Playback controls |
| Audio | M4A | Documents/Daycatcher/audio/ | Transcription, playback |
| Text | — | Core Data only | Full-text search |

---

## Appendix: Theme Comparison

| Aspect | Classic | Modern Scrapbook |
|--------|---------|------------------|
| Primary Color | Coral (#FF6B6B) | Terracotta (#C4A77D) |
| Secondary Color | Lavender (#B8A9E0) | Sage (#8B9D83) |
| Background | White | Cream (#FDF8F3) |
| Typography | System Default | Serif accents |
| Card Style | Rounded, shadows | Paper-textured |
| Mood | Bright, playful | Warm, nostalgic |

---

*This document serves as the complete product specification for Daycatcher. It can be used to rebuild the app from scratch, communicate the product vision to stakeholders, or onboard new team members to the project.*

*Last updated: January 2025*
