import SwiftUI

/// Theme configuration for each voice state
struct StateTheme {
    let primary: Color
    let glow: Color
    let dim: Color
    let label: String
    
    static func forState(_ state: VoiceState) -> StateTheme {
        switch state {
        case .idle:
            return StateTheme(
                primary: Color(hex: "5B9EF5"),
                glow: Color(hex: "5B9EF5").opacity(0.25),
                dim: Color(hex: "5B9EF5").opacity(0.12),
                label: state.displayLabel
            )
            
        case .connecting:
            return StateTheme(
                primary: Color(hex: "5B9EF5"),
                glow: Color(hex: "5B9EF5").opacity(0.25),
                dim: Color(hex: "5B9EF5").opacity(0.12),
                label: state.displayLabel
            )
            
        case .listening:
            return StateTheme(
                primary: Color(hex: "34D399"),
                glow: Color(hex: "34D399").opacity(0.25),
                dim: Color(hex: "34D399").opacity(0.12),
                label: state.displayLabel
            )
            
        case .thinking:
            return StateTheme(
                primary: Color(hex: "A78BFA"),
                glow: Color(hex: "A78BFA").opacity(0.20),
                dim: Color(hex: "A78BFA").opacity(0.12),
                label: state.displayLabel
            )
            
        case .speaking:
            return StateTheme(
                primary: Color(hex: "5B9EF5"),
                glow: Color(hex: "5B9EF5").opacity(0.25),
                dim: Color(hex: "5B9EF5").opacity(0.12),
                label: state.displayLabel
            )
            
        case .error:
            return StateTheme(
                primary: Color(hex: "F97066"),
                glow: Color(hex: "F97066").opacity(0.25),
                dim: Color(hex: "F97066").opacity(0.15),
                label: state.displayLabel
            )
        }
    }
}
