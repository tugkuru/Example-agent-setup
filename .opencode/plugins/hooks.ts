// Runs the shared hook scripts from .claude/hooks/ for opencode.
// The scripts expect Claude Code's hook input, so opencode's tool names and arguments are mapped to that shape.
// Exit code 2 from a script blocks the tool call; its stderr becomes the error the agent sees.

import type { Plugin } from "@opencode-ai/plugin"
import { spawnSync } from "node:child_process"
import { join } from "node:path"

const TOOL_NAMES: Record<string, string> = {
  bash: "Bash",
  read: "Read",
  write: "Write",
  edit: "Edit",
  grep: "Grep",
  glob: "Glob",
}

function toClaudeInput(tool: string, args: Record<string, any>): Record<string, unknown> {
  switch (tool) {
    case "bash":
      return { command: args.command }
    case "grep":
      // opencode's grep returns matching lines, which corresponds to Claude Code's content mode.
      return { pattern: args.pattern, path: args.path, glob: args.include, output_mode: "content" }
    case "glob":
      return { pattern: args.pattern, path: args.path }
    default:
      return { file_path: args.filePath ?? args.path, content: args.content, new_string: args.newString }
  }
}

export const SafetyGate: Plugin = async ({ directory, worktree }) => {
  const script = join(worktree || directory, ".claude/hooks/safety-gate.sh")

  const check = (toolName: string, toolInput: Record<string, unknown>) => {
    const result = spawnSync("bash", [script], {
      input: JSON.stringify({ tool_name: toolName, tool_input: toolInput }),
      encoding: "utf8",
    })
    if (result.error) throw new Error(`safety-gate could not run: ${result.error.message}`)
    if (result.status === 2) throw new Error(result.stderr.trim())
  }

  return {
    "tool.execute.before": async (input, output) => {
      const args = output.args ?? {}

      // apply_patch carries its target files inside the patch text.
      if (input.tool === "apply_patch") {
        const patch = String(args.patchText ?? "")
        for (const [, file] of patch.matchAll(/^\*\*\* (?:Add File|Update File|Delete File|Move to): (.+)$/gm)) {
          check("Edit", { file_path: file.trim(), new_string: patch })
        }
        return
      }

      const toolName = TOOL_NAMES[input.tool]
      if (toolName) check(toolName, toClaudeInput(input.tool, args))
    },
  }
}
