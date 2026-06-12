---
name: review-feature-architecture
description: >
  Review architecture of the current feature only — a plan file after plan mode,
  or a branch diff after implementation. Scope MUST be limited to the active plan,
  PR diff, or current branch diff against base. Uses Balanced Coupling model for
  integration analysis. Never performs broad codebase exploration.
  Uses a GAN-inspired multi-agent loop: a Reviewer agent generates findings,
  a separate Validator agent critiques them, and an Improver agent proposes
  concrete plan edits. This separation prevents self-evaluation bias.
skills:
  - balanced-coupling
allowed-tools: Read, Grep, Glob, Bash, Agent, AskUserQuestion, TaskCreate, TaskUpdate
---

# Review Feature Architecture

Architecture review scoped to the current feature — a plan or an implementation diff.

This skill uses a three-agent pipeline inspired by Anthropic's harness design
for long-running apps. Self-critique is unreliable — agents praising their own
output is the default failure mode. Separating generation from evaluation
produces better results than asking one agent to do both.

## Mode detection

1. User provides a plan file path or there is an active plan → **Mode A: Plan review**
2. User says "review implementation" or there is a branch diff → **Mode B: Implementation review**
3. Ambiguous → ask one question: "Review the plan or the implementation?"

---

## Step 0: Resolve scope and challenge it

### 0a. Determine what to review

In this order:

1. Explicit path / PR / file list from the user
2. Active plan file from conversation context
3. Current PR diff: `gh pr diff` or `git diff origin/$(git rev-parse --abbrev-ref HEAD@{upstream} 2>/dev/null | sed 's|.*/||' || echo main)...HEAD`
4. Branch diff: `git diff main...HEAD` (detect actual base branch first)
5. Last 3 commits if no diff: `git log -3 --stat`

Save the resolved scope (file paths, plan path, or diff range) — all three agents need it.

### 0b. Scope challenge (before spawning any agents)

Before reviewing, answer these questions yourself:

1. **Existing solutions**: Does existing code already solve part of this? Can we capture
   outputs from existing flows instead of building parallel ones?
2. **Minimal change set**: What is the minimum set of changes that achieves the goal?
   Flag anything that could be deferred.
3. **Complexity smell**: If the plan touches 8+ files or introduces 2+ new
   classes/services, challenge whether the same goal can be achieved with fewer parts.
4. **Built-in check**: For each architectural pattern or infrastructure the plan introduces,
   does the runtime/framework have a built-in? If a custom solution exists where a built-in
   works, flag it as a scope reduction.
5. **Distribution check**: If the plan introduces a new artifact (binary, package,
   container), does it include the build/publish pipeline? Code without distribution
   is code nobody uses.

If the complexity smell triggers, recommend scope reduction via AskUserQuestion before
proceeding to the agent pipeline. If not, proceed.

### Scope boundaries

**May read**: changed files or plan sections, directly related tests, one-hop neighbors (caller, callee, interface, DTO/model, config), ADR/design docs referenced by the change, CLAUDE.md for conventions.

**Must NOT read**: entire repository structure, files beyond one hop, unrelated modules "for context."

---

## Step 1: Reviewer agent (Generator)

Spawn a sub-agent that performs the architectural review. This agent produces findings
but does NOT validate them — that is the Validator's job.

The Reviewer agent must receive:
- The resolved scope (plan path or diff command)
- The project's CLAUDE.md path (if exists)
- The balanced-coupling reference (preloaded skill)
- The review dimensions table and evaluation questions below

### Reviewer prompt structure

Tell the Reviewer agent:

