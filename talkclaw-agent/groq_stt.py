"""
Groq Whisper STT wrapper for LiveKit Agents
FREE alternative to Deepgram
"""

import os
import asyncio
from groq import Groq


class GroqSTT:
    """Groq Whisper API wrapper for LiveKit Agents"""
    
    def __init__(self):
        api_key = os.getenv("GROQ_API_KEY")
        if not api_key:
            raise ValueError("GROQ_API_KEY environment variable not set")
        
        self.client = Groq(api_key=api_key)
        print("[GroqSTT] Initialized with Groq Whisper API (FREE)")
    
    async def transcribe(self, audio_file_path: str) -> str:
        """
        Transcribe audio file using Groq Whisper API
        
        Args:
            audio_file_path: Path to audio file
            
        Returns:
            Transcribed text
        """
        try:
            # Run in executor since Groq SDK is sync
            loop = asyncio.get_event_loop()
            
            def _transcribe():
                with open(audio_file_path, "rb") as audio_file:
                    transcription = self.client.audio.transcriptions.create(
                        file=audio_file,
                        model="whisper-large-v3",
                        language="en",
                        response_format="text"
                    )
                return transcription
            
            result = await loop.run_in_executor(None, _transcribe)
            
            print(f"[GroqSTT] Transcribed: {result[:50]}...")
            return result
            
        except Exception as e:
            print(f"[GroqSTT] Error: {e}")
            return ""
