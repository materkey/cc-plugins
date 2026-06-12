#!/usr/bin/env bash

set -euo pipefail

# Validate staged skill changes with skill-validator.
#
# Usage:
#   ci/validate-skills.sh                  # pre-commit mode: validate skills touched by staged files
#   ci/validate-skills.sh <files...>       # validate skills containing the given files (CI/manual mode)

cd "$(git rev-parse --show-toplevel)"

# Resolve a working skill-validator, in priority order:
#   1. one already in PATH;
#   2. repo-local bootstrap copy in ./ci/bin (git-ignored);
#   3. bootstrap via `go install` into ./ci/bin.
validator="./ci/bin/skill-validator"

if command -v skill-validator >/dev/null 2>&1; then
  validator="$(command -v skill-validator)"
elif ! [[ -x "$validator" ]] || ! "$validator" --version >/dev/null 2>&1; then
  if command -v go >/dev/null 2>&1; then
    mkdir -p ./ci/bin
    GOPROXY=direct GOBIN="$PWD/ci/bin" go install github.com/agent-ecosystem/skill-validator/cmd/skill-validator@v1.3.1
  else
    echo "skill-validator is not available: none in PATH, no working ./ci/bin/skill-validator, and no Go to install it." >&2
    exit 1
  fi
fi

# Without arguments (config-based pre-commit hooks receive none), collect
# staged files ourselves.
if [[ $# -eq 0 ]]; then
  staged_files=()
  while IFS= read -r f; do
    staged_files+=("$f")
  done < <(git diff --cached --name-only --diff-filter=ACMR)
  set -- ${staged_files[@]+"${staged_files[@]}"}
fi

if [[ $# -eq 0 ]]; then
  echo "No staged skill changes detected; skipping skill-validator."
  exit 0
fi

targets=()
seen_targets=$'\n'

for raw_path in "$@"; do
  path="${raw_path#./}"
  target=""

  case "$path" in
    plugins/*/skills/*)
      plugin="${path%%/skills/*}"
      remainder="${path#"$plugin/skills/"}"
      skill="${remainder%%/*}"

      if [[ -n "$plugin" && -n "$skill" ]]; then
        target="$plugin/skills/$skill"
      fi
      ;;
  esac

  if [[ -n "$target" && -d "$target" && "$seen_targets" != *$'\n'"$target"$'\n'* ]]; then
    seen_targets+="$target"$'\n'
    targets+=("$target")
  fi
done

if [[ ${#targets[@]} -eq 0 ]]; then
  echo "No staged skill changes detected; skipping skill-validator."
  exit 0
fi

failures=()

for target in "${targets[@]}"; do
  echo
  echo "==> skill-validator: $target"

  set +e
  output="$("$validator" validate structure -o json "$target" 2>&1)"
  status=$?
  set -e

  if ! echo "$output" | jq . >/dev/null 2>&1; then
    echo "$output"
    echo "skill-validator returned non-JSON output for $target" >&2
    failures+=("$target")
    continue
  fi

  echo "$output" | jq -r '
    .results[]
    | select(.level != "pass")
    | "  [" + .level + "] " + .category + ": " + .message
  '

  errors="$(echo "$output" | jq -r '.errors // 0')"
  warnings="$(echo "$output" | jq -r '.warnings // 0')"

  if [[ "$warnings" -gt 0 ]]; then
    echo "  warnings: $warnings"
  fi

  if [[ "$errors" -gt 0 ]]; then
    echo "  errors: $errors"
    failures+=("$target")
    continue
  fi

  if [[ "$status" -ne 0 && "$warnings" -eq 0 ]]; then
    echo "skill-validator exited with status $status for $target without reporting warnings or errors" >&2
    failures+=("$target")
  fi
done

if [[ ${#failures[@]} -gt 0 ]]; then
  echo
  echo "skill-validator failed for:"
  for target in "${failures[@]}"; do
    echo "  - $target"
  done
  exit 1
fi
