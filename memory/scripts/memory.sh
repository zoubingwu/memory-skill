# --- memory_write ---
# Build a JSONL entry with jq and append to the memory file.
memory_write() {
  local input_json file ts entry

  input_json="${1:-}"
  if [[ -z "$input_json" ]]; then
    input_json="$(cat)"
  fi

  if ! command -v jq >/dev/null 2>&1; then
    printf '%s\n' '{"ok":false,"error":"jq is required"}'
    return 1
  fi

  file="${MEMORY_FILE:-$HOME/.codex/memory.jsonl}"
  mkdir -p "$(dirname "$file")"
  touch "$file"
  ts="$(date -Is)"

  if ! entry="$(printf '%s' "$input_json" | jq -c --arg ts "$ts" '{ts:$ts,type:(.type//""),content:(.content//""),tags:(.tags//null),meta:(.meta//null)}' 2>/dev/null)"; then
    printf '%s\n' '{"ok":false,"error":"invalid input json"}'
    return 1
  fi

  printf '%s\n' "$entry" >> "$file"
  jq -cn --arg file "$file" --argjson entry "$entry" '{ok:true,file:$file,entry:$entry}'
}

# --- _memory_search_window ---
# Search within a window and return a JSON array.
_memory_search_window() {
  local file="$1"
  local q="$2"
  local window_lines="$3"
  local search_cmd

  if command -v rg >/dev/null 2>&1; then
    search_cmd=(rg -F --no-filename -- "$q")
  else
    search_cmd=(grep -F -- "$q")
  fi

  tail -n "$window_lines" "$file" | { "${search_cmd[@]}" || true; } | jq -Rcs \
    'split("\n") | map(select(length>0) | (fromjson?)) | map(select(. != null))'
}

# --- memory_search ---
# Search memory and return a structured JSON result.
memory_search() {
  local input_json file q limit window_lines max_window used_window
  local results total_count truncated

  input_json="${1:-}"
  if [[ -z "$input_json" ]]; then
    input_json="$(cat)"
  fi

  if ! command -v jq >/dev/null 2>&1; then
    printf '%s\n' '{"ok":false,"error":"jq is required","results":[],"truncated":false,"used_window_lines":0}'
    return 1
  fi

  if ! IFS=$'\t' read -r q limit window_lines <<<"$(printf '%s' "$input_json" | jq -r '[.q // "", .limit // 20, .window_lines // 50000] | @tsv' 2>/dev/null)"; then
    printf '%s\n' '{"ok":false,"error":"invalid input json","results":[],"truncated":false,"used_window_lines":0}'
    return 1
  fi

  if [[ -z "$q" ]]; then
    printf '%s\n' '{"ok":false,"error":"missing query","results":[],"truncated":false,"used_window_lines":0}'
    return 1
  fi

  if ! [[ "$limit" =~ ^[0-9]+$ ]]; then
    limit=20
  fi
  if ! [[ "$window_lines" =~ ^[0-9]+$ ]]; then
    window_lines=50000
  fi
  if [[ "$window_lines" -lt 1 ]]; then
    window_lines=50000
  fi

  file="${MEMORY_FILE:-$HOME/.codex/memory.jsonl}"
  mkdir -p "$(dirname "$file")"
  touch "$file"

  max_window=1000000
  used_window="$window_lines"
  results='[]'

  while :; do
    if ! results="$(_memory_search_window "$file" "$q" "$used_window")"; then
      printf '%s\n' '{"ok":false,"error":"search failed","results":[],"truncated":false,"used_window_lines":0}'
      return 1
    fi

    if ! total_count="$(printf '%s' "$results" | jq -r 'length' 2>/dev/null)"; then
      printf '%s\n' '{"ok":false,"error":"invalid search output","results":[],"truncated":false,"used_window_lines":0}'
      return 1
    fi

    if [[ "$total_count" -ge "$limit" || "$used_window" -ge "$max_window" ]]; then
      break
    fi

    used_window=$((used_window * 4))
    if [[ "$used_window" -gt "$max_window" ]]; then
      used_window="$max_window"
    fi
  done

  results="$(printf '%s' "$results" | jq -c 'reverse' 2>/dev/null)"
  total_count="$(printf '%s' "$results" | jq -r 'length' 2>/dev/null)"
  truncated=false
  if [[ "$total_count" -gt "$limit" ]]; then
    truncated=true
  fi

  results="$(printf '%s' "$results" | jq -c --argjson limit "$limit" '.[0:$limit]' 2>/dev/null)"
  jq -cn --argjson results "$results" --argjson truncated "$truncated" --argjson used_window_lines "$used_window" \
    '{results:$results,truncated:$truncated,used_window_lines:$used_window_lines}'
}
