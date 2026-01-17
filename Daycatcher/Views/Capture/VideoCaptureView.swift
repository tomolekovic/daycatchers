import SwiftUI
import PhotosUI
import AVKit

/// VideoCaptureView allows users to record video from camera or pick from photo library.
struct VideoCaptureView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var permissions = PermissionsManager.shared

    let lovedOne: LovedOne?
    let onCapture: (URL) -> Void

    @State private var showCamera = false
    @State private var showVideoPicker = false
    @State private var capturedVideoURL: URL?
    @State private var showPermissionAlert = false
    @State private var permissionAlertType: PermissionType = .camera

    enum PermissionType {
        case camera, photoLibrary
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: themeManager.theme.spacingLarge) {
                if let videoURL = capturedVideoURL {
                    // Preview captured video
                    videoPreview(videoURL)
                } else {
                    // Capture options
                    captureOptions
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeManager.theme.backgroundColor)
            .navigationTitle("Add Video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        cleanupAndDismiss()
                    }
                }

                if capturedVideoURL != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use Video") {
                            if let url = capturedVideoURL {
                                onCapture(url)
                                dismiss()
                            }
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                VideoCameraView(videoURL: $capturedVideoURL)
                    .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showVideoPicker, selection: Binding(
                get: { nil },
                set: { item in
                    if let item {
                        loadVideo(from: item)
                    }
                }
            ), matching: .videos)
            .alert("Permission Required", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    permissions.openSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text(permissionAlertMessage)
            }
        }
    }

    // MARK: - Capture Options

    private var captureOptions: some View {
        VStack(spacing: themeManager.theme.spacingLarge) {
            Spacer()

            Image(systemName: "video.fill")
                .font(.system(size: 80))
                .foregroundStyle(themeManager.theme.primaryColor.opacity(0.3))

            Text("Choose how to add a video")
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            if let lovedOne = lovedOne {
                Text("For \(lovedOne.name ?? "your loved one")")
                    .font(themeManager.theme.bodyFont)
                    .foregroundStyle(themeManager.theme.textSecondary)
            }

            VStack(spacing: themeManager.theme.spacingMedium) {
                captureButton(
                    title: "Record Video",
                    icon: "video.fill",
                    color: MemoryType.video.color
                ) {
                    requestCameraAndOpen()
                }

                captureButton(
                    title: "Choose from Library",
                    icon: "photo.on.rectangle",
                    color: themeManager.theme.secondaryColor
                ) {
                    requestPhotoLibraryAndOpen()
                }
            }
            .padding(.top, themeManager.theme.spacingLarge)

            Spacer()
        }
    }

    private func captureButton(title: String, icon: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: themeManager.theme.spacingMedium) {
                Image(systemName: icon)
                    .font(.title2)

                Text(title)
                    .font(themeManager.theme.headlineFont)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.caption)
            }
            .foregroundStyle(.white)
            .padding()
            .frame(maxWidth: .infinity)
            .background(color)
            .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))
        }
    }

    // MARK: - Video Preview

    private func videoPreview(_ url: URL) -> some View {
        VStack(spacing: themeManager.theme.spacingMedium) {
            VideoPlayer(player: AVPlayer(url: url))
                .frame(height: 300)
                .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))

            Button {
                capturedVideoURL = nil
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Choose Different Video")
                }
                .font(themeManager.theme.bodyFont)
                .foregroundStyle(themeManager.theme.primaryColor)
            }
        }
    }

    // MARK: - Permission Handling

    private func requestCameraAndOpen() {
        Task {
            let cameraGranted = await permissions.requestCameraPermission()
            let micGranted = await permissions.requestMicrophonePermission()

            if cameraGranted && micGranted {
                showCamera = true
            } else if !cameraGranted {
                permissionAlertType = .camera
                showPermissionAlert = true
            }
        }
    }

    private func requestPhotoLibraryAndOpen() {
        Task {
            let granted = await permissions.requestPhotoLibraryPermission()
            if granted {
                showVideoPicker = true
            } else {
                permissionAlertType = .photoLibrary
                showPermissionAlert = true
            }
        }
    }

    private var permissionAlertMessage: String {
        switch permissionAlertType {
        case .camera:
            return "Daycatcher needs camera and microphone access to record videos. Please enable them in Settings."
        case .photoLibrary:
            return "Daycatcher needs photo library access to select videos. Please enable it in Settings."
        }
    }

    private func loadVideo(from item: PhotosPickerItem) {
        Task {
            if let movie = try? await item.loadTransferable(type: VideoTransferable.self) {
                await MainActor.run {
                    capturedVideoURL = movie.url
                }
            }
        }
    }

    private func cleanupAndDismiss() {
        capturedVideoURL = nil
        dismiss()
    }
}

// MARK: - Video Transferable

struct VideoTransferable: Transferable {
    let url: URL

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { movie in
            SentTransferredFile(movie.url)
        } importing: { received in
            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension("mov")
            try FileManager.default.copyItem(at: received.file, to: tempURL)
            return Self(url: tempURL)
        }
    }
}

// MARK: - Video Camera View (UIKit wrapper)

struct VideoCameraView: UIViewControllerRepresentable {
    @Binding var videoURL: URL?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.mediaTypes = ["public.movie"]
        picker.videoQuality = .typeHigh
        picker.videoMaximumDuration = 300 // 5 minutes max
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: VideoCameraView

        init(_ parent: VideoCameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let url = info[.mediaURL] as? URL {
                // Copy to temp directory to ensure we have access
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathExtension("mov")
                do {
                    try FileManager.default.copyItem(at: url, to: tempURL)
                    parent.videoURL = tempURL
                } catch {
                    print("Error copying video: \(error)")
                }
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    VideoCaptureView(lovedOne: nil) { _ in }
        .environmentObject(ThemeManager())
}
