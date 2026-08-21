# Horizon 11 — THE RECKONING

Opened 2026-08-21, the evening Horizon 10 closed. Ten commits. Save v27 → v28
(one bump, spent on commit 3, ridden by the rest). Research pass:
`docs/HORIZON-11-RESEARCH.md`.

A reckoning is a bookkeeping word and a word for meeting somebody. This horizon
is both, because the fifteen ideas it came from resolved into exactly two
things: **the game has never priced anything against itself**, and **the deep
is full of other hands the player can only ever infer.**

---

## What the research found, before any of it was planned

Fifteen ideas went in. **Ten died or were reshaped on contact with the code**,
which is the pass working. The full argument is in the research doc; the three
findings that set the commit order:

**1. There is an income instrument and no wealth instrument.** `PACINGTEST`
measures earning rate against a mid-tier module and asserts a band. Nothing
anywhere measures a balance or a sink — `DEFAULT_LEDGER`'s seven keys contain
no credit figure. So the entire sink side of the economy, which is what
Horizon 10 was *about*, is unmeasured by construction.

**2. Converted, the numbers are stark.** A steady loop pays on the order of
34,000. The full module catalogue is ~1.1M — about **4.3 hours**. Everything
else in the game, added together, is about **300,000**: colony works at ≤270k,
requisitions at ≤4,500 each, a full repair at 1,400, and the deepest possible
rescue at 1,870 — **twenty-six seconds of income**. Even at the pacing band's
*floor* the deepest rescue is a fifth of one loop. A pilot is poor until the
catalogue is bought and never again, and Horizon 10 moved "never again" by
about an hour.

The cause is one sentence: **every price in this game is anchored to another
price, and no price in this game is anchored to the loop.** §109 priced the tug
at 2× the beacon jump — correct arithmetic against a number that had itself
never been anchored.

**3. One third of Horizon 10's approved scope silently did not ship.**
"Operating costs" was one of the three sink categories settled on 2026-08-21.
It appears **twice in the whole repository** — in §64's decision paragraph and
in the same list in the Horizon 10 doc — and in no commit, no section, no
assertion, and **not in §64's deferral list.** It was not built, not deferred,
and not refused. That is exactly the failure §64 exists to prevent, happening
inside §64's own paragraph.

**And the code refused it a year earlier.** §5's base-building amendment
(2026-08-04): *"no clocks, no queues, no currency sink pretending to be a
decision, and nothing that rewards logging in rather than flying … Nothing may
be built by waiting."* An upkeep bill is all three. This horizon **records that
refusal at §5's terms and closes the item** rather than building it or
forgetting it a second time.

---

## The decisions taken before any code

Settled by the author on 2026-08-21, from the research pass's forks:

- **Both halves ship.** The measure of a price *and* the other hands. This is
  not two horizons run together — the measurement is what lets the presence
  work be argued as income-neutral rather than assumed to be.
- **Measure first, decide next horizon.** The instrument and the rule ship;
  **no sink price changes in this horizon.** §41's own precedent: a red reading
  is a decision taken in the open with the measurements in hand, never a nudge
  toward whichever number makes the sweep quiet.
- **The capstone is VISIBLE.** Against the research pass's recommendation, and
  the cost is accepted in the open: §19's law is that skill feeds must compete,
  and a visible all-ladders count tells the player the long-run answer is *do
  all of it*. What the spec buys back is restraint — a **derived count on the
  ledger page's own header and nothing else**: no percentage, no popup, no
  achievement row, no second screen, and **nothing anywhere says what the
  eleventh does.** The number is visible; the reward is not.
- **The spill claimant stays faceless.** Two reshapes were proposed and the
  code refused both (below). What ships is a record, not a body.

---

## The commits

