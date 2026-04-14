# cc-plugins

Plugins for [Claude Code](https://claude.ai/code) — skills, hooks, and commands, organized as a marketplace of independent plugins.

## Install

Add the marketplace, then install the plugins you want:

    /plugin marketplace add materkey/cc-plugins

    /plugin install reflect@materkey-cc-plugins

Test a plugin locally:

    claude --plugin-dir plugins/reflect

<details>
<summary>Manual install (alternative)</summary>

Copy the files you want to your Claude Code config directory manually.

**reflect** — skills (reflect + reflect-architecture):
```bash
cp -r plugins/reflect/skills/reflect ~/.claude/skills/
cp -r plugins/reflect/skills/reflect-architecture ~/.claude/skills/
```

Restart Claude Code for changes to take effect.

</details>

## Plugins

| Plugin | Description |
|--------|-------------|
| [reflect](#reflect) | Session reflection tools — patch existing skills and design durable architectural changes |

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

## License

MIT
