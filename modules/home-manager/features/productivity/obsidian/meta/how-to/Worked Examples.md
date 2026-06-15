---
title: Worked Examples
status: active
tags: [guide, examples, workflow]
---

# Worked Examples

Step-by-step walkthroughs from beginning to end for every content type. Follow these exactly.

---

## 1. Book (El Quijote)

### Adding it

1. Cmd+P → **QuickAdd: Capture Book** → type "El Quijote"
2. Fill in the template fields you know:
   - Author: Miguel de Cervantes
   - Pages: 940
   - Status: Not Started
   - Why I'm Reading This: "Classic Spanish literature, cultural reference"
3. Leave Summary, Key Takeaways, Connections blank — you haven't read it
4. Open command palette → **IW: Add note to queue**
   - Priority: **25** (you're reading it regularly but it's not urgent)

### Reading Chapter 1

1. IW session → **IW: Next repetition** → your El Quijote note opens
2. If reading a PDF/ebook: open it with **PDF++** in a side pane, highlight passages as you go — they can be extracted as annotations. If physical book: take photos of key pages or type notes manually.
3. Read Chapter 1. Write raw notes **under a chapter heading** as you go:
   ```
   ### Chapter 1
   - Alonso Quijano reads too many chivalry books, loses his mind
   - Renames himself Don Quijote, horse → Rocinante, lady → Dulcinea
   - The renaming feels important — he rebuilds reality through language
   - First sally: attacks windmills, gets beaten up
   ```
3. Don't write a summary. Don't interpret. Just capture what happens and what strikes you.
4. Update Status: `Reading`
5. **IW: Next repetition** → move to next item in queue

### Reviewing next IW session (2-3 days later)

1. **IW: Next repetition** → El Quijote comes back
2. Re-read your Chapter 1 notes. Read Chapter 2. Add notes under `### Chapter 2`.
3. You're starting to notice a pattern — the renaming, the self-deception, the gap between what Quijote sees and what's really there. Note it:
   ```
   > Pattern: Quijote consistently replaces reality with his chivalric fantasy.
   > Inns become castles, peasants become knights. Is this madness or choice?
   ```
4. **IW: Next repetition** → move on

### Creating a seedling (after 3-4 chapters)

The pattern is now clear enough. Create a knowledge note:

1. Create `Knowledge/Books/El Quijote/El Quijote - Chapters 1-4.md`
2. Frontmatter: `status: seedling`, `type: permanent`
3. Write your understanding so far — not a summary, your interpretation:
   ```
   # El Quijote - Chapters 1-4

   ## What I see so far
   Quijote doesn't just go mad — he actively reconstructs reality.
   The renaming (himself, Rocinante, Dulcinea) is the foundation.
   Once named, everything follows the chivalric logic.

   The comedy comes from the gap between his version and reality.
   But Cervantes doesn't clearly say he's wrong — other characters
   sometimes go along with it.

   ## Questions
   - Is Sancho a counterpoint or does he get pulled in too?
   - Does Quijote know on some level?
   ```
4. Don't add flashcards yet — you don't understand the book well enough

### Growing the note (over weeks)

As you read more chapters:
- Update the seedling with new observations
- Change status to `growing` when you start connecting to other things
- When you notice a standalone concept (e.g., "idealism that replaces reality"), extract it:

Create `Knowledge/Books/El Quijote/The Madness of Idealism.md`:
- `status: evergreen`
- Write it so someone who hasn't read El Quijote can understand it
- Now add `## Flashcards` at the bottom:
  ```
  ## Flashcards

  What is the "madness of idealism" pattern in literature?
  ?
  When a character imposes an ideal vision onto reality so thoroughly
  that it replaces reality. Seen in Don Quijote (chivalric fantasy),
  Madame Bovary (romantic fantasy), Gatsby (American dream).
  ```

### When to remove from IW Queue

When you finish the book AND have extracted all knowledge notes and flashcards. Move the source note out of `Inbox/` into your archive/reference area so `Inbox/` only contains active items.

---

## 2. Programming Course (React useEffect)

### Adding it

1. Cmd+P → **QuickAdd: Capture Article** → type "React Hooks - useEffect"
2. Fill in: source URL, course name
3. **IW: Add note to queue** → Priority: **15** (active study, you need this for work)

### Watching the video

