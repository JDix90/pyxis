# Legends III — the research pass (Horizon 9 commit 5)

**Status: RESEARCH COMPLETE, 2026-08-20. Nothing built. Decisions S4–S8 are
open and gate the build; the nine names need a writing pass (S8) before the
procession can ship at all.** The pass that produced this document read the
colony/jump machinery, the escort machinery, the chart-good economy, and the
procession's surfaces against the real tree, the way the berths pass did —
and, like that one, it killed the obvious version of three of the four
legends.

The four: THE ORRERY STILL RUNNING, THE TALLY'S NURSERY, THE PATTERN FORGE,
THE PROCESSION'S END. Save bump **v26** (the nursery's store — see below; it
is the only one of the four that needs a byte).

---

## Finding 1 — the escort wing is not "genuinely new"; the spec was wrong

`REQUEST ESCORT` already ships an escort that flies on the player's wing: the
ALLIED rung of the contact menu (`main.gd` `request_escort`) puts a Cordon
picket at `ESCORT_FOLLOW` 8.0 behind the player's shoulder, guarding
`ESCORT_GUARD_RANGE` 15.0 measured **from the player**, firing only at what
`hostile_to_player` says is fighting the player, for `ESCORT_TIME` 60s. Every
hazard the forge's wing raises was already found and paid for there:
`marker_color` keeps the radar honest, the `_aggro` model handles betrayal,
and `ESCORT_FOLLOW 8.0 > OVERCHARGE_RADIUS 7.0` is a shipped, deliberate
clearance.

**What the forge actually needs is a different spawner and a different
lifetime, not a different class** — `Hostile` nodes built by `build_legend`
with `_escort` seeded at construction, the 60s clock lifted, and the
single-slot `Main._escort_ship` bookkeeping bypassed. The house rule
verbatim: the gradient is parameters.

Three integration hazards, in order, all from the pass:

1. **The player's own splash.** Three player weapons — overcharge discharge,
   arc chain, torpedo splash — sweep the `hostiles` group with **no IFF
   filter, by documented design** (a torpedo-only fit must be able to open on
   a neutral). Splash → `take_damage` → `_aggro = player` → the wing turns on
   you. One escort survives this because it stations outside the overcharge
   radius; **a formation multiplies the exposure**. The wing's formation
   geometry must keep every member outside 7.0u of the player, and the §
   that builds it must say so.
2. **The ambient floor and attribution pull opposite ways.** In `combatants`,
   `SKIRMISH_HP_FLOOR` (0.5) means an escort can soften and **never finish**
   — the player still lands every kill, so attribution, loot, contracts and
   §51 (ONLY THE PLAYER DEPLETES THE WORLD) all hold with zero new code.
   Out of `combatants`, an escort that lands a killing blow makes
   `player_kill` false: no `report_kill`, no loot, kill contracts silently
   stop ticking while the world depletes. **The wing stays in `combatants`
   and the floor stands: printed escorts are fire support, and the fiction
   already says so — "they answer", not "they win".**
3. **Census pollution.** `_pacing_kill_yield` force-attacks `live[0]` of the
   `hostiles` group for up to 5400 frames — a friendly there deadlocks the
   leg that the whole `MIDTIER` bar (sitting at ~2.91 against a hard 3.00)
   rests on. `_count_sentries()` counts any `Hostile` with an empty `patrol`
   as a sentry, and the title/tutorial harnesses expect zero. Neither leg
   can meet a forge escort today (no harness reads a forge mark), but the
   build's own legs must never leave one alive across a suite boundary.

