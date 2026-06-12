---
name: ralphex-auto
description: "One-shot ralphex: continue an active plan or create one from context, then launch execution without questions. Use when user says 'ralphex auto', 'ralphex go', 'автоматически запусти ralphex', or wants plan+execution in one step."
---

# ralphex-auto — Zero-question Plan + Execute

Continues an obvious existing ralphex plan, or creates a new plan from current conversation context, and launches execution immediately.
No interactive questions — infers everything from context.

## Step 0: Update ralphex

Always run before anything else:
```bash
GOPROXY=https://proxy.golang.org,direct go install github.com/umputun/ralphex/cmd/ralphex@latest
```

## Step 1: Gather Context Silently

Use Explore agent to understand:
- Current git branch and recent commits
- What the user has been working on in this conversation
- Files involved, errors encountered, patterns found

Do NOT ask questions. Infer intent from conversation history.

## Step 2: Choose or Create Plan

Prefer continuing an existing plan when the user asks to continue/resume/dodelat a plan, when the working tree is already dirty from an interrupted ralphex task, or when there is exactly one active non-completed plan under `docs/plans/`.

To choose an existing plan:
- List active plans: `find docs/plans -maxdepth 1 -type f -name '*.md' | sort`
- Prefer the plan named by the user
- Otherwise prefer the plan referenced by the newest `.ralphex/progress/progress-*.txt`
- Otherwise prefer the newest modified active plan

Set:
```bash
PLAN_FILE="docs/plans/<existing-plan>.md"
PLAN_CREATED=0
```

Do not create a new plan when an existing active plan is clearly being continued.

If no existing plan is clearly intended, create one.

Generate plan title from context (kebab-case, max 5 words).
Create `docs/plans/YYYY-MM-DD-<title>.md` with this structure:

```markdown
# <Title inferred from context>

## Overview
- <1-2 sentences: what and why>

## Context (from discovery)
- <files, patterns, dependencies found>

## Development Approach
- **Testing approach**: Regular (unless TDD is obvious from context)
- Complete each task fully before moving to the next

## Progress Tracking
- Mark completed items with `[x]` immediately when done
- Add newly discovered tasks with ➕ prefix
- Document issues/blockers with ⚠️ prefix

## Implementation Steps

### Task 1: <specific name>
- [ ] <specific action with file path>
- [ ] <verify step>

### Task N: Commit and push
- [ ] Commit changes
- [ ] Push to current branch

## Post-Completion
- <what to check after>
```

Keep tasks minimal — YAGNI. No test tasks unless code logic changes.

Set:
```bash
PLAN_FILE="docs/plans/YYYY-MM-DD-<title>.md"
PLAN_CREATED=1
```

## Step 3: Choose Launch Mode

Use native mode by default. Use SBX mode when any of these are true:
- User explicitly asked for `sbx`, Docker Sandboxes, sandboxed ralphex, or host protection
- Context suggests high-risk commands: Rust/C/C++/Go builds, large test suites, browsers/e2e, native Node modules, Docker builds

Never ask. Decide from context and availability. Once SBX mode is selected, do not silently downgrade to native mode.

### Native mode

Use when SBX is not requested and the task is low risk.

```bash
ralphex --max-iterations 25 "$PLAN_FILE"
```

Run with `run_in_background: true`.

Determine progress file: `.ralphex/progress/progress-YYYY-MM-DD-<title>.txt`

### SBX mode

SBX is host-protection mode for runaway builds/tests. It is a VM-style external guard, not a replacement for ralphex's own watchdogs.

Preflight:
```bash
command -v sbx >/dev/null 2>&1 && sbx ls >/dev/null 2>&1
```

If preflight fails in SBX mode, stop and report `sbx unavailable`; do not fall back to native mode. SBX mode is selected for host protection, so native fallback would remove the protection.

Use explicit limits. Never rely on SBX defaults:
```bash
SANDBOX="ralphex-YYYY-MM-DD-<title>"
MEMORY="${RALPHEX_SBX_MEMORY:-8g}"
CPUS="${RALPHEX_SBX_CPUS:-4}"
WORKSPACE="${PWD}"
```

Use a direct mount of the current repo by default so the plan file and progress log stay visible on the host. Do not use `--branch auto` unless the user explicitly requested SBX-managed branch isolation; ralphex already handles its own branch/worktree behavior. Inside the sandbox, use `$WORKSPACE_DIR` as the repo path; the shell template starts in `/home/agent/workspace`, which can be empty.

Create the sandbox if needed:
```bash
sbx create --name "$SANDBOX" --memory "$MEMORY" --cpus "$CPUS" shell "$WORKSPACE"
```

Bootstrap only the minimum needed tool/auth state. Do not mount the whole `~/.claude` or `~/.codex` by default.