1. IW session opens the note
2. Take notes while watching:
````
   ## Watching Notes
   - useEffect(callback, deps)
   - Empty deps [] = run once after mount
   - No deps = every render (usually wrong)
   - Instructor: "think of it as synchronization, not lifecycle"
     - not sure what this means yet
   - Cleanup function runs before next effect

   ## Code Examples
   ```javascript
   useEffect(() => {
     const controller = new AbortController();
     fetch('/api/data', { signal: controller.signal })
       .then(res => res.json())
       .then(setData);
     return () => controller.abort();
   }, [userId]);
   ```
````
3. **IW: Next repetition** → move on

### Creating a seedling (next session)

1. IW session → your React note comes back
2. Re-read your notes. The "synchronization" idea clicks now — deps aren't about "when to run", they're about "what am I keeping in sync with"
3. Create `Knowledge/Programming/React/React Hooks - useEffect.md`
   - `status: seedling`
   - Write what you understand, not what the instructor said:
```
     The dependency array answers: "what values does this effect
     synchronize with?" When those values change, the effect re-syncs.

     This reframes everything:
     - [] means "sync with nothing" (run once)
     - [userId] means "stay in sync with userId"
     - no array means "sync with everything" (usually wrong)
```
 
4. **IW: Next repetition** → move on

### Maturing to evergreen (after more lessons)

After watching cleanup, common mistakes, and advanced patterns videos:

1. Your seedling has grown. Create the evergreen:
   `Knowledge/Programming/React/useEffect as Synchronization.md`
   - `status: evergreen`
   - The mental model that makes everything click
   - Add `## Flashcards`:
```
     ## Flashcards

     What is the correct mental model for useEffect?
     ?
     Synchronization, not lifecycle. Ask "what am I synchronizing?"
     not "when should this run?"

     What do the three dependency array patterns mean?
     ?
     - [a, b] → re-sync when a or b change
     - [] → sync with nothing (once)
     - no array → sync with everything (usually wrong)

     What is the stale closure problem?
     ?
     Effects close over the state from their render. An effect with
     [] deps always sees initial values. Fix: add deps or use useRef.
```

### When to remove from IW Queue

When you've watched all the lessons on this topic and extracted your knowledge notes and flashcards. If the course continues with other topics, create separate inbox notes for those.

---

## 3. Language — Workbook (Grammatik aktiv)

### Adding it

1. Cmd+P → **QuickAdd: Quick Capture** → type "German - Personalpronomen (Grammatik aktiv 1)"
2. Use the Language Lesson template
3. **IW: Add note to queue** → Priority: **15** (active study, high frequency)

### First session — learning the rule + exercises

1. IW session opens the note
2. Open the workbook PDF with **PDF++** in a side pane — read the grammar explanation and view exercises there
3. Add a `## Grammar Rule` section near the top of the note:
   ```
   ## Grammar Rule
   | | Singular | Plural |
   |---|---|---|
   | 1st | ich | wir |
   | 2nd informal | du | ihr |
   | 2nd formal | Sie | Sie |
   | 3rd | er / sie / es | sie |
   ```
3. Do exercises INSIDE the note — it's a workspace:
   ```
   ## Exercise 1
   1. ___ heißt Maria. → **Sie** ✓
   2. ___ kommen aus Spanien. → **Wir** ✓
   3. Woher kommt ___? → **ihr** ✓

   ## Exercise 2
   1. Der Löffel (spoon) → ___ → **es** ❌ → should be **er** (masculine!)
   ```
4. The mistake reveals a gap — objects use grammatical gender, not natural gender
5. **IW: Next repetition** → move on. The note comes back in 1-2 days.

### Second session — more exercises + knowledge extraction

1. IW session → Personalpronomen comes back
2. Do Exercises 3-4. You're getting the pronouns right now.
3. Extract two small knowledge notes:
   - `Knowledge/Languages/German/Personal Pronouns (Nominative).md`
   - `Knowledge/Languages/German/Noun Gender and Pronouns.md`
4. Add atomic flashcards to those notes:
   ```
   German 1st person singular pronoun::ich
   German 1st person plural pronoun::wir
   German 2nd person informal singular pronoun::du
   German 2nd person informal plural pronoun::ihr
   German 2nd person formal pronoun::Sie
   German 3rd person masculine singular pronoun::er
   German 3rd person feminine singular pronoun::sie
   German 3rd person neuter singular pronoun::es
   German 3rd person plural pronoun::sie

   What pronoun does a masculine noun take in German?
   ?
   er

   What pronoun does a feminine noun take in German?
   ?
   sie

   What pronoun does a neuter noun take in German?
   ?
   es

   What pronoun does a plural noun take in German?
   ?
   sie
   ```
