# Setting up pi

This folder contains the project setup for [pi](https://pi.dev) (`@earendil-works/pi-coding-agent`). It is
independent of the Claude Code and opencode folders: hooks, skills, prompts and agent definitions are included
here as real files, not symlinks. All project paths below are relative to the repository root.

## Quick start

1. **Install prerequisites:** pi, Bash and `jq`. See [pi's installation guide](https://pi.dev). Run `pi --version`
   to check your version. The subagent installation below uses pi 1.4.0; use the matching tag for your version.
2. **Copy into your project:** copy `.pi/`, `AGENTS.md` and `docs/` into its root. You do not need `.claude/`,
   `.opencode/`, `CLAUDE.md` or `opencode.json`. From this example repository, for a new destination:

   ```bash
   DEST=/path/to/your/project
   mkdir -p "$DEST"
   cp -R AGENTS.md docs .pi "$DEST/"
   ```

   For an existing setup, merge the files rather than overwriting your project instructions or context docs.
3. **Adapt the instructions:** fill in `AGENTS.md`, `docs/architecture.md` and `docs/glossary.md`. In the Agent
   Usage Guidelines, specify that project-agent delegations must pass `agentScope: "both"`.
4. **Install the subagent extension:** follow [the instructions below](#install-the-subagent-extension) once per
   machine. The agent definitions in `.pi/agents/` alone do not add a `subagent` tool.
5. **Start and trust the project:** run `pi` from your project root and grant project trust after reviewing the
   files. Connect your provider with `/login` if needed. Run `/reload` if pi was already open.
6. **Check the setup:** confirm there are no extension-loading errors, try `/skill:focused-responses`, and ask
   pi to use `planner` with `agentScope: "both"` for a small planning task. `/review` delegates to `code-reviewer`.

**Trust first:** pi loads project settings, extensions, skills and prompt templates only after you trust the
project. Until then the safety gate is not active and the local skills are not found. `AGENTS.md` is loaded
either way.

## Files and maintenance

- `.pi/README.md`: this setup guide; it is not automatically loaded as agent instructions.
- `.pi/settings.json`: optional project overrides; no extra skill paths are needed.
- `.pi/skills/`: the four bundled skills, discovered natively.
- `.pi/hooks/safety-gate.sh`: the local safety gate; adapt its block lists to your stack.
- `.pi/extensions/hooks.ts`: maps pi tool calls to the local gate's input format.
- `.pi/prompts/`: `/review`, `/grilling`, `/code-walkthrough` and `/focused-responses`.
- `.pi/agents/`: `planner`, `code-reviewer` and `tech-research` definitions for the subagent extension.

Hooks and skills are intentionally duplicated so this folder is independently copyable. When maintaining this
multi-tool example, apply shared rule changes to both copies manually; nothing synchronizes them automatically.

## Block by block

| Block        | pi                                              | Carries over                         | Lost or different                                       |
|--------------|-------------------------------------------------|--------------------------------------|---------------------------------------------------------|
| Guidelines   | `AGENTS.md`, read natively                      | Everything in `AGENTS.md`            | pi also reads `CLAUDE.md`; whether it resolves `@AGENTS.md` is unconfirmed, so the content may load twice |
| Context docs | mentioned in `AGENTS.md`                        | Read on demand, as before            | —                                                       |
| Skills       | `.pi/skills/`                                 | Local copies of the `SKILL.md` files | Also callable as `/skill:<name>`                        |
| Commands     | `.pi/prompts/review.md`                         | `/review [focus]`, `$ARGUMENTS`      | No `agent:` or `subtask:`; the prompt asks the main agent to call the `subagent` tool |
| Hooks        | `.pi/extensions/hooks.ts` → `safety-gate.sh`    | Same script, exit 2 blocks           | See [Safety gate](#safety-gate)                         |
| Agents       | `.pi/agents/*.md` + subagent extension (installed per user) | Same instructions, own context, own model, tool allowlist | See [Subagents](#subagents)              |
| MCP          | Not configured by this setup                    | —                                    | No Context7 configured; agents fetch docs with `curl`, which needs `bash` in their `tools` |

## Subagents

pi has no built-in subagents. The three agents in `.pi/agents/` keep the instructions of the Claude Code versions;
the frontmatter has `name`, `description` and `tools` (pi tool names), and the Agent Memory section and the
Context7 references are removed. They only run through pi's subagent extension, which is required.

### Install the subagent extension

pi's [subagent example extension](https://github.com/earendil-works/pi/tree/v1.4.0/packages/coding-agent/examples/extensions/subagent)
adds a `subagent` tool that runs each agent in its own pi process with a fresh context and returns only the final
answer. It supports single, parallel (up to 8, 4 at a time) and chained runs. It is not part of this repo: install it
once per machine into your user extensions, where it works in every project.

```bash
mkdir -p ~/.pi/agent/extensions/subagent
cd ~/.pi/agent/extensions/subagent
for f in index.ts agents.ts; do
  curl -fsSLO https://raw.githubusercontent.com/earendil-works/pi/v1.4.0/packages/coding-agent/examples/extensions/subagent/$f
done
```

Restart pi or run `/reload`. Use the tag of your pi version (`pi --version`). The extension only provides the tool;
the agents it runs are the ones in `.pi/agents/`.

- **Project agents need a flag:** the extension loads `.pi/agents/` only when the call passes
  `agentScope: "both"` (default: only `~/.pi/agent/agents/`). `/review` passes it; for other delegations, ask for
  it ("use the planner subagent with agentScope both"). In an untrusted project, pi asks before running them.
- **Not like Claude Code:** no per-agent `mcpServers`, no agent memory, no background runs (the main agent waits), and the
  `tools` allowlist is not strictly enforced. Read-only rules are also in the agents' instructions.
- **Models:** all three agents omit `model:` and inherit the calling session's model and reasoning level.
  The planner can call `tech-research` through `subagent` with `agentScope: "both"` for documentation and version
  checks, without needing shell access itself.

When you change an agent, update its `.claude/agents/`, `.opencode/agents/` and `.pi/agents/` version.

## Safety gate

`.pi/extensions/hooks.ts` maps pi's tool calls to Claude Code's hook input format and runs the local
`.pi/hooks/safety-gate.sh` on the `tool_call` event. Claude Code does not need to be installed.

- Covered: `bash`, `read`, `edit`, `write`, `grep`, `find`, `ls`. Subagents are pi processes in the same project
  and should load the extension too; this is not verified yet.
- Commands you run yourself with `!` do not pass through this gate.
- Needs Bash and `jq`; missing or crashing gate scripts block calls rather than allowing them.

## Adapting `AGENTS.md`

`AGENTS.md` is shared and reads the same for pi with the subagent extension. One difference: delegating to a project
agent needs `agentScope: "both"`. For a pi-only repo, add that to the Agent Usage Guidelines.
