---
name: currentstate-app
description: Daily briefing for the Current State macOS app. Same as /currentstate but outputs section delimiters for the app's section-based rendering. Use when invoked as "/currentstate-app" or from the macOS app.
---

# Current State App — Daily Briefing (Section-Delimited)

Identical to `/currentstate` but wraps each section with delimiters for the macOS app's section-based rendering engine. Supports per-section refresh via `--section <id>`.

## Section Delimiter Protocol

Every briefing section MUST be wrapped with delimiters:
```
<<<SECTION:section_id>>>
[section content — pure markdown including ### heading]
<<</SECTION:section_id>>>
```

**Section IDs:** `header`, `picture`, `watch_list`, `what_matters`, `loose_ends`, `inbox_triage`, `wellbeing`, `health_checkin`

**Rules:**
- Delimiters go on their own lines
- Content between delimiters is pure markdown (including the `###` heading)
- Omitted sections (empty data) get NO delimiters — do not emit empty sections
- The `## [Day], [Date] — [Time]` heading goes inside `<<<SECTION:header>>>`

## Execution Model

**All data gathering and briefing composition runs in a single Opus 4.6 subagent to keep the main conversation clean.** Pablo should only see the final briefing — not 15+ tool calls of raw JSON.

### Per-Section Refresh Mode

If the prompt contains `--section <section_id>`, only regenerate that specific section:
- Re-gather only that section's data sources (see Section Data Source Mapping below)
- Output ONLY that section with its delimiters
- Keep session context for conversation continuity
- Do NOT run the full subagent flow — just fetch the data and compose one section

**Section Data Source Mapping:**

| Section | Data Sources to Re-gather |
|---------|--------------------------|
| `header` | Current date/time only |
| `picture` | Daily logs, logbook, current-state.md, goals.md, calendar |
| `watch_list` | Things deadlines, things upcoming, calendar |
| `what_matters` | Things today, calendar, calibration, school context |
| `loose_ends` | Daily logs, things inbox |
| `inbox_triage` | Things inbox, things today (stale items) |
| `wellbeing` | Daily logs, productivity.md, lessons.md, weekly review |
| `health_checkin` | No data (static template) |

### Main Agent: Step A — Spawn Subagent (Full Briefing)

Use the Task tool with these parameters:
- `subagent_type`: `"general-purpose"`
- `model`: `"opus"`
- `description`: `"Daily briefing data + compose"`
- `prompt`: Copy the **entire "Subagent Instructions" section** below (everything from `## Subagent Instructions` through the end of the file) into the prompt, verbatim. Prepend this header:

```
You are composing Pablo's daily briefing. Follow the instructions below exactly.

IMPORTANT: Wrap every briefing section with delimiters. Format:
<<<SECTION:section_id>>>
[content including ### heading]
<<</SECTION:section_id>>>

Section IDs: header, picture, watch_list, what_matters, loose_ends, inbox_triage, wellbeing, health_checkin
Omitted sections (empty data) get NO delimiters.

Return your response in this structure:

===BRIEFING===
[Full markdown briefing with section delimiters — from <<<SECTION:header>>> through <<</SECTION:health_checkin>>>]

===CALIBRATION_TASKS===
[JSON array of objects: {"task": "name", "estimate_min": N, "category": "cat"} for tasks needing timing catch-up. Empty array [] if none.]

===ACTIVITY_LOG===
[Raw screen time summary text to log silently. Empty string "" if command failed.]

===DAILY_FILE_EXISTS===
[true/false — whether ~/brain/daily/YYYY-MM-DD.md already exists]
```

### Main Agent: Step B — Process Results

When the subagent returns:

1. **Activity log (silent):** If ACTIVITY_LOG is non-empty, append it to `~/brain/daily/YYYY-MM-DD.md` under a `## Screen Time` section. Create the daily file if needed. **Never show this to Pablo.**

