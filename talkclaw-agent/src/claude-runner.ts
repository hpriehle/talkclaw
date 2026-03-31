/**
 * Spawns `claude -p` (headless mode) to handle messages.
 * Uses the host's Claude Code OAuth credentials (Max subscription).
 * Supports streaming JSON output for real-time deltas.
 *
 * Model fallback waterfall:
 *   1. Claude Sonnet → if rate-limited:
 *   2. Claude Opus  → if rate-limited:
 *   3. NVIDIA/Kimi API (free, OpenAI-compatible)
 *
 * All channels share a single session for cross-channel awareness.
 * Messages are queued and retried on transient failures.
 * Stale sessions are auto-cleared after consecutive failures.
 */

import { spawn, ChildProcess } from "child_process";
import {
  getSharedSessionDir, getSessionId, saveSessionId,
  recordFailure, recordSuccess, clearSession,
} from "./session-manager.js";

const NVIDIA_API_KEY = process.env.NVIDIA_API_KEY || "";
const NVIDIA_MODEL = "moonshotai/kimi-k2-instruct";
const CLAUDE_TIMEOUT_MS = 120_000; // 2 minutes max per claude spawn

// Verify NVIDIA model availability at startup
if (NVIDIA_API_KEY) {
  fetch("https://integrate.api.nvidia.com/v1/models", {
    headers: { Authorization: `Bearer ${NVIDIA_API_KEY}` },
  })
    .then(r => r.json())
    .then((data: any) => {
      const models: string[] = data.data?.map((m: any) => m.id) || [];
      if (models.includes(NVIDIA_MODEL)) {
        console.log(`[nvidia] Model ${NVIDIA_MODEL} verified available`);
      } else {
        console.warn(`[nvidia] WARNING: ${NVIDIA_MODEL} not found. Available: ${models.slice(0, 10).join(", ")}`);
      }
    })
    .catch(err => console.warn(`[nvidia] Could not verify models: ${err.message}`));
} else {
  console.log(`[nvidia] No NVIDIA_API_KEY — fallback disabled`);
}

export interface MessageHandler {
  replyFn: (text: string) => Promise<void>;
  deltaFn?: (delta: string, messageId: string) => Promise<void>;
  typingFn?: () => Promise<void>;
  widgets?: Array<{ slug: string; title: string; description?: string; surface?: string }>;
}

interface ClaudeResult {
  text: string | null;
  rateLimited: boolean;
  sessionId: string | null;
}

/** Spawn `claude -p` with a specific model. Returns text + whether it was rate-limited. */
function runClaude(
  content: string,
  model: string,
  channel: string,
  systemPrompt: string,
  handler: MessageHandler
): Promise<ClaudeResult> {
  const sessionDir = getSharedSessionDir();
  const existingSessionId = getSessionId();

  // Tag message with channel source for cross-channel awareness
  const taggedContent = `[via ${channel}] ${content}`;

  const args = [
    "-p", taggedContent,
    "--output-format", "stream-json",
    "--verbose",
    "--model", model,
  ];

  if (systemPrompt) {
    args.push("--system-prompt", systemPrompt);
  }

  // Resume shared session if one exists
  if (existingSessionId) {
    args.push("--resume", existingSessionId);
  }

  args.push(
    "--allowedTools", "Bash,Read,Write,Edit,Grep,Glob,WebSearch,WebFetch",
    "--max-turns", "10"
  );

  console.log(`[claude:${model}] Spawning claude (session=${existingSessionId || "new"}, channel=${channel})...`);

  return new Promise<ClaudeResult>((resolve) => {
    const claude = spawn("claude", args, {
      cwd: sessionDir,
      env: { ...process.env, HOME: process.env.HOME || "/root" },
      stdio: ["ignore", "pipe", "pipe"],
    });

    let fullText = "";
    let buffer = "";
    let rateLimited = false;
    let sessionId: string | null = null;
    let resolved = false;
    const messageId = crypto.randomUUID();

    // Timeout: kill if claude hangs
    const timeout = setTimeout(() => {
      if (!resolved) {
        console.warn(`[claude:${model}] Timeout after ${CLAUDE_TIMEOUT_MS}ms — killing process`);
        claude.kill("SIGTERM");
        setTimeout(() => {
          if (!resolved) {
            claude.kill("SIGKILL");
          }
        }, 5000);
      }
    }, CLAUDE_TIMEOUT_MS);

    function finish(result: ClaudeResult) {
      if (resolved) return;
      resolved = true;
      clearTimeout(timeout);
      resolve(result);
    }

    // Send typing indicator periodically while claude is running
    let typingInterval: ReturnType<typeof setInterval> | undefined;
    if (handler.typingFn) {
      handler.typingFn();
      typingInterval = setInterval(() => {
        handler.typingFn?.();
      }, 4000);
    }

    claude.stdout.on("data", (chunk: Buffer) => {
      buffer += chunk.toString();
      const lines = buffer.split("\n");
      buffer = lines.pop() || "";

      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          const event = JSON.parse(line);

          // Detect rate limit rejection
          if (event.type === "rate_limit_event" && event.rate_limit_info?.status === "rejected") {
            console.warn(`[claude:${model}] Rate limited (resets ${new Date(event.rate_limit_info.resetsAt * 1000).toISOString()})`);
            rateLimited = true;
          }

          if (event.type === "assistant" && event.message?.content) {
            for (const block of event.message.content) {
              if (block.type === "text" && block.text) {
                fullText += block.text;
                handler.deltaFn?.(block.text, messageId);
              }
            }
          }

          // Capture session_id from any event
          if (event.session_id) {
            sessionId = event.session_id;
          }

          // Result event with is_error + rate limit text
          if (event.type === "result") {
            if (event.is_error && event.result?.includes("hit your limit")) {
              rateLimited = true;
              console.warn(`[claude:${model}] Rate limit confirmed in result`);
            } else if (event.result) {
              fullText = event.result;
              console.log(`[claude:${model}] Got result (${fullText.length} chars)`);
            }
          }
        } catch {
          // Not valid JSON yet
        }
      }
    });

    claude.stderr.on("data", (chunk: Buffer) => {
      const msg = chunk.toString().trim();
      if (msg) console.error(`[claude:${model} stderr] ${msg}`);
    });

    claude.on("close", (code) => {
      if (typingInterval) clearInterval(typingInterval);
      console.log(`[claude:${model}] Exited code=${code}, text=${fullText.length} chars, rateLimited=${rateLimited}, session=${sessionId}`);

      // Process remaining buffer
      if (buffer.trim()) {
        try {
          const event = JSON.parse(buffer);
          if (event.session_id) sessionId = event.session_id;
          if (event.type === "result") {
            if (event.is_error && event.result?.includes("hit your limit")) {
              rateLimited = true;
            } else if (event.result) {
              fullText = event.result;
            }
          }
        } catch {
          // ignore
        }
      }

      finish({
        text: rateLimited ? null : (fullText.trim() || null),
        rateLimited,
        sessionId,
      });
    });

    claude.on("error", (err) => {
      if (typingInterval) clearInterval(typingInterval);
      console.error(`[claude:${model}] Spawn error: ${err.message}`);
      finish({ text: null, rateLimited: false, sessionId: null });
    });
  });
}

