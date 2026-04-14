---
name: reflect
description: >
  Analyzes current conversation for user corrections, patterns, and preferences,
  then proposes skill improvements. Use after sessions with corrections or when
  patterns emerge from successful approaches.
disable-model-invocation: true
allowed-tools: Read, Edit, Glob, Grep, AskUserQuestion
---

# Reflect

Analyze the current conversation to find signals for improving **existing** skills.

This skill handles patch-level remediation only — fixing steps, criteria, format,
or behavior of a skill that already exists. If the problem requires a new skill,
a subagent, a hook, MCP integration, or a CLAUDE.md rule, use `/reflect:reflect-architecture`
instead.

## Steps

### 1. Scan conversation for signals

Look for:
- **Corrections** (HIGH) — "Don't do X, do Y instead", user rejecting an approach
- **Approvals** (MEDIUM) — "perfect", "exactly right", confirming a non-obvious pattern works
- **Preferences** — "always use...", "never do...", explicit workflow choices
- **Bugs in skills** — skill gave wrong command, wrong URL, wrong API format

Ignore:
- Teammate/agent messages (not user corrections)
- Quoted text (user referencing, not correcting)
- Generic praise without a specific reusable pattern
- One-off instructions specific only to this task

### 2. Filter to skill-level fixes

For each signal, check:
- Does an existing skill already cover this area?
- Is the fix a change to that skill's steps, criteria, or output format?

If the answer to either is "no", note it as an **architecture signal** and suggest
running `/reflect:reflect-architecture` after this skill completes. Do not attempt
to create new skills, hooks, or CLAUDE.md rules from here.

### 3. Present findings

For each signal that maps to an existing skill, show:
- Which skill it affects (name and file path)
- What the signal is (quote the user)
- Confidence: HIGH / MEDIUM / LOW
- Proposed change to the skill

If nothing found — say so and stop.

### 4. Get approval

Ask the user:
- Apply all
- Review individually
- Skip

### 5. Apply

Edit the target `SKILL.md` files directly with the approved changes.

After editing, remind the user: if an edited skill was already invoked in this
session, it must be re-invoked for the changes to take effect.
