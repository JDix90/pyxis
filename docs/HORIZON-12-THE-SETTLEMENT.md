# Horizon 12 — THE SETTLEMENT

Opened 2026-08-21. Six commits. **No save bump** — v28 rides throughout
(Finding 5: staging is additive data, the vaults are a keyed accessor, the
Archive is fully derived). Research: `docs/HORIZON-12-RESEARCH.md`.

A settlement is what you pay when the bill finally comes due, and a place
where people live. This horizon is both, on purpose: the deep's bills start
biting, and the money they bite from finally has somewhere to become.

## The two sentences this horizon serves

**Raise the sinks so they bite** — but §114's lesson is that this repo
re-prices well and anchors badly, so every raised number ships inside a
measured band that reddens if it ever drifts back.

**What is a late-game pilot's money for?** The code's answer (research §1):
money converts into **place**. The network will not take credits (§96,
settled); the Authority's ledger is what a pilot leaves; the works ladder is
how the leaving is spent.

## The decisions this horizon is built on

Settled 2026-08-21, recorded in the research doc §2: the bite is **firm**
(0.3–0.5 loop at the far marks); the sinks get a **band**, income's own
instrument shape; **THE ARCHIVE is allowed** as a record, narrowly amending
H10's prestige refusal (status for money stays refused — displaying what was
already done is not status); and this spec follows a research pass in which
seven ideas died (research §6).

## The commits

| # | commit | save | size | risk | state |
|---|---|---|---|---|---|
| 0 | **The death price** — rescue decoupled from the jump ramp onto its own constants; the band leg `THE DEATH PRICE SITS IN ITS BAND` (measured-steady fraction ∈ [0.30, 0.50]); repair recorded as band-blind, and found never to have been involuntary at all | none | ~60 lines + 2 legs | medium — the numbers everyone feels | **BUILT** — §123, corrected by §124 |
| 1 | **The wider margin** — `REQ_MULT` 5→8; jump fees revisited against the new rescue curve; `THE ORDER DESK IS NOT A PRINTER` re-derives and must still clear | none | ~20 lines | low | PLANNED |
| 2 | **The ladder stands** — `requires` staging in `COLONY_WORKS`; existing four works re-priced (re-sized against the measured loop, §124: ~8–12 loops per colony across all eight stages, not the ~27 the research pass first proposed); `WORKS ARE A SINK` grows the prereq clauses; `EVERY SINK IS PRICED` rows updated in the same commit | none | ~80 lines + legs | low | PLANNED |
| 3 | **EXPANDED VAULTS + THE YARD** — the keyed `warehouse_space_of(key)` accessor (60→120 with the work); a colony `repair_price` on the deep ports' own per-def pattern | none | ~100 lines + legs | medium — STORETEST's bay legs re-derive | PLANNED |
| 4 | **THE LIGHT + THE ARCHIVE** — a held spill in the colony's system does not expire (extends §109's clock, braids §118's record); the Archive rendered entirely from existing stores, granting nothing | none | ~120 lines + legs | low | PLANNED |
| 5 | **The measure** — the horizon closed, the sweep read, the sink table re-printed at its new prices | none | docs | low | PLANNED |

## What commit 0 changed about this horizon

Commit 0 shipped `RESCUE_FEE_FAR := 13000` and its own band leg. **The first
sweep that ran it went red**, and the reason was not the leg: the steady loop
this whole horizon was planned against had never been measured. It is **11,236**,
not the ~32,500–34,000 carried through four documents. §124 records it; the fee
is now **4,500**, dead centre of the band, and the constant was the only thing
that moved.

Three consequences for the commits still planned, all of them shrinking:

- **The bite is already mostly there.** Today's rescue was 0.166 of a loop, not
  0.055. The firm bite raises it 2.4×, not 7×.
- **The ladder is re-sized, not trimmed.** Eight staged works at ~8–12 loops per
  colony (~90k–135k), against the research pass's ~300k+ — which at the real
  rate would have been forty-three hours to complete everywhere.
- **`REQ_MULT` 5→8 wants re-deriving before it ships.** Commit 1's premise was a
  margin measured against the wrong loop; the leg re-derives, but the intent
  behind the number does not.

And one defect the correction found on its way past, recorded in §124 and fixed
in the same commit: `_pacing_catalog_cost` had been summing two of `ModuleDB`'s
three purchasable dicts since v24, leaving `BERTHS` — 260,000, **23% of
everything a run can buy** — outside the catalogue that `CEILING` and
`THE CATALOGUE IS THE LONGEST PRICE` both measure against. It could never have
reddened: the catalogue is the *denominator* of both, so an under-count makes
each stricter and still passing. The yard is **1,106,200 / 98 loops / 13
hours**, and commit 5's closing table reads it from the fixed function.

Two rules the horizon now carries, from §124:

1. **A price is stated as a fraction of a measured loop**, never as a constant
   somebody felt was about right. `THE DEATH PRICE SITS IN ITS BAND` is the
   shape; every sink this horizon touches gets the same one.
2. **Two numbers for the same thing are a defect even while both are green.**
   Nothing compares a figure to another statement of itself.

**One thing for the next sweep to read rather than assume.** `MIDTIER` was
recorded at 2.91 and `STEADY MIDTIER` measures 0.775 — a best-case loop paying
~3.8× a steady one. If that spread is real it makes §123's choice to band
against STEADY load-bearing rather than tidy, and it wants a sentence in commit
5. Both legs print on every `PACINGTEST` run; read them together.

## The laws that hold it (all existing, all still asserted)

`NOTHING INVOLUNTARY EXCEEDS A LOOP` is the ceiling the bite lives under.
`THE RESCUE COSTS MORE THAN THE JUMP` sweeps the now-independent curves.
`CHART DEATH INTACT` keeps the tutorial's promise: depth 0 free, wallet
untouched. `THE CATALOGUE IS THE LONGEST PRICE` bounds the ladder per colony.
`can_store == no_retail` holds at the doubled vault exactly as at 60. And the
new band makes the re-pricing itself a law: an income retune that silently
cheapens death goes red instead of waiting a year for a research pass.

## What this horizon deliberately does not do

- **No upkeep, ever** — refused at the table it would be typed at (§114).
- **No credits at the network** — filing stays a donation; the Archive is the
  only place the two economies even face each other, and it faces them as a
  record.
- **No courier, no insurance, no hired escorts** — research §3, dead with
  reasons.
- **No income change** — `STEADY MIDTIER` should read what it read, again.
