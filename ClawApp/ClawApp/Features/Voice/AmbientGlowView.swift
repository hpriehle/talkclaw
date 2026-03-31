import SwiftUI

/// Ambient background glow that shifts color per voice state
struct AmbientGlowView: View {
    let theme: StateTheme
    let audioLevel: Float
    let state: VoiceState
    
    @State private var pulseScale: CGFloat = 1.0
    
    var body: some View {
        ZStack {
            // Primary glow (ellipse)
            Ellipse()
                .fill(
                    RadialGradient(
                        colors: [
                            theme.glow.opacity(0.6),
                            theme.glow.opacity(0.3),
                            Color.clear
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: 400
                    )
                )
                .frame(width: UIScreen.main.bounds.width, height: UIScreen.main.bounds.height * 0.7)
                .offset(y: -80)
                .scaleEffect(pulseScale)
                .opacity(glowOpacity)
                .animation(.spring(response: 0.15), value: pulseScale)
            
            // Secondary ambient layer
            Rectangle()
                .fill(theme.dim.opacity(0.3))
                .ignoresSafeArea()
        }
        .allowsHitTesting(false)
        .onAppear {
            startPulsing()
        }
        .onChange(of: state) { _, _ in
            startPulsing()
        }
        .onChange(of: audioLevel) { _, newLevel in
            if state != .thinking {
                pulseScale = 1.0 + CGFloat(newLevel) * 0.15
            }
        }
    }
    
    private var glowOpacity: Double {
        0.4 + Double(audioLevel) * 0.3
    }
    
    private func startPulsing() {
        if state == .thinking {
            withAnimation(
                .easeInOut(duration: 2.0)
                .repeatForever(autoreverses: true)
            ) {
                pulseScale = 1.08
            }
        }
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        AmbientGlowView(
            theme: StateTheme.forState(.listening),
            audioLevel: 0.5,
            state: .listening
        )
    }
}
