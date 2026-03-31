/**
 * System prompt for the TalkClaw agent, migrated from OpenClaw SOUL.md / IDENTITY.md / USER.md.
 */
interface WidgetInfo {
    slug: string;
    title: string;
    description?: string;
    surface?: string;
}
export declare function buildSystemPrompt(channel: "talkclaw" | "telegram", widgets?: WidgetInfo[]): string;
export {};
