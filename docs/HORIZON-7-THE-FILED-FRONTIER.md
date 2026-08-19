# Horizon 7 — The Filed Frontier

**Status: COMPLETE — every commit BUILT (§82–§87, §91). Commit 4 shipped the fragments as approved, the rival's wreck with them, and cut the per-visit meter; commit 5 shipped teaching and stock 8 → 3.** When any of it is adopted, record it in
`docs/STRATEGY.md` §64 in the same commit, per the house rule.

## What this answers

Horizon 6 made the deep *legible* (§78), *navigable* (§79) and, in its last
commit, *remembered* (§80). Survey coverage is the first persistent mark a
player has ever left on the expanse.

This horizon is about what that mark is worth. Three claims, in order of how
much of the game they change:

1. **The fiction and the mechanic disagree about charts.** The premise is
   selling charts of places nobody has filed a return from. The mechanic is
   `chart_drift x8`, fungible, priced by band. Nowhere does it matter *which*
   place, or that you were first.
2. **Nobody else is out there.** The deep is a pure function with no agency in
   it. Depth is risky; it is not contested.
3. **THE UNSOUNDED is an expensive door with a supply closet behind it.**
   Band 6 starts at 5,200u and the jump caps at 4,200 — by deliberate design
   the only place in the game you must fly to. What is there is one extra roll
   (`hulk2`, `deep_space.gd:1147`) and slightly denser tables.

---

## What the research changed

Six findings that reshape the work. Three of them kill the obvious design.

### Provenance cannot be per-item, and does not need to be

`GameState.cargo` is `{good_id: units}` (`game_state.gd:186`) — fungible by
construction, and every consumer assumes it: `load_cargo`, `unload_cargo`, the
hold grid, `cargo_used`, the interdiction weight. Making a chart name a cell
would be a cargo refactor touching the whole economy.

It is also unnecessary. **The coverage store already records which cells you
worked.** So the hold stays fungible — chart data is *data*, and volume is what
the interdiction system needs from it (`interdiction_weight: 0.5`, and
`commodity_db.gd:288` argues at length why it is not 0) — and **the sale is
where provenance lands.** A first-filing bonus paid at the counter, priced from
cells you have surveyed and not yet filed.

One new flag on one existing store, instead of a refactor.

### The rival needs no save at all

The instinct is a stored rival-progress dict. But the codebase's own instinct is
better: the deep is a pure function, and so is a ghost. Rival coverage can be
`f(system, run_seed, played_seconds)` — deterministic, zero bytes, and it
**races your clock** because `played_seconds` is your clock. §17's "revisiting a
sector costs zero bytes" applies unchanged.

That also settles the v1 scope question. The rival is never seen. No AI, no
pathing, no combat. Evidence only.

### A sighted colony has nowhere to be recorded — this is a live gap

Hyper structures are always present, 3–5 per system, at depth 1600–4200
(`system_db.gd:933`), **with no radar tier and no chart layer until claimed** —
`colonies_in` reads the claimed store. The silhouette argument
(`hyper_structure.gd:15`) is deliberate and good: finding one is a ~54-minute
circumferential sweep, an expedition rather than a lottery.

But you can fly past one, be driven off by its wardens, and have **no way to
note where it was.** That is not the design being hard; it is the design losing
information the player earned. It folds into commit 1 as a third mark type.

### Band 6 is one roll different from band 5

`grep 'band >= 6' scripts/deep_space.gd` returns exactly one hit: the second
grave hulk. Everything else out there is the band tables scaling. Whatever
answers THE UNSOUNDED has to be authored, because nothing about the generator
distinguishes it today.

`chart_unsounded` already exists as a good (`commodity_db.gd:326`), unearnable
in practice — nobody flies fifteen minutes for one crate.

### The signature-site pattern is the right template, and it scales

`signature_site.gd` is one class, three kinds, duck-typed into the hold
contract, streamed like anything else, and its header states the rule that keeps
it honest: **"the gradient is parameters, not new classes."** An UNSOUNDED
structure is that pattern with the volume up — and explicitly *not* a fourth
thing that shoots, for the reason that file already gives.

### §41's `MIDTIER` debt now blocks the economy work

§80 moved surveys out of the recurring term, so the steady loop is measured
honestly poorer against an unchanged [0.60, 3.00] band. Adding a *new* income
shape on top of an unresolved bar means tuning two things at once and knowing
which moved neither. **This sequences first, and it is not optional.**

---

## Commit order