**The flag decision, resolved by a shipped comment.** Escorts must fly a
non-hostile flag (or the player's own guns auto-target them), but any real
faction makes splashing your own wing a standing incident. `Hostile.
marker_color`'s last branch — "kept for a spawner-painted ship that flies no
flag at all" — is the answer: printed escorts fly an **unregistered pattern
id** (`"printed"`). `is_faction` is false, so `shift_faction` no-ops on any
splash or kill; the band lookup floors to neutral, so `fights_the_player` is
false; the tint is spawner-painted. The machinery treats an unregistered flag
exactly the way the fiction describes the forge's output: a pattern nobody's
registry has a row for.

**S3 (no warp survival) is structural** — children of `system_root` are freed
wholesale in `_load_system` — with one recorded caveat: any Main-side array of
escort references must be cleared in `_load_system` like `_muster`'s state,
or a freed-reference latch comes back.

---

## Finding 2 — the nursery cannot ride `colonies`, and the jump is a real
reversal

The draft's "foothold on the existing colony machinery" fails four ways
against the actual store:

1. **Key collision.** `colony_key` and `mark_key` are byte-identical formats
   (`"%s:%d"`). A nursery claimed into `colonies` under its FarMarks index
   collides with a hyper structure's colony key — claiming one makes the
   other read claimed, suppresses its chart diamond, mislabels its jump row.
2. **The loader would not police it** — `_load_colonies` deliberately skips
   generator validation (the stored position IS the colony), and it *requires*
   two-part keys, so a prefixed key (`"nursery:pyx01:3"`) is silently dropped
   on load. There is no shape of key that both survives the loader and avoids
   the collision.
3. **`hyper_designation` would caption it** "<hyper family> · FOURTH
   INSTRUMENT" on the chart row.
4. **The chart auto-fit folds colonies in** — one 7,000–9,000u colony
   permanently zooms that system's plot out to ~9,900u, the exact harm the
   fit excluded survey coverage to avoid.

**So the nursery gets its own store — that is the v26 bump**: a `nursery`
dict (`{key, x, z, taken_at}` plus what S5 decides), validated against
`FarMarks.positions` on load like `marks_seen`, with its own chart row and
its own caption. `marks_seen` keeps the mark's read/spent lattice; holding
the nursery is a fact about the *place*, not the plate.

**The jump is the sharp decision (S4).** A jump anchor at FarMarks depth
(6,500–9,000u — it is a range, not "7,000") breaks nothing loudly and three
things silently:

- `A FOOTHOLD, NOT A FARM` derives "deepest reachable" from
  `bounds + HYPER_DEPTH_MAX` (= 4,244u) and would keep printing PASS while
  the true ratio (9,044/5.75/300 ≈ **5.2**) blows through its 3.0 bound.
  The comment at the beacon cap *predicted this exact failure*.
- `ONLY OUT THERE` (the archives are past the jump ceiling, so the only way
  is the fifteen-minute flight) becomes false in spirit: a deep anchor puts
  the archives and all of band 6 a short hop away.
- The Tally's recapture pressure and the shared 300s `last_outbound_jump`
  stamp collide: under siege, the one-clock rule can lock you out of your own
  defense.

The counterweights, if the jump ships: the anchor is **held, not owned** —
it exists only while the nursery is held, so the door into the deep closes
the day the Tally takes it back; the recapture clock prices the door in
fights rather than credits; and the derivation is **re-derived in the open**
(the § must restate `deepest` as `max(HYPER_DEPTH_MAX, FarMarks.DEPTH_MAX)`
and either raise the bound with an argument or give the nursery jump its own
clock). The fit exclusion is one line (the nursery joins the fit the way
coverage does not).

**The recapture clock costs zero new mechanism.** The cleanest precedent is
already in the save: a persisted `played_seconds` anchor (`taken_at`, the
`founded_at` idiom — which is written, loaded, and read by nothing today)
driven through `ContractDB.board_bucket`'s derived-index arithmetic, with
`Rival.STRIDE_S`'s quantisation so world rebuilds seconds apart cannot
disagree. Wave index = `floor((played_seconds − taken_at) / PERIOD)`;
"increasing numbers, forever" is the index feeding the wave size, capped at a
sane ceiling (the muster's 6-at-a-time release is the pacing precedent).
Waves spawn from the node's own `_process` on the warden-wake pattern —
**gated on the persisted hold, never a session flag**, or a colour-vision
toggle becomes a free wave reset (the trap `hyper_structure.gd` documents).
Jumping to the nursery does not rebuild the world (`_colony_jump_sequence`
is emphatic), so arrival must be handled by the node, not the builder.

---

## Finding 3 — the orrery's naive version hands over the Grand Commission

The sharpest finding of the pass: **`chart_data_sold` counts units sold with
no cell join**, and `CommissionDB` gates its stages on it at 8/30/60/100.
A pilot who sells a 100-unit orrery windfall at any counter clears the entire
chart pillar of the Grand Commission with one press of the ALL button —
"THE SURVEY THANKS YOU FOR YOUR CONTRIBUTION" becoming mechanically true in
exactly the way the horizon must not allow. No assertion catches it today.

Numbers that size the design: the mast pays 2 units per reading; a standard
loop earns 4 units (~8 minutes); ~30 units is an hour; **100 units is the
whole game** (the Commission's own derivation: ~2.7 hours). Holds: starter
24, typical mid-game 70, absolute berthed ceiling 130 — so "a scale a pilot
cannot earn in a session" that still *fits* is roughly 20–45 units.

**The recommended shape:**

- **24 units** — six loops (~48 minutes) of survey income in one hold, fits a
  mid-game hold without demanding a berth, and honestly enormous against the
  4-per-loop rate.
- A **distinct good id** (`chart_orrery` or similar) whose sale is **excluded
  from `chart_data_sold`** — the windfall must not buy Commission stages.
  Whether it carries `chart_band: 6` decides S6 (filable with the network for
  held-cell credit, or purely sellable).
- All-or-nothing hold that **defers on a full hold** (the mast's and the
  Stillness' posture); mark spends on the payout, so the instrument pays
  once ever (drift/vein rule, not layup).
- Two tripwires in the house dialect: `ORRERY IS NOT A RAISE` (no
  orrery/legend key in either pacing profile — the fourth sibling of FILING /
  MINING / JUMP / FRONTIER IS NOT A RAISE), and a windfall-budget clause on
  `CHARTED SEAMS ARE A WINDFALL`'s template with a **re-derived** bound
  (24 × 540 = 12,960 base ≈ 83% of the three-derelict budget: one legend is
  worth two and a half hulls, stated where a retune has to argue with it).
- The flight home is the encounter: chart goods carry interdiction weight,
  so a full orrery hold flirts with the raid ceiling and makes the biggest
  toll in the game. That is the design working — a windfall you must carry
  home — and the § should say so rather than sand it off.

Also confirmed: **orrery goods cannot be filed with the network by
themselves** — `network_filing_plan` joins goods against *unfiled surveyed
cells* and never spends a unit without a matching cell. The one open vector
is fungibility (windfall units filing cells the pilot surveyed long ago,
without a mast trip), which S6 decides.

---

## Finding 4 — the procession gates on writing, and on a name it already
shares

**The nine names do not exist.** Not in code, not in docs, not in history.
Page 6 ships as *"ATTACHED: vessels known to have filed after the effective
date"* with the margin note — *"NINE NAMES. I HAVE MET TWO OF THEM. THE LAST
ONE ON THE LIST IS A HULL IN A LIVERY NOBODY REGISTERED, LAST SEEN HEADING
OUT, STILL FILING"* — and the far-marks draft promises "here are the rest"
and stops. **Commit 5 needs a writing pass — nine names plus per-hull lines,
drafted and approved like the fragments and Directive 9 — before the
procession can build** (S8). Two constraints the writing inherits: the last
name on the list is the rival ("a hull in a livery nobody registered" — whose
wreck lies in band 5 of PYX-01, *not* in the procession), and the rival has
been kept deliberately nameless for two horizons, so naming that hull is a
fiction decision, not a copy decision.

**The name collision (S7).** "THE PROCESSION" is already a living faction —
the nomad fleet with the roaming port, ash-lavender, `PROCESSION_DEF`, a
1,200s window. THE PROCESSION'S END — a formation of dead ships, all pointed
home — shares the word. Either the two are connected on purpose (the dead
formation is where that culture's name comes from, or where part of it
ended), or one gets renamed before both ship. Nothing breaks mechanically;
everything collides poetically.

Mechanics, all settled by the pass:

- **Own node, ~60 lines; do not inherit `Derelict`.** The deposit gesture is
  a duck-typed contract (hold_begin/tick/release + on_tapped + pick_anchor)
  already carried by two non-Derelict classes. `Derelict._process` writes the
  single global prompt label on range transitions — twenty hulls in formation
  would fight over it every frame the player drifts through.
- **Named hulls are nodes; the mass is scenery.** Only the readable hulls
  (the seven not-yet-met names) join the tap group — spaced wider than
  `PICK_PX` (60px) so reading is never a lottery — and the hundreds the mark
  says nobody finished counting are cheap uninteractive meshes. This also
  keeps the one-frame build cost trivial.
- **Hull names go through `prompt`, never `show_broadcast`** — a broadcast
  holds 6.2s with no queue and erases its predecessor; three hulls read
  slowly would eat each other. One broadcast total, for the deposit response.
- **No per-hull log lines.** `note_log` has no dedup and a ten-line cap;
  reading the hulls would evict the run's history. One log line on the
  deposit (`note_mark_given` already returns `first`), nothing else — which
  is also the right fiction: the arrangement does not keep books.
- **The state lattice already suffices**: read → given, never spent, `closed`
  unreachable. No new state, no loader change. The procession's `match` arm
  must not guard on `is_mark_spent` (the per-kind rule §101 recorded).

---

## The decisions (S4–S8)

- **S4 — the nursery jump.** Ship the deep jump anchor as the draft promises,
  with the reversal done in the open: `A FOOTHOLD, NOT A FARM` re-derived
  against `FarMarks.DEPTH_MAX`, the anchor live only while the nursery is
  held, and the recapture clock as the price. Or: no jump — the nursery is a
  held *place* (warden-free ground, the fact of ownership) and the foothold
  fiction stays but the door into the deep does not open. **Recommended:
  ship the jump, held-not-owned, with the open re-derivation** — it is the
  entire "worth it" of the hardest fight in the game, and a foothold that
  moves you nowhere is a flag.
- **S5 — losing the nursery.** Recommended: assaults only resolve while the
  player is in-system (waves besiege the nursery and WAIT if the player is
  absent — arriving to find them mid-siege is the encounter); fleeing or
  dying mid-assault loses it; a lost nursery reverts to the Tally and can be
  retaken (the clock restarts, the counts do not reset — they remember).
- **S6 — the orrery's good.** Recommended: distinct id, `chart_band: 6`,
  excluded from `chart_data_sold` — sellable at band-6 prices AND filable
  with the network for held-cell credit (band-6 unfiled coverage is rare and
  hard-won, so the vector is honest), while the Commission never hears of it.
- **S7 — the procession name.** Recommended: connect rather than rename —
  the nomad fleet and the dead formation share the word because they share a
  history, and one line in the writing pass can carry it. But this is a
  fiction call, not a code call.
- **S8 — the nine names.** A writing pass produces the list and the per-hull
  lines for approval before the procession builds. Constraint carried from
  page 6: the last name is the rival's hull, which is NOT in the formation —
  the procession carries the *rest* of the list, and whether the rival's
  name appears on it at all is part of the decision.

## Build order, once decided

Cheapest and least coupled first: **orrery** (one node, one good, two
tripwires) → **forge** (parameters on the shipped escort machinery, the
splash-geometry rule, census-clean legs) → **procession** (gated on S7/S8
prose) → **nursery last, alone, as the v26 commit** (its own store, the
re-derivations, the clock, the assault) — the same
riskiest-lands-last-and-alone rule that put persistent coverage at the end of
Horizon 6.
