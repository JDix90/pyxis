# Horizon 12 — the research pass

> **CORRECTION, 2026-08-21 (§124).** This document was written against an
> **estimated** steady loop of ~32,500–34,000 credits per eight minutes.
> `PACINGTEST` measures **11,236** — a third of it — and the yard catalogue is
> **1,106,200 / 98 loops / 13 hours**, not the ~27 loops §114 published (the leg
> was reading 846,200, missing `ModuleDB.BERTHS`; fixed in the same pass). Every
> credit figure below is re-derived; the ones that moved are marked. The
> commission's premise survives but shrinks: **every sink already bites three
> times harder than this pass assumed**, so the re-pricing is much smaller than
> specced and the works ladder is re-sized rather than trimmed.


Opened 2026-08-21, the evening Horizon 11 merged (§114–§122, 824 across 82
measured). The commission is two sentences from the owner:

> Raise the sinks so they bite. And deeply consider: **what is a late-game
> pilot's money for?** What should they spend on once the ship is already the
> ideal build?

This pass answers the second question from the code before letting the first
question move a single constant — because §114's whole lesson is that this
project re-prices well and *anchors* badly.

---

## 1. What the code says money is for

### What it buys today, once the catalogue is owned

Every post-catalogue sink is a **service in §26's currencies**, priced in
seconds of income:

| sink | currency | price today |
|---|---|---|
| repair, field repair, dry dock | time | ≤1,400 |
| beacon/colony jumps, anchors | time | 120–500 |
| rumours, intel, relay, repeater | information | 400–900 |
| bonded annex, warehouse | access | (work: 8,000) |
| requisitions | delivery/time | ≤4,500 |
| colony works | place | 28,000/colony |
| paint | identity | 800 (grandfathered) |
| the wager | a printed bad bet | ≤5,250/streak |

### What it can never buy — and every row is written law

| refused | by | the sentence |
|---|---|---|
| power, stats | §9/§19 | the catalogue is the only power money touches |
| network access or literacy | §72 + §96 | *"give the goods, no credits, no Commission"* — a settled ideation decision, not an omission |
| a charted escort | §72 | `request_escort` is **free and gated on ALLIED** — a fee would re-price a gate |
| escape from flying | §5, §87 | *"the trip is the cost"*; eight beacons became three over exactly this |
| the world's state | §51 | only the player depletes it |
| skills, standing | §19, §72 | disjoint feeds; gates never prices |
| upkeep | §5, §114 | REFUSED, recorded at the `COLONY_WORKS` table |
| prestige purchases | §64 (H10 decision) | *offered and declined* — amended narrowly below |

### The answer, and the fiction already wrote it

Credits are salvage — the **Authority's** ledger. The endgame arc walks the
pilot out of that economy and into the network's, and the network pays in
bearings and **will not take credits** (§96, settled). So the one large channel
left open is the one §5 deliberately opened in 2026-08-04 and priced-gated
behind a pacing measurement that §114 finally took:

> **Money converts into place.** A late-game pilot cashes out of the empire's
> economy by building somewhere to live at its edge. The network won't take
> your credits — but it notices your lights.

Horizon 12 is therefore two halves that need each other: **the re-pricing**
(so the deep costs something on the way out) and **the works ladder** (so the
money that now hurts to lose has somewhere meaningful to go).

---

## 2. The four decisions, taken before any code (2026-08-21)

1. **The bite is FIRM: 0.3–0.5 of a steady loop at the far marks**
   (**~3,400–5,600** against today's 1,869 — see the correction banner; this
   line first read "~10–17k" against a loop three times too fast). The fee still
   ramps from ~free at the chart edge; this sets the maximum, at the deepest
   place a pilot can die.
2. **The re-priced sinks get a measured BAND**, income's own instrument shape:
   an authored constant, a measured ratio, a red when they drift apart. The
   re-pricing becomes a law rather than a one-time nudge — the exact drift §114
   documented cannot recur silently.
