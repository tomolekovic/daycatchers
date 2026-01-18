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

            // Configure the persistent store description
            guard let description = container.persistentStoreDescriptions.first else {
                fatalError("Failed to retrieve persistent store description. Ensure Daycatcher.xcdatamodeld is added to the target.")
            }

            configureStore(description: description, inMemory: inMemory)
            loadStore()
            return
        }

        container = NSPersistentCloudKitContainer(name: "Daycatcher", managedObjectModel: model)

        // Configure the persistent store description
        guard let description = container.persistentStoreDescriptions.first else {
            fatalError("Failed to retrieve persistent store description. Ensure Daycatcher.xcdatamodeld is added to the target.")
        }

        configureStore(description: description, inMemory: inMemory)
        loadStore()
    }

    private func configureStore(description: NSPersistentStoreDescription, inMemory: Bool) {
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
    }

    private func loadStore() {
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
