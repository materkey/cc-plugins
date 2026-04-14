---
name: reflect-architecture
description: >
  Analyze the current conversation and determine the smallest durable change to
  Claude Code setup: update CLAUDE.md, patch an existing skill, create a new skill,
  split or merge skills, introduce a subagent, add hooks, connect MCP, or scaffold
  a plugin. Use after a failed workflow, repeated user correction, or when a session
  exposes a missing capability.
disable-model-invocation: true
argument-hint: "[optional focus, e.g. deploy workflow or session issue]"
allowed-tools: Read, Write, Edit, Glob, Grep, Bash, AskUserQuestion
---

# Reflect Architecture

Analyze the current conversation and any directly referenced artifacts to find
the smallest durable change that would prevent the same failure from recurring.

## 1. Collect signals

Look for:
- User corrections
- Rejected approaches
- Repeated re-explanations
- Moments where output volume or context handling was the real problem
- Places where a skill existed but was the wrong abstraction
- Places where an action should have been deterministic
- Places where external data or actions were missing
- Repeated workflows that suggest a missing reusable capability

Ignore:
- One-off instructions specific only to this task
- Quoted text that is not a correction
- Generic praise without a reusable pattern

## 2. Classify the root cause

For each finding, choose exactly one primary target:

| # | Target | When to choose |
|---|--------|----------------|
| 1 | **CLAUDE.md rule** | Rule should apply in every conversation |
| 2 | **Existing skill patch** | Skill exists but has wrong steps, criteria, or format |
| 3 | **New skill** | Repeatable user-invoked workflow with no existing home |
| 4 | **Split skill** | One skill covers too many concerns |
| 5 | **Merge skills** | Multiple skills overlap significantly |
| 6 | **New subagent** | Task floods context, needs a specialist worker, or should return only summary |
| 7 | **Orchestrator skill** | Skill that coordinates one or more subagents |
| 8 | **Hook** | Step must always execute without model discretion |
| 9 | **MCP integration** | Required data or actions live outside Claude Code |
| 10 | **Plugin packaging** | Solution spans skills, agents, hooks, or MCP across repositories |
| 11 | **No durable change needed** | Signal is one-off or already addressed |

### Decision heuristics

- Do not recommend a new skill when a smaller edit to an existing skill or CLAUDE.md would solve it.
- A new skill is justified only when you can name the `/invoke` trigger and describe
  at least 3 distinct future scenarios where it would fire.
- Prefer hooks over skills for steps that must always happen (deterministic, no judgment needed).
- Prefer subagents over inline skills for work that reads many files, generates
  verbose intermediate output, or requires isolated context.
- `context: fork` is good for research (code, logs, PRs) but bad for reflecting
  on the current conversation — forked skills lose conversation history.

## 3. Present findings

For each finding, show:
- **Signal** — what happened (quote the user or describe the moment)
- **Why it matters** — what breaks if this is not addressed
- **Confidence**: HIGH / MEDIUM / LOW
- **Best target** — one of the 11 types above
- **Exact files** — to create or edit
- **Proposed change** — concrete content or structure
- **Why not the nearest alternative** — why the next-closest target type is worse

## 4. Approval

Ask the user whether to:
- Apply all
- Scaffold only (create files but leave them as drafts)
- Review individually
- Skip

## 5. Apply after approval

| Target | Action |
|--------|--------|
| CLAUDE.md rule | Edit the narrowest-scope CLAUDE.md (local > user > global) |
| Existing skill patch | Edit the skill's `SKILL.md` |
| New skill | Create `skills/<name>/SKILL.md` (or plugin path if inside a plugin) |
| Split skill | Create new skills, then edit the original to narrow its scope |
| Merge skills | Consolidate into one skill, remove the other |
| New subagent | Create `.claude/agents/<name>.md` |
| Orchestrator skill | Create skill that uses Agent tool to dispatch subagents |
| Hook | Update the narrowest safe `settings.json` scope |
| MCP integration | Scaffold config and usage notes; do not assume credentials |
| Plugin packaging | Scaffold structure only unless explicitly asked to finish |

## 6. Safety and scope

- Do not assume the fix belongs to the skill that happened to be active when
  the failure occurred. The root cause may be elsewhere.
- Prefer one durable architectural change over many micro-edits.
- If a skill used earlier in this session is edited, explicitly tell the user
  to re-invoke it — changes do not retroactively apply to already-loaded skills.
- This skill runs inline (no `context: fork`) to preserve access to conversation
  history. If you need to analyze saved logs or external artifacts instead,
  consider a forked variant.
