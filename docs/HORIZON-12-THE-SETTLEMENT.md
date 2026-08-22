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
| 1 | **The margin the line did not report** — both specced halves died on research; `THE ORDER DESK IS NOT A PRINTER` now reports the thinnest per-good margin (1.124) instead of the bias-free ceiling it was printing while asserting something else. `REQ_MULT` stays 5.0 | none | ~30 lines, no new leg | low | **BUILT** — §125 |
| 2 | **The ladder stands** — `scope` promoted from the blurbs to a key that `work_stands_in_system` reads; ONE prereq (`repeater` requires `relay`) after the rest died as a price in a gate's clothes; the four re-priced to 11k/17k/28k/45k = 9 loops a colony; `THE WORKS AT THEIR CEILING` prices the channel rather than the menu; `THE LADDER STANDS` is a new leg | none | ~240 lines + 1 leg | low | **BUILT** — §126 |
| 3 | **EXPANDED VAULTS + THE YARD** — the keyed `warehouse_space_of(key)` accessor (60→120 with the work) and `WAREHOUSE_SPACE`'s refusal narrowed to "never by port def"; THE YARD deepens the dry dock's own aura to 6× rather than selling a paid repair (§26); `_bay_key_is_real` fixed after two horizons of deleting annex bays on load | none | ~330 lines + 2 legs | medium | **BUILT** — §127 |
| 4 | **THE LIGHT** — a spill inside the colony's 350u reach holds its clock; the radius is half `MIN_HYPER_SEPARATION`, so no two lights overlap. **THE ARCHIVE cut**: `PILOT'S LEDGER` (§111) and `CAPTAIN'S LOG` (§118) already render the run's record free, so it was a paywall in front of a free screen | none | ~90 lines + 1 leg | low | **BUILT** — §128 |
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

## What commit 2 changed about commits 3-4

The scope finding is not confined to the works that already exist. **Every new
work in commits 3-4 must declare a `scope`, and the choice sets its price
curve**, because a system-scoped work has a hard ceiling of three useful copies
and a colony-scoped one multiplies by fifteen.

Read against the four planned:

- **EXPANDED VAULTS** (the annex bay 60 → 120) — colony-scoped by construction;
  it extends a bay keyed to its own colony. Multiplies. Prices like the annex.
- **THE YARD** (full repair at the colony) — colony-scoped, positional, the dry
  dock's own shape.
- **THE LIGHT** — **reworded to a per-colony grant** (decided 2026-08-22) and
  shipped that way in §128. It read *"a held spill in this **system** does not
  expire"*, which caps at three useful copies and would have repeated the
  relay's mistake. It ships at a **350u** aura — half `MIN_HYPER_SEPARATION`,
  so no two lights can overlap.
- **THE ARCHIVE** — **cut** (§128). The redundancy question above turned out to
  have a sharper answer than scope: the run's record is *already displayed,
  free*, on two pause-menu pages built for it. There was nothing left for the
  work to grant.

The channel row derives from `scope`, so each of these lands in the sink table
without an edit — and lands wrong if the scope is wrong.

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
