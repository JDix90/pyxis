# Horizon 4 — Factions

Status as of the end of the 2026-08-01 session: **fully designed with the user
and adversarially reviewed. Stage 1 is BUILT (save v18, STRATEGY §47);
stages 2–6 are specced, not built.**

> **Stage 1 has not been swept.** It was written in an environment with no
> Godot binary. See README's unmeasured-baseline note before trusting any
> number, and run the `--import` pass first — stage 1 adds a `class_name`.

Every fork below was put to the user as an explicit question and answered; the
answers are recorded as settled. Where building stage 1 changed a decision, the
section says so inline rather than being quietly edited.

This file follows the HORIZON-3-COMMISSION.md pattern: numbered sections,
"settled — do not re-litigate" markers, rejected alternatives recorded rather
than erased. Everything below is settled unless marked **OPEN**.

---

## 1. The ask, and what the code already says about it

Four tiers of faction, two structural changes, one recurring event:

1. A centralized **governing** faction — order/democracy/prosperity as stated
   values, fielding a security force that defends charted space.
2. Three **system-controlling** hostile factions, one per PYX, each fielding
   that system's apex engine plus its swarms and sentries.
3. Seven **known** factions present across the chart (the ask said five; §3
   settles why it is seven), friendly-to-hostile toward the governing power
   and each other.
4. Three **unknown** factions in deep space — wary, powerful, alien.

Plus: relocate the derelict hulls (and their sentries) out past charted space
on a dedicated bearing, and a recurring massive-swarm event that marches in
from 75u out while security amasses to meet it.

### Ground truth, verified against the code this session

- **The governing faction already exists in all but name.** The Galactic
  Survey Authority speaks through `DeepSpace.BROADCASTS` ("GSA RELAY"), clears
  lanes in `on_apex_defeated`, runs the Commission, and — decisively —
  `GUARD_DESIGNATION` already names the deep guards **"GSA PICKET —
  DECOMMISSIONED"** and **"PICKET — REGISTRY LAPSED"** (`deep_space.gd:274`).
  The security force this horizon builds is the *living* version of machines
  the fiction already ships as its corpses. Tier 1 is a promotion, not an
  invention.
- **The apex engines are already out there and do not move.** `SystemDB.lair_pos`
  places each 200–1450u past `chart_edge()` on a per-run salted bearing; the
  three Hunt stages (STRATEGY §38/§39/§42), dozens of HUNTTEST/BOSSTEST
  assertions and DEEPTEST's WORLD FINGERPRINT sit on top of it. **Apex
  placement is untouched by this horizon** — the ask's "relocate the Apex
  bosses further outside charted space" is already shipped, and re-deriving it
  would be re-litigating v15.