| # | commit | save | size | risk | state |
|---|---|---|---|---|---|
| 0 | **The ledger of prices** — a SINKS block in PACINGTEST; the §-rule; §5's refusal of operating costs recorded and the §64 item closed | none | ~150 harness lines, 1 §, 1 §64 edit | low | **BUILT** — §114 |
| 1 | **The runner's teeth** — kill on the first SCRIPT ERROR; `--parse`; `--legs`; the checker's stale docstring | none | ~120 shell + ~60 python | low | **BUILT** |
| 2 | **`docs/DEFECTS.md`** — ten recurring classes, each with the rule or leg that covers it, and blanks where nothing does | none | docs only | none | **BUILT** |
| 3 | **The colleague's cell** — `survey_filed` gains a third validated word, captured at the act; the chart draws two documents | **v28** | ~80 lines, 2 legs, migrate clauses | medium | **BUILT** — §115 |
| 4 | **The trip is the cost** — a fourth colony work that takes a DELIVERED good, raised at the structure | rides v28 | ~120 lines, 2 legs | low | **BUILT** — §116 |
| 5 | **A kept light** — the procession and a player colony, one broadcast, once per run | rides v28 | ~50 lines, 1 leg | very low | **BUILT** — §117 |
| 6 | **What the claimant left** — a claimed spill enters the log and the ledger | rides v28 | ~40 lines, 1 leg | low | **BUILT** — §118 |
| 7 | **The prompt holds its refusals** — `prompt(text, hold_s := 0.0)`, appended and optional; the label wraps | rides v28 | ~80 lines, 2 legs, a 63-site triage | medium | **BUILT** — §121 |
| 8 | **The eleventh** — the capstone, derived from both table families; one broadcast; the ledger header's count | rides v28 | ~60 lines, 2 legs | low | **BUILT** — §119 |
| 9 | **The measure** — the horizon closed, the sweep read, what it leaves open stated | none | docs | low | **BUILT** — §122 |

**5c (the four legacy deepenings) is NOT in this horizon** and stays deferred
in §64 with its reason unchanged. Commit 8 must therefore derive the capstone
from `SKILL_TIERS` and the four `*_TIERS` arrays and **never write a number**,
so 5c can land before or after without moving the bar.

---

## Commit 0 — the ledger of prices

The whole horizon's argument, and it changes no number.

**What it builds.** `_run_pacing_test` already computes `earned` for the
standard loop. A SINKS block re-derives every credit sink in the game from the
live constants — `REPAIR_FULL_PRICE`, `BEACON_JUMP_MIN_FEE`/`COLONY_JUMP_FEE`,
`rescue_fee` at seven depths, `COLONY_WORKS` prices, `Market.requisition_price`
at the dearest component, the rumour prices, `_pacing_catalog_cost()` — and
prints each as a fraction of that same figure. One table, one instrument, no
new store, no save.

**What it asserts is a LAW, never a target** (§99's posture, because the
re-pricing is deliberately deferred):

- `EVERY SINK IS PRICED` — every constant the table names still exists, so a
  rename reddens the leg rather than silently dropping a row. This is the
  guard the whole instrument rests on: a measurement column that can lose a
  row without saying so is the class §113 just finished paying off.
- `THE CATALOGUE IS THE LONGEST PRICE` — no single sink exceeds the module
  catalogue. True today, and it reddens if somebody ever prices a work above
  the whole yard.
- `NOTHING INVOLUNTARY EXCEEDS A LOOP` — the two charges a pilot cannot
  decline, the tug and a full repair, each cost less than one measured loop.
  **True today at 26 and 20 seconds**, and it is a real promise worth pinning
  before any re-pricing: an involuntary charge larger than a loop is a
  punishment that erases a session, which is a different game from this one.
  It survives the re-pricing in either direction, which is why it is safe to
  assert now.

**What it does NOT assert**, deliberately: that any sink is *big enough*. That
is next horizon's decision and this commit exists to hand it a table instead of
an argument.

**The §-rule, as §11's counterpart.** §11 says no port may be a money printer.
Its missing half: **a sink's price is stated in loop-minutes.** Anchoring a
price to another price is how the tug ended up at 26 seconds while being,
correctly, twice the jump — and how the works ended up round rather than felt.

