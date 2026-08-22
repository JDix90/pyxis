# Horizon 14 — THE MIDDLE

Opened 2026-08-22 on a play-session complaint; researched in
`docs/HORIZON-14-RESEARCH.md`. Three directions, taken as one horizon at the
owner's call, with **`RICHER OUTWARD` never broken** — also the owner's call.
**No save bump**: every new store loads defaults-not-branches.

## The commits

| # | commit | state |
|---|---|---|
| 1 | **The sheet** — reward area rather than depth | **BUILT** — §137 |
| 2 | **Weather that gives** — a non-hazard phenomenon in the middle bands, paying in time through `apply_tether`'s own door | PLANNED |
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
