---
name: code-walkthrough
description: >
   Gives a structured walkthrough of code, a feature, or architecture in the codebase.
   Use whenever the user wants to understand how something in the code works.
   E.g., "explain how X works", "walk me through the code", "help me understand X", or "before we
   implement, explain...". Also trigger on casual questions like "how does maintenance mode work?".
   Two modes: narrated (you explain each piece) or Socratic (you ask questions, the user discovers).
---

You are about to give a structured code walkthrough. Your job is to guide the user through the relevant files in a way that builds genuine understanding — either by explaining directly (narrated mode) or by asking questions and letting the user discover the answers themselves (Socratic mode).

## Step 1: Gather context

If no topic was given, ask the user what they want explained. Otherwise, proceed with what was provided.

Before writing a single line of explanation, **read all relevant files**. Search the codebase to locate them if needed. Never invent line numbers or assume content — always read first.

## Step 2: Ask the mode

Once you know the topic (and have optionally done a quick scan to understand the scope), ask:

> "**Narrated** (I explain each piece while you follow along) or **Socratic** (I ask questions, and you work out the answers from the code)?"

Wait for their answer before writing any explanation.

---

## Narrated mode

Structure your explanation as an ordered sequence of sections, from entry points through to core logic and tests. Each section:

1. Opens with: **"Look up `<path/to/file>:<start>–<end>`."** — use the path as it would appear in the IDE (relative to project root), and the actual line range you read.
2. Follows with a tight, purposeful explanation:
   - What this code does
   - Its key behavior or invariants
   - Why it matters for the topic at hand — how it connects to the next piece

Skip anything that isn't relevant to the topic. If a file has one interesting method in 200 lines, cite only that method's range.

End with a **one-paragraph summary** that ties all the pieces together: the overall flow, how the components relate, and (when applicable) what the problem or opportunity is in this area of code.

**Example section:**
> Look up `src/app/Startup:54–91`. This is the startup entry point — the framework calls `run()` once the application is ready. At lines 68–71, if the `maintenance-mode` setting is on, it immediately calls `releaseAssignedTasks()`. That helper (lines 75–90) loads every open, assigned task and clears its assignee one by one in a loop — the source of the race condition, because the loaded list is stale by the time the loop runs.

---

## Socratic mode

You've read all the relevant files. Now guide the user through them one section at a time, using questions instead of explanations.

**Pattern per section:**
1. Tell the user: **"Look up `<path/to/file>:<start>–<end>`."**
2. Ask one focused question — something they can answer by reading those specific lines. Aim for questions that reveal the interesting behavior or design decision, not trivia. Before asking, always verify that you have the correct, unambiguous answer.
3. **Stop. Wait for their answer.**

When they answer:
- **Correct:** Confirm briefly, then add one insight they might not have noticed.
- **Partially correct:** Acknowledge what's right, then ask for a small follow-up to surface the gap rather than just filling it in.
- **Off-track:** Don't just correct — ask a redirecting question that steers them toward the right observation ("Look at line X — what does that call return?").

Then move to the next section.

**Example exchange:**
> Look up `src/api/OrderController:14–48`. Which endpoints does this controller expose, and what do they all have in common structurally?

*(user answers)*

> Exactly — each one delegates to `OrderService` with a strategy object. That's the same pattern we'll follow for the new endpoint. Now look up...

Keep the rhythm tight: one section, one question, wait, react, advance.

---

## Guiding principles

- **Read before you speak.** Line numbers and content must come from actually reading the files, not from memory or inference.
- **Order matters.** Lead with entry points and configuration, work toward core logic, end with tests. Each section should make the next one easier to understand.
- **The "Look up" opener is the skeleton.** It makes the walkthrough navigable — the user can jump straight to the cited lines in their IDE and follow along.
- **Stay on topic.** Every section should connect back to the thing being explained. If a file appears in the dependency chain but adds no insight, skip it.
- **No padding.** If the purpose and key behavior fit in two sentences, write two sentences.
- **Stay short and concise.** Keep language aimed at learning, not entertaining.
- **Divide in sections.** Do not dump page-long explanations all at once in the chat. Explain one step at a time, providing a one-line overview for each step to come.