**And §5's refusal, recorded where somebody would type the mistake.** The
operating-costs item is closed in §64 as **REFUSED, not deferred**, with §5's
own sentence as the reason, and a note at the colony-works site — because the
research pass's own finding is that a refusal living only in STRATEGY gets
forgotten while one living in the file gets found by whoever tries.

---

## Commit 3 — the colleague's cell, and the thing that cannot be derived

Idea 1 asked for the rival to file with the network too. **It already does**:
`file_charts_with_network` calls `note_survey_held` on the `lost` array as well
as on `cells`, with the reason written at the site — *"the somebody IS the
network — their colleague already clipped that mark to a mast"* — and the
counter's copy already switches on `files_with_the_network()`.

What is missing is that the chart cannot tell the two apart: one open ring for
every `is_survey_held(cov)`.

**And it cannot be derived, which is the finding worth keeping.** `Rival.filed`
is `floorf(seconds / STRIDE_S) * STRIDE_S >= arrival_seconds(key, depth, seed)`.
`arrival_seconds` is fixed per (key, seed) and `played_seconds` only rises, so
**the predicate is monotone: once true, true forever.** A derived chart would
retroactively re-label every cell the player filed first as a colleague's. The
distinction exists only at the instant of the act.

That is the exact inverse of §97's `files_with_the_network()`, which *is*
derivable because it is an existential over a store that only grows. The rule
that falls out and belongs in STRATEGY: **a fact about WHEN cannot be derived
from a monotone predicate about WHETHER.**

**So it is recorded, on §98's `MARK_STATES` precedent** — a third validated
word in a store that already holds two types and has exactly one accessor
(`is_survey_held`) that knows how to ask. `_load_survey_filed` validates by
type and drops anything illegal, so a third legal word is one `elif`.

**This is the horizon's one save bump, and the reason is the downgrade path.**
The value is additive and an old build would *drop* the new word rather than
mistake it — which silently un-holds the cell and loses the anchor. §73 already
paid for one save-destroying downgrade path; v28 is cheaper than a second.
`migrate26` grows clauses (a colleague-held cell in, a nonsense value out) and
everything after this commit rides the bump.

**One consequence to state rather than discover:** a colleague's cell is
already an `anchor_rows` candidate at FILING t3, and has been since §112. That
is arguably right — §112's own words, *"a place somebody keeps a light on"* —
but it is unstated, and the moment the chart draws two glyphs somebody will
ask. It goes in the commit's prose either way.

---

## Commit 4 — the trip is the cost

Idea 5, and the code says exactly where the first draft would have gone wrong.

**The defect the naive version carries.** Colony works are bought from the
**chart panel** — a menu openable from anywhere, including while docked at the
counter the goods were just bought from. There has never been a position gate
on a work. A `GameState.cargo` check on that button would let twenty alloys
teleport four thousand units, and the word "delivered" would be a fiction with
nothing under it — the class §110's forge hint belonged to.

**And the annex cannot carry it.** `can_store == no_retail`, and the comment
says why: an open bay on a retail good is a timed-arbitrage printer. Alloys are
retail. The bonded rule refuses them by design, and that refusal is a §11
closure, not an inconvenience.

**§5 wrote the fix on 2026-08-04**: *"If a structure takes time to become
something, the time is spent flying to it with what it needs — the trip is the
cost."* So the work is raised **at the structure, with the goods aboard**,
through the affordance that already exists: the chart row stays and states its
own terms when refused, the posture `SOUND ITS GROUND FIRST (WORK A MAST IN ITS
CELL)` already uses. `main.buy_colony_work` is already the one place that asks
the world's questions on the store's behalf, and gate-then-purchase already
means the refusal is free.

