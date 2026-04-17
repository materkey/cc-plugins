# cc-plugins

Plugins for [Claude Code](https://claude.ai/code) — skills, hooks, and commands, organized as a marketplace of independent plugins.

## Install

Add the marketplace, then install the plugins you want:

    /plugin marketplace add materkey/cc-plugins

    /plugin install reflect@materkey-cc-plugins
    /plugin install go@materkey-cc-plugins
    /plugin install skill-workshop@materkey-cc-plugins

Test a plugin locally:

    claude --plugin-dir plugins/reflect
    claude --plugin-dir plugins/go
    claude --plugin-dir plugins/skill-workshop

<details>
<summary>Manual install (alternative)</summary>

Copy the files you want to your Claude Code config directory manually.

**reflect** — skills (reflect + reflect-architecture):
```bash
cp -r plugins/reflect/skills/reflect ~/.claude/skills/
cp -r plugins/reflect/skills/reflect-architecture ~/.claude/skills/
```

**go** — skill (go):
```bash
cp -r plugins/go/skills/go ~/.claude/skills/
```

**skill-workshop** — skill + agent:
```bash
cp -r plugins/skill-workshop/skills/skill-workshop ~/.claude/skills/
cp plugins/skill-workshop/agents/session-analyzer.md ~/.claude/agents/
```

Restart Claude Code for changes to take effect.

</details>

## Plugins

| Plugin | Description |
|--------|-------------|
| [reflect](#reflect) | Session reflection tools — patch existing skills and design durable architectural changes |
| [go](#go) | End-of-task finisher — verify with e2e tests, simplify, and open a PR |
| [skill-workshop](#skill-workshop) | Mine Claude Code session history for repeating patterns and propose new skills |

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

### go

One skill for wrapping up a task: runs end-to-end verification, invokes `/simplify` to clean up the code, then stages, commits, pushes, and opens a Pull Request.

| Component | Trigger | Description |
|-----------|---------|-------------|
| skill | `/go:go` | Run end-to-end tests, execute `/simplify`, then create a PR |

**go** — intended as the final command after almost every significant task. Verifies backend APIs via terminal, frontend via browser tools, and CLI tools directly; fixes any issues found; then runs `/simplify` and opens a PR using `gh` or Claude Code's built-in git tools.

### skill-workshop

Republish of [grayodesa/skill-workshop](https://github.com/grayodesa/skill-workshop) packaged as a plugin (skill + bundled agent). Original author retains MIT license.

| Component | Trigger | Description |
|-----------|---------|-------------|
| skill | `/skill-workshop:skill-workshop` | Orchestrator — delegates extraction, presents ranked candidates, generates SKILL.md drafts |
| agent | `session-analyzer` | Haiku-based subagent — parses JSONL session files, scores pattern candidates, writes results to `/tmp/skill-workshop-results.json` |

Mines `~/.claude/projects/<encoded-path>/*.jsonl` for three signal types: repeated explanations, tool-chain workflows, and error→workaround patterns. Packaging the agent alongside the skill is important — `npx skills add` installs the skill but not the agent, leaving the orchestrator without its worker. Installing this plugin delivers both.

## License

MIT
