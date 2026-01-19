import XCTest
import CoreData
import CloudKit
@testable import Daycatcher

/// Tests for the Family Sharing feature (Phase 9)
/// Note: Full CloudKit sharing requires a real device with iCloud account.
/// These tests cover the testable portions of the sharing logic.
final class SharingManagerTests: XCTestCase {

    var testContext: NSManagedObjectContext!
    var persistenceController: PersistenceController!

    override func setUpWithError() throws {
        persistenceController = PersistenceController(inMemory: true)
        testContext = persistenceController.viewContext
    }

    override func tearDownWithError() throws {
        testContext = nil
        persistenceController = nil
    }

    // MARK: - LovedOne isSharedWithFamily Property Tests

    func testLovedOneIsSharedWithFamilyDefaultsFalse() throws {
        // Given: A new LovedOne
        let lovedOne = createTestLovedOne(name: "Test Child")

        // Then: isSharedWithFamily should default to false
        XCTAssertFalse(lovedOne.isSharedWithFamily, "New LovedOne should not be shared by default")
    }

    func testLovedOneIsSharedWithFamilyCanBeSet() throws {
        // Given: A LovedOne
        let lovedOne = createTestLovedOne(name: "Test Child")

        // When: Setting isSharedWithFamily to true
        lovedOne.isSharedWithFamily = true
        try testContext.save()

        // Then: The value should persist
        XCTAssertTrue(lovedOne.isSharedWithFamily, "isSharedWithFamily should be true after setting")
    }

    func testLovedOneIsSharedWithFamilyPersistsAfterFetch() throws {
        // Given: A LovedOne with isSharedWithFamily = true
        let lovedOne = createTestLovedOne(name: "Shared Child")
        lovedOne.isSharedWithFamily = true
        try testContext.save()

        let lovedOneID = lovedOne.objectID

        // When: Fetching the LovedOne again
        testContext.reset()
        let fetchedLovedOne = try testContext.existingObject(with: lovedOneID) as! LovedOne

        // Then: isSharedWithFamily should still be true
        XCTAssertTrue(fetchedLovedOne.isSharedWithFamily, "isSharedWithFamily should persist after fetch")
    }

    // MARK: - PersistenceController Sharing Helper Tests

    func testIsSharedReturnsFalseForUnsharedObject() throws {
        // Given: A LovedOne that is not shared
        let lovedOne = createTestLovedOne(name: "Unshared Child")
        try testContext.save()

        // When: Checking if it's shared
        let isShared = persistenceController.isShared(object: lovedOne)

        // Then: Should return false (no CKShare exists)
        XCTAssertFalse(isShared, "Unshared object should return false for isShared")
    }

    func testShareForReturnsNilForUnsharedObject() throws {
        // Given: A LovedOne that is not shared
        let lovedOne = createTestLovedOne(name: "Unshared Child")
        try testContext.save()

        // When: Getting the share
        let share = persistenceController.share(for: lovedOne)

        // Then: Should return nil
        XCTAssertNil(share, "Unshared object should return nil for share")
    }

    func testParticipantsReturnsEmptyForUnsharedObject() throws {
        // Given: A LovedOne that is not shared
        let lovedOne = createTestLovedOne(name: "Unshared Child")
        try testContext.save()

        // When: Getting participants
        let participants = persistenceController.participants(for: lovedOne)

        // Then: Should return empty array
        XCTAssertTrue(participants.isEmpty, "Unshared object should have no participants")
    }

    func testCanEditReturnsTrueForUnsharedObject() throws {
        // Given: A LovedOne that is not shared (user owns it)
        let lovedOne = createTestLovedOne(name: "My Child")
        try testContext.save()

        // When: Checking if user can edit
        let canEdit = persistenceController.canEdit(object: lovedOne)

        // Then: Should return true (owner can always edit their own objects)
        XCTAssertTrue(canEdit, "Owner should be able to edit their own unshared object")
    }

    func testIsOwnerReturnsTrueForUnsharedObject() throws {
        // Given: A LovedOne that is not shared
        let lovedOne = createTestLovedOne(name: "My Child")
        try testContext.save()

        // When: Checking if user is owner
        let isOwner = persistenceController.isOwner(of: lovedOne)

        // Then: Should return true (user owns unshared objects)
        XCTAssertTrue(isOwner, "User should be owner of their own unshared object")
    }

    // MARK: - SharingManager State Tests

    @MainActor
    func testSharingManagerSharedInstanceExists() {
        // Given/When: Accessing the shared instance
        let manager = SharingManager.shared

        // Then: It should exist and be properly initialized
        XCTAssertNotNil(manager, "SharingManager.shared should exist")
        XCTAssertFalse(manager.isLoading, "SharingManager should not be loading initially")
        XCTAssertNil(manager.error, "SharingManager should have no error initially")
        XCTAssertTrue(manager.activeShares.isEmpty, "SharingManager should have no active shares initially")
    }

    @MainActor
    func testGetSharedLovedOnesReturnsEmptyWhenNoneShared() {
        // Given: No shared LovedOnes
        _ = createTestLovedOne(name: "Child 1")
        _ = createTestLovedOne(name: "Child 2")
        try? testContext.save()

        // When: Getting shared LovedOnes
        let sharedLovedOnes = SharingManager.shared.getSharedLovedOnes()

        // Then: Should return empty array
        XCTAssertTrue(sharedLovedOnes.isEmpty, "Should return no shared LovedOnes when none are shared")
    }