**The goods are a GATE, not a price.** Twenty alloys is 800 credits of base
value — **1.1 seconds of loop income**. The cost is the hold and the flight: a
starter hold is 24 space against a colony 1,600–4,200u out. The credit half of
the work stays a credit price. GATES, NEVER PRICES, applied to a work.

**It does NOT feed BROKERAGE.** Tempting and refused: §111 pinned that ladder
to deliveries only because *"any contract would rise alongside three other
ladders' work"*, and a colony haul is colony play, which already feeds
COLONIAL. Two ladders rising off one afternoon is §19's clock arriving through
a feed — and `FEEDS COMPETE, SIX WAYS` would not catch it, because that leg
fires one feed and checks one ladder moved. This is a fact about where the call
lives, not about what it does.

**The one open design question in this commit** is what service the fourth work
returns. Every existing work is information, time or access (§26), and a fourth
needs a fourth answer that is not a stat, a price or an income term. Two
candidates, neither researched yet:

- **a kept light that holds a spill** — extends §109's claim clock inside its
  own system. Time, and it braids with commit 6.
- **a deep repeater** — carrying the deep's weather where the RELAY MAST
  carries the chart's. Information, and it discharges §113's open copy gap
  (the deep-event rumour line) in the same breath instead of shipping it twice.

Decide before the commit is written, not during.

---

## Commit 6 — what the claimant left, and the two reshapes the code refused

Idea 3 asked for a hull that arrives, works your spill and leaves. It is
blocked, and then its two replacements were blocked, and all three deaths are
worth the paragraph.

**The hull is blocked on §64.** A competitor the player can shoot is a combat
encounter, which is not the feature; one they cannot is a ghost; one that
splash catches by accident reopens *"Should an ALLIED ship be spared the
player's area weapons?"*, open since 2026-08-06 and dimensioned by
`WITNESS_RANGE`/`OVERCHARGE_RADIUS`. That line has to be drawn deliberately, in
its own commit, and it is a bigger decision than a spill should force.

**And the scene plays to an empty room by design.** `_tick_spill_claim`'s
window is `180 + 0.15 × depth` seconds — 390s at 1,400u, ~25 minutes at the
marks — far longer than the flight back. The clock expires *only* on the branch
where the player chose not to return.

**The market reshape was proposed and the code refused it too.** Seeding a deep
GLUT on the claimed good runs into two constants: `EVENT_MAX_DEEP := 1`, so the
deep is allowed exactly one event and a claim would starve the ambient weather
§108 built; and §108's *"the good comes from the archetype's own bias table …
not a shortcut: it is what keeps a 2.2× shortage off a component at a 1.45×
deep fence, **by construction**"*. A spill is unread **salvage**, and **no deep
station's bias table contains a single salvage good** — every one is drawn from
the seventeen retail goods. An event on salvage is precisely the unbounded case
that comment closes.

**A named claimant was the third proposal and it is deferred, not dropped.**
The rival's whole design is *"Nothing is ever seen moving"*, and §105 spent two
horizons on a deliberate anonymity it refused to break *"for a caption"*. The
first named living stranger in this game is a writing-pass decision, gated the
way the nine names were, not a side effect of a spill timer.

**What ships is the smallest true thing.** `_tick_spill_claim` today calls
neither `note_log` nor `note_ledger` — a claimed spill is a toast that scrolls
away and leaves no trace anywhere. It gains:

- a **captain's log line**, which is `note_log`'s stated purpose exactly (ten
  slots for things that happened to *you*), naming the band and the count;
- a **`spills_lost` ledger key** — one entry in `DEFAULT_LEDGER`, whose own
  comment records that *"a new key in this dict needs no save bump: the
  load-side merge is defaults-based"*;
- a toast that says **what** and **where** rather than only that it happened.

The claimant gets a face the way the rival got one: evidence, and never a body.
And the ledger gains its first loss column, which is commit 0's instrument
meeting commit 6 without either being built for the other.

---

## Commit 7 — the prompt holds its refusals

