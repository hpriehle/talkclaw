/**
 * talkclaw-agent: Claude Code CLI bridge for TalkClaw and Telegram.
 *
 * - TalkClaw: Receives webhook POSTs from Vapor, spawns `claude -p`, POSTs reply back.
 * - Telegram: Polls for messages via bot API, spawns `claude -p`, sends reply via bot API.
 *
 * Uses Claude Code CLI (headless mode) which authenticates via OAuth (Max subscription).
 * Zero API key costs.
 */
export {};
