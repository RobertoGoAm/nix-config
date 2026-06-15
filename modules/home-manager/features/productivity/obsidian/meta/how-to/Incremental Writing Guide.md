---
title: Incremental Writing Guide
status: active
tags: [guide, workflow, incremental-writing, IW]
---

# Incremental Writing Guide

IW is spaced repetition for reading. Instead of finishing one thing before starting the next, you process multiple sources in small pieces across sessions.

---

## Setup

Your queue lives in `IW-Queues/IW-Queue.md`. The plugin manages scheduling automatically.

## Commands

| Command | What it does |
|---|---|
| **IW: Next repetition** | Opens the next due item. Start here. |
| **IW: Add note to queue** | Adds current note to the queue with a priority. |
| **IW: Dismiss current repetition** | Skip for now, it comes back later. |
| **IW: Add block to queue** | Add a specific section instead of the whole note. |
| **QuickAdd: Process to Knowledge** | Moves the active `Inbox` note into a chosen `Knowledge/...` folder and sets `type: permanent`, `status: seedling`. |
| **QuickAdd: Promote to Growing** | Changes the active knowledge note to `status: growing`. |
| **QuickAdd: Promote to Evergreen** | Changes the active knowledge note to `status: evergreen`. |
| **QuickAdd: Archive Current Workbook** | Moves the active workbook note out of `Inbox/` into `Archive/Language Workbook/` and removes it from `IW-Queues/IW-Queue.md`. |

## Priority

Lower number = shows up sooner and more often.

| Priority | Use for |
|---|---|
| 10-20 | Active study material (course, workbook) |
| 20-30 | Books you're reading |
| 25-35 | Articles clipped this week |
| 30-40 | Podcasts/videos already consumed |
| 50-70 | Background reading |
| 80+ | Someday/maybe |

---

## A Session (~20 min)

1. **Cmd+P → IW: Next repetition**
2. The plugin opens your next due note
3. What you do depends on the content:
   - **Reading material**: read for 10-20 min, highlight with `==text==`, note reactions
   - **Workbook**: do 1-2 exercises, check answers, note mistakes
   - **Already consumed (podcast/video)**: review notes, extract knowledge notes and flashcards
4. When done with this item: **IW: Next repetition** to get the next one
5. Process 2-5 items per session. Stop when time's up.

**The key moment**: when something clicks — a pattern you notice, a concept that makes sense — create a seedling in `Knowledge/`. Don't wait. That's the whole point.

---

## Tips

- **Short daily sessions beat long weekly ones.** 20 min/day > 3 hours on Sunday.
- **Don't add everything at once.** Add items as they enter Inbox.
- **It's OK to dismiss.** Not in the mood? Skip it. It comes back.
- **Extract flashcards during the session**, not after. The moment you understand is the best time to write the card.
- **Remove items when fully processed.** All exercises done, knowledge extracted, flashcards created → remove from queue.
- **Archive finished source notes out of Inbox.** `Inbox/` should only contain active items. For workbook notes, use **QuickAdd: Archive Current Workbook** when the unit is done.
