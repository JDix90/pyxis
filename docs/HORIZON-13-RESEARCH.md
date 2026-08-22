# Horizon 13 — THE INDUCTION (research pass)

Opened 2026-08-22, on the owner's commission: a lore-heavy cinematic
introduction for new pilots, giving context for the war, the events that left
the derelicts in the reaches, and the Authority's control of Charted Space —
taking inspiration from a supplied reference video. **Nothing here is built.**
This document is the brainstorm and the research pass; the copy in §5 is a
draft awaiting the owner's read, the way `UNSOUNDED-FRAGMENTS-DRAFT.md` was
read and approved before §112 shipped a word of it.

---

## 1. What the reference video actually does

Fourteen seconds, ~60fps, square. Frame pass: a nebula parting around a blue
star → a slow planet reveal → a lone capital hull gliding past the limb → a
station consumed in blinding blue-white → an energy rift lanced by a single
line of light → hulls silhouetted in god-rays → three ships riding shafts of
light into a dark aperture.

Its grammar, which is what we are actually taking:

1. **Light narrates; nothing speaks.** No text, no faces, no voice. Calm is a
   warm nebula; catastrophe is over-exposure; aftermath is silhouette.
2. **One subject per shot**, held long. The camera drifts, never cuts fast.
3. **Scale is stated by occlusion** — the planet fills the frame, the ship
   crosses it, the rays dwarf the hulls.
4. **The arc is a founding myth compressed**: calm → arrival → cataclysm →
   exodus. Four beats, no connective tissue, and the viewer assembles the
   story themselves.

That last point is the load-bearing one: the reference *withholds*, and the
withholding is what makes it feel like lore rather than exposition.

## 2. What the game already says (the canon inventory)

The research pass's central finding: **the story the commission asks for is
already shipped.** It lives in `UnsoundedSite.FRAGMENTS` (approved 2026-08-19),
the beacon plates, the band names, the manual, and two commodity descriptions —
doled out in the exact order the design wants a player to earn it.

| canon | where | what it establishes |
|---|---|---|
| *"Whole machines from before the war ended."* | `commodity_db.gd:65`, and `servo_prewar`'s id | **A war existed, and it ended.** Exactly one clause deep, deliberately. |
| *"GSA SURVEY AUTHORITY · FIRST DEPLOYMENT"* | `manual_screen.gd:206` | The player is an Authority deployment. |
| THE FIRST MERIDIAN — datum station 0; *"the honest answer is: WHEN"* | `unsounded_site.gd` | The frontier was measured, and the measuring found something wrong with the idea of a chart. |
| THE STILL GLASS — *"THE DEEP RUNS SLOW... THE CONVOYS CAME BACK YOUNG... COMMERCE DID NOT SURVIVE THE ARITHMETIC"* | `unsounded_site.gd` | **The cause.** Not a battle: time dilation broke the frontier's economy. |
| DIRECTIVE 9 — *"THE FRONTIER IS RECLASSIFIED UNSOUNDABLE... CREWS BEYOND THE TERMINUS ARE INSTRUCTED NOT TO FILE"* | `unsounded_site.gd` | **The abandonment.** The Authority drew the line and wrote off its own people. |
| *"THE ENGINES WERE NOT RECALLED. THE WARDENS WERE NOT STOOD DOWN."* | `unsounded_site.gd`, THE LAST RETURN | **The derelicts and the wardens are the same event.** The wrecks in the reaches are the unrecalled; the wardens at the monuments were never told it ended. |
| The beacon plate: *"The frontier beyond the bearing terminus is reclassified UNSOUNDABLE. Survey operations in the reclassified volume are suspended indefinitely."* | `beacon.gd:55` | Directive 9's **public** text — the sanitized version already exists in-world, on charted infrastructure. |
| The rival's wreck — *"THE CHART WAS TRUE, THE FUEL WAS SHORT"* | `unsounded_site.gd` | Somebody defied the reclassification, was right, and died of it. |
| Band names, three arcs | `system_db.gd` | Three systems tell the same withdrawal in three vocabularies: filing (THE UNFILED → NO RETURN FILED), forge (THE COOLING → THE UNSMELTED), sounding (THE LEADLINE → NO BOTTOM FOUND). |
| THE PROCESSION — *"A HULL, POINTED HOME"*; *"No registry, no attachment, no name on this one."* | `procession.gd` | The unrecalled are still, slowly, coming back. |

**Consequence for the intro:** its job is not to tell this story. Its job is to
be **the Authority's cut of it** — the induction film a new GSA pilot would
actually be shown — so that every euphemism in it is a hook the deep later
answers. The intro is itself an artifact of the control the commission asks it
to convey.

