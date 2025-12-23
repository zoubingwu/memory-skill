# Memory Skill

A file-based long-term memory skill for AI agents, implemented using a single append-only JSONL file. This skill allows agents to persist information across sessions and retrieve it efficiently using standard Unix tools.

## Features

- **File-based Storage**: Uses a simple JSONL (JSON Lines) file for storage, making it easy to inspect and backup.
- **Append-Only**: Ensures data integrity by only appending new entries and never rewriting existing lines.
- **Efficient Search**: Prioritizes recent entries by searching from the end of the file using a configurable window.
- **Lightweight**: Depends only on standard Unix tools like `bash`, `jq`, and `ripgrep` (or `grep`).

## Usage

This skill provides two main capabilities to the agent:

### 1. Writing to Memory (`memory_write`)

Stores a new entry in the memory file. Each entry is a JSON object containing a timestamp, type, content, and optional tags/metadata.

**Input:**
- `type`: String (e.g., "note", "fact", "task", "todo")
- `content`: String (the raw text content)
- `tags`: (Optional) Array of strings
- `meta`: (Optional) JSON object for extra metadata

**Storage Format:**
Entries are stored in `~/.codex/memory.jsonl` (default) as:
```json
{"ts": "2023-10-27T10:00:00+00:00", "type": "note", "content": "User prefers Python.", "tags": ["preference"], "meta": null}
```

### 2. Searching Memory (`memory_search`)

Retrieves relevant entries from memory based on a query string.

**Input:**
- `q`: Query string (literal substring or regex)
- `limit`: (Optional) Max number of results to return (default: 20)
- `window_lines`: (Optional) Number of recent lines to search (default: 50000)

The search strategy uses a "hybrid" approach:
1. Reads the last `window_lines` of the file.
2. Filters lines using `rg` (ripgrep) or `grep`.
3. Parses valid JSON lines with `jq`.
4. Returns the most recent matches.

## Requirements

Ensure the environment has the following tools installed:
- `bash`
- `jq`
- `ripgrep` (recommended) or `grep`
- `tail`, `touch`, `date`, `printf`

## Installation

Copy the `memory` folder into your agent's skill configuration folder. For example:

- Codex: `~/.codex/skills`
- Claude Code: `~/.claude/skills`
