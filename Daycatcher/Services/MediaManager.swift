import Foundation
import UIKit
import AVFoundation

/// MediaManager handles file storage for photos, videos, audio, and thumbnails.
/// Provides a unified interface for saving, loading, and deleting media files.
final class MediaManager {
    static let shared = MediaManager()

    private let fileManager = FileManager.default

    // MARK: - Directory URLs

    private var documentsDirectory: URL {
        fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private var daycatcherDirectory: URL {
        documentsDirectory.appendingPathComponent("Daycatcher", isDirectory: true)
    }

    private var photosDirectory: URL {
        daycatcherDirectory.appendingPathComponent("photos", isDirectory: true)
    }

    private var videosDirectory: URL {
        daycatcherDirectory.appendingPathComponent("videos", isDirectory: true)
    }

    private var audioDirectory: URL {
        daycatcherDirectory.appendingPathComponent("audio", isDirectory: true)
    }

    private var thumbnailsDirectory: URL {
        daycatcherDirectory.appendingPathComponent("thumbnails", isDirectory: true)
    }

    private var profilesDirectory: URL {
        daycatcherDirectory.appendingPathComponent("profiles", isDirectory: true)
    }

    // MARK: - Initialization

    private init() {
        createDirectoriesIfNeeded()
    }

    private func createDirectoriesIfNeeded() {
        let directories = [
            daycatcherDirectory,
            photosDirectory,
            videosDirectory,
            audioDirectory,
            thumbnailsDirectory,
            profilesDirectory
        ]

        for directory in directories {
            if !fileManager.fileExists(atPath: directory.path) {
                do {
                    try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
                } catch {
                    print("Error creating directory \(directory): \(error)")
                }
            }
        }
    }

    // MARK: - URL Builders

    func mediaURL(filename: String, type: MemoryType) -> URL {
        switch type {
        case .photo:
            return photosDirectory.appendingPathComponent(filename)
        case .video:
            return videosDirectory.appendingPathComponent(filename)
        case .audio:
            return audioDirectory.appendingPathComponent(filename)
        case .text:
            return daycatcherDirectory.appendingPathComponent(filename)
        }
    }

    func thumbnailURL(filename: String) -> URL {
        thumbnailsDirectory.appendingPathComponent(filename)
    }

    func profileImageURL(filename: String) -> URL {
        profilesDirectory.appendingPathComponent(filename)
    }

    // MARK: - Save Operations

    /// Save photo data and return the filename
    @discardableResult
    func savePhoto(data: Data, filename: String? = nil) -> String? {
        let name = filename ?? "\(UUID().uuidString).jpg"
        let url = photosDirectory.appendingPathComponent(name)

        do {
            try data.write(to: url)
            return name
        } catch {
            print("Error saving photo: \(error)")
            return nil
        }
    }

    /// Save photo from UIImage
    @discardableResult
    func savePhoto(image: UIImage, filename: String? = nil, compressionQuality: CGFloat = 0.8) -> String? {
        guard let data = image.jpegData(compressionQuality: compressionQuality) else {
            return nil
        }
        return savePhoto(data: data, filename: filename)
    }

    /// Save video from URL and return the filename
    @discardableResult
    func saveVideo(from sourceURL: URL, filename: String? = nil) -> String? {
        let name = filename ?? "\(UUID().uuidString).mov"
        let destinationURL = videosDirectory.appendingPathComponent(name)

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return name
        } catch {
            print("Error saving video: \(error)")
            return nil
        }
    }

    /// Save audio from URL and return the filename
    @discardableResult
    func saveAudio(from sourceURL: URL, filename: String? = nil) -> String? {
        let name = filename ?? "\(UUID().uuidString).m4a"
        let destinationURL = audioDirectory.appendingPathComponent(name)

        do {
            if fileManager.fileExists(atPath: destinationURL.path) {
                try fileManager.removeItem(at: destinationURL)
            }
            try fileManager.copyItem(at: sourceURL, to: destinationURL)
            return name
        } catch {
            print("Error saving audio: \(error)")
            return nil
        }
    }