Idea 10 asked for a priority queue. **It is refused in writing, at the site,
twice** — `hud.gd`'s *"A LOCK RATHER THAN A PRIORITY NUMBER, because there is
exactly one thing in this game that gets six seconds to be read"*, and
`procession.gd`'s *"THE PROMPT LINE IS FOR REFUSALS ONLY."* Four devices for
the class already ship: `_prompt_held`, `clear_prompt_if`, `prompt_text`, and
`broadcast_busy`/`toast_busy`'s ask-first protocol. §113 added a fifth.

63 `hud.prompt(` sites across 19 files is real crowding, but the *evidenced*
defect is narrower: **a nudge stomped a refusal the player had not read yet**,
on the first-ever tap, to the pilot least able to guess.

**So: a soft lock with a duration, not a queue.** `prompt(text, hold_s := 0.0)`
— appended and optional, which is the call §108 made explicitly for this
environment: *"There is no Godot binary in the authoring environment, a wrong
arity is a parse error `check_scripts.py` cannot see."* 63 call sites stay
byte-identical; only the refusals change. A refusal owns the line for its
window; after it, the line is ambient again. A queue is refused for its own
reason: it would deliver sentences after the moment that made them true.

**And the label wraps, because the layout already supports it.** Measured:
`SoundingMark.CANNOT_READ` is **124 characters** and the next-longest prompt in
the entire game is **83**. One outlier at 1.5× the field, not a systemic
problem. `_prompt_label` is `PRESET_CENTER_BOTTOM` with
`grow_vertical = GROW_DIRECTION_BEGIN`, so a second line grows **upward, away
from the action dock** the position was chosen to clear — and no assertion
reads the label's geometry (every prompt leg goes through `prompt_text()`;
exactly one reads `modulate.a`). A width and `autowrap_mode` is the device §105
asked for, and it is two lines.

---

## Commits 1 and 2 — the toolchain, and what the process ideas became

**The watchdog died and got cheaper.** Idea 12's self-arming 60-second quit is
refused by `run_harness.sh`'s own comment: `PYXIS_BALANCE` *"has run anywhere
from five to eleven minutes"*, and *"a bound tight enough to be interesting
would report the slowest real harness as a hang on a bad roll."* A per-tag
table would be 56 hand-maintained numbers — the class §113 just paid off.

And the timeout is not the complaint: `run_one` already enforces `TIMEOUT_S`
and already counts `HARNESS TIMEOUT` into `errs`, so the sweep is *correct*
today and costs 25 minutes of wall clock. **Kill on the symptom instead.**
§111's hang printed a `SCRIPT ERROR` and then sat silent — and any script error
already fails the sweep, so a run that has printed one has nothing left to
prove. ~8 lines inside the existing `while kill -0` loop. **Zero game changes,
zero tags touched, no table**, and `PYXIS_BALANCE`'s honest eleven minutes are
untouched.

**`--legs` survives as a lower bound with its exception named.** Measured:
`main.gd` holds **808** leg print sites across 58 harness functions; 50 sit
under a conditional and 7 under a loop. `_run_save_test` alone defeats strict
arithmetic — 1,608 lines, 40 leg sites, **24 mutually-exclusive `mode ==`
branches dispatched 24 separate times.** Strip it out and ~768 sites across 57
tags have ~10 conditionals between them.

So `--legs` prints a static per-tag count **with SAVETEST excluded and printed
as excluded** — no silent truncation — and the sweep reddens on
`measured < expected`. That catches the one counting failure nothing currently
guards: **a harness that returns early and quits cleanly**, printing fewer legs
with no script error and no timeout. The "green at 758 that was never swept"
shape.

**`--parse` before CI.** Idea 11's gap is real (§111: `main.gd` parses while a
leaf class does not) but §111 already decided the static pass is the cheaper
place for it, and the checker runs clean over all 70 files today. Godot
per-file is still strictly stronger, so it is worth having — **as
`run_harness.sh --parse` first**, on the machine that has the binary, before it
is a CI job that has to solve `--import` caching to prove anything. A CI
workflow then becomes a wrapper rather than an invention.

