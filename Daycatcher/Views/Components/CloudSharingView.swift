import SwiftUI
import CloudKit
import UIKit

// MARK: - CloudKit Sharing Presenter

/// A helper class that presents UICloudSharingController directly from the root window.
/// This avoids SwiftUI sheet presentation hierarchy issues with mail/message composers.
@MainActor
class CloudSharingPresenter: NSObject, ObservableObject {
    static let shared = CloudSharingPresenter()

    @Published var isPresenting = false
    @Published var error: Error?

    private var lovedOne: LovedOne?
    private var onComplete: (() -> Void)?

    private override init() {
        super.init()
    }

    /// Present CloudKit sharing UI for a LovedOne
    func presentSharing(for lovedOne: LovedOne, existingShare: CKShare? = nil, onComplete: (() -> Void)? = nil) {
        print("[CloudSharingPresenter] presentSharing called")

        self.lovedOne = lovedOne
        self.onComplete = onComplete
        self.error = nil
        self.isPresenting = true

        Task {
            await checkAndPresentSharing(existingShare: existingShare)
        }
    }

    private func checkAndPresentSharing(existingShare: CKShare?) async {
        print("[CloudSharingPresenter] checkAndPresentSharing started")

        let container = CKContainer(identifier: PersistenceController.cloudKitContainerIdentifier)

        do {
            let status = try await container.accountStatus()
            print("[CloudSharingPresenter] iCloud status: \(status.rawValue)")

            switch status {
            case .available:
                await createAndPresentSharingController(existingShare: existingShare)
            case .noAccount:
                showAlert(title: "iCloud Required", message: "Please sign in to iCloud in Settings to share profiles with family members.")
            case .restricted:
                showAlert(title: "iCloud Restricted", message: "iCloud access is restricted on this device.")
            case .couldNotDetermine:
                showAlert(title: "Connection Error", message: "Unable to determine iCloud account status. Please check your internet connection.")
            case .temporarilyUnavailable:
                showAlert(title: "iCloud Unavailable", message: "iCloud is temporarily unavailable. Please try again later.")
            @unknown default:
                showAlert(title: "Error", message: "An unknown error occurred with iCloud.")
            }
        } catch {
            print("[CloudSharingPresenter] Error checking iCloud: \(error)")
            showAlert(title: "Error", message: "Failed to check iCloud status: \(error.localizedDescription)")
        }
    }

    private func createAndPresentSharingController(existingShare: CKShare?) async {
        guard let lovedOne = lovedOne else {
            print("[CloudSharingPresenter] No lovedOne set")
            isPresenting = false
            return
        }

        do {
            let sharingController: UICloudSharingController
            let cloudKitContainer = CKContainer(identifier: PersistenceController.cloudKitContainerIdentifier)
            let persistenceController = PersistenceController.shared

            if let existingShare = existingShare {
                print("[CloudSharingPresenter] Using existing share")
                sharingController = UICloudSharingController(share: existingShare, container: cloudKitContainer)
            } else {
                print("[CloudSharingPresenter] Creating new share via SharingManager")
                // Use SharingManager to ensure proper tag handling (detach before share, restore after)
                let newShare = try await SharingManager.shared.getOrCreateShare(for: lovedOne)
                print("[CloudSharingPresenter] Share created successfully")
                sharingController = UICloudSharingController(share: newShare, container: cloudKitContainer)
            }

            // Configure the controller
            sharingController.delegate = self
            sharingController.availablePermissions = [.allowReadWrite, .allowPrivate]

            if let name = lovedOne.name {
                sharingController.title = "Share \(name)'s Profile"
            }

            // Present from root view controller
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let rootVC = windowScene.windows.first?.rootViewController else {
                print("[CloudSharingPresenter] Could not find root view controller")
                isPresenting = false
                return
            }

            // Find the topmost view controller
            var topVC = rootVC
            while let presented = topVC.presentedViewController {
                topVC = presented
            }

            print("[CloudSharingPresenter] Presenting UICloudSharingController")
            topVC.present(sharingController, animated: true)

        } catch {
            print("[CloudSharingPresenter] Error creating share: \(error)")
            self.error = error
            showAlert(title: "Sharing Failed", message: "Failed to create share: \(error.localizedDescription)")
        }
    }

    private func showAlert(title: String, message: String) {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            isPresenting = false
            return
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default) { [weak self] _ in
            self?.isPresenting = false
            self?.onComplete?()
        })
        topVC.present(alert, animated: true)
    }

    private func complete() {
        isPresenting = false
        onComplete?()
        onComplete = nil
        lovedOne = nil
    }
}

// MARK: - UICloudSharingControllerDelegate

