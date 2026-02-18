---
name: currentstate-app
description: Daily briefing for the Current State macOS app. Same as /currentstate but outputs section delimiters for the app's section-based rendering. Use when invoked as "/currentstate-app" or from the macOS app.
---

# Current State App — Daily Briefing (Section-Delimited)

Generates Pablo's daily briefing using parallel Sonnet 4.6 subagents — one per section. Total time = slowest section (~60-90s) instead of sequential sum (~5min).

## Section Delimiter Protocol

Every briefing section MUST be wrapped:
```
<<<SECTION:section_id>>>
[section content — pure markdown including ### heading]
<<</SECTION:section_id>>>
```

**Section IDs:** `header`, `picture`, `watch_list`, `what_matters`, `loose_ends`, `inbox_triage`, `wellbeing`, `health_checkin`

**Rules:**
- Delimiters on their own lines
- Omit empty sections entirely — no delimiters for empty content
- The `## [Day], [Date] — [Time]` heading goes inside `<<<SECTION:header>>>`

---

## Main Agent Execution

### Step 1 — Output header immediately (no subagent)

Output this right now, before any tool calls:

```
<<<SECTION:header>>>
## [Day], [Date] — [Time]
<<</SECTION:header>>>
```

Use the actual current date and time. Run `date` if needed.

### Step 2 — Spawn all subagents in parallel

Make ONE message with ALL of the following Task tool calls simultaneously:

| Subagent | model | description |
|----------|-------|-------------|
| picture | sonnet | Picture section |
| watch_list | sonnet | Watch List section |
| what_matters | sonnet | What Matters Today section |
| loose_ends | sonnet | Loose Ends section |
| inbox_triage | sonnet | Inbox & Triage section |
| wellbeing | sonnet | Wellbeing section |
| background | sonnet | Activity log + calibration catch-up |

Use `subagent_type: "general-purpose"` for all. Copy the relevant subagent prompt from the sections below verbatim into each Task prompt.

### Step 3 — Output sections in display order

After all subagents return, output their results in this order. Each subagent returns its section already wrapped in delimiters — output verbatim, no editing:

1. `picture` result
2. `watch_list` result (skip if empty)
3. `what_matters` result
4. `loose_ends` result (skip if empty)
5. `inbox_triage` result (skip if empty)
6. `wellbeing` result (skip if empty)
7. Output `health_checkin` directly (static — no subagent):

```
<<<SECTION:health_checkin>>>
### Health Check-in
- What have you eaten today so far?
- Quick gut check — BMs, consistency, any urgency or blood?
- Energy and pain, 1-10.
<<</SECTION:health_checkin>>>
```

### Step 4 — Calibration catch-up

From the `background` subagent result, if CALIBRATION_TASKS is non-empty, ask about each task:
> Quick one — "[Task name]" was estimated at Xm, how long did it actually take? (or "skip")

Log each response to `~/brain/calibration/actuals.jsonl`:
```json
{"date":"YYYY-MM-DD","task":"name","category":"cat","estimated_min":N,"actual_min":N,"ratio":R,"source":"briefing"}
```

The `background` subagent also handles the activity log silently — no action needed from you on that.

### Step 5 — Post-briefing

After health data collected:
1. Offer calendar blocking: "Want me to block any focus time on your calendar for these priorities?"
2. First task prompt: "What do you want to tackle first?"

---

## Per-Section Refresh Mode

If the prompt contains `--section <section_id>`, run ONLY that section's subagent (Sonnet). Output just that section with delimiters. Do not run the full flow.

---

## Subagent Prompts

Copy each prompt verbatim into the corresponding Task tool call.

---

### PICTURE SUBAGENT PROMPT

