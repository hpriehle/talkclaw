/**
 * Manages a shared session across all channels (TalkClaw + Telegram).
 * Stores the Claude Code session_id so all channels resume the same conversation.
 * Maddie on Telegram knows what was said on TalkClaw and vice versa.
 *
 * Auto-recovery: clears stale sessions after consecutive failures or 24h expiry.
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync, unlinkSync } from "fs";
import path from "path";

const SESSIONS_DIR = process.env.SESSIONS_DIR || "/data/sessions";
const SHARED_DIR = path.join(SESSIONS_DIR, "shared");
const STATE_FILE = path.join(SESSIONS_DIR, "shared-session.json");

const MAX_CONSECUTIVE_FAILURES = 2;
const SESSION_MAX_AGE_MS = 24 * 60 * 60 * 1000; // 24 hours

interface SessionState {
  sessionId: string | null;
  lastChannel: string;
  lastMessageAt: string;
}

let consecutiveFailures = 0;

function ensureSharedDir(): string {
  if (!existsSync(SHARED_DIR)) {
    mkdirSync(SHARED_DIR, { recursive: true });
  }
  return SHARED_DIR;
}

function readState(): SessionState {
  try {
    const data = readFileSync(STATE_FILE, "utf-8");
    return JSON.parse(data);
  } catch {
    return { sessionId: null, lastChannel: "", lastMessageAt: "" };
  }
}

function writeState(state: SessionState): void {
  writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

/** Get the shared session directory (all channels use this CWD). */
export function getSharedSessionDir(): string {
  return ensureSharedDir();
}

/** Get the current session ID, or null if expired/missing. */
export function getSessionId(): string | null {
  const state = readState();
  if (state.sessionId && state.lastMessageAt) {
    const age = Date.now() - new Date(state.lastMessageAt).getTime();
    if (age > SESSION_MAX_AGE_MS) {
      console.log(`[session] Session expired (${Math.round(age / 3600000)}h old) — starting fresh`);
      clearSession();
      return null;
    }
  }
  return state.sessionId;
}

/** Save the session ID after a successful claude invocation. */
export function saveSessionId(sessionId: string, channel: string): void {
  writeState({
    sessionId,
    lastChannel: channel,
    lastMessageAt: new Date().toISOString(),
  });
  console.log(`[session] Saved session ${sessionId} (from ${channel})`);
}

/** Record a failure. After MAX_CONSECUTIVE_FAILURES, auto-clear the session. */
export function recordFailure(): void {
  consecutiveFailures++;
  if (consecutiveFailures >= MAX_CONSECUTIVE_FAILURES) {
    console.warn(`[session] ${consecutiveFailures} consecutive failures — clearing stale session`);
    clearSession();
  }
}

/** Record a success — resets the failure counter. */
export function recordSuccess(): void {
  consecutiveFailures = 0;
}

/** Clear the session file and reset failure counter. */
export function clearSession(): void {
  try { unlinkSync(STATE_FILE); } catch {}
  consecutiveFailures = 0;
  console.log(`[session] Session cleared`);
}
