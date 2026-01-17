import SwiftUI
import CoreData
import BackgroundTasks

@main
struct DaycatcherApp: App {
    let persistenceController = PersistenceController.shared
    @StateObject private var themeManager = ThemeManager()

    // Background task identifier for media uploads
    static let mediaUploadTaskIdentifier = "com.daycatcher.app.mediaupload"

    // Check if running in test environment
    private static var isRunningTests: Bool {
        ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil
    }

    init() {
        // Only register background tasks if not in test environment
        if !Self.isRunningTests {
            registerBackgroundTasks()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(\.managedObjectContext, persistenceController.container.viewContext)
                .environmentObject(themeManager)
                .environmentObject(MediaSyncManager.shared)
                .task {
                    // Skip sync operations during tests
                    guard !Self.isRunningTests else { return }

                    // Check sync status and retry any pending uploads on launch
                    await MediaSyncManager.shared.checkSyncStatus()
                    await MediaSyncManager.shared.retryFailedUploads()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Skip background scheduling during tests
                    guard !Self.isRunningTests else { return }

                    // Schedule background upload when entering background
                    scheduleMediaUploadTask()
                }
        }
    }

    // MARK: - Background Tasks

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: Self.mediaUploadTaskIdentifier,
            using: nil
        ) { task in
            self.handleMediaUploadTask(task as! BGProcessingTask)
        }
    }

    private func scheduleMediaUploadTask() {
        // Only schedule if there are pending uploads
        guard MediaSyncManager.shared.pendingUploads > 0 else { return }

        let request = BGProcessingTaskRequest(identifier: Self.mediaUploadTaskIdentifier)
        request.requiresNetworkConnectivity = true
        request.requiresExternalPower = false

        do {
            try BGTaskScheduler.shared.submit(request)
        } catch {
            print("Failed to schedule background upload: \(error)")
        }
    }

    private func handleMediaUploadTask(_ task: BGProcessingTask) {
        // Set expiration handler
        task.expirationHandler = {
            MediaSyncManager.shared.cancelPendingOperations()
        }

        // Perform the upload
        Task {
            await MediaSyncManager.shared.retryFailedUploads()

            // Mark task as complete
            task.setTaskCompleted(success: true)

            // Schedule next task if there are still pending uploads
            if MediaSyncManager.shared.pendingUploads > 0 {
                scheduleMediaUploadTask()
            }
        }
    }
}
