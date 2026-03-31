/**
 * Spawns `claude -p` (headless mode) to handle messages.
 * Uses the host's Claude Code OAuth credentials (Max subscription).
 * Supports streaming JSON output for real-time deltas.
 */
import { spawn } from "child_process";
import { existsSync, mkdirSync } from "fs";
import path from "path";
const SESSIONS_DIR = process.env.SESSIONS_DIR || "/data/sessions";
function getSessionDir(sessionKey) {
    const dir = path.join(SESSIONS_DIR, sessionKey);
    if (!existsSync(dir)) {
        mkdirSync(dir, { recursive: true });
    }
    return dir;
}
function sessionExists(sessionKey) {
    return existsSync(path.join(SESSIONS_DIR, sessionKey));
}
export async function handleMessage(content, sessionKey, systemPrompt, handler) {
    const sessionDir = getSessionDir(sessionKey);
    const args = [
        "-p", content,
        "--output-format", "stream-json",
        "--verbose",
    ];
    // Add system prompt
    if (systemPrompt) {
        args.push("--system-prompt", systemPrompt);
    }
    // Resume existing conversation
    if (sessionExists(sessionKey)) {
        args.push("--continue");
    }
    // Limit tool usage for chat context (no destructive actions)
    args.push("--allowedTools", "Read,Grep,Glob,WebSearch,WebFetch", "--max-turns", "10");
    console.log(`[claude] Spawning: claude ${args.join(" ").substring(0, 200)}...`);
    return new Promise((resolve, reject) => {
        const claude = spawn("claude", args, {
            cwd: sessionDir,
            env: { ...process.env, HOME: process.env.HOME || "/root" },
            stdio: ["pipe", "pipe", "pipe"],
        });
        let fullText = "";
        let buffer = "";
        const messageId = crypto.randomUUID();
        claude.stdout.on("data", (chunk) => {
            buffer += chunk.toString();
            const lines = buffer.split("\n");
            // Keep the last incomplete line in the buffer
            buffer = lines.pop() || "";
            for (const line of lines) {
                if (!line.trim())
                    continue;
                try {
                    const event = JSON.parse(line);
                    // assistant message: content is at event.message.content[]
                    if (event.type === "assistant" && event.message?.content) {
                        for (const block of event.message.content) {
                            if (block.type === "text" && block.text) {
                                fullText += block.text;
                                handler.deltaFn?.(block.text, messageId);
                            }
                        }
                    }
                    // result event: final text at event.result
                    if (event.type === "result" && event.result) {
                        fullText = event.result;
                        console.log(`[claude] Got result (${fullText.length} chars)`);
                    }
                }
                catch {
                    // Not valid JSON yet, ignore partial lines
                }
            }
        });
        claude.stderr.on("data", (chunk) => {
            const msg = chunk.toString().trim();
            if (msg)
                console.error(`[claude stderr] ${msg}`);
        });
        claude.on("close", async (code) => {
            console.log(`[claude] Process exited with code ${code}, fullText length: ${fullText.length}`);
            // Process any remaining buffer
            if (buffer.trim()) {
                try {
                    const event = JSON.parse(buffer);
                    if (event.type === "result" && event.result) {
                        fullText = event.result;
                    }
                }
                catch {
                    // ignore
                }
            }
            if (code !== 0 && !fullText) {
                console.error(`[claude] Exited with code ${code} and no output`);
                await handler.replyFn("Sorry, I encountered an error processing your message. Please try again.");
                resolve();
                return;
            }
            if (fullText.trim()) {
                await handler.replyFn(fullText.trim());
            }
            else {
                console.error(`[claude] No text output produced`);
                await handler.replyFn("Sorry, I couldn't generate a response. Please try again.");
            }
            resolve();
        });
        claude.on("error", async (err) => {
            console.error(`[claude] Spawn error: ${err.message}`);
            await handler.replyFn("Sorry, the AI service is temporarily unavailable.");
            reject(err);
        });
    });
}
