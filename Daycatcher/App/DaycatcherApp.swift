import SwiftUI
import CoreData
import BackgroundTasks
import UserNotifications
import CloudKit

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

                    // Allow time for CloudKit shared store zone to initialize
                    // Then mark the shared store as ready for access
                    try? await Task.sleep(for: .seconds(2))
                    persistenceController.markSharedStoreReady()

                    // Generate any missing weekly digests (now safe since shared store is ready)
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
                .onOpenURL { url in
                    // Handle CloudKit share URLs
                    handleIncomingURL(url)
                }
        }
    }

    // MARK: - URL Handling

    private func handleIncomingURL(_ url: URL) {
        print("[DaycatcherApp] Received URL: \(url)")

        // Check if this is a CloudKit share URL
        // CloudKit share URLs typically have the format: https://www.icloud.com/share/...
        guard url.scheme == "https" || url.scheme == "cloudkit" else {
            print("[DaycatcherApp] Not a CloudKit URL, ignoring")
            return
        }

        // For CloudKit share URLs, the system should automatically call
        // application(_:userDidAcceptCloudKitShareWith:) on the AppDelegate.
        // This handler is a backup for any URL-based share acceptance.
        print("[DaycatcherApp] CloudKit URL detected, system will handle via AppDelegate")
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

    // MARK: - CloudKit Share Acceptance

    func application(
        _ application: UIApplication,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        print("[AppDelegate] userDidAcceptCloudKitShareWith called")
        print("[AppDelegate] Share metadata - containerID: \(cloudKitShareMetadata.containerIdentifier)")
        print("[AppDelegate] Share metadata - rootRecordID: \(cloudKitShareMetadata.rootRecordID)")

        // Handle share acceptance when user taps a share link
        Task { @MainActor in
            do {
                print("[AppDelegate] Accepting share...")
                try await SharingManager.shared.acceptShare(from: cloudKitShareMetadata)
                print("[AppDelegate] Share accepted successfully")
            } catch {
                print("[AppDelegate] Failed to accept CloudKit share: \(error)")
            }
        }
    }

    // MARK: - Scene Configuration

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        // Check if there's a CloudKit share in the connection options
        if let cloudKitShareMetadata = options.cloudKitShareMetadata {
            print("[AppDelegate] Scene connecting with CloudKit share metadata")
            Task { @MainActor in
                do {
                    try await SharingManager.shared.acceptShare(from: cloudKitShareMetadata)
                } catch {
                    print("[AppDelegate] Failed to accept share from scene options: \(error)")
                }
            }
        }

        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
}

// MARK: - SceneDelegate

class SceneDelegate: NSObject, UIWindowSceneDelegate {
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        print("[SceneDelegate] userDidAcceptCloudKitShareWith called")
        print("[SceneDelegate] Share metadata - containerID: \(cloudKitShareMetadata.containerIdentifier)")

        Task { @MainActor in
            do {
                print("[SceneDelegate] Accepting share...")
                try await SharingManager.shared.acceptShare(from: cloudKitShareMetadata)
                print("[SceneDelegate] Share accepted successfully")
            } catch {
                print("[SceneDelegate] Failed to accept CloudKit share: \(error)")
            }
        }
    }
}
