# Pyxis — Founding Strategy

Reference analysis and direction for the project. Written 2026-07-24 after
studying a screen recording of Star Trek Fleet Command (Scopely) as a quality
benchmark. This document records *why* Pyxis is built the way it is; it is not
a spec for any single feature.

## 1. What we are building

An original single-player mobile-portrait space game about **salvage and
cartography**: you command a survey vessel charting a dead frontier — burned-out
battlefronts, derelict megastructures, automated defense swarms still fighting a
war nobody remembers. Compass-constellation theme (Pyxis is the mariner's
compass), amber/gold holographic cartography as the primary visual language,
with a cyberpunk "signal glitch" accent in magenta/teal.

We are matching the reference's **feel**, not its scope.

## 2. Decisions

| Decision | Choice | Rationale |
|---|---|---|
| Engine | Godot 4.6 | Already installed; handles our modest technical ceiling; Unity's advantages (asset marketplace, live-ops tooling) don't apply until much later. Reassess at end of vertical slice. |
| Platform | Mobile portrait (720×1280 base) | Where the reference's audience lives. |
| Scope | Single-player, offline-capable | MMO/live-ops scope is a 50-person operation. Ours is not. |
| State | Local save, explicitly serialized | Keeps a server port possible without building one now. |
| Content | Data-driven | Content scales without code changes. |

## 3. Experience pillars

These are the qualities that must be reproduced at high fidelity. Everything
else is negotiable.

1. **Living star chart presentation** — dark space + one strong holographic
   environmental element + massive foreground props + parallax. This formula
   produces most of the atmosphere.
2. **Reward spectacle** — kills erupt in staged explosions and spill physical
   loot that is visibly vacuumed up while counters animate. Anticipate →
   destroy → shower → count.
3. **Diegetic, quiet HUD** — console-styled, corner-anchored, never modal
   during play, everything animated.
4. **Frictionless command interaction** — tap to designate; the ship handles
   the rest. Every tap acknowledged within 100ms by a ring pulse and a sound.
5. **Scale contrast** — a tiny player ship against enormous hostiles,
   derelicts, and asteroids. Cheap to build, huge atmospheric payoff.
6. **Cohesion** — one palette, one type ramp, one VFX language. Polish here
   beats adding any feature.

## 4. Reference analysis summary

The studied recording (19s) showed a high-level player destroying large
biomechanical hostiles in a star system. Directly observed: tilted top-down 3D
camera with smooth pan/zoom over a system plane; deep near-black starfield with
a huge curved holographic grid; photo-real mega-asteroids anchoring frame edges;
small player ship with a thin damage strip; swarms of small fighters plus large
tanky structures with red HP bars; multi-stage fireball destruction; dozens of
gold loot cubes spilling and being vacuumed into a particle vortex; a resource
counter climbing 16.2M → 80.9M with animated count-ups; a static corner HUD that
never occludes play.

Reasonably inferred: tap-to-target with auto-resolved combat (player skill lives
in fleet/loadout choice, not aiming); Unity mobile forward rendering with bloom;
modest entity counts (<30) where density is sold by particles and scale
contrast, not object count.

Unvalidated: all audio design (the capture was silent), actual input gestures,
menus, onboarding, progression pacing, and whether nearby ships were live
players.

## 5. What we deliberately do not build

Real-time MMO backend; alliance/social systems; timer or energy monetization;
base building; officer/crew collection; a three-tier map hierarchy; and any
lookalike of the reference's licensed IP (ship silhouettes, insignia, HUD
layout, naming). Divergence is checked at every art review — the
amber-cartography identity is the mitigation.

## 6. Roadmap

- **Phase 0 — Feel prototype.** *Complete.* Camera rig, tap-command autopilot,
  auto-combat, staged kills, loot vacuum + animated counter, hold-to-breach
  derelict set piece, ten procedurally synthesized SFX.
- **Phase 1a — Fitting system.** *Complete.* Slot-and-module ship fitting,
  swarm hostile archetype, local save. See §9 for its design contract.
- **Phase 1b/1c — Warp travel, three systems, contracts, onboarding.**
  *Complete.* Systems are data (`scripts/data/system_db.gd`) built by
  `SystemBuilder`; breaching a system's derelict charts the next one, so the
  best moment in the game is also the door to more game. Survey contracts give
  the loop direction; ship-AI barks handle onboarding without a tutorial mode.
- **Phase 1d — Apex boss ("The Gnomon").** *Complete, tuning open.* A survey
  engine that alternates SURVEY (iris open, core vulnerable) with SEAL (vents
  tanky probes that weld the iris shut for the next window), inside a rotating
  sweep arm. Damaging the core requires entering the sweep's reach, so nobody
  snipes it from safety. Killing it drops a wreck that pays out through the
  game's hold-to-breach loot vortex. **Known open item:** dual Lance Mk II still
  clears it ~40-90% faster than the other fits (27s vs 44-51s). Every fit
  completes it, but the "no fit >25% faster" bar is not met — needs a hands-on
  tuning pass with a human dodging.
- **Phase 1e — Ports & the living market.** *Complete.* One dockable port per
  system (freeport station, mining colony, military yards), each with a trading
  personality. Docking is the only fully safe state — invulnerable and ignored
  by hostiles — and is refused during an apex fight. Prices are
  `base × port bias × slow drift × player pressure × events`: routes emerge from
  the data rather than being scripted, dumping cargo visibly depresses a local
  price, and shortages/gluts announce themselves. Module purchasing moved to
  port outfitters (swapping owned gear stays free anywhere); cargo capacity is a
  fitting stat, so trading builds argue with combat builds; combat drops typed
  commodity crates; delivery contracts settle automatically on docking.
