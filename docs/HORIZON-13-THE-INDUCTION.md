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

## The four legs (TITLETEST 4 → 8; runs stay 82)

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
