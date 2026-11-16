# Plan: Example-agent-setup

We build this repo file by file. Each step produces exactly one file (or one section of `README.md`), which is
reviewed and committed on its own.
Status: `[ ]` open · `[~]` in progress · `[x]` done · `[-]` dropped

## Ground rules

- **Language:** everything in English.
- **Neutral:** no example project, no stack, no company or person specifics. Files are generic templates that any
  repo can adopt. Instructions are worded generically ("run the project's test command") instead of using
  `<PLACEHOLDER>` tokens.
- **Three agents:** the setup works for Claude Code, opencode and pi. Shared content is written once; opencode and
  pi get only a thin adapter where they cannot read the shared file directly.
  - Instructions: `AGENTS.md` is the single source (read by opencode). `CLAUDE.md` imports it with `@AGENTS.md`
    and holds only Claude-Code-specific notes. Claude Code can read `AGENTS.md` natively (v2.1.277+), but the
    import also covers older versions and sessions where it can't, and is never loaded twice.
  - Skills: live in `.claude/skills/`, which opencode reads natively.
  - Hooks: rule logic lives in shell scripts under `.claude/hooks/`. Claude Code calls them from `settings.json`;
    opencode calls the same scripts from a small TypeScript plugin in `.opencode/plugins/`.
- **pi:** gets its own files in Phase 7. pi reads `AGENTS.md` directly; agents run through pi's subagent example
  extension, which each user installs (required; not copied into the repo), hooks become a TypeScript
  extension, slash commands become prompt templates. The README section "Setting up pi" covers the setup; `PI.md`
  is a local working note and is not committed.
- **Project context is explained, not invented:** `docs/glossary.md` and `docs/architecture.md` are empty-but-guided
  templates. `AGENTS.md` mentions each one where it is needed (glossary under Domain Terms, architecture under
  Project Overview), so agents read them on demand (no `@` import).
- **Sources:** `banz/coding-agent-harness` and `banz/immotep-backend`. Only generic patterns are taken over.
- **Deliberately left out:** rubber-ducky (private). Agent memory and plans are created locally and never committed.
- **Verify tool specifics before writing:** opencode and pi details (event names, blocking semantics, frontmatter)
  are checked against their current docs in the step that uses them.
- **README instead of a landing page:** `README.md` holds the overview, tool support and useful resources; no
  `index.html`.

## Phase 1 – Skeleton

| #   | Status | File         | Content                                                                         |
|-----|--------|--------------|---------------------------------------------------------------------------------|
| 1.1 | [x]    | `README.md`  | Purpose of the repo, layout, tool support matrix, pointer to `PI.md`, how to adopt |
| 1.2 | [x]    | `.gitignore` | `.claude/settings.local.json`, `CLAUDE.local.md`, `.claude/agent-memory/`, `.agents/plans/`, `.opencode/node_modules/`, `.idea/`, `*.iml`, `.DS_Store` |
| 1.3 | [-]    | `index.html` | Landing page skeleton: header, hero, empty sections, light/dark theme. No content yet |

## Phase 2 – Project context

Shows: what is loaded every session vs. what is read on demand.

| #   | Status | File                   | Content                                                                    |
|-----|--------|------------------------|----------------------------------------------------------------------------|
| 2.1 | [x]    | `AGENTS.md`            | Shared: project overview, hard stops, working guidelines, domain terms, agent usage |
| 2.2 | [x]    | `CLAUDE.md`            | `@AGENTS.md` import plus Claude-Code-specific notes only                  |
| 2.3 | [x]    | `docs/glossary.md`     | Template: term · meaning; one marked sample row |
| 2.4 | [x]    | `docs/architecture.md` | Template: overview, modules/layers, data flow, integrations, constraints, decisions |

## Phase 3 – Hooks

Shows: deterministic rules that apply no matter what the model decides — written
once as shell scripts, wired into all three tools (pi in 7.2).

| #   | Status | File                                  | Content                                                        |
|-----|--------|---------------------------------------|----------------------------------------------------------------|
| 3.1 | [x]    | `.claude/hooks/safety-gate.sh`        | Before tool call: blocks dangerous commands and secret access   |
| 3.2 | [-]    | `.claude/hooks/pii-log-check.sh`      | After tool call: nudges the agent when log statements contain likely PII |
| 3.3 | [x]    | `.claude/settings.json`               | Claude Code: wires up the safety gate                          |
| 3.4 | [x]    | `.claude/settings.local.json.example` | Claude Code: sample permission allowlist                        |
| 3.5 | [x]    | `.opencode/plugins/hooks.ts`          | opencode: `tool.execute.before` calling the safety gate         |

