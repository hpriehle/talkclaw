import SwiftUI

/// Single control button for voice interface (mute/speaker)
struct VoiceControlButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let action: () -> Void
    
    private let errorColor = Color(hex: "F97066")
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                // Button circle
                ZStack {
                    Circle()
                        .fill(backgroundColor)
                        .frame(width: 48, height: 48)
                        .overlay(
                            Circle()
                                .stroke(borderColor, lineWidth: 1)
                        )
                    
                    Image(systemName: icon)
                        .font(.system(size: 22))
                        .foregroundColor(iconColor)
                }
                
                // Label
                Text(label)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(Color.white.opacity(0.35))
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var backgroundColor: Color {
        isActive ? errorColor.opacity(0.12) : Color.white.opacity(0.08)
    }
    
    private var borderColor: Color {
        isActive ? errorColor.opacity(0.2) : Color.white.opacity(0.06)
    }
    
    private var iconColor: Color {
        isActive ? errorColor : Color.white.opacity(0.6)
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        HStack(spacing: 32) {
            VoiceControlButton(
                icon: "mic",
                label: "Mute",
                isActive: false,
                action: {}
            )
            
            VoiceControlButton(
                icon: "mic.slash",
                label: "Unmute",
                isActive: true,
                action: {}
            )
        }
    }
}
