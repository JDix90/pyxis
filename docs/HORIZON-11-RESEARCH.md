# Horizon 11 — the research pass

Opened 2026-08-21, the evening Horizon 10 closed (§107–§113, 813 across 81).
Fifteen ideas came out of that session — six game, four worries, five process.
This document is the pass that reads the code before proposing anything, in
this repo's own habit: **findings kill or reshape ideas, and the ones that die
on contact are the valuable part.**

Nothing here is built. Sizes are estimates, and every number below was measured
from the files named beside it rather than recalled.

---

## 0. The finding that reorders the whole list

Three of the fifteen items circle the same hole without naming it, so it gets
named first.

### The game has an income instrument and has never had a wealth instrument

`PYXIS_PACINGTEST` measures **earning rate**: `_pacing_earned` folds seven
measured yields over an authored 8-minute loop and divides by
`ModuleDB.MODULES["rig_strike"].price` (14,500). `STEADY MIDTIER` and `MIDTIER`
assert that ratio sits inside `[0.60, 3.00]`. §113 records it holding.

**Nothing anywhere measures a balance, a sink, or a lifetime spend.**
`DEFAULT_LEDGER` (`game_state.gd:78`) has seven keys and not one is a credit
figure: `deepest_depth`, `distance_flown`, `hulks_cracked`, `posts_cleared`,
`chart_data_sold`, `tolls_paid`, `cells_filed`. So the entire sink side of the
economy — the thing Horizon 10 was *about* — is unmeasured by construction.

### What that hides, in numbers

`MIDTIER` at 2.91 × 14,500 = **~42,200 per best-case 8-minute loop**;
`STEADY` (the same loop less one derelict and two surveys) is lower, and the
horizon doc's own `~1.1M catalogue` against the recorded steady catalog ratio
of 0.031 puts it near **~34,000 per loop**. Take the conservative figure. Every
credit sink in the shipped game, converted:

| sink | credits | loops | wall clock at ~34k/loop |
|---|---|---|---|
| the full module catalogue | ~1,100,000 | ~32 | **~4.3 hours** |
| all colony works, every colony (15 × 18,000) | ≤270,000 | ~7.9 | ~63 min |
| three requisitions at the dearest component (900 × 5) | 13,500 | 0.40 | ~3.2 min |
| repair to full (`REPAIR_FULL_PRICE`) | 1,400 | 0.041 | **~20 s** |
| **the tug at the far marks** (`rescue_fee`, deepest) | 1,870 | 0.055 | **~26 s** |
| a beacon jump at its depth cap | 500 | 0.015 | ~7 s |
| the tug at the chart edge | 240 | 0.007 | ~3 s |
| a rumour at the desk | ~400 | 0.012 | ~6 s |

Even at the band's **floor** — 0.60 × 14,500 = 8,700 per loop, the poorest
legal economy this project asserts — the deepest possible rescue is 21% of one
loop, and a repair is 16%.

### So worry #7 has an answer, and it is not the one it expected

*"Does a mid-game pilot ever feel poor again, and does the rescue fee bite at
the wrong moment?"*

**No, and it cannot bite at any moment.** A pilot is poor for exactly as long
as the catalogue is unbought — about four hours — and after that the entire
remaining sink inventory in the game is ~300k, roughly **nine loops, about
seventy minutes**, spread across a run of tens of hours. Horizon 10 did not
fail to move this; it moved it by about an hour, which is a rounding error
against 4.3 hours of catalogue and an unbounded run past it.

The rescue fee is the sharpest case and the reason is structural. §109 priced
it at **2× the beacon jump** — deliberately, and the arithmetic is sound. But
the jump was never priced against income either. **Every price in this game is
anchored to another price, and no price in this game is anchored to the loop.**
That is one sentence and it explains all of it.

### And one third of Horizon 10's scope silently did not ship

§64 records the author's four scope decisions of 2026-08-21. One of them:

> the sinks are requisitions, colony/station investment and **operating
> costs**, and NOT prestige purchases

Requisitions shipped (§110). Colony/station investment shipped (§112).
**"Operating costs" appears exactly twice in the entire repository** — in that
§64 sentence and in the same list in `HORIZON-10-THE-COUNTED-SHELF.md`. It is
in no commit, no section, no assertion, and it is **not in §64's deferral
list**. It was not built, not deferred, and not refused. It was dropped
silently, which is precisely the failure mode §64 exists to prevent, occurring
inside §64's own paragraph.

