# Horizon 13 — THE INDUCTION

Opened 2026-08-22, **built the same day** (§133) after the owner approved the
research pass's draft copy (`docs/HORIZON-13-RESEARCH.md`, the
`UNSOUNDED-FRAGMENTS-DRAFT` ritual). One commit. **No save shape change at
all** — the seen flag is a device preference.

## What shipped

`scripts/induction.gd` — the Authority's briefing film: five beats, sixty
seconds, drawn in **chart language** (cells, rings, clocks, silhouettes) over a
translucent scrim, so the live system remains the backdrop — the title
screen's own promise, kept one layer up. Copy is the approved draft, verbatim,
carried in a `const BEATS` table the harness walks without a viewport.

| beat | tableau | the Authority says |
|---|---|---|
| I THE COMMISSION | one bright datum star | the war is over; the charts did not survive it |
| II THE INSTRUMENTS | cells lighting outward, three instruments raised | every cell filed was a cell held |
| III THE ARITHMETIC | two clocks drifting apart; the outer lights going out | the deep keeps its own time |
| IV THE RECLASSIFICATION | dark hulls adrift; one warden lamp | Directive 9, quoted verbatim; **ASSETS REMAIN ON STATION** |
| V YOU | one small hull crossing the ring outward | fly safe, pilot; file returns |

## The wiring

- **NEW SURVEY** → induction (first time on this device) → `start_new_game()`.
  Replayable from the title (`THE INDUCTION`, the manual's opened-on-top
  contract). Tap advances a beat; a visible SKIP ends it (§88).
- **`seen_induction` is a preference, not a save key** — NEW SURVEY resets the
  save, and a returning player starting a second pilot has not un-watched the
  film. Marked watched OR skipped: skip is an answer, and re-asking is a nag.
- **The scene owns no state.** Main writes the flag on the `finished` signal;
  `SKIP LEAVES NO TRACE` keeps it true.
- **`reduce_motion`**: durations halve and every element draws at its end
  state — UIKit's own rule, the accommodation is the end state immediately.
- **Music: none in this commit** — the game owns one eight-bar phrase and the
  right treatment is its own decision; the film plays over whatever the title
  was playing. Recorded open in §64.

## The legs (TITLETEST 4 → 10; runs stay 82)

1. `THE BEAT TABLE IS WELL-FORMED` — five beats, durations 6–20s, total 40–90s,
   line lengths bounded.
2. `THE INDUCTION QUOTES NO FRAGMENT` — derived against
   `UnsoundedSite.FRAGMENTS` in both directions, and the one allowed quotation
   (`Beacon.DIRECTIVE_PAGES[0]`'s clause) must appear **verbatim** — a
   paraphrased legal text is a second version of the law.
3. `SKIP LEAVES NO TRACE` — the film walked to the end in replay mode;
   GameState byte-identical across it. `PYXIS_SHOTS` captures one still per
   beat here.
4. `REDUCE MOTION HAS A PATH` — flag on, the film still opens, advances and
   closes; the preference is restored after.

## What this deliberately does not do

- No voice-over, no named narrator (§105 — an institution speaks).
- No prerendered video (COSTED and declined at the fork).
- No new music cue (open).
- No quotation of any fragment — the deep keeps its own sentences.


## Commit 2 — §134, the column with no height

A playtest screenshot found every beat drawing its lines on one baseline: the
copy column was anchored top and bottom at the same fraction with no offsets, a
rect zero pixels tall, and a `Container` hands its children the rect it has.
Fixed by anchoring the box to the bottom with a margin and pinning it to
`ALIGNMENT_BEGIN`.

Nine legs were green through it because **every one of them asks what the film
says and none asked where it puts it**. The published contact sheet missed it
for a sharper reason: it transcribed the *draw calls*, and the drawing was never
wrong.

5. `THE COPY DOES NOT STACK` — the scene exposes `copy_rects()`, the engine's
   own laid-out rectangles, and the leg walks all five beats asserting every
   line has real height and clears the one above it. A screenshot cannot be a
   verdict; a `Rect2` can.


## Commit 3 — §135, the door steps aside

The replay opens on top of an open title, so the compass, taglines and five
buttons were reading through the scrim. `set_chrome_visible()` hides the
furniture for the duration and Main restores it on `finished` — in exactly one
place, because `_finish` is the film's only exit.

The layer's own `visible` stays true throughout: it means *is the door open*,
and making it also mean *is the door drawn* would give one word two jobs.

6. `THE REPLAY HIDES THE DOOR` — driven through the signal, not the setters,
   so what is asserted is the wiring; checks the chrome goes and returns, and
   that the title stayed open behind it.

**Measured, not assumed:** the large ellipse in the §134 screenshots is the live
3D system, not the compass — 129px of circular compass arc cannot produce a
~500×430 ellipse. This commit fixes the replay path; the backdrop on the first-
boot path is `SCRIM_BASE`'s alpha and a separate decision.


## Commit 4 — §136, a container owns its children's positions

§134's height fix was necessary and not sufficient. The real cause:
`UIKit.reveal_list` tweens each item's `position` to slide it in, and both call
sites add their labels to a `VBoxContainer` **in the same frame** — before the
container sorts. So `from` reads `(0,0)` for every label, the tween drives every
label there, and the tween wins, because a tween writes every frame and a
container sorts only when asked.

The helper now slides only where `position` is ours to write. Inside a container
the reveal is the stagger alone — the half that carried the meaning.

**`CAPTAIN'S LOG` has the same defect and has since §118** (code-derived, not
observed — that page wants an eye now the cause is named).

**And §134's leg would have missed this.** `THE COPY DOES NOT STACK` sampled two
process frames in; the reveal runs `T_STAGGER × lines + T_REVEAL` ≈ 0.33s. It
now waits out the reveal, derived from `UIKit`'s constants.
