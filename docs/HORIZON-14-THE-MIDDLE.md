# Horizon 14 — THE MIDDLE

Opened 2026-08-22 on a play-session complaint; researched in
`docs/HORIZON-14-RESEARCH.md`. Three directions, taken as one horizon at the
owner's call, with **`RICHER OUTWARD` never broken** — also the owner's call.
**No save bump**: every new store loads defaults-not-branches.

## The commits

| # | commit | state |
|---|---|---|
| 1 | **The sheet** — reward area rather than depth | **BUILT** — §137 |
| 2 | **The tide** — weather that gives, in the middle bands, through `apply_tether`'s own door | **BUILT** — §139 |
| 3 | **Home waters** — colony works that reach into the band around them | PLANNED |

## Commit 1 — the sheet

A **sheet** is a `SUPERCELL` — a 4×4 block of 64u cells, 256u square — whose
every *readable* cell this pilot has read.

**Readable, not every cell**, and that finding reshaped the feature before it
was built: a survey mast rides on a **derelict** and a berth charts its own cell
on the first dock, so at band 4 barely a third of cells hold anything at all.
"Survey every cell in the block" is not a hard goal, it is an impossible one.

| band | readable cells | readings per sheet |
|---|---|---|
| 3 REACHES | 25.1% | ~4.0 |
| 4 QUIET | 31.2% | ~5.0 |
| 5 FATHOMS | 36.3% | ~5.8 |
| 6 UNSOUNDED | 41.2% | ~6.6 |

**A sheet is more work the deeper it sits** — a counter-gradient bought without
moving one number in one value table.

### The premium is flat, and flat is the design

`SHEET_PREMIUM` is **2,800** — a quarter of the loop §124 measured — and it does
not scale with depth. Every other value in the game rises outward, which is why
the middle is never optimal for anything. A premium that also rose would change
nothing; flat, it is worth proportionally most exactly where income is lowest.

### What carries it

- `DeepSpace.sheet_readings()` / `sheet_read()` — **both derived**, walked
  against `plan_cell` and `survey_coverage`. No progress counter exists to
  disagree with the store it summarises.
- `sheet_completed` signal, emitted from `note_surveyed` — the one door all
  three coverage grants come through.
- `GameState.sheets_filed` — its own store, because `survey_coverage` is a
  400-cell **window**: a sheet finished a thousand cells ago would silently
  un-finish and pay twice. Capped at 24 per system, evicting the **nearest**.
- The mast now prints `SHEET n OF m IN THIS BLOCK` on every reading but the
  last. **That line is the feature** — the premium is the payment; visible
  progress is the motivation.

### Legs (CARTTEST 21 → 23)

- `A SHEET IS DERIVED, NOT COUNTED` — the requirement is what the block holds,
  bounded by the block, and rising outward. An empty block is legal and says so.
- `THE SHEET'S PREMIUM IS PAID ONCE` — §11 with a geometry; plus the cap keeps
  the deepest sheet rather than the newest.


## Commit 2 — the tide

A **standing set of water**, one per `SUPERCELL` across THE QUIET and THE
FATHOMS, derived rather than stored: a pure function of `(system, supercell)`
on its own salted stream, so it costs no save key, no world-gen change and no
fingerprint. Roughly one block in three carries one.

### It only ever gives

The push is scaled by how well the hull's heading **already** agrees with the
set — a dot product clamped at zero — so crossing a tide gets nothing and
fighting one gets nothing. There is no escape guarantee anywhere in the file
because there is nothing to escape.

> A storm is a thing you **prepared for**. A tide is a thing you **found**.

### It runs across the depth, never along it

The set is tangential to the system centre, twisted up to 35°. That is the
feature rather than the flavour: a radial tide would be a slide outward, which
is *more* of the complaint this horizon opened on. A tangential one is a reason
to move **across** a band — to the next colony, to the sheet next door.

### The drift is flat, which is §137's trick again

`DRIFT := 0.9` u/s everywhere, against a drive ladder that only rises: **+56%**
on the 1.6 `max_speed` floor and about **+15%** on the fastest legal fit. The
water is worth most to the pilot who has least. `RICHER OUTWARD` is untouched —
the tide pays in **time**, and it pays the same everywhere it exists.

### The braid

**What a filed sheet unlocks is the chart, not the tide.** The water moves
whether or not you have worked the block — motes show it, the cockpit tag names
it — so a tide is always discoverable by flying into one. What the sheet buys is
the tide **drawn**, permanently, so the next crossing can be planned instead of
stumbled into.

The research asked whether a current should be *learned* or *shown*. This
answers both, in that order, and makes §137's sheet pay twice: a premium once,
and a fact about the region forever.

### What it must not do

- **Pay credits.** §67, one system along: a thing out here that pays out stops
  being weather and becomes another errand.
- **Log or save.** §53. Zero `note_log`, zero `note_ledger`, zero `_queue_save`,
  asserted off the source.
- **Fight a storm for the tether channel.** `apply_tether` re-clamps to the
  *last* caller's cap, so two drivers in one frame settle it by node order —
  DEFECTS class 2b. The tide stands down inside any storm's pull radius, checked
  against the `storm` group rather than through main.
- **Turn.** A tide on a clock would make route knowledge into
  route-and-timetable knowledge, which the chart has no way to draw. §64 carries
  the question of whether it ever should.

### Legs (TIDETEST, 10 — a new tag, 82 → 83 runs)

| leg | what would make it red |
|---|---|
| runs across the depth, never along it | a set with a component along the gradient past the twist ceiling |
| goes one way round in a band | a hand that flips inside one band |
| lives only in the middle | water outside bands 4–5, or a band missing |
| one block in three | `DENSITY` stopped meaning what it says |
| derived, not rolled | a shared RNG — two calls to one block disagreeing across an interleaved call |
| **gives and never takes** | riding pays ≠ `DRIFT`, or crossing/fighting pays anything at all |
| stands down inside a storm | the tide writing the tether channel while a storm holds the hull |
| the bearing is the chart's own up | `set_deg` and the plot disagreeing about which way is north |
| the cockpit names the set | the suffix in the wrong branch, or an unpadded bearing |
| derived weather | a log, a ledger or a save appearing in `tide.gd` |

