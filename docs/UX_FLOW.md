# UX Flow

## Screen 1: Launch → Loading

When the app opens, it immediately triggers a briefing.

```
┌─────────────────────────────────────┐
│  ●  Current State                   │
├─────────────────────────────────────┤
│                                     │
│                                     │
│            ◯ ◯ ◯                    │
│                                     │
│     Preparing your briefing...      │
│                                     │
│                                     │
└─────────────────────────────────────┘
```

- Subprocess started: `claude -p "/currentstate" --output-format stream-json --verbose`
- Animated dots or spinner
- Typically takes 30-90 seconds (multiple tool calls happening invisibly)

## Screen 2: Briefing Displayed

Once assistant text starts streaming, render progressively.

```
┌──────────────────────────────────────────┐
│  ●  Current State               ⟳   ⚙   │
├──────────────────────────────────────────┤
│                                          │
│  Saturday, February 15 — 10:42 AM        │
│  ─────────────────────────────────       │
│                                          │
│  Your Day                                │
│  Your morning is wide open until lunch   │
│  with Marcus at 12:30. After that...     │
│                                          │
│  This Week                               │
│  Heavy front-load. FNCE case due Tue,    │
│  fellowship application due Friday...    │
│                                          │
│  What Matters Today                      │
│  1. FNCE 7500 case prep (~2h) — the     │
│     case covers venture capital...       │
│  2. Fellowship draft (~90m) — you have   │
│     a solid outline, need to...          │
│  3. Clear inbox (3 items, ~20m)          │
│                                          │
│  Inbox & Triage                          │
│  │ # │ Item              │ Action      │ │
│  │ 1 │ Reply to Sam      │ Today 10m   │ │
│  │ 2 │ Book flights      │ Tomorrow    │ │
│                                          │
│  Health Check-in                         │
│  What have you eaten so far today?...    │
│                                          │
├──────────────────────────────────────────┤
│  ▸  Type a message...                 ⏎  │
└──────────────────────────────────────────┘
```

- Markdown rendered with proper headers, bold, tables
- Scrollable content area
- Input bar at bottom, always visible
- ⟳ button to regenerate briefing (new session)
- ⚙ button for settings

## Screen 3: Chat Interaction

User responds, Claude processes in background.

```
├──────────────────────────────────────────┤
│                                          │
│  ...Health Check-in                      │
│  What have you eaten so far today?...    │
│                                          │
│  ┌─────────────────────────────────────┐ │
│  │ Had eggs and coffee. Energy 7/10,  │ │
│  │ no issues. Let's do the FNCE prep. │ │
│  └─────────────────────────────────────┘ │
│                                          │
│  ◯ Working...                            │
│                                          │
├──────────────────────────────────────────┤
│  ▸                                    ⏎  │
└──────────────────────────────────────────┘
```

Then once Claude responds:

```
│  ┌─────────────────────────────────────┐ │
│  │ Had eggs and coffee. Energy 7/10,  │ │
│  │ no issues. Let's do the FNCE prep. │ │
│  └─────────────────────────────────────┘ │
│                                          │
│  Logged your health check-in. Good       │
│  energy today.                           │
│                                          │
│  For the FNCE 7500 case — it's the      │
│  Four Seasons valuation. You'll need     │
│  the case PDF and the VCFI framework...  │
│                                          │
│  I've blocked 11:00 AM - 1:00 PM on     │
│  your calendar for this. Want me to      │
│  pull up the case context?               │
│                                          │
├──────────────────────────────────────────┤
│  ▸  Type a message...                 ⏎  │
└──────────────────────────────────────────┘
```

## State Machine

```
         App Launch
             │
             ▼
    ┌─── LOADING ◄──── ⟳ Refresh
    │        │
    │   (stream starts)
    │        ▼
    │    STREAMING ────► text arrives ────► append to view
    │        │
    │   (result event)
    │        ▼
    │     READY ◄────────────────────────┐
    │        │                           │
    │   (user sends message)             │
    │        ▼                           │
    │    STREAMING ──► text arrives ──► READY
    │
    │   (error)
    │        ▼
    └──► ERROR ──► retry / new session
```

## Keyboard Shortcuts

| Shortcut | Action |
|---|---|
| ⌘N | New briefing (fresh session) |
| ⌘R | Refresh / regenerate |
| ⏎ | Send message |
| ⇧⏎ | Newline in input |
| ⌘W | Close window |
| ⌘, | Settings |

## Settings Panel

```
┌──────────────────────────────────┐
│  Settings                        │
├──────────────────────────────────┤
│                                  │
│  Claude Code Path                │
│  [/usr/local/bin/claude      ]   │
│                                  │
│  Startup Skill                   │
│  [/currentstate              ]   │
│                                  │
│  □ Launch at login               │
│  □ Auto-generate on open         │
│  □ Show token costs              │
│                                  │
│              [Save]              │
└──────────────────────────────────┘
```