> You are an architecture reviewer. Your job is to find real architectural issues
> in the scoped change. You will NOT validate your own findings — a separate
> Validator agent will do that. Be thorough but honest about your confidence level.
>
> **For plan review (Mode A):**
> 1. Read the plan file at [path].
> 2. Summarize feature intent in 3-5 bullets.
> 3. Evaluate against these dimensions:
>    - Module boundaries — respected or broken?
>    - Dependency direction — unstable → stable, or reversed?
>    - Interface shape — deep modules hiding complexity, or shallow wrappers?
>    - Coupling balance — apply Balanced Coupling (strength × distance × volatility)
>    - State/data flow — clear ownership or shared mutable state?
>    - Async/background — retries, idempotency, timeouts addressed?
>    - Failure modes — dependency failures handled? rollback possible?
>    - Test strategy — clear seams for boundary testing?
>    - Blast radius — what breaks if this feature breaks?
>    - Production failure scenario — for each new codepath or integration point,
>      describe one realistic production failure and whether the plan accounts for it
>
> Apply these cognitive lenses while reviewing:
> - **Boring by default** — is the plan using proven technology, or spending an
>   "innovation token" on something novel? Challenge novel choices.
> - **Reversibility** — can this be feature-flagged, canary-deployed, rolled back?
>   Prefer reversible over irreversible.
> - **Essential vs accidental complexity** — is this solving a real problem or one
>   the plan created? (Brooks, No Silver Bullet)
> - **Systems over heroes** — will this work for a tired engineer at 3am, or does
>   it require deep context to operate safely?
>
> **For implementation review (Mode B):**
> 1. Run the diff command, read changed files and one-hop neighbors.
> 2. Build a feature context map: entry points, changed modules, touched contracts,
>    boundaries crossed, test coverage.
> 3. Evaluate: right module/layer? justified abstractions? coupling increased?
>    feature logic fragmented? dependency direction clean? stable test seams?
>    diff leaked into unrelated modules?
> 4. For cross-boundary integrations, apply Balanced Coupling.
> 5. If a plan/PR description exists, compare implementation vs intended scope.
>
> **Output format** — write to a temporary file `/tmp/arch-review-findings.md`:
> ```
> ## Architectural Review Findings
>
> **Feature intent**: [2-3 sentences]
> **Scope reviewed**: [files/sections]
>
> ### Finding 1: [title]
> - **Severity**: must-fix | watch | observation
> - **Confidence**: 1-10 (9-10: verified by reading code; 7-8: high pattern match; 5-6: moderate, may be false positive; 3-4: low, suppress from main report; 1-2: speculation, only report if P0)
> - **What**: [one sentence]
> - **Where**: [file:line or plan section]
> - **Why it matters**: [for this feature specifically]
> - **Evidence**: [what you read that led to this conclusion]
>
> ### Finding 2: ...
> ```
>
> List 3-7 findings maximum. If you find fewer real issues, that is fine —
> do not pad with style nits to fill a quota.

---

## Step 2: Validator agent (Evaluator)

After the Reviewer finishes, spawn a separate Validator agent. This agent has
NOT seen the Reviewer's reasoning process — only its output file. This separation
is the core of the GAN pattern: the Validator has no bias toward the findings.

The Validator agent must receive:
- The findings file path (`/tmp/arch-review-findings.md`)
- The same scope (plan path or diff command) so it can independently verify
- Access to Read, Grep, Glob to check claims against actual code/plan

### Validator prompt structure

Tell the Validator agent:

> You are an architecture review validator. A separate Reviewer agent produced
> findings about a feature's architecture. Your job is to independently verify
> each finding by reading the actual code or plan. You are skeptical by default —
> the Reviewer tends to over-flag issues and under-specify evidence.
>
> For each finding in `/tmp/arch-review-findings.md`:
>
> 1. **Verify the claim.** Read the file/section referenced. Does the issue
>    actually exist, or did the Reviewer misread the code?
> 2. **Check severity.** Is "must-fix" justified, or is this really "watch"?
>    Downgrade generously — must-fix means "will cause production issues or
>    block future changes in the next 1-2 sprints."
> 3. **Check actionability.** Is the finding specific enough to act on?
>    "Coupling is too high" is not actionable. "Module A imports Module B's
>    internal DTO at file:line, creating intrusive coupling in a volatile area"
>    is actionable.
> 4. **Filter false positives.** Remove findings that are:
>    - Style preferences disguised as architecture issues
>    - Repo-wide problems not introduced by this feature
>    - Theoretical risks with no evidence in the current change
>    - Correct patterns flagged due to Reviewer unfamiliarity with the codebase
>
> **Output format** — write to `/tmp/arch-review-validated.md`:
> ```
> ## Validated Findings
>
> **Findings received**: N
> **Findings confirmed**: M
> **False positives removed**: K (with one-line reason each)
>
> ### Confirmed Finding 1: [title]
> - **Severity** (original → validated): [e.g., must-fix → watch]
> - **Verification**: [what you checked, what you found]
> - **Actionable**: yes/no — [if no, what's missing]
>
> ### Confirmed Finding 2: ...
>
> ### Removed Findings
> - [title]: [why removed — e.g., "checked file:line, the dependency direction
>   is actually correct because X implements interface Y"]
> ```

