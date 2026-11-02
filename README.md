# Example agent setup

A reference setup for working with coding agents. It works with [Claude Code](https://code.claude.com),
[opencode](https://opencode.ai) and [pi](https://pi.dev). Each file in this repo is a generic, self-contained
template that shows one building block. Nothing here is tied to a specific project, stack or team.

Use it to see how the pieces fit together, or copy the parts you need into your own repo.

## Building blocks

| Block        | What it is                                                                          | When it applies                    | Where                                         |
|--------------|-------------------------------------------------------------------------------------|------------------------------------|-----------------------------------------------|
| Guidelines   | Project instructions: overview, hard stops, working rules. Keep them short.         | Always, loaded at session start    | `AGENTS.md`, `CLAUDE.md`                      |
| Context docs | Glossary and architecture, mentioned in `AGENTS.md` instead of imported.            | On demand, when the task needs them | `docs/`                                       |
| Skills       | Task-specific knowledge. Only the description is loaded up front.                   | When a task matches the description | `.claude/skills/<name>/SKILL.md`             |
| Commands     | Reusable prompts triggered with `/name`, optionally with arguments.                 | When the user types the command    | `.claude/commands/`, `.opencode/commands/`, `.pi/prompts/` |
| Hooks        | Scripts that run before or after tool calls, no matter what the model decides.      | On every matching tool call        | `.claude/hooks/` + per-tool wiring            |
| Agents       | Subagents with their own context, model and tools. They return only the result.     | When work is delegated to them     | `.claude/agents/`, `.opencode/agents/`, `.pi/agents/` |

### Skill or agent?

- **Skill:** knowledge the current session should apply while it works. It loads into the main context, uses the
  session's model and tools, and costs little. Example: test-writing rules that apply where the code is written.
- **Agent:** a self-contained task handed off to a separate worker. It starts with a fresh context, can have its
  own model and a restricted tool set, and returns only the result. Use it when the intermediate steps would clutter
  the main context (research), when an unbiased view matters (review), or when a different model fits (planning).

## Layout

```
.
├── AGENTS.md                         # Shared instructions, loaded every session (all tools)
├── CLAUDE.md                         # Imports AGENTS.md, plus Claude-Code-specific notes
├── docs/
│   ├── glossary.md                   # Domain terms, read on demand
│   └── architecture.md               # System overview, read on demand
├── .claude/
│   ├── settings.json                 # Claude Code: wires up the hooks
│   ├── settings.local.json.example   # Claude Code: sample personal permission allowlist
│   ├── hooks/
│   │   └── safety-gate.sh            # Before tool call: blocks dangerous commands and secret access
│   ├── skills/
│   │   └── test-generation-skill/
│   │       └── SKILL.md              # Test-writing rules, loaded when the task matches (all tools)
│   ├── agents/                       # Claude Code subagents
│   │   ├── planner.md                # Plans work, writes no code
│   │   ├── code-reviewer.md          # Reviews the diff, findings by severity
│   │   └── tech-research.md          # Version-accurate research via MCP
│   └── commands/
│       └── review.md                 # /review [focus] launches the code-reviewer
├── .opencode/
│   ├── plugins/
│   │   └── hooks.ts                  # Runs the shared safety gate for opencode
│   ├── agents/                       # opencode versions of the three subagents
│   └── commands/
│       └── review.md                 # /review [focus] launches the code-reviewer
├── .pi/
│   ├── settings.json                 # pi: points to the shared skills in .claude/skills/
│   ├── extensions/
│   │   └── hooks.ts                  # Runs the shared safety gate for pi
│   ├── agents/                       # pi versions of the three subagents
│   └── prompts/
│       └── review.md                 # /review [focus] launches the code-reviewer
└── opencode.json                     # opencode: MCP servers
```

## Tool support

Shared content is written once. opencode and pi get their own file only where they can't read the shared one.

| Block        | Claude Code                         | opencode                          | pi                                     |
|--------------|-------------------------------------|-----------------------------------|----------------------------------------|
| Guidelines   | `CLAUDE.md` → `@AGENTS.md`          | `AGENTS.md`                       | `AGENTS.md`                            |
| Context docs | mentioned in `AGENTS.md`            | mentioned in `AGENTS.md`          | mentioned in `AGENTS.md`               |
| Skills       | `.claude/skills/`                   | `.claude/skills/` (native)        | `.pi/settings.json` → `.claude/skills/` |
| Commands     | `.claude/commands/`                 | `.opencode/commands/`             | `.pi/prompts/`                         |
| Hooks        | `.claude/settings.json` → scripts   | `.opencode/plugins/` → scripts    | `.pi/extensions/hooks.ts` → scripts    |
| Agents       | `.claude/agents/`                   | `.opencode/agents/`               | `.pi/agents/` + subagent extension     |
| MCP          | `mcpServers` in agent frontmatter   | `opencode.json`                   | — (`tech-research` uses `curl`)        |

### MCP servers and models

- **Claude Code:** `planner` and `tech-research` declare Context7 under `mcpServers` in their own frontmatter. The
  server starts only when one of these agents runs, so no `.mcp.json` is needed. Add one only if the main session
  should use an MCP server as well.
- **opencode:** an agent can't bring its own MCP server. Context7 is set up once in `opencode.json`, and then every
  agent sees its tools, the main agent too. Without `opencode.json` the opencode agents have no Context7.
- **Models:** the Claude agents use the aliases `opus` and `sonnet`. The opencode agents name a provider and model
  (`anthropic/claude-opus-5-5`). If you don't use Anthropic in opencode, change `model:` to a model of your provider
  (`opencode models` lists them) or remove the line so the agent uses the session's model.

### Agent definitions

All three tools define an agent as a Markdown file: YAML frontmatter on top, the system prompt below. The body can
stay the same; the frontmatter can't, so each tool gets its own file. pi has no built-in subagents; the column
describes its [subagent example extension](https://github.com/earendil-works/pi/tree/main/packages/coding-agent/examples/extensions/subagent),
which each user installs once (see [Setting up pi](#setting-up-pi)).

| Category    | Aspect              | Claude Code                       | opencode                                  | pi (subagent extension)               |
|-------------|---------------------|-----------------------------------|-------------------------------------------|---------------------------------------|
| Definition  | Location            | `.claude/agents/`                 | `.opencode/agents/`                       | `.pi/agents/`                         |
|             | Name                | `name:`                           | file name                                 | `name:` (required)                    |
|             | Mark as subagent    | not needed                        | `mode: subagent`                          | not needed                            |
| Model       | Format              | alias (`opus`, `sonnet`)          | `provider/model`                          | model ID; session's model if omitted  |
| Tools       | Restriction         | `tools:` allowlist (`Read, Grep`) | `permission:` allow/deny per tool, with patterns (`"git diff*": allow`) | `tools:` allowlist (`read, grep`), not strictly enforced |
|             | MCP                 | `mcpServers:` per agent           | global, in `opencode.json`                | —                                     |
| Runtime     | Context             | fresh, only the result returns    | fresh, only the result returns            | separate pi process, only the result returns |
|             | Parallel            | yes                               | yes                                       | yes, within one tool call (max. 8)    |
|             | Background          | yes                               | yes, `background: true` (v1: experimental, needs `OPENCODE_EXPERIMENTAL_BACKGROUND_SUBAGENTS=true`) | — (the main agent waits)              |
|             | Chaining            | —                                 | —                                         | yes (`{previous}` passes output on)   |
| Extras      | Memory              | `memory:`                         | —                                         | —                                     |
|             | Built in            | yes                               | yes                                       | no, installed per user                |

### Hook lifecycles

The idea is the same in all three tools: code runs at fixed points of a session and can block or change what
happens. The events and how you write the code differ.

| Point in the session | Claude Code (shell scripts, JSON on stdin) | opencode (JS/TS plugin)       | pi (TS extension)              |
|----------------------|--------------------------------------------|-------------------------------|--------------------------------|
| Session starts       | `SessionStart`                             | `session.created`             | `session_start`                |
| Prompt submitted     | `UserPromptSubmit` (can block)             | —                             | `input` (can transform/handle) |
| Before a tool call   | `PreToolUse` (can block)                   | `tool.execute.before` (throw blocks) | `tool_call` (can block)  |
| After a tool call    | `PostToolUse` (feedback to the agent)      | `tool.execute.after`          | `tool_result` (can patch)      |
| Subagent starts      | `SubagentStart`                            | —                             | — (subagents via extension, no event) |
| Before compaction    | `PreCompact` (can block)                   | `experimental.session.compacting` | `session_before_compact` (can cancel) |
| Agent finished       | `Stop` (can keep it working)               | `session.idle`                | `agent_end`                    |
| Session ends         | `SessionEnd`                               | —                             | `session_shutdown`             |

Claude Code has the most events and is the only one configured declaratively in `settings.json`. opencode and pi
hook in through code, which is why this repo keeps the rules in shell scripts and lets the opencode plugin
and the pi extension call them.

## Adopting the setup

1. Copy the files for the tools you use into the root of your repo. `AGENTS.md`, `docs/`, `.claude/hooks/` and
   `.claude/skills/` are shared by all three.
2. Fill in the Project Overview in `AGENTS.md`, and `docs/glossary.md` and `docs/architecture.md` for your project.
   Keep `AGENTS.md` short: mention the docs where they are needed instead of copying their content.
3. Adjust the rest of `AGENTS.md` to your project's hard stops and conventions. Put anything that only applies to
   Claude Code in `CLAUDE.md`.
4. Review the safety gate. Extend the block lists in `.claude/hooks/safety-gate.sh` to match your stack; it needs
   `jq`. The opencode plugin and the pi extension call the same script, so changes apply to all tools.
5. For Claude Code, copy `.claude/settings.local.json.example` to `.claude/settings.local.json` and tailor the
   allowlist. The local file is personal and stays out of version control.
6. Keep only the skills, agents and commands you will actually use, and tune their descriptions so they trigger
   when you expect them to. If you change an agent, update its Claude Code, opencode and pi version.
7. For pi, follow [Setting up pi](#setting-up-pi).

### Setting up pi

pi ([`@earendil-works/pi-coding-agent`](https://pi.dev))
has no built-in subagents and no MCP, and it hooks in through TypeScript extensions.

- **Trust the project.** pi loads `.pi/` (settings, extensions, prompt templates) only after you trust the project.
  Until then the safety gate is not active and the shared skills are not found. `AGENTS.md` is loaded either way.
- **Install the subagent extension** once per machine. It is pi's
  [subagent example](https://github.com/earendil-works/pi/tree/v1.4.0/packages/coding-agent/examples/extensions/subagent)
  and not part of this repo. It adds a `subagent` tool that runs the agents in `.pi/agents/` in their own pi process:

  ```bash
  mkdir -p ~/.pi/agent/extensions/subagent
  cd ~/.pi/agent/extensions/subagent
  for f in index.ts agents.ts; do
    curl -fsSLO https://raw.githubusercontent.com/earendil-works/pi/v1.4.0/packages/coding-agent/examples/extensions/subagent/$f
  done
  ```

  Use the tag of your pi version (`pi --version`), then restart pi or run `/reload`.
- **Ask for project agents explicitly.** The extension loads `.pi/agents/` only when the call passes
  `agentScope: "both"`. `/review` does this; for other delegations, say so ("use the planner subagent with
  agentScope both").
- **Without the extension,** turn each agent into a skill: move `.pi/agents/<name>.md` to
  `.pi/skills/<name>/SKILL.md`, remove `tools` and `model`, and change `.pi/prompts/review.md` to load the
  `code-reviewer` skill. The agents then run in the main context on the session's model.
- **Models:** the pi agents name `claude-opus-5-5` and `claude-sonnet-5-5`. Change `model:` for other providers or
  remove it to use the session's model.
- **Known gaps:** pi also reads `CLAUDE.md`, so `AGENTS.md` may load twice. Commands you run yourself with `!` do
  not pass the safety gate.

## Useful resources

<!--
Template for new entries (check the link before adding it):
- **[Title](URL)** — what it is, in one sentence. How it relates to this setup.
-->

- **[Karpathy guidelines (skill)](https://github.com/multica-ai/andrej-karpathy-skills/blob/main/skills/karpathy-guidelines/SKILL.md)**
  — behavioral guidelines against common LLM coding mistakes: think before coding, simplicity first, surgical
  changes, goal-driven execution. The same ideas as the Working Guidelines in `AGENTS.md`. Here they load into
  every session; packaged as a skill, they would load only when the agent writes, reviews or refactors code.
- **[Claude Code hooks reference](https://code.claude.com/docs/en/hooks)** — all hook events in lifecycle order
  (`SessionStart`, `UserPromptSubmit`, `PreToolUse`, `PostToolUse`, `Stop`, `SubagentStart`, `PreCompact`, …),
  which of them can block, the JSON input and output, and exit codes. `safety-gate.sh` follows the `PreToolUse`
  contract described there (exit 2 blocks). opencode (plugin events) and pi (extension events) have their own
  event models; see the comparison below the tool support table.
- **[claude-howto: hooks](https://github.com/luongnv89/claude-howto/tree/main/06-hooks)** — a guide with ready-made
  example hooks: formatting after edits, scanning written code for secrets, validating prompts, logging commands,
  tracking context usage. Useful as a starting point for hooks beyond the two in this repo.
- **[everything-claude-code: skills](https://github.com/affaan-m/everything-claude-code/tree/main/.agents/skills)** —
  a large collection of ready-made skills (coding, testing, security, MCP, evals, research, content). Good for
  seeing how other people scope skills and write their descriptions.
- **[awesome-claude-agents](https://github.com/vijaythecoder/awesome-claude-agents/tree/main/agents)** — subagent
  definitions grouped into core, orchestrator, specialized and universal agents. Shows how a team of agents can
  split work between a coordinator and specialists.
- **[claude-code-best-practice](https://github.com/shanraisshan/claude-code-best-practice/tree/main/best-practice)**
  — short best-practice notes per Claude Code feature: subagents, skills, commands, memory, MCP, settings.
- **[wshobson/agents: plugins](https://github.com/wshobson/agents/tree/main/plugins)** — around 90 plugins that
  bundle agents, commands and skills per topic. An example of sharing a setup through a plugin marketplace.
- **[MCP Market](https://mcpmarket.com/server)** — a directory of MCP servers, searchable and filterable by
  category (developer tools, databases, browser automation, …). Use it to check whether a server already exists
  before wiring one into an agent's frontmatter or `opencode.json`, as this repo does with Context7. Listings are
  submitted by third parties and the site describes no review process: check the maintainer and source before
  adding one, and prefer servers marked "Official" or published by the vendor.
- **[pi subagent extension (example)](https://github.com/earendil-works/pi/blob/main/packages/coding-agent/examples/extensions/subagent/agents.ts)**
  — an example extension that adds subagents to pi: agents are Markdown files with `name`, `description`, `tools`
  and `model`, each run in its own pi process, and only the final answer returns. Supports single, parallel and
  chained runs. Not built in; [Setting up pi](#setting-up-pi) shows how to install it. `mcpServers`, agent memory
  and background runs have no equivalent.

## Not committed

Agent memory (`.claude/agent-memory/`), plans (`.agents/plans/`) and personal files (`.claude/settings.local.json`,
`CLAUDE.local.md`) are created locally and ignored by git.
