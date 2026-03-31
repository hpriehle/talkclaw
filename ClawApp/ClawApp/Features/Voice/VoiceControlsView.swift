import SwiftUI

/// Bottom controls for voice conversation
/// Includes mute, end call, and speaker buttons
struct VoiceControlsView: View {
    @Binding var isMuted: Bool
    @Binding var isSpeakerOn: Bool
    let onEnd: () -> Void
    
    private let errorColor = Color(hex: "F97066")
    
    var body: some View {
        VStack(spacing: 16) {
            // Main controls row
            HStack(spacing: 32) {
                // Mute button
                VoiceControlButton(
                    icon: isMuted ? "mic.slash" : "mic",
                    label: isMuted ? "Unmute" : "Mute",
                    isActive: isMuted,
                    action: { isMuted.toggle() }
                )
                
                // End call button (prominent)
                Button(action: onEnd) {
                    Circle()
                        .fill(errorColor)
                        .frame(width: 56, height: 56)
                        .overlay(
                            Image(systemName: "xmark")
                                .font(.system(size: 28, weight: .medium))
                                .foregroundColor(.white)
                        )
                        .shadow(color: errorColor.opacity(0.3), radius: 10, x: 0, y: 4)
                }
                
                // Speaker button
                VoiceControlButton(
                    icon: isSpeakerOn ? "speaker.wave.3" : "speaker.slash",
                    label: "Speaker",
                    isActive: !isSpeakerOn,
                    action: { isSpeakerOn.toggle() }
                )
            }
            
            // Switch to text button
            Button(action: onEnd) {
                HStack(spacing: 8) {
                    Image(systemName: "text.bubble")
                        .font(.system(size: 16))
                    
                    Text("Switch to text")
                        .font(.system(size: 13, weight: .medium))
                }
                .foregroundColor(Color.white.opacity(0.45))
                .padding(.horizontal, 20)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 22)
                        .fill(Color.white.opacity(0.04))
                        .overlay(
                            RoundedRectangle(cornerRadius: 22)
                                .stroke(Color.white.opacity(0.06), lineWidth: 1)
                        )
                )
            }
            .buttonStyle(PlainButtonStyle())
        }
        .padding(.horizontal, 24)
        .padding(.top, 8)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        VStack {
            Spacer()
            
            VoiceControlsView(
                isMuted: .constant(false),
                isSpeakerOn: .constant(true),
                onEnd: {}
            )
            .padding(.bottom, 40)
        }
    }
}