---

## Step 3: Improver agent (Plan Editor)

After the Validator finishes, spawn an Improver agent. This agent reads only
the validated findings and the original plan/diff, then proposes concrete
improvements.

The Improver agent must receive:
- The validated findings file (`/tmp/arch-review-validated.md`)
- The original plan path or diff
- Instruction to produce actionable plan edits, not abstract advice

### Improver prompt structure

Tell the Improver agent:

> You are a plan improvement specialist. You receive validated architecture
> findings and the original plan. Your job is to propose concrete edits —
> not vague recommendations, but specific text changes to the plan file
> or specific code changes for the implementation.
>
> For each confirmed finding with severity must-fix or watch:
>
> 1. **Propose a minimal fix** — the smallest change that resolves the issue.
>    For plans: show the exact section to change and the replacement text.
>    For implementations: show the file, the current code, and the fix.
> 2. **Propose a better alternative** (if one exists) — a cleaner approach
>    that addresses the root cause rather than the symptom.
> 3. **Estimate blast radius of the fix** — what else changes if we apply this?
>
> **Output format** — write to `/tmp/arch-review-improvements.md`:
> ```
> ## Proposed Improvements
>
> ### Improvement 1: [finding title]
> **Severity**: [from validated findings]
>
> #### Minimal fix
> In [file/section], change:
> ```
> [current text/code]
> ```
> To:
> ```
> [proposed text/code]
> ```
>
> #### Better alternative
> [description + concrete changes]
>
> #### Blast radius
> [what else needs to change]
>
> ### Improvement 2: ...
>
> ## Summary
> - Must-fix improvements: N
> - Watch improvements: M
> - Estimated total changes: [files/sections affected]
> ```

---

## Step 4: Present and apply

After all three agents complete:

1. Read all three output files.
2. Present a unified summary to the user:
   - Overall verdict: healthy / watch / must-fix
   - Confirmed findings (with Validator's verification notes)
   - Proposed improvements (with Improver's concrete edits)
   - What the Validator removed and why (transparency)
3. **Auto-apply all confirmed improvements** (must-fix and watch) from the Improver's output
   directly to the plan or source files. Do NOT ask for permission — apply immediately.
4. After applying, re-read the modified plan/files and confirm the changes are coherent.
5. Report what was applied (file, change summary) so the user can review the diff.

---

## Agent orchestration rules

- **Never let the Reviewer validate its own findings.** The entire point of the
  separation is that self-evaluation is unreliable.
- **File-based communication only.** Agents write to `/tmp/arch-review-*.md` files.
  The orchestrator reads these files between stages. No agent sees another agent's
  reasoning process — only its output.
- **Sequential, not parallel.** Validator needs Reviewer's output. Improver needs
  Validator's output. Run them in sequence.
- **Clean up.** After the user makes their decision, remove the temp files.

---

## Anti-patterns

- Proposing repo-wide refactors from a local observation
- Flagging style issues as architectural problems
- Recommending "decouple everything" — decomposition increases distance
- Treating commit frequency as volatility — evaluate from business domain
- Listing 20 observations instead of 3-5 that matter
- Letting the Reviewer also validate (self-evaluation bias)
- Proposing abstract improvements ("consider using a facade") instead of concrete edits