    @MainActor
    func testGetSharedLovedOnesReturnsOnlyShared() throws {
        // Note: This test uses the in-memory test context which is separate from
        // SharingManager.shared's context. We test the predicate logic directly instead.

        // Given: Mix of shared and unshared LovedOnes
        let shared1 = createTestLovedOne(name: "Shared Child 1")
        shared1.isSharedWithFamily = true

        let shared2 = createTestLovedOne(name: "Shared Child 2")
        shared2.isSharedWithFamily = true

        let unshared = createTestLovedOne(name: "Unshared Child")
        unshared.isSharedWithFamily = false

        try testContext.save()

        // When: Fetching with the same predicate SharingManager uses
        let fetchRequest: NSFetchRequest<LovedOne> = LovedOne.fetchRequest()
        fetchRequest.predicate = NSPredicate(format: "isSharedWithFamily == YES")
        let sharedLovedOnes = try testContext.fetch(fetchRequest)

        // Then: Should return only shared ones
        XCTAssertEqual(sharedLovedOnes.count, 2, "Should return exactly 2 shared LovedOnes")
        XCTAssertTrue(sharedLovedOnes.allSatisfy { $0.isSharedWithFamily }, "All returned LovedOnes should be shared")
    }

    @MainActor
    func testParticipantCountTextForUnsharedLovedOne() {
        // Given: An unshared LovedOne
        let lovedOne = createTestLovedOne(name: "Unshared")
        try? testContext.save()

        // When: Getting participant count text
        let text = SharingManager.shared.participantCountText(for: lovedOne)

        // Then: Should indicate not shared
        XCTAssertEqual(text, "Not shared", "Should indicate the profile is not shared")
    }

    // MARK: - CKShare.Participant Extension Tests

    func testParticipantInitialsWithUnknownIdentity() {
        // Note: CKShare.Participant cannot be easily mocked, so this test
        // documents expected behavior rather than testing it directly.
        // In production, participants without name components return "?"
    }

    // MARK: - Memory Association Tests

    func testMemoriesAreAccessibleFromSharedLovedOne() throws {
        // Given: A shared LovedOne with memories
        let lovedOne = createTestLovedOne(name: "Shared Child")
        lovedOne.isSharedWithFamily = true

        let memory1 = Memory(context: testContext)
        memory1.id = UUID()
        memory1.title = "First Memory"
        memory1.type = MemoryType.photo.rawValue
        memory1.captureDate = Date()
        memory1.createdAt = Date()
        memory1.lovedOne = lovedOne

        let memory2 = Memory(context: testContext)
        memory2.id = UUID()
        memory2.title = "Second Memory"
        memory2.type = MemoryType.text.rawValue
        memory2.captureDate = Date()
        memory2.createdAt = Date()
        memory2.lovedOne = lovedOne

        try testContext.save()

        // When: Accessing memories from the shared LovedOne
        let memories = lovedOne.memories?.allObjects as? [Memory] ?? []

        // Then: All memories should be accessible
        XCTAssertEqual(memories.count, 2, "Shared LovedOne should have access to all associated memories")
        XCTAssertTrue(memories.contains { $0.title == "First Memory" }, "First memory should be accessible")
        XCTAssertTrue(memories.contains { $0.title == "Second Memory" }, "Second memory should be accessible")
    }

    // MARK: - Edge Case Tests

    func testTogglingSharingStatus() throws {
        // Given: A LovedOne
        let lovedOne = createTestLovedOne(name: "Toggle Test")
        try testContext.save()

        // When: Toggling sharing status multiple times
        lovedOne.isSharedWithFamily = true
        try testContext.save()
        XCTAssertTrue(lovedOne.isSharedWithFamily)

        lovedOne.isSharedWithFamily = false
        try testContext.save()
        XCTAssertFalse(lovedOne.isSharedWithFamily)

        lovedOne.isSharedWithFamily = true
        try testContext.save()
        XCTAssertTrue(lovedOne.isSharedWithFamily)
    }

    func testMultipleLovedOnesCanBeSharedIndependently() throws {
        // Given: Multiple LovedOnes
        let child1 = createTestLovedOne(name: "Child 1")
        let child2 = createTestLovedOne(name: "Child 2")
        let child3 = createTestLovedOne(name: "Child 3")

        // When: Sharing only some of them
        child1.isSharedWithFamily = true
        child2.isSharedWithFamily = false
        child3.isSharedWithFamily = true
        try testContext.save()

        // Then: Each should maintain its own sharing status
        XCTAssertTrue(child1.isSharedWithFamily, "Child 1 should be shared")
        XCTAssertFalse(child2.isSharedWithFamily, "Child 2 should not be shared")
        XCTAssertTrue(child3.isSharedWithFamily, "Child 3 should be shared")
    }

    // MARK: - Helper Methods

    private func createTestLovedOne(name: String) -> LovedOne {
        let lovedOne = LovedOne(context: testContext)
        lovedOne.id = UUID()
        lovedOne.name = name
        lovedOne.relationship = RelationshipType.child.rawValue
        lovedOne.createdAt = Date()
        return lovedOne
    }
}

// MARK: - UI Component Tests (Compile-time verification)

/// These tests verify that the UI components compile correctly.
/// Full UI testing would require XCUITest.
extension SharingManagerTests {

    func testSharedStatusBadgeCompiles() {
        // This test verifies SharedStatusBadge can be instantiated
        // Full rendering would require a SwiftUI test host
        let lovedOne = createTestLovedOne(name: "Test")
        _ = SharedStatusBadge(lovedOne: lovedOne)
    }

    func testParticipantAvatarViewCompiles() {
        // ParticipantAvatarView requires a CKShare.Participant which
        // cannot be easily mocked. This documents the expected interface.
    }
}
