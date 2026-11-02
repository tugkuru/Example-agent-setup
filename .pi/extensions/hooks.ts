// Runs the shared hook scripts from .claude/hooks/ for pi.
// The scripts expect Claude Code's hook input, so pi's tool names and arguments are mapped to that shape.
// Exit code 2 from a script blocks the tool call; its stderr becomes the reason the agent sees.

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent"
import { spawnSync } from "node:child_process"
import { fileURLToPath } from "node:url"

const SCRIPT = fileURLToPath(new URL("../../.claude/hooks/safety-gate.sh", import.meta.url))

const TOOL_NAMES: Record<string, string> = {
  bash: "Bash",
  read: "Read",
  write: "Write",
  edit: "Edit",
  grep: "Grep",
  find: "Glob",
  ls: "Glob",
}

function toClaudeInput(tool: string, input: Record<string, any>): Record<string, unknown> {
  switch (tool) {
    case "bash":
      return { command: input.command }
    case "edit":
      return { file_path: input.path, new_string: (input.edits ?? []).map((e: any) => e.newText).join("\n") }
    case "grep":
      // pi's grep returns matching lines, which corresponds to Claude Code's content mode.
      return { pattern: input.pattern, path: input.path, glob: input.glob, output_mode: "content" }
    case "find":
      return { pattern: input.pattern, path: input.path }
    case "ls":
      return { path: input.path }
    default:
      return { file_path: input.path, content: input.content }
  }
}

export default function (pi: ExtensionAPI) {
  pi.on("tool_call", async (event) => {
    const toolName = TOOL_NAMES[event.toolName]
    if (!toolName) return

    const result = spawnSync("bash", [SCRIPT], {
      input: JSON.stringify({ tool_name: toolName, tool_input: toClaudeInput(event.toolName, event.input ?? {}) }),
      encoding: "utf8",
    })
    if (result.error) return { block: true, reason: `safety-gate could not run: ${result.error.message}` }
    if (result.status === 2) return { block: true, reason: result.stderr.trim() || "Blocked by safety-gate." }
    // Fail closed: a missing script or a crash must not let the call through.
    if (result.status !== 0) {
      return { block: true, reason: `safety-gate failed (status ${result.status}, signal ${result.signal})` }
    }
  })
}