| # | Commit | Save | Why here |
|---|---|---|---|
| 0 | §41 `MIDTIER` re-derivation | — | Blocks everything economic. Measurement and a decision, not a feature. |
| 1 | Marks: filed charts, sighted structures | **v22** | **BUILT — §82.** Provenance's storage half, plus the live colony gap. No pricing yet. |
| 2 | The counter pays for being first | — | **BUILT — §83.** Landed ahead of commit 0: the bonus never enters the recurring loop (asserted), so it cannot move §41's bar. |
| 3 | The other cartographer | — | Needs "first" to mean something. Zero save: a pure function. |
| 4 | THE UNSOUNDED answers | **v23** | Independent of the economy. Can run in parallel with 2–3. |
| 5 | Small: beacon stock, deep onboarding | — | Both cheap, both overdue, neither blocking. |
| — | Long expeditions | — | **Deferred, deliberately.** See the last section. |

---

## Commit 0 — Pay §41

Not a feature. `STEADY MIDTIER` measures the recurring loop in mid-tier modules
against [0.60, 3.00], and §80 made that loop poorer by two once-only surveys
without touching the band. Either the band is wrong, the yields are wrong, or
the loop composition is wrong, and the answer is a decision taken in the open.

Run `PYXIS_PACINGTEST` and read the actual numbers first. The commit body states
which of the three moved and why. **No number is nudged to make a leg green** —
that is the failure §64 names explicitly.

Ships with whatever `STEADY MIDTIER` and `ROUTE PARITY` say afterwards, green or
argued.

## Commit 1 — What the chart records (v22)

**`survey_coverage` values become a small dict**, `{filed: bool}`, from bare
`true`. Defaults-not-branches: a v21 file's `true` migrates to
`{"filed": false}` — everything you surveyed before is unfiled and therefore
still worth the bonus, which is the generous reading and the correct one.

**A second store, `structures_seen`**, keyed the same way — `"pyx02:31:-7"` —
recording a hyper structure you came within silhouette range of. Sparse, tiny
(3–5 per system, ever), and it closes the gap above. The chart draws them as
hollow diamonds: seen, not yours. Claimed ones keep the filled square.

Cap and loader follow `survey_coverage`'s own posture exactly (§80) — the
per-system cap, oldest-first eviction, insertion through the same cap on load.
`structures_seen` needs no cap: it is bounded by `HYPER_MAX` per system by
construction, which is worth an assertion rather than a cap.

**Harness.** `A FILED CELL IS NOT AN UNFILED ONE` (both directions — a migration
that marks everything filed passes half of it perfectly); `THE STRUCTURE STORE
IS BOUNDED BY THE GENERATOR` (never exceeds `hyper_positions().size()`, asserted
against the generator rather than a literal); `migrate21` with the usual rubbish
pass; and the sighted-structure store joins `NO BLEED BETWEEN PILOTS`, since it
is the newest field and that is exactly when a leak ships.

## Commit 2 — The counter pays for being first

Selling chart data at a port pays a **first-filing bonus** for each surveyed-
but-unfiled cell the sale covers, then marks those cells filed. The bonus scales
with depth and is paid **once ever, per cell, per pilot**.

Three design constraints, each with a reason:

- **The bonus is a bonus, not the price.** Base chart-good value is unchanged,
  so a player who never thinks about filing loses nothing they have today. This
  is additive income on top of a bar just re-derived in commit 0 — which is why
  commit 0 is commit 0.
- **It converts §80's accepted trade into the point.** §80 recorded that
  persistence burns the near ring and makes chart income an outward treadmill.
  The bonus is what makes that a *pull* rather than a *tax*: the near ring is
  filed, so going out is where the money is, which is the sentence the whole
  game rests on.
- **A ledger of what you filed.** The ledger already exists. "Places I named" is
  the cheapest emotional payload available and it is currently unavailable.

**Harness.** `THE BONUS IS PAID ONCE` (sell twice, second sale pays base only);
`AN UNFILED CELL IS WORTH MORE THAN A FILED ONE` (measured, not assumed);
`FILING DOES NOT MOVE THE STEADY RATE` — the bonus is one-time by construction,
so `PACING_LOOP` must not name it, the same shape as `MINING IS A ROUTE, NOT A
RAISE`.

## Commit 3 — The other cartographer

A rival surveyor working the same deep. **Never seen. Evidence only.**

Rival coverage is a pure function of `(system, run_seed, played_seconds)` — no
store, no node, no AI. It answers one question: *has the rival filed this cell
by now?* Cells fill outward from the charted edge at a rate slower than a
committed player and faster than a casual one, so the near ring goes first and
the deep stays yours if you push.

What the player actually meets:

- **A cell already filed when you arrive.** The mast still pays base; the
  first-filing bonus is gone. Toast names it — *"FILED ALREADY — SOMEBODY WAS
  HERE"*, per §58's rule that a refusal states its own terms.
- **Beacons that are not yours**, in a livery that is not yours. Reuses the
  beacon node and the livery accent wholesale.
- **Eventually, their wreck.** One authored site, deep, carrying their log. This
  is where the rival stops being a rate and becomes a person — and it is the
  only part of this commit that is content rather than arithmetic.

