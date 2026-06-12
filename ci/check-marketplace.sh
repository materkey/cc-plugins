#!/usr/bin/env bash
set -euo pipefail
shopt -s nullglob

# Validate that .claude-plugin/marketplace.json is in sync with actual plugin
# directories. A plugin directory is any plugins/<name> dir containing
# .claude-plugin/plugin.json.
#
# Checks:
#   1. Every plugin dir is listed in .claude-plugin/marketplace.json
#   2. Every marketplace entry points to an existing plugin dir
#   3. No orphan skill dirs: every plugins/<name> dir with skills/*/SKILL.md
#      must also have .claude-plugin/plugin.json (otherwise check 1 would
#      silently skip it and the "plugin" wouldn't actually load).

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"

MARKETPLACE="${REPO_ROOT}/.claude-plugin/marketplace.json"

errors=0

# --- Discover plugin directories ---
plugin_dirs=()
for plugin_json in "${REPO_ROOT}"/plugins/*/.claude-plugin/plugin.json; do
  [[ -f "${plugin_json}" ]] || continue
  dir="$(dirname "$(dirname "${plugin_json}")")"
  name="$(basename "${dir}")"
  plugin_dirs+=("${name}")
done

if [[ ${#plugin_dirs[@]} -eq 0 ]]; then
  echo "ERROR: no plugin directories found (expected dirs with plugins/*/.claude-plugin/plugin.json)"
  exit 1
fi

echo "Found ${#plugin_dirs[@]} plugin(s): ${plugin_dirs[*]}"

# --- Extract names from marketplace ---
marketplace_names=()
if [[ -f "${MARKETPLACE}" ]]; then
  while IFS= read -r name; do
    marketplace_names+=("${name}")
  done < <(python3 -c "
import json, sys
with open(sys.argv[1]) as f:
    data = json.load(f)
for p in data.get('plugins', []):
    print(p['name'])
" "${MARKETPLACE}")
else
  echo "ERROR: ${MARKETPLACE} not found"
  errors=$((errors + 1))
fi

# --- Check 1: every plugin dir is in the marketplace ---
for name in "${plugin_dirs[@]}"; do
  found=false
  for mn in "${marketplace_names[@]}"; do
    if [[ "${mn}" == "${name}" ]]; then
      found=true
      break
    fi
  done
  if [[ "${found}" == "false" ]]; then
    echo "ERROR: plugin '${name}' has .claude-plugin/plugin.json but is missing from ${MARKETPLACE}"
    errors=$((errors + 1))
  fi
done

# --- Check 2: every marketplace entry has a plugin dir ---
for mn in "${marketplace_names[@]}"; do
  if [[ ! -f "${REPO_ROOT}/plugins/${mn}/.claude-plugin/plugin.json" ]]; then
    echo "ERROR: marketplace lists '${mn}' but plugins/${mn}/.claude-plugin/plugin.json does not exist"
    errors=$((errors + 1))
  fi
done

# --- Check 3: orphan skill directories (SKILL.md without plugin.json) ---
# Catches the blind spot in the discovery loop above: a dir with
# skills/*/SKILL.md but no .claude-plugin/plugin.json is silently skipped
# by checks 1-2, even though it's clearly meant to be a plugin.
# Dedupe by plugin dir so a plugin with N skills doesn't produce N errors.
# Plain space-delimited string instead of `declare -A` for bash 3.2 (macOS) compat.
seen_orphan_dirs=" "
for skill_md in "${REPO_ROOT}"/plugins/*/skills/*/SKILL.md; do
  top="$(basename "$(dirname "$(dirname "$(dirname "${skill_md}")")")")"
  [[ "${seen_orphan_dirs}" == *" ${top} "* ]] && continue
  seen_orphan_dirs+="${top} "
  if [[ ! -f "${REPO_ROOT}/plugins/${top}/.claude-plugin/plugin.json" ]]; then
    echo "ERROR: orphan skill dir 'plugins/${top}' has skills/*/SKILL.md but no .claude-plugin/plugin.json"
    errors=$((errors + 1))
  fi
done

if [[ ${errors} -gt 0 ]]; then
  echo ""
  echo "FAILED: ${errors} marketplace consistency error(s)"
  exit 1
fi

echo "OK: all ${#plugin_dirs[@]} plugins are listed in the marketplace"