5. **IW: Next repetition** → move on

### Third session — wrapping up

1. Do remaining exercises. Review flashcards (SR plugin handles scheduling).
2. The noun-gender note has grown — add more patterns from Hammer's, change it to `status: growing` when it starts connecting to other grammar notes
3. If all exercises are done and knowledge extracted → archive the workbook note with:
   `Cmd+P → QuickAdd: Archive Current Workbook`
4. Create the next unit's note: `Inbox/German - Verben Präsens (Grammatik aktiv 2).md` → Priority 15

### When to remove from IW Queue

When all exercises are done and all grammar rules have been extracted to Knowledge notes with flashcards. Archive the workbook note out of `Inbox/`; it stays as a record of your work in `Archive/Language Workbook/`.

---

## 4. Language — Vocabulary

### The approach

Vocabulary doesn't need the full pipeline. It goes straight to flashcards. The question is where the vocabulary comes from and how to enrich cards.

### From any source (class, workbook, podcast, reading)

Whenever you encounter a new word, add it as an inline flashcard in the relevant knowledge note. If there's no specific knowledge note, add to a vocabulary collection:

Create `Knowledge/Languages/German/German Vocabulary A1.md` (or the equivalent folder for another language):
```
---
type: permanent
status: evergreen
tags: [permanent, german, vocabulary, A1, flashcards]
---

# German Vocabulary A1

## Flashcards

### Unit 1 — Introductions
die Begrüßung::the greeting
der Nachname::the surname
die Herkunft::the origin
sich vorstellen::to introduce oneself

### Unit 2 — Family
die Geschwister::the siblings
der Verwandte::the relative
```

### Real example — noun gender from a grammar mistake

If a grammar exercise shows that the real gap is noun gender, keep the grammar rule in the grammar note and put the concrete noun drills in the vocabulary collection:

```
Knowledge/Languages/German/Noun Gender and Pronouns.md

## Flashcards
German pronoun for masculine nouns::er
German pronoun for feminine nouns::sie
German pronoun for neuter nouns::es
German pronoun for plural nouns::sie
```

```
Knowledge/Languages/German/German Vocabulary A1.md

## Flashcards
cake, with article::der Kuchen

`der Kuchen` -> pronoun in "Möchten Sie Kuchen? ___ ist sehr gut."::Er
```

### Adding images

Embed an image directly in the flashcard for visual association:

```
What is "der Schmetterling"?
?
The butterfly
![[schmetterling.jpg]]
```

Save the image in a folder like `000 Meta/Assets/` or alongside the note. The SR plugin renders images in review.

### Adding audio / TTS

The SR plugin doesn't have built-in TTS. Two approaches:

**Option A — Audio files**: Record or download pronunciation, save as `.mp3`, embed in the card:
```
How do you pronounce "Eichhörnchen"?
?
![[eichhoernchen.mp3]]
Squirrel. One of the hardest German words to pronounce.
```
<!--ID: 1776680786845-->


**Option B — External TTS during review**: Use macOS text-to-speech (System Settings → Accessibility → Spoken Content → enable "Speak selection"). During review, select the word and press the keyboard shortcut to hear it. No plugin needed.

### When to review

The SR plugin handles scheduling. Just do your daily reviews. Vocabulary cards are high-volume, low-effort — aim for consistency over intensity.

---

## 5. Language — Company English Lessons

### Adding it

1. After class, create a note: `Inbox/English Class - 2026-04-19.md`
2. Use the Language Lesson template
3. **IW: Add note to queue** → Priority: **30** (review within a few days)

### During / after class

Capture everything that happened:
```
## Topic
Conditionals — second and third

## What was taught
- Second conditional: If + past simple, would + infinitive
- Third conditional: If + past perfect, would have + pp
- Mixed conditionals exist but weren't covered today

## Corrections (most valuable part)
- I said "if I would go" → ❌ should be "if I went"
- I confused "unless" with "if not" — teacher says they're not always the same

## New vocabulary
provided that::siempre que
in case::en caso de que
as long as::siempre y cuando

## Exercises / drills
- Built 5 sentences with second conditional
- Role play: "what would you do if..."
```

### Processing (next IW session)

