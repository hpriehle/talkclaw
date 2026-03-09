import SwiftUI

struct VoiceRecordingOverlay: View {
    let audioManager: AudioRecorderManager
    let onCancel: () -> Void

    @State private var startTime = Date()
    @State private var elapsedTime: TimeInterval = 0
    @State private var timer: Timer?
    @State private var pulsing = false

    var body: some View {
        HStack(spacing: Theme.Spacing.sm) {
            // Tappable cancel button
            Button(action: onCancel) {
                HStack(spacing: 3) {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                }
                .foregroundStyle(Theme.Colors.error)
                .frame(width: 28, height: 28)
                .background(Theme.Colors.error.opacity(0.15), in: Circle())
            }

            // Red pulsing dot
            Circle()
                .fill(Theme.Colors.error)
                .frame(width: 8, height: 8)
                .scaleEffect(pulsing ? 1.4 : 1.0)
                .animation(
                    .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                    value: pulsing
                )

            // Timer
            Text(formattedTime)
                .font(Theme.Typography.subhead)
                .foregroundStyle(Theme.Colors.textPrimary)
                .monospacedDigit()
                .frame(width: 40, alignment: .leading)

            // Waveform
            WaveformView(
                samples: audioManager.levelSamples,
                accentColor: Theme.Colors.accent
            )
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, Theme.Spacing.md)
        .padding(.vertical, Theme.Spacing.sm)
        .glassCard(cornerRadius: Theme.Radius.xl)
        .onAppear {
            startTime = Date()
            pulsing = true
            timer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                Task { @MainActor in
                    elapsedTime = Date().timeIntervalSince(startTime)
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }

    private var formattedTime: String {
        let seconds = Int(elapsedTime) % 60
        let minutes = Int(elapsedTime) / 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}
