import SwiftUI
import CoreData
import BackgroundTasks
import UserNotifications

@main
struct DaycatcherApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    let persistenceController = PersistenceController.shared
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var notificationManager = NotificationManager.shared

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
                .environmentObject(notificationManager)
                .task {
                    // Skip operations during tests
                    guard !Self.isRunningTests else { return }

                    // Setup notification categories
                    notificationManager.setupNotificationCategories()

                    // Check sync status and retry any pending uploads on launch
                    await MediaSyncManager.shared.checkSyncStatus()
                    await MediaSyncManager.shared.retryFailedUploads()

                    // Refresh notification authorization status
                    await notificationManager.refreshAuthorizationStatus()
                    await notificationManager.updatePendingCount()

                    // Generate any missing weekly digests
                    await DigestService.shared.generateMissingDigests(in: persistenceController.container.viewContext)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)) { _ in
                    // Skip background scheduling during tests
                    guard !Self.isRunningTests else { return }

                    // Schedule background upload when entering background
                    scheduleMediaUploadTask()
                }
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Clear badge when app becomes active
                    notificationManager.clearBadge()
                }
                .onReceive(NotificationCenter.default.publisher(for: .reschedulebirthday)) { notification in
                    handleBirthdayReschedule(notification)
                }
        }
    }

    // MARK: - Birthday Rescheduling

    private func handleBirthdayReschedule(_ notification: Foundation.Notification) {
        guard let userInfo = notification.userInfo,
              let eventIdString = userInfo["eventId"] as? String,
              let eventId = UUID(uuidString: eventIdString),
              let year = userInfo["year"] as? Int else {
            return
        }

        // Fetch the event and reschedule for next year
        let context = persistenceController.container.viewContext
        let fetchRequest: NSFetchRequest<Event> = Event.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "id == %@", eventId as CVarArg)
        fetchRequest.fetchLimit = 1

        do {
            if let event = try context.fetch(fetchRequest).first {
                Task {
                    await notificationManager.scheduleBirthdayForNextYear(event: event, currentYear: year)
                }
            }
        } catch {
            print("Failed to fetch event for birthday reschedule: \(error)")
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

// MARK: - AppDelegate

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification delegate
        UNUserNotificationCenter.current().delegate = NotificationManager.shared
        return true
    }
}
