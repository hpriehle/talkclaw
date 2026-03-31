/**
 * System prompt builder — embeds core identity (SOUL + IDENTITY) and generates
 * a file index for everything else. Claude reads files on demand via the Read tool.
 */

import { readFileSync, readdirSync, statSync } from "fs";
import path from "path";

const CONTEXT_DIR = process.env.CONTEXT_DIR || "/data/context";

function tryRead(filePath: string): string {
  try { return readFileSync(filePath, "utf-8").trim(); } catch { return ""; }
}

/** Recursively list .md files with relative paths and first-line descriptions. */
function indexDir(dir: string, prefix: string = ""): string[] {
  const entries: string[] = [];
  try {
    for (const name of readdirSync(dir).sort()) {
      const full = path.join(dir, name);
      const rel = prefix ? `${prefix}/${name}` : name;
      try {
        const stat = statSync(full);
        if (stat.isDirectory()) {
          entries.push(...indexDir(full, rel));
        } else if (name.endsWith(".md")) {
          // Get first non-empty, non-heading line as description
          const firstLine = tryRead(full)
            .split("\n")
            .map(l => l.trim())
            .find(l => l && !l.startsWith("#") && !l.startsWith("_") && !l.startsWith("---"));
          const desc = firstLine ? ` — ${firstLine.substring(0, 80)}` : "";
          entries.push(`- ${CONTEXT_DIR}/${rel}${desc}`);
        }
      } catch { /* skip unreadable */ }
    }
  } catch { /* dir doesn't exist */ }
  return entries;
}

// Load core identity files (fully embedded)
const SOUL = tryRead(`${CONTEXT_DIR}/SOUL.md`);
const IDENTITY = tryRead(`${CONTEXT_DIR}/IDENTITY.md`);

// Build file index (paths + one-line descriptions)
const contextIndex = indexDir(`${CONTEXT_DIR}/contexts`, "contexts");
const skillDirs = (() => {
  try {
    return readdirSync(`${CONTEXT_DIR}/skills`)
      .filter(d => {
        try { return statSync(`${CONTEXT_DIR}/skills/${d}`).isDirectory(); } catch { return false; }
      })
      .map(d => {
        const skillMd = tryRead(`${CONTEXT_DIR}/skills/${d}/SKILL.md`);
        const desc = skillMd
          .split("\n")
          .map(l => l.trim())
          .find(l => l && !l.startsWith("#") && !l.startsWith("_"));
        return `- ${CONTEXT_DIR}/skills/${d}/${desc ? ` — ${desc.substring(0, 80)}` : ""}`;
      });
  } catch { return []; }
})();

const memoryFiles = (() => {
  try {
    return readdirSync(`${CONTEXT_DIR}/memory`)
      .filter(f => f.endsWith(".md"))
      .sort()
      .reverse()
      .slice(0, 5) // last 5 days
      .map(f => `- ${CONTEXT_DIR}/memory/${f}`);
  } catch { return []; }
})();

const rootFiles = (() => {
  try {
    return readdirSync(CONTEXT_DIR)
      .filter(f => f.endsWith(".md") && f !== "SOUL.md" && f !== "IDENTITY.md")
      .sort()
      .map(f => {
        const firstLine = tryRead(`${CONTEXT_DIR}/${f}`)
          .split("\n")
          .map(l => l.trim())
          .find(l => l && !l.startsWith("#") && !l.startsWith("_") && !l.startsWith("---") && !l.startsWith("⚠"));
        const desc = firstLine ? ` — ${firstLine.substring(0, 80)}` : "";
        return `- ${CONTEXT_DIR}/${f}${desc}`;
      });
  } catch { return []; }
})();

// Log what was indexed
const counts = {
  soul: SOUL ? "yes" : "no",
  identity: IDENTITY ? "yes" : "no",
  contexts: contextIndex.length,
  skills: skillDirs.length,
  memory: memoryFiles.length,
  root: rootFiles.length,
};
console.log(`[system-prompt] Embedded: SOUL.md (${counts.soul}), IDENTITY.md (${counts.identity}). Indexed: ${counts.contexts} contexts, ${counts.skills} skills, ${counts.memory} memory logs, ${counts.root} reference files`);

// Fallback if no files mounted
const DEFAULT_SOUL = `You are Maddie, a personal AI assistant. Be genuinely helpful, not performatively helpful. Have opinions. Be resourceful before asking. Earn trust through competence.`;

interface WidgetInfo {
  slug: string;
  title: string;
  description?: string;
  surface?: string;
}

export function buildSystemPrompt(
  channel: "talkclaw" | "telegram",
  widgets?: WidgetInfo[]
): string {
  const parts: string[] = [];

  // Core identity (fully embedded)
  parts.push(SOUL || DEFAULT_SOUL);
  if (IDENTITY) parts.push(IDENTITY);

  // File index — Claude reads these on demand
  parts.push(`## Available Files

You have access to reference files via the Read tool. Don't guess — look things up when relevant.

### Project Contexts
${contextIndex.length > 0 ? contextIndex.join("\n") : "(none found)"}

### Skills & Integrations
${skillDirs.length > 0 ? skillDirs.join("\n") : "(none found)"}

### Recent Memory Logs
${memoryFiles.length > 0 ? memoryFiles.join("\n") : "(none found)"}

### Reference Documents
${rootFiles.length > 0 ? rootFiles.join("\n") : "(none found)"}`);

  // Environment & capabilities
  parts.push(`## Environment & Capabilities

You run inside a Docker container on riehle-01 (Beelink N95). You have full access to your workspace.

### Your workspace: /data/context/
This is your home. You can read, write, edit, and delete any file here. It maps to ~/.openclaw/workspace/ on the host.
- Memory logs: /data/context/memory/
- Context files: /data/context/contexts/
- Skills: /data/context/skills/
- Reference docs: /data/context/*.md

### Bash and SSH
You have Bash and SSH access for host-level and remote commands:
- Host (riehle-01): \`ssh -o StrictHostKeyChecking=no riehle@host.docker.internal "command"\`
- riehle-02 (MacBook Air): \`ssh -i /root/.ssh/macbook_air_key riehle-02@192.168.1.218\`
- Main Mac: \`ssh -i /root/.ssh/mac_key harrisonriehle@192.168.1.202\`
- Omnira: \`ssh sam@100.89.121.25\`

Host tools: gog (Gmail/Calendar), summarize, systemctl, docker, git

Read /data/context/TOOLS.md for full tool inventory.`);

  // Channel-specific
  if (channel === "talkclaw") {
    parts.push(
      `## Channel Context\nThe user is chatting via TalkClaw, a self-hosted iOS chat app with a widget engine for interactive dashboards.`
    );
    if (widgets && widgets.length > 0) {
      const list = widgets
        .map((w) => `- ${w.slug}: ${w.title}${w.description ? ` — ${w.description}` : ""}`)
        .join("\n");
      parts.push(`## Active Widgets\n${list}`);
    }
  } else if (channel === "telegram") {
    parts.push(
      `## Channel Context\nThe user is chatting via Telegram. Keep responses concise and mobile-friendly. Use markdown formatting that Telegram supports.`
    );
  }

  return parts.join("\n\n---\n\n");
}