**And one live defect found by reading the checker**: its module docstring says
*"Four checks"*. `main()` runs six. §111 and §113 both say six. Fixed in this
commit.

**`docs/DEFECTS.md` (commit 2) undercounts in the idea and overdelivers in the
file.** The idea estimated ~5 recurring classes; reading for it produced **ten**,
each with two or more instances. Half are covered by a rule or a leg; half are
covered only by somebody remembering, and the document's value is that second
column. It is also where idea 15 lives — and the one thing worth adding beyond
"keep writing refusals" is what this pass found: **a refusal in STRATEGY with no
counterpart at the site gets forgotten** (operating costs), while a refusal
written *in the file* gets found by whoever tries. The rule is not "write the
refusal down." It is **"write it where somebody would type the mistake."**

---

## Commit 8 — the eleventh

Reachability holds: `hyper_positions` yields 3–5 structures across 3 systems
(9–15) against `colonial: [0,1,3,6]`; `FarMarks.PER_SYSTEM = 5` gives 15 marks
a run against `hunting: [0,1,4]` (3 apexes + ≥1 legend). No ladder is longer
than its feed.

The check spans two representations — `skill_tier()` against
`SKILL_TIERS[name].size()-1`, and four legacy vars against four `*_TIERS`
arrays — and **is derived from the tables in both**, which is what keeps 5c
free to land on either side of it.

**The §19 cost is accepted, in the open.** A reward for capping all eleven
tells the player the long-run answer is *do all of it*, which is the shape §19's
competing-feeds law exists to refuse and §111 named as *"a checklist that
cannot be finished."* The author's decision is that the count is visible. What
the spec buys back is everything else: **a derived count on the pilot ledger's
own header line**, and no percentage, no popup, no achievement row, no second
screen — and **nothing anywhere says what the eleventh does.** The payload is
one `hud.show_broadcast` from the channel that never gives its name, on the
broadcast plate, which is a different surface from the prompt line and needs no
part of commit 7.

Refused in the spec, in advance: a second grant of any kind, a credit payout, a
stat, and any per-ladder progress rendering beyond the count itself.

---

## What this horizon does NOT do

- **It changes no sink price.** That is next horizon's decision and commit 0
  exists to hand it a table.
- **It does not touch a yield**, so `STEADY MIDTIER` should read what it read.
  A red there during this work is a real regression, **not** §41's
  re-derivation arriving — stated here so the sweep is not misread.
- **It does not build operating costs**, and it does not leave them open. §5
  refused them and this horizon writes that down.
- **It does not answer the ALLIED-splash question**, and commit 6 is shaped so
  it does not have to.
- **It does not build the pressure front.** Idea 4 survived research only as a
  reshape — a **quadrant**-shaped front on `quadrant_of`/`QUADRANTS`, moving
  `DEEP_RAID_TAPER` and nothing else — because bands are concentric rings you
  must cross while a quadrant is a bearing you can decline. Three separate
  things refuse the original: raiders are one kind tapered by depth rather than
  a per-band roster, `PACK_DROP` rides the same index as `PACK_DIFFICULTY` so
  the shift is a printer or a tax with nothing between, and `plan_cell` is a
  pure function of `(system, cx, cz)` that `THE DEEP IS STILL UNCLAIMED` guards.
  The reshape wants its own pacing argument against `_pacing_earned`, which
  commit 0 will make possible and this horizon will not spend.
- **It does not extract the harness from `main.gd`.** Measured: 28,626 lines,
  **78% of them harness**, cleanly split at line 5,219. The game half is ~5,200
  lines — comparable to `game_state.gd`. Idea 8 aimed at the 18%; the only
  refactor with mass is one GDScript cannot do cheaply. The measurement is
  recorded in STRATEGY so the proposal does not recur.
