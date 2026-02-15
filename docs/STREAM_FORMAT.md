# Claude Code Stream JSON Format

Documented from live testing on 2026-02-15 with Claude Code v2.1.42.

## Protocol

- Output format: newline-delimited JSON (NDJSON)
- Requires flags: `--output-format stream-json --verbose`
- Each line is a complete JSON object with a `type` field

## Event Types

### 1. `system` (subtype: `init`)

First event emitted. Contains session metadata.

```json
{
  "type": "system",
  "subtype": "init",
  "cwd": "/Users/pabloordonezbravo",
  "session_id": "c45a70e1-0d9b-484e-a7b9-b8045d28d718",
  "model": "claude-opus-4-6",
  "tools": ["Task", "Bash", "Read", "Edit", "Write", ...],
  "skills": ["currentstate", "things3", "calendar", ...],
  "claude_code_version": "2.1.42",
  "mcp_servers": [{"name": "playwright", "status": "connected"}]
}
```

**Key fields for the app:**
- `session_id` — store for `--resume` on follow-up calls
- `model` — display in UI if desired

### 2. `assistant`

Contains model response text. May appear multiple times per turn (before/after tool calls).

```json
{
  "type": "assistant",
  "message": {
    "model": "claude-opus-4-6",
    "id": "msg_01HSqZjiTJ8ybWxQEHMJQqEd",
    "role": "assistant",
    "content": [
      {"type": "text", "text": "## Saturday, February 15 — 10:42 AM\n\n### Your Day\n..."}
    ],
    "usage": {
      "input_tokens": 3,
      "output_tokens": 1,
      "cache_read_input_tokens": 13848,
      "cache_creation_input_tokens": 10539
    }
  },
  "session_id": "c45a70e1-0d9b-484e-a7b9-b8045d28d718"
}
```

**Key fields:**
- `message.content[]` — array of content blocks. Filter for `type: "text"` and concatenate `.text` values.
- Multiple `assistant` events may fire per turn. Append all text sequentially.

### 3. `result`

Final event. Signals completion.

```json
{
  "type": "result",
  "subtype": "success",
  "is_error": false,
  "result": "Full concatenated text of the response",
  "session_id": "c45a70e1-0d9b-484e-a7b9-b8045d28d718",
  "duration_ms": 3130,
  "duration_api_ms": 2952,
  "num_turns": 1,
  "total_cost_usd": 0.073,
  "usage": {
    "input_tokens": 3,
    "output_tokens": 12,
    "cache_read_input_tokens": 13848
  }
}
```

**Key fields:**
- `result` — complete response text (can use as fallback if streaming was interrupted)
- `session_id` — confirm/update stored session ID
- `is_error` — check for failure
- `total_cost_usd` — display if desired

### 4. Other Events (Hidden)

These appear when Claude Code uses tools. The app discards them:
- Tool call events (type varies — likely `tool_use` or nested in `assistant.message.content`)
- Tool result events
- Permission request events

**Rule: Only render events where `type == "assistant"`. Discard everything else.**

## Conversation Continuity

### First call:
```bash
claude -p "/currentstate" --output-format stream-json --verbose
```
→ Extract `session_id` from `init` or `result` event.

### Subsequent calls:
```bash
claude -p "block 2-4pm for FNCE prep" --resume <session_id> --output-format stream-json --verbose
```
→ Claude Code loads the full conversation history. All context preserved.

### Verified behavior:
- Call 1: "say hello in one sentence" → session `c45a70e1-...`
- Call 2: "what did I just ask you?" with `--resume c45a70e1-...` → "You asked me to say hello in one sentence."

Conversation state fully preserved across subprocess invocations.
