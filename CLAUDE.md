# Current State macOS App

## What This Is

A native macOS SwiftUI app that wraps Claude Code CLI to deliver daily briefings. Thin client architecture — the app spawns `claude -p` subprocesses, streams JSON output, and renders only the conversational content. All tool calls (Things 3, Calendar, file reads, scripts) happen invisibly through Claude Code.

## Architecture

See `docs/ARCHITECTURE.md` for the full design. Key points:

- **Subprocess model**: Each interaction is `claude -p "<msg>" --output-format stream-json --verbose`
- **Conversation continuity**: First call returns a `session_id`, subsequent calls use `--resume <id>`
- **Event filtering**: Only `assistant` type events rendered. `tool_use`, `tool_result`, etc. are hidden.
- **Stream format**: Documented in `docs/STREAM_FORMAT.md` from live testing on 2026-02-15.

## Project Structure

```
CurrentState/
├── project.yml                    # XcodeGen spec → generates .xcodeproj
├── Sources/
│   ├── App/
│   │   ├── CurrentStateApp.swift  # @main entry point, window config
│   │   └── AppState.swift         # @MainActor state machine driving the UI
│   ├── Models/
│   │   ├── Message.swift          # Chat message (role, content, timestamp)
│   │   └── StreamEvent.swift      # Parsed stream events (init, assistant, result)
│   ├── Services/
│   │   ├── ClaudeCodeService.swift # Subprocess lifecycle + async stream
│   │   ├── StreamParser.swift      # NDJSON line parser
│   │   └── SessionStore.swift      # UserDefaults session persistence
│   └── Views/
│       ├── MainView.swift          # Container: header + messages + input
│       ├── MessageBubble.swift     # User/assistant message rendering
│       ├── InputBar.swift          # Text input + send button
│       └── StatusIndicator.swift   # Streaming state dot
├── Tests/
│   └── StreamParserTests.swift     # 10 tests against real captured output
└── Resources/
    └── CurrentState.entitlements   # Sandbox disabled (needs subprocess access)
```

## Build

```bash
cd CurrentState
xcodegen generate        # generates .xcodeproj from project.yml
open CurrentState.xcodeproj
# Cmd+R to build and run
```

Requires: macOS 14.0+, Xcode 15+, Claude Code CLI installed and authenticated.

## Current Status

### Done
- [x] Project scaffold with all source files
- [x] Documentation (ARCHITECTURE, STREAM_FORMAT, UX_FLOW)
- [x] StreamParser with event filtering
- [x] ClaudeCodeService with async streaming
- [x] AppState state machine
- [x] All SwiftUI views (Main, MessageBubble, InputBar, StatusIndicator)
- [x] StreamParserTests (10 test cases with real data)
- [x] XcodeGen project spec
- [x] GitHub repo: https://github.com/pabscodes/current-state-macos-app

### Next (PR order)
- [ ] **PR 1**: Get compiling + parser tests green in Xcode
- [ ] **PR 2**: ClaudeCodeService actually spawns subprocess and streams
- [ ] **PR 3**: Wire service → views, render first real briefing
- [ ] **PR 4**: Chat follow-up with `--resume`
- [ ] **PR 5**: Markdown rendering polish
- [ ] **PR 6**: Error handling, settings, keyboard shortcuts

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Architecture | Thin client over Claude Code | Reuse all existing skills/tools, zero reimplementation |
| Subprocess mode | `claude -p` with `--output-format stream-json --verbose` | Structured output, session continuity via `--resume` |
| Conversation state | `--resume <session_id>` | Proven via live test — full context preserved across calls |
| Sandbox | Disabled | Must spawn `claude` subprocess — can't sandbox |
| Design | Apple Liquid Glass (macOS 26) | Native feel, modern, aligns with latest Apple HIG |
| Deployment target | macOS 14.0 (Sonoma) | Broad compatibility, may bump to 26 for Liquid Glass |

## Important Notes

- The `CLAUDECODE` env var must be unset when spawning subprocess (prevents "nested session" error)
- `--verbose` flag is required when using `--output-format stream-json` in print mode
- Stream events: `system` (init) → N × `assistant`/`tool_use`/`tool_result` → `result`
- Only render `type: "assistant"` events where `content` contains `type: "text"` blocks
- The briefing takes 30-90 seconds to generate (many parallel tool calls under the hood)
