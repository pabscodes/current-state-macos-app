# Architecture

## Overview

Current State is a thin SwiftUI client over the Claude Code CLI. The app spawns `claude` as a subprocess, streams structured JSON output, and renders only the conversational content — hiding all tool calls, file reads, and background orchestration.

## System Diagram

```
┌─────────────────────────────────────┐
│         SwiftUI macOS App           │
│                                     │
│  ┌───────────┐  ┌────────────────┐  │
│  │ Briefing  │  │  Chat / Follow │  │
│  │   View    │  │    Up View     │  │
│  └─────┬─────┘  └───────┬────────┘  │
│        │                │            │
│  ┌─────┴────────────────┴─────────┐ │
│  │     ClaudeCodeService          │ │
│  │     (Process + StreamParser)   │ │
│  └────────────────────────────────┘ │
└──────────────┬──────────────────────┘
               │  Process.spawn("claude")
               ▼
┌──────────────────────────────────────┐
│  Claude Code CLI (subprocess)        │
│  Skills: /currentstate, /intake, ... │
│  Tools: Things 3, Calendar, files    │
└──────────────────────────────────────┘
```

## Subprocess Protocol

### First Call (Briefing Generation)

```bash
claude -p "/currentstate" \
  --output-format stream-json \
  --verbose
```

### Follow-Up Calls (Chat)

```bash
claude -p "<user message>" \
  --resume <session-id> \
  --output-format stream-json \
  --verbose
```

### Stream Events

Each line of stdout is a JSON object. The app handles three event types:

| Event Type | Action | Visible to User |
|---|---|---|
| `system` (subtype: `init`) | Extract `session_id`, store for `--resume` | No |
| `assistant` | Extract `message.content[].text`, append to chat | Yes — this is the briefing/response |
| `result` | Mark streaming complete, confirm `session_id` | No (triggers "done" state) |

All other events (tool_use, tool_result, etc.) are silently discarded.

### Event Schemas

**Init event:**
```json
{
  "type": "system",
  "subtype": "init",
  "session_id": "uuid",
  "model": "claude-opus-4-6",
  "tools": ["Bash", "Read", ...],
  "skills": ["currentstate", "things3", ...]
}
```

**Assistant event:**
```json
{
  "type": "assistant",
  "message": {
    "content": [{"type": "text", "text": "## Saturday, Feb 15..."}],
    "model": "claude-opus-4-6"
  },
  "session_id": "uuid"
}
```

**Result event:**
```json
{
  "type": "result",
  "subtype": "success",
  "result": "full text of final response",
  "session_id": "uuid",
  "duration_ms": 45000,
  "total_cost_usd": 0.15
}
```

## App Components

### ClaudeCodeService
- Manages subprocess lifecycle (spawn, stream, kill)
- Parses stream-json line by line
- Publishes `@Published` properties for SwiftUI binding
- Tracks session ID for conversation continuity

### StreamParser
- Decodes newline-delimited JSON
- Routes events by type
- Extracts text content from assistant messages

### SessionStore
- Persists session ID to UserDefaults
- Enables app restart without losing conversation
- Clears on "new briefing" action

### Views
- **MainView**: Container with briefing area + chat input
- **BriefingView**: Markdown-rendered briefing content
- **ChatView**: Message bubbles for follow-up conversation
- **StatusIndicator**: Shows streaming/working/idle states

## Build Phases

### Phase 1: MVP (Read-Only Briefing)
- [ ] ClaudeCodeService subprocess management
- [ ] StreamParser with event filtering
- [ ] BriefingView with markdown rendering
- [ ] Loading state during generation
- [ ] Session ID persistence

### Phase 2: Interactive Chat
- [ ] Chat input bar
- [ ] Message history (briefing + follow-ups)
- [ ] `--resume` integration
- [ ] Working indicator during tool execution

### Phase 3: Polish
- [ ] Menu bar mode (optional)
- [ ] Error handling and retry
- [ ] App icon and styling
- [ ] Keyboard shortcuts (Cmd+N for new briefing, etc.)

### Phase 4: Shareable
- [ ] First-run setup (detect Claude Code, guide auth)
- [ ] Configurable skill trigger (not hardcoded to /currentstate)
- [ ] Distribute via GitHub Releases (notarized .app)
