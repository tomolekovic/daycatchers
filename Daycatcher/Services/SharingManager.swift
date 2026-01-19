import Foundation
import CoreData
import CloudKit
import UIKit

/// SharingManager handles CloudKit sharing for LovedOne profiles.
/// Allows family members to view and add memories to shared profiles.
@MainActor
final class SharingManager: ObservableObject {
    static let shared = SharingManager()

    @Published var activeShares: [CKShare] = []
    @Published var isLoading = false
    @Published var error: Error?

    private let persistenceController = PersistenceController.shared

    private init() {}

    // MARK: - Share Management

    /// Get or create a CKShare for a LovedOne
    func getOrCreateShare(for lovedOne: LovedOne) async throws -> CKShare {
        // Check if share already exists
        if let existingShare = persistenceController.share(for: lovedOne) {
            return existingShare
        }

        // Create new share using NSPersistentCloudKitContainer
        let (_, share, _) = try await persistenceController.container.share(
            [lovedOne],
            to: nil
        )

        // Configure share settings
        share[CKShare.SystemFieldKey.title] = lovedOne.name ?? "Shared Profile"
        share.publicPermission = .none // Only invited participants

        // Update the lovedOne's shared status
        lovedOne.isSharedWithFamily = true
        persistenceController.save()

        // Upload media for all memories to the share zone so recipients can access them
        let shareZoneID = share.recordID.zoneID
        await uploadMediaToShareZone(for: lovedOne, zoneID: shareZoneID)

        // Refresh active shares
        await refreshActiveShares()

        return share
    }

    /// Upload all media associated with a LovedOne to the share zone
    /// This makes media accessible to share participants
    func uploadMediaToShareZone(for lovedOne: LovedOne, zoneID: CKRecordZone.ID) async {
        let memories = lovedOne.memories?.allObjects as? [Memory] ?? []

        print("[SharingManager] Uploading media for \(memories.count) memories to share zone: \(zoneID)")

        for memory in memories {
            guard memory.hasMedia, memory.memoryType != .text else { continue }
            await MediaSyncManager.shared.uploadMediaToSharedZone(for: memory, zoneID: zoneID)
        }

        // Also upload profile image if exists
        if let profileImagePath = lovedOne.profileImagePath {
            await MediaSyncManager.shared.uploadProfileImageToSharedZone(
                for: lovedOne,
                profileImagePath: profileImagePath,
                zoneID: zoneID
            )
        }

        print("[SharingManager] Finished uploading media to share zone")
    }

    /// Sync media to share zone for an existing share
    /// Call this when the owner views a shared profile to ensure media is uploaded
    func syncMediaForExistingShare(lovedOne: LovedOne) async {
        guard lovedOne.isSharedWithFamily else { return }
        guard let share = persistenceController.share(for: lovedOne) else { return }

        // Only sync if we're the owner
        guard persistenceController.isOwner(of: lovedOne) else { return }

        let shareZoneID = share.recordID.zoneID
        print("[SharingManager] Syncing media for existing share to zone: \(shareZoneID)")
        await uploadMediaToShareZone(for: lovedOne, zoneID: shareZoneID)
    }

    /// Stop sharing a LovedOne profile
    func stopSharing(_ lovedOne: LovedOne) async throws {
        guard let share = persistenceController.share(for: lovedOne) else {
            // Not currently shared
            lovedOne.isSharedWithFamily = false
            persistenceController.save()
            return
        }

        // Purge the share from CloudKit
        let container = CKContainer(identifier: PersistenceController.cloudKitContainerIdentifier)
        let database = container.privateCloudDatabase

        try await database.deleteRecord(withID: share.recordID)

        // Update local state
        lovedOne.isSharedWithFamily = false
        persistenceController.save()

        // Refresh active shares
        await refreshActiveShares()
    }

    /// Persist an updated share after changes via UICloudSharingController
    func persistUpdatedShare(_ share: CKShare, for lovedOne: LovedOne) {
        do {
            try persistenceController.container.persistUpdatedShare(share, in: persistenceController.privateStore!)
            lovedOne.isSharedWithFamily = true
            persistenceController.save()
        } catch {
            print("Failed to persist updated share: \(error)")
            self.error = error
        }

        // Refresh shares in background
        Task {
            await refreshActiveShares()
        }
    }

    // MARK: - Share Acceptance

