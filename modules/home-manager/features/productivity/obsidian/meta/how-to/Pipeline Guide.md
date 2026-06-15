---
title: Pipeline Guide
status: active
tags: [workflow, pipeline, process]
---

# Pipeline Guide

```
CAPTURE (Inbox) → DEVELOP (Knowledge) → REVIEW (SR plugin) → ARCHIVE
```

---

## 1. Capture

Everything goes to `Inbox/`. Use the right template. Don't process — just get it in.

| I have a... | Template | Frontmatter `type:` |
|---|---|---|
| Web article | Article | `article` |
| YouTube video | Video | `video` |
| Book I'm reading | Book | `book` |
| Podcast I listened to | Podcast | `podcast` |
| Course lesson | Article or Video | `course` |
| Language lesson / class | Language Lesson | `language` |
| PDF / academic paper | Paper | `paper` |
| Quick thought | Fleeting Note | `fleeting` |
| Quote to memorize | — | Skip Inbox, add directly to `Knowledge/Personal Development/Quotes.md` |

**Rules**: capture the source (URL, author, date). One note per source. Add to IW Queue if worth revisiting.

**Timestamps** are mandatory for videos and podcasts — they're your page numbers.

---

## 2. Develop

Notes live in `Knowledge/` organized by domain. They mature in place:

| Status | You can say... | Looks like |
|---|---|---|
| `seedling` | "I think I understand this" | Rough, tied to source, incomplete |
| `growing` | "I'm connecting this to other things" | Multiple sources, examples, links |
| `evergreen` | "I can explain this to anyone" | Atomic, standalone, your own words |

**When to create a seedling**: when something clicks during an IW session — not before.

**One idea per note.** If a note answers more than one question, split it.

**Flashcards go inline** at the bottom of knowledge notes under `## Flashcards`. The note must have `flashcards` in its `tags:` frontmatter for the SR plugin to detect them:

```
What is X?
?
X is...

word::translation

- ==Key fact== in context for cloze.
```

---

## 3. Review

The `obsidian-spaced-repetition` plugin finds all `## Flashcards` sections and schedules review automatically.

**One fact per card.** No yes/no questions. Include enough context that the card makes sense on its own.

---

## 4. Archive

`Inbox/` is only for active items. When a source note is fully processed, move it out of `Inbox/` into `Archive/`.

- Use archive folders by source type when helpful, e.g. `Archive/Language Workbook/`.
- Keep the archived source note as a record of your work.
- Remove it from the IW queue when you archive it.

---

## How Each Content Type Flows

### Books (fiction, non-fiction)
- **Inbox**: one note per book, chapter notes as you read
- **Knowledge**: seedlings emerge when you notice patterns across chapters — not before
- **You don't know the themes on day 1.** Highlight what resonates, review later, group by pattern

### Philosophy / aphoristic books
- Same as books, but organize by theme instead of chapter
- **You discover themes by re-reading your highlights.** During IW sessions, scan your highlighted passages — you'll start noticing the same ideas coming back. That's when you group them into a seedling.

### Programming courses
- **Inbox**: one note per lesson with code examples
- **Knowledge**: seedling when you understand a concept beyond what the instructor said
- Simple API facts can skip to flashcard directly

### Podcasts / videos
- **Inbox**: one note that grows over time. Start with timestamps while listening, then add "what landed", questions, and connections in later IW sessions. Use **Snipd** only as capture support
- **Seedling first** — hearing something isn't the same as understanding it. Write what landed for you, what you're unsure about, what you want to test.
- Matures to evergreen after you've reflected, connected, or tested the ideas

### Language learning
- **Vocabulary**: skip everything, go straight to inline flashcard (`word::translation`)
<!--ID: 1776680786841-->

- **Grammar**: full pipeline when you need to understand WHY
- **Workbook notes**: keep the exercises in `Inbox/` while active, extract reusable rules into `Knowledge/Languages/[Language]/`, then archive the workbook note when the unit is done
- **Class corrections are gold** — they reveal your actual mistakes

### Quotes
- Skip Inbox entirely → add to `Knowledge/Personal Development/Quotes.md`
- Use cloze format: `==key phrase== rest of quote` (no `- ` list prefix — plain text for Anki export compatibility)
- For long quotes, speeches, or poems, repeat the full passage across separate blocks and highlight one phrase per block so SR and Obsidian_to_Anki both stay stable

---

## When to Skip Stages

| Situation | Do this |
|---|---|
| Simple vocab or fact | Inbox → inline flashcard |
| Quote | Straight to Quotes.md |
| Complex concept | Full pipeline: seedling → growing → evergreen |

---

## Mobile

The IW plugin is desktop-only. On mobile, the workflow is intentionally scoped:

| Works on mobile | Requires desktop |
|---|---|
| Capture (Quick Capture, fleeting notes) | IW sessions |
| SR flashcard review | Processing / seedling creation |
| Reading and annotating notes | PDF++ annotations |
| Snipd audio clips / synced raw notes | Queue management |

Don't try to replicate the full pipeline on mobile. Use it for **capture + review** and process on desktop.

---

## Daily Cadence

- **Morning**: review due flashcards (SR plugin), one IW session (20 min)
- **Weekly**: promote seedlings, update connections
- **Monthly**: review Inbox for stale items, archive what's done

---

## Quick Reference

| I have... | It goes to... |
|---|---|
| Something to consume | `Inbox/` with template |
| Something I understand | `Knowledge/[Domain]/` as seedling |
| Something I've synthesized | `Knowledge/[Domain]/` as evergreen |
| Something to memorize | `## Flashcards` in the knowledge note |
| A quote | `Knowledge/Personal Development/Quotes.md` |
| Finished source/workbook note | `Archive/...` |
| Daily log | `Daily/` |
| Work stuff | `Work/` |
