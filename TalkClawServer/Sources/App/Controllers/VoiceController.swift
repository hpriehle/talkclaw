import Vapor

struct VoiceController: RouteCollection {
    func boot(routes: RoutesBuilder) throws {
        let voice = routes.grouped("api", "v1", "voice")
        
        // Generate LiveKit token for session
        voice.post("token", ":sessionId", use: generateToken)
    }
    
    func generateToken(req: Request) async throws -> VoiceTokenResponse {
        guard let sessionId = req.parameters.get("sessionId") else {
            throw Abort(.badRequest, reason: "Session ID required")
        }
        
        // Get LiveKit configuration from environment
        guard let livekitUrl = Environment.get("LIVEKIT_URL") else {
            throw Abort(.internalServerError, reason: "LIVEKIT_URL not configured")
        }
        
        guard let apiKey = Environment.get("LIVEKIT_API_KEY") else {
            throw Abort(.internalServerError, reason: "LIVEKIT_API_KEY not configured")
        }
        
        guard let apiSecret = Environment.get("LIVEKIT_API_SECRET") else {
            throw Abort(.internalServerError, reason: "LIVEKIT_API_SECRET not configured")
        }
        
        // Generate room name from session ID
        let roomName = "talkclaw-\(sessionId)"
        
        // Generate access token
        // TODO: Use actual JWT library for production
        // For now, return configuration for client to connect
        let token = try generateLiveKitToken(
            apiKey: apiKey,
            apiSecret: apiSecret,
            roomName: roomName,
            identity: "user-\(sessionId)",
            ttl: 3600 // 1 hour
        )
        
        return VoiceTokenResponse(
            token: token,
            url: livekitUrl,
            roomName: roomName
        )
    }
    
    /// Generate LiveKit access token (JWT)
    /// 
    /// In production, use a proper JWT library like vapor/jwt
    /// This is a simplified implementation for development
    private func generateLiveKitToken(
        apiKey: String,
        apiSecret: String,
        roomName: String,
        identity: String,
        ttl: Int
    ) throws -> String {
        // TODO: Implement proper JWT generation
        // For now, return a placeholder that includes necessary info
        
        // In production, this should create a JWT with:
        // - Header: { "alg": "HS256", "typ": "JWT" }
        // - Payload: {
        //     "exp": now + ttl,
        //     "iss": apiKey,
        //     "sub": identity,
        //     "video": { "room": roomName, "roomJoin": true }
        //   }
        // - Signature: HMAC-SHA256(header.payload, apiSecret)
        
        let exp = Int(Date().timeIntervalSince1970) + ttl
        let payload = """
        {
            "exp": \(exp),
            "iss": "\(apiKey)",
            "sub": "\(identity)",
            "video": {
                "room": "\(roomName)",
                "roomJoin": true
            }
        }
        """
        
        // For development, return base64-encoded payload
        // LiveKit client will need proper JWT in production
        let tokenData = payload.data(using: .utf8)!
        return tokenData.base64EncodedString()
    }
}

struct VoiceTokenResponse: Content {
    let token: String
    let url: String
    let roomName: String
}
