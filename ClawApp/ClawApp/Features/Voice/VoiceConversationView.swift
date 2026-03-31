import SwiftUI

/// Full-screen voice conversation modal
/// Inspired by Omnira-iOS design with Siri-style orb and ambient effects
struct VoiceConversationView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var voiceManager = LiveKitVoiceManager()
    
    @State private var showTranscript = false
    @State private var isMuted = false
    @State private var isSpeakerOn = true
    
    let sessionId: String
    
    private var theme: StateTheme {
        StateTheme.forState(voiceManager.state)
    }
    
    var body: some View {
        ZStack {
            // Background
            Color.black.ignoresSafeArea()
            
            // Ambient glow
            AmbientGlowView(
                theme: theme,
                audioLevel: voiceManager.audioLevel,
                state: voiceManager.state
            )
            
            VStack(spacing: 0) {
                // Top bar
                topBar
                
                Spacer()
                
                // Main orb area
                orbArea
                
                Spacer()
                
                // Transcript area (if visible)
                if showTranscript {
                    transcriptArea
                }
                
                // Bottom controls
                VoiceControlsView(
                    isMuted: $isMuted,
                    isSpeakerOn: $isSpeakerOn,
                    onEnd: handleClose
                )
                .padding(.bottom, 20)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            Task {
                await voiceManager.connect(sessionId: sessionId)
            }
        }
        .onDisappear {
            Task {
                await voiceManager.disconnect()
            }
        }
    }
    
    // MARK: - Top Bar
    
    private var topBar: some View {
        HStack {
            // Back button
            Button(action: handleClose) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 22))
                    .foregroundColor(Color.white.opacity(0.6))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
            }
            
            Spacer()
            
            // Status indicator
            HStack(spacing: 8) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 6, height: 6)
                    .shadow(
                        color: voiceManager.state == .idle ? .clear : theme.primary,
                        radius: 4
                    )
                
                Text(voiceManager.state == .idle ? "Voice Mode" : theme.label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.6))
            }
            
            Spacer()
            
            // Transcript toggle
            Button(action: { showTranscript.toggle() }) {
                Image(systemName: "text.bubble")
                    .font(.system(size: 20))
                    .foregroundColor(showTranscript ? Color(hex: "5B9EF5") : Color.white.opacity(0.4))
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color.white.opacity(0.05))
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.06), lineWidth: 1)
                            )
                    )
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 8)
    }
    
    private var statusColor: Color {
        voiceManager.state == .idle ? Color.white.opacity(0.2) : theme.primary
    }
    
    // MARK: - Orb Area
    
    private var orbArea: some View {
        VStack(spacing: 24) {
            // Main orb with glow rings
            Button(action: handleOrbTap) {
                SiriOrbView(
                    state: voiceManager.state,
                    audioLevel: voiceManager.audioLevel,
                    size: 130
                )
            }
            .buttonStyle(PlainButtonStyle())
            .disabled(voiceManager.state == .speaking || voiceManager.state == .thinking)
            
            // State label
            VStack(spacing: 6) {
                Text(stateText)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(theme.primary)
                
                if voiceManager.state == .error {
                    Text("Tap to retry")
                        .font(.system(size: 12))
                        .foregroundColor(Color.white.opacity(0.3))
                }
            }
        }
    }
    
    private var stateText: String {
        if voiceManager.state == .error {
            return "Connection lost"
        } else if voiceManager.state == .idle {
            return voiceManager.isConnected ? "Tap to start" : "Tap to connect"
        } else {
            return theme.label
        }
    }
    
    // MARK: - Transcript Area
    
    private var transcriptArea: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if !voiceManager.transcript.isEmpty {
                    transcriptBlock(label: "YOU", text: voiceManager.transcript)
                }
                
                if !voiceManager.response.isEmpty {
                    transcriptBlock(
                        label: "AI",
                        text: voiceManager.response,
                        color: Color(hex: "5B9EF5").opacity(0.5)
                    )
                }
            }
            .padding(.horizontal, 24)
        }
        .frame(maxHeight: 180)
    }
    
    private func transcriptBlock(label: String, text: String, color: Color = Color.white.opacity(0.3)) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 11, weight: .semibold))
                .tracking(0.8)
                .foregroundColor(color)
            
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(Color.white.opacity(0.6))
                .lineSpacing(6)
        }
    }
    
    // MARK: - Actions
    
    private func handleOrbTap() {
        Task {
            if !voiceManager.isConnected {
                await voiceManager.connect(sessionId: sessionId)
            } else if voiceManager.state == .listening {
                await voiceManager.stopListening()
            } else if voiceManager.state == .idle || voiceManager.state == .error {
                await voiceManager.startListening()
            }
        }
    }
    
    private func handleClose() {
        Task {
            await voiceManager.disconnect()
            dismiss()
        }
    }
}

#Preview {
    VoiceConversationView(sessionId: "test-session")
}