3. **THE ARCHIVE is allowed, as a record and not a purchase.** This narrowly
   amends H10's *"NOT prestige purchases"*: prestige buys **status a system
   acknowledges**; the Archive **displays what the pilot already did** — the
   captain's log made of stone, the pilot's-ledger register in a place. The
   amendment is recorded here and in §64 so the original decision's boundary
   stays legible: status for money remains refused.
4. **Research pass before spec** — this document, then the horizon doc.

---

## 3. Findings — what died, what split, what survived

### Finding 1 (the big one): the instrument is BLIND to repair, so the bite splits

`_run_pacing_test` sets `player.invulnerable = true` before measuring a single
yield. The measured loop **never takes damage and never pays a repair** — so a
repair re-pricing changes real-play *net* income while `STEADY MIDTIER` reads
exactly what it read. A 6× repair would be a stealth income nerf the band
structurally cannot see, landing hardest on the mid-game pilot who fights every
loop.

Deep ports compound it: they price repairs **per-def** (`repair_price`
1,000–1,300 across three archetypes), part of the deep's authored pricing arc.
A global repair raise means editing several authored numbers whose
relationships were argued individually.

**So the involuntary pair splits, and the split is the design:**

- **The RESCUE is the death price.** Rare, always the consequence of a chosen
  risk, invisible to the income band (nobody dies in the harness loop either —
  but nobody is *supposed* to die in a measured loop, whereas everyone repairs).
  It takes the full firm bite: **0.3–0.5 loop at the far marks.**
- **The REPAIR is a maintenance tax.** Constant, loop-coupled, band-invisible.
  It moves modestly if at all (≤2×), with the blindness recorded as the reason.

### Finding 2: the rescue must decouple from the jump ramp

`rescue_fee` is `beacon_jump_fee`'s lerp ×2, unclamped — the anchoring-to-
another-price defect §114 named, still live in the function §109 built. The
re-pricing gives the rescue **its own constants** expressing loop-fraction
intent, and keeps `THE RESCUE COSTS MORE THAN THE JUMP` sweeping seven depths
across the now-independent curves. `CHART DEATH INTACT` (depth 0 free, wallet
untouched) is untouched — the tutorial's promise survives any bite.

### Finding 3: three services died in one paragraph each

- **The bonded courier** (pay to ferry warehouse goods between bays) — buys
  *out of* the trip, and §5's sentence is that the trip IS the cost. The same
  reasoning that cut eight beacons to three (§87). Dead.
- **Insurance / prepaid rescue** — a debt is *"a second currency this game does
  not have"* (§109), and prepayment is the same instrument facing backwards.
  Dead.
- **Escort for hire** — charted space: re-prices a free ALLIED gate (§72), dead
  outright. Deep space: no §72 collision, but nothing in the fiction flies it —
  the network has no hulls, the Authority stops at the chart, and a printed
  wing is the forge's and priced in hulls, not credits. Dead until the fiction
  grows a provider, recorded rather than forced.

### Finding 4: THE GLASS died on §111's dead-rung test

A work granting silhouette sighting range collides with COLONIAL t1
(`COLONIAL_NAME_MULT`, *"the silhouette answers from twice as far"*). A work
that grants what a skill already grants is a rung that grants nothing — the
exact test that killed RIFT-WORK's `THE SHEAR HEARD`. Killed at the list stage,
before it cost anything.

### Finding 5: the works ladder needs no save bump