## Phase 4 – Skill

Shows: knowledge that loads only when the task matches, and how the `description` controls triggering.

| #   | Status | File                                        | Content                                                     |
|-----|--------|---------------------------------------------|-------------------------------------------------------------|
| 4.1 | [x]    | `.claude/skills/test-generation-skill/SKILL.md` | Stack-neutral test rules: scope, naming, AAA, doubles, edge cases; frontmatter valid for both tools |

## Phase 5 – Subagents (Claude Code, opencode)

Shows: separate context, own model, narrowly scoped tools, MCP in the frontmatter. Each agent has one file per tool
because the frontmatter differs (`tools`/`model` vs. `mode: subagent`/`permission`/`provider/model`).

| #   | Status | File                                | Content                                                         |
|-----|--------|-------------------------------------|-----------------------------------------------------------------|
| 5.1 | [x]    | `.claude/agents/planner.md`         | Plans with phases, test strategy and success criteria; writes no code; reads the context docs |
| 5.2 | [x]    | `.claude/agents/code-reviewer.md`   | Reviews the diff against `AGENTS.md` and the context docs, findings by severity |
| 5.3 | [x]    | `.claude/agents/tech-research.md`   | Version-accurate research via Context7 (MCP), with evidence      |
| 5.4 | [x]    | `.opencode/agents/planner.md`       | opencode version of 5.1                                         |
| 5.5 | [x]    | `.opencode/agents/code-reviewer.md` | opencode version of 5.2                                         |
| 5.6 | [x]    | `.opencode/agents/tech-research.md` | opencode version of 5.3                                         |
| 5.7 | [-]    | `.mcp.json`                         | Dropped: the Claude agents define Context7 in their frontmatter |
| 5.8 | [x]    | `opencode.json`                     | opencode: Context7 MCP server (and permissions, if useful)      |
| 5.9 | [x]    | `README.md`                         | Note: opencode agents use `anthropic/…` models and need Context7 from `opencode.json`; how to switch provider/model |

## Phase 6 – Slash command (Claude Code, opencode)

| #   | Status | File                           | Content                                        |
|-----|--------|--------------------------------|------------------------------------------------|
| 6.1 | [x]    | `.claude/commands/review.md`   | `/review [focus]` launches the `code-reviewer` |
| 6.2 | [x]    | `.opencode/commands/review.md` | `/review [focus]` with `agent: code-reviewer`, `subtask: true` |

## Phase 7 – pi

Done after Phases 1–6. Paths and formats are checked against the current pi docs first.

| #   | Status | File                     | Content                                                                     |
|-----|--------|--------------------------|-----------------------------------------------------------------------------|
| 7.1 | [x]    | `.pi/settings.json`      | pi project settings (skills path, if `.claude/skills/` is not read natively) |
| 7.2 | [x]    | `.pi/extensions/hooks.ts` | Extension calling `safety-gate.sh` before tool calls                        |
| 7.3 | [-]    | `.pi/skills/planner/SKILL.md`, `code-reviewer/SKILL.md`, `tech-research/SKILL.md` | The Phase 5 agents as skills. Replaced by 7.6 |
| 7.4 | [x]    | `.pi/prompts/review.md`  | `/review [focus]` as a prompt template                                      |
| 7.5 | [x]    | `PI.md`                  | What changes for pi, block by block: what carries over, what is lost, `AGENTS.md` sections to adapt (agent usage, agent output handling) |
| 7.6 | [x]    | `.pi/agents/*.md` | The Phase 5 agents as pi subagents. pi's subagent example extension is not copied into the repo; `PI.md` explains installing it per user. `/review`, `PI.md` and `README.md` updated |
| 7.7 | [ ]    | — | End-to-end test in pi (later): install the extension, `/review` starts the subagent, the safety gate blocks `.env` (also inside a subagent), check whether `CLAUDE.md` and `AGENTS.md` load twice. Review finding: confirm `.pi/extensions/hooks.ts` loads at all (`import.meta.url` must resolve under pi; if not, the gate is silently missing — then resolve the script from the project directory instead) |

## Phase 8 – README content

The user provides the content; Claude fits it into `README.md`.