## 3. The four decisions, taken 2026-08-22

1. **Narrator: the Authority briefing.** Diegetic, institutional, partial.
   Honors §105 (no named living strangers — an institution speaks, not a
   person) and makes the redactions load-bearing.
2. **Spoiler budget: the cause is shown** — owner's call, against the
   assistant's recommendation, and §6 below is the mitigation that makes it
   safe: the intro states the *fact* of deep time in the Authority's flat
   language; the STILL GLASS keeps the *people* — the changed clocks, the young
   convoys, the crews who decided to be late.
3. **Form: in-engine hybrid.** Scripted tableaux in the game's own renderer —
   washes, DeepField, existing meshes in silhouette, FX light — carrying
   filing-voice text cards on the log's reveal stagger. Prerendered died
   COSTED (~2MB/s of binary, an art pipeline we don't have, headless
   untestability, and the title's own written rule: *"the first thing a player
   sees is the actual game rather than a still"*).
4. **Placement: first boot + replayable.** Plays once between NEW SURVEY and
   the tutorial; re-watchable from the title (the manual's precedent). A
   `seen_induction` flag rides v28, defaults-not-branches. Skippable from
   frame one, forever — a mobile game never holds the door shut.

## 4. The copy rules (before any copy)

1. **THE INTRO NEVER QUOTES A FRAGMENT.** The fragments' sentences exist only
   at their structures; the intro writes new sentences that gesture at the
   same facts. (Leg-enforceable: walk `FRAGMENTS`, assert no induction line
   contains one. §124's family, applied to fiction.)
2. **It MAY quote the beacon plate** — that text is already public in-world,
   and quoting only what the Authority published is exactly in character.
3. **The war stays one clause deep**, matching its one clause of canon.
4. **No named persons** (§105). No "we". The Authority speaks in passive voice
   and the passive voice is characterization.
5. **Every factual line carries a canon anchor** in the table below, or is
   marked NEW CANON and dies without the owner's approval.

## 5. The beat sheet (draft copy for approval)

Five beats, ~60–75s total, portrait 720×1280. Each beat is one tableau + 2–4
lines. Reference-frame mapping noted per beat.

### BEAT I — THE COMMISSION (~10s)
*Stage:* pyx01's cold blue wash; dense DeepField; slow drift toward one bright
star. The reference's opening nebula, in our own sky.
> GSA SURVEY AUTHORITY
> PILOT INDUCTION · FIRST DEPLOYMENT
> THE WAR IS OVER. THE CHARTS DID NOT SURVIVE IT.
> WHAT THE AUTHORITY COULD HOLD, IT CHARTED.

*Anchors:* manual 206 (verbatim header); the war clause ↔ `commodity_db.gd:65`.
"The charts did not survive it" is NEW CANON (one line, explains why a Survey
Authority rules the map).

### BEAT II — THE INSTRUMENTS (~12s)
*Stage:* Orrery-family silhouettes against the wash; a lattice of filed cells
lighting outward from the chart ring; procession-mesh hulls outbound through
god-ray backlight. The reference's capital-ship beat, pluralized and hopeful.
> THE SURVEY WENT OUT.
> DATUM RAISED. TIME KEPT. BEARINGS TAKEN.
> EVERY CELL FILED WAS A CELL HELD.

*Anchors:* the three structures (meridian / glass / return), unnamed so their
discovery stays a discovery; "filed/held" is the live survey vocabulary.

### BEAT III — THE ARITHMETIC (~14s) — the cause, per decision 2
*Stage:* two chronometer readouts drift apart at the top of frame; the cell
lattice's outermost lights begin going dark, outside-in; the wash cools. The
reference's blinding-light beat **inverted** — our catastrophe is quiet, so
ours is light *withdrawing*.
> BEYOND THE DEEP MARKS, SCHEDULES RETURNED IN DISAGREEMENT.
> THE CLOCKS WERE NOT WRONG. THE DEEP KEEPS ITS OWN TIME.
> ACCOUNTS COULD NOT BE SETTLED ACROSS THE LINE.

*Anchors:* STILL GLASS fragments 1–2, restated in new sentences. States
dilation as fact; withholds the changed clocks, the young convoys, the human
arithmetic. "Deep marks" is pyx03's own band vocabulary.

### BEAT IV — THE RECLASSIFICATION (~14s)
*Stage:* god-rays die; derelict silhouettes adrift, dark; one warden lamp
still burning; a procession hull drifting the *other* way, pointed home. The
reference's exodus beat, reversed — nobody flees; they are simply left.
> DIRECTIVE 9: "THE FRONTIER BEYOND THE BEARING TERMINUS IS RECLASSIFIED
> UNSOUNDABLE. SURVEY OPERATIONS IN THE RECLASSIFIED VOLUME ARE SUSPENDED
> INDEFINITELY."
> ASSETS REMAIN ON STATION.

*Anchors:* the quote is `beacon.gd:55` verbatim (rule 2). "ASSETS REMAIN ON
STATION." is NEW CANON and the whole design in four words — the euphemism for
*engines not recalled, wardens not stood down, crews instructed not to file*,
every one of which stays out past 5,600u for the pilot to find.

### BEAT V — YOU (~10s)
*Stage:* the chart ring; one small player hull crossing it outbound; the wash
warms to the live game's look and the last card resolves into the title /
tutorial handoff.
> CHARTED SPACE IS PATROLLED. THE CHART IS NOT FINISHED.
> WHAT YOU READ, YOU MAY FILE. THE COUNTER PAYS FOR FIRSTS.
> FLY SAFE, PILOT. FILE RETURNS.

*Anchors:* the manual's counter copy; the tutorial's own verbs. "FILE RETURNS"
is the Authority's bureaucratic imperative — and the game's last fragment out
at the terminus turns the same phrase into a plea. The rhyme is the point and
the intro must not wink at it.

## 6. Protecting THE STILL GLASS under "cause too"

The owner chose to reveal the cause. The split that keeps the vault worth
flying to:

| the intro states (fact, flat) | the deep keeps (consequence, human) |
|---|---|
| the deep keeps its own time | *we changed the clocks* |
| schedules returned in disagreement | *the convoys came back young* |
| accounts could not be settled | *commerce did not survive the arithmetic* |
| assets remain on station | *the engines were not recalled; the wardens were not stood down; we decided to be late* |

The intro sells the *what*; the structures keep the *who paid*. Fragment 3 of
the STILL GLASS — the crew that chose lateness — is untouched entirely.

## 7. Integration shape (spec-level, not built)

- **Its own scene** (`induction.gd`), an isolated stage: own Node3D root, own
  DeepField, wash colors read from SystemDB env, silhouette meshes reused
  (procession hull, derelict, hyper-structure, warden, player ship). Never
  the live system — no GameState mutation, no shared-stream draws (§17), and
  a leg asserts the byte-identical save.
- **A const BEAT table** drives it — durations, copy, stage id — so the
  harness walks it headlessly and the copy has one home.
- **Entry:** `new_game_pressed` → induction (if `!seen_induction`) → tutorial.
  Title gains a replay row (manual's pattern). Tap advances a beat; a visible
  SKIP corner button ends it (§88 — the affordance is on screen, not a secret
  gesture).
- **`reduce_motion`:** drifts become crossfades; durations halve; nothing is
  conveyed by motion alone.
- **Save:** `seen_induction` rides v28, defaults-not-branches
  (`marks_seen`'s precedent). No bump.
- **Music:** open question — the game owns one eight-bar phrase; the intro
  wants either a sparser treatment of it or near-silence with FX swells.
  Deliberately not decided here.
- **Capture:** `PYXIS_SHOTS` writes one still per beat, the DEMO machinery's
  own idiom, so the Mac review loop sees the tableaux without a build.

## 8. Testability (folded into TITLETEST — no new run; 82 holds)

1. `THE BEAT TABLE IS WELL-FORMED` — five beats, bounded durations, total
   under 90s, copy within the wrap width.
2. `SKIP LEAVES NO TRACE` — enter, skip at every beat index: GameState
   byte-identical except `seen_induction`.
3. `THE INDUCTION QUOTES NO FRAGMENT` — derived against
   `UnsoundedSite.FRAGMENTS` verbatim; the beacon plate is the one allowed
   quotation.
4. `REDUCE MOTION HAS A PATH` — the flag on, every beat still reachable.

## 9. What died in this pass

- **Prerendered video** — COSTED, declined at the fork (binary size, art
  pipeline, untestable, title's written rule).
- **Voice-over** — localization and size, and §105 pressure toward a named
  speaker.
- **A survivor-voice intro** — spends the fragments' register before it is
  earned.
- **Playing it inside the live pyx01** — state bleed risk against §17's pure
  expanse; an isolated stage costs nothing.
- **A text crawl** — another franchise's furniture; the filing voice wants
  cards.
- **Branching or interactive beats** — the tutorial is the interactive half;
  the induction is a document.

## 10. Next steps

1. Owner reads §5's copy — edits, kills, or approves (the fragments-draft
   ritual).
2. On approval: spec doc (`HORIZON-13-THE-INDUCTION.md`), then build as
   commits — the stage + beat table, the copy + legs, the title/tutorial
   wiring, the measure.