2. **Output briefing:** Output the BRIEFING section verbatim — including all `<<<SECTION:...>>>` delimiters. Do not strip them. Do not add any preamble or commentary.

3. **Calibration catch-up:** If CALIBRATION_TASKS is non-empty, after the briefing, ask about each task one at a time:
   > Quick one — "[Task name]" was estimated at Xm, how long did it actually take? (or "skip")

   Log responses to `~/brain/calibration/actuals.jsonl` with format:
   ```json
   {"date":"YYYY-MM-DD","task":"name","category":"cat","estimated_min":N,"actual_min":N,"ratio":R,"source":"briefing"}
   ```

### Main Agent: Step C — Post-Briefing

After health data is collected:

1. **Offer calendar blocking:** "Want me to block any focus time on your calendar for these priorities?"
2. **First task prompt:** "What do you want to tackle first?" → trigger context surfacing

---

## Subagent Instructions

Everything below is executed by the subagent.

### Step 1: Gather Data (run all in parallel)

#### 1a. Calendar

Today's events across all calendars:
```bash
/opt/homebrew/bin/python3.12 ~/.claude/skills/schedule-meeting/gcal.py --list-events --date today --json --calendar personal
/opt/homebrew/bin/python3.12 ~/.claude/skills/schedule-meeting/gcal.py --list-events --date today --json --calendar wharton
```

This week's events (7-day lookahead):
```bash
/opt/homebrew/bin/python3.12 ~/.claude/skills/schedule-meeting/gcal.py --list-events --from $(date +%Y-%m-%d) --to $(date -v+7d +%Y-%m-%d) --json --calendar personal
/opt/homebrew/bin/python3.12 ~/.claude/skills/schedule-meeting/gcal.py --list-events --from $(date +%Y-%m-%d) --to $(date -v+7d +%Y-%m-%d) --json --calendar wharton
```

#### 1b. Tasks (Things 3)

```bash
things today --json
things inbox --json
things deadlines --json
things upcoming --json --limit 50
```

#### 1c. Counts

```bash
~/bin/daily-summary
```

#### 1d. Activity (silent — log only, never display)

```bash
~/bin/activity-report --yesterday --summary --chrome
```

Return this output in the ACTIVITY_LOG section. **Never include it in the briefing.**

#### 1e. Context reads (parallel)

Read these files (skip silently if missing):
- `~/brain/context/current-state.md`
- `~/brain/context/productivity.md`
- `~/brain/context/lessons.md`
- `~/brain/calibration/factors.md`
- `~/brain/calibration/actuals.jsonl`
- `~/brain/context/goals.md`
- All files matching `*.md` in `/Users/pabloordonezbravo/brain/school/`

