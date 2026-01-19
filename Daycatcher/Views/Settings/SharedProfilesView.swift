import SwiftUI
import CoreData
import CloudKit

/// View for managing shared profiles in Family Sharing settings.
struct SharedProfilesView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.managedObjectContext) private var viewContext

    @StateObject private var sharingManager = SharingManager.shared

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \LovedOne.name, ascending: true)],
        predicate: NSPredicate(format: "isSharedWithFamily == YES")
    )
    private var sharedLovedOnes: FetchedResults<LovedOne>

    var body: some View {
        List {
            if sharedLovedOnes.isEmpty {
                emptyState
            } else {
                sharedProfilesSection
            }

            howItWorksSection
        }
        .navigationTitle("Family Sharing")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await sharingManager.refreshActiveShares()
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        Section {
            VStack(spacing: 16) {
                Image(systemName: "person.2.slash")
                    .font(.system(size: 50))
                    .foregroundStyle(themeManager.theme.textSecondary.opacity(0.5))

                Text("No Shared Profiles")
                    .font(themeManager.theme.headlineFont)
                    .foregroundStyle(themeManager.theme.textPrimary)

                Text("Share a loved one's profile to let family members view and add memories together.")
                    .font(themeManager.theme.bodyFont)
                    .foregroundStyle(themeManager.theme.textSecondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 32)
        }
    }

    // MARK: - Shared Profiles Section

    private var sharedProfilesSection: some View {
        Section("Shared Profiles") {
            ForEach(sharedLovedOnes) { lovedOne in
                SharedProfileRow(
                    lovedOne: lovedOne,
                    onManage: {
                        let existingShare = PersistenceController.shared.share(for: lovedOne)
                        CloudSharingPresenter.shared.presentSharing(for: lovedOne, existingShare: existingShare)
                    }
                )
            }
        }
    }

    // MARK: - How It Works Section

    private var howItWorksSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HowItWorksRow(
                    icon: "person.badge.plus",
                    title: "Share a Profile",
                    description: "Tap the share button on any profile to invite family members."
                )

                HowItWorksRow(
                    icon: "envelope.fill",
                    title: "Send Invitation",
                    description: "Family members receive an invite via Messages, Email, or a link."
                )

                HowItWorksRow(
                    icon: "photo.on.rectangle.angled",
                    title: "Add Memories Together",
                    description: "Everyone with access can add photos, videos, and notes."
                )

                HowItWorksRow(
                    icon: "icloud.fill",
                    title: "Sync Everywhere",
                    description: "All memories sync automatically to everyone's devices."
                )
            }
            .padding(.vertical, 8)
        } header: {
            Text("How It Works")
        }
    }
}

// MARK: - Shared Profile Row

struct SharedProfileRow: View {
    let lovedOne: LovedOne
    let onManage: () -> Void

    @EnvironmentObject var themeManager: ThemeManager
    private let sharingManager = SharingManager.shared

    var body: some View {
        Button(action: onManage) {
            HStack(spacing: 12) {
                // Profile image
                profileImage

                // Profile info
                VStack(alignment: .leading, spacing: 4) {
                    Text(lovedOne.name ?? "Unknown")
                        .font(themeManager.theme.bodyFont)
                        .foregroundStyle(themeManager.theme.textPrimary)

                    // Participant info
                    HStack(spacing: 4) {
                        participantAvatars

                        Text(sharingManager.participantCountText(for: lovedOne))
                            .font(.caption)
                            .foregroundStyle(themeManager.theme.textSecondary)
                    }
                }

                Spacer()

                // Owner/participant indicator
                if sharingManager.isOwner(of: lovedOne) {
                    Text("Owner")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.secondary.opacity(0.15))
                        .clipShape(Capsule())
                }

                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private var profileImage: some View {
        if let imageURL = lovedOne.profileImageURL,
           let imageData = try? Data(contentsOf: imageURL),
           let uiImage = UIImage(data: imageData) {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFill()
                .frame(width: 50, height: 50)
                .clipShape(Circle())
        } else {
            Circle()
                .fill(themeManager.theme.primaryColor.opacity(0.2))
                .frame(width: 50, height: 50)
                .overlay {
                    Text(initials)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(themeManager.theme.primaryColor)
                }
        }
    }

    private var initials: String {
        let name = lovedOne.name ?? ""
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1)).uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    @ViewBuilder
    private var participantAvatars: some View {
        let participants = sharingManager.acceptedParticipants(for: lovedOne)
        let displayCount = min(participants.count, 3)

        HStack(spacing: -8) {
            ForEach(0..<displayCount, id: \.self) { index in
                ParticipantAvatarView(participant: participants[index], size: 20)
                    .overlay {
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    }
            }

            // Show pending count if any
            let pendingCount = sharingManager.pendingParticipants(for: lovedOne).count
            if pendingCount > 0 {
                Text("+\(pendingCount)")
                    .font(.caption2)
                    .foregroundStyle(.white)
                    .frame(width: 20, height: 20)
                    .background(Color.orange)
                    .clipShape(Circle())
                    .overlay {
                        Circle()
                            .stroke(Color(.systemBackground), lineWidth: 2)
                    }
            }
        }
    }
}

// MARK: - How It Works Row

struct HowItWorksRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.purple)
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        SharedProfilesView()
    }
    .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
    .environmentObject(ThemeManager())
}