**The design risk, stated plainly:** a rival that takes things the player earned
is punishing. This one takes only *opportunity*, never property — nothing you
have filed is ever un-filed, no beacon of yours is ever removed, no cargo is
lost. The loss is always "you could have been first here", which is a reason to
go further out, which is the game.

**Harness.** `THE RIVAL IS A PURE FUNCTION` (same seed and clock, same answer,
twice); `THE RIVAL NEVER TAKES WHAT YOU HAVE` (a filed cell stays filed across
any amount of rival advance); `THE DEEP OUTRUNS THEM` (at band 4+ rival coverage
is materially behind a player who flew there, measured, not asserted);
`THE RIVAL IS NOT A DIFFICULTY DIAL` (no combat, no spawn, no faction delta).

## Commit 4 — THE UNSOUNDED answers (v23)

One authored structure per system, past 5,200u, that takes more than one
expedition to read and recontextualises the four bands you crossed.

**What it is not:** a boss. §76's signature-site header already argues this —
the deep has hulks, packs, traps and guards, and a fourth thing that shoots is
the existing vocabulary in a new hat. This is a *place*, and the reward is an
*answer*: what killed the frontier.

**Shape.** The `SignatureSite` pattern with the volume up — one class, three
kinds, one per Pyx, streamed like anything else, duck-typed into the hold
contract. Read in stages, each stage a hold that costs time and pays a fragment
plus `chart_unsounded`, which finally becomes earnable in quantity. Progress
persists (v23) because the whole point is that one trip is not enough.

**The honest risk:** this is a *writing* problem as much as a code one.
Under-written it is an anticlimax at the end of a fifteen-minute flight, which
is worse than the supply closet. The three fragments want drafting and reading
aloud before any of the mesh work starts.

**Harness.** `THE ANSWER SURVIVES THE WARP` (staged progress persists, both
directions); `IT IS NOT A FIGHT` (spawns nothing hostile, joins no combat
group); `ONE PER SYSTEM, AND ONLY OUT THERE` (never below band 6, never two);
`THE FRAGMENTS ARE ALL REACHABLE` (every stage is completable from the previous
one — an unreachable last fragment is the failure mode nobody would notice).

## Commit 5 — Two small overdue things

**Beacon stock.** Eight was tuned when a beacon was a passive bookmark. §79 made
them navigable, which multiplied their value: a beacon is now a free flight to
anywhere you have been. The number wants re-deriving against what it now buys —
and this is a playtest question, not an assertion question.

**The deep teaches nothing past the tutorial.** Barks fire once, the manual is
good, and band 4 has no onboarding at all — which is where the interesting game
lives. §76 built the per-band, per-system broadcast overlay; that is the
natural teacher and it is already there. A handful of authored lines, fired on
first entry to each band, using the machinery that exists.

---

## Verification

No Godot binary in the authoring environment, so every commit stages as: write →
`python3 tools/check_scripts.py` → hand over the commands → the sweep is run on
the machine that has the binary → the commit body quotes real output.

Two rules this horizon inherits and should keep, both earned the hard way:

- **The full adversarial pass is not the default.** It found real defects
  (§78's unclipped rings) at a cost that did not scale — 24 candidates
  collapsing to 6 distinct, four lenses finding the same bug. Reserve it for
  commits 1 and 4, the two that touch save shape. Everything else gets a
  targeted check on the specific thing being suspected.
- **The sweep is the real gate.** Two of the three worst defects in Horizon 6
  were found by *running*, not reading — and §81's was found only because a
  live save had fuller state than the harness assumed.

Red-verification per the README's fourth house rule: each new assertion is
confirmed red when its bug is reintroduced, and the reintroduction is named in
the commit body. The ones that matter most here are `THE BONUS IS PAID ONCE`
(pay it twice), `A FILED CELL IS NOT AN UNFILED ONE` (migrate everything to
filed), and `THE RIVAL NEVER TAKES WHAT YOU HAVE` (let rival advance clear a
player cell).

## Deliberately not in this horizon

**Long expeditions** — provisioning, a reason you cannot turn back. It is the
idea most likely to become tedium, and it only earns its place once commit 4
gives THE UNSOUNDED something worth the trip. Revisit after, with the answer
already built.

**PYX-04.** §76 just made three systems read differently; a fourth is content,
not depth, and it dilutes work that has barely shipped.

**More module tiers.** §64 already records that six Mk II tiers grew the catalog
84% and moved no pacing at all. That lesson is written down; paying for it twice
would be a choice.

**Chart trading between pilots.** §2's "local save, explicitly serialized, keeps
a server port possible" is preserved, not spent — and chart data is exactly the
right artifact for it if it is ever wanted. Out of scope here: this horizon has
no network code in it.