```
You are generating the "picture" section of Pablo's daily briefing. Gather data, synthesize, and return the section wrapped in delimiters.

## Step 1: Gather data in parallel

Run all of these simultaneously:

Bash:
```bash
/opt/homebrew/bin/python3.12 ~/.claude/skills/schedule-meeting/gcal.py --list-events --date today --json --calendar personal
/opt/homebrew/bin/python3.12 ~/.claude/skills/schedule-meeting/gcal.py --list-events --date today --json --calendar wharton
```

Read files (skip silently if missing):
- ~/brain/context/current-state.md
- ~/brain/context/goals.md

Bash (recent completed tasks):
```bash
things logbook --modified-after=$(date -v-3d +%Y-%m-%d) --json
```

Read the 3 most recent daily log files from /Users/pabloordonezbravo/brain/daily/ (use Glob with pattern `*.md` and path `/Users/pabloordonezbravo/brain/daily`, take 3 most recent by filename). From each, extract only ## Completed and ## Log sections.

Read the most recent weekly review file from /Users/pabloordonezbravo/brain/weekly/ (use Glob with pattern `*.md` and path `/Users/pabloordonezbravo/brain/weekly`, take most recent by filename). Extract key themes and open items.

## Step 2: Day-of-week resolution (REQUIRED)

For every date in calendar events, run:
```bash
for d in YYYY-MM-DD ...; do echo "$d $(date -j -f '%Y-%m-%d' "$d" '+%A')"; done
```
Use this as sole source of truth for day names. Never infer from arithmetic.

## Step 3: Synthesize

Combine daily logs, completed tasks, current-state.md, goals.md, and weekly review into structured notes:
- **Recent momentum**: What has Pablo been shipping? Throughput trend?
- **Week-level context**: Shape of this week — front-loaded, back-loaded, scattered?
- **Semester arc**: Where does this week sit relative to goals.md objectives?
- **Today's role**: Recovery day, sprint day, prep day, etc.

If past calendar events (end < now) exist, note for a catch-up question.

## Step 4: Compose and return

Return ONLY this — nothing else:

<<<SECTION:picture>>>
### The Picture
[3-6 bullets. Direct, specific, editorial. Name tasks, dates, projects — never generic.
If past events exist: lead with "You had **[Event]** at **[Time]** — how'd that go?"
Litmus test: if a bullet could apply to any MBA student on any week, delete it.
If sparse logs: 2 bullets minimum from logbook data.]
<<</SECTION:picture>>>

If nothing meaningful to show, return an empty string (no delimiters).
```

---

### WATCH LIST SUBAGENT PROMPT

```
You are generating the "watch_list" section of Pablo's daily briefing. Gather data and return the section wrapped in delimiters.

## Step 1: Gather data in parallel

```bash
things deadlines --json
things upcoming --json --limit 50
/opt/homebrew/bin/python3.12 ~/.claude/skills/schedule-meeting/gcal.py --list-events --from $(date +%Y-%m-%d) --to $(date -v+7d +%Y-%m-%d) --json --calendar personal
/opt/homebrew/bin/python3.12 ~/.claude/skills/schedule-meeting/gcal.py --list-events --from $(date +%Y-%m-%d) --to $(date -v+7d +%Y-%m-%d) --json --calendar wharton
```

## Step 2: Day-of-week resolution (REQUIRED)

For every date in results, run:
```bash
for d in YYYY-MM-DD ...; do echo "$d $(date -j -f '%Y-%m-%d' "$d" '+%A')"; done
```

## Step 3: Deadline scan

**Tier 1 — This week (0-7 days):**
- Flag: start_date == deadline (no prep time), unscheduled work (deadline but no start_date), capacity risks
- Parse time estimates from titles: `\((\d+(?:\.\d+)?)\s*(m|min|h|hr)\)`. Keyword defaults: email/follow up/schedule/book → 20m, read/review/prep → 45m, write/draft → 90m, case/code/analysis → 150m, fallback → 30m.
- Flag if available calendar time < estimated task time

**Tier 2 — Horizon (8-28 days):**
- Surface tasks if: estimated > 1h, belongs to school project, deadline but no start_date
- Limit to top 5 by urgency (earliest deadline first)

## Step 4: Compose and return

Return ONLY this — nothing else:

<<<SECTION:watch_list>>>
### Watch List
[Bullets only — items needing attention. Each: **what** — why it matters — suggested action.
Tier 2 items marked with horizon context (e.g., "3 weeks out but needs 4h").
Does NOT repeat What Matters Today items unless there's a separate risk.]
<<</SECTION:watch_list>>>

If nothing to flag, return an empty string (no delimiters).
```

---

