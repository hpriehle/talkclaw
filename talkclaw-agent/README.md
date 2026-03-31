# TalkClaw Voice Agent

LiveKit Agent Server for real-time voice conversations with OpenClaw.

## Setup

### 1. Install Dependencies

```bash
pip install -r requirements.txt
```

### 2. Configure Environment

Copy `.env.example` to `.env` and fill in your API keys:

```bash
cp .env.example .env
```

**Get your credentials:**
- **LiveKit:** https://cloud.livekit.io → Create Project
- **Deepgram:** https://console.deepgram.com → API Keys ($200 free credit)
- **ElevenLabs:** https://elevenlabs.io/app → API Key (10k chars/month free)

### 3. Run in Development

```bash
python agent.py dev
```

### 4. Test

1. Open LiveKit Agents Playground: https://agents-playground.livekit.io/
2. Enter your LiveKit credentials
3. Click "Connect"
4. Click microphone and speak
5. You should hear OpenClaw respond!

## Architecture

```
iPhone (TalkClaw)
    ↓ WebRTC
LiveKit Room
    ↓
This Agent Server (Python)
    ├─► Silero VAD (voice activity detection)
    ├─► Deepgram STT (speech-to-text)
    ├─► OpenClaw API (LLM processing)
    └─► ElevenLabs TTS (text-to-speech)
    ↓ WebRTC Audio
iPhone (plays response)
```

## Components

### agent.py
Main entry point. Creates LiveKit Agent session for each room.

### openclaw_llm.py
Custom LLM wrapper that routes to OpenClaw API instead of OpenAI/Claude directly.

## Environment Variables

| Variable | Description | Required |
|----------|-------------|----------|
| `LIVEKIT_URL` | LiveKit server URL | ✅ |
| `LIVEKIT_API_KEY` | LiveKit API key | ✅ |
| `LIVEKIT_API_SECRET` | LiveKit API secret | ✅ |
| `DEEPGRAM_API_KEY` | Deepgram STT API key | ✅ |
| `ELEVENLABS_API_KEY` | ElevenLabs TTS API key | ✅ |
| `ELEVENLABS_VOICE_ID` | Voice ID (default: 21m00... Rachel) | Optional |
| `OPENCLAW_URL` | OpenClaw API URL | Optional |

## Deployment

### Docker

```bash
cd ~/talkclaw
docker-compose up -d talkclaw-agent
```

### Systemd Service

```bash
# Create service file
sudo nano /etc/systemd/system/talkclaw-agent.service

# Add:
[Unit]
Description=TalkClaw Voice Agent
After=network.target

[Service]
Type=simple
User=riehle
WorkingDirectory=/home/riehle/talkclaw/talkclaw-agent
EnvironmentFile=/home/riehle/talkclaw/talkclaw-agent/.env
ExecStart=/usr/bin/python3 agent.py start
Restart=always

[Install]
WantedBy=multi-user.target

# Enable and start
sudo systemctl enable talkclaw-agent
sudo systemctl start talkclaw-agent
```

## Troubleshooting

### "Failed to connect to LiveKit"
- Check `LIVEKIT_URL` is correct (starts with `wss://`)
- Verify API credentials
- Check firewall settings

### "Deepgram authentication failed"
- Verify `DEEPGRAM_API_KEY`
- Check account has credits
- Try regenerating API key

### "No audio output"
- Check `ELEVENLABS_API_KEY`
- Verify voice ID is valid
- Check account has credits

### "OpenClaw not responding"
- Verify `OPENCLAW_URL` is accessible
- Check session key format
- Look at agent logs for errors

## Costs

**Per minute of conversation:**
- Deepgram STT: ~$0.0043
- ElevenLabs TTS: ~$0.05 (150 words/min)
- OpenClaw API: ~$0.01 (tokens)
- LiveKit Cloud: Free tier (10GB/month)

**Total: ~$0.06-0.08 per minute**

## Logs

```bash
# View logs
python agent.py dev  # stdout in dev mode

# Or in production
journalctl -u talkclaw-agent -f
```

## Next Steps

1. Test in Agents Playground
2. Test with TalkClaw iOS app
3. Deploy to production
4. Monitor usage and costs
