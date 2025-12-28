---
name: memory
description: Long-term memory across sessions. Always use memory_search at the start of any user request (unless the user explicitly says not to), especially for questions about the user (profile/personal info/preferences), prior constraints or decisions, and resuming ongoing work; use memory_write only when the user explicitly asks to store memory.
---

# Memory Skill

## Overview

- Provide two functions: `memory_write` and `memory_search`.
- Store memory in a single append-only JSONL file (one JSON object per line).
- Search a recent tail window first; only expand the window if needed.

## Workflow decision tree

### Recall context
Run `memory_search` at the start of every task unless the user explicitly says not to.

### Persist knowledge
Run `memory_write` only when the user explicitly asks to store memory, and only for stable, reusable information.

### Avoid writing
Do not write secrets, tokens, one-off details, or transient reasoning.

## Setup

Source the script before using the functions:

```bash
source scripts/memory.sh
```

Optionally override the storage file:

```bash
export MEMORY_FILE="$HOME/.codex/memory.jsonl"
```

## Storage format

- Store entries in `${MEMORY_FILE:-~/.codex/memory.jsonl}`; create it if missing.
- Write one JSON object per line with at least:
  - `ts`: ISO8601 timestamp
  - `type`: string (e.g., `note`, `fact`, `task`, `todo`)
  - `content`: string (raw text)
  - `tags`: optional array of strings
  - `meta`: optional object
- Never rewrite existing lines; append only.

## Write workflow (`memory_write`)

- Pass input as JSON: `{type, content, tags?, meta?}`.
- Generate valid JSON via `jq`; do not hand-build JSON strings.
- Append exactly one JSON object per line.

Example:
```bash
memory_write '{"type":"note","content":"Prefers terse status updates.","tags":["preference"]}'
```

## Search workflow (`memory_search`)

memory_search(query)
- Pass input as JSON: `{q, limit?, window_lines?}`.
- Treat `q` as a literal substring.
- Search a tail window first; expand exponentially if results are insufficient.
- Return output: `{results, truncated, used_window_lines}`.

Example:
```bash
memory_search '{"q":"prefers","limit":5,"window_lines":20000}'
```

## Requirements

- Depend on standard unix tools: bash, touch, tail, rg (ripgrep), jq.
- Provide fallbacks: if rg missing, use grep; if jq missing, fail with a clear error.
- Make sure commands are safe with arbitrary user text (proper quoting).
- Ensure the skill returns structured JSON to the agent, not raw text logs.
- Require bash and jq; use rg or grep, tail, date, printf, and touch.
- Allow tools: Bash(date:*) Bash(jq:*) Bash(printf:*) Bash(touch:*) Bash(tail:*) Bash(rg:*) Bash(grep:*)