### WHAT MATTERS SUBAGENT PROMPT

```
You are generating the "what_matters" section of Pablo's daily briefing. Gather data and return the section wrapped in delimiters.

## Step 1: Gather data in parallel

```bash
things today --json
things deadlines --json
/opt/homebrew/bin/python3.12 ~/.claude/skills/schedule-meeting/gcal.py --list-events --date today --json --calendar personal
/opt/homebrew/bin/python3.12 ~/.claude/skills/schedule-meeting/gcal.py --list-events --date today --json --calendar wharton
/opt/homebrew/bin/python3.12 ~/.claude/skills/schedule-meeting/gcal.py --list-events --from $(date +%Y-%m-%d) --to $(date -v+7d +%Y-%m-%d) --json --calendar personal
/opt/homebrew/bin/python3.12 ~/.claude/skills/schedule-meeting/gcal.py --list-events --from $(date +%Y-%m-%d) --to $(date -v+7d +%Y-%m-%d) --json --calendar wharton
```

Read files (skip silently if missing):
- ~/brain/calibration/factors.md
- ~/brain/calibration/actuals.jsonl
- All *.md files in /Users/pabloordonezbravo/brain/school/ (use Glob with pattern `*.md` and path `/Users/pabloordonezbravo/brain/school`)

## Step 2: Day-of-week resolution (REQUIRED)

For every date in results, run:
```bash
for d in YYYY-MM-DD ...; do echo "$d $(date -j -f '%Y-%m-%d' "$d" '+%A')"; done
```

## Step 3: Processing

**Time slots:** Scheduling window MAX(now rounded to next 15-min, 8:00 AM) through 11:00 PM. Find gaps >= 30 minutes between events.

**Task estimates:** Parse `\((\d+(?:\.\d+)?)\s*(m|min|h|hr)\)`. Keyword defaults: email/follow up/schedule/book → 20m, read/review/prep → 45m, write/draft/memo/essay → 90m, case/code/analysis/problem set → 150m, fallback → 30m.

**Calibration:** From factors.md, apply category factors silently. Categories: class-prep (case prep/quiz prep), case-work (case/analysis/REAL project), writing (write/draft/essay/application), code-analysis (code/build/script), reading (read/review), admin (email/follow up/schedule), fallback. Only surface warning if factor > 2x.

**Class context:** For tasks in a school project, read ~/brain/school/{project_title}.md to find the topic/case for the task's date. Weave naturally into reasoning.

**Forward-looking:** Include tasks due later in the week if today is the only realistic window to start them. Think forward, not just what Things labels "today."

**Bin-packing:** Greedy first-fit by duration. Informs priorities — never shown as a table.

## Step 4: Compose and return

Return ONLY this — nothing else:

<<<SECTION:what_matters>>>
### What Matters Today
[Numbered list. No preamble. Draw from deadlines needing work today.
1. **[Top priority]** — one line reasoning, time estimate, when to do it
2. **[Second priority]** — one line reasoning, time estimate
3. **[Third priority]** — one line reasoning, time estimate
Calibration warning inline if factor > 2x: "(heads up — [category] tasks run [factor]x, so ~[adjusted])"
Class context woven into reasoning line naturally.]
<<</SECTION:what_matters>>>
```

---

### LOOSE ENDS SUBAGENT PROMPT

```
You are generating the "loose_ends" section of Pablo's daily briefing. Gather data and return the section wrapped in delimiters.

## Step 1: Gather data in parallel

```bash
things inbox --json
```

Read the 3 most recent daily log files from /Users/pabloordonezbravo/brain/daily/ (use Glob with pattern `*.md` and path `/Users/pabloordonezbravo/brain/daily`, take 3 most recent by filename). From each, extract only ## Completed and ## Log sections.

## Step 2: Find loose ends

Scan daily logs for:
- Items mentioned but not in Things (open threads, promises, mentioned tasks)
- Meeting notes with no action item captured
- Anything that seems unresolved

Cross-reference with Things inbox to avoid surfacing things already captured.

## Step 3: Compose and return

Return ONLY this — nothing else:

<<<SECTION:loose_ends>>>
### Loose Ends
| # | Item | Destination | Urgency |
|---|------|-------------|---------|
| 1 | [item] | → Things inbox | low/medium/high |
<<</SECTION:loose_ends>>>

If nothing to surface, return an empty string (no delimiters).
```