    /// Save thumbnail and return the filename
    @discardableResult
    func saveThumbnail(image: UIImage, filename: String? = nil) -> String? {
        let name = filename ?? "\(UUID().uuidString)_thumb.jpg"
        let url = thumbnailsDirectory.appendingPathComponent(name)

        // Resize to thumbnail size
        let thumbnailSize = CGSize(width: 300, height: 300)
        let resized = image.resized(to: thumbnailSize)

        guard let data = resized.jpegData(compressionQuality: 0.7) else {
            return nil
        }

        do {
            try data.write(to: url)
            return name
        } catch {
            print("Error saving thumbnail: \(error)")
            return nil
        }
    }

    /// Save profile image and return success
    @discardableResult
    func saveProfileImage(data: Data, filename: String) -> Bool {
        let url = profilesDirectory.appendingPathComponent(filename)

        do {
            // Resize to profile size
            if let image = UIImage(data: data) {
                let profileSize = CGSize(width: 400, height: 400)
                let resized = image.resized(to: profileSize)
                if let resizedData = resized.jpegData(compressionQuality: 0.8) {
                    try resizedData.write(to: url)
                    return true
                }
            }
            return false
        } catch {
            print("Error saving profile image: \(error)")
            return false
        }
    }

    // MARK: - Load Operations

    func loadImage(filename: String, type: MemoryType) -> UIImage? {
        let url = mediaURL(filename: filename, type: type)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func loadThumbnail(filename: String) -> UIImage? {
        let url = thumbnailURL(filename: filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    func loadProfileImage(filename: String) -> UIImage? {
        let url = profileImageURL(filename: filename)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    // MARK: - Delete Operations

    func deleteMedia(filename: String, type: MemoryType) {
        let url = mediaURL(filename: filename, type: type)
        try? fileManager.removeItem(at: url)
    }

    func deleteThumbnail(filename: String) {
        let url = thumbnailURL(filename: filename)
        try? fileManager.removeItem(at: url)
    }

    func deleteProfileImage(filename: String) {
        let url = profileImageURL(filename: filename)
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Thumbnail Generation

    /// Generate thumbnail from video URL
    func generateVideoThumbnail(from videoURL: URL) -> UIImage? {
        let asset = AVAsset(url: videoURL)
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try generator.copyCGImage(at: .zero, actualTime: nil)
            return UIImage(cgImage: cgImage)
        } catch {
            print("Error generating video thumbnail: \(error)")
            return nil
        }
    }

    // MARK: - Storage Info

    /// Calculate total storage used by Daycatcher
    func storageUsed() -> Int64 {
        var totalSize: Int64 = 0

        let directories = [photosDirectory, videosDirectory, audioDirectory, thumbnailsDirectory, profilesDirectory]

        for directory in directories {
            if let enumerator = fileManager.enumerator(at: directory, includingPropertiesForKeys: [.fileSizeKey]) {
                for case let fileURL as URL in enumerator {
                    if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                        totalSize += Int64(fileSize)
                    }
                }
            }
        }

        return totalSize
    }

    /// Formatted storage used string
    func formattedStorageUsed() -> String {
        let bytes = storageUsed()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    // MARK: - Export

    /// Export all media to a given directory
    func exportAllMedia(to destinationURL: URL) throws {
        let directories = [
            ("photos", photosDirectory),
            ("videos", videosDirectory),
            ("audio", audioDirectory)
        ]

        for (name, sourceDir) in directories {
            let destDir = destinationURL.appendingPathComponent(name, isDirectory: true)
            try fileManager.createDirectory(at: destDir, withIntermediateDirectories: true)

            if let contents = try? fileManager.contentsOfDirectory(at: sourceDir, includingPropertiesForKeys: nil) {
                for file in contents {
                    let destFile = destDir.appendingPathComponent(file.lastPathComponent)
                    try fileManager.copyItem(at: file, to: destFile)
                }
            }
        }
    }
}

// MARK: - UIImage Extension

extension UIImage {
    func resized(to targetSize: CGSize) -> UIImage {
        let widthRatio = targetSize.width / size.width
        let heightRatio = targetSize.height / size.height
        let ratio = min(widthRatio, heightRatio)

        let newSize = CGSize(width: size.width * ratio, height: size.height * ratio)

        let renderer = UIGraphicsImageRenderer(size: newSize)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}