1. IW session → class note comes back
2. **Vocabulary**: already captured as `word::translation` inline — SR will pick these up
<!--ID: 1776680786843-->

3. **Corrections**: these reveal your actual mistakes. Turn them into flashcards in a knowledge note:
   ```
   Knowledge/Languages/English Conditionals - The Reality Gradient.md

   ## Flashcards
   - A common error for Spanish speakers: ==using "would" in the
     if-clause is always wrong==. Say "If I went" ✓, never
     "If I would go" ❌.
   ```
4. **Grammar that confused you**: if the conditionals don't make sense, create a seedling and work through the full pipeline
5. **Grammar you understood**: turn it into flashcards directly

### When to remove from IW Queue

After one review session. Class notes don't need repeated processing — the value is in the corrections and vocabulary you extracted.

---

## 6. Language — LingQ Reading / Mini Stories

### Adding it

1. Create a note: `Inbox/German - LingQ Mini Story 12.md`
2. Use the Language Lesson template
3. Fill in:
   - Language: German
   - Source: LingQ
   - Status: In Progress
4. **IW: Add note to queue** → Priority: **20** (active language study)

### While reading / listening in LingQ

LingQ already tracks your word exposure. Don't duplicate that by dumping every blue/yellow word into Obsidian.

Capture only:
- phrases you want to reuse
- grammar patterns you notice repeatedly
- sentences you partly understand but can't fully explain
- mistakes in comprehension you want to revisit

Write into the note as you go:

```
## Lesson Notes
- [Paragraph 2] `um ... zu` = "in order to"
- [Paragraph 3] `Ich freue mich darauf` — I get the sense, but why `darauf`?
- [Paragraph 4] `als ich klein war` = "when I was little"
- [Paragraph 5] Repeated pattern: verb at the end in subordinate clauses
- [Paragraph 6] Useful chunk: `Das kommt darauf an`
```

If LingQ has a saved phrase or sentence you care about, rewrite it here in your own words or copy only the relevant line. The Obsidian note is for your understanding, not for mirroring LingQ's database.

### First IW session — adding understanding

1. **IW: Next repetition** → the LingQ note comes back
2. Re-read your captures and fill `## What Landed` and `## Questions`:
   ```
   ## What Landed
   - This lesson gave me more feel for subordinate-clause word order.
   - `Das kommt darauf an` feels like a chunk I should learn whole.
   - `um ... zu` is worth keeping because it appears often and is easy to reuse.

   ## Questions
   - Why is it `sich freuen auf` in one place and `sich freuen über` in another?
   - Do I understand subordinate clauses, or am I only recognizing them?
   ```
3. Keep the note focused on what changed in your understanding. Don't turn it into a word dump.

### Second IW session — extraction and review

1. **Vocabulary worth keeping** → add only the high-value items as inline flashcards:
   ```
   um ... zu::in order to
   Das kommt darauf an.::That depends.
   ```
2. **Grammar patterns** → if repeated enough, add them to an existing knowledge note or create a small seedling:
   `Knowledge/Languages/German/Subordinate Clause Word Order.md`
   - `status: seedling`
3. **Unclear sentences** → replay the LingQ audio or reread the sentence slowly. If still unclear, note the question for a teacher or grammar reference.
4. **Speaking/writing reuse** → add one short production card if the chunk is worth using actively:
   ```
   How do you say "That depends" in German?
   ?
   Das kommt darauf an.
   ```

### When to remove from IW Queue

After you've extracted the useful chunks/patterns. LingQ itself provides repeated exposure; Obsidian is where you keep only what changed your understanding. Usually 1-2 IW sessions.

---

## 7. Language — Audio Lessons / Podcasts (e.g., Coffee Break German)

### Adding it

1. Create `Inbox/Coffee Break German - Episode 12.md` using the Podcast template
2. Fill in: podcast name, episode, URL, duration
3. **IW: Add note to queue** → Priority: **20** (active language study)

### While listening

Use **Snipd** to mark interesting audio moments as you listen. On the free tier, think of it primarily as an **audio capture aid**. The note you process is still your normal podcast note.

Write into the note as you listen:

```
## Listening Notes
- [00:59] Jahresrückblick = annual review
- [01:20] etwas Revue passieren lassen = look back over something step by step
- [06:20] in Erinnerung rufen = recall something
- [06:30] Grammar: wir + infinitive sounds like a suggestion / "let's ..."
- [07:00] Replay later — exact wording still unclear
```