---

### INBOX TRIAGE SUBAGENT PROMPT

```
You are generating the "inbox_triage" section of Pablo's daily briefing. Gather data and return the section wrapped in delimiters.

## Step 1: Gather data in parallel

```bash
things inbox --json
things today --json
```

## Step 2: Classify today's tasks

Split `things today` results into:
- **Fresh** — start_date == today
- **Stale** — start_date < today (rolled over)

## Step 3: Compose and return

Return ONLY this — nothing else:

<<<SECTION:inbox_triage>>>
### Inbox & Triage

#### Inbox (X items)
| # | Item | Suggested Action |
|---|------|-----------------|
| 1 | [task] | [action] |

#### Rollover (X stale items)
**List ALL stale today items — never trim.** Every item gets a row.
| # | Item | Since | Suggested Action |
|---|------|-------|-----------------|
| 1 | [task] | [date] | [action] |

"Respond: '1 sat, 2 next week, 3 keep' — or 'skip all'"
<<</SECTION:inbox_triage>>>

Omit Inbox sub-section if inbox is empty. Omit Rollover sub-section if no stale items. If both empty, return an empty string (no delimiters).
```

---

### WELLBEING SUBAGENT PROMPT

```
You are generating the "wellbeing" section of Pablo's daily briefing. Gather data and return the section wrapped in delimiters.

## Step 1: Gather data in parallel

Read files (skip silently if missing):
- ~/brain/context/productivity.md
- ~/brain/context/lessons.md

Read the 3 most recent daily log files from /Users/pabloordonezbravo/brain/daily/ (use Glob with pattern `*.md` and path `/Users/pabloordonezbravo/brain/daily`, take 3 most recent by filename). From each, extract only ## Completed, ## Log, ## Health sections.

Read most recent weekly review file from /Users/pabloordonezbravo/brain/weekly/ (use Glob with pattern `*.md` and path `/Users/pabloordonezbravo/brain/weekly`, take most recent). Check date — flag if 7+ days old.

## Step 2: Compose and return

Return ONLY this — nothing else:

<<<SECTION:wellbeing>>>
### Wellbeing
[Bullets only. Only if actionable. Pick from:
- Health patterns worth noting (from daily logs)
- Productivity nudges (from productivity.md)
- Relevant lessons (from lessons.md)
- Weekly review overdue reminder (if 7+ days)
- Energy/sleep observations]
<<</SECTION:wellbeing>>>

If nothing actionable, return an empty string (no delimiters).
```

---

### BACKGROUND SUBAGENT PROMPT

```
You are handling background tasks for Pablo's daily briefing. Run silently — your output is never shown to Pablo directly. Return structured data only.

## Task 1: Activity log

```bash
~/bin/activity-report --yesterday --summary --chrome
```

If successful, append output to ~/brain/daily/YYYY-MM-DD.md (today's date) under a ## Screen Time section. Create the file if it doesn't exist. Never show this output in the briefing.

## Task 2: Calibration catch-up data

Determine "yesterday" (late-night rule: if current hour is 0-2, shift back 1 day).

```bash
things logbook --modified-after=$(date -v-1d +%Y-%m-%d) --modified-before=$(date +%Y-%m-%d) --json
```

Find tasks with time estimates in title: `\((\d+(?:\.\d+)?)\s*(m|min|h|hr)\)`

Read ~/brain/calibration/actuals.jsonl. Skip tasks already captured (match by task name substring).

Classify each uncaptured task by category:
1. class-prep: "case prep", "quiz prep"
2. case-work: case/analysis/REAL project
3. writing: write/draft/essay/application/fellowship/letter
4. code-analysis: code/problem set/build/script
5. reading: read/review/chapter
6. admin: email/follow up/schedule/book/send/buy
7. fallback: everything else

## Return format

Return ONLY this JSON structure:

{
  "calibration_tasks": [
    {"task": "Task title", "estimated_min": N, "category": "cat"}
  ]
}

Empty array if no uncaptured tasks.
```
