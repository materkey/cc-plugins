# cc-plugins

Plugins for [Claude Code](https://claude.ai/code) — skills, hooks, and commands, organized as a marketplace of independent plugins.

## Install

Add the marketplace, then install the plugins you want:

    /plugin marketplace add materkey/cc-plugins

    /plugin install reflect@materkey-cc-plugins
    /plugin install skill-workshop@materkey-cc-plugins
    /plugin install review-feature-architecture@materkey-cc-plugins
    /plugin install ralphex-auto@materkey-cc-plugins
    /plugin install complexity-optimizer@materkey-cc-plugins

Test a plugin locally:

    claude --plugin-dir plugins/reflect
    claude --plugin-dir plugins/skill-workshop
    claude --plugin-dir plugins/review-feature-architecture
    claude --plugin-dir plugins/ralphex-auto
    claude --plugin-dir plugins/complexity-optimizer

<details>
<summary>Manual install (alternative)</summary>

Copy the files you want to your Claude Code config directory manually.

**reflect** — skills (reflect + reflect-architecture):
```bash
cp -r plugins/reflect/skills/reflect ~/.claude/skills/
cp -r plugins/reflect/skills/reflect-architecture ~/.claude/skills/
```

**skill-workshop** — skill + agent:
```bash
cp -r plugins/skill-workshop/skills/skill-workshop ~/.claude/skills/
cp plugins/skill-workshop/agents/session-analyzer.md ~/.claude/agents/
```

**review-feature-architecture** — skills (review-feature-architecture + balanced-coupling):
```bash
cp -r plugins/review-feature-architecture/skills/review-feature-architecture ~/.claude/skills/
cp -r plugins/review-feature-architecture/skills/balanced-coupling ~/.claude/skills/
```

**ralphex-auto** — skill:
```bash
cp -r plugins/ralphex-auto/skills/ralphex-auto ~/.claude/skills/
```

**complexity-optimizer** — skill (with bundled scanner script and references):
```bash
cp -r plugins/complexity-optimizer/skills/complexity-optimizer ~/.claude/skills/
```

Restart Claude Code for changes to take effect.

</details>

## Plugins

| Plugin | Description |
|--------|-------------|
| [reflect](#reflect) | Session reflection tools — patch existing skills and design durable architectural changes |
| [skill-workshop](#skill-workshop) | Mine Claude Code session history for repeating patterns and propose new skills |
| [review-feature-architecture](#review-feature-architecture) | Feature-scoped architecture review with a Reviewer/Validator/Improver agent loop and the Balanced Coupling model |
| [ralphex-auto](#ralphex-auto) | One-shot ralphex: continue or create a plan from conversation context, then launch autonomous execution |
| [complexity-optimizer](#complexity-optimizer) | Find algorithmic complexity hotspots and apply safe, behavior-preserving optimizations |

### reflect

Two complementary skills for learning from session experience. `reflect` handles patch-level fixes to existing skills. `reflect-architecture` steps back and decides what *type* of change is needed.

| Component | Trigger | Description |
|-----------|---------|-------------|
| skill | `/reflect:reflect` | Patch existing skills based on user corrections, approvals, and preferences |
| skill | `/reflect:reflect-architecture` | Determine the smallest durable change: CLAUDE.md rule, new skill, subagent, hook, MCP, or plugin |

**reflect** — scans the current conversation for corrections, confirmed patterns, preference signals, and skill bugs. Maps each signal to an existing skill and proposes targeted edits. Signals that don't map to any existing skill are flagged as architecture-level and deferred to `reflect-architecture`.

- Filters out agent messages, quoted text, and one-off instructions
- Edits `SKILL.md` files directly after user approval
- Reminds to re-invoke edited skills in the current session

**reflect-architecture** — analyzes the conversation to determine *what kind* of durable change would prevent the same problem from recurring. Classifies each finding into one of 11 target types:

| # | Target | When |
|---|--------|------|
| 1 | CLAUDE.md rule | Should apply in every conversation |
| 2 | Existing skill patch | Skill exists, wrong steps/criteria/format |
| 3 | New skill | Repeatable workflow with no existing home |
| 4 | Split skill | One skill covers too many concerns |
| 5 | Merge skills | Multiple skills overlap |
| 6 | New subagent | Task floods context or needs specialist worker |
| 7 | Orchestrator skill | Skill coordinating multiple subagents |
| 8 | Hook | Step must always execute deterministically |
| 9 | MCP integration | Data or actions live outside Claude Code |
| 10 | Plugin packaging | Multi-component solution spanning repos |
| 11 | No change needed | One-off signal |

After classification, presents findings with confidence, proposed changes, and rationale for the chosen target over alternatives. Supports apply-all, scaffold-only, review-individually, and skip modes.

Both skills run inline (no `context: fork`) to preserve access to current conversation history.

### skill-workshop

Republish of [grayodesa/skill-workshop](https://github.com/grayodesa/skill-workshop) packaged as a plugin (skill + bundled agent). Original author retains MIT license.

| Component | Trigger | Description |
|-----------|---------|-------------|
| skill | `/skill-workshop:skill-workshop` | Orchestrator — delegates extraction, presents ranked candidates, generates SKILL.md drafts |
| agent | `session-analyzer` | Haiku-based subagent — parses JSONL session files, scores pattern candidates, writes results to `/tmp/skill-workshop-results.json` |

Mines `~/.claude/projects/<encoded-path>/*.jsonl` for three signal types: repeated explanations, tool-chain workflows, and error→workaround patterns. Packaging the agent alongside the skill is important — `npx skills add` installs the skill but not the agent, leaving the orchestrator without its worker. Installing this plugin delivers both.

### review-feature-architecture

Architecture review scoped strictly to the current feature — a plan file after plan mode, or a branch/PR diff after implementation. Never explores the whole repository.

| Component | Trigger | Description |
|-----------|---------|-------------|
| skill | `/review-feature-architecture:review-feature-architecture` | Three-agent review pipeline over the active plan or diff |
| skill | `balanced-coupling` (reference, not user-invocable) | The Balanced Coupling model (Vlad Khononov) — integration strength × distance × volatility |

The review uses a GAN-inspired three-agent loop — self-critique is unreliable, so generation and evaluation are separated:

1. **Reviewer** — produces 3–7 findings across dimensions (module boundaries, dependency direction, coupling balance, failure modes, blast radius), each with severity and confidence.
2. **Validator** — independently re-verifies every finding against the actual code/plan, downgrades severities, removes false positives.
3. **Improver** — turns confirmed findings into concrete plan/code edits (minimal fix + better alternative + blast radius), which are then auto-applied.

Cross-boundary integrations are analyzed with the bundled **balanced-coupling** reference skill: modularity = strength XOR distance, with volatility as the pragmatism dimension. A scope-challenge step before the pipeline catches over-engineering early (built-in alternatives, minimal change set, complexity smells).

The bundled `balanced-coupling` skill is taken unchanged from [vladikk/modularity](https://github.com/vladikk/modularity) by Vlad Khononov and is licensed [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) (see `plugins/review-feature-architecture/LICENSE-balanced-coupling`) — it is the one exception to this repository's MIT license. For commercial use of that skill, contact the author (see the modularity repo). Vlad's plugin also offers complementary skills not bundled here: a whole-codebase modularity `review` and a greenfield `design` skill — install `vladikk/modularity` alongside if you need those stages.

### ralphex-auto

Zero-question plan + execute on top of [umputun/ralphex](https://github.com/umputun/ralphex).

| Component | Trigger | Description |
|-----------|---------|-------------|
| skill | `/ralphex-auto:ralphex-auto` ("ralphex auto", "ralphex go") | Continue an active plan or create one from conversation context, then launch ralphex in the background |

Infers everything from context instead of asking: picks an existing plan under `docs/plans/` (or creates one from the conversation), chooses native vs SBX (Docker Sandboxes) launch mode based on risk, starts `ralphex --max-iterations 25` in the background, and reports the progress file to tail. Ralphex itself runs the full loop: task implementation + Claude review + Codex review + final review.

Requires the `ralphex` binary (installed automatically via `go install`); SBX mode additionally requires the `sbx` CLI.

### complexity-optimizer

Adapted from [Kappaemme-git/codex-complexity-optimizer](https://github.com/Kappaemme-git/codex-complexity-optimizer) (MIT). An example of a domain-specific review skill to run after implementation — analogous to pairing language-specific packs like [rust-skills](https://github.com/actionbook/rust-skills) for Rust code.

| Component | Trigger | Description |
|-----------|---------|-------------|
| skill | `/complexity-optimizer:complexity-optimizer` | Scan for complexity hotspots, then report or apply safe optimizations |
| script | `scripts/analyze_complexity.py` | Multi-language static scanner (Python, JS/TS, Java, Go, C/C++, C#, Ruby, PHP, Swift) used as a lead generator |

Report-vs-edit mode is inferred from the request wording ("analyze/audit" → report only; "fix/optimize" → report + edits). Optimizations are conservative: prove current behavior with tests first, prefer maps/sets, batching, memoization over rewrites, verify with the project's own test/lint/build commands. Includes an optimization playbook and a report template under `references/`.

## Development: pre-commit hooks

The repository ships native git config-based hooks (git >= 2.54, no lefthook or other hook runner needed). Defined in `hooks.gitconfig`:

| Hook | Script | What it checks |
|------|--------|----------------|
| validate-skills | `ci/validate-skills.sh` | Runs [skill-validator](https://github.com/agent-ecosystem/skill-validator) (`validate structure`) on every skill touched by staged files; fails the commit on validation errors |
| check-marketplace | `ci/check-marketplace.sh` | `.claude-plugin/marketplace.json` is in sync with `plugins/`: every plugin dir is listed, every entry points to an existing plugin, no orphan skill dirs without `plugin.json` |

Enable once per clone:

```bash
git config --local include.path ../hooks.gitconfig
```

Verify with `git hook list pre-commit` — it should print both hooks. Both scripts can also be run directly (e.g. in CI); `ci/validate-skills.sh` validates skills containing the files passed as arguments, or staged files when called with none.

Dependencies: `jq` and `python3`; `skill-validator` in `PATH` (otherwise bootstrapped via `go install` into the git-ignored `ci/bin/`).

## License

MIT, with one exception: the `balanced-coupling` skill in `plugins/review-feature-architecture/skills/balanced-coupling/` is from [vladikk/modularity](https://github.com/vladikk/modularity) © Vlad Khononov and is licensed under [CC BY-NC-SA 4.0](https://creativecommons.org/licenses/by-nc-sa/4.0/) (see `plugins/review-feature-architecture/LICENSE-balanced-coupling`).
