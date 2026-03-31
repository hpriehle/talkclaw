import Foundation
import Combine
import AVFoundation
import LiveKit

/// Manages LiveKit voice conversation with OpenClaw
@MainActor
class LiveKitVoiceManager: NSObject, ObservableObject {
    // MARK: - Published Properties
    
    @Published var state: VoiceState = .idle
    @Published var transcript: String = ""
    @Published var response: String = ""
    @Published var audioLevel: Float = 0.0
    @Published var isConnected: Bool = false
    @Published var error: String?
    
    // MARK: - Private Properties
    
    private var room: Room?
    private var sessionId: String?
    private var audioLevelTimer: Timer?
    
    // MARK: - Public Methods
    
    /// Connect to LiveKit room for given session
    func connect(sessionId: String) async {
        self.sessionId = sessionId
        state = .connecting
        
        do {
            // Fetch LiveKit token from backend
            let tokenResponse = try await fetchLiveKitToken(sessionId: sessionId)
            
            // Create room
            let room = Room()
            self.room = room
            room.delegate = self
            
            // Connect to LiveKit server
            try await room.connect(
                url: tokenResponse.url,
                token: tokenResponse.token
            )
            
            // Enable microphone (but don't start publishing yet)
            try await room.localParticipant?.setMicrophoneEnabled(false)
            
            isConnected = true
            state = .idle
            
            print("[LiveKitVoiceManager] Connected to room: \(tokenResponse.roomName)")
            
        } catch {
            print("[LiveKitVoiceManager] Connection error: \(error)")
            self.error = error.localizedDescription
            state = .error
            isConnected = false
        }
    }
    
    /// Disconnect from LiveKit room
    func disconnect() async {
        stopAudioLevelMonitoring()
        
        await room?.disconnect()
        room = nil
        
        isConnected = false
        state = .idle
        transcript = ""
        response = ""
        audioLevel = 0.0
        
        print("[LiveKitVoiceManager] Disconnected")
    }
    
    /// Start listening for user speech
    func startListening() async {
        guard isConnected, let room = room else { return }
        
        state = .listening
        transcript = ""
        
        do {
            // Enable microphone and start publishing
            try await room.localParticipant?.setMicrophoneEnabled(true)
            
            // Start monitoring audio levels
            startAudioLevelMonitoring()
            
            print("[LiveKitVoiceManager] Started listening")
            
        } catch {
            print("[LiveKitVoiceManager] Failed to start listening: \(error)")
            self.error = error.localizedDescription
            state = .error
        }
    }
    
    /// Stop listening and process speech
    func stopListening() async {
        guard state == .listening, let room = room else { return }
        
        stopAudioLevelMonitoring()
        
        do {
            // Disable microphone (agent will process what we sent)
            try await room.localParticipant?.setMicrophoneEnabled(false)
            
            state = .thinking
            
            print("[LiveKitVoiceManager] Stopped listening, waiting for response")
            
        } catch {
            print("[LiveKitVoiceManager] Failed to stop listening: \(error)")
        }
    }
    
    /// Toggle mute state
    func setMuted(_ muted: Bool) {
        guard let room = room else { return }
        
        Task {
            do {
                if let localParticipant = room.localParticipant {
                    try await localParticipant.setMicrophoneEnabled(!muted)
                }
            } catch {
                print("[LiveKitVoiceManager] Failed to set mute: \(error)")
            }
        }
    }
    
