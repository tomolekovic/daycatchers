import SwiftUI
import CoreData

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext
    @ObservedObject var persistenceController = PersistenceController.shared

    @AppStorage("smartTaggingEnabled") private var smartTaggingEnabled = true
    @AppStorage("weeklyDigestsEnabled") private var weeklyDigestsEnabled = true
    @AppStorage("birthdayRemindersEnabled") private var birthdayRemindersEnabled = true
    @AppStorage("defaultReminderOffset") private var defaultReminderOffset = ReminderOffset.oneDay.rawValue

    @State private var showingFamilySheet = false
    @State private var showingExportSheet = false
    @State private var showingBackupSheet = false

    var body: some View {
        NavigationStack {
            Form {
                // Appearance
                appearanceSection

                // iCloud Sync
                syncSection

                // Family Sharing
                familySharingSection

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
            Button(action: { showingFamilySheet = true }) {
                HStack {
                    Image(systemName: "person.2.fill")
                        .foregroundStyle(themeManager.theme.primaryColor)

                    Text("Manage Family")

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .foregroundStyle(themeManager.theme.textPrimary)
        } header: {
            Text("Family Sharing")
        } footer: {
            Text("Share specific loved ones with family members so everyone can contribute memories.")
        }
        .sheet(isPresented: $showingFamilySheet) {
            FamilySharingView()
        }
    }

    // MARK: - Reminders Section

    private var remindersSection: some View {
        Section("Reminders") {
            Toggle("Birthday Reminders", isOn: $birthdayRemindersEnabled)

            Picker("Default Reminder Timing", selection: $defaultReminderOffset) {
                ForEach(ReminderOffset.allCases) { offset in
                    Text(offset.displayName).tag(offset.rawValue)
                }
            }
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

            Button(action: {}) {
                Label("Export All Media", systemImage: "square.and.arrow.up")
            }

            Button(action: { showingBackupSheet = true }) {
                Label("Create Backup", systemImage: "externaldrive.fill")
            }

            Button(action: {}) {
                Label("Restore from Backup", systemImage: "arrow.clockwise")
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
                Text("\(memories.count)")
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

// MARK: - Family Sharing View

struct FamilySharingView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: themeManager.theme.spacingLarge) {
                Spacer()

                Image(systemName: "person.2.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(themeManager.theme.primaryColor.opacity(0.5))

                Text("Family Sharing")
                    .font(themeManager.theme.titleFont)

                Text("Create a family group to share memories of your loved ones with family members.")
                    .font(themeManager.theme.bodyFont)
                    .foregroundStyle(themeManager.theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)

                Button(action: {}) {
                    Text("Create Family")
                        .font(themeManager.theme.headlineFont)
                        .foregroundStyle(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(themeManager.theme.primaryColor)
                        .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))
                }
                .padding(.horizontal, 40)

                Spacer()
            }
            .navigationTitle("Family Sharing")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - PDF Export View

struct PDFExportView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.managedObjectContext) private var viewContext

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LovedOne.name, ascending: true)]
    )
    private var lovedOnes: FetchedResults<LovedOne>

    @State private var selectedLovedOne: LovedOne?
    @State private var startDate = Calendar.current.date(byAdding: .year, value: -1, to: Date())!
    @State private var endDate = Date()
    @State private var includePhotos = true
    @State private var includeMilestones = true
    @State private var isGenerating = false

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
                    Toggle("Photos & Videos", isOn: $includePhotos)
                    Toggle("Milestones & Events", isOn: $includeMilestones)
                }

                Section {
                    Button(action: generatePDF) {
                        if isGenerating {
                            HStack {
                                ProgressView()
                                Text("Generating...")
                            }
                        } else {
                            Text("Generate PDF")
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .disabled(selectedLovedOne == nil || isGenerating)
                }
            }
            .navigationTitle("Memory Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func generatePDF() {
        guard let lovedOne = selectedLovedOne else { return }
        isGenerating = true

        // TODO: Implement PDF generation
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            isGenerating = false
            dismiss()
        }
    }
}

#Preview {
    SettingsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
        .environmentObject(ThemeManager())
}
