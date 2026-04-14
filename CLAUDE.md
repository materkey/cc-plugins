# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Editing Principles

Do NOT make changes beyond what was requested. Avoid removing comments, moving variables, inlining helpers, deleting blank lines, or adding unrequested config sections. When in doubt, make the minimal change.

## Repository Purpose

Plugins for Claude Code — skills, hooks, and commands, organized as a marketplace of independent plugins.

## Key Rules

- **README.md must be kept up to date** — whenever a new component, script, or configuration is added, update README.md with a description of what it does and how to use it.
- Content is MIT-licensed.
- **No personal configuration** — scripts and configs must be generic and not contain hardcoded personal paths, editor preferences, or machine-specific settings. Use environment variables for user-specific values.
- **Self-contained documentation** — do not reference external custom skills, actions, or configurations that exist only in a user's personal Claude Code setup. All documentation must refer only to what exists in this repository.

## Conventions

- Hook scripts use `${CLAUDE_PLUGIN_ROOT}` for path resolution when running as a plugin.
- **Versioning** — each plugin has its own `version` in `plugins/<name>/.claude-plugin/plugin.json`. Bump independently per plugin. Use semver: patch for bug fixes, minor for new components, major for breaking changes.
- **Cross-references** — when skills reference other skills within the same plugin, use the plugin name prefix (e.g., `/reflect:reflect-architecture`). When referencing skills in other plugins, use that plugin's name.

## Structure

- `.claude-plugin/marketplace.json` — marketplace catalog listing all plugins
- `plugins/` — each subdirectory is an independent plugin:
  - `plugins/reflect/` — session reflection tools (reflect + reflect-architecture)
- Each plugin has its own `.claude-plugin/plugin.json`, and standard subdirectories (`skills/`, `commands/`, `hooks/`) as needed.

## Local Plugin Development

- **Testing locally** — use `claude --plugin-dir plugins/<name>` to load a local plugin without publishing. Use `/reload-plugins` inside a session to pick up file changes without restarting.