| #   | Status | File        | Section                                                                        |
|-----|--------|-------------|--------------------------------------------------------------------------------|
| 8.1 | [x]    | `README.md` | Building blocks table (replaces the `index.html` overview)                     |
| 8.2 | [x]    | `README.md` | Useful resources (links checked before adding) with a template for new entries |
| 8.3 | [x]    | `README.md` | Hook lifecycles: Claude Code vs. opencode vs. pi                               |
| 8.4 | [x]    | `README.md` | "Skill or agent?": when to use which, under Building blocks                    |
| 8.5 | [x]    | `README.md` | "Agent definitions": frontmatter and runtime comparison of the three tools     |
| 8.6 | [x]    | `README.md` | pi column in Tool support, `.pi/` in Layout, "Setting up pi" (replaces `PI.md` for adopters) |

## Possible later

- `.claude/rules/<area>.md` with `paths:` as a live example of path-scoped context
- `security-engineer` agent (review without write access)
- **Safety gate gap (all tools):** reading `credentials.yml`, `secrets.toml` or `id_rsa.bak` is not blocked. The
  broad filename list in `safety-gate.sh` (`*credentials.*`, `*secrets.*`, `*id_rsa*`, `*.key`, `*secrets/*`) is
  only checked against search paths (`tool_input.path`), not `file_path` of Read/Write/Edit. Fix once in the script
  so Claude Code, opencode and pi are covered alike; keep `CredentialsService.java` readable.
- **Safety gate gap (pi credentials; follow-up only):** the protected-file patterns do not cover pi's
  `~/.pi/agent/auth.json` or `~/.pi/agent/mcp-auth.json`. Add path-aware protection and regression tests using fake
  fixtures; do not read real credential files. No safety-gate changes are part of the workshop setup.
- **Background subagents (pi; follow-up only):** the official pi 1.4.0 example supports single, parallel and chained
  calls, but waits for completion. The grilling skill's non-blocking exploration needs a background extension:
  start returns a job ID, status/result retrieval, cancellation, lifecycle cleanup and result delivery back to the
  conversation. Preserve project trust, safety hooks and model inheritance. Not implemented for the workshop test.
