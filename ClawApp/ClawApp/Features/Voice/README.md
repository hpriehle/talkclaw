# Voice Conversation Feature

SwiftUI implementation of voice conversation UI, inspired by Omnira-iOS design with Siri-style orb and ambient effects.

## Components

### Views

- **VoiceConversationView.swift** - Main full-screen modal for voice conversations
- **SiriOrbView.swift** - Animated Siri-style orb with concentric glow rings
- **GlowRingView.swift** - Single animated glow ring component
- **AmbientGlowView.swift** - Ambient background glow that shifts color per state
- **VoiceControlsView.swift** - Bottom controls (mute, end, speaker)
- **VoiceControlButton.swift** - Single control button component

### Models

- **VoiceState.swift** - Voice conversation state enum (idle, listening, thinking, speaking, error)
- **StateTheme.swift** - Theme configuration for each voice state (colors, labels)

### Services

- **LiveKitVoiceManager.swift** - Voice conversation manager (placeholder for LiveKit integration)

## Design System

### 5-State Color System

| State | Primary Color | Use Case |
|-------|--------------|----------|
| **Idle** | `#5B9EF5` (Blue) | Ready to start |
| **Listening** | `#34D399` (Green) | User is speaking |
| **Thinking** | `#A78BFA` (Purple) | AI is processing |
| **Speaking** | `#5B9EF5` (Blue) | AI is responding |
| **Error** | `#F97066` (Red) | Connection issue |

### Visual Elements

**Siri Orb:**
- Main orb: 130pt diameter
- 3 concentric glow rings (180pt, 240pt, 310pt)
- Audio-reactive scaling (responds to voice amplitude)
- Smooth state transitions with color shifts

**Ambient Glow:**
- Radial gradient background
- Shifts color based on current state
- Pulses during "thinking" state
- Audio-reactive opacity

**Bottom Controls:**
- Mute / End / Speaker buttons
- Glass morphism design (dark with subtle borders)
- "Switch to text" option below controls
- End button: prominent red circle

## Usage

```swift
import SwiftUI

struct MyView: View {
    @State private var showVoice = false
    let sessionId: String
    
    var body: some View {
        Button("Start Voice") {
            showVoice = true
        }
        .fullScreenCover(isPresented: $showVoice) {
            VoiceConversationView(sessionId: sessionId)
        }
    }
}
```

## Implementation Status

### ✅ Phase 1: UI Components (Complete)

All SwiftUI components built and ready:
- [x] State system (VoiceState, StateTheme)
- [x] Visual components (Orb, Glow rings, Controls)
- [x] Full-screen modal (VoiceConversationView)
- [x] Placeholder manager (LiveKitVoiceManager)

### 🔨 Phase 2: LiveKit Integration (TODO)

**Steps:**
1. Add LiveKit Swift SDK to Package.swift:
   ```swift
   .package(url: "https://github.com/livekit/client-sdk-swift", from: "2.0.0")
   ```

2. Update LiveKitVoiceManager.swift:
   - Import LiveKit framework
   - Implement actual room connection
   - Handle audio tracks
   - Process data channel messages

3. Backend integration:
   - Generate LiveKit tokens via TalkClawServer
   - Connect to LiveKit Agent Server (Python)
   - Handle transcript/state updates

### 🎯 Phase 3: Polish (TODO)

- [ ] Haptic feedback on state changes
- [ ] Background audio support
- [ ] Interruption handling
- [ ] Voice settings (speed, voice selection)
- [ ] Error recovery UI
- [ ] Accessibility features

## Architecture

```
VoiceConversationView (UI)
    ↓
LiveKitVoiceManager (Manager)
    ↓
LiveKit Swift SDK (Framework) — TODO: Add in Phase 2
    ↓
WebRTC → LiveKit Room
    ↓
LiveKit Agent Server (Python Backend)
    ├─► Deepgram STT
    ├─► OpenClaw API
    └─► ElevenLabs TTS
```

## Preview Support

All components include SwiftUI previews for easy development:

```bash
# In Xcode, open any component file and press Option+Cmd+Return
# to see live preview
```

## Testing

**Placeholder mode (current):**
- UI is fully functional
- Audio levels are simulated
- Transcript is mock data
- States transition automatically

**With LiveKit (Phase 2):**
- Real microphone input
- Actual STT/TTS
- OpenClaw integration
- End-to-end voice conversation

## Credits

UI design inspired by:
- Omnira-iOS voice interface (React Native)
- Apple Siri design language
- ChatGPT Advanced Voice mode

Ported from React Native to native SwiftUI by OpenClaw agent (March 2026).
