/**
 * talkclaw-agent: Claude Code CLI bridge for TalkClaw and Telegram.
 *
 * - TalkClaw: Receives webhook POSTs from Vapor, spawns `claude -p`, POSTs reply back.
 * - Telegram: Polls for messages via bot API, spawns `claude -p`, sends reply via bot API.
 *
 * Uses Claude Code CLI (headless mode) which authenticates via OAuth (Max subscription).
 * Zero API key costs.
 */

import express from "express";
import { existsSync } from "fs";
import TelegramBot from "node-telegram-bot-api";
import { handleMessage } from "./claude-runner.js";
import { buildSystemPrompt } from "./system-prompt.js";

const PORT = parseInt(process.env.PORT || "3000", 10);
const WEBHOOK_SECRET = process.env.WEBHOOK_SECRET || "";
const TALKCLAW_SERVER_URL = process.env.TALKCLAW_SERVER_URL || "http://localhost:8080";
const TALKCLAW_API_TOKEN = process.env.TALKCLAW_API_TOKEN || "";
const TELEGRAM_BOT_TOKEN = process.env.TELEGRAM_BOT_TOKEN || "";
const ALLOWED_TELEGRAM_USERS = (process.env.ALLOWED_TELEGRAM_USERS || "")
  .split(",")
  .map((s) => s.trim())
  .filter(Boolean);

const app = express();
app.use(express.json());

// ── Startup checks ──────────────────────────────────────────────────────────
const CONTEXT_DIR = process.env.CONTEXT_DIR || "/data/context";
const contextMounted = existsSync(`${CONTEXT_DIR}/SOUL.md`);
if (!contextMounted) {
  console.error(`[FATAL] Context mount is empty — ${CONTEXT_DIR}/SOUL.md not found. Check docker-compose volume mounts.`);
}

// ── Health check ────────────────────────────────────────────────────────────
app.get("/health", (_req, res) => {
  const healthy = existsSync(`${CONTEXT_DIR}/SOUL.md`);
  res.status(healthy ? 200 : 503).json({
    status: healthy ? "ok" : "unhealthy",
    service: "talkclaw-agent",
    contextMounted: healthy,
  });
});

// ── TalkClaw webhook ────────────────────────────────────────────────────────
// Same contract as the OpenClaw channel plugin:
// - Receives: { sessionId, content, secret, apiToken?, widgets? }
// - Returns 204 immediately
// - POSTs reply to {serverUrl}/api/v1/sessions/{sessionId}/messages

app.post("/webhook/talkclaw", (req, res) => {
  const { sessionId, content, secret, widgets } = req.body;

  if (WEBHOOK_SECRET && secret !== WEBHOOK_SECRET) {
    res.status(401).json({ error: "Invalid webhook secret" });
    return;
  }

  if (!sessionId || !content) {
    res.status(400).json({ error: "Missing sessionId or content" });
    return;
  }

  console.log(`[talkclaw] Received message for session ${sessionId} (${content.length} chars)`);

  // Acknowledge immediately — async processing
  res.status(204).end();

  const systemPrompt = buildSystemPrompt("talkclaw", widgets);
  const messageId = crypto.randomUUID();

  handleMessage(content, "TalkClaw", systemPrompt, {
    replyFn: async (text) => {
      console.log(`[talkclaw] Sending reply to session ${sessionId} (${text.length} chars)`);
      try {
        const response = await fetch(
          `${TALKCLAW_SERVER_URL}/api/v1/sessions/${sessionId}/messages`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${TALKCLAW_API_TOKEN}`,
            },
            body: JSON.stringify({ content: text, role: "assistant" }),
          }
        );
        if (!response.ok) {
          console.error(`[talkclaw] Failed to deliver reply — HTTP ${response.status}`);
        } else {
          console.log(`[talkclaw] Reply delivered successfully`);
        }
      } catch (err: any) {
        console.error(`[talkclaw] Delivery error: ${err.message}`);
      }
    },
    deltaFn: async (delta, _msgId) => {
      // Stream deltas to Vapor for real-time chatDelta WS events
      try {
        await fetch(
          `${TALKCLAW_SERVER_URL}/api/v1/sessions/${sessionId}/delta`,
          {
            method: "POST",
            headers: {
              "Content-Type": "application/json",
              Authorization: `Bearer ${TALKCLAW_API_TOKEN}`,
            },
            body: JSON.stringify({ delta, messageId }),
          }
        );
      } catch {
        // Non-critical — delta streaming is best-effort
      }
    },
    widgets,
  });
});

// ── Telegram bot ────────────────────────────────────────────────────────────

if (TELEGRAM_BOT_TOKEN) {
  const bot = new TelegramBot(TELEGRAM_BOT_TOKEN, { polling: true });

  bot.on("message", (msg) => {
    if (!msg.text) return;

    const chatId = msg.chat.id;
    const userId = msg.from?.id?.toString() || "";
    const username = msg.from?.username || "";

    // Optional: restrict to specific Telegram users
    if (
      ALLOWED_TELEGRAM_USERS.length > 0 &&
      !ALLOWED_TELEGRAM_USERS.includes(userId) &&
      !ALLOWED_TELEGRAM_USERS.includes(username)
    ) {
      bot.sendMessage(chatId, "Sorry, you're not authorized to use this bot.");
      return;
    }

    console.log(`[telegram] Message from ${username || userId}: ${msg.text.substring(0, 100)}`);

    const systemPrompt = buildSystemPrompt("telegram");

    handleMessage(msg.text, "Telegram", systemPrompt, {
      typingFn: async () => {
        try { await bot.sendChatAction(chatId, "typing"); } catch {}
      },
      replyFn: async (text) => {
        // Split long messages (Telegram max is 4096 chars)
        const MAX_LEN = 4000;
        for (let i = 0; i < text.length; i += MAX_LEN) {
          const chunk = text.slice(i, i + MAX_LEN);
          await bot.sendMessage(chatId, chunk, { parse_mode: "Markdown" }).catch(() => {
            // Retry without markdown if parsing fails
            bot.sendMessage(chatId, chunk);
          });
        }
      },
    });
  });

  console.log(`[telegram] Bot started (polling mode)`);
} else {
  console.log(`[telegram] No TELEGRAM_BOT_TOKEN — Telegram disabled`);
}

// ── Start server ────────────────────────────────────────────────────────────

app.listen(PORT, () => {
  console.log(`[talkclaw-agent] Listening on port ${PORT}`);
  console.log(`[talkclaw-agent] TalkClaw server: ${TALKCLAW_SERVER_URL}`);
  console.log(`[talkclaw-agent] Webhook secret: ${WEBHOOK_SECRET ? "configured" : "none"}`);
});