/** NVIDIA/Kimi fallback via OpenAI-compatible API. */
async function callNvidiaKimi(content: string, systemPrompt: string): Promise<string> {
  console.log(`[nvidia] Falling back to NVIDIA/Kimi API...`);

  const response = await fetch("https://integrate.api.nvidia.com/v1/chat/completions", {
    method: "POST",
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${NVIDIA_API_KEY}`,
    },
    body: JSON.stringify({
      model: NVIDIA_MODEL,
      messages: [
        { role: "system", content: systemPrompt },
        { role: "user", content },
      ],
      max_tokens: 4096,
    }),
  });

  if (!response.ok) {
    const errText = await response.text().catch(() => "unknown");
    console.error(`[nvidia] API error ${response.status}: ${errText}`);
    return "Sorry, all AI services are currently unavailable. Please try again later.";
  }

  const data = await response.json() as any;
  const text = data.choices?.[0]?.message?.content;
  if (text) {
    console.log(`[nvidia] Got response (${text.length} chars)`);
    return text;
  }

  console.error(`[nvidia] Unexpected response shape:`, JSON.stringify(data).substring(0, 300));
  return "Sorry, all AI services are currently unavailable. Please try again later.";
}

const MODELS = ["sonnet", "opus"] as const;
const MAX_RETRIES = 1; // retry once on non-rate-limit failures

export async function handleMessage(
  content: string,
  channel: string,
  systemPrompt: string,
  handler: MessageHandler
): Promise<void> {
  let sentRetryNotice = false;

  // Waterfall: try each Claude model in order, with retry on transient failures
  for (const model of MODELS) {
    for (let attempt = 0; attempt <= MAX_RETRIES; attempt++) {
      if (attempt > 0) {
        // Clear session on retry — stale session is the #1 cause of 0-char exits
        clearSession();
        console.log(`[retry] Retrying ${model} (attempt ${attempt + 1}) with fresh session...`);

        if (!sentRetryNotice) {
          handler.replyFn("On it...").catch(() => {});
          sentRetryNotice = true;
        }
      }

      const result = await runClaude(content, model, channel, systemPrompt, handler);

      if (result.text) {
        recordSuccess();
        if (result.sessionId) {
          saveSessionId(result.sessionId, channel);
        }
        await handler.replyFn(result.text);
        return;
      }

      if (result.rateLimited) {
        console.log(`[fallback] ${model} rate-limited, trying next model...`);
        break; // skip retries, move to next model
      }

      // Non-rate-limit failure
      recordFailure();
      if (attempt < MAX_RETRIES) {
        console.warn(`[retry] ${model} returned no text and no rate limit — will retry with fresh session`);
      }
    }
  }

  // Final fallback: NVIDIA/Kimi
  if (NVIDIA_API_KEY) {
    const result = await callNvidiaKimi(content, systemPrompt);
    await handler.replyFn(result);
  } else {
    await handler.replyFn("Sorry, all AI models are currently rate-limited. Please try again later.");
  }
}