Staging is a `requires` field in `COLONY_WORKS` and a prereq check in
`GameState.buy_colony_work` (a store rule — the world gates stay Main's).
`colony_works` already persists a per-colony id list; new ids are additive.
EXPANDED VAULTS needs `WAREHOUSE_SPACE` (3 real consumers, 1 leg, 1 UI line) to
become a keyed accessor — small and mechanical. THE ARCHIVE derives everything
from stores that already exist (`deep_logs`, `marks_seen`, `breached`,
`structures_seen`): **zero new stores anywhere in the horizon.** v28 rides.

---

## 4. The works ladder — survivors, with their code notes

Stage-gated per colony (each requires the previous), every gate §116's pattern
(sounded ground + delivered goods + standing at it), every return a §26
service, every price a gate-plus-price where the goods are the gate:

| stage | work | currency | code note |
|---|---|---|---|
| 1–3 | the existing RELAY / DRY DOCK / ANNEX, re-priced | info/time/access | prices move, mechanics stand |
| 4 | DEEP REPEATER (§116), re-priced | information | stands |
| 5 | **EXPANDED VAULTS** — the annex bay 60 → 120 | access | keyed accessor for `WAREHOUSE_SPACE`; STORETEST legs derive from it |
| 6 | **THE YARD** — full repair service at the colony, per-def priced like a deep port | time | `repair_price` on the colony, the deep ports' own pattern |
| 7 | **THE LIGHT** — a held spill in this system does not expire | time | extends §109's claim clock; braids §118's record |
| 8 | **THE ARCHIVE** — the run's record, made into a place | record | fully derived; renders fragments read, legends resolved, names met; grants nothing |

Prices are the spec's to derive, and **the sizing below is re-derived against
the measured loop** (§124) rather than the estimate this section first carried.

*(**And the ×12 column below is itself wrong**, corrected in §126 after commit 2
researched it: two of the four works are **system-scoped**, capped at three
useful copies by the chart's own any-in-system question. Multiplying every work
by twelve prices purchases that grant nothing. The channel's real ceiling is
derived per-scope, and the shipped answer is **843,000 / 75 loops / 10 hours**.)*

| ladder, per colony | credits | loops | wall | naive ×12 |
|---|---|---|---|---|
| today (four works) | 28,000 | 2.5 | 20 min | 4.0 h |
| **shipped (§126: 11k/17k/28k/45k)** | **101,000** | **9.0** | **72 min** | — see channel |
| the estimate this doc shipped | ~300,000+ | 27+ | 3.6 h+ | **43 h+** — deleted |

The target is *one colony fully developed ≈ one long session*, and §126 shipped
it at 101,000 — nine loops, seventy-two minutes. The **channel** at its ceiling
(3 relays, 3 repeaters, 15 docks, 15 annexes) is **843,000 / 75 loops / 10
hours**: 76% of the yard's 1,106,200 / 98 loops / 13 hours. That is the right
shape for a terminal sink — the largest thing in the game that is not the ship,
never longer than it, and entirely optional. `THE CATALOGUE IS THE LONGEST
PRICE` now clears by 24% rather than by an order of magnitude, which is the
first time that law has had anything to hold.

**Stated as fractions, not constants** (§124's rule): the four existing works
re-price to ~3 loops together, the four new ones to ~6, and the spec derives
credits from whatever `PACINGTEST` measures at the time rather than from these
figures.

**One DEFECTS-class note, stated now:** §114's `EVERY SINK IS PRICED` walks an
**authored** list. Every new work and every new fee must be added to it in the
same commit, or the instrument reports a world it no longer describes.

## 5. The re-pricing sketch (provisional numbers, §99's posture)

| sink | today | proposed | law that holds it |
|---|---|---|---|
| rescue at far marks | 1,869 | **4,500** — BUILT (§123/§124); this row first read "~12,000–14,000" | new BAND: measured-steady fraction ∈ [0.30, 0.50]; ceiling law unchanged |
| repair full | 1,400 | ≤2,800, possibly untouched | Finding 1 recorded as the reason |
| requisitions `REQ_MULT` | 5.0× | ~8.0× | widens the anti-printer margin *and* deepens the sink |
| colony/beacon jumps | 120–500 | modest or untouched | rescue must still exceed the jump everywhere |
| works ladder | 28k/colony | **~90k–135k/colony** staged (was "~300k+", §124) | catalogue stays the longest price |
| the wager | stakes ≤4,000 | optional deep table, 16,000 stake | odds printed, streak-capped, EV-negative as ever |

## 6. What this pass killed

1. The courier — §5 inversion. 2. Insurance — §109's second currency.
3. Charted escort pricing — §72. 4. Deep escort — no provider in the fiction.
5. THE GLASS — §111's dead rung. 6. A flat repair raise — Finding 1's
instrument blindness. 7. Rescue riding the jump ramp — §114's anchoring defect,
retired at its last site.
