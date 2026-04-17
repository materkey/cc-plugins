---
name: skill-workshop
description: >
  Analyze Claude Code session history to discover skill candidates.
  Finds repeating explanations, tool chains, and workaround patterns
  across project sessions. Use when user wants to find what should
  become a skill, mine session history, or extract tribal knowledge.
disable-model-invocation: true
allowed-tools: Bash, Read, Write, Grep, Glob
---

# Skill Workshop

Mine project session history for repeating patterns and propose new skills.

## Overview

This skill works in two phases:
1. **Extract & Analyze** — delegate to the `session-analyzer` subagent (Haiku)
   which parses JSONL session files and identifies pattern candidates
2. **Present & Generate** — read the analysis results, present candidates
   to the user, and generate SKILL.md drafts for approved candidates

## Step 1: Determine target project

Use `$ARGUMENTS` as the project path. If empty, use the current working directory.

```bash
PROJECT_PATH="${ARGUMENTS:-$(pwd)}"
echo "Target project: $PROJECT_PATH"
```

Verify sessions exist by checking the encoded project directory:

```bash
ENCODED=$(echo "$PROJECT_PATH" | sed 's|^/||; s|/|-|g')
for PREFIX in "-${ENCODED}" "${ENCODED}"; do
  DIR="$HOME/.claude/projects/${PREFIX}"
  if [ -d "$DIR" ]; then
    COUNT=$(ls "$DIR"/*.jsonl 2>/dev/null | grep -v '/agent-' | wc -l | tr -d ' ')
    echo "Found $COUNT session files in $DIR"
    break
  fi
done
```

If no sessions found, inform the user:
- Check if the path is correct
- Note that Claude Code deletes sessions after 30 days by default
- Suggest: `"cleanupPeriodDays": 100000` in `~/.claude/settings.json`

If sessions found, report the count and proceed.

## Step 2: Delegate extraction to session-analyzer

Clean previous temporary files:
```bash
rm -f /tmp/sw-*.jsonl /tmp/sw-*.json /tmp/sw-*.txt
```

Delegate the extraction and analysis work to the **session-analyzer** subagent.
Tell it the project path and session directory. It will:
- Parse all JSONL session files via bash extraction
- Identify repeated explanations, tool chain patterns, and workaround patterns
- Score and rank candidates
- Write results to `/tmp/skill-workshop-results.json`

Wait for the subagent to complete.

## Step 3: Read and present results

Read `/tmp/skill-workshop-results.json`. Present to the user:

**Header:**
- Project path
- Sessions analyzed (count and date range)
- Extraction stats (messages, tool calls, errors found)

**Candidates table:**

For each candidate (sorted by rank):

```
### #{rank}: {suggested_name}
Type: {signal_type} → proposed skill: {proposed_skill_type}
Score: {score} | Found in {frequency} sessions

{description}

Evidence:
- Session {id}: "{example}"
- Session {id}: "{example}"

Would create: {draft_content_hint}
```

**After listing all candidates, ask:**
"Which candidates should I develop into skill drafts? (numbers, 'all', or 'none')"

## Step 4: Generate SKILL.md drafts

For each approved candidate, generate a proper SKILL.md following these practices:

### Skill authoring rules

1. **Frontmatter:**
   - `name:` kebab-case, match the suggested_name
   - `description:` CRITICAL field — Claude uses this to decide when to load the skill.
     Format: "What it does. Use when [trigger conditions]."
     Write in third person. Max 200 characters. Include trigger words.

2. **Body structure:**
   - Start with a 1-2 sentence purpose statement
   - Use imperative language ("Run...", "Check...", not "You should...")
   - Include concrete examples from the evidence
   - Keep under 500 lines total

3. **By skill type:**

   **knowledge** (from repeated_explanation):
   - State the facts/rules directly
   - Include the exact terminology, values, configs the user kept repeating
   - Add a "Common mistakes" section listing what Claude gets wrong

   **workflow** (from tool_chain):
   - Step-by-step procedure
   - Include the tool sequence as explicit steps
   - Add validation checkpoints between steps

   **gotcha** (from workaround):
   - Lead with the error pattern (what goes wrong)
   - Then the fix (what to do instead)
   - Make it a concise "DO this, NOT that" format
   - If possible, include a validation command

4. **Write to:** `.claude/skills/{name}/SKILL.md`
   Create the directory if needed.

5. **DO NOT auto-enable.** Tell the user to review and test.

### Example gotcha skill

```markdown
---
name: pip-break-system-packages
description: >
  Prevents pip externally-managed-environment errors on this system.
  Use when installing Python packages with pip.
---

# pip install configuration

On this system, always use the `--break-system-packages` flag with pip.

## The problem
Bare `pip install <package>` fails with:
`error: externally-managed-environment`

## The fix
Always run:
```bash
pip install <package> --break-system-packages
```

This applies to ALL pip install commands including:
- `pip install -r requirements.txt --break-system-packages`
- `pip install -e . --break-system-packages`
- `pip install --upgrade <package> --break-system-packages`
```

### Example knowledge skill

```markdown
---
name: milvus-collection-config
description: >
  Milvus connection details and collection schema for this project.
  Use when working with vector database, embeddings, or Milvus queries.
---

# Milvus Configuration

## Connection
- Host: localhost
- Port: 19530
- No authentication required in dev

## Collection: expert_tax_chunks
- Fields: id (int64, primary), text (varchar), vector (float_vector, dim=1024), metadata (json)
- Index: IVF_FLAT on vector field, nlist=128
- Metric: COSINE

## Common queries
[... concrete examples from evidence ...]
```

## Step 5: Summary

After generating drafts, report:
- How many skills created, where
- Remind user to review each SKILL.md
- Suggest testing: "Try asking Claude something that should trigger the skill"
- Note: newly created skills may need a session restart or `/context` refresh to be discovered