- **Phase 1f — Desktop direct control.** *Complete.* Mouse-to-touch emulation is
  off so the two device families can disagree about the primary button: on
  touch a tap on empty space still moves (mobile's only way to move), on desktop
  a click selects and a miss does nothing. Desktop adds WASD/arrows (screen-
  relative, derived from the camera basis), Tab to cycle targets, Space for the
  Core ability, Escape to back out. Direct input overrides the autopilot but
  deliberately keeps the attack target, so you strafe while firing; the ship
  noses at its target and banks into the drift. A persistent reticle now marks
  what you are shooting. **Mobile is untouched** — tap-to-command remains the
  only mobile scheme, per pillar 4.
- **Phase 1g — Front door & guided first run.** *Complete.* The game boots into
  an attract state: the title sits over a live, drifting PYX-01 (real starfield,
  lattice, derelict) with the ship parked and the HUD hidden — NEW SURVEY,
  CONTINUE (only when a save exists) and an audio toggle. NEW SURVEY starts a
  six-step guided run in the real starting system — move, engage, collect,
  discharge, refit, breach — during which no garrison is built and no swarm wave
  spawns. The finale is the derelict breach, which charts PYX-02, so the tutorial
  ends by opening the world; the garrison then arrives on a five-second grace so
  the loot vortex gets to land first. Everything past that is already handled by
  the contextual barks.
- **Phase 1h — Responsive UI.** *Complete.* The 720×1280 portrait design space is
  unchanged, but `scripts/ui_layout.gd` now owns responsiveness. On a wide window
  the `canvas_items` stretch would otherwise be driven by the height term
  (0.70× at 1440×900 — smaller than on a phone), so a scale boost applies to
  landscape windows only; portrait windows, meaning every phone, are left
  bit-identical. The UI also renders inside a centred column capped at the design
  width, so the layout appears exactly as authored — just larger — with the 3D
  world filling the window behind it. Desktop launches at 1100×800 and re-lays
  out live on resize.
  **Revised in phase 2.5 after play** — see §15. The column cap was right for
  the sheet consoles and wrong for the corner controls, and the scale boost
  overshot.
- **Phase 2 — The Living Frontier.** *Complete.* The frontier stopped being a
  backdrop and became a place with weather.
  - *Physicality.* `scripts/obstacles.gd` — an analytic sphere registry, not
    physics bodies, because every mover in this codebase integrates its own
    position and retrofitting `CharacterBody3D` would have rewritten all of them
    at once. Three queries carry it: `resolve` (slide out), `steer` (autopilot
    rounds corners), `blocked` (a rock stops a shot, and you see the spark).
  - *Scale.* Per-system bounds (40/48/44), new celestial bodies, denser
    garrisons, a secondary station per system, +15% drive speed so bigger does
    not mean slower.
  - *Economy bite.* Loot ~0.55×, prices ~1.8×, contracts 0.7×, repeat apex kills
    0.7×. See §10 and §11.
  - *Feel.* Two-layer adaptive score crossfading on threat; edge-of-screen radar
    pings; pause, settings and save v6.
  - *Depth.* Cargo interdictions (a full hold is now a liability as well as an
    asset), a contract board you choose from instead of a to-do list handed to
    you, the torpedo family, three station types, 64 ship liveries and six Mk II
    module tiers.
- **Phase 2.5 — Vertical slice.** Art-dressed systems, final models, complete
  VFX pass, a mega-derelict climax. Acceptance: side by side with the reference,
  an observer says "same league" at 60fps on target hardware.
- **Phase 3+ — Production foundation, content production, polish.** Gated on
  the slice validating the direction.

## 7. Principal risks

1. **Demo-vs-game cliff.** Reproducing 19 impressive seconds is a weeks-scale
   problem; sustaining it for hours is the real cost. Content production is
   deliberately gated behind slice validation.
2. **Auto-combat flatness.** The reference's moment-to-moment play is shallow
   and carried by meta pressure and social stakes we won't have. Our answer is
   fitting decisions plus an active ability; if that doesn't land, the design
   needs a bigger swing (positioning, targeting choices).
3. **Art cohesion.** The biggest polish risk for a small team; mitigated by a
   mandatory palette/color-grade pipeline and hand-made hero assets.
4. **Scope gravity.** Every genre neighbor will feel "missing." The pillar list
   is the contract for saying no.

## 8. Conventions

- Feel-critical tunables live as named constants at the top of their script
  under a `FEEL CONSTANTS` comment.
- All colors come from `scripts/palette.gd`. No literal colors in gameplay code.
- One-shot visual effects go through `scripts/fx.gd`; audio through the `Sfx`
  autoload.
- Audio is synthesized by `tools/gen_sfx.py` (pure stdlib Python) — original,
  license-free, and regenerable. Tune the numbers and re-run.
- Meshes are kitbashed from primitives in code, which keeps asset cost near zero
  and makes per-module ship variation cheap.
- Audio buses (Master / SFX / Music / MusicCalm) are built in code at boot for
  the same reason: the project stays reproducible from source with no binary
  resources to keep in sync.
- Every major system gets an env-var harness in `main.gd` printing tagged,
  greppable assertion lines (`[station] NO ROUND-TRIP PROFIT ... -> PASS`). Run
  them; do not eyeball the game and call it verified.
- **Harnesses must never be able to write the player's save.** They call
  `GameState.lock_saving()`, which is deliberately ONE-WAY. Assigning
  `save_enabled = false` is not enough: `start_new_game()` assigns it back to
  true, and `PYXIS_TITLETEST` exists to press NEW SURVEY — that combination
  silently overwrote a real save with a fresh starter run. A harness that needs
  the real file layer (see `PYXIS_SAVETEST`, `PYXIS_LIVERYTEST`) redirects
  `save_path` to a probe file *first* and never unlocks.

## 9. The fitting system's design contract

Chosen deliberately between two failure modes. A **linear upgrade ladder**
(Mk I → II → III, +10% each) is a salvage sink, not a decision — it works in
the reference only because alliance politics and PvP supply the pressure, which
single-player Pyxis will not have. **Full EVE-style fitting** (multiple
constraint resources, hundreds of modules, stacking penalties) has depth that is
socially real rather than mechanically intrinsic; combinatorial space that
encounters never test is fake depth the player cannot perceive, and its UI
density is hostile to a portrait phone.

What we build instead — "EVE in miniature." A fitting decision is interesting
when it is:

1. **Constrained** — one power budget, not several. One constraint is a
   decision; two or more is bookkeeping. The reactor's three tiers loosen it,
   and even Mk III cannot carry a fit of all-best modules.
2. **Legible** — few stats, all shown as deltas against the current fit.
3. **Tested** — encounters must punish and reward different fits, or the
   tradeoffs are cosmetic. Arc chains shred swarms and tickle single tanks;
   Lance is the reverse. Shipping a fitting system without encounter variety
   would be shipping nothing.
4. **Reversible** — salvage buys modules; swapping owned modules is always
   free. Cheap experimentation is what turns a catalog into a decision space.
5. **Visible** — every module changes the kitbashed hull, so a fit is an
   identity you can read at a glance.

Note what is absent: module count. Expressiveness comes from combinatorics
against varied encounters, not from a large catalog. ~12 modules across 5 slots
already yields hundreds of meaningfully distinct fits. The architecture (slots +
power + data-driven modules) scales EVE-ward for years if the game earns it —
we chose a small initial catalog, not a small ceiling.

## 10. The economy's pacing contract

Phase 1 shipped a catalog a normal run could buy almost entirely, with change
left over. That quietly broke contract #1 above: when everything is affordable,
a power budget is the only thing still forcing a choice, and the catalog reads
as a shopping list to work through rather than a set of tradeoffs to argue with.
Money has to be a second constraint, or fitting is half a system.

The rule, asserted by `PYXIS_PACINGTEST`:

- An **eight-minute standard loop** — clear waves, crack one derelict, run one
  full hold between ports, finish one contract — earns **4–15% of the full
  catalog**, which is roughly one mid-tier module.
- The **steady-state** version of that loop (no derelict, because there are only
  three hulls in the whole game and each cracks once) must still clear the 4%
  floor on its own. If it does not, the game slows to a crawl the moment the
  hulls run out, which is exactly when it should be opening up.

Both levers are pulled moderately rather than one severely: loot cubes pay
~55% of their phase-1 value and prices are ~1.8x. Halving earnings alone would
have made the same catalog feel like a grind; raising prices alone would have
made early salvage feel worthless. Repeat apex kills pay 70% — the one-time
first-kill bonus already carries the achievement, and farming a solved fight
should never out-earn flying somewhere new.

The harness is an activity budget, not a wall-clock replay. It plays each
activity for real with a starter fit and measures what the game actually pays;
only the weights are authored. Re-run it after touching any price, reward, or
drop rate — that is the entire point of it existing.

One lesson worth keeping: the floor is measured in **mid-tier modules per loop**,
not as a fraction of the catalog. Shipping the six Mk II tiers grew the catalog
84% and would have failed a catalog-fraction floor without a single earning
changing — the metric would have been reporting on how much content exists
rather than on how the game paces. A pacing assertion has to hold still while
the catalog grows. The catalog fraction is still the right shape for the
*ceiling*, because "earning got too fast" stays true at any catalog size.

## 11. The economy's integrity rule

**No port may be a money printer.** Buying a good and immediately re-selling it
at the same station must lose money — at every port, for every good, at every
trade size. `PYXIS_STATIONTEST` asserts this exhaustively, and it exists because
the rule was broken the first time a station modified prices: the smuggler's den
pays a 1.25x fence premium, a freeport's spread is only 6%, so Stolen Goods
quoted BUY 169 / SELL 188 at the same counter — an infinite money loop reachable
by tapping two buttons.

The fix is the one to reach for again: a fence **buys and does not sell**. Close
the loop at its source rather than capping the premium, which would have made
the fence pointless. Any future service that moves a price on one side only must
either close the other side or prove it stays inside the spread.

**Declared tradeable must mean actually tradeable.** `CommodityDB.trades_at()`
and a port's `services` list are separate data that have to agree, and nothing
made them. Contraband declared itself tradeable at the Cantina, the Cantina
shipped with neither a market nor a fence, and the marquee smuggling route could
be bought into and never sold out of — while the price assertion passed the
whole time, because `Market.sell_price` is arithmetic that never asks whether a
counter exists. `PYXIS_STATIONTEST` now asserts every good has a counter that
will take it, and prints the counter list for every restricted good.

A restricted good is a route, and a route needs both ends built. When adding one:
list its `trade_only_at` ports, then check each of those ports actually has a
`market`, or a `fence` naming that good.

## 12. Station types

Ports are data. A port def lists `services: []`, and `port_panel.gd` builds its
tabs from that list — so a new kind of station is a dictionary entry plus one
`_build_<service>` method, never a new panel class. Systems carry one primary
`port` (which the tutorial, the chart and delivery contracts all still mean) and
any number of secondaries in `ports: []`.

Three shipped, each with one idea:

- **The Embers Cantina** (PYX-01) — no market at all. Sells rumours that name a
  live market event, and an honest losing wager (45% to double, streak-capped).
  The wager's odds are printed on the table because a hidden bad bet is a con,
  and this game is about reading a market.
- **Forgeline Depot** (PYX-02) — bulk breaks at 10+ units, 75% module sell-back
  against the usual 60%, and no Mk II weapons. Somewhere to rotate a fit.
- **The Grinning Void** (PYX-03) — fences relics, cores and stolen goods at
  1.25x; grey-market modules at −20%; the supply end of the contraband route.

Contraband is the trade with teeth: dense, valuable, only two buyers on the
chart, and weighted ×3 for interdictions. Buy at the Void, sell at the Cantina
two systems away, and the margin is the fattest on the chart precisely because
carrying it is what brings the raiders. Stolen goods sit one step down — raider
drops, restricted to the Void, the Cantina and the Anchor, weighted ×2. The
Anchor is on that list deliberately: a drop in the starting system should never
be cargo with nowhere to take it.

## 13. The apex engines

Each system's apex is the same class with a different identity, supplied as data
(`name` + `attack` on the system's `apex` def). Before this they were one machine
repeated three times, and all of the machine's pressure was *delegated* — probes
deny the window, the sweep denies the ground — so the hub was a target rather
than an opponent, and "fight the boss" meant "shoot swarm fighters and time your
shots".

| Engine | System | Armament | The question it asks |
|---|---|---|---|
| **THE GNOMON** | PYX-01 | Shadow lance — locks a firing line on your position, fires down it a beat later | Sidestep. The cleanest statement of the rule. |
| **THE ARMILLARY** | PYX-02 | Flare mortars — shells lob onto you under shrinking ground rings | The dodge is a direction, not a sidestep. |
| **THE MERIDIAN** | PYX-03 | Graviton tether — no damage at all; drags you toward the hub and the sweep | Weaponizes position itself. Burn outward. |

Two rules hold all three together:

1. **Every armament is telegraphed and fully dodgeable.** `PYXIS_APEXTEST`
   asserts a parked ship takes damage and an orbiting one takes zero. An attack
   you cannot answer with movement is a damage tax, not a mechanic.
2. **They fire during SURVEY only.** SURVEY is where the player parks on the core,
   which is the behaviour they exist to punish. Firing through SEAL as well
   stacked a second pressure onto the phase where slow fits already spend most
   of their time: Arc went from a 53s kill to a 180s timeout with two emergency
   warps, and since a warp resets the engine to full, the tax compounded into a
   wall rather than a cost.

Damage is deliberately small and scales more softly than the rest of the
encounter (`ATTACK_DIFFICULTY_SOFTENING`). A later engine already brings more HP,
a faster sweep and more probes; at the full multiplier a Meridian lance hit was
44 against a 100-point shield, which made the armament the fight instead of the
pressure on it.

### Harness bots are not pilots

Adding the armaments exposed two ways the scripted bots were measuring
themselves instead of the game, and both are worth remembering because any
future timing mechanic will re-open them:

- A dodge expressed as *velocity added per call* makes evasiveness a function of
  how often the caller polls. The balance harness ticks at 0.25s and the demo at
  0.6s, so the demo bot dodged 2.4× worse and lost fights the balance bot won
  with every fit. Express bot movement as a **target speed**, never an impulse.
- The same poll rate also throttles **retargeting**. At 0.6s the demo idled up to
  half a second after each probe died, never cleared a seal, and sat at the 0.15
  floor multiplier all fight. Control cadence and capture cadence must be
  separate numbers.

Both looked exactly like "the boss is too hard" and were neither.

## 14. When the world is allowed to interrupt you

Docking is the only fully safe state. Everything else keeps moving — but an
interdiction is specifically *not* allowed to begin while a console is open.
A console covers two thirds of the screen and does not pause the game, so a raid
starting behind one is an ambush the player never had a chance to see coming;
they close the sheet and a pack is already on top of them. Being jumped should
always be something you could have reacted to.

The full exclusion list (`Main.interdiction_eligible`): docked, warping, in an
apex fight, in the tutorial, any console open, a raid already live, or inside the
90-second cooldown. Warping out of a raid earns that cooldown too — the escape
hatch must not drop you into a fresh roll twenty seconds later in the new system.

## 15. Chrome sits in the corners; sheets sit in the column

Phase 1h put the whole interface in a centred column capped at the design width,
on the reasoning that corner controls would otherwise "drift to opposite edges"
on a wide window. Playing it full-screen on a Mac showed the opposite problem is
worse: the controls stop framing the play area and start sitting *in* it.

Two faults were compounding, and they are worth separating because they have
different fixes.

**Position.** At 1920×1080 the logical space is wider than the 720 column, so the
cap inset every corner control ~337 physical pixels from each screen edge —
CHART, REFIT and the ability button all parked well inside the play field. The
distinction that was missing: a **sheet** is rows, and rows must not stretch
across an ultrawide with the label at one edge and its buttons at the other; a
**HUD corner** is a corner, and belongs at the screen's. `UILayout.chrome()`
spans the viewport, `UILayout.column()` still caps the sheets. On portrait the
logical width already equals the design width, so every phone is bit-identical.

**Size.** `DESKTOP_REFERENCE` was 620 — a target logical height less than half
the phone's 1280 — so a round button that occupies ~5% of a phone screen occupied
**12.3%** of a desktop one. The rule written to stop the UI shrinking had quietly
turned into one that doubled it. At 820 the same button is ~8.3% everywhere on
desktop, and the effective scale still never drops below 1.0.

`PYXIS_LAYOUTTEST` now prints the button's share of screen height at every test
size and asserts desktop stays within 1.8× the phone's. Nothing was watching
that axis before, which is how a scale rule drifted this far without failing
anything.

## 16. Ship specialisation, and the guards around it

The five fitting slots became six: `UTILITY_B`. Deliberately a **second utility**
rather than a new category — the interesting question was never "what kind of
thing can I bolt on", it was "which of these do I want", and a second slot turns
one pick into a pairing decision.

Five specialist rigs, each a genuine **trade** expressed as negative stats on the
same additive pile everything else uses:

| Rig | Buys | Costs |
|---|---|---|
| Hauler Frame | +34 hold | speed, turn, accel |
| Prospector Rig | salvage yield, magnet, hold | speed, reach, shield |
| Strike Frame | crit, reach, speed | hold, shield |
| Bulwark Plating | +150 shield, regen | speed, turn, hold |
| Runner Frame | speed, accel, turn | hold, shield |

A hauler ends up at 58 hold / 7.8 speed against a strike frame's 10 / 10.4 — the
specialisation reads at a glance, which is the point. `PYXIS_SHIPTEST` asserts
every rig has at least one cost, so no rig can quietly become a stat stick.

Two rigs stack, so `compute_stats` carries **floors** (speed ≥ 1.6, accel ≥ 3.0,
turn ≥ 1.5, shield ≥ 40, hold ≥ 6). Hauler + Bulwark must be sluggish, not
stationary or reversing.

### The hold guard

A refit that shrinks the hold below what is in it is **refused**, not allowed
through. Before this, stripping a Cargo Bay from a loaded ship left `cargo_used`
above `cargo_capacity` — an invalid state every other system then had to
tolerate. The refit console offers the only honest way out: jettison, dumping
**cheapest-first** so the player loses the least valuable thing aboard, behind a
two-tap confirm (this game has no dialogs; the toast says what will happen and
the second tap means yes). Jettisoning pays nothing — dumping cargo to dodge a
trip to a port should not also be profitable.

### Hull integrity

One health pool, named honestly. `HULL n%` sits in the top-left readout stack
because the bar over the ship is readable when you are looking at the ship and
useless when you are looking at what is shooting it. Recovery out of combat was
always there (gated behind `SHIELD_CALM_DELAY`) and is the free option; the
REPAIR bay at four stations is what you pay to skip the wait, priced on what is
actually missing so a scratch is cheap and limping in is not. Repair Bay modules
raise regen and compete with the Shield Capacitor for the utility slot — "survive
a bigger hit" against "be ready sooner" is the decision.

### Breaking off

An apex fight had exactly one exit: die. Docking is refused mid-encounter and the
chart button is locked, so a player who had bitten off too much had to stand
there and let it happen — a fail state wearing a mechanic's clothes. BREAK OFF
lives in the pause menu, the one console reachable during a fight, and costs
exactly what dying costs: the engine resets to full and the run continues.


## 17. The expanse

Space is almost endless and mostly empty, and the camera follows out into it.
The player found the seam themselves: `player_ship.gd` had no positional bound
at all while the rig was clamped to the world origin, so you could fly off your
own screen. The fix was not a fence. Going the other way — leash the camera to
the ship, wrap the starfield, and let the map end — turns the game's one
navigation bug into its largest room.

### Distance is measured as depth, never as radius

`DeepSpace.depth_at` is `radius - bounds`, floored at zero, so **everything
inside the charted system reads as depth 0** and every gradient built on it is a
no-op for content that already existed. It also means a bigger system pushes its
own expanse out with it: PYX-03's Reaches begin where PYX-03 ends, not at an
absolute number that happens to suit PYX-01.

Four bands past the chart — THE SHOALS, THE DRIFT, THE REACHES, THE QUIET — and
every system that varies with distance indexes the same table, so the gradient is
tuned in one file. Each of those tables carries an identity row at index 0. That
is what makes "the expanse changes nothing about the charted game" a property of
the data rather than a promise.

### Nothing out there is saved

A cell's contents are a pure function of `hash("<system_id>|<cx>|<cz>")`.
`plan_cell` returns a manifest and the spawner builds from it — one source of
truth, so stability is provable rather than asserted, and a harness can compare
two visits without flying there twice. Revisiting a sector costs zero bytes; the
alternative, a visited-cells array, would grow every minute the player flies.

Streaming is 5×5 cells of 64u, torn down at 7×7. The gap is hysteresis, and the
sizing is load-bearing: crossing into a new cell adds a column whose nearest edge
is 128u away against a visible half-extent of ~34u, so content always appears and
disappears three screens off camera. That is the only reason it needs no fade.
Obstacles come out of the registry **synchronously, before** the deferred
`queue_free`, or there is one frame with an invisible wall in it.

### The gradient is parameters, not new classes

Danger out there is `SwarmHostile.tint` / `hp_scale` / `difficulty` and a
`Hostile` escort, indexed by band. No new enemy type earns its keep when the
existing ones have the dials already, and a violet swarm that hits like a sentry
reads instantly on a phone in a way a new silhouette would not.

Three things had to be added to make it survivable rather than merely hostile:

- **A despawn leash.** A swarm does 7.5 against the ship's 5.75, so it cannot be
  outrun. Inside a system that is correct — a system has edges and a station to
  reach. In open space it is a sentence. `despawn_radius` defaults to 0 (never
  give up), so every authored encounter is untouched; the expanse sets 140.
  Breaking off pays **nothing** — no loot, no credit — or the leash becomes a way
  to farm packs by running away.
- **Nests arm, they do not spawn.** A cell materialises 128u out, which is beyond
  its own leash, so a pack born with the cell would die on arrival. The manifest
  holds the nest; it springs at 44u — outside the visible half-extent, inside the
  leash — so you never watch ships appear.
- **Hostiles belong to `system_root`, never to the cell.** A pack that belonged
  to its cell would vanish mid-fight the moment the chase carried you past the
  streaming window, which is exactly what a real chase does.

Swarm waves stop at the chart edge, and not only for pacing: `_spawn_swarm_pack`
clamps inside `bounds - 6`, which a few hundred units out collapses onto one
fixed world point the player would never see. `spawn_interdiction` had the same
clamp and the same fix.

### Interdiction runs the other way

Danger climbs with distance while interdiction **falls** — ×0.6 / ×0.3 / ×0.1 /
×0.05 by band, applied after the clamp so `RAID_MIN_CHANCE` cannot swallow the
gradient. Never zero: there is no range at which a full hold is safe, only ranges
at which it is unlikely to be noticed. This is the trade the expanse rests on.
A hold full of contraband is safest exactly where everything else will kill you.

### Deep stations are not on the chart, by construction

`SystemDB.port_ids()` feeds the market-event roll, the cantina's
O(goods × ports²) rumour loop and three `PYXIS_STATIONTEST` sweeps. Deep
archetypes therefore live in `DeepPortDB` and ride on `Port.def` instead;
`port_panel` reads that when set and falls back to the SystemDB lookup otherwise,
which for every authored port returns the same dictionary. Charted docking is
bit-identical, not merely equivalent — and there is no code path by which a
station 600u off the map can start a shortage at the Anchor.

Out there nothing is restricted (`CommodityDB.trades_at` returns true for any
`deep_` prefix): nobody asks what is in the crate, and that is the reward for the
trip. The branch cannot fire for a charted port id, so the chart's restriction
map is untouched. The Long Haven fences at 1.45 against the best charted 1.25,
which is the reason to carry contraband **outward** rather than home.

### The arbitrage rule got its real assertion

§11 says no port may be a money printer. The module side of that rule is
`max(sellback) < min(outfit_mult)` across every station, because a module is
bought at `price × outfit_mult` and sold at `price × sellback`. What was actually
asserted was one hard-coded pair — grey-market `arc_2` at the Void against
sell-back at the Depot — and it passed at 0.75 < 0.80 by luck, not by design.

Deep stations are precisely the content that turns that luck into an infinite
laundry flown between two docks: one archetype at `outfit_mult 0.70`, another at
`sellback 0.85`, and you print money. So `PYXIS_STATIONTEST` now sweeps every
buyer against every seller — chart and expanse together, 121 pairs — and names
the binding one. `DeepPortDB` states the guard rail as constants and
`violations()` checks its own defs against it, so a bad archetype is caught as a
bad archetype rather than found later as an exploit.

The general rule, worth keeping: **when a value holds by luck, the assertion that
covers it is the invariant, not the instance.** A test that names one pair stops
being a test the moment somebody adds a third station.

### Finding your way back

An endless map needs two things a bounded one does not: a way to know where you
are, and a way to get home. Both were deferred until the expanse had something in
it worth flying to; once it did, they stopped being polish.

**The label became instrumentation.** Inside a system the bottom-left readout is
decoration — the lattice, the moon and the station already tell you where you
are. Past the chart edge none of those exist, so the label is the only answer to
"where am I", and it changes to give one: `SYS // PYX-01 · THE DRIFT · 340u OUT`,
tinted with the band's own colour. The short system name survives and the tagline
does not, because "DERELICT FIELD" names a charted volume and is precisely the
thing that stops being true when you leave it.

**The home marker is a compass, not a contact.** It sits above the apex in the
radar's priority tiers, so the 12-marker cap can never drop it — out in the
Reaches with a full board, the one arrow you cannot afford to lose is the one
pointing at the system you came from. It is also exempt from the distance fade
and from the on-screen skip every other marker obeys: it should be on the border
the whole way out and the whole way back, not blink off near the chart edge.

**Marker alpha was saturating.** The falloff spent its whole range in 60 units
and then sat on a 0.3 floor, which is right for a system 40-48 units across and
useless outside one — every contact beyond ~54u drew identically, which out there
is every contact. The span now scales with the player's band. Band 0 is ×1.0, so
nothing inside a system moved by a pixel.

**Recall is free, and that is an argument rather than a kindness.**
`PlayerShip._emergency_warp` already puts a dying player back at the spawn point,
so the game performs this move for you involuntarily whenever you get it wrong.
Charging for the voluntary version would tax doing deliberately what carelessness
gets for nothing. It is refused exactly where docking is refused — mid-fight,
mid-warp — because breaking off an apex by tapping a console is an exit, not a
decision.

It runs the warp charge, streak and flash **without** `_load_system`. That
function frees SystemRoot wholesale, which for a move that never leaves the
system would reset the apex to full, respawn the garrison, delete loot still
drifting toward the player and reroll every deep sector. `travel_to` early-returns
when the destination is the system you are already in, which is what a recall is,
so this needed its own entry point rather than a flag on that one. The harness
asserts the SystemRoot instance id is unchanged across the move, which is the
cheap way to keep that true.

One latent bug fell out of building it: `dock_to` animates the ship onto the dock
ring with a 0.6s position tween, and `undock` did not cancel it. Anything that
moved the ship inside that window — undocking fast, or now a recall — was quietly
fought by a tween still dragging it back to a ring it had already left.

## 18. What playing it out there changed

Five notes came back from flying the expanse, plus one bug the flying uncovered.

### The mounts answer on their own

Chasing a swarm around by clicking produced the worst possible loop: the player
is being shot, is busy repositioning, and is therefore *not shooting back* —
which is not a difficulty curve, it is a control problem wearing one.

The fix could not simply assign to `attack_target`, because that one variable
drives three things at once: the guns, the autopilot's destination and the hull's
facing. Auto-assigning it would fly the ship *at* whatever shot it — the exact
opposite of what someone backing out of a pack wants, and the same fight-for-the-
stick the WASD path already refuses to have.

So the guns got their own target. `auto_target` is acquired only while something
is actually shooting at you, is read only by the weapons, and never moves or
turns the ship. **The player runs; the mounts answer.** An explicit order takes
the guns back instantly and completely.

Two details that are load-bearing:

- Acquisition is gated on *being under fire*, not on anything being in range. A
  ship that shoots whatever wanders past picks fights the player did not — and
  gating it this way is also why it cannot misfire during the tutorial, whose
  first combat step is "click a contact to engage".
- Return fire is timed off its own clock, not `_time_since_hit`. That one gates
  shield regen and only moves when damage actually lands, so a shot absorbed by
  Aegis leaves it untouched. Correct for regen; wrong here. Being shot at while
  protected is still being shot at.

### Some wrecks are bait

Out past the chart a share of hulks are rigged: breaching one blows an EMP —
drives and mounts dead for a couple of seconds — and whoever set it comes to
collect, with a bigger pack and, from the Reaches out, a fighter riding along.

Three things keep it a decision rather than a tax:

- It is **seeded** like everything else out there. A given hulk is always rigged
  or always is not. A trap that rerolled per visit would be a coin flip wearing a
  mechanic's clothes.
- A rigged hulk **pays more**. You are not being punished for salvaging; you are
  being offered worse odds on a bigger pot.
- It **has a tell**. Everything in this game that can hurt you telegraphs first —
  the sentry's charge-up, the apex's ground rings — and a trap is not an
  exception to that rule. A rigged beacon runs cold electric blue and stutters
  instead of breathing: something in there is still drawing power, on a wreck
  that should be dead. It is deliberately only legible up close, so you learn
  what it means at the moment you are already deciding to commit.

The EMP does not grant invulnerability, and `_emergency_warp` still fires if the
hull goes. It can cost you the run; it cannot trap you in one.

### Leaving is breaking off

`boss_active` locks the chart and refit buttons, refuses docking and refuses
recall. That was airtight while the camera clamp meant you could not meaningfully
leave the arena. Phase 3 removed the clamp and left the lock — so a player could
fly out into the Drift carrying a boss fight's console lockout for a fight four
hundred units behind them.

Rather than a new rule, this reuses the one that exists: **crossing the chart
edge mid-encounter IS disengaging**, and costs exactly what BREAK OFF costs. The
geometry and the rules now agree. It does *not* teleport you home the way the
pause-menu version does — you went out there on purpose.

The apex also no longer wakes while the player is outside the charted volume. It
sits at an authored position near the origin, so waking it out there would lock
every console for a fight that is not visible, not reachable and not started —
and against the rule above it would wake and disengage on a loop.

### A wall, versus somebody washing their hands of you

The plan called for a soft outer limit with a turn-back prompt. A broadcast is
better and costs less: a wall says *the designer stopped building here*, whereas
a survey authority disclaiming responsibility says *people stopped coming here* —
the same information delivered as fiction instead of as UI.

One automated beacon per band, outward only, escalating from a formal GSA
liability notice to a recording nobody is maintaining to no carrier at all. It
also does a job the taper needed: raiders thin out with distance because nobody
is watching, and saying so out loud is what turns a number into a place.

### The bug the expanse found: every sentry was at the origin

`Hostile._ready` captured `_home` from `global_position`. But **every** spawner in
this codebase — `SystemBuilder`, the apex, the interdiction, the expanse — calls
`add_child()` and sets `position` on the *next* line, because a node has to be in
the tree before `global_position` means anything. So `_home` was always the
container's origin, and since `_process` hard-writes
`global_position = _home + drift`, every sentry in every system snapped to the
middle of the map on frame one.

PYX-01's four lane guards are authored 6-20u out to cover the derelict and apex
approaches. All four were sitting on the player's spawn point.

It survived ~140 passing assertions across two dozen harnesses because **nothing
had ever asserted where an enemy is**. Everything measured HP, damage, counts,
prices, layout, and save round-trips. Position was checked for ports, for
obstacles, for the camera and for the player — never for a hostile. The lesson is
narrower than "write more tests": a value that no assertion reads is a value that
can be wrong for months, and the ones most likely to be wrong are the ones set by
a caller *after* construction.

`_home` is now captured on the first frame — wherever the spawner put us, once it
has finished putting us there — and `PYXIS_DEEPTEST` asserts every sentry stands
within its drift radius of an authored post.

### The assertion that was measuring the wrong thing

Return fire raised peak single-window damage against the apex and tripped
`PHASE INTEGRITY` — "no fit may burst a whole phase inside one SURVEY window."
Chasing it turned up something worse than a balance problem.

**`max_window` is the HP a phase LOST in a window, so it can never exceed that
phase's HP.** The assertion compared it against phase HP, which means it was
measuring *"the phase died"* rather than *"the fit could have killed it twice
over"*. Raising phase HP to buy headroom raised the measurement with it:

| phase HP | worst window | apparent headroom |
|---|---|---|
| 1500 | 1500 | 0% |
| 1700 | 1681 | 1.1% |

Removing the cap entirely (phase HP temporarily 6000) gave the real number:
**~2520 in one window**, against a 1700 phase. So a strong fit with Overcharge up
and every plate open has *always* been able to delete a phase in one window. The
assertion passed only because peak burst and a full window rarely coincided, and
it started failing when return fire made them coincide more often.

The fix was to measure the stated intent instead of a proxy that saturates. From
the top of `apex_boss.gd`, the concern is that such a fit "would never meet a
seal, a probe, or the sweep — it would skip the encounter's ENTIRE mechanic."
That is directly countable. Each phase that is *not* bursted forces at least one
seal, so the seal count reads as how many phases the fit actually had to play:

    0 seals - all three phases bursted; the mechanic never ran
    1 seal  - two phases bursted
    2 seals - one phase bursted
    3+      - every phase played

The bar is **2**: at most one phase may be skipped. Deliberately not "one per
phase" — that would sit exactly on the observed floor, which is how the previous
assertion ended up failing on a coin flip. The observed range is printed
alongside so drift toward the bar is visible long before it crosses.

`PYXIS_BALANCE` is now seeded, the same way and for the same reason
`PYXIS_PACINGTEST` is. Note the limit honestly: seeding makes runs *similar*, not
identical, because FX and price drift pull from the same global RNG on a
frame-count-dependent schedule. A threshold this close to its data needs both a
seed and margin.

Two things were kept from the balance work: phase HP stays at **1700** (more
room, honestly earned, just not the reason it was raised), and return fire never
targets the apex hub. The hub exemption is defensible on its own terms — when the
iris opens you are already parked on the core with it explicitly targeted, so
there is nothing there for auto-targeting to fix — and it cut return fire's share
of that fight from 13.5% to ~4%.

**The general lesson, and it is the same one as the sentries:** an assertion that
has never failed is not evidence that it works. This one had a ceiling it could
not exceed by construction, so it could only ever fire on an exact tie. Ask of
any invariant: *what value would this print if the thing it guards were badly
broken?* If the answer is "the same value", it is not guarding anything.

## 19. Salvage you cannot read yet

The seven goods were sell-fodder: one verb, one axis. The brief asked for four
things — goods as categories, loot with a purpose, skills that turn scrap into
useful items, and items with effects of their own. A first pass planned these as
a crafting system. Laying all four side by side showed they are not four
features; they chain into one loop.

> You crack something in the deep. What you pull out is **unidentified** — you
> know roughly where it came from and nothing else. It sells for scrap as-is.
> Read it, and it becomes a specific thing worth more, that does something while
> you carry it, and that feeds a recipe later.

This fits the game's own first sentence better than crafting alone does. Pyxis is
*"salvage and cartography"* — this makes salvage an act of **interpretation**
rather than collection.

### Provenance is the category, and it was already there

`DeepSpace.BAND_NAMES` already named five places. So unidentified salvage is five
goods named for them — CHARTED, SHOAL, DRIFT, REACHES and QUIET Salvage — and the
"sub-items" the brief asked for come from *where you found a thing* rather than
from a parallel item list. That is also what let the component set stay at nine
instead of fourteen: a Pre-War Servo out of Quiet Salvage already feels different
from one out of the Shoals, with no extra rows on a portrait phone.

### Reading is a decision, not a roll

§12 says the Cantina prints its odds "because a hidden bad bet is a con." A paid
random reveal is disqualified by the game's own standard, so **the player picks
the output** from a printed list per band. No RNG anywhere in the conversion.

That is not just integrity, it is better: it makes a run plannable — three servos
means three Drift Salvage — which is §9's legibility rule applied to loot instead
of to fitting.

### One rule for where you can read

    in the field   band <= archeology
    at a lab       band <= archeology + 1

The lab is always exactly one band ahead. So there is always a reason to carry
something home, and always a reason to raise the skill, at **every** tier — which
is what stops either half becoming vestigial once the other matures. Field reads
live in REFIT rather than at a port, because reading your own hold is not a
service; §12 keeps services at stations, and this is you and a prybar.

### The skill gates information, not power

ARCHEOLOGY is deliberately not spendable and grants no stats. A higher tier does
not make you stronger; it makes a thing you were already carrying legible. That
is what keeps it clear of §9's "linear upgrade ladder" objection — and it is why
it is one line of text above the read list rather than a console. A skill with its
own screen is a skill that has become bookkeeping.

It is also why it is called ARCHEOLOGY and not "Crafting": craft to level crafting
to unlock crafting is circular. When CHEMISTRY and SMUGGLING follow, their feeds
must *compete* — an hour smuggling is an hour not cracking hulks — or four skills
all fed by "playing the game" rise together and it is a clock, not a decision.

### Carried effects are world effects

A Forged Manifest quietens the whole hold's signature; an Unstable Charge lights
it up. Both are read at the point of use (`Main.hold_signature`), never through
`compute_stats`.

That was not a style preference. `cargo_after()` probes `compute_stats(fit)` while
`cargo_capacity()` reads live stats, and `cargo_overflow()` subtracts one from the
other — so a good that moved a fitted number would make the hold guard from §16
subtract two different piles from each other. The rule that falls out: **cargo may
change what the world does to you, never what the ship can do.**

The pair is the design. An Unstable Charge is one of the best things THE QUIET
yields *and* it makes the trip home louder, so the most valuable haul in the game
is also the most dangerous to carry. That is §16's "every specialist pays for
something", moved off the fitting screen and into the hold.

### Two assertions that would have passed while broken

`REACHABLE` only requires one counter *anywhere on the chart*. A component listed
at four ports and sellable at one would pass it — which is precisely the shape of
the contraband-at-the-Cantina bug §11 was written about, since the Cantina has a
fence and no market. `EVERY NAMED BUYER BUYS` closes it: every port a good names
must actually have a counter for it.

`_pacing_trade_yield` swept every good against every port pair with **no legality
check at all**, so it priced routes the player cannot fly — buying contraband at
Bastion Yards among them. It went unnoticed because the best fictional route
happened to be beaten by a real one, which is luck rather than a property. Adding
sell-only goods would have broken that luck immediately: each gets an imaginary
buy leg, and the whole pacing band moves for a route nobody can fly. The fix
prints the best *illegal* route beside the legal one and asserts the skip count is
non-zero, so if the filter is ever removed the two numbers visibly collapse into
each other.

Both are the same lesson as §18, arriving from a different direction: an
assertion that has never failed is not evidence that it works.

### What the audit before the play-test found

The loop shipped green and the next step was flying it. Auditing first turned up
four gaps that would have made that play-test evaluate a half-built system —
worth recording because three of the four are the same mistake in different
clothes.

**A constant nothing paid.** `ARCHEOLOGY_PER_BREACH` existed, and the `TIERS`
assertion divided by it to print "6.5 standard loops to cap" — but no gameplay
code ever awarded it. The real paid rate was reads-only, nearer ten loops. The
assertion was §18's failure shape exactly: its output was identical whether the
rate was real or fictional. Breaching now pays it, deep hulks included (cracking
a hull teaches you about hulls wherever you found it — only the charting and the
apex wake are things the expanse must be kept away from), and `BREACH XP` asserts
the game pays what `TIERS` claims.

**Three effects that existed only in their own descriptions.** The Thermal Sink
said "shrugs off an EMP wash", the Cartographic Index said "stations answer it",
the Reliquary Heart said "rigged hulls hum near it". None of them did anything.
Flavour text is a promise, and an unimplemented promise is worse than no promise:
it teaches the player the system is arbitrary.

**A tier that arrived in silence.** `mark_archeology` returned whether a tier was
gained and both callers discarded it. "Does 0→1 land fast enough to teach the
loop" is unanswerable in play if nothing announces the tier.

### The rule the effects had to be built under

All five carried effects read the hold at their point of use — never through
`compute_stats`. That is not style. `cargo_after()` probes `compute_stats(fit)`
while `cargo_capacity()` reads live stats, and `cargo_overflow()` subtracts one
from the other, so a good that moved a fitted number would make §16's hold guard
subtract two different piles from each other. **Cargo may change what the world
does to you, never what the ship can do** — and `CARGO IS NOT A FIT` now asserts
it across all five, so the next carried effect cannot quietly break it.

### Testing a rule, not a rendering

Two of the effects lived inside draw code — the Index in `RadarLayer._draw`'s
alpha maths, the Heart in the derelict's prompt string. Both were lifted into
`marker_alpha(tier, dist)` and `breach_prompt()`, which the renderers now call.
The assertion tests the rule; nothing has to read pixels.

That refactor immediately earned itself. The first `INDEX` assertion measured a
station marker at 300u and failed with both values pinned at 0.30 — because at
band 0 every contact is already inside the fade span, so widening it changes
nothing. The effect was correct and the *test* was wrong: it was measuring the
Index exactly where the Index is designed to be inert. You do not need somebody
else's chart of the system you started in. Measured in THE REACHES it reads
0.40 → 0.76, with hostile markers unmoved.

Worth keeping as a companion to §18: **an assertion can fail because the thing it
measures is broken, or because it is measuring in the one place the thing is
supposed to do nothing.** Check which before changing the code.

## 20. Bonded stores

Play raised a question the salvage loop could not answer on its own: does a hold
of unknowns feel like a reason to come home, or does the hold just fill up and
end the run? Free-floating caches were the obvious answer and the wrong one —
they bypass hold capacity outright, which voids §16's specialisation trade (a
Strike Frame would get a Hauler's capacity for the price of extra trips), and
they decouple what you found from what you are exposed to. Storage at stations
instead: bounded, tied to a place, and it does not dodge in-flight raid risk
because you flew the cargo there.

Note honestly what it does NOT solve. "I am 900u out and full" is answered by
something already built and still invisible: reading compresses a hold 2.6–3.7×
(Quiet Salvage at 340 value / 3 space becomes an Unstable Charge at 420 / 1).
Making that legible is deferred. Bays answer a different question — **where do
you put unread salvage you cannot read yet.**

### The key is the place, and the place is the cell

`deep_space.gd` sets a station's `port_id` from its archetype, so every Shoal
Relay in every system, forever, is `"deep_relay"`. A bay keyed on that is one bay
shared across an infinite map: stash 200u out of PYX-01, warp, withdraw 200u out
of PYX-03, and a hold has teleported between systems having flown two band-1 hops
at ×0.6 raid taper instead of two loaded crossings at ×1.0. Deep bays are
therefore keyed on the **cell** — `"pyx01:5:-6"` — which is a stable identity
precisely because content is a pure function of `hash("system|cx|cz")`.

This does not make the expanse saved state in §17's sense, and the distinction is
worth stating because it will come up again: §17 refuses a visited-cells array
because it "would grow every minute the player flies" — **passive** growth
proportional to distance. A bay grows only when you deliberately put something
down. `NO PASSIVE GROWTH` asserts exactly that, by flying forty cells past live
stations and requiring the key count not to move.

And because generation stayed pure, the save can be **validated against the
generator**. Every deep key is re-derived through `plan_cell` on load and dropped
if that cell does not hold a station with a bay. An edited or stale save
self-corrects. That property is a dividend of determinism, not a feature that had
to be built — and the first version of the round-trip test proved it by dropping
a cell the author had picked by hand, which turned out to hold no station at all.
The fix was to *find* a real bay cell from the generator rather than name one.

### The bonded rule

> **A bay accepts only goods the game will never sell you** — `no_retail`: the
> five salvage grades and the ten components.

This closes a money printer that no shipped assertion could see. Market events
last 240–360s, so with an open bay: buy alloys at the Anchor under a 0.55× glut,
put them down, wait for the event to lapse, sell at the same counter. **+62%,
guaranteed, no travel, no raid exposure** — and the Cantina's rumour tab sells you
the event locations. `NO ROUND-TRIP PROFIT` cannot catch it, because it prices
both legs inside one loop iteration, at one instant, under one `market_events`
array. It encodes "no port may be a money printer" but it tests "no port's spread
is inverted *right now*", and storage is the content that separates those.

Closed at the source rather than by capping anything, which is §11's own fix
pattern. And it earns its keep as design rather than as a guard: at Archeology 2 a
hold of Reaches and Quiet Salvage is unreadable everywhere and is dead weight you
sell for scrap. A bay is where you put it down and come back at tier 3. The bay's
contents are exactly the set of goods that have a reason to accumulate.

`NO TIMED ARBITRAGE` prints the full arithmetic every run whether or not the
guard holds, so relaxing the rule does not change a `0` to a `0` — it changes
`can_store=false -> PASS` into `stashed 24 -> FAIL` with `+62%` already sitting in
the same sentence.

### Where the line is on "one constraint"

`WAREHOUSE_SPACE` is one constant, printed on the tab, identical at every station,
**never a port-def key** — and `CAP` asserts no def carries one. A cap that varies
turns storage capacity into a thing you shop for and compare across stations,
which is a second budget with its own shopping trip. §9 rule 1 allows one.

Three chart bays, one per system, so retrieval is a warp rather than a hop. Plus
15% of deep stations, rolled from the same seeded stream as everything else out
there — scarcity has to be a property of the place or "is there a bay at that
relay" stops being something a player can learn. Not finding one is the point.

### Stash is not a weakening of the hold guard

§16 says jettison pays nothing "because dumping cargo to dodge a trip to a port
should not also be profitable." Stashing **is** the trip to the port — you are
docked, you flew here. The cost is preserved exactly; only the destruction is
removed. Three constraints made it safe:

- **Its own function.** Cheapest-first is still right but for a different reason —
  what stays aboard is what you fly away with and what draws raiders — and
  reusing `jettison_to_fit` would have left a comment that lies.
- **All or nothing.** A stash that half-fills the bay, still fails the equip and
  leaves you over-full with a partly-emptied hold is the worst failure available.
  `STASH CONSERVES` asserts `used_before == used_after + bay_after` as an
  equation with all three numbers printed, because a stash that silently eats
  three units passes any boolean you could write around `can_equip`.
- **Its own control**, not the second tap. "Tap again" already means jettison, and
  overloading a gesture designed to slow down a destructive action makes the
  destructive action ambiguous.

### One landmine worth remembering

`DeepPortDB.by_id()` returns the `ARCHETYPES` entry itself, and GDScript
dictionaries are references. `p.def = arch` then appending `"storage"` to
`p.def["services"]` would have appended it to the archetype — giving every Shoal
Relay generated afterwards, in every system, for the rest of the session, a bay
nobody authored. `p.def = arch.duplicate(true)`, and `ARCHETYPE INTACT` spawns
fifty stations and then checks the const is unmutated.

The general shape: **a shared const handed out by reference is a global variable
with good manners.** Duplicate at the boundary, and assert the original survives.

## 21. Guarded hulks

A deep wreck used to be a thing you flew to. The only interruption was a rigged
hulk's trap pack, which fires *after* you have committed — so approaching a hulk
was a flight plan, not a decision. Past depth 55 a wreck now carries a standing
post: 20% none, 25% two, 30% three, 25% four, rolled per cell and stable forever.
You can read the post from further out than you can read the rigged beacon, so
the choice to turn around is always available.

Not from the chart edge. The Shoals have to keep teaching that going out is
survivable, so the first wrecks a player ever finds stay unguarded.

### The curve, and the inversion that shaped it

The obvious move — scale guards on `PACK_DIFFICULTY` — is wrong, and not for the
reason it looks. `Hostile.difficulty` scales **both** HP and damage from one dial,
so at the swarm curve's 2.6 a Quiet guard deals `14.0 × 2.6 = 36.4` per shot
against PYX-03's authored sentries at `14.0 × 2.2 = 30.8`. A machine 1100u from
the nearest dock, with no station to run to and no regen window, would hit **18%
harder than anything on the chart.** That inversion was the defect. HP was never
the lethal axis.

So the axes came apart: `difficulty` carries damage, a new `hp_scale` carries HP,
mirroring `SwarmHostile`. **A guard is scary through count, HP and where it is
standing, never through alpha.** `GUARD CURVE` computes the hardest charted
sentry's shot from `SystemDB` rather than restating it, so the swarm curve prints
`36.4 vs 30.8 -> FAIL` instead of merely playing badly.

What falls out is a band-gated decision whose answer is already in the fitting
console: **you can tank a guarded crack in the Shoals and the Drift; from the
Reaches out you clear the post first or you fit Bulwark.**

### Two guns, never four — measured, not assumed

`Derelict._approach` parks the ship at `CRACK_RANGE × 0.78` = 5.07u from the
breach point, on a bearing bounded to **32°** off the hull's outward axis by that
function's own `1.6` weighting. Against `ENGAGE_RANGE 9.0` and posts on a 7.6u
ring, the inner pair at ±26° always engage (2.6–3.8u) and the outer pair at ±100°
only on an oblique approach (7.4u versus 9.8u straight in).

So **the count of guards sets how long the fight is, not how hard the hold is.**
The whole difficulty curve is tuned against that, which is why it is asserted over
8 hull bearings × 3 approach angles rather than derived on paper.

### Determinism: a salted stream, because the shared one is a sequence

`plan_cell`'s RNG is one linear stream. A roll inserted anywhere but the last line
reshuffles every cell in the game — every rigged hulk moves, every nest moves,
every station moves. Guards use `hash("...|guard")`, mirroring `_spring`'s
`"|pack"`, which buys two things: existing determinism is untouched *by
construction*, and "guards roll independently of whether the hulk is rigged"
becomes true structurally rather than statistically.

`SECTOR STABLE` and `TRAP SEEDED` finding the same rigged hulk at the same cell
after the change is the evidence that it worked.

### The tree and the ownership record are different things

A stationary guard fits neither existing pattern. Packs go to `system_root`
because chases move; cell-node parenting would free them cleanly but can strand
`_die()`'s deferred loot spawn. The resolution is the split `Obstacles` already
makes with owner tags: **nodes live in `system_root`, the cell owns them**, and
`_despawn_cell` frees them explicitly alongside the synchronous obstacle clear.

`despawn_radius = 0.0` is deliberate rather than forgotten, and the comment says
so because the next reader will assume otherwise. The leash exists because a swarm
does 7.5 against the ship's 5.75 and cannot be outrun, so a chase needs an end. A
guard does not chase. Setting a leash would create a **141u disarm**: back off past
it, return before the cell cycles at 192u, and the hulk is unguarded.

Guards spawn with the cell rather than arming at 44u like a nest, because §14 says
being jumped must be something you could react to — and a hulk is a thing you fly
toward for ten seconds.

### A cleared post stays cleared, and that is a §11 guard

`Hostile.LOOT_COUNT` is 14 against a swarm's 2, so a four-guard post pays roughly
2,600 — and `PACING_LOOP` budgets **five** sentries for a whole eight-minute loop.
A post that rebuilt every time its cell cycled would be an unbounded farm
reachable by flying 200u out and back. §11's money-printer rule reaching somewhere
ports cannot.

`GUARD CLEARED` prints both halves: killing 1 of 3 and returning gives **3
standing** (the post rebuilt, as it should), killing all and returning gives
**0**. `4/4` would mean it farms forever; `0/0` would mean flying away disarms it.
Both are visibly wrong in the same line.

### The machine does not change; your ability to name it does

Guards take the band tint — vanes blended at **0.45**, not `SwarmHostile`'s 0.62,
because a sentry's silhouette is roughly four times a dart's and at 0.62 a Quiet
guard's hull lands on `Palette.HULL`, the player's own ship colour. The emissive
core takes the band colour outright, since that is the part that swells during the
telegraph.

The designation degrades along the arc `BROADCASTS` already walks — authority,
lapsed authority, a recording nobody maintains, no carrier:

    GSA PICKET — DECOMMISSIONED      still on the register, just abandoned
    PICKET — REGISTRY LAPSED         the register does not reach out here
    UNFLAGGED — NO PATTERN ON FILE   it is not in anybody's book
    UNREADABLE — IT DOES NOT ANSWER  you ask, and nothing comes back

Announced once per post through `_check_encounters`, reusing `ENCOUNTER_TRIGGER`
rather than inventing a hail range — one number for "the expanse has noticed you"
beats two, or the player learns two distances for the same sensation.

### A hostile is never an obstacle in this game

Guards register no collision spheres, and the reason is decisive rather than
stylistic: `Obstacles` has only `remove_owner(tag)` — per-cell, not per-node — so
a dead guard would leave an invisible wall standing exactly where you just blew
something up. `Obstacles.blocked` would also let front guards eat your shots at
the ones behind them. Authored sentries register nothing either.

The tell that this was right: `SECTOR CONTENT` needed no amendment. **The
assertion that would have broken is the one telling you not to do it.**

## 22. Spill, the logbook, and the survey

Three gaps came out of reading the genre — EVE, Elite, Albion, Star Citizen,
Astrox — against what Pyxis already had. **Cartography was in the game's name and
was not a verb.** **The deep had no stakes**, because emergency warp brought the
whole hold home. And **encounters had no decisions**. This section covers the
first two answers; the parley and the rift are the rest of the wave.

### Dying out there costs you what you could not read

Emergency warp past the chart edge now spills the **unread salvage** at the death
site, recoverable this session. Identified components stay aboard — *reading a
thing is also stowing it* — which hands ARCHEOLOGY a third job beside compressing
a hold and unlocking deeper grades, and turns field-reading into a survival act
rather than only an economic one.

Spilling the WHOLE hold was cut: it would make deep death lethal to the
contraband trade §17 rests on. And **nothing spills inside the charted system**,
so the tutorial's promise — *you lose position and tempo, never salvage* — stays
literally true everywhere it was taught.

**Three stock loot-cube behaviours had to be switched off, and every one of them
would have silently deleted the mechanic rather than erroring:**

- the 25s reaper evaporates a spill long before a player who is offline ~2.4s and
  then has to fly back from spawn can reach it;
- `SEEK_ALWAYS_AFTER` homes a cube from *any* distance after 1.3s, so the naive
  spill flies four hundred units to the respawn point and hands itself back;
- collection during warp-out lets the corpse vacuum its own cargo in the 0.64s
  before the position tween fires.

`NO SEEK` is the one worth copying as a technique. Measuring raw displacement
cannot distinguish homing from the spawn scatter every cube already has, so it
measures **closing** instead: a leak eats distance at 16u/s, and scatter cannot
close on a ship 500u away at all. It prints `-2.02u` — the cube drifting *away* —
against a leak's ~32u.

Spill also fixed a live bug nobody had noticed: `_emergency_warp` never cleared
CameraRig's hold, so a finger still down when you died left the rig holding the
wreck, and the next `hold_tick` issued a fresh move order — flying a
just-respawned player back toward whatever killed them.

### The logbook: run state and identity are different things

`ledger` follows the settings/livery shape and **is** cleared by
`reset_to_starter` — a new survey is a new logbook. `ship_name` follows the
livery precedent and is **not**: like the paint, what you called your ship
outlives the run that named it.

Ledger mutators deliberately do not `_queue_save`, following `played_seconds` —
`distance_flown` ticks every frame and a save on each would be a disk write per
frame.

The round-trip test uses **six distinct sentinel values**, because identical ones
would let a swapped key mapping round-trip cleanly and pass.

### Cartography is a verb now

Four sell-only `chart_*` goods, one per band, taken by holding on a **survey
mast** — the fourth implementation of the same duck-typed hold contract Derelict
and ApexWreck carry. Joining the `crackable` group cost zero lines anywhere else
and bought the radar marker for free.

The mast rides the hulk's **stern**, opposite the prow breach beacon. That
separation does two jobs: it gives `_pick` room to tell two verbs on one wreck
apart, and it places the survey stand-off outside the guard ring. **Surveying a
guarded hulk is the sneak play; cracking it is what contests the post.**

Scanners finally scan — `survey_speed` on both marks, which is the first time
"Targeting Scanner" has meant anything sensor-shaped rather than being a
range-and-crit module wearing an instrument's name.

**Two traps the adversarial pass caught before either shipped.**

*The key collision.* `is_salvage()` is literally `has("band")` and
`salvage_for_band()` returns the first good matching one — so a chart good
carrying `band` could shadow a salvage grade in dictionary order, at which point
`spawn_loot`'s 22% regrade would start minting free chart data out of ordinary
combat crates. They use `chart_band`, and `NOT SALVAGE` asserts both directions.

*Weightless data.* Zero interdiction weight reads beautifully as fiction — data
is not cargo — and would have made a pure explorer's weighted hold never cross
`RAID_MIN_HOLD`, leaving the entire interdiction system inert for a whole
playstyle and voiding §17's "no range at which a full hold is safe." At 0.5, the
Forged Manifest's own number, an explorer is **quiet, not invisible**.

### A survey resets on warp, and that is asserted on purpose

`_surveyed` is session-only, like `_sprung`. Persisting it would be a
visited-cells array by another name — the thing §17 refuses because it grows
every minute the player flies. So warping resets surveys, and `SESSION RESET`
asserts that *deliberately*: if anyone ever "fixes" it by saving the dict, the
line turns red and forces the conversation instead of quietly growing saves.

The farming arithmetic says the reset is safe. The near ring inside depth 60
holds an expected 0.64 hulks, so there is no dense cluster near home to reset;
measured survey rates run ~510/min in the Drift against a ~2,000/min combat
baseline, and the limiter is geometry — speed × landmark density — which is
identical whether cells are fresh or re-rolled.

### One more function that was safe only because of its callers

`SurveyMast._complete()` originally had no self-guard: `hold_begin` and
`hold_tick` both check `surveyed`, so the real path was safe. The harness called
it directly and got a second reading. **A function that is safe only because of
who calls it stops being safe the moment something else calls it, and nothing
about the name says so.** It guards itself now — same family as the sentry that
sat at the origin and the assertion that could not fail.

## 23. The parley and the shear

### A raid is a demand now, not just an arrival

Interdictions open with six seconds of standoff — the pack orbits at nine units
and holds fire, because raiders spawned 17u out at 7.5u/s would otherwise be
shooting ~2.3 seconds after the klaxon, before the demand could be read. §14's
rule, applied to the demand itself. One transient button, not a console: §14
excludes consoles from raid starts, so a raid that opened a sheet would deadlock
its own eligibility rule.

**The toll prices off the UNWEIGHTED hold.** The weighted figure is what the
raider ROLL reads (contraband triples your visibility), and the old HUD prompt
printed it labelled "HOLD VALUE" — a cosmetic lie the parley would have turned
into a real one. Weighted tolls would also double-dip the Forged Manifest (fewer
raids AND a smaller toll) and shrink toward zero on a chart-data hold. `TOLL
BASE` prints both figures side by side, so wiring it to the wrong one flips the
line.

**Payment takes cargo hottest-first** — interdiction weight × value, the
raiders taking what they came for. The deliberate asymmetry with
`jettison_to_fit`'s cheapest-first is the point: there the player chooses what
to lose, here the raiders do. Nothing is paid back, nothing transfers — a
departing raider carrying the toll would hand it to whoever shot them, which is
the printer.

**`depart()` sheds every group immediately**, and that one line is the
difference between a feature and a session-bricking bug. `_count_raiders()`
reaching zero is what ends a raid and starts the cooldown; a paid pack that
merely flew away would leave `_raid_active` true forever, and interdictions
would silently stop for the rest of the session — the §18 shape, found in the
adversarial pass before it shipped. Immediate group removal is also what makes
pay-then-kill impossible: a departing raider is not a hostile and drops nothing.

Shooting a raider during the window is also an answer — the whole pack opens up
together, or the player fights one raider while three watch.

### The shear: expiry as escalation

A rift is a windfall with a fuse you can read. A hidden countdown fails the
Cantina standard (a bad bet you cannot see is a con), and content vanishing
under a mid-collection player fails §14 — so the rift dies in three telegraphed
collapse pulses: klaxon, ring, a pack through the tear, a third of the
remaining pot evaporating. Staying longer is more of the pot and more company.

The pot is one band better than the depth deserves, built from existing salvage
grades — no new goods, no new table. Every crate is spill-flagged, because the
feature is impossible on stock cubes: they reap themselves at 25 seconds and
vacuum themselves to the player from any distance after 1.3. A pot that
collects itself is not a pot.

Nothing is saved anywhere. A rift is weather you were present for — a
system_root child that dies with the system, announced on the comms plate, and
never promised to persist the way a market event is. The Cantina's rumor ladder
names a live shear above everything else (the scarcest thing on the ladder, and
the only one with a fuse), and no printer lives there: the shear pays
identically whether or not anyone bought the word.

### Two harness lessons from the same evening

The rift harness failed twice, and neither failure was the rift.

*The pack "didn't spawn."* It spawned and immediately leashed away — the
harness pulsed a rift 290 units from the player, and the spawned pack correctly
gave up on frame one. The leash working looked exactly like the spawn failing.
Assertions about spawns need the player standing where a player would stand.

*A freed reference compares equal to null.* `rift2 != null`, evaluated after
the system rebuild freed it, silently became "did the rift survive the rebuild"
— the exact opposite of the intent. Capture booleans before the teardown they
are meant to survive, and never let freed-equals-null semantics carry an
assertion. `live_rift` is now cleared explicitly in `_load_system` for the same
reason: the subtlety happens to self-heal today, and relying on that is how the
next bug hides.

## 24. The third rewrite of one assertion, and the engine that wakes up

### PHASE INTEGRITY, sampled

This assertion has now been written three times, and each rewrite was the same
lesson arriving again. The first compared peak window damage against phase HP —
a number capped by phase HP, so it could only fail on an exact tie. The second
counted seals against a bar of 2, set from six runs showing 3–10 — and PULSE's
true floor turned out to be 1, so the bar sat inside the noise and failed on a
coin flip. **Both times: a threshold set from too few samples of a distribution
nobody had measured.**

The third version measures the distribution it asserts against. A fit whose
first run engages fewer than 2 seals runs twice more, and the claims are
two-tier, each matched to what it can honestly guarantee: **every run ≥ 1**
(no fit ever fully skips the mechanic — §13's actual catastrophe was "would
never meet a seal") and **every median ≥ 2** (the typical fight engages it
properly). The tail where a burst fit high-rolls one phase is *allowed*, on
purpose: whether that high-roll feels triumphant or degenerate in the hand is a
playtest question, and no threshold can answer it.

The resample branch was exercised in isolation — a green first pass never runs
it, and untested harness code guarding exactly the case that matters is how the
first two versions happened.

### Vent escalation

From the playtest: each successive seal within a phase now vents one more probe
than the last, so an engine that keeps sealing on you is visibly waking up
rather than looping. Two guards, both from measurement rather than taste:
**capped at 4**, because 4–5 probes were measured consuming ~40% of total
damage output and stretching fights past two and a half minutes; and **reset on
phase change**, because a bill that scales with whole-fight length makes slow
fits pay several times what fast fits do — the axis the SURVEY-only armament
decision already rejected once. Stalling one phase gets harder; being a slow
fit does not compound. BREAK OFF resets it for free, since `reset_fight` goes
through `_begin_phase(0)`.

`VENT ESCALATION` asserts the table pure (`p0: 2 3 4 4 …`); `VENT WIRING`
asserts it live, because a pure table passes even if the seal path never reads
it — the self-guard lesson from §22, applied to a test.

## 25. Horizon 1 — making the shipped systems legible

Three player reports and an adversarial pass. The reports were all the same
shape underneath: **systems that work and cannot be seen.**

### The hold, readable anywhere

Cargo could only be inspected at a market counter, so a pilot 900 units out with
a full hold had no way to see what was in it. REFIT is the console open
everywhere except a boss fight and a dock, which makes it the only place this
can live. Each row now names the good, its count, its space cost, its unit
value — and for a component, **its parent category**. Every component has known
its parent since the salvage wave and no screen ever said so; that was the half
of "goods became categories" that never shipped.

The read buttons gained their value and space deltas, which is §20's deferred
item finally landing: reading compresses a hold 2.6–3.7× and physically shrinks
the deep grades, and nothing anywhere said so. `READ COMPRESSION` asserts the
property (worst grade 2.6×) rather than the printout.

**Per-good jettison** completes an ownership triangle the code had already
written two thirds of: `jettison_to_fit` machine-chooses cheapest,
`strip_hottest` raider-chooses hottest, and nothing let the *pilot* choose. It
creates no capability — swapping to a smaller-hold module already dumps
cheapest-first for free — it makes an existing one honest.

### The pilot line

There is deliberately no skill screen ("a skill with its own screen is a skill
that has become bookkeeping"). What was missing was never a tree, it was
**visibility**: ARCHEOLOGY could only be read inside a lab tab, i.e. only after
flying to a station. `GameState.archeology_line()` is now one rule with three
renderers — lab, pause menu, refit strip — and the assertion tests the rule
once rather than the three renderings separately.

### The notification bands

Root cause of the browser-readability report: a wide window pins the logical
canvas to ~820 tall against the 1280 these were authored in, so every vertical
gap is 64% of what it looks like in design space. Three surfaces were already
overlapping *at the design size* — the toast rested **on** the boss bar, the
broadcast plate nearly touched the toast, and the parley button clipped the
crack gauge.

Bands are named constants now, because `BANDS CLEAR` asserts against the same
numbers the layout uses: a reflow that moved a plate without moving the
assertion would be a reflow the assertion could not see. Toast rest 128→142,
font 17→18, hold 1.6→**2.2s** (the longest shipped toast is ~47 characters; at a
transient-read rate of ~19 chars/s, 1.6 was never enough). Broadcast 168→176 and
a point larger on both lines. Parley −216→−252.

**Why the constant-probe assertion stays a constant.** §15's 1.8× chrome check
measures `RoundButton.RADIUS`, and the temptation was to make it measure real
extents. Rejected for the same reason §10 counts its floor in mid-tier modules:
a metric must hold still while content grows, or it reports on layout churn
instead of on the rule. What it structurally *cannot* see is overlap, so that
got its own assertion rather than a rewrite of the old one.

`BANDS CLEAR` checks only pairs that can co-occur. The exempt pair is
parley/tutorial, and the exemption is guarded by **asserting the rule that makes
it exclusive** — if raids ever become possible during the tutorial, the
exemption goes red instead of the overlap going unnoticed.

### Four defects the work surfaced, three of them mine

**`pay_toll` accepted partial payment as settlement**, and was safe only by
coincidence: the cheapest raidable hold is `RAID_MIN_HOLD / max_weight` = 428.6
against a 400 floor — three constants that have never heard of each other,
holding a rule up by 28 credits. Nothing could shrink a hold mid-standoff until
the manifest added a dump button. `TOLL MARGIN` now prints that 28.6 every run.

**Console camping was live**: `interdiction_eligible` excludes open consoles and
nothing gated movement, so a full hold crossed two systems raid-proof behind the
refit sheet. The exclusion is kept for a ship at *rest* — §14's actual claim —
and a moving ship's sheet now closes as the klaxon lands, with the six-second
standoff carrying the reactability the exclusion used to.

**`show_toast` never killed its previous tween**, so the first toast's fade tail
clipped the second — and the pair that fires back-to-back is "READ AS X"
followed by the ARCHEOLOGY tier-up, meaning the announcement §19 says must not
arrive in silence was the one being cut. `show_broadcast` had already fixed this
exact bug in itself; the fix was sitting eight lines away.

**The refit panel re-connected its signals on every window resize** — the
connects had been swept into `_apply_layout`, which is itself wired to
`size_changed`. N resizes meant N+1 rebuilds per signal, and a browser window
gets dragged constantly.

### And three the new assertion caught in its own author's work

Worth recording because they arrived in a row, all in the code written to
*prevent* this class of bug:

1. `centred_probe()` was changed from an array of `[name, centre_x]` pairs to a
   dictionary — so the existing assertion iterated **keys**, indexed `pair[1]`
   into the second character of a name, and reported a 1398px offset. It failed
   loudly, which is the only reason it is a comment and not a bug.
2. The parley button was 4px off centre because `position.x = 0` recentres a
   *container* with grow-BOTH but not a `Button` carrying an explicit
   `custom_minimum_size`. Symmetric offsets state it instead of inferring it.
3. Fixing that introduced the overlap it was meant to remove: writing
   `offset_top = PARLEY_BOTTOM` made −252 the button's **top** edge, while every
   other element in that band treats its y as the **bottom** edge. The button
   grew downward into the crack gauge — 9px, caught immediately.

The through-line, again: **an assertion is only worth what it can see.** These
three were all invisible until the notification surfaces were added to the probe
and given a clearance check, and all three had shipped or nearly shipped in code
written by someone holding the whole design in their head.

## 26. Horizon 2 — the Forge and the Smuggler

Two systems that had been waiting on a verdict. Both landed smaller than
planned, and in both cases the shrinking was the design work.

### The Forge needed no gate, because the gate already existed

The obvious question was which skill unlocks crafting. The answer is none.
Every recipe input is a **component**; components are `no_retail` (unbuyable at
any counter, chart or deep) and exist *only* as archeology reads, band-locked by
`can_read`. You cannot hold a Reliquary Heart without ARCHEOLOGY 3. So the forge
is transitively archeology-gated with **zero new machinery** — and the two
alternatives were both disqualified by rules already written down: a CHEMISTRY
skill is circular by §19's own sentence (craft to level crafting to unlock
crafting), and found-recipes-as-drops would put a die roll inside the one system
whose doctrine is that there is no roll in the conversion.

`RECIPES` asserts the gate directly: every input of every recipe must be a
component *and* must be `no_retail`. If someone ever adds a buyable input, the
forge silently stops being gated and that line goes red.

### Four things no counter will sell you — each weaker than what it is made of

The rule that keeps crafting from eating §19's carried-effects design:
**a fitted effect is deliberately weaker than the carried item it is made from.**

| fitted | carried | and it also costs |
|---|---|---|
| Baffle Array ×0.70 | Forged Manifest ×0.55 | a slot, 4 power, 25 shield |
| Sink Lattice ×0.70 | Thermal Sink ×0.50 | a slot, 4 power, 0.9 speed |
| Survey Array ×1.9 | Cartographic Index ×2.5 | a slot, 5 power, crit and reach |

If any of those inverted, one trip to a bench would permanently obsolete
carrying anything, and "the most valuable haul is also the loudest" would be
deleted by a workbench. `FITTED WEAKER THAN CARRIED` compares the pairs as data.

The dampers also **do not stack** — the better of carried-or-fitted applies.
Multiplying them would put a Quiet-band 2.8s EMP under a second, which is not
"a bet that cost you the beat it bought", it is the hazard switched off.

The price is the fence sale you did not make (~2,200 at a deep haven for one
recipe's inputs), which is why crafting needs no `PACING_LOOP` entry: it can
only *reduce* per-loop earnings. And `price: 0` is not what makes a craftable
unbuyable — `GameState.buy()` **succeeds** at price 0, because `spend_salvage(0)`
returns true. The guarantee is **absence from every stock list**, asserted at
all eleven counters rather than trusted to a number.

`NOT CARGO + NO FREE GOODS` guards something wider than the forge. A price-0
*good* would be dumped first by `jettison_to_fit`'s cheapest-first sort, stashed
first by `_stashable_order`, invisible to `hold_value` and therefore to
`RAID_MIN_HOLD`, and stripped for zero credit by `strip_hottest` — four systems
misreading one zero. The assertion says every good has a positive base price.

### SMUGGLING lost two of its three feeds to arithmetic

The plan proposed XP from tolls paid, interdictions survived, and fence sales.
Two died in the adversarial pass, and both deaths were sums rather than taste:

- **Tolls pay the losing move.** A fight nets ~+700 in drops, running is free,
  and a toll costs 400 or more. A skill levelling on tolls would reward the
  player for choosing worst — and it would grant retroactive XP out of every v10
  ledger, which has been counting `tolls_paid` since the wave shipped.
- **Escaping is a free ninety-second loop** between two systems, which is the
  exact printer shape the leash rule was written against.

What is left is one feed — contraband and stolen goods over a **fence** — and
it competes honestly with ARCHEOLOGY because the good-sets are provably
disjoint. `FEEDS COMPETE` asserts that intersection is empty as *data*, because
§19's warning is that skills all fed by "playing the game" rise together and
become a clock instead of a decision.

A test bug worth keeping: the first version of that assertion asked whether the
**Void** fences contraband. It does not — the Void is contraband's supply end
and sells it over a counter; the **Cantina** is the demand end and fences it.
"A fence" is a specific desk, not a synonym for a shady station.

### Tiers buy time, a choice, and access — never credits

A toll discount is a stat denominated in salvage, and a fence premium would move
`_pacing_trade_yield`'s best legal route and drag the pacing band with it. So:

- **t1** — three more seconds of standoff. Time to read the demand.
- **t2** — the BLUFF: a second parley button, only with a Forged Manifest
  aboard, **odds printed on the button**, and the manifest is **consumed
  whether it works or not**. Without a real stake, bluffing strictly dominates
  paying and stops being a decision. Fail and the standoff ends with PAY
  withdrawn — you showed your hand.
- **t3** — access: deep fences will take anything you carry. Who deals with
  you, not what they pay.

`NO PRICE TIERS` asserts the toll on a given hold is **identical at every
tier** — the single line that keeps this skill out of the economy.

## 27. Horizon 3 — the arc

Two pieces, and both are about a run having a shape you can see afterwards.
The ledger has counted since v10 and the title screen has summarised it since,
but a column of totals is not a memory of an evening.

### The captain's log: ten lines, five sources

A bounded ring of ten one-line entries, appended on **discrete events only** —
a toll paid, a shear closed, a post cleared, a skill tier landed, a band
entered for the first time this run. Bounded because an unbounded one is a
visited-cells array by another name, which is the thing §17 refuses on the
grounds that it grows every minute the player flies.

It is deliberately **not** a seventh `DEFAULT_LEDGER` key. That dict's load-side
merge is `maxi(0, int(...))` — an int contract that turns an array into `0`. It
gets its own field and its own sanitizer, which is the shape `market_events`
already uses: rebuilt element by element on load, `str()`-coerced, length-capped,
and shed from the front to the newest ten. An over-long log is the same invalid
state an over-capacity warehouse is, and it self-corrects the same way rather
than being tolerated.

It does not `_queue_save`, and the reason is stronger than `note_ledger`'s
disk-write one: the log and `deepest_depth` are written by the **same**
`save_game()` dict, so they cannot disagree. Saving the log on its own would let
a line naming THE DRIFT outlive a high-water mark that never reached it — and
the next crossing would then log the band a second time.

### The entry that fired ten times

The band-crossing line reads the run's own high-water mark rather than
`_broadcast_band`, because that field is per-system-visit and resets on warp:
hanging a log line off it would re-log THE DRIFT on every trip out. Using
`deepest_depth` costs no new state, survives a load, and resets with the run.

The first version compared the stored int against the **live float**, and that
double-logs across the one edge that is not a whole number. `band_of` returns
CHARTED only at depth `<= 0`, so from depth 0.1 to 0.9 the mark reads CHARTED
while the ship reads THE SHOALS — the line fires every frame until depth passes
1.0. Ten identical entries, and the run's log evicted by its own first crossing.

Truncating **both** sides fixes it, and the assertion that found it is the one
worth keeping: `TRUNCATED BAND LADDER` tests the property the code actually
leans on — `band_of(int(d))` never falls, never skips a band, and reaches every
one of them — rather than testing the crossing at one sampled depth.

The same lesson landed twice more in miniature. `POST NAMES THE HULK` exists
because a cell is 64u across and a band edge runs straight through some of them,
so `cell_centre` and the wreck genuinely disagree; the harness finds a cell where
they do and asserts the log follows the wreck. And `ONE LINE PER TIER-UP` exists
because `mark_archeology`'s loop can cross three tiers in one call while the
toast the player saw announces only the last — a log emitting one line per tier
would describe an evening that did not happen.

### The pause sheet was already over the line

`SHEET FITS` measures the panel against the viewport at the worst configuration
the settings allow: a 1.6 UI scale on a wide window, which leaves ~512 logical
rows. The root page measured 582 with the log button on it — and 530 without,
which means **it was already overflowing before this horizon touched it**. A
`PanelContainer` centred with grow-BOTH and no clip pushes its heading off the
top and its last button off the bottom simultaneously, and the trigger is a boss
fight and an abandon-confirm being on screen together, which nothing prevents.

The body lives in a `ScrollContainer` now, capped per-page rather than per-window
— three pages of different heights share one sheet, so re-measuring on resize
alone would leave the log page wearing the root page's height. Worst page is 492
against 512.

This is §25's lesson again, third time: **an assertion is only worth what it can
see.** Nothing had ever measured that panel, and the overflow had shipped.

### The hull that forgot

Found by the Grand Commission's adversarial pass, and older than this horizon.
`_spawn_cell` builds three things per expanse cell. The survey mast remembers it
was read (`mast.surveyed = _surveyed.has(key)`). The guard post remembers it was
cleared (`if cfg.is_empty() or _cleared.has(key): return`). **The hull remembered
nothing** — `var d := Derelict.new()`, fresh every time — and streaming despawns
at 192u, so flying out and back rebuilt the same wreck uncracked: full loot, four
archeology XP and a `hulks_cracked` tick, every lap, forever.

`_build_post`'s own comment states the rule the hull was breaking, verbatim: *"a
post that re-armed every time its cell cycled would be an unbounded farm
reachable by flying 200u out and back: §11's money-printer rule."* The post was
guarded and the hull was missed **in the same function**.

It had to be fixed before the Commission, because the Commission gates a
2,900-salvage stage on `hulks_cracked` — and `distance_flown` had already been
excluded as a citation criterion for being farmable in circles. Gating money on a
counter with a tighter farm loop than the one just rejected would have been
incoherent.

The hull now spawns **already breached** rather than re-breaching: `_breach` is an
event with a vortex, a shockwave and a payout in it, and replaying it on a cell
rebuild would be the wrong kind of correct. `_cracked` is session-scoped like its
two neighbours, so a warp resets all three together and §22's geometry argument
keeps covering them as one rule.

`HULK STAYS CRACKED` sits next to `GUARD CLEARED` — the same assertion for the
wreck the post is standing over — and was verified in both directions: green with
the fix, red when the fix was temporarily reverted. It shipped because nothing
looked: `GUARD CLEARED` measures the post, `CARTTEST` measures the mast, and
nothing measured the thing between them.

Writing it cost a round trip to a trap this codebase had already documented.
The first version checked `live_hulk != null` *after* cycling the cell — but
cycling frees the node, and a freed reference compares equal to null, so the
check had silently become "did it survive the rebuild" instead of "did we find
it". `RIFTTEST` hit that exact trap and left a comment naming it. The comment was
read, and the mistake was made anyway — which is the argument for the comment
being an assertion wherever it can be.
