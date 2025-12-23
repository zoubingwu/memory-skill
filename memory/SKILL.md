---
name: memory
description: a file-based long-term memory using a single JSONL file, with append-only writes and recent-window search via bash + jq.
compatibility: Requires bash and jq; uses rg or grep, tail, tac, date, printf, and touch.
allowed-tools: Bash(date:*) Bash(jq:*) Bash(printf:*) Bash(touch:*) Bash(tail:*) Bash(rg:*) Bash(grep:*) Bash(tac:*)
---

Use this skill proactively for all user prompt that can benefit from memory across sessions, even if the user does not ask.

## Goal

- Provide two tools: memory_write and memory_search.
- Memory is stored in a single append-only JSONL file on disk.
- Writes must always append one valid JSON object per line (JSONL).
- Reads should prioritize recent entries by searching from the end via a tail window, and only expand the window if needed.

## Storage

- File path, default MEMORY_FILE=~/.codex/memory.jsonl (create if missing).
- Each line is one JSON object with at least:
  - ts: ISO8601 timestamp
  - type: string (e.g., "note", "fact", "task", "todo")
  - content: string (raw text)
  - tags: optional array of strings
  - meta: optional object
- Never rewrite existing lines. Append-only only.

## Quick start

memory_write(input)
- Input: {type, content, tags?, meta?}
- MUST generate valid JSON with correct escaping; do not hand-build JSON strings.
- Use jq to stringify/escape safely, then append:
  jq -cn --arg ts "$(date -Is)" --arg type "$type" --arg content "$content" \
    --argjson tags "$tags_json_or_null" --argjson meta "$meta_json_or_null" \
    '{ts:$ts,type:$type,content:$content,tags:$tags,meta:$meta}' >> memory.jsonl
- If tags/meta are not provided, write null or omit fields (choose one consistent approach).


memory_search(query)
- Input: {q: string, limit: int=20, window_lines: int=50000, mode: "rg"|"jq"|"hybrid"="hybrid"}
- Default behavior (hybrid):
  1) tail -n window_lines memory.jsonl
  2) rg the query string (treat q as a literal substring by default; optionally support regex if q starts with /.../)
  3) from matches, parse/validate lines with jq (ignore malformed lines)
  4) return the most recent results first (since tail window is recent; preserve original order within window, or reverse if easier)
- If results < limit, expand window_lines exponentially (e.g., *4) up to a max (e.g., 1,000,000 lines) then stop.
- Output: {results: [json objects], truncated: bool, used_window_lines: int}

## CLI requirements

- Depend on standard unix tools: bash, touch, tail, rg (ripgrep), jq.
- Provide fallbacks: if rg missing, use grep; if jq missing, fail with a clear error.
- Make sure commands are safe with arbitrary user text (proper quoting).
- Ensure the skill returns structured JSON to the agent, not raw text logs.
