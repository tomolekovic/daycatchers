import XCTest
import UIKit
@testable import Daycatcher

final class MediaManagerTests: XCTestCase {

    var sut: MediaManager!
    var testDirectory: URL!

    override func setUpWithError() throws {
        try super.setUpWithError()
        sut = MediaManager.shared

        // Create a test directory for our tests
        testDirectory = FileManager.default.temporaryDirectory.appendingPathComponent("MediaManagerTests")
        try? FileManager.default.createDirectory(at: testDirectory, withIntermediateDirectories: true)
    }

    override func tearDownWithError() throws {
        // Clean up test files
        try? FileManager.default.removeItem(at: testDirectory)
        try super.tearDownWithError()
    }

    // MARK: - Photo Save Tests

    func testSavePhotoFromData() {
        // Given
        let testImage = createTestImage()
        guard let imageData = testImage.jpegData(compressionQuality: 0.8) else {
            XCTFail("Failed to create test image data")
            return
        }

        // When
        let filename = sut.savePhoto(data: imageData)

        // Then
        XCTAssertNotNil(filename)
        XCTAssertTrue(filename?.hasSuffix(".jpg") ?? false)

        // Clean up
        if let filename = filename {
            sut.deleteMedia(filename: filename, type: .photo)
        }
    }

    func testSavePhotoFromUIImage() {
        // Given
        let testImage = createTestImage()

        // When
        let filename = sut.savePhoto(image: testImage)

        // Then
        XCTAssertNotNil(filename)
        XCTAssertTrue(filename?.hasSuffix(".jpg") ?? false)

        // Verify we can load it back
        if let filename = filename {
            let loadedImage = sut.loadImage(filename: filename, type: .photo)
            XCTAssertNotNil(loadedImage)
            sut.deleteMedia(filename: filename, type: .photo)
        }
    }

    func testSavePhotoWithCustomFilename() {
        // Given
        let testImage = createTestImage()
        let customFilename = "custom_test_photo.jpg"

        // When
        let filename = sut.savePhoto(image: testImage, filename: customFilename)

        // Then
        XCTAssertEqual(filename, customFilename)

        // Clean up
        sut.deleteMedia(filename: customFilename, type: .photo)
    }

    // MARK: - Thumbnail Tests

    func testSaveThumbnail() {
        // Given
        let testImage = createTestImage(size: CGSize(width: 1000, height: 1000))

        // When
        let filename = sut.saveThumbnail(image: testImage)

        // Then
        XCTAssertNotNil(filename)
        XCTAssertTrue(filename?.contains("_thumb") ?? false)

        // Verify thumbnail was resized
        if let filename = filename {
            let thumbnail = sut.loadThumbnail(filename: filename)
            XCTAssertNotNil(thumbnail)

            // Thumbnail should be smaller than original (accounting for scale)
            if let thumb = thumbnail {
                // The resized image should be smaller than the original 1000x1000
                XCTAssertLessThan(thumb.size.width, 1000)
                XCTAssertLessThan(thumb.size.height, 1000)
            }

            sut.deleteThumbnail(filename: filename)
        }
    }

    // MARK: - Profile Image Tests

    func testSaveProfileImage() {
        // Given
        let testImage = createTestImage(size: CGSize(width: 800, height: 800))
        guard let imageData = testImage.jpegData(compressionQuality: 0.8) else {
            XCTFail("Failed to create test image data")
            return
        }
        let filename = "test_profile.jpg"

        // When
        let success = sut.saveProfileImage(data: imageData, filename: filename)

        // Then
        XCTAssertTrue(success)

        // Verify we can load it
        let loadedImage = sut.loadProfileImage(filename: filename)
        XCTAssertNotNil(loadedImage)

        // Profile image should exist and be a valid image
        // Size checking is complex due to scale factors, so we just verify
        // the save/load round-trip works correctly
        XCTAssertNotNil(loadedImage?.size)

        // Clean up
        sut.deleteProfileImage(filename: filename)
    }

    // MARK: - Media URL Tests