```bash
sbx exec "$SANDBOX" -- sh -lc 'mkdir -p ~/.claude ~/.codex && chmod 700 ~/.claude ~/.codex'

# Claude Code auth on macOS is commonly in Keychain. Prefer the current user account
# because older duplicate "Claude Code-credentials" entries may exist.
if [ "${RALPHEX_SBX_IMPORT_HOST_AUTH:-1}" = "1" ] && command -v security >/dev/null 2>&1; then
  TMP_CLAUDE_CREDS="$(mktemp)"
  if security find-generic-password -s "Claude Code-credentials" -a "$USER" -w > "$TMP_CLAUDE_CREDS" 2>/dev/null \
    || security find-generic-password -s "Claude Code-credentials" -w > "$TMP_CLAUDE_CREDS" 2>/dev/null; then
    chmod 600 "$TMP_CLAUDE_CREDS"
    sbx cp "$TMP_CLAUDE_CREDS" "$SANDBOX:/home/agent/.claude/.credentials.json"
  fi
  rm -f "$TMP_CLAUDE_CREDS"
fi

if [ "${RALPHEX_SBX_IMPORT_HOST_AUTH:-1}" = "1" ] && [ -f "$HOME/.codex/auth.json" ]; then
  sbx cp "$HOME/.codex/auth.json" "$SANDBOX:/home/agent/.codex/auth.json"
  [ -f "$HOME/.codex/config.toml" ] && sbx cp "$HOME/.codex/config.toml" "$SANDBOX:/home/agent/.codex/config.toml"
fi

sbx exec "$SANDBOX" -- sh -lc '
if command -v sudo >/dev/null 2>&1; then
  sudo chown -R agent:agent ~/.claude ~/.codex 2>/dev/null || true
  sudo chmod 600 ~/.claude/.credentials.json ~/.codex/auth.json ~/.codex/config.toml 2>/dev/null || true
else
  chown -R agent:agent ~/.claude ~/.codex 2>/dev/null || true
  chmod 600 ~/.claude/.credentials.json ~/.codex/auth.json ~/.codex/config.toml 2>/dev/null || true
fi
'
```

Launch ralphex inside the sandbox. Keep `ralphex` in the foreground inside `sbx exec`; if background execution is needed, background the host `sbx exec` command via the agent runtime, not `ralphex ... &` inside the sandbox.

```bash
sbx exec "$SANDBOX" -- sh -lc '
set -e
cd "$WORKSPACE_DIR"
export PATH="$PATH:$(go env GOPATH 2>/dev/null)/bin"
[ "${ANTHROPIC_API_KEY:-}" = "proxy-managed" ] && unset ANTHROPIC_API_KEY
[ "${OPENAI_API_KEY:-}" = "proxy-managed" ] && unset OPENAI_API_KEY
if ! command -v ralphex >/dev/null 2>&1; then
  if command -v go >/dev/null 2>&1; then
    GOPROXY=https://proxy.golang.org,direct go install github.com/umputun/ralphex/cmd/ralphex@latest
  else
    echo "ralphex not found in sandbox and Go is unavailable; use native mode or an SBX template with ralphex installed" >&2
    exit 127
  fi
fi
if ! command -v claude >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  npm install -g @anthropic-ai/claude-code@latest
fi
if ! command -v codex >/dev/null 2>&1 && command -v npm >/dev/null 2>&1; then
  npm install -g @openai/codex@latest
fi
if [ -f Cargo.toml ] && ! command -v cargo >/dev/null 2>&1; then
  if command -v rustup >/dev/null 2>&1; then
    rustup default stable
  elif command -v curl >/dev/null 2>&1; then
    curl --proto =https --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
    . "$HOME/.cargo/env"
  else
    echo "Cargo.toml found but cargo/rustup/curl are unavailable; use an SBX template with Rust installed" >&2
    exit 127
  fi
fi
ralphex --max-iterations 25 "$1"
' sh "$PLAN_FILE"
```

The plain SBX shell template is intentionally minimal. For Rust repos, install minimal stable Rust automatically when `Cargo.toml` exists and `cargo` is missing; do not ask and do not fall back to native. It may still lack project-specific tools such as `gcc`, Android SDK, or `golangci-lint`; report those as sandbox environment gaps or use an explicit template when the plan requires them.

Run the `sbx exec ...` command with `run_in_background: true` only at the host command level. Do not use `nohup ralphex ... &` inside `sbx exec`; that process can be terminated when the `sbx exec` session exits.

Determine progress file the same way: `.ralphex/progress/progress-YYYY-MM-DD-<title>.txt`

After completion, the sandbox may be stopped or removed manually:
```bash
sbx exec "$SANDBOX" -- sh -lc '
if command -v sudo >/dev/null 2>&1; then
  sudo rm -f ~/.claude/.credentials.json ~/.codex/auth.json ~/.codex/config.toml ~/.claude.json
else
  rm -f ~/.claude/.credentials.json ~/.codex/auth.json ~/.codex/config.toml ~/.claude.json
fi
' || true
sbx stop "$SANDBOX"
sbx rm "$SANDBOX"
```

## Step 4: Confirm Launch

Wait a few seconds, then read progress file to confirm start.

Report:
```
Plan: docs/plans/<file>.md (created|continued)
ralphex started (mode: native|sbx, task ID: <id>)
Progress: .ralphex/progress/<file>.txt

tail -f .ralphex/progress/<file>.txt
```

STOP. Do not monitor automatically.

## Defaults (non-negotiable)
- Mode: Full (task + claude review + codex + final review)
- Max iterations: 25
- No questions asked
- Plan title auto-generated from context
- Testing approach: Regular
- SBX limits when used: memory 8g, cpus 4 unless `RALPHEX_SBX_MEMORY`/`RALPHEX_SBX_CPUS` override
