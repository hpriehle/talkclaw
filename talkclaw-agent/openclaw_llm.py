"""
OpenClaw LLM Wrapper for LiveKit Agents
Bridges LiveKit conversation to OpenClaw API
"""

from livekit.agents import LLM, ChatContext
import httpx
import os


class OpenClawLLM(LLM):
    """
    Custom LLM that routes conversations to OpenClaw
    """
    
    def __init__(
        self,
        session_key: str,
        openclaw_url: str = "https://openclaw.clntacq.com",
    ):
        super().__init__()
        self.session_key = session_key
        self.openclaw_url = openclaw_url
        self.client = httpx.AsyncClient(timeout=30.0)
    
    async def chat(
        self,
        *,
        chat_ctx: ChatContext,
        fnc_ctx: None = None,
        temperature: float | None = None,
        n: int = 1,
    ) -> LLM.ChatChunk:
        """
        Send conversation to OpenClaw and return response
        """
        
        # Get last user message
        last_message = None
        for msg in reversed(chat_ctx.messages):
            if msg.role == "user":
                last_message = msg.content
                break
        
        if not last_message:
            return self._error_response("No user message found")
        
        # Call OpenClaw API
        try:
            response = await self.client.post(
                f"{self.openclaw_url}/api/sessions/{self.session_key}/send",
                json={
                    "message": last_message,
                    "stream": False
                },
                headers={
                    "Content-Type": "application/json"
                }
            )
            
            response.raise_for_status()
            data = response.json()
            
            # Extract response text
            assistant_message = data.get("response", "Sorry, I didn't get that.")
            
            # Return as LiveKit ChatChunk
            return LLM.ChatChunk(
                choices=[
                    LLM.Choice(
                        delta=LLM.ChoiceDelta(
                            role="assistant",
                            content=assistant_message
                        )
                    )
                ]
            )
            
        except Exception as e:
            print(f"OpenClaw API error: {e}")
            return self._error_response(str(e))
    
    def _error_response(self, error: str) -> LLM.ChatChunk:
        """Return error response"""
        return LLM.ChatChunk(
            choices=[
                LLM.Choice(
                    delta=LLM.ChoiceDelta(
                        role="assistant",
                        content="I'm having trouble connecting right now. Please try again."
                    )
                )
            ]
        )
