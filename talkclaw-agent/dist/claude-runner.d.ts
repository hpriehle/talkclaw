/**
 * Spawns `claude -p` (headless mode) to handle messages.
 * Uses the host's Claude Code OAuth credentials (Max subscription).
 * Supports streaming JSON output for real-time deltas.
 */
export interface MessageHandler {
    replyFn: (text: string) => Promise<void>;
    deltaFn?: (delta: string, messageId: string) => Promise<void>;
    widgets?: Array<{
        slug: string;
        title: string;
        description?: string;
        surface?: string;
    }>;
}
export declare function handleMessage(content: string, sessionKey: string, systemPrompt: string, handler: MessageHandler): Promise<void>;
