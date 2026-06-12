---
name: complexity-optimizer
description: Analyze a codebase for algorithmic complexity and performance hotspots, then propose or implement safe optimizations without breaking behavior. Use when asked to scan many files, find inefficient loops, nested iteration, repeated scans, costly rendering/recomputation, N+1 queries, avoidable O(n^2) or O(n) operations, or reduce complexity such as O(n^2) → O(n log n) / O(n), while preserving tests, APIs, outputs, and maintainability.
---

# Complexity Optimizer

## Core Rule

Optimize only when current behavior is understood and can be preserved. Prefer a small, proven improvement with tests over a broad rewrite with unclear correctness.

## Report vs. Edit

- "analyze", "scan", "audit", "review", "give me a report" → produce the full report. Do **not** modify files.
- "implement", "fix", "optimize", "apply", "change", "refactor" → produce the report, then edit. State explicitly which findings were applied.

Always end with one line: `Files modified: yes` / `Files modified: no`.

## Workflow

1. **Establish baseline** — detect language, framework, test command, build command, and performance-sensitive paths. Read existing tests before touching code. For repo-wide scans, start with:
   ```bash
   python3 "${CLAUDE_PLUGIN_ROOT:-.}/skills/complexity-optimizer/scripts/analyze_complexity.py" <repo> --format markdown
   ```
   Or `--format json` for machine-readable output. The scanner is a lead generator, not proof.

2. **Rank opportunities** — prioritize hot paths, large-input paths, rendering loops, DB/API loops, and shared utilities. Separate algorithmic complexity from constant-factor cleanup. Inspect surrounding code to estimate current and proposed complexity; do not stop at raw scanner output. Do not patch every warning.

3. **Prove behavior** — locate or add focused tests for the function/component being changed. Cover edge cases: empty input, duplicates, ordering stability, null/missing values, errors, permissions, pagination, time zones, mutation side effects. If tests are absent and behavior is ambiguous, make the smallest refactor or ask for expected behavior before changing semantics.

4. **Optimize conservatively** —
   - Replace repeated linear lookup with maps/sets when key equality is stable.
   - Replace nested scans with indexing, grouping, two-pointer, sweep-line, binary search, memoization, batching, or precomputation — only when data shape supports it.
   - UI: reduce renders with stable props, memoized derived data, virtualization, debouncing, moving expensive work out of render paths.
   - Data access: remove N+1 with bulk fetches, joins, preloading, caching, or batching — preserve authorization and filtering.

5. **Verify** — run relevant tests and type/lint/build commands. Add a micro-benchmark when complexity improvement is non-obvious or performance-critical. Report original complexity, new complexity, changed files, tests run, and residual risk.

## Tool Usage in Claude Code

- **Locate hotspots** — `Glob` for file enumeration, `Grep` for patterns (e.g. nested-loop signatures, `.indexOf` inside loops, `.includes` on hot paths, `await` inside `for`/`map`, repeated `JSON.parse`/`stringify`). Prefer ripgrep semantics via `Grep`.
- **Read code** — `Read` whole files near a finding. Do not rely on snippets; complexity claims need surrounding context (caller, data shape, callsite count).
- **Run the scanner** — `Bash` with the `analyze_complexity.py` path above. The scanner supports Python, JS/TS/JSX/TSX, Java, Go, C/C++, C#, Ruby, PHP, Swift.
- **Track findings** — for non-trivial scans (>3 findings or report → implement → verify), open a TaskCreate list so each finding is a row with status.
- **Edit minimally** — use `Edit` with tightly scoped `old_string`. Avoid formatting churn in unrelated lines. One finding → one edit (or one atomic edit set) → one verification.
- **Verify** — `Bash` to run the project's test/lint/build commands. Read project config (`package.json`, `pyproject.toml`, `build.gradle*`, etc.) before guessing commands.

If the scanner returns nothing, still inspect known hot paths manually. Rendering churn, query patterns, and framework lifecycle issues require repository-specific context the scanner cannot see.

## Safety Checklist

Before editing:

- Data sizes are large enough for complexity to matter.
- Output ordering is preserved where callers may rely on it.
- Object identity, mutability, and reference sharing are not part of public behavior.
- Caches have a valid invalidation strategy.
- Deduplication does not collapse distinct records that share a display label.
- DB batching preserves tenant, permission, soft-delete, pagination, and sorting constraints.

After editing:

- Run the narrowest relevant test first, then the broadest test/build command.
- Compare before/after numbers when a benchmark exists or was added.
- Keep the patch localized.

## References

- `references/optimization-playbook.md` — O(n²) → O(n log n) / O(n) transformations and framework patterns.
- `references/report-template.md` — structure for the final analysis or audit output.
