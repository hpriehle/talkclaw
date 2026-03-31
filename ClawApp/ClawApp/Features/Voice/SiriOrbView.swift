import SwiftUI

/// Siri-style orb with concentric glow rings
/// Audio-reactive and state-aware
struct SiriOrbView: View {
    let state: VoiceState
    let audioLevel: Float
    let size: CGFloat
    
    // Glow ring sizes (matching Omnira design)
    private var ring1Size: CGFloat { size * 1.38 }  // ~180
    private var ring2Size: CGFloat { size * 1.85 }  // ~240
    private var ring3Size: CGFloat { size * 2.38 }  // ~310
    
    private var glowBase: CGFloat {
        1.0 + CGFloat(audioLevel) * 0.5
    }
    
    private var theme: StateTheme {
        StateTheme.forState(state)
    }
    
    var body: some View {
        ZStack {
            // Outer ring (largest, most subtle)
            GlowRingView(
                size: ring3Size,
                color: theme.primary,
                audioLevel: audioLevel,
                glowScale: glowBase * 1.3,
                opacityMultiplier: 0.15
            )
            
            // Middle ring
            GlowRingView(
                size: ring2Size,
                color: theme.primary,
                audioLevel: audioLevel,
                glowScale: glowBase * 1.1,
                opacityMultiplier: 0.25
            )
            
            // Inner ring (brightest)
            GlowRingView(
                size: ring1Size,
                color: theme.primary,
                audioLevel: audioLevel,
                glowScale: glowBase,
                opacityMultiplier: 0.5
            )
            
            // Main orb
            Circle()
                .fill(
                    RadialGradient(
                        colors: [
                            theme.primary,
                            theme.glow
                        ],
                        center: .center,
                        startRadius: 0,
                        endRadius: size / 2
                    )
                )
                .frame(width: size, height: size)
                .scaleEffect(1.0 + CGFloat(audioLevel) * 0.3)
                .animation(.spring(response: 0.15, dampingFraction: 0.7), value: audioLevel)
                .shadow(color: theme.glow, radius: 20, x: 0, y: 0)
        }
    }
}

#Preview("Idle") {
    ZStack {
        Color.black.ignoresSafeArea()
        SiriOrbView(state: .idle, audioLevel: 0.0, size: 130)
    }
}

#Preview("Listening") {
    ZStack {
        Color.black.ignoresSafeArea()
        SiriOrbView(state: .listening, audioLevel: 0.6, size: 130)
    }
}

#Preview("Thinking") {
    ZStack {
        Color.black.ignoresSafeArea()
        SiriOrbView(state: .thinking, audioLevel: 0.0, size: 130)
    }
}
