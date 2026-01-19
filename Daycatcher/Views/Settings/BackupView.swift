import SwiftUI
import CoreData
import UniformTypeIdentifiers

struct BackupView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext

    @StateObject private var backupService = BackupService.shared

    @State private var backups: [BackupInfo] = []
    @State private var showingCreateConfirmation = false
    @State private var showingRestoreConfirmation = false
    @State private var showingDeleteConfirmation = false
    @State private var selectedBackupForRestore: BackupInfo?
    @State private var selectedBackupForDelete: BackupInfo?
    @State private var showingError = false
    @State private var errorMessage = ""
    @State private var showingRestoreSuccess = false
    @State private var restoreReport: RestoreReport?
    @State private var showingFilePicker = false

    var body: some View {
        List {
            // Status Section
            statusSection

            // Actions Section
            actionsSection

            // Backups List Section
            if !backups.isEmpty {
                backupsListSection
            }
        }
        .navigationTitle("Backup & Restore")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            refreshBackups()
        }
        .refreshable {
            refreshBackups()
        }
        .confirmationDialog(
            "Create Backup",
            isPresented: $showingCreateConfirmation,
            titleVisibility: .visible
        ) {
            Button("Create Backup") {
                createBackup()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will create a complete backup of all your data and media files.")
        }
        .confirmationDialog(
            "Restore Backup",
            isPresented: $showingRestoreConfirmation,
            titleVisibility: .visible
        ) {
            Button("Restore", role: .destructive) {
                if let backup = selectedBackupForRestore {
                    restoreBackup(backup)
                }
            }
            Button("Cancel", role: .cancel) {
                selectedBackupForRestore = nil
            }
        } message: {
            Text("This will replace ALL existing data with the backup. This action cannot be undone.")
        }
        .confirmationDialog(
            "Delete Backup",
            isPresented: $showingDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let backup = selectedBackupForDelete {
                    deleteBackup(backup)
                }
            }
            Button("Cancel", role: .cancel) {
                selectedBackupForDelete = nil
            }
        } message: {
            Text("Are you sure you want to delete this backup?")
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage)
        }
        .alert("Restore Complete", isPresented: $showingRestoreSuccess) {
            Button("OK", role: .cancel) { }
        } message: {
            if let report = restoreReport {
                Text("Restored \(report.lovedOnesRestored) loved ones, \(report.memoriesRestored) memories, \(report.eventsRestored) events, and \(report.mediaFilesRestored) media files.")
            }
        }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [UTType.zip],
            allowsMultipleSelection: false
        ) { result in
            handleImportedFile(result)
        }
    }

    // MARK: - Status Section

    private var statusSection: some View {
        Section {
            if backupService.isBackingUp || backupService.isRestoring {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        ProgressView()
                            .padding(.trailing, 4)

                        Text(backupService.currentStep)
                            .font(.subheadline)
                    }

                    ProgressView(value: backupService.progress)
                        .progressViewStyle(.linear)

                    Text("\(Int(backupService.progress * 100))% complete")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 4)
            } else {
                HStack {
                    Image(systemName: "externaldrive.fill")
                        .foregroundStyle(.blue)
                        .font(.title2)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Backup Status")
                            .font(.headline)

                        if let lastBackup = backups.first {
                            Text("Last backup: \(lastBackup.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("No backups available")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    if !backups.isEmpty {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
        } header: {
            Text("Status")
        } footer: {
            Text("Total backup storage: \(backupService.formattedBackupsSize())")
        }
    }

    // MARK: - Actions Section

    private var actionsSection: some View {
        Section("Actions") {
            Button(action: { showingCreateConfirmation = true }) {
                Label("Create Backup Now", systemImage: "arrow.down.doc.fill")
            }
            .disabled(backupService.isBackingUp || backupService.isRestoring)

            Button(action: { showingFilePicker = true }) {
                Label("Import Backup from Files", systemImage: "folder")
            }
            .disabled(backupService.isBackingUp || backupService.isRestoring)
        }
    }

    // MARK: - Backups List Section

    private var backupsListSection: some View {
        Section("Available Backups") {
            ForEach(backups) { backup in
                BackupRow(backup: backup)
                    .contentShape(Rectangle())
                    .contextMenu {
                        Button(action: {
                            selectedBackupForRestore = backup
                            showingRestoreConfirmation = true
                        }) {
                            Label("Restore", systemImage: "arrow.clockwise")
                        }

                        Button(action: {
                            shareBackup(backup)
                        }) {
                            Label("Share", systemImage: "square.and.arrow.up")
                        }

                        Divider()

                        Button(role: .destructive, action: {
                            selectedBackupForDelete = backup
                            showingDeleteConfirmation = true
                        }) {
                            Label("Delete", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            selectedBackupForDelete = backup
                            showingDeleteConfirmation = true
                        } label: {
                            Label("Delete", systemImage: "trash")
                        }

                        Button {
                            selectedBackupForRestore = backup
                            showingRestoreConfirmation = true
                        } label: {
                            Label("Restore", systemImage: "arrow.clockwise")
                        }
                        .tint(.blue)
                    }
            }
        }
    }

    // MARK: - Actions

    private func refreshBackups() {
        backups = backupService.listAvailableBackups()
    }

    private func createBackup() {
        Task {
            do {
                _ = try await backupService.createBackup(context: viewContext)
                refreshBackups()
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func restoreBackup(_ backup: BackupInfo) {
        Task {
            do {
                let report = try await backupService.restoreFromBackup(url: backup.url, context: viewContext)
                restoreReport = report
                showingRestoreSuccess = true
            } catch {
                errorMessage = error.localizedDescription
                showingError = true
            }
        }
    }

    private func deleteBackup(_ backup: BackupInfo) {
        do {
            try backupService.deleteBackup(backup)
            refreshBackups()
        } catch {
            errorMessage = error.localizedDescription
            showingError = true
        }
    }

    private func shareBackup(_ backup: BackupInfo) {
        let activityVC = UIActivityViewController(
            activityItems: [backup.url],
            applicationActivities: nil
        )

        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootVC = window.rootViewController {
            rootVC.present(activityVC, animated: true)
        }
    }

    private func handleImportedFile(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }

            // Copy file to backups directory and restore
            Task {
                do {
                    // Start accessing security-scoped resource
                    guard url.startAccessingSecurityScopedResource() else {
                        throw BackupError.invalidBackup("Cannot access the selected file")
                    }
                    defer { url.stopAccessingSecurityScopedResource() }

                    // Copy to backups directory
                    let backupsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("Backups", isDirectory: true)
                    try? FileManager.default.createDirectory(at: backupsDir, withIntermediateDirectories: true)

                    let destURL = backupsDir.appendingPathComponent(url.lastPathComponent)
                    try? FileManager.default.removeItem(at: destURL)
                    try FileManager.default.copyItem(at: url, to: destURL)

                    // Refresh and show the new backup
                    await MainActor.run {
                        refreshBackups()
                    }
                } catch {
                    await MainActor.run {
                        errorMessage = error.localizedDescription
                        showingError = true
                    }
                }
            }

        case .failure(let error):
            errorMessage = error.localizedDescription
            showingError = true
        }
    }
}

// MARK: - Backup Row

struct BackupRow: View {
    let backup: BackupInfo

    var body: some View {
        HStack {
            Image(systemName: "doc.zipper")
                .foregroundStyle(.blue)
                .font(.title2)

            VStack(alignment: .leading, spacing: 4) {
                Text(backup.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.headline)

                HStack(spacing: 12) {
                    Label("\(backup.lovedOnesCount)", systemImage: "person.fill")
                    Label("\(backup.memoriesCount)", systemImage: "photo.fill")
                    Label("\(backup.eventsCount)", systemImage: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)

                Text(formattedSize)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .foregroundStyle(.tertiary)
                .font(.caption)
        }
        .padding(.vertical, 4)
    }

    private var formattedSize: String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: backup.size)
    }
}

#Preview {
    NavigationStack {
        BackupView()
    }
    .environmentObject(ThemeManager())
}