    /// Accept a share from metadata (called when user taps share link)
    func acceptShare(from metadata: CKShare.Metadata) async throws {
        print("[SharingManager] acceptShare called")
        print("[SharingManager] Share root record ID: \(metadata.rootRecordID)")
        print("[SharingManager] Container ID: \(metadata.containerIdentifier)")

        let container = CKContainer(identifier: PersistenceController.cloudKitContainerIdentifier)

        print("[SharingManager] Accepting share...")
        try await container.accept(metadata)
        print("[SharingManager] Share accepted successfully")

        // Give CloudKit time to sync the shared data to the shared store
        print("[SharingManager] Waiting for CloudKit sync...")
        try await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds

        // Force a context refresh to pick up changes from the shared store
        await MainActor.run {
            persistenceController.viewContext.refreshAllObjects()
            print("[SharingManager] Context refreshed")
        }

        // Refresh to pick up new shared data
        await refreshActiveShares()

        // Log what we have after acceptance
        let sharedLovedOnes = getSharedLovedOnes()
        print("[SharingManager] After acceptance - shared loved ones count: \(sharedLovedOnes.count)")
        for lovedOne in sharedLovedOnes {
            print("[SharingManager] - \(lovedOne.name ?? "unknown")")
        }
    }

    // MARK: - Query Shares

    /// Refresh the list of active shares
    func refreshActiveShares() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let shares = try await fetchAllShares()
            activeShares = shares
        } catch {
            print("Failed to fetch shares: \(error)")
            self.error = error
        }
    }

    /// Fetch all shares from the persistent stores
    private func fetchAllShares() async throws -> [CKShare] {
        // Fetch all LovedOne objects
        let fetchRequest: NSFetchRequest<LovedOne> = LovedOne.fetchRequest()
        let lovedOnes = try persistenceController.viewContext.fetch(fetchRequest)

        // Get shares for each
        var shares: [CKShare] = []
        for lovedOne in lovedOnes {
            if let share = persistenceController.share(for: lovedOne) {
                shares.append(share)
            }
        }

        return shares
    }

    /// Get shared LovedOnes (profiles shared with or by the user)
    func getSharedLovedOnes() -> [LovedOne] {
        let fetchRequest: NSFetchRequest<LovedOne> = LovedOne.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isSharedWithFamily == YES")

        do {
            return try persistenceController.viewContext.fetch(fetchRequest)
        } catch {
            print("Failed to fetch shared loved ones: \(error)")
            return []
        }
    }

    /// Get the LovedOne associated with a share
    func lovedOne(for share: CKShare) -> LovedOne? {
        let fetchRequest: NSFetchRequest<LovedOne> = LovedOne.fetchRequest()
        let lovedOnes = (try? persistenceController.viewContext.fetch(fetchRequest)) ?? []

        for lovedOne in lovedOnes {
            if persistenceController.share(for: lovedOne)?.recordID == share.recordID {
                return lovedOne
            }
        }
        return nil
    }

    // MARK: - Participant Helpers

    /// Get a formatted string for participant count
    func participantCountText(for lovedOne: LovedOne) -> String {
        let participants = persistenceController.participants(for: lovedOne)
        let count = participants.count

        if count == 0 {
            return "Not shared"
        } else if count == 1 {
            return "Only you"
        } else {
            // Subtract 1 for the owner
            let others = count - 1
            return others == 1 ? "1 family member" : "\(others) family members"
        }
    }

    /// Get accepted participants (excluding pending)
    func acceptedParticipants(for lovedOne: LovedOne) -> [CKShare.Participant] {
        persistenceController.participants(for: lovedOne).filter {
            $0.acceptanceStatus == .accepted
        }
    }

    /// Get pending participants
    func pendingParticipants(for lovedOne: LovedOne) -> [CKShare.Participant] {
        persistenceController.participants(for: lovedOne).filter {
            $0.acceptanceStatus == .pending
        }
    }

    /// Check if user is owner of shared profile
    func isOwner(of lovedOne: LovedOne) -> Bool {
        persistenceController.isOwner(of: lovedOne)
    }

    /// Check if user can edit the profile
    func canEdit(_ lovedOne: LovedOne) -> Bool {
        persistenceController.canEdit(object: lovedOne)
    }
}

// MARK: - CKShare.Participant Extension

extension CKShare.Participant {
    /// Get a display name for the participant
    var displayName: String {
        if let name = userIdentity.nameComponents?.formatted() {
            return name
        }
        return "Unknown"
    }

    /// Get initials for the participant
    var initials: String {
        if let components = userIdentity.nameComponents {
            let first = components.givenName?.prefix(1) ?? ""
            let last = components.familyName?.prefix(1) ?? ""
            return "\(first)\(last)".uppercased()
        }
        return "?"
    }
}
