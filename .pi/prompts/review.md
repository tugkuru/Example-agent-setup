---
description: Review the current diff with the code-reviewer subagent
argument-hint: "[focus]"
---

Use the `subagent` tool with `agent: "code-reviewer"` and `agentScope: "both"` to review the current changes. If a
focus area is given, pass it on so the reviewer checks it first.

Focus: $ARGUMENTS

Relay the reviewer's result verbatim.