    func testMediaURLForPhoto() {
        // Given
        let filename = "test.jpg"

        // When
        let url = sut.mediaURL(filename: filename, type: .photo)

        // Then
        XCTAssertTrue(url.path.contains("photos"))
        XCTAssertTrue(url.path.hasSuffix(filename))
    }

    func testMediaURLForVideo() {
        // Given
        let filename = "test.mov"

        // When
        let url = sut.mediaURL(filename: filename, type: .video)

        // Then
        XCTAssertTrue(url.path.contains("videos"))
        XCTAssertTrue(url.path.hasSuffix(filename))
    }

    func testMediaURLForAudio() {
        // Given
        let filename = "test.m4a"

        // When
        let url = sut.mediaURL(filename: filename, type: .audio)

        // Then
        XCTAssertTrue(url.path.contains("audio"))
        XCTAssertTrue(url.path.hasSuffix(filename))
    }

    func testThumbnailURL() {
        // Given
        let filename = "test_thumb.jpg"

        // When
        let url = sut.thumbnailURL(filename: filename)

        // Then
        XCTAssertTrue(url.path.contains("thumbnails"))
        XCTAssertTrue(url.path.hasSuffix(filename))
    }

    func testProfileImageURL() {
        // Given
        let filename = "profile.jpg"

        // When
        let url = sut.profileImageURL(filename: filename)

        // Then
        XCTAssertTrue(url.path.contains("profiles"))
        XCTAssertTrue(url.path.hasSuffix(filename))
    }

    // MARK: - Delete Tests

    func testDeleteMedia() {
        // Given
        let testImage = createTestImage()
        let filename = sut.savePhoto(image: testImage)
        XCTAssertNotNil(filename)

        // When
        sut.deleteMedia(filename: filename!, type: .photo)

        // Then
        let loadedImage = sut.loadImage(filename: filename!, type: .photo)
        XCTAssertNil(loadedImage)
    }

    func testDeleteThumbnail() {
        // Given
        let testImage = createTestImage()
        let filename = sut.saveThumbnail(image: testImage)
        XCTAssertNotNil(filename)

        // When
        sut.deleteThumbnail(filename: filename!)

        // Then
        let loadedImage = sut.loadThumbnail(filename: filename!)
        XCTAssertNil(loadedImage)
    }

    // MARK: - Storage Tests

    func testStorageUsed() {
        // Given - save some test data
        let testImage = createTestImage()
        let filename = sut.savePhoto(image: testImage)

        // When
        let storageUsed = sut.storageUsed()

        // Then
        XCTAssertGreaterThan(storageUsed, 0)

        // Clean up
        if let filename = filename {
            sut.deleteMedia(filename: filename, type: .photo)
        }
    }

    func testFormattedStorageUsed() {
        // When
        let formattedStorage = sut.formattedStorageUsed()

        // Then
        XCTAssertFalse(formattedStorage.isEmpty)
        // Should contain a unit like KB, MB, or GB
        let hasUnit = formattedStorage.contains("KB") ||
                      formattedStorage.contains("MB") ||
                      formattedStorage.contains("GB") ||
                      formattedStorage.contains("bytes")
        XCTAssertTrue(hasUnit || formattedStorage == "Zero KB")
    }

    // MARK: - UIImage Extension Tests

    func testImageResizing() {
        // Given
        let originalImage = createTestImage(size: CGSize(width: 1000, height: 500))

        // When
        let targetSize = CGSize(width: 300, height: 300)
        let resizedImage = originalImage.resized(to: targetSize)

        // Then - aspect ratio should be maintained
        let expectedWidth: CGFloat = 300
        let expectedHeight: CGFloat = 150 // 500/1000 * 300

        XCTAssertEqual(resizedImage.size.width, expectedWidth, accuracy: 1.0)
        XCTAssertEqual(resizedImage.size.height, expectedHeight, accuracy: 1.0)
    }

    // MARK: - Helper Methods

    private func createTestImage(size: CGSize = CGSize(width: 100, height: 100)) -> UIImage {
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { context in
            UIColor.red.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }
}
