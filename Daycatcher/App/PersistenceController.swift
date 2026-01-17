import CoreData
import CloudKit

/// PersistenceController manages the Core Data stack with CloudKit integration.
/// Uses NSPersistentCloudKitContainer for automatic sync to iCloud.
final class PersistenceController: ObservableObject {
    static let shared = PersistenceController()

    /// The CloudKit container identifier
    static let cloudKitContainerIdentifier = "iCloud.com.tko.momentvault"

    /// The Core Data container with CloudKit sync
    let container: NSPersistentCloudKitContainer

    /// Published sync status for UI observation
    @Published var syncStatus: SyncStatus = .idle

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
        container = NSPersistentCloudKitContainer(name: "Daycatcher")

        // Configure the persistent store description
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description")
        }

        if inMemory {
            description.url = URL(fileURLWithPath: "/dev/null")
            description.cloudKitContainerOptions = nil
        } else {
            // Configure CloudKit sync
            let cloudKitOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Self.cloudKitContainerIdentifier
            )

            // Enable history tracking for CloudKit sync
            description.setOption(true as NSNumber, forKey: NSPersistentHistoryTrackingKey)
            description.setOption(true as NSNumber, forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            description.cloudKitContainerOptions = cloudKitOptions
        }

        // Load the persistent store
        container.loadPersistentStores { storeDescription, error in
            if let error = error as NSError? {
                // In production, handle this gracefully
                fatalError("Unresolved error \(error), \(error.userInfo)")
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

    // MARK: - CloudKit Sharing Support

    /// Returns the CKShare for a given managed object, if it exists
    func share(for object: NSManagedObject) -> CKShare? {
        guard let persistentStore = object.objectID.persistentStore else { return nil }

        do {
            let shares = try container.fetchShares(matching: [object.objectID])
            return shares[object.objectID]
        } catch {
            print("Failed to fetch share: \(error)")
            return nil
        }
    }

    /// Creates or returns existing share for a managed object
    func getOrCreateShare(for object: NSManagedObject) async throws -> (CKShare, CKContainer) {
        let (objectIDs, share, ckContainer) = try await container.share([object], to: nil)
        return (share, ckContainer)
    }

    /// Check if an object is shared
    func isShared(object: NSManagedObject) -> Bool {
        isShared(objectID: object.objectID)
    }

    func isShared(objectID: NSManagedObjectID) -> Bool {
        var isShared = false
        if let persistentStore = objectID.persistentStore {
            do {
                let shares = try container.fetchShares(matching: [objectID])
                isShared = shares.first != nil
            } catch {
                print("Failed to fetch shares: \(error)")
            }
        }
        return isShared
    }

    /// Returns participants for a shared object
    func participants(for object: NSManagedObject) -> [CKShare.Participant] {
        guard let share = share(for: object) else { return [] }
        return Array(share.participants)
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
}