Also check if `~/brain/daily/YYYY-MM-DD.md` exists (for today's date). Report in DAILY_FILE_EXISTS.

#### 1f. Calibration catch-up data

Determine "yesterday" (late-night rule: if current hour is 0–2, shift back 1 day).

Pull yesterday's completed tasks:
```bash
things logbook --modified-after=$(date -v-1d +%Y-%m-%d) --modified-before=$(date +%Y-%m-%d) --json
```

Find tasks with time estimates in title: `\((\d+(?:\.\d+)?)\s*(m|min|h|hr)\)`

Cross-reference with `~/brain/calibration/actuals.jsonl` — skip any task already captured (match by task name substring).

Return uncaptured tasks in the CALIBRATION_TASKS section.

#### 1g. Weekly review check

Check for most recent file in `/Users/pabloordonezbravo/brain/weekly/` (use Glob with pattern `*.md` and path `/Users/pabloordonezbravo/brain/weekly`). Note the date of the most recent file. If 7+ days old, flag for the Wellbeing section.

#### 1h. Recent daily logs

Read the last 3 daily log files from `/Users/pabloordonezbravo/brain/daily/` (use Glob with pattern `*.md` and path `/Users/pabloordonezbravo/brain/daily`, take the 3 most recent by filename).

From each file, extract only the `## Completed` and `## Log` sections (skip Screen Time, Health, and other sections). These feed "The Picture" synthesis in Step 2h.

Also read the most recent weekly review file from `/Users/pabloordonezbravo/brain/weekly/` if it exists — extract key themes and open items.

#### 1i. Recent completed tasks

```bash
things logbook --modified-after=$(date -v-3d +%Y-%m-%d) --json
```

Supplements daily logs with recently completed tasks for narrative continuity. Feeds Step 2h.

### Step 1j: Resolve day-of-week names (REQUIRED before composing)

**Do NOT mentally calculate day-of-week names.** LLM day-counting is error-prone. Instead, run this command for every unique date that will appear in the briefing (calendar events, deadlines, start_dates):

```bash
for d in YYYY-MM-DD YYYY-MM-DD ...; do echo "$d $(date -j -f '%Y-%m-%d' "$d" '+%A')"; done
```

Store the resulting date→day mapping and use it as the **sole source of truth** when writing day names in all prose sections. Never infer a day name from arithmetic.

### Step 2: Background Processing (silent — informs prose, never shown)

All of this happens behind the scenes. Results feed into the prose output but are never displayed as tables or metrics.

#### 2a. Time-aware catch-up

Compare current time to calendar events. Events with `end` < now are flagged for catch-up — folded into "The Picture" as a leading question (e.g., "You had [event] at [time] — how'd that go?").

#### 2b. Time slots

- Scheduling window: MAX(now rounded to next 15-min, 8:00 AM) through 11:00 PM
- Find gaps between future events. Merge overlapping/adjacent events.
- **Only surface gaps >= 30 minutes** (raised from 15m)
- Calculate total free hours

#### 2c. Task estimates

Parse from title: `\((\d+(?:\.\d+)?)\s*(m|min|h|hr)\)`

Keyword defaults if no match:
| Keywords | Default |
|----------|---------|
| email, follow up, schedule, book | 20m |
| read, review, prep | 45m |
| write, draft, memo, essay | 90m |
| case, code, analysis, problem set | 150m |
| fallback | 30m |

#### 2d. Calibration factors

Read `~/brain/calibration/factors.md`. Apply category factors silently.

Category rules (same as end-of-day):
1. `class-prep`: "case prep", "quiz prep", or just prep/quiz
2. `case-work`: case, pre-dev, analysis, or task in a REAL project
3. `writing`: write, draft, memo*, essay, application, fellowship, letter
4. `code-analysis`: code, problem set, build, script, skill
5. `reading`: read, review, chapter
6. `admin`: email, follow up, schedule, book, send, buy
7. `fallback`: everything else

*Exception: "memo" in a REAL project → `case-work`*

Compute: `adjusted_min = raw_estimate * factor`, round to nearest 5 min.

**Only surface a calibration warning if factor > 2x** (e.g., "Heads up — case work tasks have historically taken 4x your estimates"). Otherwise, silently use adjusted times for scheduling logic.

#### 2e. Class context

For tasks with `project_title` matching a class:
- Read `~/brain/school/{project_title}.md` (if it exists)
- Find the topic/case for the task's date
- Weave into "What Matters Today" naturally (e.g., "FNCE 7500 on Tuesday covers [topic] — the [case name] needs ~2h of prep")

#### 2f. Bin-packing

Greedy first-fit: explicit estimates first, then descending by duration. Informs prose recommendations but the schedule is never shown as a table.

#### 2g. Deadline scan (two tiers)

**Tier 1 — This week (0-7 days):**
From `things deadlines` and `things upcoming`, extract all tasks with deadlines in the next 7 days.
- Compare `start_date` vs `deadline` — flag tasks where they're equal (no prep time built in)
- Flag tasks with deadlines but no `start_date` at all (unscheduled)
- Check if available calendar time < estimated task time for any deadline — flag capacity risks
- Feed into Watch List and What Matters Today

**Tier 2 — Horizon (8-28 days):**
From the same sources, extract tasks with deadlines 8-28 days out. Surface a task if ANY of:
- Estimated time > 1h
- Belongs to a class project (`project_title` matches a school file)
- Has a deadline but no `start_date` (unscheduled)
- Limit to top 5 by urgency (earliest deadline first)
- Feed into Watch List only

#### 2h. Picture synthesis

Combine data from Steps 1h (daily logs), 1i (completed tasks), 1e (current-state.md, goals.md), and 1g (weekly review) to produce structured notes for "The Picture":

- **Recent momentum**: What has Pablo been shipping? What's the throughput trend?
- **Week-level context**: What's the shape of this week — front-loaded, back-loaded, scattered?
- **Semester arc**: Where does this week sit relative to goals.md objectives?
- **Today's role**: Given the above, what is today's job? (Recovery day, sprint day, prep day, etc.)

**Editorial guidelines — these are non-negotiable:**
- Be specific: name tasks, dates, and projects — not categories
- Connect dots Pablo might not see (e.g., "You shipped 3 deliverables in 2 days but have nothing scheduled until Thursday — good time to catch up on the FNCE reading backlog")
- State the arc plainly — no motivational fluff
- 3-6 bullets max
- **Litmus test: "If a bullet could apply to any MBA student on any week, delete it"**
- If daily logs are sparse, fall back to 2 bullets using logbook data only

#### 2i. Today classification

From `things today`, split items into two buckets:
- **Fresh** — `start_date` == today (legitimately scheduled for today)
- **Stale** — `start_date` < today (rolled over from previous days)

Stale items feed the Rollover triage in the "Inbox & Triage" output section.

### Step 3: Compose Briefing (with Section Delimiters)

Write the briefing in this structure. **Omit any section that would be empty — do NOT emit delimiters for empty sections.** Use bullets, not prose paragraphs — every section should be scannable.

**CRITICAL: Every section MUST be wrapped with `<<<SECTION:id>>>` and `<<</SECTION:id>>>` delimiters.**

```
<<<SECTION:header>>>
## [Day], [Date] — [Time]
<<</SECTION:header>>>

<<<SECTION:picture>>>
### The Picture
[3-6 bullets from Step 2h synthesis. Situational awareness, not calendar narration.

- If past events exist (end < now), lead with a catch-up question:
  "You had **[Event]** at **9:00 AM** — how'd that go?"
- Then: recent momentum → this week's shape → today's role → optional semester connection
- Tone: direct, specific, editorial — like a chief of staff
- Must name specific tasks, dates, and projects — never generic
- **Litmus test: if a bullet could apply to any MBA student on any week, delete it**
- If no events and sparse logs: 2 bullets minimum from logbook data

All-day events mentioned naturally in a bullet if relevant.]
<<</SECTION:picture>>>

<<<SECTION:watch_list>>>
### Watch List
[Bullets — only items needing attention. Does NOT repeat What Matters Today items
unless there's a separate risk to flag.

From Tier 1 (0-7 days) and Tier 2 (8-28 days) deadline scans:
- Each item: **what** — why it matters — suggested action
- Flag: deadlines with no prep time (start_date == deadline), unscheduled work,
  capacity risks (available time < estimated time)
- Tier 2 items marked with horizon context (e.g., "3 weeks out but needs 4h")

Omit section entirely if nothing to flag.]
<<</SECTION:watch_list>>>

<<<SECTION:what_matters>>>
### What Matters Today
[Numbered list only — no preamble paragraphs.

**Draw priorities from deadlines that need work today** — even if their start_date
is later. If a 3h task is due Friday but Wed/Thu are packed, it belongs in today's
priorities. Think forward, not just about what Things labels as "today."

1. **[Top priority]** — one line of reasoning, time estimate, when to do it
2. **[Second priority]** — one line of reasoning, time estimate
3. **[Third priority]** — one line of reasoning, time estimate

Class context woven into the reasoning line naturally.
If calibration factor > 2x, add inline: "(heads up — [category] tasks run [factor]x, so ~[adjusted])"
Forward-looking: include tasks due later if today is the only realistic window to start them.]
<<</SECTION:what_matters>>>

<<<SECTION:loose_ends>>>
### Loose Ends
[TABLE format:
| # | Item | Destination | Urgency |
|---|------|-------------|---------|
| 1 | Mentioned in log but not in Things | → Things inbox | low |
| 2 | Open thread from meeting | → follow-up email | medium |

Sources: daily log mentions, open threads, messages without tasks.
Omit section entirely if nothing to surface.]
<<</SECTION:loose_ends>>>

<<<SECTION:inbox_triage>>>
### Inbox & Triage
[Two sub-sections. Omit each if empty. Omit entire section if both are empty.]

#### Inbox (X items)
[TABLE — same format as before:
| # | Item | Suggested Action |
|---|------|------------------|
| 1 | Task name | Schedule for tomorrow |

Omit if inbox is empty.]

#### Rollover (X stale items)
[**List ALL stale Today items — never trim or cherry-pick.** Pablo needs the full
list to triage. Every item gets a row. TABLE with context-aware suggestions:
| # | Item | Since | Suggested Action |
|---|------|-------|------------------|
| 1 | Weekly review (30m) | Jan 30 | Reschedule → weekend |
| 2 | Passport renewal | Feb 2 | Reschedule → next week |
| 3 | Essay 3 neighborhoods (2h) | Jan 31 | Keep — block time this weekend |

Omit if no stale items.]

"Respond: '1 sat, 2 next week, 3 keep' — or 'skip all'"
<<</SECTION:inbox_triage>>>

<<<SECTION:wellbeing>>>
### Wellbeing
[Bullets only. Only if actionable. Pick from:
- Health patterns worth noting (from daily logs)
- Productivity nudges (from productivity.md)
- Relevant lessons (from lessons.md)
- Weekly review reminder (if 7+ days overdue)
- Energy/sleep observations

Omit section entirely if nothing actionable to surface.]
<<</SECTION:wellbeing>>>

<<<SECTION:health_checkin>>>
### Health Check-in
[Bullets:
- "What have you eaten today so far?"
- "Quick gut check — BMs, consistency, any urgency or blood?"
- "Energy and pain, 1-10."]
<<</SECTION:health_checkin>>>
```

### Edge Cases

| Edge Case | Handling |
|-----------|----------|
| All-day events | Mentioned in prose, don't consume time slots |
| Overlapping events | Merge into single blocked range |
| No time estimate on task | Apply keyword defaults, note count in prose |
| Task larger than biggest slot | Call out in "What Matters Today" with splitting suggestion |
| No calendar events | "Your day is completely free" |
| No tasks | "Nothing scheduled — want to pull from inbox?" |
| Wall-to-wall events | Note no free slots, suggest moving tasks |
| Late night (12am-3am) | Shift date per late-night rule in CLAUDE.md |

### Notes

- Screen time is **always silent** — logged to daily file, never displayed. Surfaced only in weekly review.
- Calibration is **always silent** unless factor > 2x — no tables, no annotations, just adjusted scheduling.
- Class context is **woven in** — never a standalone section.
- Sections are **omitted when empty** — Watch List, Loose Ends, Inbox & Triage, Wellbeing all disappear if nothing to show. Do NOT emit delimiters for empty sections.
- **Bullets over prose** — every section should be scannable. No multi-sentence paragraphs. If you catch yourself writing a paragraph, convert it to bullets.
- When using Glob tool, always use absolute paths — never use `~` in patterns. Use `/Users/pabloordonezbravo/` instead.
- **"Context" is now "Wellbeing"** — uses section ID `wellbeing` and heading `### Wellbeing`.
