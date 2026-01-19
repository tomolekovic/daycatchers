import SwiftUI
import CoreData
import UserNotifications
import UIKit

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var notificationManager: NotificationManager
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var persistenceController = PersistenceController.shared
    @ObservedObject var syncManager = MediaSyncManager.shared

    @AppStorage("smartTaggingEnabled") private var smartTaggingEnabled = true
    @AppStorage("weeklyDigestsEnabled") private var weeklyDigestsEnabled = true
    @AppStorage("birthdayRemindersEnabled") private var birthdayRemindersEnabled = true
    @AppStorage("defaultReminderOffset") private var defaultReminderOffset = ReminderOffset.oneDay.rawValue

    @State private var showingExportSheet = false

    var body: some View {
        NavigationStack {
            Form {
                // Appearance
                appearanceSection

                // iCloud Sync
                syncSection

                // Family Sharing
                familySharingSection

                // Media Sync
                mediaSyncSection

                // Reminders
                remindersSection

                // AI Features
                aiSection

                // Export & Backup
                exportSection

                // Data & Storage
                dataSection

                // About
                aboutSection
            }
            .navigationTitle("Settings")
        }
    }

    // MARK: - Appearance Section

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $themeManager.selectedTheme) {
                ForEach(AppTheme.allCases) { theme in
                    VStack(alignment: .leading) {
                        Text(theme.displayName)
                        Text(theme.description)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .tag(theme)
                }
            }
            .pickerStyle(.navigationLink)

            // Theme Preview
            HStack(spacing: 12) {
                ForEach(AppTheme.allCases) { theme in
                    ThemePreviewCard(
                        theme: theme,
                        isSelected: themeManager.selectedTheme == theme
                    )
                    .onTapGesture {
                        withAnimation {
                            themeManager.selectedTheme = theme
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    // MARK: - Sync Section

    private var syncSection: some View {
        Section {
            HStack {
                Image(systemName: "icloud.fill")
                    .foregroundStyle(.blue)

                VStack(alignment: .leading) {
                    Text("iCloud Sync")

                    switch persistenceController.syncStatus {
                    case .idle:
                        Text("Idle")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .syncing:
                        Text("Syncing...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .synced(let date):
                        Text("Last synced: \(date.formatted())")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    case .error(let message):
                        Text("Error: \(message)")
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Spacer()

                if case .syncing = persistenceController.syncStatus {
                    ProgressView()
                } else {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        } header: {
            Text("iCloud & Sync")
        } footer: {
            Text("Your data is automatically synced across all your devices using iCloud.")
        }
    }

    // MARK: - Family Sharing Section

    private var familySharingSection: some View {
        Section {
            NavigationLink {
                SharedProfilesView()
            } label: {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(.purple)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Family Sharing")

                        let sharedCount = SharingManager.shared.getSharedLovedOnes().count
                        if sharedCount > 0 {
                            Text("\(sharedCount) shared profile\(sharedCount == 1 ? "" : "s")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Share profiles with family")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()
                }
            }
        } header: {
            Text("Family")
        } footer: {
            Text("Share loved ones' profiles with family members so they can view and add memories.")
        }
    }

    // MARK: - Media Sync Section

    private var mediaSyncSection: some View {
        Section {
            // Media sync status row
            HStack {
                Image(systemName: "photo.on.rectangle.angled")
                    .foregroundStyle(.purple)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Media Sync")

                    if syncManager.pendingUploads > 0 {
                        Text("\(syncManager.pendingUploads) pending upload\(syncManager.pendingUploads == 1 ? "" : "s")")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        Text("All media synced")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if syncManager.isUploading {
                    VStack(alignment: .trailing, spacing: 2) {
                        ProgressView(value: syncManager.currentUploadProgress)
                            .frame(width: 60)

                        Text("\(Int(syncManager.currentUploadProgress * 100))%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                } else if syncManager.pendingUploads == 0 {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }

            // Network status indicator
            if !syncManager.isNetworkAvailable {
                HStack {
                    Image(systemName: "wifi.slash")
                        .foregroundStyle(.orange)

                    Text("No network connection")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            // Sync now button
            if syncManager.pendingUploads > 0 {
                Button(action: {
                    Task {
                        await syncManager.retryFailedUploads()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Sync Now")
                    }
                }
                .disabled(syncManager.isUploading || !syncManager.isNetworkAvailable)
            }

            // Error display
            if let error = syncManager.syncError {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)

                    Text(error.localizedDescription)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }
        } header: {
            Text("Media")
        } footer: {
            Text("Photos, videos, and audio are synced to iCloud so they're available on all your devices.")
        }
    }

    // MARK: - Reminders Section

    private var remindersSection: some View {
        Section {
            // Notification permission status
            HStack {
                Image(systemName: "bell.fill")
                    .foregroundStyle(notificationStatusColor)

                VStack(alignment: .leading, spacing: 2) {
                    Text("Notifications")

                    Text(notificationStatusText)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                notificationStatusIcon
            }

            // Open Settings button if denied
            if notificationManager.authorizationStatus == .denied {
                Button(action: {
                    notificationManager.openSettings()
                }) {
                    HStack {
                        Image(systemName: "gear")
                        Text("Open Settings")
                    }
                }
            }

            // Request permission button if not determined
            if notificationManager.authorizationStatus == .notDetermined {
                Button(action: {
                    Task {
                        await notificationManager.requestAuthorization()
                    }
                }) {
                    HStack {
                        Image(systemName: "bell.badge")
                        Text("Enable Notifications")
                    }
                }
            }

            // Birthday reminders toggle
            Toggle("Birthday Reminders", isOn: $birthdayRemindersEnabled)
                .disabled(notificationManager.authorizationStatus == .denied)

            // Default reminder timing
            Picker("Default Reminder Timing", selection: $defaultReminderOffset) {
                ForEach(ReminderOffset.allCases) { offset in
                    Text(offset.displayName).tag(offset.rawValue)
                }
            }
            .disabled(notificationManager.authorizationStatus == .denied)

            // Pending notifications count
            if notificationManager.pendingNotificationsCount > 0 {
                HStack {
                    Text("Scheduled Reminders")
                    Spacer()
                    Text("\(notificationManager.pendingNotificationsCount)")
                        .foregroundStyle(.secondary)
                }
            }
        } header: {
            Text("Reminders")
        } footer: {
            if notificationManager.authorizationStatus == .denied {
                Text("Notifications are disabled. Enable them in Settings to receive event reminders.")
            } else {
                Text("You'll receive reminders before events and birthdays.")
            }
        }
        .onAppear {
            Task {
                await notificationManager.refreshAuthorizationStatus()
                await notificationManager.updatePendingCount()
            }
        }
    }

    // MARK: - Notification Status Helpers

    private var notificationStatusColor: Color {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return .green
        case .denied:
            return .red
        case .notDetermined:
            return .orange
        @unknown default:
            return .gray
        }
    }

    private var notificationStatusText: String {
        switch notificationManager.authorizationStatus {
        case .authorized:
            return "Enabled"
        case .provisional:
            return "Provisional"
        case .ephemeral:
            return "Temporary"
        case .denied:
            return "Disabled"
        case .notDetermined:
            return "Not configured"
        @unknown default:
            return "Unknown"
        }
    }

    @ViewBuilder
    private var notificationStatusIcon: some View {
        switch notificationManager.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .denied:
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.red)
        case .notDetermined:
            Image(systemName: "questionmark.circle.fill")
                .foregroundStyle(.orange)
        @unknown default:
            Image(systemName: "circle.fill")
                .foregroundStyle(.gray)
        }
    }

    // MARK: - AI Section

    private var aiSection: some View {
        Section {
            Toggle("Smart Tagging", isOn: $smartTaggingEnabled)

            Toggle("Weekly Digests", isOn: $weeklyDigestsEnabled)
        } header: {
            Text("AI Features")
        } footer: {
            Text("All AI processing happens on your device. Your photos and data are never sent to external servers.")
        }
    }

    // MARK: - Export Section

    private var exportSection: some View {
        Section("Export & Backup") {
            Button(action: { showingExportSheet = true }) {
                Label("Generate PDF Memory Book", systemImage: "book.fill")
            }

            NavigationLink {
                BackupView()
            } label: {
                HStack {
                    Label("Backup & Restore", systemImage: "externaldrive.fill")

                    Spacer()

                    if let lastBackup = BackupService.shared.listAvailableBackups().first {
                        Text(lastBackup.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .sheet(isPresented: $showingExportSheet) {
            PDFExportView()
        }
    }

    // MARK: - Data Section

    private var dataSection: some View {
        Section("Data & Storage") {
            DataStatsRow()
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            HStack {
                Text("Version")
                Spacer()
                Text("1.0.0")
                    .foregroundStyle(.secondary)
            }

            Link(destination: URL(string: "https://daycatcher.app/privacy")!) {
                HStack {
                    Text("Privacy Policy")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
            }
            .foregroundStyle(themeManager.theme.textPrimary)

            Link(destination: URL(string: "https://daycatcher.app/terms")!) {
                HStack {
                    Text("Terms of Service")
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.caption)
                }
            }
            .foregroundStyle(themeManager.theme.textPrimary)
        }
    }
}

// MARK: - Theme Preview Card

struct ThemePreviewCard: View {
    let theme: AppTheme
    let isSelected: Bool

    var body: some View {
        VStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.theme.backgroundColor)
                .frame(width: 60, height: 80)
                .overlay {
                    VStack(spacing: 4) {
                        Circle()
                            .fill(theme.theme.primaryColor)
                            .frame(width: 20, height: 20)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.theme.secondaryColor)
                            .frame(width: 40, height: 8)

                        RoundedRectangle(cornerRadius: 2)
                            .fill(theme.theme.surfaceColor)
                            .frame(width: 40, height: 8)
                    }
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? theme.theme.primaryColor : Color.clear, lineWidth: 2)
                }

            Text(theme.displayName)
                .font(.caption2)
                .foregroundStyle(isSelected ? theme.theme.primaryColor : .secondary)
        }
    }
}

// MARK: - Data Stats Row

struct DataStatsRow: View {
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(sortDescriptors: []) private var lovedOnes: FetchedResults<LovedOne>
    @FetchRequest(sortDescriptors: []) private var memories: FetchedResults<Memory>
    @FetchRequest(sortDescriptors: []) private var events: FetchedResults<Event>

    private var accessibleMemoriesCount: Int {
        memories.filter { $0.isAccessible }.count
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Loved Ones")
                Spacer()
                Text("\(lovedOnes.count)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Memories")
                Spacer()
                Text("\(accessibleMemoriesCount)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Events")
                Spacer()
                Text("\(events.count)")
                    .foregroundStyle(.secondary)
            }

            HStack {
                Text("Storage Used")
                Spacer()
                Text(MediaManager.shared.formattedStorageUsed())
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - PDF Export View

struct PDFExportView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @StateObject private var pdfService = PDFExportService.shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LovedOne.name, ascending: true)]
    )
    private var lovedOnes: FetchedResults<LovedOne>

    @State private var selectedLovedOne: LovedOne?
    @State private var startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
    @State private var endDate = Date()
    @State private var includePhotos = true
    @State private var includeVideos = true
    @State private var includeMilestones = true
    @State private var showingShareSheet = false
    @State private var generatedPDFURL: URL?
    @State private var showingError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Select Person") {
                    Picker("Person", selection: $selectedLovedOne) {
                        Text("Select...").tag(nil as LovedOne?)
                        ForEach(lovedOnes) { lovedOne in
                            Text(lovedOne.name ?? "Unknown").tag(lovedOne as LovedOne?)
                        }
                    }
                }

                Section("Date Range") {
                    DatePicker("From", selection: $startDate, displayedComponents: .date)
                    DatePicker("To", selection: $endDate, displayedComponents: .date)
                }

                Section("Include") {
                    Toggle("Photos", isOn: $includePhotos)
                    Toggle("Videos", isOn: $includeVideos)
                    Toggle("Milestones & Events", isOn: $includeMilestones)
                }

                if pdfService.isGenerating {
                    Section {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(pdfService.currentStep)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)

                            ProgressView(value: pdfService.progress)
                                .progressViewStyle(.linear)

                            Text("\(Int(pdfService.progress * 100))% complete")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section {
                    Button(action: generatePDF) {
                        HStack {
                            Spacer()
                            if pdfService.isGenerating {
                                ProgressView()
                                    .padding(.trailing, 8)
                                Text("Generating...")
                            } else {
                                Image(systemName: "doc.richtext")
                                Text("Generate PDF")
                            }
                            Spacer()
                        }
                    }
                    .disabled(selectedLovedOne == nil || pdfService.isGenerating)
                }
            }
            .navigationTitle("Memory Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .disabled(pdfService.isGenerating)
                }
            }
            .sheet(isPresented: $showingShareSheet) {
                if let url = generatedPDFURL {
                    ShareSheet(items: [url])
                }
            }
            .alert("Error", isPresented: $showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func generatePDF() {
        guard let lovedOne = selectedLovedOne else { return }

        Task {
            do {
                let url = try await pdfService.generateMemoryBook(
                    for: lovedOne,
                    from: startDate,
                    to: endDate,
                    includePhotos: includePhotos,
                    includeVideos: includeVideos,
                    includeMilestones: includeMilestones,
                    in: viewContext
                )
                generatedPDFURL = url
                showingShareSheet = true
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
        .environmentObject(NotificationManager.shared)
}
