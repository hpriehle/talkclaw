"""
Piper TTS wrapper for LiveKit Agents
FREE, open-source, CPU-only alternative to ElevenLabs
"""

import os
import subprocess
import tempfile
import asyncio


class PiperTTS:
    """Piper TTS wrapper for LiveKit Agents"""
    
    def __init__(self, model_path: str = "models/en_US-lessac-medium.onnx"):
        if not os.path.exists(model_path):
            raise FileNotFoundError(f"Piper model not found: {model_path}")
        
        self.model_path = model_path
        print(f"[PiperTTS] Initialized with model: {model_path}")
        print("[PiperTTS] FREE, open-source, CPU-only TTS")
    
    async def synthesize(self, text: str) -> str:
        """
        Synthesize text to speech using Piper
        
        Args:
            text: Text to convert to speech
            
        Returns:
            Path to generated WAV file
        """
        try:
            # Create temporary output file
            with tempfile.NamedTemporaryFile(suffix=".wav", delete=False) as f:
                output_file = f.name
            
            # Run Piper synthesis
            loop = asyncio.get_event_loop()
            
            def _synthesize():
                # Run piper command
                process = subprocess.run(
                    [
                        "piper",
                        "--model", self.model_path,
                        "--output_file", output_file
                    ],
                    input=text.encode('utf-8'),
                    capture_output=True,
                    check=True
                )
                return output_file
            
            result = await loop.run_in_executor(None, _synthesize)
            
            print(f"[PiperTTS] Synthesized: {text[:50]}... → {output_file}")
            return result
            
        except subprocess.CalledProcessError as e:
            print(f"[PiperTTS] Piper error: {e.stderr.decode()}")
            raise
        except Exception as e:
            print(f"[PiperTTS] Error: {e}")
            raise
