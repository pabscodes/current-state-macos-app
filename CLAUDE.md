# Current State macOS App

## What This Is

A native macOS SwiftUI app that wraps Claude Code CLI to deliver daily briefings. Thin client architecture — the app spawns `claude -p` subprocesses, streams JSON output, and renders only the conversational content. All tool calls (Things 3, Calendar, file reads, scripts) happen invisibly through Claude Code.

## Architecture

See `docs/ARCHITECTURE.md` for the full design. Key points:

- **Subprocess model**: Each interaction is `claude -p "<msg>" --output-format stream-json --verbose`
- **Conversation continuity**: First call returns a `session_id`, subsequent calls use `--resume <id>`
- **Event filtering**: Only `assistant` type events rendered. `tool_use`, `tool_result`, etc. are hidden.
- **Stream format**: Documented in `docs/STREAM_FORMAT.md` from live testing on 2026-02-15.
- **Section-based rendering**: The `/currentstate-app` skill wraps each briefing section with `<<<SECTION:id>>>` delimiters. The app parses these into independent, cacheable section cards.

## Section Delimiter Protocol

The app uses a custom delimiter protocol for section-based rendering:
```
<<<SECTION:picture>>>
### The Picture
- Bullet content...
<<</SECTION:picture>>>
```

**Section IDs:** `header`, `picture`, `watch_list`, `what_matters`, `loose_ends`, `inbox_triage`, `wellbeing`, `health_checkin`

- Delimiters on their own lines, content between is pure markdown
- Empty sections are omitted (no delimiters emitted)
- `SectionStreamParser` handles delimiters split across stream chunks
- Streams without delimiters fall through as passthrough (backward compat with `/currentstate`)

## Project Structure

```
CurrentState/
├── project.yml                        # XcodeGen spec → generates .xcodeproj
├── Sources/
│   ├── App/
│   │   ├── CurrentStateApp.swift      # @main entry point, window config
│   │   └── AppState.swift             # @MainActor state machine — sections, cache, streaming
│   ├── Models/
│   │   ├── Message.swift              # Chat message (role, content, timestamp)
│   │   ├── StreamEvent.swift          # Parsed stream events (init, assistant, result)
│   │   ├── SectionID.swift            # Section identifier enum with display order
│   │   ├── BriefingSection.swift      # Per-section data model with loading states
│   │   ├── CachedBriefing.swift       # JSON-serializable cache root object
│   │   └── UserAction.swift           # Action → affected sections mapping
│   ├── Services/
│   │   ├── ClaudeCodeService.swift    # Subprocess lifecycle + async stream
│   │   ├── ClaudeCodeServiceProtocol.swift # Protocol for DI/testing
│   │   ├── StreamParser.swift         # NDJSON line parser
│   │   ├── SectionStreamParser.swift  # Delimiter parser (chunk-boundary safe)
│   │   ├── BriefingCache.swift        # Actor — file-based section cache
│   │   └── SessionStore.swift         # UserDefaults session persistence
│   └── Views/
│       ├── MainView.swift             # Dashboard + chat dual layout
│       ├── DashboardView.swift        # Section card container in display order
│       ├── SectionCard.swift          # Individual section with refresh overlay
│       ├── MessageBubble.swift        # User/assistant message rendering
│       ├── InputBar.swift             # Text input + send button
│       ├── StatusIndicator.swift      # Streaming state dot
│       ├── SettingsView.swift         # CLI path, startup skill, auto-generate
│       └── MarkdownTheme+CurrentState.swift # Custom markdown styling
├── Tests/
│   ├── StreamParserTests.swift        # 11 tests against real captured output
│   ├── SectionStreamParserTests.swift # 12 tests — chunk splitting, delimiters, flush
│   ├── BriefingCacheTests.swift       # 5 tests — save/load/update/clear
│   ├── AppStateTests.swift            # 22 tests — state machine + sections + cache
│   └── MockClaudeCodeService.swift    # Test mock for async streaming
└── Resources/
    └── CurrentState.entitlements      # Sandbox disabled (needs subprocess access)
```

## Skills

| Skill | Purpose |
|-------|---------|
| `/currentstate` | Original CLI briefing — no delimiters, untouched |
| `/currentstate-app` | App-specific briefing — section delimiters, per-section refresh, "Wellbeing" rename |

The app defaults to `/currentstate-app`. Changing the startup skill to `/currentstate` in Settings falls back to flat-message rendering (backward compat).

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
- [x] StreamParser with event filtering (11 tests)
- [x] ClaudeCodeService with async streaming
- [x] AppState state machine (22 tests)
- [x] All SwiftUI views (Main, Dashboard, SectionCard, MessageBubble, InputBar, StatusIndicator)
- [x] XcodeGen project spec
- [x] GitHub repo: https://github.com/pabscodes/current-state-macos-app
- [x] **PRD 1: Section-based execution & caching**
  - [x] Data models (SectionID, BriefingSection, CachedBriefing, UserAction)
  - [x] SectionStreamParser with 12 test cases
  - [x] BriefingCache actor with 5 test cases
  - [x] AppState refactor — sections, cache loading, per-section refresh, smart refresh
  - [x] `/currentstate-app` skill — delimiters verified in production (2026-02-17)
  - [x] View layer — DashboardView, SectionCard with context menu refresh
  - [x] Smart refresh wiring — keyword detection → affected section refresh
  - [x] 49 total tests passing, 0 failures

### Key UX Behaviors
- **Instant-on**: Cached sections load from `~/Library/Application Support/CurrentState/briefing-cache.json` on launch
- **Background refresh**: New briefing streams in background; cached sections show "refreshing" overlay
- **Per-section refresh**: Right-click any section card → "Refresh This Section"
- **Smart refresh**: After chat messages ("done", "skip", "schedule"), affected sections auto-refresh
- **Backward compat**: Streams without delimiters render as flat messages

### Next
- [ ] Integration testing — full app with live briefing
- [ ] Liquid Glass design pass (macOS 26)
- [ ] Performance tuning — briefing currently takes ~5 min

## Key Decisions

| Decision | Choice | Rationale |
|----------|--------|-----------|
| Architecture | Thin client over Claude Code | Reuse all existing skills/tools, zero reimplementation |
| Subprocess mode | `claude -p` with `--output-format stream-json --verbose` | Structured output, session continuity via `--resume` |
| Conversation state | `--resume <session_id>` | Proven via live test — full context preserved across calls |
| Sandbox | Disabled | Must spawn `claude` subprocess — can't sandbox |
| Design | Apple Liquid Glass (macOS 26) | Native feel, modern, aligns with latest Apple HIG |
| Deployment target | macOS 14.0 (Sonoma) | Broad compatibility, may bump to 26 for Liquid Glass |
| Section rendering | Single subprocess + delimiters | Simpler than multiple subprocesses; skill parallelizes internally |
| Skill strategy | New `/currentstate-app`, original untouched | Safety-first — CLI usage unaffected |
| Cache location | `~/Library/Application Support/CurrentState/` | Standard macOS app data location |

## Important Notes

- The `CLAUDECODE` env var must be unset when spawning subprocess (prevents "nested session" error)
- `--verbose` flag is required when using `--output-format stream-json` in print mode
- Stream events: `system` (init) → N × `assistant`/`tool_use`/`tool_result` → `result`
- Only render `type: "assistant"` events where `content` contains `type: "text"` blocks
- The briefing takes ~5 minutes to generate (subagent with many parallel tool calls)
- All text routes through `SectionStreamParser` — never append directly to messages
- "Context" section renamed to "Wellbeing" in `/currentstate-app` (section ID: `wellbeing`)