- `/adapt-stack` command that fills the templates for a concrete repo
- pi usability closer to Claude Code, via extensions (`.pi/extensions/`):
  - **Asking back:** permission prompts before risky tool calls (`tool_call` event, `ctx.ui.confirm`, returns
    `{ block: true }` on decline) and a question tool the model can call to ask the user (`pi.registerTool` with
    `ctx.ui.select`/`input`), like Claude Code's `AskUserQuestion`.
  - **Memory:** see [Outlook: Memory](#outlook-memory).
- Outlook only, not to be implemented now: sharing agents, skills, hooks and central rules across repos via a
  shared plugin marketplace (as in `immotep-ai-harness`: a plugin with `hooks.json`, and `SessionStart`/
  `SubagentStart` hooks that pass central rules to the main session and every subagent). Just a short README note
  for teams that want to share their setup later.
- README section with practical tips for daily work with the agents (working title "Working with agents", name
  not decided yet). First entry, resuming sessions (check against `--help` of each tool before adding):

  | Tool        | Continue last session | Pick a session                    | Specific session    |
  |-------------|-----------------------|-----------------------------------|---------------------|
  | Claude Code | `claude -c`           | `claude -r` / `/resume`           | `claude -r <id>`    |
  | opencode    | `opencode -c`         | `/sessions` in the TUI            | `opencode -s <id>`  |
  | pi          | `pi -c`               | `pi -r` / `/resume`               | `pi --session <path>` |

  Headless runs in opencode: `opencode run -c "…"` / `opencode run -s <id> "…"`.

## Outlook: Memory

Outlook only, not to be implemented now. Checked on 2026-11-02 against pi 1.4.0 and 1.5.0 (npm tarball docs and
examples) and opencode 1.19.5.

### Where each tool stands

| Tool        | Built-in memory                                                                 | Per-agent memory                         |
|-------------|---------------------------------------------------------------------------------|------------------------------------------|
| Claude Code | Auto memory in `~/.claude/projects/<project>/memory/`, `MEMORY.md` index loaded at session start | `memory:` frontmatter → `.claude/agent-memory/` |
| opencode    | None (open request anomalyco/opencode#43068)                                     | None                                     |
| pi          | None, and no official memory extension or package                               | None (no built-in subagents)             |

- pi only loads context files: `AGENTS.override.md`, `AGENTS.md`, `CLAUDE.md` from `~/.pi/agent/`, the working
  directory and its parents, plus `SYSTEM.md`/`APPEND_SYSTEM.md` (global and `.pi/`). None of them are written by
  the agent.
- There is no `memory` field in `AGENTS.md` or in `.pi/agents/*.md`. A memory extension does not add one.

### Options for pi

1. **Skill or `AGENTS.md` instruction, no code:** tell the agent to keep notes in e.g. `.pi/memory/*.md` and read
   the index at the start. Cheap and works in all three tools, but the agent has to remember to read and write;
   nothing loads automatically.
2. **Community package:** install with `pi install npm:<package>` (personal or project scope, see
   `docs/packages.md`). Candidates: `@henryqw/pi-memory` (`MEMORY.md`/`USER.md` with size caps, closest to Claude
   Code), `pi-memory` by jayzeng (daily logs, long-term memory, semantic search). Not reviewed; extensions run
   with full user rights, so read the code before installing.
3. **Own extension `.pi/extensions/memory.ts`** (recommended if we build it). Loads only once the project is
   trusted, like the safety gate.

### What the own extension would entail

| Part   | pi API                                                     | Behavior                                                       |
|--------|------------------------------------------------------------|----------------------------------------------------------------|
| Load   | `before_agent_start` → add a section via `event.systemPromptOptions.sections` | Inserts `MEMORY.md` into the system prompt. Changing `sections` is cache-friendly; returning a full `systemPrompt` causes cache misses |
| Save   | `pi.registerTool({ name: "remember", … })` with `promptGuidelines` | The model writes or updates an entry file and the index line   |
| Forget | Same tool or a second one                                  | Removes stale or wrong entries                                 |
| Manual | Optional `/remember` command                               | The user saves something explicitly                            |

**When memory is saved:**

- **Model-driven (main path):** the model calls `remember` whenever it learns something worth keeping, such as a
  user correction, a confirmed approach, or a project fact that is not in the repo. The tool's `promptGuidelines`
  decide how reliably this happens.
- **On user request:** "remember that …" or `/remember`.
- **Not automatic at session end:** `session_shutdown` and `session_before_compact` exist, but extracting
  memories there would need an extra LLM call from the extension. Not checked whether that is supported.

**How the model decides what to remember:**

There is no separate relevance mechanism, in Claude Code either. Claude Code's auto memory is a section in the
system prompt plus the normal write tool; the model applies those rules while it works. The pi extension has to
ship the same guidance, in the tool's `promptGuidelines` and/or a `systemPromptOptions.sections` entry:

- **Types worth saving** (modelled on Claude Code):
  - `user`: role, expertise, preferences
  - `feedback`: corrections and confirmed approaches, with the reason
  - `project`: ongoing goals and constraints not derivable from the code
  - `reference`: pointers to external resources (URLs, dashboards, tickets)
- **Not saved:** anything already in the repo, git history or `AGENTS.md`/`CLAUDE.md`, and anything that only
  matters to the current conversation.
- **Maintenance:** update an existing entry instead of adding a duplicate; delete entries that turn out wrong.
- **Typical triggers:** the user corrects the agent, confirms a non-obvious approach, or shares a fact about
  themselves or the project that is not in the code.
- **Structured tool parameters** (`type`, `name`, `description`, `content`) enforce the shape and filter out
  obvious noise.

How well it works depends on this text and on the model: weaker models save less often or save too much, even
with the same guidance.

**What happens once it is active:**

- Every session (and every turn, via `before_agent_start`) carries the index, so keep it short.
- Entries are plain files that persist across sessions. Store them in a gitignored folder (e.g. `.pi/memory/`, add
  to `.gitignore`) or under `~/.pi/agent/`.
- Subagents started through the subagent extension probably load the same extension and share one memory. This is
  inferred, not verified; Claude Code keeps memory separate per agent.
- Hard stop: no credentials, tokens or PII in memory. Put this into the tool's `promptGuidelines`.

### opencode equivalent

Plugin with `experimental.chat.system.transform` (appends to `output.system`) plus a custom tool from
`@opencode-ai/plugin`, or the no-code route: memory files in the `instructions` globs of `opencode.json`. The hook
is experimental and missing from the docs page (only in the type definitions). The most visible community plugin
is `opencode-supermemory`, which uses a cloud service.

## Open decisions (later)

- **Coding conventions:** decide whether and where they live — `AGENTS.md`, `.claude/rules/` with `paths:`, or a
  skill. Option: a dummy implementation skill (e.g. `.claude/skills/implementation-skill/SKILL.md`) as a template.
  Deferred until the main phases are done.
