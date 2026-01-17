import SwiftUI
import PhotosUI

/// PhotoCaptureView allows users to capture photos from camera or pick from photo library.
struct PhotoCaptureView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    @StateObject private var permissions = PermissionsManager.shared

    let lovedOne: LovedOne?
    let onCapture: (UIImage) -> Void

    @State private var showCamera = false
    @State private var showPhotoPicker = false
    @State private var capturedImage: UIImage?
    @State private var showPermissionAlert = false
    @State private var permissionAlertType: PermissionType = .camera

    enum PermissionType {
        case camera, photoLibrary
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: themeManager.theme.spacingLarge) {
                if let image = capturedImage {
                    // Preview captured image
                    imagePreview(image)
                } else {
                    // Capture options
                    captureOptions
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeManager.theme.backgroundColor)
            .navigationTitle("Add Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                if capturedImage != nil {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use Photo") {
                            if let image = capturedImage {
                                onCapture(image)
                                dismiss()
                            }
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraView(image: $capturedImage)
                    .ignoresSafeArea()
            }
            .photosPicker(isPresented: $showPhotoPicker, selection: Binding(
                get: { nil },
                set: { item in
                    if let item {
                        loadImage(from: item)
                    }
                }
            ), matching: .images)
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

            Image(systemName: "photo.fill")
                .font(.system(size: 80))
                .foregroundStyle(themeManager.theme.primaryColor.opacity(0.3))

            Text("Choose how to add a photo")
                .font(themeManager.theme.headlineFont)
                .foregroundStyle(themeManager.theme.textPrimary)

            if let lovedOne = lovedOne {
                Text("For \(lovedOne.name ?? "your loved one")")
                    .font(themeManager.theme.bodyFont)
                    .foregroundStyle(themeManager.theme.textSecondary)
            }

            VStack(spacing: themeManager.theme.spacingMedium) {
                captureButton(
                    title: "Take Photo",
                    icon: "camera.fill",
                    color: MemoryType.photo.color
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

    // MARK: - Image Preview

    private func imagePreview(_ image: UIImage) -> some View {
        VStack(spacing: themeManager.theme.spacingMedium) {
            Image(uiImage: image)
                .resizable()
                .scaledToFit()
                .clipShape(RoundedRectangle(cornerRadius: themeManager.theme.cornerRadiusMedium))

            Button {
                capturedImage = nil
            } label: {
                HStack {
                    Image(systemName: "arrow.counterclockwise")
                    Text("Retake")
                }
                .font(themeManager.theme.bodyFont)
                .foregroundStyle(themeManager.theme.primaryColor)
            }
        }
    }

    // MARK: - Permission Handling

    private func requestCameraAndOpen() {
        Task {
            let granted = await permissions.requestCameraPermission()
            if granted {
                showCamera = true
            } else {
                permissionAlertType = .camera
                showPermissionAlert = true
            }
        }
    }

    private func requestPhotoLibraryAndOpen() {
        Task {
            let granted = await permissions.requestPhotoLibraryPermission()
            if granted {
                showPhotoPicker = true
            } else {
                permissionAlertType = .photoLibrary
                showPermissionAlert = true
            }
        }
    }

    private var permissionAlertMessage: String {
        switch permissionAlertType {
        case .camera:
            return "Daycatcher needs camera access to take photos. Please enable it in Settings."
        case .photoLibrary:
            return "Daycatcher needs photo library access to select photos. Please enable it in Settings."
        }
    }

    private func loadImage(from item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                await MainActor.run {
                    capturedImage = image
                }
            }
        }
    }
}

// MARK: - Camera View (UIKit wrapper)

struct CameraView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        picker.allowsEditing = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraView

        init(_ parent: CameraView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

#Preview {
    PhotoCaptureView(lovedOne: nil) { _ in }
        .environmentObject(ThemeManager())
}
