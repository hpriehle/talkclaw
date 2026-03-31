import Foundation

/// Voice conversation states
enum VoiceState: String, Equatable {
    case idle = "idle"
    case connecting = "connecting"
    case listening = "listening"
    case thinking = "thinking"
    case speaking = "speaking"
    case error = "error"
    
    var displayLabel: String {
        switch self {
        case .idle:
            return "Tap to speak"
        case .connecting:
            return "Connecting..."
        case .listening:
            return "Listening..."
        case .thinking:
            return "Thinking..."
        case .speaking:
            return "Speaking..."
        case .error:
            return "Error occurred"
        }
    }
}