- **The derelicts are the piece that moves.** All three sit at authored points
  near the hub (`pyx01` at `Vector3(-9, 0, -18)`; the `-15` sometimes quoted is
  `_build_derelict`'s fallback, which no system uses).
- **No allegiance concept exists.** `Hostile._weapon` (hostile.gd:174) and
  `SwarmHostile._physics_process` (swarm_hostile.gd:142) both hardcode
  `get_first_node_in_group("player")` as the only target in the world, and
  `take_damage(amount)` carries no attacker. NPC-vs-NPC combat is a
  target-selection and damage-attribution rewrite in the two hottest loops in
  the game. It is the single largest engineering item in this horizon, which is
  why it ships first and alone (§4).
- **A faction prototype already shipped: the interdiction raiders.** Same
  airframe, `RAID_TINT` crimson, an extra group, a parley protocol, their own
  leash. The pattern "a faction is paint, groups and behaviour on an existing
  machine, never a new silhouette" is established and this horizon keeps it.
- **Two hard ceilings, both measured, both binding.**
  - `PACING_LOOP` measures 2.91 × lance_1 against a 3.00 cap — 97%. **Nothing
    in this horizon may add recurring income.** (§10)
  - `SwarmHostile`'s separation scan is O(n²) over the whole `swarm` group per
    physics tick (swarm_hostile.gd:178), with a fresh `get_nodes_in_group`
    allocation per ship per frame. Shipped caps are 10/16/6 per system. The
    set-piece's entire entity budget hangs on this loop (§8).
- **The radar caps at 12 markers** (`RadarLayer.MAX_MARKERS`, hud.gd:61), six
  tiers, all hostiles in one tier. A three-sided battle overruns the marker
  budget long before the frame budget (§8).
- **The band-1 beacon is the constitution.** *"Security patrols do not operate
  beyond this marker and cannot be dispatched to assist"* — pinned by DEEPTEST
  (substrings `"charted space"`, `"own risk"`) and by the PYXIS_DEEPSHOTS
  golden image. The Cordon's territorial limit is already canon, already
  asserted, and this design treats it as load-bearing rather than as an
  obstacle (§5, §7).
- **The no-charting crack already exists.** `Derelict.counts_as_survey` is the
  shipped mechanism by which deep hulks crack without charting the next system
  (derelict.gd:336-341). The training hull (§6) reuses it; no new gate is
  designed.

## 2. The relationship model — settled, do not re-litigate

**A full dynamic matrix, moved by player actions only.** The user chose the
matrix over the recommended scalar-plus-static-table, and chose player-only
drivers over seeded world drift and over NPC-combat feedback. The combination
is coherent and it is what makes the matrix assertable:

- Every faction pair holds an attitude in one of five named bands:
  **ALLIED / FRIENDLY / NEUTRAL / WARY / HOSTILE.** Bands, not floats —
  module_db.gd's "constrained, legible, few stats" contract applies to
  diplomacy too. Internally a small clamped int per pair; the band is the only
  thing any targeting rule or line of copy may read.
- The matrix = **authored baseline + player-caused deltas, clamped.** The
  baseline is a static table in FactionDB. Deltas move only from attributable
  player acts: kills, contract outcomes, fencing, tolls, holding the line at a
  muster. Flying a faction's contract implicates that faction — an escort run
  for the Combine through Grin space that ends in Grin kills moves
  Combine↔Grin as well as player↔Grin, because the player acted under the
  Combine's flag.
- **No input, no drift.** With zero player actions the matrix is
  bit-identical to the baseline forever. This is the invariant that makes the
  whole thing harness-defensible, and it is the first assertion of stage 1.
- Asymmetric baselines are allowed (A wary of B, B hostile to A); deltas apply
  symmetrically per event, for legibility.
- The player is a row in the matrix ("the surveyor", independent), which is
  what makes standing and inter-faction attitude one mechanism, not two.

**Rejected:** a single scalar per faction with a static inter-faction table
(user overruled the recommendation — recorded, not re-argued); fixed flavour
with no state; seeded autonomous drift ("the player logs into a world they did
nothing to"); NPC-outcome feedback (A kills B → A hates B more → A kills B
more needs explicit damping and a convergence proof — the shape of harness
that cannot be written honestly).

**One clamp is settled now rather than discovered later:** player↔GSA floors
at WARY. The Cordon never fires on the surveyor. A governing faction that can
be farmed into shooting the player breaks docking safety, the tutorial and the
new-player game in one move; outlaw-vs-the-Authority play is a real design but
it is a *deliberate* one, and it is out of scope for this horizon. Recorded as
a rejected alternative, revisitable on its own merits.

## 3. The roster — fourteen, and where each comes from

Settled with the user: the five known factions **grow from the existing port
identities** (not a parallel structure), plus **two deliberately placeless**
additions. That makes the known tier seven and the roster fourteen.

| # | tier | faction | grown from |
|---|---|---|---|
| 1 | governing | **THE GALACTIC SURVEY AUTHORITY**, whose armed service is **THE CORDON** | BROADCASTS, GUARD_DESIGNATION, the Commission, `open_lane` |
| 2 | system | **THE GNOMON** (PYX-01 host) | shipped apex identity + that system's swarms/sentries |
| 3 | system | **THE ARMILLARY** (PYX-02 host) | ditto |
| 4 | system | **THE MERIDIAN** (PYX-03 host) | ditto |
| 5 | known | **THE BASTION CHARTER** — armourers, lawful, pro-GSA | Bastion Yards + Blackwatch Yard |
| 6 | known | **THE FORGELINE COMBINE** — industry, neutral, trades with anyone | Cinderworks + Forgeline Depot + the Cold Forge |
| 7 | known | **THE EMBERS** — entertainment, rumour, the polite fence | the Embers Cantina |
| 8 | known | **THE GRIN** — the smuggling network | the Grinning Void + the Long Haven |
| 9 | known | **THE RELAY LEAGUE** — frontier homesteaders, "somebody has to be first out" | the Shoal Relay |
| 10 | known, placeless | **THE TITHE** — the corsair banner. Retroactively names the interdiction raiders: the crimson tint, the parley, the toll — all shipped content becomes their voice | RAID_TINT, the parley/toll system |
| 11 | known, placeless | **THE PROCESSION** — a nomad fleet that shows up rather than sits still; seeded route, trades rarities, wary of everyone | new |
| 12–14 | unknown | three deep powers, deliberately under-designed until their stage (§9) | GUARD_DESIGNATION bands 3–4, the band-3 commissioned broadcast, the Last Watch |

Naming note: tiers 2–4 keep the instrument scheme (Pyxis is the compass; the
engines are the sundial, the sphere, the line). The unknowns' names are
**OPEN** until stage 6 and should be chosen the way the Commission's names
were — against the copy they have to sit in.

**The Last Watch stays unaffiliated on purpose.** "Still lit. Nobody is sure
who is paying for it" (deep_port_db.gd) is a shipped hook, and the intended
answer is one of the unknowns. Do not assign it to the League or the Grin in
stage 5; that would spend the best mystery in the port data on tidiness.

**Rejected:** five portless parallel factions (orphans the port identities and
needs a new delivery channel per faction); folding the two placeless factions
into ports to keep the count at five (the user explicitly asked for placeless
additions; the Tithe in particular *must* be placeless — a toll collector with
a dock is a shop).

## 4. Stage 1 — the allegiance layer, alone — **BUILT**

> **As built.** The narrative of what changed and why is STRATEGY §47; what
> follows is the plan, kept as written, with build-time corrections marked.
> Shipped: `scripts/data/faction_db.gd`, the matrix and v18 save in
> `game_state.gd`, faction/targeting/attribution on both hostile classes,
> every `take_damage` caller updated, `PYXIS_FACTIONTEST` (10 assertions) and
> `SAVETEST=migrate17` (3).
>
> **Four corrections the build made to this plan:**
> 1. The `combatants` group is what carries allegiance; `hostiles` is
>    untouched and still means "opposed to the player". The plan's phrasing
>    ("allies are emphatically not in `hostiles`") was right but understated —
>    `hostiles` could not be *derived*, because six systems read it as the
>    player-opposition set.
> 2. Deltas are **sparse by invariant** (zero is erased, never stored). This
>    was not in the plan and is what lets `NO INPUT, NO DRIFT` assert on
>    emptiness rather than touring 240 pairs.
> 3. Not a correction but a confirmation worth recording: §2's split — an
>    asymmetric authored baseline, symmetric player deltas — survived contact
>    with the code, and is now enforced rather than merely intended. A
>    canonical `pair_key` makes an asymmetric *delta* unrepresentable, while
>    the authored table stays free to say the Grin hates the Authority more
>    than the Authority minds the Grin.
> 4. The apex scrapping its own pending probes no longer pays the player loot
>    or kill credit. Deliberate, and the one player-visible behaviour change in
>    a stage that promised none — see STRATEGY §47.

The foundation ships first, with **zero new content**, the way Hunt stage 1
built the door before stage 2 moved anything. Visible change to a player:
none. That is the point; it is proven entirely by harness.

What it contains:

- **FactionDB** (`scripts/data/faction_db.gd`) — a data-only leaf class like
  every other DB: ids, display names, the baseline matrix, band thresholds,
  tint per faction. It references nothing that references it back —
  §39's class-cycle lesson (DeepSpace→ApexBoss→HUD→DeepSpace hangs the boot
  with every `class_name` in the project "undeclared") says the constraint out
  loud: **FactionDB may name no scene class, and any constant another class
  must agree with is agreed by assertion, not by derivation.** Adding the
  class requires the import pass (README: the class registry is rebuilt only
  by `--import`).
