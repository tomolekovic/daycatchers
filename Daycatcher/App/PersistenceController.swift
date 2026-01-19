import CoreData
import CloudKit

/// PersistenceController manages the Core Data stack with CloudKit integration.
/// Uses NSPersistentCloudKitContainer for automatic sync to iCloud.
/// Configured with TWO stores: private (user's data) and shared (data shared with user).
final class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    /// The CloudKit container identifier
    static let cloudKitContainerIdentifier = "iCloud.com.tko.momentvault"

    /// The Core Data container with CloudKit sync
    let container: NSPersistentCloudKitContainer

    /// Reference to the private store (user's own data)
    private(set) var privateStore: NSPersistentStore?

    /// Reference to the shared store (data shared with user from others)
    private(set) var sharedStore: NSPersistentStore?

    /// Published sync status for UI observation
    @Published var syncStatus: SyncStatus = .idle

    /// Flag indicating whether the shared store is ready for access.
    /// On app launch, the shared store's CloudKit zone may not be immediately available.
    /// Objects from the shared store should not be accessed until this is true.
    @Published var isSharedStoreReady: Bool = false

    enum SyncStatus: Equatable {
        case idle
        case syncing
        case synced(Date)
        case error(String)
    }

    /// The view context for main thread operations
    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Background context for heavy operations
    func newBackgroundContext() -> NSManagedObjectContext {
        let context = container.newBackgroundContext()
        context.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
        return context
    }

    // MARK: - Initialization

    init(inMemory: Bool = false) {
        // Explicitly load the managed object model from the bundle
        guard let modelURL = Bundle.main.url(forResource: "Daycatcher", withExtension: "momd"),
              let model = NSManagedObjectModel(contentsOf: modelURL) else {
            // Fallback: try to load without .momd extension (development)
            if let altURL = Bundle.main.url(forResource: "Daycatcher", withExtension: "mom"),
               let altModel = NSManagedObjectModel(contentsOf: altURL) {
                container = NSPersistentCloudKitContainer(name: "Daycatcher", managedObjectModel: altModel)
            } else {
                // Last resort: let the container find it
                container = NSPersistentCloudKitContainer(name: "Daycatcher")
            }

            configureStores(inMemory: inMemory)
            loadStores()
            return
        }

        container = NSPersistentCloudKitContainer(name: "Daycatcher", managedObjectModel: model)
        configureStores(inMemory: inMemory)
        loadStores()
    }

    private func configureStores(inMemory: Bool) {
        // Get the default store URL from the first description
        guard let defaultDescription = container.persistentStoreDescriptions.first,
              let defaultURL = defaultDescription.url else {
            fatalError("Failed to retrieve persistent store description.")
        }

        if inMemory {
            defaultDescription.url = URL(fileURLWithPath: "/dev/null")
            defaultDescription.cloudKitContainerOptions = nil
            return
        }

        // MARK: - Configure Private Store (user's own data)
        let privateStoreURL = defaultURL.deletingLastPathComponent()
            .appendingPathComponent("Daycatcher-private.sqlite")

        let privateDescription = NSPersistentStoreDescription(url: privateStoreURL)
        let privateOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: Self.cloudKitContainerIdentifier
        )
        privateOptions.databaseScope = .private
        privateDescription.cloudKitContainerOptions = privateOptions
        privateDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        privateDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // MARK: - Configure Shared Store (data shared with user from others)
        let sharedStoreURL = defaultURL.deletingLastPathComponent()
            .appendingPathComponent("Daycatcher-shared.sqlite")

        let sharedDescription = NSPersistentStoreDescription(url: sharedStoreURL)
        let sharedOptions = NSPersistentCloudKitContainerOptions(
            containerIdentifier: Self.cloudKitContainerIdentifier
        )
        sharedOptions.databaseScope = .shared
        sharedDescription.cloudKitContainerOptions = sharedOptions
        sharedDescription.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
        sharedDescription.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

        // Replace the default descriptions with our configured ones
        container.persistentStoreDescriptions = [privateDescription, sharedDescription]

        print("[PersistenceController] Configured stores:")
        print("[PersistenceController] - Private store: \(privateStoreURL)")
        print("[PersistenceController] - Shared store: \(sharedStoreURL)")
    }

    private func loadStores() {
        // Load the persistent stores
        container.loadPersistentStores { [weak self] storeDescription, error in
            if let error = error as NSError? {
                // In production, handle this gracefully
                fatalError("Unresolved error \(error), \(error.userInfo)")
            }

            // Store references based on URL
            if let url = storeDescription.url,
               let store = self?.container.persistentStoreCoordinator.persistentStore(for: url) {
                if url.lastPathComponent.contains("shared") {
                    self?.sharedStore = store
                    print("[PersistenceController] Loaded shared store: \(url.lastPathComponent)")
                } else {
                    self?.privateStore = store
                    print("[PersistenceController] Loaded private store: \(url.lastPathComponent)")
                }
            }
        }

        // Configure the view context
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy

        // Set up remote change notification observer
        setupRemoteChangeNotifications()
    }

    // MARK: - Remote Change Notifications

    private func setupRemoteChangeNotifications() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
    }

    @objc private func handleRemoteChange(_ notification: Notification) {
        DispatchQueue.main.async {
            self.syncStatus = .synced(Date())

            // Refresh all objects to pick up remote changes.
            // This is essential for properly handling deletions from other devices.
            self.viewContext.refreshAllObjects()

            // Post notification so views can react to remote changes
            // (e.g., dismiss detail views for deleted objects)
            NotificationCenter.default.post(name: .coreDataRemoteChangeProcessed, object: nil)
        }
    }

    // MARK: - Save

    func save() {
        let context = viewContext
        guard context.hasChanges else { return }

        do {
            try context.save()
        } catch {
            let nsError = error as NSError
            // In production, handle this gracefully
            print("Unresolved error \(nsError), \(nsError.userInfo)")
        }
    }

    // MARK: - Preview Support

    static var preview: PersistenceController = {
        let controller = PersistenceController(inMemory: true)
        let context = controller.viewContext

        // Create sample data for previews
        let lovedOne = LovedOne(context: context)
        lovedOne.id = UUID()
        lovedOne.name = "Emma"
        lovedOne.birthDate = Calendar.current.date(byAdding: .year, value: -3, to: Date())
        lovedOne.relationship = RelationshipType.child.rawValue
        lovedOne.createdAt = Date()

        let memory = Memory(context: context)
        memory.id = UUID()
        memory.title = "First Day at the Park"
        memory.notes = "Emma loved the swings!"
        memory.type = MemoryType.photo.rawValue
        memory.captureDate = Date()
        memory.createdAt = Date()
        memory.lovedOne = lovedOne

        do {
            try context.save()
        } catch {
            print("Preview data save error: \(error)")
        }

        return controller
    }()

    // MARK: - CloudKit Sharing Helpers

    /// Check if a managed object is shared via CloudKit
    func isShared(object: NSManagedObject) -> Bool {
        isShared(objectID: object.objectID)
    }

    /// Check if an object ID is shared via CloudKit
    func isShared(objectID: NSManagedObjectID) -> Bool {
        var isShared = false
        if let persistentStore = objectID.persistentStore {
            if persistentStore == sharedStore {
                isShared = true
            } else {
                do {
                    let shares = try container.fetchShares(matching: [objectID])
                    isShared = !shares.isEmpty
                } catch {
                    print("Failed to fetch shares for object: \(error)")
                }
            }
        }
        return isShared
    }

    /// Get the CKShare for a managed object, if one exists
    func share(for object: NSManagedObject) -> CKShare? {
        do {
            let shares = try container.fetchShares(matching: [object.objectID])
            return shares[object.objectID]
        } catch {
            print("Failed to fetch share for object: \(error)")
            return nil
        }
    }

    /// Get participants for a shared object
    func participants(for object: NSManagedObject) -> [CKShare.Participant] {
        guard let share = share(for: object) else { return [] }
        return share.participants
    }

    /// Check if the current user can edit the object
    func canEdit(object: NSManagedObject) -> Bool {
        // If not shared, owner can always edit
        guard isShared(object: object) else { return true }

        // If shared, check participant permission
        if let share = share(for: object),
           let currentUser = share.currentUserParticipant {
            return currentUser.permission == .readWrite
        }

        // Default to read-only if we can't determine permissions
        return false
    }

    /// Check if the current user is the owner of the share
    func isOwner(of object: NSManagedObject) -> Bool {
        // If not shared, user owns it
        guard isShared(object: object) else { return true }

        // If shared, check if user is owner
        if let share = share(for: object),
           let currentUser = share.currentUserParticipant {
            return currentUser.role == .owner
        }

        return false
    }

    /// Get the persistent store for an object
    func persistentStore(for object: NSManagedObject) -> NSPersistentStore? {
        return object.objectID.persistentStore
    }

    /// Check if an object is from the shared store (i.e., shared with us by someone else)
    /// This is different from isShared - isFromSharedStore means we received this via a share,
    /// while isShared means we may have shared it or received it.
    func isFromSharedStore(object: NSManagedObject) -> Bool {
        guard let persistentStore = object.objectID.persistentStore else { return false }
        return persistentStore == sharedStore
    }

    /// Check if a Memory is from the shared store
    func isFromSharedStore(memory: Memory) -> Bool {
        return isFromSharedStore(object: memory)
    }

    /// Mark the shared store as ready for access.
    /// Call this after allowing time for CloudKit to initialize.
    func markSharedStoreReady() {
        DispatchQueue.main.async {
            self.isSharedStoreReady = true
            print("[PersistenceController] Shared store marked as ready")
        }
    }

    /// Check if a managed object is safe to access.
    /// Returns false for shared store objects until isSharedStoreReady is true.
    func isObjectAccessible(_ object: NSManagedObject) -> Bool {
        // Must have a managed object context
        guard object.managedObjectContext != nil else { return false }

        // Must have a valid persistent store
        guard let persistentStore = object.objectID.persistentStore else { return false }

        // Temporary objects are always accessible
        if object.objectID.isTemporaryID { return true }

        // For shared store objects, check if the shared store is ready
        if persistentStore == sharedStore && !isSharedStoreReady {
            return false
        }

        return true
    }
}

// MARK: - Notification Names

extension Notification.Name {
    /// Posted after a Core Data remote change has been processed.
    /// Views should listen for this to refresh their state and handle deleted objects.
    static let coreDataRemoteChangeProcessed = Notification.Name("coreDataRemoteChangeProcessed")
}
