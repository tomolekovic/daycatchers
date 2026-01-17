import SwiftUI
import AVFoundation

/// AudioCaptureView allows users to record audio memories.
struct AudioCaptureView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    @StateObject private var permissions = PermissionsManager.shared
    @StateObject private var recorder = AudioRecorder()

    let lovedOne: LovedOne?
    let onCapture: (URL) -> Void

    @State private var showPermissionAlert = false

    var body: some View {
        NavigationStack {
            VStack(spacing: themeManager.theme.spacingLarge) {
                Spacer()

                // Visual indicator
                recordingIndicator

                // Duration display
                if recorder.isRecording || recorder.hasRecording {
                    Text(recorder.formattedDuration)
                        .font(.system(size: 48, weight: .light, design: .monospaced))
                        .foregroundStyle(themeManager.theme.textPrimary)
                }

                // Status text
                statusText

                Spacer()

                // Controls
                recordingControls
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(themeManager.theme.backgroundColor)
            .navigationTitle("Record Audio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        recorder.cleanup()
                        dismiss()
                    }
                }

                if recorder.hasRecording && !recorder.isRecording {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Use Recording") {
                            if let url = recorder.recordingURL {
                                onCapture(url)
                                dismiss()
                            }
                        }
                        .fontWeight(.semibold)
                    }
                }
            }
            .alert("Microphone Access Required", isPresented: $showPermissionAlert) {
                Button("Open Settings") {
                    permissions.openSettings()
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Daycatcher needs microphone access to record audio. Please enable it in Settings.")
            }
            .onAppear {
                checkPermission()
            }
        }
    }

    // MARK: - Recording Indicator

    private var recordingIndicator: some View {
        ZStack {
            // Outer pulsing circle when recording
            if recorder.isRecording {
                Circle()
                    .fill(MemoryType.audio.color.opacity(0.2))
                    .frame(width: 180, height: 180)
                    .scaleEffect(recorder.isRecording ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: recorder.isRecording)
            }

            // Main circle
            Circle()
                .fill(recorder.isRecording ? MemoryType.audio.color : themeManager.theme.surfaceColor)
                .frame(width: 150, height: 150)

            // Microphone icon
            Image(systemName: "mic.fill")
                .font(.system(size: 50))
                .foregroundStyle(recorder.isRecording ? .white : MemoryType.audio.color)
        }
    }

    // MARK: - Status Text

    private var statusText: some View {
        Group {
            if recorder.hasRecording && !recorder.isRecording {
                VStack(spacing: 4) {
                    Text("Recording Complete")
                        .font(themeManager.theme.headlineFont)
                        .foregroundStyle(themeManager.theme.textPrimary)

                    if let lovedOne = lovedOne {
                        Text("For \(lovedOne.name ?? "your loved one")")
                            .font(themeManager.theme.bodyFont)
                            .foregroundStyle(themeManager.theme.textSecondary)
                    }
                }
            } else if recorder.isRecording {
                Text("Recording...")
                    .font(themeManager.theme.headlineFont)
                    .foregroundStyle(MemoryType.audio.color)
            } else {
                VStack(spacing: 4) {
                    Text("Tap to start recording")
                        .font(themeManager.theme.headlineFont)
                        .foregroundStyle(themeManager.theme.textPrimary)

                    if let lovedOne = lovedOne {
                        Text("For \(lovedOne.name ?? "your loved one")")
                            .font(themeManager.theme.bodyFont)
                            .foregroundStyle(themeManager.theme.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Recording Controls

    private var recordingControls: some View {
        HStack(spacing: themeManager.theme.spacingLarge) {
            if recorder.hasRecording && !recorder.isRecording {
                // Discard button
                Button {
                    recorder.discardRecording()
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: "trash")
                            .font(.title2)
                        Text("Discard")
                            .font(themeManager.theme.captionFont)
                    }
                    .foregroundStyle(themeManager.theme.textSecondary)
                }

                // Play/Pause button
                Button {
                    recorder.togglePlayback()
                } label: {
                    ZStack {
                        Circle()
                            .fill(themeManager.theme.surfaceColor)
                            .frame(width: 70, height: 70)

                        Image(systemName: recorder.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundStyle(themeManager.theme.primaryColor)
                    }
                }
            } else {
                // Record/Stop button
                Button {
                    if recorder.isRecording {
                        recorder.stopRecording()
                    } else {
                        startRecording()
                    }
                } label: {
                    ZStack {
                        Circle()
                            .fill(MemoryType.audio.color)
                            .frame(width: 80, height: 80)

                        if recorder.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(.white)
                                .frame(width: 24, height: 24)
                        } else {
                            Circle()
                                .fill(.white)
                                .frame(width: 30, height: 30)
                        }
                    }
                }
            }
        }
        .padding(.bottom, themeManager.theme.spacingLarge)
    }

    // MARK: - Permission Handling

    private func checkPermission() {
        Task {
            let granted = await permissions.requestMicrophonePermission()
            if !granted {
                showPermissionAlert = true
            }
        }
    }

    private func startRecording() {
        Task {
            let granted = await permissions.requestMicrophonePermission()
            if granted {
                recorder.startRecording()
            } else {
                showPermissionAlert = true
            }
        }
    }
}

// MARK: - Audio Recorder

@MainActor
class AudioRecorder: NSObject, ObservableObject {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var hasRecording = false
    @Published var duration: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var timer: Timer?

    var recordingURL: URL? {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsPath.appendingPathComponent("temp_recording.m4a")
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }

    override init() {
        super.init()
    }

    func startRecording() {
        guard let url = recordingURL else { return }

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
            AVSampleRateKey: 44100,
            AVNumberOfChannelsKey: 1,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)

            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.record()

            isRecording = true
            hasRecording = false
            duration = 0

            startTimer()
        } catch {
            print("Failed to start recording: \(error)")
        }
    }

    func stopRecording() {
        audioRecorder?.stop()
        audioRecorder = nil
        isRecording = false
        hasRecording = true
        stopTimer()
    }

    func discardRecording() {
        cleanup()
        hasRecording = false
        duration = 0
    }

    func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        guard let url = recordingURL else { return }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()
            isPlaying = true
        } catch {
            print("Failed to play recording: \(error)")
        }
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
    }

    func cleanup() {
        stopRecording()
        stopPlayback()

        if let url = recordingURL {
            try? FileManager.default.removeItem(at: url)
        }
    }

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.duration += 1
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }
}

extension AudioRecorder: AVAudioPlayerDelegate {
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in
            isPlaying = false
        }
    }
}

#Preview {
    AudioCaptureView(lovedOne: nil) { _ in }
        .environmentObject(ThemeManager())
}
