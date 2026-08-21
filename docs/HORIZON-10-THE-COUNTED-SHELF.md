# Horizon 10 — THE COUNTED SHELF

Opened 2026-08-21, after a second week of playtesting. Seven commits.
STRATEGY §107–§114. Save v26 → v27.

## What the playtest said, and what was actually true

Five complaints came back. Three of them had a different cause than the
symptom suggested, and finding that out is what set the commit order — so the
corrections are recorded here first, before the plan they produced.

| # | the complaint | what the code says |
|---|---|---|
| 1 | "can't buy at markets — long lists, sell only" | **The buy verb has worked since phase 1.** What is missing is a *counter*: 21 of 34 goods are `no_retail`, so most rows read FENCED, and no station has ever had an inventory. |
| 2 | "the economy is trivial; dying is inconsequential" | True, and worse than reported. Charted death costs nothing *by taught promise*; deep death spills cubes that **never expire**; free emergency warp from 9,000u is **cheaper than a beacon jump**. And after the ~1.1M catalogue, nothing in the game costs credits at all. |
| 3 | "forge materials never drop" | Substantially a **copy defect**. `READS_AS` is not monotone, but the hint line prints `BAND n+`. Four of eight inputs are unobtainable by following the game's own instruction. |
| 4 | "why survey?" | The payoff exists and is undiscoverable: filing with the network buys far-mark literacy, which is where the ten legends stand. Nothing teaches the chain. Also: **charts have no read/unread state**, so complaint 2's "unread charts" is unread *salvage*. |
| 5 | "expand the skills, RuneScape-style" | Four real XP ladders already exist and are governed by written law: information / a choice / access / time, never credits or stats; disjoint feed verbs; no skill screen. |

## The four scope decisions

Taken by the author on 2026-08-21, before any code:

- **10–12 skills and one shared ledger page**, not twenty with a screen each.
  §19's refusal stands per-skill and is amended only far enough to admit a
  record.
- **Death prices the RESCUE.** The tutorial's promise — *you lose position and
  tempo, never salvage* — stays literally true in charted space. The deep gains
  a bill and a clock.
- **The sinks are requisitions, colony/station investment, and operating
  costs.** Prestige purchases were offered and declined.
- **A filed cell becomes a paid jump anchor.** §87 cut beacons from eight to
  three because free route-threading killed the recover verb; the fee, the
  depth cap and the length of the chain that earns this are the answer, and
  §112 has to make that argument rather than wave at it.

## The commits

| # | commit | save | state |
|---|---|---|---|
| 1 | **The shelf is finite** — per-counter stock derived from the bias tables; events as masks; MARKETTEST given assertions | **v27** | **BUILT** — §107 |
| 2 | **The word on the shelf** — stock at the rumour desk, a FRIENDLY+ reserve as a gate, deep-station events | rides v27 | **BUILT** — §108 |
| 3 | **The tug and the claim** — depth-scaled rescue fee, claim clock on deep spills | rides v27 | **BUILT** — §109 |
| 4 | **The order book** — the hint that lied, two widened read windows, requisitions | rides v27 | **BUILT** — §110 |
| 5 | **The ladder** — seven new skills, four deepened, one ledger page | rides v27 | not built |
| 6 | **The sounded ground** — teach the chain, held cells as anchors, colony works | rides v27 | not built |
| 7 | **The measure** — re-derive the pacing band, derive the README's counts | none | not built |

## The constraint that shapes all seven

`MIDTIER` reads **2.91 ± 0.05 against a hard 3.00**. There is roughly nine
hundredths of a mid-tier module of headroom in the entire economy, which means
**no commit in this horizon may add income**. Every feature here is a sink, a
cap, or neutral:

- a shelf *reduces* the ceiling on repeat farming and touches the standard loop
  not at all, which `THE SHELF SERVES THE STANDARD LOOP` measures rather than
  assumes;
- the rescue fee, requisitions, colony works and deep repair are all outflows;
- skill tiers pay in information, a choice, access or time, and
  `NO LADDER PAYS IN CREDITS` will assert the wallet does not move.

Commit 7 re-derives the band from a real sweep. If it lands red, that IS the
§41 re-derivation arriving — the answer is a decision about yields or about the
band, taken in the open, not a nudge toward whichever number is green.

## Verification

There is no Godot binary in the authoring environment and `run_harness.sh` is
macOS-bound in three places, so **nothing here is self-verified**. Every commit
stages as: write → hand over the commands → the author sweeps → the commit body
quotes the real output. No commit body asserts a sweep nobody ran.