extension CloudSharingPresenter: UICloudSharingControllerDelegate {
    nonisolated func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        print("[CloudSharingPresenter] failedToSaveShareWithError: \(error)")
        Task { @MainActor in
            SharingManager.shared.error = error
            self.error = error
        }
    }

    nonisolated func itemTitle(for csc: UICloudSharingController) -> String? {
        // Access lovedOne on main actor
        let title = MainActor.assumeIsolated {
            lovedOne?.name ?? "Shared Profile"
        }
        return title
    }

    nonisolated func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
        let data = MainActor.assumeIsolated { () -> Data? in
            guard let lovedOne = lovedOne,
                  let imagePath = lovedOne.profileImagePath,
                  let url = MediaManager.shared.profileImageURL(filename: imagePath) as URL?,
                  let data = try? Data(contentsOf: url),
                  let image = UIImage(data: data),
                  let thumbnail = image.preparingThumbnail(of: CGSize(width: 120, height: 120)) else {
                return nil
            }
            return thumbnail.jpegData(compressionQuality: 0.7)
        }
        return data
    }

    nonisolated func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        print("[CloudSharingPresenter] cloudSharingControllerDidSaveShare")
        Task { @MainActor in
            if let share = csc.share, let lovedOne = lovedOne {
                SharingManager.shared.persistUpdatedShare(share, for: lovedOne)
            }
            complete()
        }
    }

    nonisolated func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        print("[CloudSharingPresenter] cloudSharingControllerDidStopSharing")
        Task { @MainActor in
            if let lovedOne = lovedOne {
                lovedOne.isSharedWithFamily = false
                PersistenceController.shared.save()
                await SharingManager.shared.refreshActiveShares()
            }
            complete()
        }
    }
}

/// Dummy view for backward compatibility - the actual presentation happens via CloudSharingPresenter
struct CloudSharingView: View {
    let share: CKShare?
    let lovedOne: LovedOne

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Color.clear
            .onAppear {
                // Use the presenter to show sharing UI
                // The onComplete callback handles dismissal when sharing finishes
                CloudSharingPresenter.shared.presentSharing(
                    for: lovedOne,
                    existingShare: share,
                    onComplete: {
                        dismiss()
                    }
                )
                // Note: Do NOT dismiss here - wait for presenter's onComplete callback
                // to avoid tearing down the view hierarchy while presenter is presenting
            }
    }
}

// MARK: - Share Button View

/// A button that initiates sharing for a LovedOne
struct ShareButton: View {
    let lovedOne: LovedOne
    @State private var showingShareSheet = false
    @State private var activeShare: CKShare?
    @State private var isLoading = false

    var body: some View {
        Button(action: initiateSharing) {
            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
            } else {
                Image(systemName: lovedOne.isSharedWithFamily ? "person.2.fill" : "person.badge.plus")
            }
        }
        .disabled(isLoading)
        .sheet(isPresented: $showingShareSheet) {
            CloudSharingView(share: activeShare, lovedOne: lovedOne)
        }
    }

    private func initiateSharing() {
        isLoading = true

        Task {
            // Get existing share if any
            activeShare = PersistenceController.shared.share(for: lovedOne)
            isLoading = false
            showingShareSheet = true
        }
    }
}

// MARK: - Shared Status Badge

/// A badge showing the sharing status of a LovedOne
struct SharedStatusBadge: View {
    let lovedOne: LovedOne
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        if lovedOne.isSharedWithFamily {
            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.caption2)
                Text("Shared")
                    .font(.caption2)
            }
            .foregroundStyle(themeManager.theme.primaryColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(themeManager.theme.primaryColor.opacity(0.15))
            .clipShape(Capsule())
        }
    }
}

// MARK: - Participant Avatar View

/// Displays a participant's avatar/initials
struct ParticipantAvatarView: View {
    let participant: CKShare.Participant
    let size: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .fill(colorForParticipant)
                .frame(width: size, height: size)

            Text(participant.initials)
                .font(.system(size: size * 0.4, weight: .medium))
                .foregroundStyle(.white)

            // Pending indicator
            if participant.acceptanceStatus == .pending {
                Circle()
                    .stroke(Color.orange, lineWidth: 2)
                    .frame(width: size, height: size)
            }
        }
    }

    private var colorForParticipant: Color {
        switch participant.role {
        case .owner:
            return .blue
        case .privateUser:
            return .green
        case .publicUser:
            return .purple
        default:
            return .gray
        }
    }
}

// MARK: - Participant Row View

/// A row displaying participant information
struct ParticipantRowView: View {
    let participant: CKShare.Participant

    var body: some View {
        HStack(spacing: 12) {
            ParticipantAvatarView(participant: participant, size: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(participant.displayName)
                    .font(.body)

                HStack(spacing: 4) {
                    if participant.role == .owner {
                        Text("Owner")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    if participant.acceptanceStatus == .pending {
                        Text("Pending")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else if participant.permission == .readOnly {
                        Text("View only")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            // Permission indicator
            Image(systemName: permissionIcon)
                .foregroundStyle(permissionColor)
        }
        .padding(.vertical, 4)
    }

    private var permissionIcon: String {
        switch participant.permission {
        case .readWrite:
            return "pencil.circle.fill"
        case .readOnly:
            return "eye.circle.fill"
        default:
            return "questionmark.circle"
        }
    }

    private var permissionColor: Color {
        switch participant.permission {
        case .readWrite:
            return .green
        case .readOnly:
            return .blue
        default:
            return .gray
        }
    }
}