**And the code refuses it, in writing, from 2026-08-04.** §5's base-building
amendment states the boundary that survives the lifted exclusion:

> no clocks, no queues, **no currency sink pretending to be a decision**, and
> nothing that rewards logging in rather than flying. If a structure takes time
> to become something, the time is *spent flying to it with what it needs* —
> the trip is the cost … **Nothing may be built by waiting.**

An upkeep bill is a clock and a currency sink that is not a decision. §5 killed
operating costs a year before they were scoped. **The right outcome is not to
build them and not to quietly forget them a second time: it is to record the
refusal at §5's own terms and close the item.** That is finding #1 for the
horizon plan below.

---

## 1. The game ideas

### Idea 1 — the rival files with the network too

**Status: ALREADY BUILT, and the proposed read is unsound.**

`network_filing_plan` (`main.gd:1440`) already sorts unfiled cells into
`cells` (yours to pay for) and `lost` (the rival got there first), and
`file_charts_with_network` calls `note_survey_held` on **both** — with the
reason written at the site:

> THE RIVAL'S CELLS COME HOME FREE … Here the somebody IS the network — their
> colleague already clipped that mark to a mast — so it is held without costing
> a reading.

The copy already says it: `ALREADY HELD BY A COLLEAGUE` vs `ALREADY FILED BY
ANOTHER HAND`, switched on `files_with_the_network()`. The community reading is
shipped.

**What is genuinely missing** is that the *chart* cannot tell the two apart:
`chart_panel.gd:632` draws the same open ring for every `is_survey_held(cov)`.

**And a derived read off the Rival hash CANNOT supply the difference.**
`Rival.filed()` is `floorf(seconds / STRIDE_S) * STRIDE_S >= arrival_seconds(key,
depth, seed)`. `arrival_seconds` is fixed per (key, seed); `played_seconds`
only rises. **The predicate is monotone: once true, true forever.** So a cell
the player filed *first* at hour one reads `Rival.filed == true` at hour twenty,
and a derived chart would retroactively re-label the player's own firsts as a
colleague's. The distinction exists only at the instant of the act.

This is the exact inverse of §97's `files_with_the_network()`, which *is*
derivable because it is an existential over a store that only grows. **Worth
recording as a rule: a fact about WHEN something happened cannot be derived
from a monotone predicate about whether it has happened.**

*Reshaped:* a third validated value in `survey_filed` (`HELD` → `HELD` /
`HELD_BY_ANOTHER`), on §98's `MARK_STATES` precedent — a store that already
holds two types and has exactly one function (`is_survey_held`) that knows how
to ask. `_load_survey_filed` validates by type and drops anything illegal, so
a third legal word is one `elif`. **Additive, no save bump** (an old file
simply has none of the new word, and reads as "all mine", which is what it was).
Cost: ~40 lines + one leg + a chart glyph. Risk: low. Value: the chart becomes
two documents, which §97 already argued for and could not draw.

*One consequence to decide, not to discover:* rival-held cells are already
`anchor_rows` candidates at FILING t3. A colleague's cell is a free anchor
today. That is arguably right (§112: "a place somebody keeps a light on") but
it is unstated, and if the chart starts distinguishing them somebody will ask.

---

### Idea 2 — the all-ladders capstone

**Status: reachable, cheap, and it has one real design objection.**

Reachability checks out. `hyper_positions` yields `HYPER_MIN..HYPER_MAX` = 3–5
per system across 3 authored systems → **9–15 structures**, against
`colonial: [0,1,3,6]`. `FarMarks.PER_SYSTEM = 5` → 15 marks a run, against
`hunting: [0,1,4]` (3 apexes + ≥1 legend). No ladder is longer than its feed.

The check spans two representations — `skill_tier(name)` against
`SKILL_TIERS[name].size()-1` for the seven, and four bare vars against four
`*_TIERS` arrays for the legacy — but **derived from the tables in both cases**
it is ~15 lines and immune to 5c moving the caps. The payload is one
`hud.show_broadcast` on the **broadcast plate**, which is a different channel
from the crowded prompt line, so idea 10 is not a dependency.

