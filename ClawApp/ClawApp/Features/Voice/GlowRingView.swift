import SwiftUI

/// Single animated glow ring for voice visualization
struct GlowRingView: View {
    let size: CGFloat
    let color: Color
    let audioLevel: Float
    let glowScale: CGFloat
    let opacityMultiplier: Double
    
    @State private var animatedScale: CGFloat = 1.0
    
    var body: some View {
        Circle()
            .stroke(color, lineWidth: 1)
            .frame(width: size, height: size)
            .opacity(glowOpacity)
            .scaleEffect(animatedScale)
            .animation(.spring(response: 0.12, dampingFraction: 0.8), value: animatedScale)
            .onChange(of: glowScale) { _, newValue in
                animatedScale = newValue
            }
    }
    
    private var glowOpacity: Double {
        (0.15 + Double(audioLevel) * 0.4) * opacityMultiplier
    }
}

#Preview {
    ZStack {
        Color.black.ignoresSafeArea()
        
        GlowRingView(
            size: 200,
            color: Color(hex: "5B9EF5"),
            audioLevel: 0.3,
            glowScale: 1.2,
            opacityMultiplier: 0.5
        )
    }
}
