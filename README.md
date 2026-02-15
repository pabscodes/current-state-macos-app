# Current State

A native macOS app that delivers your daily briefing powered by Claude Code.

Think of it as a clean window into your productivity system — you see the briefing and have a conversation, while Claude Code handles all the orchestration (calendar, tasks, files, scripts) invisibly in the background.

## Prerequisites

- macOS 14.0+ (Sonoma)
- [Claude Code](https://docs.anthropic.com/en/docs/claude-code) installed and authenticated
- Xcode 15+ (to build)

## How It Works

```
SwiftUI App  →  spawns `claude` CLI  →  streams JSON  →  renders briefing
     ↕                                                         ↕
  Chat input  →  `claude --resume`   →  streams JSON  →  renders response
```

The app is a thin client over Claude Code. Every interaction spawns a `claude -p` subprocess with `--output-format stream-json`. The app parses the stream, shows assistant messages, and hides all tool calls. Your existing skills, tools, and brain files work unchanged.

## Build & Run

```bash
cd CurrentState
xcodegen generate
open CurrentState.xcodeproj
# Cmd+R to run
```

## Architecture

See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) for the full design.