If Snipd synced a raw note into `Inbox/Data/...`, use it only to help you fill gaps. Do not process the synced note directly, and do not turn your inbox note into a dump of clips/transcripts. Rewrite the useful parts into your own note.

### First IW session — adding understanding

1. **IW: Next repetition** → the episode note comes back
2. Re-read your listening notes. Add what seems important:
   ```
   ## What Landed

   This episode isn't just vocab. It's about how German talks about
   memory and reviewing the past.

   "Etwas Revue passieren lassen" feels more sequential than just
   "remember" — like walking back through events in order.

   "In Erinnerung rufen" seems more like actively bringing something
   back to mind.

   ## Questions
   - Is "Revue passieren lassen" common in normal speech or mainly formal?
   - Does "in Erinnerung rufen" always take an object?
   ```
3. Keep writing in the same note. Don't create a knowledge note yet unless something clearly stands alone.

### Second IW session — extracting vocabulary and grammar

1. **Vocabulary** → add to your vocabulary collection note as inline flashcards:
   ```
   Jahresrückblick::annual review
   etwas Revue passieren lassen::to mentally review / look back over
   in Erinnerung rufen::to recall / bring to mind
   ```
2. **Grammar patterns** → if new, add to the relevant knowledge note. If you already have a note on Konjunktiv II, add this example to it.
3. **Unclear parts** → replay the marked timestamp or Snipd clip. If still unclear, note the question for your teacher.
4. If one pattern is worth keeping, create a small seedling:
   `Knowledge/Languages/German/Language for Recalling the Past.md`
   - `status: seedling`
   - Write the distinction in your own words
5. **Audio cards** → if pronunciation matters, record the phrase or save a clip:
   ```
   What German phrase means "to recall / bring something to mind"?
   ?
   in Erinnerung rufen
   ![[in-erinnerung-rufen.mp3]]
   ```

### When to remove from IW Queue

After you've extracted the useful vocabulary/grammar and any small seedling the episode triggered. Usually 1-2 IW sessions.

---

## 8. Language — Reference Book (Hammer's German Grammar)

### The approach

You don't read Hammer's cover to cover. You look things up when confused.

### When to use it

1. You're doing a Grammatik aktiv exercise and get something wrong
2. A class correction doesn't make sense
3. A grammar rule feels arbitrary and you want to understand WHY

### How to use it

1. If PDF: open with **PDF++**, search for the section, highlight key rules
2. Look up the section (e.g., Chapter 1: Noun Gender)
3. Open your existing knowledge note on the topic (e.g., `German Noun Gender.md`)
3. Add what Hammer's explains — the deeper patterns, the exceptions, the reasoning:
   ```
   ## From Hammer's (Ch. 1)
   - Diminutives (-chen, -lein) are ALWAYS neuter, overriding natural gender
   - Compound nouns take the gender of the LAST component: die Haustür (die Tür)
   - Most nouns ending in -ung are feminine — no exceptions
   ```
4. Update the note's status if your understanding deepened
5. Add new flashcards for the patterns:
   ```
   What gender are German diminutives (-chen, -lein)?
   ?
   Always neuter (das). das Mädchen, das Brötchen, das Büchlein.
   ```

### IW Queue?

Don't add Hammer's to the queue. It's a reference book — use it on demand when a gap appears.

---

## 9. Podcast (Huberman — Sleep Optimization)

### Adding it

1. Cmd+P → **QuickAdd: Quick Capture** → type "Huberman - Sleep Optimization"
2. Apply the Podcast template manually (Cmd+P → Templater → insert Podcast)
3. Fill in: podcast name, episode URL, duration
4. **IW: Add note to queue** → Priority: **30** (already listened, needs processing)

### While listening

Use **Snipd** to clip the key moments as you listen. Use the same raw-capture pattern as the Coffee Break example above:

1. Let Snipd capture audio clips while you listen
2. If a raw synced note appears in `Inbox/Data/...`, treat it as source material, not as your working note
3. Pull only the claims, timestamps, and experiments worth keeping into your normal inbox note
4. Replay the audio clip and summarize it yourself whenever the transcript is missing or noisy

Your note after listening might look like:

```
## Listening Notes
- [12:30] Morning sunlight within 30-60 min of waking — sets cortisol pulse
  Not through a window. 5-10 min sunny, 15-20 cloudy.
- [28:00] Two sleep forces: circadian rhythm + adenosine (sleep pressure)
  Caffeine blocks adenosine receptors but doesn't remove it
- [45:00] Delay caffeine 90-120 min after waking
  Adenosine clears naturally first; caffeine too early = afternoon crash
- [1:15:00] Hot shower 1-2h before bed — vasodilation then compensatory cooling
- [1:40:00] Supplements in order of evidence:
  1. Magnesium threonate 300-400mg
  2. L-Theanine 100-400mg
  3. Apigenin 50mg
  NOT melatonin (it's a hormone, doses too high)
```

### First IW session — adding what landed

You listened to 2 hours of content. You captured timestamps. But hearing something isn't the same as understanding it or knowing what matters to you.

1. Re-read your notes. In the same inbox note, add:
   ```
   ## What Landed

   The morning sunlight thing seems like the highest leverage habit.
   It's free and it affects the whole circadian system.

   The caffeine timing explains my afternoon crashes better than any
   supplement section did.

   Supplements are lower-confidence. Interesting, but not yet action.

   ## Questions
   - Does sunlight through a window really not count? Why?
   - How does this change if I wake before sunrise?
   ```
2. Now ask: what actually changes how I behave?
3. Create a seedling only from what survived that filter:
   `Knowledge/Personal Development/Sleep Optimization Protocol.md`
   - `status: seedling`
   - Write the condensed version:
     ```
     ## What I'm taking from this
     The morning sunlight thing seems like the highest leverage —
     one free habit that sets the whole circadian clock.

     The caffeine timing explains my afternoon crashes. I drink
     coffee immediately. Worth trying the 90-min delay.

     Not sure about the supplements. Need to look into magnesium
     threonate more before committing.

     ## Questions
     - Does sunlight through a window really not count? Why?
     - How does this interact with shift work?
     ```

### Second IW session — growing and connecting

1. IW session → note comes back
2. You tried the caffeine delay for a week. It works. Update the note with your experience.
3. You looked up magnesium threonate — found it's specifically for brain bioavailability. Add that.
4. Connect to other things you know — maybe your fitness note, maybe a sleep book you read.
5. Change status to `growing`

### Third IW session — evergreen + flashcards

1. You now know what works for you and why. Rewrite as a clean protocol.
2. Change status to `evergreen`
3. Add `## Flashcards`:
   ```
   ## Flashcards

   What is the single most effective free tool for better sleep?
   ?
   Morning sunlight within 30-60 min of waking. Not through a window.
   5-10 min sunny, 15-20 cloudy. Sets the cortisol pulse.

   Why delay caffeine 90-120 min after waking?
   ?
   Adenosine clears naturally in the first 90 min. Caffeine too early
   masks this → afternoon crash when it wears off.

   - The optimal bedroom temperature for sleep is ==65-68°F (18-20°C)==.
   ```

### When to remove from IW Queue

After you've processed the content, tested what matters to you, and extracted flashcards. Usually 2-3 sessions over a couple of weeks.

---

## 10. Short Explainer Video (3Blue1Brown — Linear Algebra)

### Adding it

1. Cmd+P → **QuickAdd: Capture Video** → type "3Blue1Brown - Essence of Linear Algebra"
2. Fill in: URL, channel, duration
3. **IW: Add note to queue** → Priority: **30**

### While watching

Write into the same sections your template already gives you. These videos are about building visual understanding:

```
## Watching Notes
- [2:00] Three perspectives on vectors:
  Physics (arrows), CS (ordered lists), Math (abstract objects)
- [5:30] Coordinates = instructions from origin to tip
  [3, -2] means: walk 3 right, 2 down
- [9:00] Addition: geometrically chain arrows, algebraically add components
- [12:00] "Scalar" because it SCALES the vector
  2 × [3, -2] = [6, -4] — twice as long, same direction
```

### First IW session — seedling

You watched the video and took notes. But can you actually explain vectors to someone without looking at your notes? Probably not yet.

1. In the same inbox note, fill `## What Landed` and `## Questions`:
   ```
   ## What Landed
   Vectors are just lists of numbers, but the insight is thinking of
   them as arrows from the origin. The numbers are "walking instructions."

   Addition chains arrows end-to-end. Multiplication stretches/shrinks.

   ## Questions
   - Why does the physics vs CS distinction matter?
   - What happens with 3+ dimensions — can't visualize
   ```