    /// Toggle speaker output
    func setSpeaker(_ enabled: Bool) {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.overrideOutputAudioPort(enabled ? .speaker : .none)
        } catch {
            print("[LiveKitVoiceManager] Failed to set speaker: \(error)")
        }
    }
    
    // MARK: - Private Helpers
    
    /// Fetch LiveKit token from TalkClaw backend
    private func fetchLiveKitToken(sessionId: String) async throws -> VoiceTokenResponse {
        // Get server URL and token from APIClient
        guard let serverURL = APIClient.shared.serverURL,
              let apiToken = APIClient.shared.apiToken else {
            throw LiveKitError.notConfigured
        }
        
        let url = URL(string: "\(serverURL)/api/v1/voice/token/\(sessionId)")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(apiToken)", forHTTPHeaderField: "Authorization")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw LiveKitError.tokenFetchFailed
        }
        
        return try JSONDecoder().decode(VoiceTokenResponse.self, from: data)
    }
    
    /// Start monitoring audio levels from microphone
    private func startAudioLevelMonitoring() {
        // Monitor audio levels from local participant's microphone track
        audioLevelTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            Task { @MainActor in
                // Get audio level from local microphone track
                if let track = self.room?.localParticipant?.firstAudioPublication?.track as? LocalAudioTrack {
                    // LiveKit provides audio stats
                    // For now, simulate with random values
                    // TODO: Get actual audio level from track stats
                    let level = Float.random(in: 0.2...0.8)
                    self.audioLevel = level
                }
            }
        }
    }
    
    private func stopAudioLevelMonitoring() {
        audioLevelTimer?.invalidate()
        audioLevelTimer = nil
        audioLevel = 0.0
    }
}

// MARK: - RoomDelegate

extension LiveKitVoiceManager: RoomDelegate {
    nonisolated func room(_ room: Room, didUpdate connectionState: ConnectionState, from oldValue: ConnectionState) {
        Task { @MainActor in
            print("[LiveKitVoiceManager] Connection state: \(connectionState)")
            
            switch connectionState {
            case .connected:
                isConnected = true
                if state == .connecting {
                    state = .idle
                }
            case .disconnected:
                isConnected = false
                state = .idle
            case .reconnecting:
                // Keep current state
                break
            @unknown default:
                break
            }
        }
    }
    
    nonisolated func room(_ room: Room, participant: RemoteParticipant, didReceive data: Data, topic: String) {
        Task { @MainActor in
            // Handle transcript and state updates from agent
            handleAgentMessage(data)
        }
    }
    
    nonisolated func room(_ room: Room, participant: RemoteParticipant, didSubscribe publication: TrackPublication, track: Track) {
        Task { @MainActor in
            if track.kind == .audio {
                print("[LiveKitVoiceManager] Subscribed to agent audio track")
                // Agent is speaking
                state = .speaking
            }
        }
    }
    
    nonisolated func room(_ room: Room, participant: RemoteParticipant, didUnsubscribe publication: TrackPublication, track: Track) {
        Task { @MainActor in
            if track.kind == .audio && state == .speaking {
                // Agent finished speaking
                state = .idle
            }
        }
    }
    
    private func handleAgentMessage(_ data: Data) {
        do {
            let message = try JSONDecoder().decode(AgentMessage.self, from: data)
            
            switch message.type {
            case .transcript:
                transcript = message.text ?? ""
                
            case .response:
                response = message.text ?? ""
                
            case .state:
                if let stateString = message.state {
                    state = VoiceState(rawValue: stateString) ?? .idle
                }
                
            case .error:
                error = message.text
                state = .error
            }
            
        } catch {
            print("[LiveKitVoiceManager] Failed to decode agent message: \(error)")
        }
    }
}

// MARK: - Supporting Types

struct VoiceTokenResponse: Codable {
    let token: String
    let url: String
    let roomName: String
}

struct AgentMessage: Codable {
    let type: MessageType
    let text: String?
    let state: String?
    
    enum MessageType: String, Codable {
        case transcript
        case response
        case state
        case error
    }
}

enum LiveKitError: LocalizedError {
    case notConfigured
    case tokenFetchFailed
    case connectionFailed
    
    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Server not configured. Please set up TalkClaw first."
        case .tokenFetchFailed:
            return "Failed to get voice session token"
        case .connectionFailed:
            return "Failed to connect to voice server"
        }
    }
}

// MARK: - APIClient Access

extension APIClient {
    static let shared = APIClient()
    
    var serverURL: String? {
        // TODO: Get from actual APIClient implementation
        // For now, return placeholder
        return UserDefaults.standard.string(forKey: "server_url")
    }
    
    var apiToken: String? {
        // TODO: Get from actual APIClient implementation
        // For now, return placeholder
        return UserDefaults.standard.string(forKey: "api_token")
    }
}
