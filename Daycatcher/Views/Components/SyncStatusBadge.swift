import SwiftUI

/// A badge component displaying the current sync status of a memory or media item.
/// Shows an icon and optional text based on the sync state.
struct SyncStatusBadge: View {
    let status: MediaSyncStatus
    var showLabel: Bool = true
    var progress: Double? = nil

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        HStack(spacing: 6) {
            statusIcon
            if showLabel {
                Text(status.displayName)
                    .font(themeManager.theme.captionFont)
            }
        }
        .foregroundStyle(status.color)
        .padding(.horizontal, showLabel ? 10 : 6)
        .padding(.vertical, 4)
        .background(status.color.opacity(0.1))
        .clipShape(Capsule())
    }

    @ViewBuilder
    private var statusIcon: some View {
        switch status {
        case .pending:
            Image(systemName: status.icon)
                .font(.caption)

        case .uploading:
            if let progress = progress, progress > 0 {
                CircularProgressView(progress: progress, lineWidth: 2)
                    .frame(width: 14, height: 14)
            } else {
                ProgressView()
                    .scaleEffect(0.6)
                    .frame(width: 14, height: 14)
            }

        case .downloading:
            ProgressView()
                .scaleEffect(0.6)
                .frame(width: 14, height: 14)

        case .synced:
            Image(systemName: status.icon)
                .font(.caption)

        case .failed:
            Image(systemName: status.icon)
                .font(.caption)

        case .localOnly:
            Image(systemName: status.icon)
                .font(.caption)
        }
    }
}

/// A compact sync status indicator for use in grid/thumbnail views.
/// Shows just an icon overlay.
struct SyncStatusIndicator: View {
    let status: MediaSyncStatus
    var progress: Double? = nil

    var body: some View {
        Group {
            switch status {
            case .uploading:
                if let progress = progress, progress > 0 {
                    CircularProgressView(progress: progress, lineWidth: 2)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundStyle(.blue)
                }

            case .downloading:
                Image(systemName: "arrow.down.circle.fill")
                    .foregroundStyle(.blue)

            case .failed:
                Image(systemName: "exclamationmark.circle.fill")
                    .foregroundStyle(.red)

            case .pending:
                Image(systemName: "clock.fill")
                    .foregroundStyle(.orange)

            case .synced, .localOnly:
                EmptyView()
            }
        }
        .font(.caption)
        .background(
            Circle()
                .fill(.white.opacity(0.8))
                .frame(width: 18, height: 18)
        )
    }
}

/// A circular progress indicator view
struct CircularProgressView: View {
    let progress: Double
    var lineWidth: CGFloat = 3
    var backgroundColor: Color = .gray.opacity(0.3)
    var foregroundColor: Color = .blue

    var body: some View {
        ZStack {
            Circle()
                .stroke(backgroundColor, lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(foregroundColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.2), value: progress)
        }
    }
}

// MARK: - Previews

#Preview("Sync Status Badge") {
    VStack(spacing: 16) {
        ForEach(MediaSyncStatus.allCases) { status in
            SyncStatusBadge(status: status)
        }

        SyncStatusBadge(status: .uploading, progress: 0.65)
    }
    .padding()
    .environmentObject(ThemeManager())
}

#Preview("Sync Status Indicator") {
    HStack(spacing: 20) {
        ForEach(MediaSyncStatus.allCases) { status in
            SyncStatusIndicator(status: status)
        }
    }
    .padding()
    .background(Color.gray.opacity(0.2))
}

#Preview("Circular Progress") {
    HStack(spacing: 20) {
        CircularProgressView(progress: 0.25)
            .frame(width: 40, height: 40)

        CircularProgressView(progress: 0.5)
            .frame(width: 40, height: 40)

        CircularProgressView(progress: 0.75)
            .frame(width: 40, height: 40)

        CircularProgressView(progress: 1.0)
            .frame(width: 40, height: 40)
    }
    .padding()
}
