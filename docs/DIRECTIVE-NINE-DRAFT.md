# DIRECTIVE 9 — prose draft (Horizon 8 commit 0)

**Status: SHIPPED (§92) for everything in sections A, C and D; section B's
pages wait for Horizon 8 commit 1.** Read and approved 2026-08-19. The four
marked decisions came back answered and one general note came with them; both
are folded in below and recorded here so the reasoning survives.

**One change was found during the build and is recorded in §92 rather than
here.** The band-5 and band-6 after-lines sit BELOW the per-system override,
so in pyx01 (which speaks band 6 as a GSA repeater) and pyx03 (which speaks
band 5 as a sounding mark) the shipped local line still wins — both of those
overrides are machines, and the rule this pass is held to is that machines were
never told. Every system still carries one living voice, and an assertion holds
that per system. Edit these lines HERE and in `deep_space.gd` together.

**R1 (the gate)** — the worry was the twist landing too early, before the game
has earned it. Answered structurally: the reveal is now **staged** (see "The
arc"), and the pages no longer reach the shallows.
**R2 (band 6)** — kept in full, as drafted.
**R3 (page count)** — six.
**R4 (the Commission field)** — the always-visible dash was a give-away. The
field now **appears only after the order is read**, where it is corroboration
instead of a teaser.
**The register note** — the copy was more cryptic than it needed to be. The
rule below is new, and every line in this draft was rewritten against it.

---

## The register rule (new, and it governs everything here)

**Every line is understandable on first read. Eeriness comes from what a line
means, never from being hard to parse.** The player should always know what
they were just told; what should grow with depth is how much they wish they
had not been told it.

And the game already walks that gradient — this pass adds nothing eerie to the
near game, because the near game is already authored normal:

| where | shipped voice | register |
|---|---|---|
| bands 1–2 | the GSA beacon, the last repeater | mundane, bureaucratic, even warm |
| bands 3–4 | a degraded recording, then a dead carrier | official voice failing |
| bands 5–6 | A KEPT LIGHT, the listener | not the authority's voice at all |
| past 5,200u | the three archives | the truth, in plain words |

Everything this horizon adds slots into the bottom half of that table. Nothing
above band 3 changes at all.

---

## The arc — normal, then hints, then the truth, then the aftermath

This is R1's answer. The reveal is not one gate; it is three beats that the
player walks in order because the *geography* orders them:

**1. Hints (mid-game, bands 3+).** Directive 9's six pages ride foreign
beacons — but **only beacons standing at band 3 or deeper** (1,100u+). This is
new: without the gate, the rival's shallows sweep would put pages at the chart
edge inside the first hours, which is exactly the too-early reveal R1 feared.
The band gate is also the fiction agreeing: you do not leave contraband where
the authority still sweeps. A mid-game player finds one page, out of order,
understands every word of it, and cannot yet tell what it is part of. That is
the "several eerie, unsettling interactions" beat, done with content that
never pretends to be confusing — just incomplete.

**2. The truth (late, past 5,200u).** THE LAST RETURN, fragment 2, is the
order itself. Reading it is the realization, and it changes only what is
**private**: the ship says one line, the log takes one entry, the Commission
page gains its field. The world does not react yet — you know, and nothing
else does, which is its own kind of alone.

**3. The aftermath (later still).** The two living voices — bands 5 and 6, the
only broadcasts that were never the GSA's — change register only once **the
whole record is held**: all three archives read to the end. The deep speaks
differently to someone who knows everything, and to no one else.

Two derived flags, zero new save (both read v23's `deep_logs`):

```
knows_directive_9()  := any ":return" record at stage >= 2
holds_whole_record() := meridian, glass and return all at stage 3
```

Fragment 3 of THE LAST RETURN — *"file a return for us"* — is still not spent.
The verb it asks for is deferred past this horizon, deliberately.

---

## A. The two living voices (gated on the whole record)

Heard on the next outward crossing — `_tick_broadcast` reads at fire time, so
this costs nothing. Both shipped lines stay verbatim for everyone else.

### Band 5 — A KEPT LIGHT

Shipped, unchanged before the record is complete:

> *There is a light ahead of you. It is kept. It has been kept a long time,
> and by somebody. If you need it, it is there.*

After:

> *You have read the order, so you know whose light this is. The crews who
> came home and were not counted stopped going home. They kept the light
> instead. It is lit for whoever is still out here — which, by the
> authority's own ledger, now includes you.*

### Band 6 — · · ·

Shipped:

> *Nothing is transmitting. Something is listening.*

After (kept in full, per R2):

> *Nothing is transmitting. Something is listening: a recorder, left running,
> taking down returns for a file that was closed a long time ago. It has your
> bearing. It will keep it. Nobody will read it.*

---

## B. Directive 9 — six pages, band 3 and deeper

Foreign beacons keep their existing refusal untouched (*"NOT YOUR ANCHOR CODE —
THIS BEACON ANSWERS TO SOMEBODY ELSE"*). The read is a second, shorter hold
that costs nothing and pays nothing. Which page a beacon carries is a pure
function of its cell key — zero bytes of save. The Authority's records persist;
the refusers leave nothing behind.

Plate sender: `DIRECTIVE 9 — PAGE n OF 6 · PASSED HAND TO HAND`. Each page is
the order's own words, then one hand-written line from whoever copied it. The
order is bureaucratic and plain; the margins are people, and also plain.

**1.**
> *The frontier beyond the bearing terminus is reclassified UNSOUNDABLE.
> Survey operations in the reclassified volume are suspended indefinitely.*
> — copied and passed on. whoever gave it to me would not give a name.

**2.**
> *No return filed from the reclassified volume shall be logged, corroborated,
> or entered against a commission.*
> — READ IT TWICE. IT DOES NOT SAY THE CREWS WERE LOST. IT SAYS THE CREWS CAME
> BACK, AND THE RETURNS WENT IN THE BIN.

**3.**
> *Vessels remaining in the reclassified volume at the effective date are
> removed from the active register.*
> — NO RESCUE WAS SENT. NO SEARCH WAS FLOWN. THEY DELETED THE SHIPS FROM THE
> LIST AND CALLED IT DONE.

**4.**
> *Automated instruments, relays and standing security assets within the
> reclassified volume are to remain in service. Recall is not authorized at
> this time.*
> — SO EVERY MACHINE OUT THERE IS STILL ON DUTY. THE WARDENS, THE ENGINES, THE
> BEACONS. NOBODY EVER TOLD THEM IT WAS OVER.

**5.** *(the spine)*
> *APPENDIX B — NOT CIRCULATED. Reclassification is recommended on the grounds
> that repeated resurvey of the volume produces charts which do not agree with
> one another. Publication of charts known to be provisional exposes the
> authority to severe commercial and legal liability.*
> — THERE IT IS. THEY DID NOT CLOSE THE FRONTIER BECAUSE SOMETHING WAS WRONG
> WITH IT. THEY CLOSED IT BECAUSE THE MAPS WOULD NOT AGREE — AND THEY SELL
> MAPS.

**6.**
> *ATTACHED: vessels known to have filed after the effective date.*
> — nine names. I have met two of them. the last one on the list is a hull in
> a livery nobody registered, last seen heading out, still filing.

---

## C. The player's own file (appears with the order, per R4)

Before Directive 9 is read: the Commission page is exactly as it ships today.
No dash, no unexplained field, nothing to ask about.

After, one field appears at the bottom of the registry, in the page's own
plain voice:

> **RETURNS LOGGED FROM THE RECLASSIFIED VOLUME: —**
> *Field retired at Resurvey 44. Filings from the volume are accepted and
> counted above.*

Read after the order, this is the page confirming it: your deep returns go
into the general tally, and the ledger that would have named where they came
from was switched off the cycle the datum was found to move. *Accepted and
counted* — just never as what they are.

The existing closing line stays exactly as shipped, and does its own work now:

> THE FILE IS CLOSED. THE REGISTRY CARRIES YOUR NAME.

---

## D. The ship (fires at the moment of the read)

One bark, once ever, answering the crew's own band-6 line ("WE ARE THE RECORD
NOW"):

> **WE ARE STILL FILING. SOMEBODY SHOULD KNOW THAT WE ARE STILL FILING.**

One captain's-log entry, in the log's terse register:

> **READ DIRECTIVE 9 — THE RETURNS WERE REFUSED**

---

## What is deliberately not touched

- **Every GSA broadcast, bands 1–4.** The machines were not told. If a
  recording changes its words, this pass is wrong — `THE MACHINES DO NOT KNOW`
  is that rule as an assertion.
- **Band 4's silence.** *"Do not 'finish' this entry"* stands.
- **The near game.** Bands 1–2 stay mundane; no page, no field, no line lands
  before band 3. The game starts normal because it is normal, for hours.
- **The Commission's statement-of-record posture.** One field, appearing only
  once it corroborates something the player did, stating plainly what it is.
- **No faction, no side, no questline, no tracker.** The revelation changes
  the reader, not the rules.
- **No new save.** Both flags derive from v23's `deep_logs`; the pages are a
  pure function of cell keys.
