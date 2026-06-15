---
title: Anki Export Guide
status: active
tags: [guide, anki, sharing, workflow]
---

# Anki Export Guide

Export your Obsidian flashcards to Anki and share decks with colleagues via CrowdAnki.

---

## Prerequisites

- Anki desktop installed
- Obsidian with your current vault

---

## 1. Install Anki Add-ons

Open Anki → Tools → Add-ons → Get Add-ons:

| Add-on | Code |
|---|---|
| AnkiConnect | `2055492159` |
| CrowdAnki | `1788670778` |

Restart Anki after installing.

### Configure AnkiConnect

Tools → Add-ons → AnkiConnect → Config:

```json
{
    "apiKey": null,
    "apiLogPath": null,
    "webBindAddress": "127.0.0.1",
    "webBindPort": 8765,
    "webCorsOrigin": "http://localhost",
    "webCorsOriginList": [
        "http://localhost",
        "app://obsidian.md"
    ]
}
```

Restart Anki again.

---

## 2. Install Obsidian_to_Anki

Settings → Community Plugins → Browse → search "Obsidian_to_Anki" → Install → Enable.

---

## 3. Configure Obsidian_to_Anki

Open the plugin settings (Settings → Obsidian_to_Anki).

### Scan directory

Under Defaults, set **Scan Directory** to `Knowledge`. This restricts scanning to only your knowledge notes — the plugin won't pick up example text from guides, templates, or other folders.

### Custom Regexps

Settings → Note type settings → expand **Note Type Table**. You'll see a table with a **Custom Regexp** field for each Anki note type. Paste the regex directly — no toggle needed. Empty = default, filled = active.

If the table is empty: scroll to Actions → click **Regenerate Note Type Table** (Anki must be running).

For the `Basic` note type, paste this to handle `word::translation`:
<!--ID: 1776680786837-->


```
^(.*[^\n:]{1}):{2}([^\n:]{1}.*)
```

For multi-line `?` separator, add a second regex for `Basic (and reversed card)` or a separate note type:

```
((?:[^\n][\n]?)+\n)\?((?:\n(?:^.{1,3}$|^.{4}(?<!<!--).*))+)
```

### Enable cloze support

- Toggle **CurlyCloze** ON
- Toggle **CurlyCloze - Highlights to Clozes** ON

This converts highlight syntax (double equals around text) to Anki cloze format.

Leave the `Cloze` note type's Custom Regexp field **empty** — the CurlyCloze + Highlights toggles handle detection automatically without a regex.

Cloze cards must be plain text, not list items. Write `==text==` on its own line, not `- ==text==`.

### Folder-to-deck mapping

Settings → Folder settings → expand **Folder Table**. The plugin lists every vault folder automatically. Find the relevant folders and type the deck name in the **Folder Deck** column:

| Folder (auto-listed)             | Folder Deck            |
| -------------------------------- | ---------------------- |
| `Knowledge/Languages/German`     | `German`               |
| `Knowledge/Languages/English`    | `English`              |
| `Knowledge/Programming`          | `Programming`          |
| `Knowledge/Personal Development` | `Personal Development` |

Leave a folder's deck blank to inherit from its parent folder (or the global default deck).

Each language gets its own deck, so you can export and share them independently (e.g., share only German via CrowdAnki without exposing other languages).

This auto-assigns decks without needing `TARGET DECK` in every note.

---

## 4. First Sync

1. **Anki must be running**
2. In Obsidian: Cmd+P → "Obsidian_to_Anki: Scan vault"
3. The plugin scans all notes, finds cards by regex, and pushes them to Anki via AnkiConnect
4. Media files (`![[image.jpg]]`, `![[audio.mp3]]`) are copied to Anki's `collection.media` automatically
5. The plugin writes `<!--ID:1234567890-->` comments in your notes to track exported cards — don't delete these

### Verify

- Open Anki → Browse → check that cards appeared in the correct decks
- Verify media renders (images show, audio plays)

---

## 5. Share with CrowdAnki

### Export

1. In Anki: File → Export
2. Export format: **CrowdAnki JSON Representation**
3. Select the deck to export (can't export "All Decks" — do one at a time)
4. Choose an output folder (e.g., `~/Shared/Anki-Decks/Languages/`)
5. Result: a JSON file + `media/` folder with all images and audio

### Share via Git (recommended)

```bash
cd ~/Shared/Anki-Decks
git init
git add .
git commit -m "Initial deck export"
git remote add origin <your-repo-url>
git push -u origin main
```

### Colleague setup (one-time)

1. Install Anki + CrowdAnki add-on (`1788670778`)
2. Clone the repo: `git clone <repo-url>`
3. In Anki: File → CrowdAnki: Import from disk → select the deck folder
4. Cards imported with fresh scheduling — they start reviewing from scratch

### Updating (ongoing)

When you add new flashcards:

1. In Obsidian: Cmd+P → "Obsidian_to_Anki: Scan vault" (new cards push to Anki)
2. In Anki: File → Export → CrowdAnki → same folder (overwrites)
3. `git add . && git commit -m "Added new cards" && git push`
4. Colleagues: `git pull` → File → CrowdAnki: Import from disk
   - New cards appear fresh
   - Existing cards update content if changed
   - **Their scheduling/stats are preserved** (matched by note GUID)

---

## 6. Coexistence with obsidian-spaced-repetition

Both plugins are active. This is fine:

- **You** review in Obsidian (SR plugin) as usual
- **Obsidian_to_Anki** exports the same cards to Anki for colleagues
- The `<!--ID:...-->` comments from Obsidian_to_Anki don't interfere with SR scheduling comments `<!--SR:...-->`
- Both parse `::` and `?` independently — no conflict, just parallel operation
- For long-form clozes with `==...==`, avoid multiple highlights in the same block if you review siblings in SR. Repeat the full quote across separate blocks and highlight one span per block.
<!--ID: 1776680786839-->


---

## Quick Reference

| Task | Command |
|---|---|
| Sync to Anki | Cmd+P → Obsidian_to_Anki: Scan vault |
| Export for sharing | Anki → File → Export → CrowdAnki |
| Colleague imports | Anki → File → CrowdAnki: Import from disk |
| Check sync status | Anki → Browse → look for recent cards |