2. The gaps you find are valuable — they tell you what to focus on in the next video
3. If the idea now stands on its own, create:
   `Knowledge/Programming/Linear Algebra Basics.md`
   - `status: seedling`

### Second IW session — growing + flashcards

1. IW session → note comes back
2. You've watched the next video in the series (linear combinations, span). Update the note with new understanding.
3. The original concepts now make more sense in context. Rewrite the parts you were unsure about.
4. Change status to `growing`
5. Add flashcards for what you're confident about:
   ```
   ## Flashcards

   What do vector coordinates represent geometrically?
   ?
   Instructions for walking from the origin to the tip.
   [3, -2] = walk 3 right, 2 down.

   What is scalar multiplication and why "scalar"?
   ?
   Multiplying each component by a number. Called "scalar" because
   it SCALES the vector — stretching, squishing, or flipping it.
   ```

### When to remove from IW Queue

When you've watched all the videos in the series you plan to watch and extracted your understanding. If it's a single standalone video, 2-3 sessions is usually enough.

---

## 11. Philosophy Book (Meditations — Marcus Aurelius)

### Adding it

1. Cmd+P → **QuickAdd: Capture Book** → type "Meditations - Marcus Aurelius"
2. Fill in: Author, pages, why you're reading it
3. **IW: Add note to queue** → Priority: **25**

### While reading

If reading a PDF: open with **PDF++** alongside your inbox note — highlight directly in the PDF, then copy key passages into your note. If physical book: type or photograph key passages.

Just highlight what resonates. Use `==text==` for cloze candidates. Don't try to categorize or label anything — you don't know the themes yet.

```
### Book 2
> 2.1: ==Begin each day by telling yourself: Today I shall be meeting
> with interference, ingratitude, insolence, disloyalty==

My reaction: this is about preparing your response, not preventing bad things

> 2.14: Even if you were to live three thousand years... remember that
> no one loses any life other than the one now being lived

### Book 4
> 4.3: ==The happiness of your life depends upon the quality of your thoughts==

### Book 5
> 5.20: ==The impediment to action advances action.
> What stands in the way becomes the way.==

My reaction: same idea as 2.1 — what you can't control becomes raw material
```

### How themes emerge (IW session, weeks later)

1. IW session → Meditations comes back
2. Re-read your highlights. Don't read new material this session — just scan what you've marked.
3. You notice: 2.1, 5.20, and several others all circle the same idea — the distinction between what you can and can't control.
4. **That's the moment.** Create a seedling:

`Knowledge/Personal Development/Meditations - The Dichotomy of Control.md`
- `status: seedling`
- Gather the related passages
- Write your interpretation of how they connect

### Growing the seedling

Over more reading sessions:
- You find more passages on this theme → add them to the note
- You connect it to Epictetus (the original source of the idea)
- You see the link to CBT
- Change status to `growing`

### Creating the evergreen

When your understanding stands alone — someone who hasn't read Meditations can get it:

`Knowledge/Personal Development/The Dichotomy of Control.md`
- `status: evergreen`
- The universal principle, your words, with examples from multiple contexts
- Flashcards inline:
  ```
  ## Flashcards

  What is the Stoic Dichotomy of Control?
  ?
  The distinction between what's in your power (judgments, effort,
  responses) and what isn't (outcomes, others, events). Direct all
  energy toward the first; accept the second without resistance.

  - ==The impediment to action advances action. What stands in the
    way becomes the way.== (Meditations 5.20)

  - ==Begin each day by telling yourself: Today I shall be meeting
    with interference, ingratitude, insolence== (Meditations 2.1)
  ```

### Key difference from fiction

Don't organize by chapter. Themes cut across the entire book. Let them emerge from your highlights — don't plan them.

### When to remove from IW Queue

When you finish reading AND have extracted all themes into knowledge notes. This takes months for a dense philosophy book. That's fine.

---

## 12. PDF (Academic Paper, Technical Documentation)

### Adding it

1. Save the PDF to your vault (e.g., `Inbox/` or a dedicated `Inbox/PDFs/` subfolder)
2. Install the **PDF++** plugin if not already installed — it lets you annotate and highlight PDFs directly in Obsidian
3. Create an inbox note: Cmd+P → **QuickAdd: Quick Capture** → type the paper/doc title
4. In the note, link to the PDF: `![[paper-name.pdf]]` or `[[paper-name.pdf]]`
5. **IW: Add note to queue** → Priority depends on urgency:
   - For work/study: **15-25**
   - For background reading: **40-60**

