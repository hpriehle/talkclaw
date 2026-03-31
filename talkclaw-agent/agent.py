"""
TalkClaw Voice Agent
Real-time voice conversation powered by LiveKit + OpenClaw
"""

import os
import asyncio
from livekit.agents import (
    Agent,
    AgentServer,
    AgentSession,
    JobContext,
    cli,
)
from livekit.plugins import silero, deepgram, elevenlabs
from openclaw_llm import OpenClawLLM


# Create server instance
server = AgentServer()


@server.rtc_session()
async def entrypoint(ctx: JobContext):
    """
    Main entry point for each voice session
    """
    
    print(f"🎙️ Starting voice session in room: {ctx.room.name}")
    
    # Extract session key from room name (talkclaw-{uuid})
    session_key = ctx.room.name
    
    # Get OpenClaw API URL from environment
    openclaw_url = os.getenv("OPENCLAW_URL", "https://openclaw.clntacq.com")
    
    # Create agent session
    session = AgentSession(
        vad=silero.VAD.load(),  # Voice activity detection
        stt=deepgram.STT(model="nova-3"),  # Speech-to-text
        llm=OpenClawLLM(
            session_key=session_key,
            openclaw_url=openclaw_url
        ),
        tts=elevenlabs.TTS(
            voice=os.getenv("ELEVENLABS_VOICE_ID", "21m00Tcm4TlvDq8ikWAM")
        ),
    )
    
    # Create agent with instructions
    agent = Agent(
        instructions=(
            "You are an AI assistant helping via voice conversation. "
            "Keep responses concise since this is voice chat. "
            "Be natural and conversational."
        ),
    )
    
    # Start the session
    await session.start(agent=agent, room=ctx.room)
    
    # Greet the user
    await session.generate_reply(
        instructions="Greet the user briefly and ask how you can help"
    )
    
    print(f"✅ Voice session started: {session_key}")


if __name__ == "__main__":
    # Run the agent
    cli.run_app(server)
