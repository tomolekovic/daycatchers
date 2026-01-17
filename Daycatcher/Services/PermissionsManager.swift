import Foundation
import AVFoundation
import Photos
import UIKit

/// PermissionsManager handles camera, photo library, and microphone permission requests.
/// Provides a unified interface for checking and requesting permissions.
@MainActor
final class PermissionsManager: ObservableObject {
    static let shared = PermissionsManager()

    @Published var cameraStatus: AVAuthorizationStatus = .notDetermined
    @Published var photoLibraryStatus: PHAuthorizationStatus = .notDetermined
    @Published var microphoneStatus: AVAuthorizationStatus = .notDetermined

    private init() {
        refreshAllStatuses()
    }

    // MARK: - Status Refresh

    func refreshAllStatuses() {
        cameraStatus = AVCaptureDevice.authorizationStatus(for: .video)
        photoLibraryStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        microphoneStatus = AVCaptureDevice.authorizationStatus(for: .audio)
    }

    // MARK: - Camera

    var isCameraAuthorized: Bool {
        cameraStatus == .authorized
    }

    var isCameraDenied: Bool {
        cameraStatus == .denied || cameraStatus == .restricted
    }

    func requestCameraPermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .video)

        switch status {
        case .authorized:
            cameraStatus = .authorized
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            cameraStatus = granted ? .authorized : .denied
            return granted
        default:
            cameraStatus = status
            return false
        }
    }

    // MARK: - Photo Library

    var isPhotoLibraryAuthorized: Bool {
        photoLibraryStatus == .authorized || photoLibraryStatus == .limited
    }

    var isPhotoLibraryDenied: Bool {
        photoLibraryStatus == .denied || photoLibraryStatus == .restricted
    }

    func requestPhotoLibraryPermission() async -> Bool {
        let status = PHPhotoLibrary.authorizationStatus(for: .readWrite)

        switch status {
        case .authorized, .limited:
            photoLibraryStatus = status
            return true
        case .notDetermined:
            let newStatus = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
            photoLibraryStatus = newStatus
            return newStatus == .authorized || newStatus == .limited
        default:
            photoLibraryStatus = status
            return false
        }
    }

    // MARK: - Microphone

    var isMicrophoneAuthorized: Bool {
        microphoneStatus == .authorized
    }

    var isMicrophoneDenied: Bool {
        microphoneStatus == .denied || microphoneStatus == .restricted
    }

    func requestMicrophonePermission() async -> Bool {
        let status = AVCaptureDevice.authorizationStatus(for: .audio)

        switch status {
        case .authorized:
            microphoneStatus = .authorized
            return true
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .audio)
            microphoneStatus = granted ? .authorized : .denied
            return granted
        default:
            microphoneStatus = status
            return false
        }
    }

    // MARK: - Settings

    func openSettings() {
        guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(settingsURL)
    }
}