### Reading and annotating

1. IW session → your note opens
2. Open the linked PDF in Obsidian (PDF++ renders it in a pane)
3. Read a section at a time — you don't have to finish in one session
4. Highlight key passages in PDF++ — highlights can be extracted as annotations
5. In your inbox note, write down what the section says:
   ```
   ## Reading Notes

   ### Section 2 — Methodology
   - They used a transformer architecture with 6 attention heads
   - Key insight: pre-training on unlabeled data, then fine-tuning
   - Figure 3 shows the attention patterns — interesting that it
     learns syntactic structure without being told about grammar

   ### Section 4 — Results
   - 95.2% accuracy on benchmark, but only 78% on adversarial examples
   - The gap suggests the model is pattern-matching, not "understanding"
   ```
6. **IW: Next repetition** → move on

### Creating a seedling (after reading enough)

1. IW session → paper comes back. Re-read your notes.
2. In the same inbox note, add:
   ```
   ## What I Understand
   Attention lets the model decide which parts of the input to
   focus on for each part of the output. It's a learned weighting,
   not a fixed window.

   ## What I'm Not Sure About
   - How does multi-head attention differ from single-head?
   - Why 6 heads specifically?
   ```
3. You now see the main contribution. Create a seedling:
   `Knowledge/Programming/Attention Mechanisms.md` (or whatever domain fits)
   - `status: seedling`, `tags: [flashcards]`
   - Write what you understood — the core idea, not the full paper:
     ```
     ## What I understand
     Attention lets the model decide which parts of the input to
     focus on for each part of the output. It's a learned weighting,
     not a fixed window.

     ## What I'm not sure about
     - How does multi-head attention differ from single-head?
     - Why 6 heads specifically?
     ```

### Growing + flashcards

Over subsequent sessions or after reading related papers:
1. Connect to other things you know — maybe a course, another paper, your own code
2. Change status to `growing`
3. When the concept stands alone: `status: evergreen`
4. Add `## Flashcards`:
   ```
   ## Flashcards

   What is the attention mechanism in transformers?
   ?
   A learned weighting that lets the model decide which parts of the
   input to focus on for each output position. Query, Key, Value
   matrices compute relevance scores.
   ```

### When to remove from IW Queue

When you've read the sections you care about and extracted your understanding. You don't have to read every section — skip the parts that aren't relevant to you.

---

## Important: the `flashcards` tag

The SR plugin only detects flashcards in notes that have `flashcards` in their `tags:` frontmatter. The `## Flashcards` heading alone is not enough.

Every knowledge note that contains flashcards must have:
```yaml
tags: [..., flashcards]
```

The Permanent Note template includes this by default.

---

## Summary — Quick Reference

| Content                | Priority | Sessions to process       | Seedling?                                            | Remove from queue when...            |
| ---------------------- | -------- | ------------------------- | ---------------------------------------------------- | ------------------------------------ |
| **Book (fiction)**     | 20-30    | Many (chapter by chapter) | Yes, after patterns emerge                           | Finished + notes extracted           |
| **Book (philosophy)**  | 20-30    | Many (theme by theme)     | Yes, when themes emerge from highlights              | Finished + themes extracted          |
| **Programming course** | 10-20    | 2-3 per lesson            | Yes, when you understand beyond the instructor       | All lessons processed                |
| **Workbook**           | 10-20    | 2-4 per unit              | Via exercises, not separate notes                    | All exercises done + rules extracted |
| **Vocabulary**         | —        | Instant                   | No — straight to flashcard                           | Not queued                           |
| **English class**      | 25-35    | 1                         | Only for confusing grammar                           | After one review                     |
| **Audio lesson**       | 15-25    | 1                         | Only for complex grammar                             | After extraction                     |
| **Reference book**     | —        | On demand                 | No — updates existing notes                          | Not queued                           |
| **Podcast**            | 25-35    | 2-3                       | Yes — filter through your lens, test, then evergreen | Processed + tested + flashcards      |
| **Short video**        | 25-35    | 2-3                       | Yes — try explaining it without looking at notes     | Series done or understanding solid   |
| **PDF / paper**        | 15-60    | 2-3                       | Yes — after reading key sections                     | Key sections read + notes extracted  |
| **Quote**              | —        | Instant                   | No — straight to Quotes.md                           | Not queued                           |