**The objection is §19's, turned around.** §19's law is that skill feeds must
*compete* — "an hour smuggling is an hour not cracking hulks" — "or four skills
all fed by playing the game rise together and it is a clock, not a decision."
A reward for capping **all eleven** converts that competition into a completion
list: it tells the player the correct long-run answer is *do all of it*. And
§111 already wrote the sharper version of this: *"a ladder longer than its feed
is a checklist that cannot be finished."* Eleven rows all of which must tick is
a checklist by construction.

*Recommendation:* build it, and **build it invisible**. No counter, no `3/11`,
no achievement row, no mention on the ledger page that a capstone exists. The
pilot's page already lists eleven ladders, so a player can infer it; the game
never poses it. That is the register `SINGULAR` legends and THE WATCH already
use (§102, §112: *"speaks once, unprompted and unpriced"*). Refused in advance,
in the spec: a progress counter, a checklist row, and any second grant.

---

### Idea 3 — the spill claimant gets a face

**Status: blocked on an open §64 question, and the audience is nearly empty.**

`_tick_spill_claim` (`main.gd:1758`) is a deadline on `system_root` LootCubes
with `spill` set. It fires **only when the player did not come back** — the
window is `180 + 0.15 × depth` seconds (390s at 1,400u, ~25 min at the marks),
which is far longer than the flight. So the expiry is, by design, the branch
where nobody is watching. A hull that arrives at T+0 plays to an empty room.

A hull that arrives **early** and works visibly is the good version — and it
walks straight into the §64 item that has been open since 2026-08-06:

> **Should an ALLIED ship be spared the player's area weapons?** … Splash
> catching a flag is deliberate and measured — `WITNESS_RANGE` is dimensioned
> by `OVERCHARGE_RADIUS`

A competitor the player can shoot is a combat encounter, which is not the
feature. One they cannot shoot is a ghost, which is worse. One that splash
catches by accident reopens the §64 question under a new name. **Idea 3 cannot
be specced until that line is drawn**, and drawing it is a bigger decision than
this feature deserves to force.