- **Allegiance on the two hostile classes.** A `faction` id set by the spawner
  before `add_child`, same contract as `tint`/`difficulty`. Default: the
  faction every current spawner implies — sentries and swarms to their
  system's host engine id *later* (stage 3); in stage 1 everything defaults to
  a reserved `"feral"` id whose row is HOSTILE to the player and NEUTRAL to
  everything, which reproduces today's behaviour exactly.
- **Target selection.** `_acquire_target()` replaces the two hardcoded
  `get_first_node_in_group("player")` sites: nearest node whose faction band
  toward mine is HOSTILE (the player included), plus defend-if-attacked
  regardless of band. Docked player remains untargetable — safety at port has
  to be total, or it is not safety, and the assertion moves with the code.
- **Damage attribution.** `take_damage(amount, attacker)` — see finding A1
  for why the default argument is the dangerous part. Loot, `report_kill`,
  contract credit and ledger keys flow **only from player-attributed kills**.
  An NPC-on-NPC kill spawns nothing, credits nothing, ticks nothing.
- **The matrix state + save v18.** Standing/deltas persist; `migrate17`
  proves a v17 save arrives at the authored baseline — which by construction
  reproduces today's world (raiders hostile, everything hostile to the
  player, no allies). The v15 lesson applies verbatim: a migration must never
  revoke reachability or safety the old save had. Load path clamps every
  delta (`LOGTEST`'s LOAD COERCES is the template). Full persistence details
  (key shapes, sentinels for SAVETEST's write leg) are implementation-session
  work — flagged, not designed here.
- **Groups.** Allied ships are emphatically **not** in `"hostiles"` — that
  group is load-bearing everywhere (raid counting, cleanup, BANDS-style
  sweeps). Allies get `"cordon"`/`"allied"` groups and their own teardown;
  children of SystemRoot die with the warp for free, like everything else.

## 4b. Stage 2 preparation — what stage 1 leaves ready, and what it does not

Written at the end of the stage-1 session, while the code was in hand. §5 and
§6 are the *design*; this is the implementation runway.

### What stage 2 inherits, already built and asserted

- `faction` on both hostile classes, set before `add_child`. A Cordon picket
  is `var h := Hostile.new(); h.faction = "gsa"` — no new class, no new
  spawner shape.
- Allegiance-aware targeting. A `"gsa"` picket already refuses to fire on the
  player at any standing (asserted by `THE CORDON NEVER FIRES ON THE
  SURVEYOR`, which stands up a real picket and asks the real selector), and
  already engages anything its row calls HOSTILE. **Stage 2 does not write
  targeting code.** It writes patrol movement.
- Attribution. A picket killing a sentry pays nothing and ticks nothing,
  today, with no further work — `SKIRMISH PAYS NOTHING` (stage 3's assertion)
  is already true by construction.
- `FactionDB.TINTS` carries the Cordon's authority blue and the precedence
  rule (faction > raid > band) as a written-down comment. **Nothing reads it
  yet.** Wiring it is stage 2's, and it owes the palette audit (finding A2).

### The five edits stage 2 actually makes

1. **`hostile.gd`** — a waypoint patrol mode. It drifts around `_home` today
   (`_process`, the `sin/cos` line); patrolling is a route and a leash back to
   it. The engage envelope (~12u out, ~25u give-up) is new state, not a new
   behaviour: `_combat_target` already returns the right node.
2. **`system_db.gd`** — a `patrols` array per system, beside `sentries`, and
   `derelict` grows `bearing_deg` + `depth`. Both are authored data.
3. **`system_builder.gd`** — `_build_patrols` beside `_build_sentries` (and
   into the `skip_sentries` quiet path: nothing shoots at a menu, and a title
   screen over a patrol skirmish is noise). `_build_derelict` learns to place
   from bearing/depth, and gains the `training` branch.
4. **`derelict.gd`** — nothing, if the training hull is expressed as
   `counts_as_survey: false` on an ordinary derelict def. That flag already
   exists and already does exactly this for deep hulks. **Do not add a
   `TrainingHull` class.**
5. **`main.gd`** — the parley exemption (finding A3), and the harness work.

### Numbers settled by stage 1's reading of the code

- Relocation depth **100 / 130 / 150** for pyx01/02/03. All are inside band 1
  (`BAND_EDGES[1]` is 160), where `PACK_CHANCE[1] = 0.0` — so no procedural
  pack can ever spawn on the approach — and all are past
  `CONTENT_MIN_DEPTH` (24). pyx01's hull lands at radius 140 from origin
  against a lair at 300–380, so the derelict can never fall inside
  `LAIR_KEEPOUT` (120) for any run seed. That is a provable property and
  should be asserted as one, not assumed.
- The derelict's own placement must draw from **no RNG stream** (authored
  bearing and depth), which is what keeps DEEPTEST's WORLD FINGERPRINT still.
  Its suppression radius runs at instantiation, in `built_plan` and its four
  consumers — never in `plan_cell`. §39 already litigated this; re-read it
  before touching the generator.

### Collisions found while building stage 1 that stage 2 will hit

- **`_load_system` line ~933** arms the apex wake from `GameState.breached`
  and `_find_apex()`. It never reads the derelict's position, and `_wake_apex`
  has been a proximity poll since v15 — so relocation genuinely does not
  touch the wake chain. Verified, not assumed.
- **PACINGTEST's `_pacing_derelict_yield`** grabs
  `get_first_node_in_group("crackable")` in the charted system. Post-
  relocation that is the **training hull**, and the `derelict: 1` term in
  `PACING_LOOP` would silently measure a stub. This is finding A8 and it is
  the most likely way stage 2 goes quietly wrong. Re-aim it *and re-measure
  the loop* — the number will move, and it must be recorded rather than
  reasoned about.
- **`main.gd` line ~5266's comment** names "PYX-01's four lane guards,
  authored 6-20u out to cover the derelict". The sentries move with the hull
  (the ask says so); that comment moves with them.
- **`tutorial.gd` step 5** looks up `get_first_node_in_group("crackable")` and
  completes when it is gone. With two hulls in PYX-01 that lookup is
  ambiguous — whichever is first in the tree wins. The tutorial must find the
  **training** hull explicitly.

### The blocker, RESOLVED — and it dissolved rather than being chosen

§6's OPEN asked what the tutorial's finale *charts*, and offered two answers.
The user gave a third that makes the question much smaller: **the finale's
payload is a bearing to the engine, not a chart entry.** Shipped as STRATEGY
§48 — cracking a system's own derelict files a ±20° bearing on that system's
engine, the widest cone in the game and the only free one.

That reframes the two options rather than picking between them. Charting is
just "PYX-02 appears on the map, jammed"; the *hunt* is the payload, and the
hunt now starts at the breach whichever hull carries it. So stage 2 can put
`counts_as_survey` on either hull without changing what the tutorial means:

- **training hull carries it** — tutorial keeps §38's "ends by opening the
  world", relocated hull becomes loot plus Cordon narrative.
- **relocated hull carries it** — tutorial ends by handing over a bearing and
  pointing past the cordon; the world opens on the first real expedition.

Both are now cheap, because the bearing is filed by whichever hull is the
system's survey hull, and `counts_as_survey` is a one-line flag that already
exists. **Still worth confirming with the user before building** — but it is a
preference now, not a blocker.

**One thing §48 settled that stage 2 must not undo:** "PYX-02 only after the
PYX-01 engine dies" was checked and found to be **already true** —
`on_apex_defeated` → `open_lane`, and `travel_to` refuses a closed lane. §38's
two-tier gate, working as designed since v15. Do not reimplement it.

**And one new collision for stage 2's tutorial work:** with two hulls in
PYX-01, `tutorial.gd` step 5's `get_first_node_in_group("crackable")` is
ambiguous (whichever is first in the tree wins) — and so is `_find_crackable`
in main.gd, and PACINGTEST's `_pacing_derelict_yield`. All three need to name
which hull they mean. This is finding A8 widened: it is no longer just the
pacing loop.

## 5. Stage 2 — the Authority, the Cordon, and what "assist" means

Settled: **ambient patrols normally; reactive spawn-in reserved for
set-pieces.** Two mechanisms, each doing the job it is good at.

- **Pickets.** The Hostile airframe with GSA paint — the same machine as the
  decommissioned deep guards, *alive* — 2–4 per system, flying authored
  waypoint routes through charted space. Hostile grows a waypoint patrol mode
  (it drifts at `_home` today; modest extension). Sentry-class stats
  (`BASE_HP` 120 × system difficulty), no new silhouette: the tell is paint,
  per the raider precedent.
- **Assist = geometry, not scripting.** A picket peels off when a hostile
  crosses its engage envelope (~12u of route) and returns when the target is
  dead or ~25u gone. The player benefits by fighting near a patrol lane — the
  world is not staged around them. Fighting five units past the last picket
  gets no help, and that is the design: territory means something because you
  can leave it.
- **THE CORDON STOPS AT THE MARKER.** No picket exists or pursues past
  `chart_edge()`. The band-1 beacon has been promising this since v13, DEEPTEST
  pins the promise, and stage 2 turns it into an assertion about ships instead
  of about copy. This is also why "assists the player against the Apex" is
  resolved the way it is: the apex fights happen 200–1450u past the marker by
  shipped design, so **the Cordon never assists at a lair** — the hunt stays
  yours, and the beacon has already told you why. Assist-vs-Apex applies only
  in the counterfactual where an engine's forces push *into* charted space —
  which is exactly the muster (§8).
- **Death and respawn.** Pickets rebuild on `_load_system` like authored
  sentries do. No mid-session respawn in stage 2 (flagged **OPEN** for later:
  a respawn timer is a knob, not a design). A dead picket drops nothing and
  credits nothing — and a player who shoots one takes a standing hit while the
  picket does *not* return fire (the WARY floor, §2). Farming refusal is
  economic, not retaliatory: no loot, no credit, ever.
- **Skips.** The tutorial and ATTRACT builds skip pickets exactly as they skip
  sentries (`skip_sentries` widens or gains a sibling flag) — nothing shoots
  at a menu, and a title screen over a running patrol skirmish is noise.
- **Parley immunity.** During a live parley the Cordon holds fire at the
  raiders — finding A3. The toll is read, paid or refused by the *player*;
  a picket that shoots first turns the Tithe's signature mechanic into a
  spectator sport in charted space.
- **Standing surface.** Where the player *sees* standing follows the
  Commission's posture: a statement of record at dock (a line in the port
  sheet), never a HUD tracker row. Exact rendering is implementation detail;
  the prohibition is the design.

## 6. Stage 2 — the relocation, and the two-hull contract

Settled: **all three derelicts move far (depth 100–150 past `chart_edge()`,
authored per-system bearing), and PYX-01 gains a training hull.** The user
chose this over the short move and over grandfathering PYX-01.

- **The training hull takes the derelict's old berth.** It reuses pyx01's
  authored position `(-9, 0, -18)`, rotation and obstacle math — placement
  that is already proven against CRACK_RANGE (the 6.8-vs-6.5 lesson is in the
  builder's comments; do not re-learn it). Small loot, `counts_as_survey =
  false` — the shipped deep-hulk mechanism — so it **charts nothing and wakes
  nothing.** The tutorial's step-5 finale re-aims at it with its text
  unchanged.
- **The real derelicts keep every duty.** `mark_breached` → charts the next
  system; `arm_apex_wake` → the 9-second aftershock; `GameState.breached`
  semantics untouched. The only thing that changes is where the hull stands.
- **The bearing is authored, not rolled.** `derelict: {bearing_deg, depth}`
  per system def. Authored because the security fiction needs a *direction*
  the Cordon watches and the copy can name — and because the muster (§8)
  marches down the same bearing: the hulls drifted in from somewhere, and the
  swarms come from the same quarter. One bearing per system is "the wound."
  Deliberately **not** `lair_pos`-style per-run placement: the derelict is a
  destination the unlock hint sends you to, not a hunt.
- **The corridor is quiet by construction.** Depth 100–150 is THE SHOALS,
  where `PACK_CHANCE[1] = 0.0` — no procedural nests spawn on the approach,
  ever, and `CONTENT_MIN_DEPTH = 24` keeps generation off the doorstep. A
  tutorial-fresh pilot crosses the marker, hears the Authority disown them,
  and flies ~25–35 seconds of eerie empty Shoals to the hull. That beat *is*
  the pitch of the game, moved to minute twenty.
- **The keep-out runs at instantiation, never in `plan_cell`.** Stations do
  roll in band 1 (`STATION_CHANCE[1] = 0.035`), so the hull needs a modest
  suppression radius — and pyx01's hull at radius 140–190 sits squarely
  inside DEEPTEST's fingerprint window (cells −5..5, ~±384u), exactly where
  the lair keep-out sits. §39 already litigated this: `plan_cell` is the
  generator's word and stays untouched; `built_plan` and all four consumers
  (meshes, obstacles, armed nests, bay validation) carry the filter. The
  fingerprint stays safe by construction. The derelict's own placement draws
  from **no RNG stream at all** (authored bearing/depth), so the draw-order
  canary cannot move.
- **The sentries move with their hulls.** The derelict-lane sentries relocate
  out; they keep their engine allegiance (stage 3) and their kills still
  count for cull contracts (kills are counted, not populations). What remains
  charted thins — which is the *point* of a security narrative: charted space
  is safe-ish because someone holds it.
- **The tutorial's contract changes shape, and the doc says so out loud.**
  tutorial.gd's header promise — "ends by opening the world" — becomes "ends
  by teaching the verb and pointing at the cordon." The world now opens on
  the player's first real expedition. The post-tutorial bark/broadcast names
  the bearing: the first quest is implicit in the copy, not a quest system.
  TUTORIALTEST re-aims accordingly.

**Sequencing check (the part the ask flagged):** `_load_system`'s
"already-breached systems have a live engine" branch keys on
`GameState.breached` + `_find_apex()`, and `_wake_apex` is a proximity poll
since v15 — none of it cares where the *derelict* stands. Breach at depth 140
→ aftershock arms → the engine wakes whenever the hunter actually reaches a
lair hundreds of units away, exactly as today. Verified against main.gd:933
and main.gd:1933-1956; no redesign needed, only the assertions in §11.

**Rejected:** short relocation (30–70u — the user chose the stronger read);
grandfathering PYX-01 (non-uniform rule in the system the player lives in);
per-run rolled derelict bearing (a hunt already exists; the derelict is a
destination); co-locating the derelict with the lair bearing (would let one
bearing hint answer both the hunt and the salvage run — two currencies, one
purchase).

## 7. Stage 3 — the three engines become powers

Lowest-risk stage: the identities exist (`THE GNOMON` / `THE ARMILLARY` /
`THE MERIDIAN` are already data on the apex defs), the probes already fly the
engine's colours, and stage 1 built the machinery.

- Every ambient hostile a system builds — authored sentries, wave swarms,
  seeded deep nests within that system — takes its host engine's faction id.
  The dead frontier gets a retcon that was always latent: the "automated
  leftovers" were never masterless, and the lane-jamming engine you silence is
  the *government* of the system you took it from.
- **Charted space becomes visibly contested, at authored intensity.** Patrol
  routes are drawn to cross one sentry post per system, so an ambient
  picket-vs-sentry skirmish is a place you can go watch — and only one. The
  entity count of ambient NPC-vs-NPC combat is a route-authoring decision,
  not an emergent one.
- Skirmishes resolve honestly: sentries can kill pickets and vice versa; both
  drop nothing and credit nothing (stage 1 rule). An equal-force stalemate is
  broken by the existing despawn/leash machinery, and finding A6 adds a
  timeout assertion so two immortal machines cannot grind forever.
- Killing an engine (apex down) does **not** dissolve its faction's ambient
  forces this horizon — sentries rebuild on load exactly as today. A "the
  system falls quiet after the kill" beat is real design, flagged **OPEN**
  for a later stage; wiring it now would touch BOSSTEST's kill-permanence
  suite for a payoff nobody asked for yet.

## 8. Stage 4 — THE MUSTER (the recurring massive-swarm event)

Its own stage, per the user — it is arguably more new machinery than the
Cordon itself: goal-directed movement, a second army, an entity budget, and a
radar answer.

**The fiction resolves the constitutional problem.** The swarm spawns at
depth 75 — *beyond the marker*, where the beacon swears patrols never go. So
the Cordon does not sally: **it amasses at the chart edge on the bearing and
holds the line there.** The warning broadcast names the bearing; the marching
column crosses the Shoals corridor (empty by construction, §6); the fight
happens at the marker. A player can fly out to meet the column early — alone,
past the line, exactly as the beacon warned — or stand with the Cordon. The
event teaches the game's territorial rule instead of bending it.

- **Trigger:** timer-rolled like the rift (roll ~every 300s, chance ~0.25,
  long minimum spacing), never during boss/tutorial/raid/another muster, one
  live muster at a time. Warning broadcast ~45s before spawn. All constants
  named, provisional, and playtest-movable — "a number to fix later" in the
  Commission's sense. The muster also joins `interdiction_eligible`'s
  exclusion list (finding A5).
- **The column:** event-spawned SwarmHostiles (host-engine faction, distinct
  muster tint) in waves, plus escorts per the shipped `PACK_ESCORT_FROM`
  pattern. A new **march mode**: goal-directed movement toward the edge point
  at reduced speed (~2.5–3u/s — at the shipped 7.5 the whole march lasts ten
  seconds), ignoring the player until engaged. This is the first non-orbit
  movement mode in SwarmHostile's life; it is the stage's real engineering.
- **The line:** Cordon ships spawn in as a response fleet — this is the
  set-piece half of the settled assist model, and the one place reactive
  spawn-in is allowed. Precedent for player-keyed spawning exists
  (interdictions are keyed to hold value); the muster is keyed to a clock.
- **Entity budget:** total live event combatants capped (~36 provisional,
  wave-fed), because the O(n²) separation scan prices every ship against
  every ship. **The budget is set by measurement on the phone target before
  tuning, not by taste** — a STREAMTEST-style pass first. If the measured
  budget can't afford the spectacle, the separation scan gets a cheap
  neighbour cap (sample K nearest, not all) *as part of this stage*, measured
  again after.
- **Radar:** the set-piece renders **force-cluster markers** — one marker per
  force (the column, the line), not one per ship — sidestepping the 12-marker
  cap instead of reworking the tier system. Ordinary combat keeps ordinary
  markers.
- **Ordinary swarm activity continues separately**, as the ask requires:
  `_wave_timer` and the in-system spawner are untouched; the muster runs its
  own spawner and is exempt from the waves-stop-at-the-edge rule by being its
  own system (that rule exists because `_spawn_swarm_pack` clamps into
  `bounds − 6`; the muster spawner never clamps).
- **Outcomes.** Line holds (all column ships dead before crossing): GSA
  broadcast of thanks, standing gain, nothing bankable. Line breaks: the
  survivors dissolve into accelerated ordinary wave pressure for a few
  minutes (`_wave_timer` interval scaled — existing machinery, no new
  spawner), then normalcy. No port lockdowns, no damage states — consequence
  through a knob that already exists.

### Nothing bankable — settled, do not re-litigate

The muster **drops no loot, pays no salvage, and ticks no contracts** — even
on player-landed kills. `PACING_LOOP` is at 97% of a hard ceiling; this is
the only option that is pacing-neutral **by construction** rather than by
argument. The reward is standing, spectacle, and the line holding.

- Legibility: muster ships carry a distinct tint and the fiction says it out
  loud — the column is chaff, hollow airframes, a *weapon* rather than a
  cargo run. One bark, one broadcast line, and the player is never trained to
  expect a payout that isn't coming.
- Muster kills report a distinct kind (`"muster"`), so `kill_swarm` contracts
  cannot be farmed against a 24-ship column (finding A4).
- **Rejected:** paying out with an offsetting cut (a full economy re-tune
  inside a factions stage); paying through the apex-bonus route (excluded
  from the loop only by omission from a hand-written sum — a one-time trick,
  and the muster is recurring, so it would be recurring income wearing a
  bonus's clothes).

## 9. Stages 5 and 6 — the known seven, then the unknown three

**Stage 5 — the known seven, narrative-first.** The five port-grown factions
get their names on the doors they already own, standing wired to machinery
that already exists, and *gates rather than prices*:

- Standing gates **access**: the fence refuses a HOSTILE player, high
  FRIENDLY unlocks stock tiers or contract kinds, the Grin's grey market
  cares who you are. Standing **never modulates a price**. The
  sellback-vs-outfit guard rail (`max(sellback) < min(outfit_mult)`,
  STATIONTEST's pairwise sweep) holds today by two authored numbers; a
  standing multiplier on either side turns every standing band into a new
  point the sweep must hold at, and the failure mode is a module laundry.
  Recorded as the rejected alternative it is.
- The Tithe is retroactively attributed the interdiction system. **Raid
  mechanics are untouched in this stage** — whether Tithe standing modulates
  raid odds is **OPEN**, because RAID_* constants are tuned, RAIDTEST is
  already the flakiest suite in the sweep, and "pay the toll to make friends
  with the toll collectors" needs its own measured pass.
- The Procession is the one genuinely new object: a seeded route (own RNG
  stream, per the lair_pos discipline), appears in a system for a while,
  trades, leaves. Smallest possible first version: a visitable non-combat
  presence with a market bias — a *moving port*, reusing `Port.def` the way
  deep stations do.
- Faction contracts extend `contract_db.gd` kinds; note `ACTIVE_SLOTS = 2`
  (the HOLDTEST finding) before authoring anything that assumes a free slot.

**Stage 6 — the unknown three, deliberately under-designed here.** The hooks
are already in shipped data: band-3 guards are "UNFLAGGED — NO PATTERN ON
FILE", band-4 "UNREADABLE — IT DOES NOT ANSWER", the band-3 commissioned
broadcast ends *"It has been surveyed."*, and the Last Watch is lit by nobody.
The design rule this doc *does* settle: **alien reads as behaviour that
breaks the game's own conventions legibly** — telegraphs that are true but
strange — never as unreadable mechanics; the "every armament is telegraphed
and fully dodgeable" rule (§13 of STRATEGY) binds the unknowns too. Their
names, abilities and the Last Watch reveal are stage-6 session work with the
user. Their matrix rows exist from stage 1 (baseline WARY toward everyone)
and simply do not move until their stage.

## 10. The staging ladder — settled

| stage | ships | save | the proof |
|---|---|---|---|
| 1 | allegiance layer: FactionDB, faction ids, targeting, attribution, matrix | v17→v18 | harness-only; world visibly unchanged |
| 2 | GSA + Cordon patrols/assist; derelict relocation + training hull; tutorial re-aim | — | cordon stops at the marker; breach sequencing holds |
| 3 | the three engines own their systems; one authored skirmish theatre each | — | attribution complete; skirmish pays nothing |
| 4 | THE MUSTER | — | budget holds on phone; pacing untouched by construction |
| 5 | the known seven, narrative-first; standing gates | maybe (contract state) | guard rail holds at every standing band |
| 6 | the unknown three | — | designed in its own session |

Stage 2 is the widest stage. If it needs cutting in the hand, the seam is:
2a = Cordon + assist, 2b = relocation + training hull — they touch disjoint
files and either can ship first. Recorded so the cut is a decision already
made, not a scramble.

## 11. The adversarial pass — findings to carry into implementation

Each verified against the code this session, not speculative. Ranked.

- **A1 — `take_damage`'s default argument is a trap.** Adding
  `take_damage(amount, attacker = null)` compiles every existing caller
  silently — player weapons, torpedo.gd, arc chains, harness pokes — and if
  `null` means "nobody", every legacy call path stops dropping loot and the
  economy dies quietly; if `null` means "player", every future NPC caller
  that forgets the argument mints player credit. **Neither default is safe.
  Update every caller explicitly and assert both directions:** an
  NPC-attributed kill pays nothing, an unattributed call is a harness
  failure, not a guess. The callers are enumerable (`grep take_damage`) and
  the assertion belongs in stage 1's suite.
- **A2 — colour is already double-booked.** The one glance-legible channel on
  a phone (`tint`) currently encodes *band* on deep guards and *raider* on
  interdiction ships, blended at different ratios per silhouette
  (hostile.gd's 0.45-vs-0.62 comment). Faction tint is a third booking.
  Stage 1 must write the precedence rule down as data (proposal: faction >
  raid > band, because allegiance is the thing combat decisions hang on) and
  stage 2 owes a palette audit: fourteen faction tints × three band tints ×
  colour-vision modes (ACCESSTEST) is a legibility matrix somebody has to
  actually look at.
- **A3 — the parley dies without an exemption.** `break_parley` ends the
  standoff when a *raider* takes damage, from anyone. A Cordon picket that
  peels onto raiders mid-parley breaks the toll mechanic in charted space
  forever — the demand would never survive long enough to be read. The
  Cordon holds fire during a live parley (§5); assert it: a parley in picket
  range runs its full window untouched.
- **A4 — contracts are a payout channel too.** "Nothing bankable" is not just
  loot: `report_kill("swarm")` ticks `kill_swarm` contracts, and a 24-ship
  column is the fastest `sweep_swarm` filler in the game. Muster kills
  report `"muster"`; assert no contract kind matches it.
- **A5 — event collisions.** A muster during an interdiction (or vice versa)
  stacks two klaxons, two spawn systems and a parley timer on one screen.
  The muster joins `interdiction_eligible`'s exclusion list, and the muster's
  own trigger refuses while a raid is live. Same shape as the shipped rift
  exclusivity.
- **A6 — two immortal machines can stalemate.** NPC-vs-NPC fights have no
  player to die or flee; a picket and a sentry with mutually insufficient
  DPS can grind until the heat death of the frame budget. Every NPC-vs-NPC
  engagement carries a disengage timeout (return to route / post) and stage
  3 asserts a staged equal fight *ends*.
- **A7 — the wave-timer resume bug is waiting.** Swarm waves pause during
  `boss_active` and tutorial; the muster adds a third pause-source, and
  BOSSTEST's "WAVES RESUMED" already polices the second. The muster must use
  its own gate, not overload `boss_active` — overloading it would lock HUD
  panels (`set_panels_locked`) for an event the player may be nowhere near.
- **A8 — the training hull and PACINGTEST.** `_pacing_derelict_yield` finds
  "the crackable" in the charted system — post-relocation that is the
  training hull, and the `derelict: 1` term in `PACING_LOOP` would silently
  measure a stub. The harness must be re-aimed at the real hull (fly-out
  included, or staged at depth) **and the loop re-measured, not reasoned
  about** — the relocation moves real yield-per-loop numbers the same way §39
  moved BALANCE's seal counts.
- **A9 — the unlock hint now points into the dark.** "BREACH THE PYX-01
  DERELICT TO CHART" was written for a hull in plain sight. Post-relocation
  the hint needs the bearing in it, or the chart panel sends new players to
  a berth that holds a training stub. Copy change, but a mandatory one, and
  GSATEST-adjacent copy is asserted.
- **A10 — fourteen rows the player cannot see.** A dynamic matrix that only
  ever surfaces as targeting decisions is invisible politics — the player
  changed something and cannot find out what. Minimum viable surface ships
  *with* stage 1's consumer stages: the dock line (§5) plus one log line per
  delta ("CORDON STANDING RISES — THE LINE HELD"), through the existing
  `note_log` machinery. Never a HUD row.

## 12. Assertions to write (tagged per stage; FACTIONTEST is a new tag — add
it to `HARNESS_VARS` **and** `run_harness.sh`'s TAGS, per the §38 lesson)

Stage 1: `NO INPUT, NO DRIFT` (fresh state, zero acts → matrix ==
baseline) · `DELTAS ARE BOUNDED` · `TARGETING HONOURS THE TABLE` (staged
pairs at every band) · `DOCKED IS STILL SAFE` · `NPC KILLS PAY NOTHING`
(loot, salvage, ledger, contracts — all four) · `ATTRIBUTION IS EXPLICIT`
(A1, both directions) · `[save] v18 round-trip + migrate17 arrives at
baseline` · `LOAD CLAMPS THE MATRIX`.

Stage 2: `THE CORDON STOPS AT THE MARKER` (no allied node past
`chart_edge()`, ever — the beacon's sentence as code) · `PICKETS PEEL AND
RETURN` · `THE PARLEY IS IMMUNE` (A3) · `THE TRAINING HULL CHARTS NOTHING`
and `THE REAL BREACH STILL CHARTS AND WAKES` (both directions of the two-hull
contract) · `THE KEEP-OUT NEVER REACHES THE FINGERPRINT` (derelict edition)
· `DEEPTEST band-1 substrings unchanged` · TUTORIALTEST re-aim · A8's
re-measure.

Stage 3: `EVERY AMBIENT HOSTILE HAS AN OWNER` (attribution sweep per
system) · `SKIRMISH PAYS NOTHING` · `THE FIGHT ENDS` (A6 timeout).

Stage 4: `THE MUSTER CARRIES NOTHING` (no loot table, no drop path) · `MUSTER
KILLS TICK NO CONTRACT` (A4) · `THE LINE IS THE EDGE` (cordon-side of A5's
geometry) · `THE BUDGET HOLDS` (live entity count under wave feed, measured)
· `WARNING PRECEDES SPAWN` · `ORDINARY WAVES ARE UNTOUCHED` (wave timer
independence, A7) · PACINGTEST unchanged — asserted, not assumed.

Stage 5: `THE GUARD RAIL HOLDS AT EVERY BAND` (STATIONTEST sweep × standing
bands) · `THE FENCE REMEMBERS` (gate assertions) · RAIDTEST untouched until
the Tithe question is decided.

House rules apply: every assertion red-verified by breaking its mechanism;
observation lines are not assertions (§39's `(must be true)` beside `false`
lesson); no assertion reads the developer's save.

## 13. Facts checked so you do not have to re-check them

- `PACING_LOOP` headroom is 0.09 × lance_1 (2.91 measured vs 3.00) — there is
  no room, which is why §8/§10 are absolute rather than cautious.
- The Shoals corridor really is empty: `PACK_CHANCE[1] = 0.0`, and only
  stations (3.5%/cell) and hulks roll there — hence the keep-out, and hence
  the relocation corridor being safe for a tutorial-fresh pilot.
- `counts_as_survey` already splits "cracking teaches/charts" correctly:
  archeology and `hulks_cracked` tick outside the guard, charting and the
  apex wake inside it (derelict.gd:336-357). The training hull needs zero new
  gating logic.
- The wake pipeline is position-independent end to end: breach →
  `arm_apex_wake` → 9s timer → proximity poll at the lair. Verified against
  main.gd:1927-1956; relocation touches none of it.
- `lair_pos` and the fingerprint: the derelict's authored placement draws no
  RNG, and pyx01's hull (radius 140–190) is inside the hashed window — both
  facts point at the same instantiation-only keep-out rule.
- The raiders' full kit (tint, groups, standoff, `depart`, drop_good) is the
  template for every faction-flavoured ship this horizon adds; nothing needs
  a new silhouette.
- 40 suites / 53 runs, baseline 447 PASS / 1 standing FAIL (HOLDTEST,
  pre-existing) — plus the two known flakes (RAIDTEST's eligibility race,
  DEEPTEST's STARFIELD under load). A red sweep during this horizon is not
  news until those three are ruled out.