*Reshaped, and it is better:* keep the claimant faceless and give it a
**consequence** instead of a body. The pile is not deleted — it is *taken*, and
somewhere out there the goods surface. A claimed spill could seed a single
`deep_event` GLUT on that good at the nearest deep counter, in that cell,
carrying the same `event_place` name §108 built. No AI, no class, no new node:
**the claimant is evidenced by the market, which is the register this game
already uses for the rival.** §51-safe (the player's own goods), income-neutral
(a GLUT lowers the sale price of a thing you no longer have), and it turns the
one branch nobody watches into the one branch that leaves a mark.

*Refused for later:* an actual hull, until the splash question is settled.

---

### Idea 4 — a second weather kind: a pressure front

**Status: the mental model does not match the code. One reshape survives.**

Three findings, in order of severity.

1. **There is no per-band raider roster to shift.** Raiders are one kind
   (THE TITHE), rolled every 20s off *hold value* — `RAID_MIN_HOLD 1500`,
   `RAID_VALUE_SCALE 40000`, clamped `[0.05, 0.35]` — and then **tapered by
   depth**: `DEEP_RAID_TAPER = [1.0, 0.6, 0.3, 0.1, 0.05, 0.03, 0.02]`.
   Raiders effectively do not exist past band 2. The deep's threat is packs
   and guard posts, and those are `PACK_*[band]` / `GUARD_*[band]` lookups
   keyed on `band_of(depth)` inside `plan_cell`.

2. **Shifting a band's packs is a money printer or a tax, with nothing
   between.** `PACK_DROP[band]` rides the same index as `PACK_DIFFICULTY[band]`.
   Carry the drop with the difficulty and relics appear at band 2 — a shallow
   farm, §11. Leave the drop behind and it is a harder fight for a worse
   payout, so the correct play is *stop flying until it passes*, which is a
   feature that asks the player to put the game down.

3. **`plan_cell` is a pure function of `(system, cx, cz)`** — `rng.seed =
   hash("%s|%d|%d")`, no time term — and STREAMTEST compares a synchronous
   build against an amortised one. A time-varying band is buildable *only* the
   Rival's way (stride-quantised, seeded, zero save); that precedent exists and
   works, but it is machinery spent on (2)'s dead end.

4. **§51 has an assertion in the way.** `THE DEEP IS STILL UNCLAIMED` (leg 16,
   `main.gd:22239`) exists so a spawner cannot reach a flag past band 2. A
   front that moved flagged patrols outward reddens it.

*Reshaped, and this one is good:* a front that occupies a **QUADRANT**, not a
band. `DeepSpace.QUADRANTS`, `quadrant_of(pos)` and `compass_deg` already ship;
the chart already draws the compass rose from the same table (§78/§108's
"which way is which"); the rumour desk already names quarters of the sky. A
quadrant is **routable** — you leave on a different bearing — where a band is a
concentric ring you must cross to go anywhere. That is the difference between
"tactical routes with zero new payout" and "wait ten minutes".

What it may move, to stay income-neutral: the **raid taper** and nothing else
— more raiders on the loud bearing, unchanged elsewhere, unchanged totals if
you route around it. Announced on the comms plate, drawn on the chart as an
arc. Cost: a `Front` static (Rival's shape), a taper multiplier, a plate line,
a chart arc, three legs. Risk: medium — it is the first thing in the game to
make a *place* temporarily worse, and the pacing argument has to be made
against `_pacing_earned`, not asserted.

---

### Idea 5 — a colony work that takes a delivered good

**Status: the strongest of the six, and the code tells you exactly where the
first draft would have gone wrong.**

**The defect the naive version carries:** colony works are bought **from the
chart panel** (`chart_panel.gd:1254–1279`), a menu the player can open from
anywhere in the game, including while docked at the counter they just bought
the goods from. There is no position gate on a work and never has been. A work
that checked `GameState.cargo` from that button would let twenty alloys
teleport four thousand units. **The word "delivered" would be a fiction with no
mechanism behind it** — which is exactly the class §110's forge hint belonged
to, a sentence the data does not support.

**And the annex cannot carry it either.** `can_store == no_retail`
(`game_state.gd:2831`), and the comment says why: an open bay on a retail good
is a timed-arbitrage printer (`buy alloys under a 0.55× glut, put them down,
wait for the event to lapse, sell at the SAME counter for 1.61×`). Alloys are
retail. The bonded rule refuses them by design.

**§5 already wrote the fix, on 2026-08-04:**

> If a structure takes time to become something, the time is *spent flying to
> it with what it needs* — **the trip is the cost**, which is the trade the
> whole game already rests on.

So the work is raised **at the structure**, with the goods in the hold, through
the affordance that is already there: the chart row stays, disabled, and says
its own terms — the posture `SOUND ITS GROUND FIRST (WORK A MAST IN ITS CELL)`
already uses (§58, and `buy_colony_work`'s gate-then-purchase order, with the
refusal free). `main.buy_colony_work` is already the one place that asks the
world's questions on the store's behalf; a second world question is one more
line in the same function.

**The price is a gate, not a price.** Twenty alloys is 800 credits of base
value — **1.1 seconds of loop income**. The goods cost nothing; the *hold* and
the *flight* cost everything, and a starter hold is 24 space against a
1,600–4,200u colony. That is the trade §5 describes, and it means the credit
half of the work must stay a credit price. GATES, NEVER PRICES, applied to a
work.

**On feeding BROKERAGE:** tempting and I would not. §111 pinned BROKERAGE to
"deliveries ONLY — *any contract* would rise alongside three other ladders'
work", and a colony haul is colony play, which already feeds COLONIAL. Two
ladders rising off one afternoon is §19's clock arriving through a feed.
`FEEDS COMPETE, SIX WAYS` would not catch it (it fires one feed and checks one
moved) — this is a fact about where the call lives, not about what it does.

**What service the fourth work returns is still open** — every existing work is
information, time or access (§26), and a fourth needs a fourth answer that is
not a stat, a price or an income term. Two candidates worth arguing, neither
researched yet: a **kept light that holds a spill** in its system (extends
§109's claim clock — time, and it braids with idea 3), or a **deep repeater**
carrying the deep's own weather where the relay carries the chart's (§113 lists
that copy gap as open).

Cost: ~120 lines, one dict entry, one gate, one leg, one refusal string.
Risk: low. Save: additive to `colony_works`, no bump.

---

### Idea 6 — the procession passes a kept light

**Status: the cheapest good idea in the list, and the fiction is already
fully loaded.**

Everything it needs is written and none of it is connected:

- `BROADCASTS[5]` is literally titled **`A KEPT LIGHT`**: *"There is a light
  ahead of you. It is kept. It has been kept a long time, and by somebody."*
  and its `body_after` closes with *"It is lit for whoever is still out here,
  which by the authority's own ledger now includes you."*
- COLONIAL t3's perk is named **`KEPT LIGHTS`** (§111) — a founded colony
  borrows `TIER_HOME` on the radar so its light never fades.
- `Procession.ATTACHMENT` is seven named hulls that filed and were not
  counted, and `UNNAMED_LINE` covers the twelve beside them and the 260 behind.

The player's colony *is* a kept light, in the game's own words, and the
procession is the uncounted. Idea 6 closes that circle.

**Do it as a broadcast, not as geometry.** The procession's position comes from
its far mark; a colony's from `hyper_positions`. Forcing an intersection means
moving one of two independently-salted generators, and §102/§105 both hold that
a legend is a *place*. Nothing needs to move: the condition is
`the procession exists in this run AND the player holds a colony`, and the
payload is one plate. `hud.broadcast_busy()` already exists for exactly this
(§96: *"a caller with something that can WAIT asks first"*), so it never stomps
a hull's attachment entry.

**Once per run and no store.** `Procession` already refuses to spend its mark;
this must not become the thing that does. A session flag, the storm's own
posture (`session weather, never generated world`).

Cost: ~50 lines, one broadcast, one condition, one leg. Risk: very low. It
pays nothing, which §105 says is the point.

---

## 2. The worries

### Worry #7 — sink-rich economy, stale feel data

Answered in §0 above, and it is the horizon's spine rather than an item on it.
The two deliverables it implies:

1. **A wealth instrument.** `PACINGTEST` already computes `earned` for the
   standard loop; a `SINKS` block re-derives **every** credit sink in the game
   as a fraction of that same figure and prints the table. What it asserts is a
   LAW, not a number — §99's posture: *at least one sink in the game costs more
   than one loop*, and *no single involuntary charge exceeds N loops* — so a
   retune moves constants and no assertion.
2. **A rule to go with it**, the counterpart to §11's no-money-printers:
   **a sink's price is stated in loop-minutes.** Anchoring a price to another
   price is how the rescue fee ended up at 26 seconds while being, correctly,
   twice the jump.

Note what the instrument does *not* need: a new store, a balance history, or a
save bump. It is arithmetic over constants the harness already loads.

### Worry #8 — main.gd at 28k lines

**Status: misaimed, and the measurement should be recorded so it does not come
back.**

`main.gd` is 28,626 lines across 268 functions. **22,309 of them (78%) are
harness.** The split is almost perfectly clean: lines 1–5,218 are the game
(144 functions); the first harness function starts at 5,219 and the last ends
at the file's end. The five largest single functions are
`_run_faction_test` (1,954), `_run_save_test` (1,607), `_run_return_test`
(1,463), `_run_deep_test` (1,272), `_run_mine_test` (1,082).

So the game half of `main.gd` is **~5,200 lines** — comparable to
`game_state.gd`'s 4,686 and smaller than the top three other files combined.
Migrating rule functions out of it would move a few hundred lines of the 18%
while leaving the 78% exactly where it is. There is no crisis to fix.

The only refactor with real mass is **extracting the harness**, and GDScript
has no partial classes: every one of 64 functions would have to be rewritten
against a passed-in `main`, touching ~800 assertions in a repo that can only
sweep on one machine. That is the wrong risk for zero player-visible value.

*Recommendation:* kill it, record the 78/22 measurement in STRATEGY so the
proposal does not recur, and — if the itch persists — spend it on
`tools/check_scripts.py --sizes` printing the split, which costs an hour and
tells the truth forever.

### Worry #9 — no new ladder without a new verb

**Status: should be written, and the wording matters.**

It is already how the roster was actually built, and it already has teeth:
`FEEDS COMPETE, SIX WAYS` fires one feed and asserts exactly one ladder moved,
`EVERY RUNG SAYS WHAT IT BOUGHT` fails a rung with no perk string, and
`A TIER IS A GATE` measures each grant at zero and at cap.

What none of them covers is the *proposal* stage — §111's HUNTING deferral and
its two dead rungs were both caught by a human reading the surface, not by a
leg. So the rule is a §, not an assertion, and its honest form is stronger than
"a new verb": **a new ladder needs a feed no existing ladder reads, and a first
rung a player can see.** The second half is §88; the first half is §19. Both
are already the law — this just puts them in one sentence where a roster
proposal will meet them.

### Worry #10 — the crowded prompt channel

**Status: a priority queue is refused in writing, at the site, twice.**

`hud.gd:1954`, on `hold_prompt`:

> **A LOCK RATHER THAN A PRIORITY NUMBER**, because there is exactly one thing
> in this game that gets six seconds to be read while something closes on you.

`procession.gd:32`:

> **THE PROMPT LINE IS FOR REFUSALS ONLY.** It is a single un-wrapped Label at
> font 16 on a 720-wide design space…

And the repo already has **four** devices for the collision class: `_prompt_held`
(a hard lock), `clear_prompt_if(text)` (only clears what is still yours),
`prompt_text()` (read what is up), and `broadcast_busy()` / `toast_busy()`
(ask first, used by the procession to enforce "read them slowly"). §113's fix
for the one red was a fifth: **arm on the refusal, fire at range-exit, stand
down unspent if anything else wrote first.**

63 `hud.prompt(` call sites across 19 files is real crowding. But the evidenced
defect is narrower than "crowded": **a nudge stomped a refusal the player had
not read yet** — the pilot least able to guess, on the first-ever tap.

*Reshaped:* not a queue — **a soft lock with a duration.**
`prompt(text, hold_s := 0.0)`, appended and optional. §108 made that exact call
explicitly, for this exact environment: *"There is no Godot binary in the
authoring environment, a wrong arity is a parse error `check_scripts.py` cannot
see"* — so an appended default leaves 63 call sites byte-identical and changes
only the handful that are refusals. A refusal takes the line for ~2 seconds and
nothing can stomp it; after that the line is ambient again. Two constants, one
timer, ~25 lines, and a leg that raises a refusal, fires an ambient prompt
inside the window, and asserts the refusal survived.

*What it does not need:* a class enum, a priority table, or a queue. A queue
would mean sentences arriving after the moment that made them true, which is
worse than losing them.

---

## 3. The process ideas

### Idea 11 — per-file `godot --check-only` in CI

**Status: real, but smaller than it looks, and it has a prerequisite.**

The gap it names is genuine and documented (§111): `run_harness.sh` parse-checks
`main.gd` only, `main.gd` parses fine while a leaf class does not, and the
sweep then dies at `SurveyMast.new()` with *"Nonexistent function 'new' in base
'GDScript'"*. But §111 also decided where that gap gets closed:

> The pre-flight's blind spot is now covered by the **static pass** rather than
> by Godot, which is the cheaper place for it … no amount of `--check-only` on
> `main.gd` will ever see a leaf class fail.

`check_scripts.py` reads all 70 files in well under a second and currently runs
clean. Its six rules are exact rather than heuristic, but they are six rules
against a full parser, so **Godot per-file is strictly stronger and would catch
classes nobody has thought of yet.**

Two costs to name honestly: CI needs a Godot Linux headless binary, and
`--check-only` on a file that names `DeepSpace` needs the global class cache,
which needs `--import` to have run at least once (the harness's own error
message says so). That is a cacheable step, not a blocker.

*Recommendation:* worth doing, and worth doing as **`run_harness.sh --parse`**
first — a loop over all 70 files locally, on the machine that already has the
binary — before it is a CI job. That is ten lines, proves the idea on the
machine where it can be verified, and a CI workflow becomes a wrapper rather
than a new invention.

**One live defect found while reading the checker:** its module docstring says
*"Four checks"*. `main()` runs six (`check_indent`, `check_duplicates`,
`check_shadow`, `check_infer`, `check_container_infer`, `check_refs`). §111 and
§113 both say six. The file's own header is two rules stale.

### Idea 12 — the harness watchdog

**Status: refused as specced, by `run_harness.sh`'s own comment. A cheaper fix
exists and it touches zero tags.**

The specced form is a self-arming quit-after-60s per tag. The runner already
answers it:

> `PYXIS_BALANCE` fights the apex to a conclusion with three different fits …
> it has run anywhere from **five to eleven minutes**. A bound tight enough to
> be interesting would report the slowest real harness as a hang on a bad roll,
> which is worse than useless: it fails the sweep for a reason that is not a
> defect.

A 60s bound is wrong for at least one real tag, and a per-tag timeout table
would be 56 hand-maintained numbers — a measurement column maintained by hand,
which is the class §113 just finished paying off.

**And the timeout is not the failure being complained about.** `run_one`
already enforces `TIMEOUT_S` and already counts `HARNESS TIMEOUT` into `errs`,
so the sweep is *correct* today; what it costs is 25 minutes of wall clock.

*Reshaped:* kill on the **symptom**, not on the clock. §111's hang printed a
`SCRIPT ERROR` and then sat silent — and any `SCRIPT ERROR` already fails the
sweep, so a run that has printed one has nothing left to prove. `run_one`'s
existing `while kill -0` loop can grep the log each second and kill the run
shortly after the first matching line. **~8 lines in `run_harness.sh`, zero
game changes, zero tags touched, no per-tag table**, and it turns the exact
1,500-second case into a ~10-second one while leaving `PYXIS_BALANCE`'s eleven
honest minutes alone.

### Idea 13 — `run_harness.sh --legs`

**Status: the strict version is arithmetically impossible. A useful weaker one
survives.**

Measured: `main.gd` has **808** `-> %s` leg print sites across 58 harness
functions. Of those, **50 sit under an `if`/`elif`/`else`/`match`** and **7
under a `for`/`while`**. The last sweep measured 813 PASS + 1 FAIL.

**`_run_save_test` alone defeats the arithmetic.** It is 1,608 lines with 40
leg sites and **24 mutually-exclusive `mode ==` branches**, dispatched 24
separate times by `SAVE_MODES`. A static count of that function has no
relationship to its contribution: 24 of the sweep's 81 runs go through one
function and each executes one branch.

But strip SAVETEST out and the picture is much better: ~768 sites across 57
tags, of which ~10 are conditional and 7 loop. **A static per-tag count is a
sound lower bound for every tag except one, and the exception can be named
rather than hidden.**

*Reshaped:* `--legs` prints, per tag, the static site count and the tag it
belongs to, **with SAVETEST excluded and printed as excluded** (no silent
truncation). The sweep then compares measured against expected and reddens on
`measured < expected` — which catches the failure `errs` cannot see: **a
harness that returns early and quits cleanly**, printing fewer legs with no
script error and no timeout. That is the "green at 758 that was never swept"
shape, and it is the only one of the three counting failures in this repo's
history that nothing currently guards.

Cost: a ~60-line Python helper plus a tag→function map. Risk: low, and it never
runs Godot, so it works on the machine that authors but cannot sweep.

### Idea 14 — `docs/DEFECTS.md`

**Status: yes, and the premise undercounts.** The idea estimates "six checker
rules and ~5 recurring classes." Reading for it produced **ten distinct
recurring classes**, each with two or more instances and a named cure:

| class | instances | what covers it now |
|---|---|---|
| `:=` inferred off an untyped container/global → parse error → class cascade | 3 forms (§77, §106, §111) | checker rules 4 and 6 |
| a loader validating against a store that loads later | 2 (§112 works, berths) | nothing — read the order |
| an assertion whose premise a feature reversed | 2 (§80 `SESSION RESET`, §109 `NO EXPIRY`) | §24, by discipline |
| one UI channel, many unqueued writers | 3 (§v18 prompt, §96 broadcast, §113 bark) | `_prompt_held`, `*_busy`, arm-and-fire |
| a measurement column maintained by hand | 3 (§73, §77, §113) | `--counts` |
| `String(x)` on a multi-typed store — an invalid constructor that returns false and passes | 2, **in one file, minutes apart** (§97) | one accessor, `typeof` first |
| copy derived from a table under a false monotonicity assumption | 1 large (§110 forge hint) | `THE HINT WOULD HAVE LIED` |
| a leg that can pass by never reaching its case | 3 (§88 tree-order, §108 HOSTILE, §110 both-halves) | the both-halves habit |
| a wired verb with no affordance | 6 of 9 playtest notes (§88) | §88, by discipline |
| a wrong arity invisible without the Godot binary | 1 near-miss (§108) | append-with-default |

Half of these are covered by a rule or a leg; half are covered only by somebody
remembering. **The document's value is the second column** — it makes "which of
these does the thing I am about to write belong to" a two-minute question
instead of a grep through 11,761 lines of STRATEGY. Cheap, docs-only, and it
also gives idea 15 somewhere to live.

### Idea 15 — protect refusals-with-reasons written at the site

**Status: it is already this repo's single most productive habit, and this pass
is evidence.** Of the fifteen ideas, **five were killed or reshaped by a comment
sitting exactly where the bad idea would have been typed**:

- idea 10, by `hud.gd`'s *"A LOCK RATHER THAN A PRIORITY NUMBER"*;
- idea 12, by `run_harness.sh`'s *"a bound tight enough to be interesting…"*;
- idea 5, by `can_store`'s bonded-rule printer argument **and** by §5's
  *"the trip is the cost"*;
- idea 4, by `plan_cell`'s purity and `THE DEEP IS STILL UNCLAIMED`;
- the operating-costs item, by §5's *"nothing may be built by waiting."*

*Recommendation:* it does not need protecting with a mechanism, because a
mechanism cannot check prose. It needs **stating as a §**, and the one thing
worth adding beyond "keep doing it" is the failure mode this pass found: a
refusal in STRATEGY that has **no counterpart at the site** (operating costs)
gets forgotten, while a refusal written *in the file* gets found by whoever
tries. **The rule is not "write the refusal down" — it is "write it where
somebody would type the mistake."**

---

## 4. Standing in §64, weighed here

**The four legacy deepenings (5c).** Confirmed as §111 described. Each legacy
line function (`smuggling_line` at `game_state.gd:3183` and its three siblings)
is an `if/elif` ladder over hand-written tier constants with the cap-out string
inline. Extending one is: a tier in the array, a constant, an `elif`, and any
leg that pins the cap. Genuinely an afternoon **with a sweep at hand** — and it
is a prerequisite for idea 2's capstone only in the sense that the capstone must
be *derived from the tables*, never written as a number. Do that and 5c can land
before or after.

**The deep-weather rumour line.** Small, copy-only, and it now has a second
consumer if idea 5's fourth work turns out to be a deep repeater. Worth holding
until that is decided rather than shipping it twice.

**`CANNOT_READ` at an un-wrapped label.** Measured: the constant is **124
characters** and **the next-longest prompt in the entire game is 83**
(`sounding_mark.gd`'s readable counterpart). It is a single outlier at 1.5× the
field, not a systemic wrapping problem.

And the device §105 asked for is nearly free, because the layout already
supports it: `_prompt_label` is `PRESET_CENTER_BOTTOM` with
`grow_vertical = GROW_DIRECTION_BEGIN`, so **a second line grows upward, away
from the action dock** it was carefully positioned to clear. All that is missing
is a width and `autowrap_mode`. And no assertion reads the label's geometry —
every prompt leg goes through `prompt_text()`, and exactly one reads
`modulate.a`. Two lines in `_build`, one constant, one leg.

**§41's `MIDTIER` re-derivation.** Not owed this horizon *unless* the sink
re-pricing changes a yield, which it should not — a sink is not an income term.
Worth stating explicitly in the horizon doc so a red `STEADY MIDTIER` during
this work is read as a real regression rather than as the debt arriving again.

---

## 5. What this pass killed

Recorded plainly, because the deaths are the output:

1. **Idea 1's derived read** — `Rival.filed` is monotone; a fact about *when*
   cannot come from a predicate about *whether*.
2. **Idea 3's arriving hull** — blocked behind §64's open splash question, and
   its scene plays to an empty room by design.
3. **Idea 4's band-shifted raiders** — no per-band roster exists; the drop
   rides the difficulty index; `plan_cell` is pure; §51 asserts against it.
4. **Idea 5's chart-panel goods check** — the works button is a menu with no
   position gate, so "delivered" would have been a word with nothing under it.
5. **Idea 5's annex route** — `can_store == no_retail`; alloys are retail, and
   the bonded rule is a money-printer closure.
6. **Idea 8's GameState migration** — 78% of `main.gd` is harness; the target
   is the wrong 18%.
7. **Idea 10's priority queue** — refused in writing at the site, twice, and
   four devices for the class already ship.
8. **Idea 12's 60-second watchdog** — `PYXIS_BALANCE` legitimately runs to
   eleven minutes; the runner says so in a comment.
9. **Idea 13's checkable arithmetic** — `_run_save_test` is 24 branches
   dispatched 24 times; static counting cannot reach it.
10. **Operating costs** — refused by §5 since 2026-08-04 and never recorded.
