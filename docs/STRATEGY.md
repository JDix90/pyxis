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
- All type sizes, control styling and transition timings come from
  `scripts/ui_kit.gd` — the same rule as Palette, applied to the control voice.
  A `Button.new()` with hand-rolled theme overrides is the defect this prevents:
  it produced three unrelated button idioms, one of which (the pause menu, the
  most-opened screen in the game) had no `StyleBox` at all and rendered in stock
  Godot grey.
- One-shot visual effects go through `scripts/fx.gd`; audio through the `Sfx`
  autoload.
- **Smoothing toward a target uses `scripts/smoothing.gd`, never
  `lerp(a, b, k * delta)`.** That form is not frame-rate independent — one step
  at 1/60 lands somewhere different from two at 1/120, so the camera felt
  different on a 120Hz phone than on the machine it was tuned on — and it
  overshoots and oscillates whenever `k * delta` exceeds 1.0, which a long frame
  produces. `Smoothing.toward` is the analytic solution, `target + (current -
  target) * exp(-rate * delta)`, which subdivides exactly and can never cross the
  target. Asserted by `PYXIS_FEELTEST`.
- Audio is synthesized by `tools/gen_sfx.py` (pure stdlib Python) — original,
  license-free, and regenerable. Tune the numbers and re-run.
- Meshes are kitbashed from primitives in code, which keeps asset cost near zero
  and makes per-module ship variation cheap.
- Audio buses (Master / SFX / Music / MusicCalm) are built in code at boot for
  the same reason: the project stays reproducible from source with no binary
  resources to keep in sync.
- **Accessibility settings are gated at one entry point each, never at the call
  sites.** `CameraRig.shake()` established the rule; `CameraRig.punch_zoom()`
  and `Sfx.haptic()` follow it. There are roughly twenty shake callers and a
  dozen haptic ones, and any of them could forget a setting exists — none of
  them can forget a function that checks for them. `punch_zoom` is the proof
  this matters: it was the one motion effect gated nowhere, so turning screen
  shake off visibly did half its job for as long as it shipped.
- **Reduced motion means the end state immediately, not the same animation
  faster.** An accommodation that still animates is not an accommodation.
  `reduce_motion` also subsumes `shake_enabled()` — someone asking for less
  movement is not asking to keep the camera lurching — but the two settings stay
  separate, because turning shake off is a statement about shake and reading it
  as a statement about every transition in the game would silently reinterpret a
  preference the player already expressed.
- Every major system gets an env-var harness in `main.gd` printing tagged,
  greppable assertion lines (`[station] NO ROUND-TRIP PROFIT ... -> PASS`). Run
  them; do not eyeball the game and call it verified. `tools/run_harness.sh`
  runs the whole sweep and checks the real save is untouched.
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
   you cannot answer with movement is a damage tax, not a mechanic. The Meridian
   deals no damage, so its half of this rule is asserted as *drag* and *escape*
   instead — see §40, which is also the story of that assertion being green for
   the entire life of an armament that did nothing at all.
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

## 28. The Grand Commission

Shipped from `docs/HORIZON-3-COMMISSION.md`. Four stages of the survey authority
acknowledging you — ON FILE, CORROBORATED, COMMENDED, COMMISSIONED — read off
ledger keys the player was already filling, claimed at one desk on the Anchor.

**It is recognition, not a quest.** Every line the Commission prints is a
statement of record — `44 OF 60 SURVEYS ON FILE` — never an instruction. The
grammar enforces itself: stage names are statuses rather than tasks, so a
description written in the imperative clashes audibly with the name directly
above it. `PYXIS_GSATEST`'s `NO IMPERATIVE` checks the copy as data, on the FIRST
word of each description, because English imperatives lead with their verb and a
contains-check would also ban "a first *survey* packet", where the same word is a
noun. A structural rule nothing checks is worth nothing.

**There is no HUD tracker, and there never will be.** `hud.band_controls()` is
the complete inventory of centre-anchored plates and `BANDS CLEAR` measures
against it, so adding a tracker row would have to go through that inventory —
which makes the prohibition mechanically checkable rather than a promise.

### The two fields, and why they are shaped differently

`commission_claimed` is run state and top-level. It was nearly a seventh
`DEFAULT_LEDGER` key; the argument against is that the ledger's load merge is
`maxi(0, int(...))` — a floor with no ceiling — so a hand-edited `99` would reach
`STAGES[99]` and crash *at a dock*, and the SAVETEST write leg assigns a literal
six-key dict, so a seventh key would round-trip untested. It is the shape
`captains_log` already shipped as, for the same reasons.

`commissioned` is persistent, and is a strict monotone derivative of "stage 4 was
ever claimed". It is read by exactly three things: the title screen's registry
line, the accent lock, and the beacons. **The claim counter must never read it,**
or stage 4 becomes unclaimable on every run after the first.

### The accent lock could not live in `set_livery`

`player_ship.gd` reads `Palette.livery_accent(GameState.livery_index("accent"))`
directly and never asks `set_livery` anything, and a hand-edited save never calls
it at all — so a refusal there would guard nothing while also rewriting a
legitimately earned livery every time a save restored one. The lock is at the
**load path** and at the **purchase layer**, and `GSATEST` asserts it against
fixtures at `accent: 8` and `accent: 17`, because `posmod` wraps and 17 is the
same attack wearing a different number.

That also closed the one unbounded int left in `load_game`. The livery indices
had no clamp; `posmod` was doing the containing, which is not protection but a
rename — `accent: 8` silently became amber rather than being corrected.

### The note the arc ends on

COMMISSIONED requires reaching THE QUIET. The beacons answer back once you are
commissioned — for bands 1–3 only. **Band 4 stays silent, and that is deliberate:
the one band the Commission requires you to reach is the one that will never
acknowledge it.** `GUARD_DESIGNATION[4]` is already *"UNREADABLE — IT DOES NOT
ANSWER"*, so the data agrees with the fiction. Do not "finish" that entry.

The commissioned text lives inside `BROADCASTS` as optional
`from_commissioned`/`body_commissioned` keys with a fallback, not as a parallel
array — a second array would be a second bounds contract that could disagree with
the first, and "band 4 is unchanged" would become a size mismatch instead of a
stated property. `BEACON PARITY` asserts that `broadcast_for(band, false)` is
string-identical to what shipped, which is what stops the rewrite quietly editing
the uncommissioned text.

### Two orderings that are load-bearing

`claim_commission` increments **before** it pays. `add_salvage` emits
`salvage_changed`, and `PortPanel._ready` wires that straight back into
`_refresh()` — so a claim that paid first would rebuild the sheet reading the
pre-claim stage and redraw the button it had just honoured.

`_apply_paint` checks eligibility **above** `spend_salvage`. It used to spend
first and apply second, which was harmless only for as long as nothing could be
refused; the locked ninth swatch is exactly the refusal that would have charged
800 for nothing. §12's rule: a hidden bad bet is a con.

### What the harness had to learn to see this

Two assertions in `GSATEST` were written, passed, and were worth nothing until
they were verified in the failing direction:

- `EVERY SERVICE HAS A BUILDER` renders each tab and compares it to the
  outfitter's, because `port_panel`'s `match _tab` catch-all *is* the outfitter —
  a `TAB_LABELS` entry without a matching arm renders a plausible second
  outfitter with no error and no crash. The first version walked `_body`'s
  children without skipping ones queued for deletion; `_refresh` frees the old
  rows and builds the new ones in the same frame, so every fingerprint came out
  unique and the assertion passed on every possible input.
- `STATE BEFORE MONEY` uses a one-element Array as its box. GDScript lambdas
  capture locals **by value**, so the first version's `int` was written inside
  the closure and read from the untouched original — an assertion that could not
  fail.

Both are the §8 rule biting: an assertion is only worth what it can see.

## 29. The score's second axis

The music had one axis — threat — and the game's central fiction is the other
one. Going further out changed the colour of the sky, the radar span, the spawn
tables and the beacon text, and did not change a single thing you could hear.
THE SHOALS and THE REACHES sounded identical.

There are now four stems, not two: `music_calm`, `music_combat`, `music_deep`,
`music_quiet`. All four are **the same eight bars at the same sample count**,
started in the same frame and never stopped, which is the rule the original two
were built on and the reason `gen_sfx.py` fails the build if their lengths
diverge. Depth is a mix position, never a key change — the beds are crossfaded
against each other while all of them are playing, so any harmonic difference
between them would be audible as a lurch every time a band edge was crossed.

**The two axes are orthogonal, and that is the whole design.** Threat picks
between the calm pair and the combat layer; depth picks which *bed* that pair is
heard over. Collapsing them into one "intensity" dial would make deep space
permanently tense and shallow space permanently safe, which is a statement about
the map rather than about what is happening to the player. Being jumped in THE
QUIET has to sound like being jumped, so the combat layer is never attenuated by
depth. `AXES ORTHOGONAL` asserts exactly that: at depth 1200 the threat blend
still swings 0 → 1 while the depth blend holds at 1.

Depth maps **piecewise across the band anchors** (0, 160, 440, 1100), not
linearly across the range. The bands are not evenly spaced, so a linear map would
put three quarters of the audible change inside THE REACHES and leave the first
two bands sounding the same. Piecewise, each band edge lands on an even third:
`[0, 160, 440, 1100, 2000]u` measures `[0.0, 0.33, 0.67, 1.0, 1.0]`.

`music_quiet` is deliberately almost nothing — one sustained low partial, two
sines detuned by 0.0009 so they beat against each other over about eleven
seconds. THE QUIET is the band where the beacons stop answering and the guard
designation is already *"UNREADABLE — IT DOES NOT ANSWER"*. The score agrees with
the fiction rather than scoring over it.

### Two things this pass had to be careful about

**`gen_sfx.py`'s `SOUNDS` dict is append-only**, for the same reason
`DeepSpace.plan_cell`'s roll order is. `random.seed(7)` is set once before the
loop, so the RNG stream is shared across every sound in insertion order — a new
entry anywhere but the end re-rolls the noise in every sound after it, and
`explode.wav`'s sixty crackle grains would come back different. Verified by
md5-ing `explode`, `ambient` and `music_calm` before and after: byte-identical.

**The harness must fly the ship, not call `set_depth`.** `main._process` polls
`deep_depth()` every frame and pushes it at `Music`, so a hand-set target is
overwritten on the next frame and the assertion measures nothing. Flying the ship
out also makes the assertion cover the whole chain — position through
`deep_depth` through the mix — rather than the arithmetic at the end of it. The
first version of `DEPTH AXIS` was green-on-broken-code for precisely this reason.

## 30. Accessibility, and what it cost to do honestly

Four settings shipped in this pass: **haptics**, **reduce motion**, **colour
vision**, and **rebindable controls**. Two rules held the whole way through.

**Gate at one entry point, never at the call sites.** `CameraRig.shake()`
established it; `punch_zoom()` and `Sfx.haptic()` now follow it. There are ~20
shake callers and a dozen haptic ones, and any of them could forget a setting —
none of them can forget a function that checks. `punch_zoom` is the proof: it was
the one motion effect gated nowhere, so "screen shake off" visibly did half its
job for as long as it shipped.

**Reduced motion means the end state immediately.** An accommodation that still
animates is not an accommodation, so `UIKit.reveal_list` and the pause fade take
the branch that skips straight to the finished frame rather than a faster tween.

### Colour vision: the band set was the whole problem

`§17` says colour is the only band tell that reads at a glance on a phone, and
the shipped set — amber, rose, violet, bile green — is close to a worst case.
Under deuteranopia the amber and the bile collapse toward each other and so do
the rose and the violet: four bands become two.

Two independent fixes, because they fail differently.

**Redundancy first.** Every band carries a glyph (`◈ ▲ ● ◆`) on the wayfinding
readout and on every broadcast header. This works in *every* mode including the
default, in greyscale, with the saturation turned down, and on a phone in
sunlight. Remapping only ever helps the modes it was tuned for; a glyph helps
everyone, so it is the one that is always on.

**Remapping second,** through `Palette.band_color()` — the single accessor every
tint now goes through. The consts are never touched and mode 0 returns them
byte-identically, asserted, so the default look cannot drift as a side effect of
the feature existing.

The palettes were **not chosen by eye**, and the first ones that were are the
reason this paragraph exists. `BANDS SEPARATE` simulates each dichromacy and
measures the *minimum pairwise distance between the simulated colours* — the only
measurement that matters, since two colours can be far apart in RGB and land on
top of each other on a confusion line. The hand-picked "colourblind-safe" sets
scored **0.066 / 0.048 / 0.077**, materially *worse* than the shipped set's
0.173. They looked obviously distinct on the author's monitor and were not. The
shipped sets are the best of 60,000 candidates from a constrained grid search and
score **0.307 / 0.317 / 0.333**, with `REMAP IMPROVES` asserting that each one
actually beats the default under the same simulation rather than merely differing
from it.

Constraints on the search worth keeping: a luminance floor, because these are
emissive against a near-black sky and a dark "safe" colour is one nobody can see;
and THE QUIET stays near-white in every mode, because "no colour left at all" is
what that band *is* and recolouring it would win a number and lose the fiction.

Materials are baked at construction, so a mode change calls
`main.rebuild_visuals()`, which goes through the **existing** build paths —
`_load_system` and `DeepSpace.rebuild` — rather than a bespoke retint walk. A
second path that has to know about every material in the game is a second path
that will fall out of date with the first. It only fires on an actual change,
because `apply_settings` runs on every frame of a slider drag.

### Rebinding

`cancel` is deliberately **not** rebindable. It is the way out of every console
and out of the settings page itself, so a player who bound it to a key they could
not reach would have no route back to the screen that would fix it. Two actions
may never share a key — `NO SHARED KEY` asserts the old owner loses it — and no
action may be left with nothing bound, because an unreachable action is worse
than a shared one: nothing reveals it until the moment it is needed.

## 31. The streaming hitch, measured before it was fixed

The 5×5 cell window was built synchronously on every boundary crossing, and the
suspicion was that this hitched. Suspicion is not a reason to add a queue, an
escape hatch and a determinism risk to the one system in this game whose purity
is load-bearing — so `PYXIS_STREAMTEST` measured it first.

It did hitch, and not where expected. **First entry is cheap** — the whole window
at once, near the chart edge, is a few milliseconds, because shallow cells are
mostly empty. **Steady crossings spiked to 44ms**, roughly three dropped frames,
because the tables that make deep cells interesting (`STATION_CHANCE`,
`PACK_CHANCE`) all climb with depth. The expensive case was the one that happens
while the player is flying, with nothing on screen to hide behind.

The split is **what the game needs versus what the eye needs**:

- `_register_cell` — the container node and every collision sphere, all derived
  from `plan_cell`, which is pure arithmetic. Runs synchronously for the whole
  window. The world is solid before it is visible, because flying through a rock
  that has not been dressed yet is a far worse bug than watching one appear.
- `_populate_cell` — meshes, the `Derelict`, its guard post, the `Port`. Queued
  nearest-first and drained under a 5ms budget, with a floor of one cell per
  frame so the queue provably empties even when a single cell exceeds the whole
  budget — which is the exact case that motivated this.

Worst frame after: **10.3ms**, inside a 60Hz frame.

Determinism is untouched. `plan_cell` is still the only source of truth, still
called in the same order; only the moment a mesh appears moves, and nothing reads
a mesh to decide anything. `DEEPTEST`'s 44 assertions pass unmodified, which is
the check that matters — they measure obstacles and cell counts, both of which
stayed synchronous precisely so they would.

### Three things this got wrong first

**Guards went in the cheap half.** They are gameplay, so it seemed right — but a
guard post is several `Hostile` nodes each building a mesh, which is the single
most expensive thing a cell can hold. Putting them in `_register_cell` moved the
cost rather than deferring it. They stand around a hulk the player cannot reach
without crossing another cell, so a frame's delay costs nothing.

**The measurement timed the crossing, not the frame.** With the build amortised a
crossing deliberately spans several frames, so timing the whole crossing counts
the amortisation as if it were the cost — and reported the fix as a regression
from 44ms to 107ms. A hitch is one long frame; that is what the assertion
measures now.

**The equivalence check compared a live window against a fresh one.** `KEEP` is 3
and `WINDOW` is 2, so the live state legitimately carries cells the fresh stream
has not got. Both sides now start from a clean `rebuild()`, and `SAME WORLD
EITHER WAY` confirms the amortised path lands on the same 17 cells and the same
86 obstacles the synchronous one does.

### Do not gate a harness on wall-clock frame time

The first version of `NO HITCH` asserted `worst < 16.67ms`. It passed run alone
and failed inside the full sweep — 10.3ms versus 23.5ms for identical code, on a
build machine doing other work. A stopwatch assertion measures the machine, and a
test that fails for reasons that are not defects trains you to ignore it.

`§8`'s rule applies: assert the rule, not the rendering. The machine-independent
rule is that construction is **deferred** — a crossing leaves cells registered and
undressed for a later frame to drain. `WORK IS DEFERRED` checks the backlog was
non-empty and `QUEUE DRAINS` checks it reaches zero; between them a queue that has
become a no-op cannot pass. Note that "the row always splits across frames" is
*not* the rule and asserting it was also wrong: a cheap row legitimately finishes
inside one frame's budget, and only expensive rows are meant to split.

The timing survives as a reported number with a deliberately loose bound (40ms).
It would still catch the original 44ms spike; it will not fail on a busy box.

## 32. The light responds; the expanse has landmarks

Two things the world was missing, both about the same claim: that the two axes
this game is actually about — how far out you are, and whether something is
hunting you — should be visible in the picture and not only in the numbers.

### One owner for the Environment

`scripts/atmosphere.gd`. `SystemBuilder` writes the system's baseline into it
once at build time and nothing else assigns to the `Environment` after that. Two
writers and the last one per frame wins, which is how a lighting bug that was
"fixed" comes back six months later wearing different clothes.

Everything is expressed as a **multiple of the system's own values**, so a system
authored dim stays dim. Depth pulls the sky toward `DEEP_COLD` (not toward black
— black reads as the renderer stopping rather than as somewhere), takes ambient
and the sun down with it, and drops glow to 42% by THE QUIET. Threat is a **lift,
not a tint**: deep space is already a colour statement and a red wash on top
would fight the band gradient, so a contact raises the bloom and pulls ambient
slightly toward `THREAT`, which reads as the room getting harder. The two
compose — being jumped in THE QUIET still brightens the room, from a much lower
floor.

Depth uses `DeepSpace.BAND_EDGES`, the same anchors the score uses, so the sky
and the mix change at the same places rather than a beat apart. Threat rises fast
and falls slow, matching the music's asymmetry for the same reason: a fight
starts on one frame and ends raggedly over several. Both are fed from a single
`_threat_near_player()` in `main`, so the lighting and the score can never
disagree about whether you are in a fight.

### Landmarks: randomness at two scales

The expanse was uniform noise — every cell rolled the same four things from the
same tables, so flying out felt like more of the same rather than like going
somewhere. There is now one deliberate object per **supercell** of 4×4 cells,
roughly every 256 units, themed by band.

That is what "designed rather than random" means here: not less randomness, but
randomness at two scales with the coarse one carrying meaning. A single scale is
noise however you tune it.

Each band gets a **different silhouette**, not the same shape in a different
colour — colour already tells you the band, and a second tell that is also colour
tells you nothing new. Read outward they are one story: a shattered survey pylon
the authority built and stopped maintaining; the frame of a colony with two lit
windows; a monolith nobody built, scarred where a nest grew on it; and a GSA
boundary marker with its lamps stripped out. That last one is the only landmark
that does not emit — you see it because it occludes stars. THE QUIET is the band
whose beacons do not answer, and a marker with a working light would contradict
that.

They are **scenery**: no loot, no collision, nothing to hold on. The expanse
already has four things to do in it; what it lacked was somewhere to *be*, and an
object that pays out stops being a landmark and becomes another errand.

The roll is **appended** to `plan_cell` after every existing one, on its own
salted stream — `§17`'s rule, the same one `gen_sfx.py`'s `SOUNDS` dict follows.
`DEEPTEST`'s 44 assertions pass unmodified, which is the proof it held.

### Three assertions that passed while measuring nothing

Worth recording together, because they are the same mistake in three costumes and
`§8`'s rule caught all three:

- `THREAT LIGHTING` called `air.set_threat(1.0)` directly. `main` polls the threat
  every frame and overwrites it, so the test measured a 0.004 wobble and called
  it a lift. It now spawns an actual hostile, which also covers the poll and the
  radius test.
- Its *baseline* was then wrong too: PYX-01 has sentries inside `THREAT_RADIUS`,
  so "calm" glow was already lifted and was being compared against itself. The
  field is cleared first, and `calm field=true` is now part of the assertion.
- And the waves refilled it anyway, so `_wave_timer` has to be pinned — the same
  two lines `MUSICTEST` already needed, for the same reason.

The pattern: **a harness that sets a value the game also sets every frame is
measuring the game's value, not its own.** Drive the system, do not poke it.

## 33. A harness may not read the player's save either

`lock_saving()` has said since Horizon 1 that a harness must never *write* the
player's save. The other half was missing, and it cost three false failures the
first time anyone actually played this build on the machine that runs the sweep.

`GameState._ready()` loads `user://save.json` before `Main` exists. Every
harness therefore started from one person's savegame. Three assertions went red
on correct code:

- **`SURVEY SPEED`** equips a scanner to prove the module's stat is live. The
  save's fit already drew all 12 of a Mk I reactor's power, so `equip` refused
  the scanner, the assertion printed the same number twice, and it reported a
  dead stat that was perfectly alive.
- **`DOCK GRANTS`** needs a deep station in the streaming window. The expanse is
  a pure function of the system id, and the save was parked in PYX-03 rather
  than the PYX-01 the assertion was authored against, so it rolled a different
  world.
- **`FITTED EFFECT LIVE`** asserts that equipping a craftable does not move the
  hold. The save had a Cargo Bay in the slot under test, so equipping over it
  dropped the hold from 50 to 24 — a real change, of a thing the assertion
  exists to prove never changes.

None of these is a bug in the game. All three are a harness with no baseline.

**The fix is one gate, not thirty.** `Main._ready()` checks `harness_running()`
— any name in `HARNESS_VARS`, which is the dispatch's own list of `PYXIS_*`
variables minus the capture modes — and calls `reset_to_starter()` before the
first `_load_system`. Three harnesses (`PACINGTEST`, `SAVETEST`, and now
`CARTTEST`) already did this by hand; the other twenty-seven did not, and had
simply never been run against a divergent save.

It is deliberately in `Main` and not in `GameState`. An autoload that behaved
differently under a test flag would put a second code path through the one
object every assertion trusts; `Main` resets it the same way starting a new game
does, using the same function.

**The general rule, and it is the sharper half of §8's doctrine:** an assertion
is only worth what it can see, *and only as much as it controls.* A harness that
has never been told what to assume will quietly assume whatever the last session
left behind — and it will keep passing until the day someone plays the game.

Pinning immediately exposed a second one. `ABANDON KEEPS RUN` asserted
`salvage > 0` while never paying the player anything, so what it actually asked
was "did a wave happen to spawn and a kill happen to land in the preceding half
second." It read 90 on one run and 0 on the next with no code change between
them, and had only ever looked stable because it was reading a save with money
in it. It now grants a known amount and compares it across the call, which is
the invariant it always meant: abandoning preserves the run.

## 34. Mining — stage 1, the verb

Ore on the flank of a rock. Fly to it, hold on it, cut it out. **Metals and
Minerals**, four each, priced 60–240 and every one under Intact Relics (260) —
this is bulk industry, not treasure. The deep pays a prospector in volume and
density, never in one fat unit.

The user's four decisions frame the whole thing: mining is an **alternative
loop** rather than extra income (`PACING_LOOP` sits at 96% of its ceiling, so
there is no room for a seventh earner); **one step**, so a seam yields the
finished tradeable and there is no refinery; seams in **both** charted and
expanse weighted outward; and mined rocks stay mined.

### Four traps this had to walk around, all of them already documented

**The marker key is `ore`, never `band`.** `is_salvage()` is literally
`has("band")` and `salvage_for_band()` returns the first dict-order match, so an
ore carrying `band` would shadow a salvage grade — and `Main.spawn_loot`'s 22%
regrade would start minting ore out of ordinary combat crates, *feeding
ARCHEOLOGY off rock*. It is a String rather than an int so the two cannot be
confused by a reader or by a `get()` with the wrong default.

**Mining never calls `spawn_loot`.** Same reason, from the other direction: that
funnel is where the regrade lives, so routing a seam through it would make
cutting rock level a reading skill.

**The seam roll is appended, on its own salted stream.** `plan_cell`'s rolls are
one linear sequence and a draw inserted anywhere but the last line reshuffles
every cell in the game. `WORLD FINGERPRINT` hashes every rock, hulk, nest and
station across 121 cells against a constant **recorded before seams existed** —
a hash taken afterwards would agree with whatever it was given.

**A seam is a separate node standing 0.6u off the rock's collision sphere, not a
flag on the rock.** A QUIET boulder's obstacle radius reaches 6.56 against a
6.0 hold range, so a seam measured from the rock's centre would push the ship
outside its own reach and could never be worked at all. `system_builder.gd:288`
records this exact bug shipping once already.

### Its own group, and the order matters

Seams join `"mineable"`, not `"crackable"`, for two measured reasons.
`MAX_MARKERS` is 12 and a Drift window holds about ten seams, so in `crackable`
they would routinely evict the hulk and the survey mast — the two things the trip
was for. And `_pick` is screen-space with no raycast, with no keep-out between
rocks and hulks, so both in one group makes a contested tap a coin flip between
cutting and breaching. `_try_begin_hold` checks **crackable first**: a hulk is
one-time, a rock is one of many.

### All or nothing, which the survey mast is not

`load_cargo` is **partial**. `SurveyMast._complete()` calls it and reverts only
when it took zero, so a mast worked with one space free takes 1 of its 2 units
and marks itself surveyed — half the reading destroyed, silently. With a
five-unit seam that would be five times worse. `MineableSeam` checks
`can_load()` first, which is the mast's own stated intent ("the trip is not
wasted, only deferred") actually implemented. Fixing the mast is a companion
one-liner and belongs with stage 3.

### The anti-farm defence is arithmetic, not a save

`_mined` is session state, matching `_cracked` and `_surveyed`, because §17
refuses a persistent visited-cells array and rocks are the most numerous thing
out there. What makes a warp-reset safe is the gradient: mean seam value runs
**195 / 425 / 530 / 981** across the bands, and band 1 — the only band reachable
without flying back out — measures **329 credits a minute against a combat
baseline of about 2,000**. Warp-farming the Shoals is six times worse than just
fighting. `WARP FARM` asserts the number so that anyone who later raises
`SEAM_CHANCE[1]` sees it collapse. (Stage 2 gave the game a module that adds a
unit to every cut, so that assertion now prices the *fitted* farm rather than the
starter one — see §35.)

Band 1 is a thin *shell*, not a region — depth 0–160 past a chart edge of 40 is
a radius of 40–200, roughly `|c| <= 3` at `CELL 64`. The first version of that
assertion scanned outward from the origin, found no band-1 cells at all, and
reported a farm rate of zero.

### Three assertions that were worth nothing until they were made to fail

- `PICK PRECEDENCE` called `_pick("crackable")` and asserted it returned the
  hulk — true regardless of which group `_try_begin_hold` consults first. It now
  drives the real entry point and reads what latched. Then it *still* proved
  nothing, twice: the probes were 123 screen pixels apart (outside `PICK_PX 60`,
  so never contested), and the seam was being placed from a `breach_point` that
  `Derelict._process` had not refreshed yet — `await process_frame` does not
  guarantee a given node's `_process` has run — which put it 400 units away.
  It derives the beacon position from `BEACON_LOCAL` now.
- `WORLD FINGERPRINT` was first injected with a draw *after* the seam roll,
  which changes nothing downstream. The hazard is a draw *before* the other
  rolls, and that is what it is verified against.
- `HOLD FULL DEFERS` was the one that worked first time, and it is the one that
  found the mast's latent partial-load bug.

## 35. Mining — stages 2 and 3, the fit and the profile

Stage 1 gave the deep a verb. These two give it a **fit worth choosing** and a
**profile that proves it is a route rather than a raise**. Neither touches the
save.

### The fit: two tools, two axes

`util_cutter` (Cutting Head, 3 power, 5,600) buys **speed** — `mining_rate` 0.35,
paid for in turn rate. `util_assay` (Assay Rig, 4 power, 15,200) buys **yield** —
a flat `+1` unit on every cut, paid for in shield. Two axes rather than one
bigger number, so a prospector with a slot spare has a question to answer instead
of a strictly-better module to buy.

`ore_yield` is **flat, not a multiplier**, and that is the anti-farm gradient
talking: one more unit of band-1 ore is 65 credits and one more of band-4 is 196.
A multiplier rounded to whole units would have paid the shallow band best in
percentage terms — exactly backwards for a system whose expanse resets on a warp.

Everything downstream of a cut reads one function, `MineableSeam.cut_units()`:
the prompt, the room check, the load and the toast. Four call sites each doing
their own arithmetic is how a player gets promised a number the hold never
receives, so `THE FIT REACHES THE VERB` checks that what lands equals what was
promised, not merely that the stat is non-zero.

### Three modules, two slots

No new slot family, and that is the constraint. `rig_prospector`, `util_cutter`
and `util_assay` are three utility modules against **two** utility slots, so the
complete prospector can never exist — you pick two. The heaviest legal pair over
the best drive and the best core draws **16 of a Mk III's 18**, leaving 2 against
a Lance Array's 4: a ship built to mine gives up the mid-tier weapon the pacing
band is denominated in. `MINING COSTS A MOUNT` asserts that rather than trusting
it, and goes red if either tool is cheapened.

### A module the console cannot draw is a module nobody buys

Both tools were finished, correct at the rock face, and **unsellable**, and it
took building them to see why. `ModuleDB.summary_lines()` is a hardcoded
seven-row list — DPS, REACH, SPEED, HANDLING, SHIELD, SALVAGE, HOLD — and it is
the whole of what the refit console shows. Neither `mining_rate` nor `ore_yield`
was on it. So the Cutting Head rendered as **HANDLING −1.6 and nothing else**,
and the Assay Rig as **SHIELD −30 and nothing else**: two purchases that read as
pure downside at 5,600 and 15,200 credits.

The fitting contract at the top of `module_db.gd` already promised the opposite —
"legible, few stats, all surfaced as deltas in the refit console" — so this was a
contract violation rather than a missing feature. A `CUT` / `ORE` pair now appears
**conditionally**, only when a mining stat is non-zero, because `_stat_row` is a
plain `HBoxContainer` on a 720-wide portrait phone rather than a wrapping one and
seven cells is already tight. The pair appears and disappears together so that
comparing the two tools never shifts the other columns.

`THE CONSOLE DRAWS THE UPSIDE` asserts it, and checks that the row **exists**
rather than that the summary merely **changed** — `util_cutter`'s turn-rate
penalty already moves HANDLING, so a difference check would have passed with the
upside still invisible.

The same defect is still live elsewhere and is deliberately left for its own
change: `util_repair` (5,200) and `util_repair_2` (13,500) carry `shield_regen`
as their *only* stat, and `shield_regen` is not on the list either — so fitting
either changes not one number the player can see.

### The contract, priced against the band rather than for flavour

`haul_ore` delivers 6 Ferrite Ingots to the Cinderworks for **1,650**. Ferrite
because band 1 is the only band a first warp reaches and ferrite is the metal it
yields — a consignment the new prospector cannot fill would teach the wrong thing
about the verb it advertises.

The reward is the interesting number. `_pacing_contract_yield()` measures the
**mean** reward of everything PYX-01 offers, so a ninth contract is a lever on
the whole economy: at 1,650 the mean moves 1,667.5 → 1,665.6 and `EARNED` falls
by two credits. A round 2,000 would have raised it by 37.

### The profile: a second weighting, never a second measurement

`PACING_PROSPECT` is `4 swarm, 2 sentry, 8 seams, 1 trade, 1 contract, 1 survey`
— a second **authored weighting folded over the same measured yields**.
`PACING_LOOP` is untouched and carries no `seam` term at all. Both profiles run
through one `_pacing_earned(profile, yields)` against one `yields` dictionary,
and that is the whole design: two profiles sharing the measurements cannot drift
apart by valuing an activity differently, so a parity failure always means the
*routes* diverged and never that the instrument did.

Measured: prospector **12,016** against a steady (no-derelict) **11,804**, 1.8%
apart inside a 20% tolerance, at 2.07 × `lance_1` inside `[0.60, 3.00]`. The
tuning knob is the weight `"seam": 8`, never an ore price — a price moves the
market, the contract, the interdiction weight and four port inventories at once.

`ROUTE PARITY` measures against **steady, not best-case**, and that choice is the
assertion. A derelict is a once-per-system windfall with three in the whole game
and the prospector's route has none, so comparing against the loop that includes
one would credit mining with a hull it never cracked.

### What the ceiling actually looks like

The plan was written against a recorded `EARNED` of 16,418 = 2.831 × `lance_1`.
The real figure is **16,764–17,001, or 2.88–2.93 × `lance_1`**, measured across
five runs: the standard loop sits at roughly **97% of its ceiling**, not 94%,
with about ±0.9% of run-to-run noise coming from the derelict's spill. That is on
the order of **400 credits of headroom, not 980** — and stage 4 should re-measure
before authoring a single charted seam rather than trusting either figure.

Which is why `MINING IS A ROUTE, NOT A RAISE` is its own assertion. Adding a mere
`"seam": 4` to `PACING_LOOP` — the obvious knob, and the one a later stage will
reach for — puts `MIDTIER` at **3.18** and breaks the ceiling outright. Verified
by doing it.

### The three harness holes stage 1 exposed

**`EVERY NAMED BUYER BUYS` swept 10 goods and should have swept 20.** It filtered
on `is_component`, but `trade_only_at` is not a component field — it is a
restriction field that contraband, stolen goods and all eight ores carry too. Ore
shipped naming four ports as its only buyers, and the one assertion whose whole
job is to check that claim skipped every one of them. Verified in both
directions: with an ore pointed at a port that has no counter for it, the widened
filter fails and the old one passes.

**`NO ROUND-TRIP PROFIT` had only ever run at `smuggling = 0`.**
`Market.fences()` carries a tier-3 clause returning true for any deep port with a
fence service, and `can_buy` is `not fences(...)`, so at tier 3 the buy side
*closes* at the deep havens: 107 pairs swept against tier 0's 130. Both counts
are printed, because tier 3 legitimately checks fewer pairs and a reader has to
see that rather than assume one sweep ran twice. Prices themselves do not move
with the tier — `sell_price` applies `fence_bonus`, keyed on the port's own
`fence_goods` list — which is now a property proved rather than assumed.

**The survey mast's partial load, fixed.** §34 called this a companion one-liner.
It was subtler than recorded: the *full* hold was always handled, because the mast
reverted when `load_cargo` took zero. The **nearly full** hold was not — one space
free took 1 of a 2-unit reading and toasted "SURVEY LOGGED x1". That is the harder
half to notice and the one a working hold is actually in. The mast now asks
`can_load()` before spending itself, exactly as `MineableSeam` always did.

### And one number that was wrong in the source

`deep_space.gd` said band 1 works out at "roughly 195 credits a minute". 195 is
the band-1 mean **seam value** from `SEAM_YIELDS`; the rate is 329. Two figures
transcribed into one sentence, and the doc had it right while the code did not.
`WARP FARM` now also prices the **fitted** farm: the Assay Rig's flat extra unit
is precisely what someone farming would be carrying, so measuring the starter fit
was measuring a ship no farmer would fly.

### Every new assertion made to fail first

Seven assertions were added across the two stages, and each was verified red by
reintroducing the specific defect it names — the house rule from §34, which
exists because five of stage 1's assertions shipped green and proved nothing.

- `THE FIT REACHES THE VERB` — twice. Once with `cut_units()` ignoring
  `ore_yield` (3 units → 3), and once with `_complete()` loading `units` while
  the prompt promised `cut_units()` ("3 units → 4, hold took 3"). The second is
  the one worth having: it is the four call sites disagreeing, not the stat
  failing.
- `MINING COSTS A MOUNT` — Assay Rig dropped to 2 power, leaving 4 spare against
  a Lance Array's 4, which is no longer "cannot afford".
- `THE MAST DEFERS TOO` — the guard weakened from `can_load(good, YIELD_UNITS)`
  to `can_load(good, 1)`, which is precisely the old partial-load behaviour:
  "took 1, mast still workable=false".
- `EVERY NAMED BUYER BUYS` — verified in **both** directions, which is the only
  way a widening can be proved. An ore was pointed at the Cantina, which has no
  counter for it: the widened filter fails over 20 goods and the old
  `is_component` filter passes over 10, with the same bug present.
- `NO ROUND-TRIP PROFIT` — market spreads inverted; the failure names the tier
  it was found at ("smuggling 3: deep_yard ore_iridium x25"), which proves the
  tier-3 pass actually reaches the price comparison rather than merely running.
- `ROUTE PARITY` and `PROSPECT MIDTIER` — the seam weight taken to 30 (3.70 ×
  `lance_1`, 78% apart) and to 0 (27.6% apart). Both directions, because a
  parity check that only fails upward would accept a seam yield of nothing.
- `MINING IS A ROUTE, NOT A RAISE` — `"seam": 4` added to `PACING_LOOP`, which
  put `MIDTIER` at 3.18 and broke the ceiling. This is the assertion's whole
  argument, demonstrated.
- `THE CONSOLE DRAWS THE UPSIDE` — the conditional rows disabled, and the
  console went back to rendering the Assay Rig as a shield penalty.

## 36. Mining — stage 4, the skill

The verb, the fit and the profile were stages 1–3. This is the ladder that sits
on top of them, and the first save bump since the Commission: **`SAVE_VERSION`
14**.

### What the tiers buy, and what they deliberately do not

`MINING_TIERS [0, 18, 50, 110]`, fed by **seams cut, weighted by band** — never
by ore *sold*. A sale is a dock visit, which a smuggler makes anyway; if selling
ore paid, a trade run would level a mining skill and §19's clock warning lands.
`MINING PAYS ON SEAMS, NOT SALES` drives a real sale through `PortPanel._sell`
and a real cut through `_complete()`, and checks only the second one moves.

- **t1 — information.** The radar marker takes the ore's colour. Below the tier
  every seam is the same grey arrow, so a 60-credit Silicate and a 240-credit
  Iridium are indistinguishable until you fly inside `MINE_RANGE`. This turns
  "fly to every arrow and read it" into "choose which rock is worth the trip".
- **t2 — a choice.** Past halfway, letting go takes **half the cut and spends the
  seam**. Paying the whole seam for half the ore is what makes leaving early a
  decision rather than an optimisation; a free partial would just be a slower
  full cut.
- **t3 — access.** Band-4 seams open. A locked seam stays visible and stays on
  the radar, and its prompt names the tier it wants — a thing you can see and
  cannot have is a goal, a thing that is absent is nothing.

None of them buys credits or yield. `util_assay` already owns the yield axis, and
a tier that moved a priced number would be a second earner under a loop already
at 97% of its ceiling. `TIERS BUY NO CREDITS` compares a seam's yield at tier 0
and at the cap, at every band.

**110 tops out higher than archeology's 78 and smuggling's 84, and that is not an
inconsistency** — the three are earned in different units, so comparing their top
values is a category error. What matters is sessions-to-max, and band weighting
sets it: roughly fourteen sessions working the Shoals, three and a half working
the Quiet. The shallow grind being slow is the anti-farm gradient said again in
the skill.

### Band 0, and why charted seams persist

Charted space had no ore table at all. It has one now — Silicate and Ferrite at
**2 units**, ~130 a seam — so the gradient runs **130 / 195 / 425 / 530 / 981**
and `RICHER OUTWARD` starts at band 0 rather than band 1. Band 0 is the poorest
of all because it is the only band that never resets.

One seam per authored asteroid: **11 in the entire game** (pyx01 5, pyx02 3,
pyx03 3). They are *placed* by `SystemBuilder` from authored data rather than
rolled, because they persist and a persistent thing needs a stable identity. The
key is the system id and the rock's **array index**, which means reordering an
`asteroids` array silently rekeys a player's cut seams — said out loud at the
array and in `game_state.gd`.

The split is the design: charted is **persistent** (eleven finite rocks
respawning on every warp is the deep-hulk farm this repo already shipped once),
expanse is **session** (safe because the band gradient makes shallow farming pay
badly). `CHARTED PERSISTS, EXPANSE RESETS` drives both kinds through
`_complete()` and rebuilds.

### The gate the old plan set could not be executed

The staged plan said: *run PACINGTEST, and if headroom is under ~1.5%, cut
charted seams.* Stage 3 forbade a `seam` term in `PACING_LOOP` and
`MINING IS A ROUTE, NOT A RAISE` asserts its absence — so **charted seams cannot
move `MIDTIER` at all**, and the gate measured something unconnected to the thing
it gated. PACINGTEST is structurally blind to them.

They are a one-time windfall, structurally a small derelict, so they are measured
against the windfall the game already has: `CHARTED SEAMS ARE A WINDFALL` totals
all eleven and holds them under **15%** of the three-derelict budget. They sit at
**9%** (1,430 against 15,600). The bound is 15 and not 25 deliberately — a bound
loose enough to tolerate a doubling would sit green through exactly the change it
exists to catch, which the red pass confirmed by doubling band 0's units.

### There was no migration to write

`load_game()` has been field-defaulting since v1 and there is still no
`migrate_*()` function anywhere. A v13 save arrives at mining 0 with nothing cut
because `data.get` says so. The work was the version constant, `seams_cut`
save/load, a `SAVETEST=migrate13` fixture leg, and adding `migrate13` to
`run_harness.sh`'s `SAVE_MODES` **in both places it hardcodes that list**.

`seams_cut` is validated against the generator the way `_load_warehouse` is: a
raw dictionary keyed by strings the player never types must not survive naming a
system or a rock that is not there.

### Two assertions that did not test what they claimed

Both were caught by the red pass, and both are the reason it is mandatory.

**`CHARTED PERSISTS, EXPANSE RESETS` poked the two stores directly.** It called
`GameState.note_seam_cut()` and `deep_space.note_mined()` and then checked what
survived a rebuild — which proves only that a Dictionary remembers things. With
the entire routing in `_record_cut()` deleted it stayed green. It drives both
kinds through `_complete()` now.

**`CORE SAMPLE CANNOT OUT-YIELD A CUT` inherited state from the assertion above
it.** `TIERS BUY NO CREDITS` leaves the ladder at its cap, and the sample check
read that instead of pinning its own — so a red patch that should have failed it
passed, because the inherited tier inflated `cut_units()` enough to hide the bug.
It pins `mining = 0` now. An assertion that reads state a previous one happened
to leave behind is measuring the order of the file.

A third, smaller finding: `_load_seams_cut`'s system-exists filter is **redundant**
— the bounds check already rejects an unknown system, because `get_system()`
returns `{}` and an empty asteroids array fails it. That is an implementation
detail of `SystemDB` rather than a promise, so the explicit test stays, and the
comment now says which filter has the teeth.

### The pause sheet, measured rather than feared

A third skill line was predicted to break `SHEET FITS`. It does not, and the
measurement is worth keeping: at a 1.6 UI scale the root page content is **546
rows against a 456 cap**, going to **572** with the third line, while the panel
reads **492 of 512 either way** because `_clamp_height()` pins it. A line costs
26 rows of scroll and the assertion cannot see the difference.

Which is the real finding: **`SHEET FITS` is structurally incapable of failing on
content growth.** It measures `_panel.size.y`, and the clamp guarantees that
value. It proves the clamp works; it cannot prove the page is usable, and the
root page has been ~90 rows past its cap since before this horizon with the
assertion silent. §25's rule landing on the assertion written to enforce §25.
Restoring its teeth means asserting something the clamp does not guarantee — that
the last action button is reachable without scrolling — which is a different
assertion, and its own change.

### Known, small, and deliberately not fixed here

`MineableSeam._update_prompt()` memoises on `_in_range_last` alone, so a prompt
written while a seam is locked does not refresh if the tier changes while the
ship sits inside `MINE_RANGE` — you would read "SEAM TOO DEEP" until you moved a
unit and came back. It is the same memo the `cut_units()` figure already lives
with when a refit changes the fit mid-approach, so it is consistent rather than
new, it self-corrects on any movement, and reaching it requires levelling on some
*other* seam while parked on a band-4 one. Left alone so the sweep that signed
off this stage describes the code that shipped; worth a `_locked_last` companion
next time this file is open.

## 37. The manual, in the game rather than beside it

There is an illustrated web version of the pilot's manual, and it is the better
artefact to read — but it is a private page on a service, and a game that sends a
new player to a browser to learn its verbs has not taught them anything. So the
manual ships **inside the build**: `scripts/manual_screen.gd`, reachable from the
title screen and from the pause sheet, working offline, in the game's own voice.

### Its own node, not a fourth pause page

The pause menu has a page router and would have taken a `manual` page in about
ten lines. It is not one, because **the title screen has no page system at all**
and a new player is precisely the person who needs this before they have ever
pressed NEW SURVEY. One node with two doors beats two copies that drift.

### It never touches `get_tree().paused`

The load-bearing property, and the reason it is stated in the file's header as
well as asserted. The manual opens over the title screen (running) and over the
pause sheet (already stopped). A node that paused on open would freeze the title;
one that unpaused on close would resume the game out from under the pause menu
that opened it. Whoever opened it owns the pause state — this node only draws.
`NEVER TOUCHES PAUSE` checks it from *both* states, because a bug that only
appears in one of them is exactly what a single-state check misses.

### Escape needed an explicit guard, not a bigger layer number

`_unhandled_input` is delivered in **tree order**. A higher CanvasLayer buys
drawing priority and no input priority whatsoever, and both the manual and the
pause menu are `PROCESS_MODE_ALWAYS`, so both are live at once. Without a guard,
Escape inside the manual fell through to the sheet underneath and resumed the
game instead of backing out one page. `pause_menu._unhandled_input` now returns
early while the manual is open, and the manual is first on `CameraRig._cancel`'s
ladder — it is the only console that can be open on top of another.

### What it says is derived, not retyped

Every number on these pages is read from the data that defines it: the reactor
from `ModuleDB`, the slot list from `SLOT_NAMES` and `STARTER_FIT`, the band
names and glyphs from `DeepSpace` and `Palette`, the ore count from
`CommodityDB`, the tier count from `GameState`. A manual that hardcodes "12
power" lies the first time somebody retunes `REACTOR_TIERS`, and a lying manual
is worse than no manual.

`THE NUMBERS ARE DERIVED` is honest about its reach in its own comment: it is a
**drift detector, not a hardcode detector**. It cannot tell a derived 12 from a
typed 12 today — both render the same glyphs — but the day the data moves, a
typed number stops agreeing and it goes red. That is the failure that costs a
player something.

`THE LEGEND FOLLOWS THE PALETTE` is the one that proves a derivation outright,
because colour-vision mode is the single input here that *can* change at runtime:
flip it, and all five band swatches must recolour. It matters on its own terms
too — a player on a colour-vision mode sees a recoloured band on the HUD, and a
manual still printing the default palette teaches them the wrong colour for the
thing in front of them.

### The assertion that was toothless, and the bug it found once it wasn't

`THE CLAMP HOLDS` was first written the obvious way, `panel <= viewport` — which
is exactly the shape §36 records `SHEET FITS` being structurally incapable of
failing in, since the clamp guarantees the value being measured. Here it was
worse: with `_clamp_height()` deleted outright the sheet **collapsed to 32 rows**
and the check still passed, because a collapsed sheet fits a viewport
beautifully. It could not fail in either direction.

Rewritten to state what the clamp is *for* — every page's scroll viewport must be
exactly `min(content, room)`, so too tall fails and so does collapsed — it went
red immediately on real code, and the bug it found was real:

**`queue_free()` is deferred, so `_refresh()` was measuring two pages at once.**
The outgoing page's children were still parented to `_body` while the incoming
page's were being added, so `get_combined_minimum_size()` summed both and sized
the sheet for a page that no longer existed — the Deep page clamped to 456 rows
against a true 435. The fix is `remove_child()` paired with `queue_free()`.

"`queue_free`d children still appear in `get_children()` that same frame" was
already written down in this repo's harness notes. This is that trap in ordinary
UI code rather than in a test, and it was found by refusing to ship a second
assertion shaped like the one §36 had just finished complaining about.

## 38. The Hunt — stage 1, the seed and the gate

The playtest verdict that opened this horizon: the loop works, but the *soul* of
the game is flying out past the chart and getting home again. The apex engines
were nowhere near that. They sat at ~60% of the charted radius, permanently on
the radar, and **gated nothing** — breaching the derelict opened the next system
about twenty minutes into a run, and the engine was an optional windfall you
could ignore forever.

This horizon makes the engine the door. Stage 1 builds the door; stage 2 moves it
out into the deep where it belongs.

### Two doors, not one

    breached    ->  the next system is CHARTED. Named, on the map, lane jammed.
    lanes_open  ->  the lane is OPEN. You may fly it.

Breaching still charts, so the tutorial's finale still opens the world — it just
ends by *starting* the hunt instead of closing the act. `is_system_unlocked` was
split into `is_system_charted` and `is_lane_open`, with the old name kept as an
alias for the **travel** question so that any call site missed in the rework
fails *closed* — refusing a lane — rather than silently granting one.

The chart panel grew a third state. A jammed system is not drawn like a system
nobody has heard of: it keeps its name, and wears a **broken ring** rather than a
padlock — interference, not bureaucracy, the same visual grammar as the shattered
survey pylon out in the Shoals. The hint names the engine, because "kill the
boss" is a chore and "silence THE GNOMON" is a hunt.

### The lane opens on the kill, not on the wreck

`open_lane()` and `mark_apex_killed()` are deliberately separate functions, and
the separation is load-bearing rather than tidiness. The lane opens when the
engine **dies**; the first-kill bonus is paid when its **wreck is breached**,
which is a second trip the player may not survive. Folding them together — which
the first draft did — meant `has_killed_apex` was already true by the time the
wreck was cracked, and **the bonus would never have paid at all**. A player who
dies flying home from a kill still keeps the frontier they earned.

### The run salt

`run_seed` is rolled once, at `reset_to_starter`, from the system clock rather
than the seeded global stream — it is the one number in this game that must *not*
be deterministic. Everything the hunt will hide (stage 2 onward) derives from it
and nothing else, which buys both halves of what a hunt needs: **deterministic
within a run**, so a bearing you were told an hour ago is still true and the lair
has not moved while you flew home; **fresh across runs**, so a second playthrough
is not a walk to a remembered coordinate. It is never re-rolled mid-run —
re-rolling would silently invalidate every hint the player had paid for.

### The migration that could have taken something away

v15 is the first save bump in this project that could **revoke** something. A
player who breached PYX-01 last night could fly to PYX-02 this morning; a plain
`lanes_open = []` default would wake them up locked out, and `load_game` would
have quietly teleported them home for standing in a system it now considered
unreachable. So an absent key means "this save predates the split", and every
system they had breached is treated as a lane they had open. It grants nothing
new — it reproduces exactly the reachability the old rule gave them.
`SAVETEST=migrate14` asserts it through the real file layer, and its red test
shows the harm precisely: `lanes_open=[]`, and the pilot standing in PYX-01
wondering how they got there.

### The assertion this file owed itself

`PYXIS_MINETEST` was dispatched, swept, and **absent from `HARNESS_VARS` from the
day mining stage 1 shipped it** — so all 25 of its assertions ran against
whatever was in the developer's real savegame instead of pinned starter state.
That is the exact defect §33 created that list to prevent, sitting inside the
list §33 created. It passed anyway, on luck: MINETEST resets most of what it
touches itself.

`THE PINNING LIST IS COMPLETE` now reads `main.gd` at runtime, regexes every
`OS.get_environment("PYXIS_*")` the game dispatches on, and asserts each one is
named in `HARNESS_VARS`. Reading the source is unusual and deliberate: the two
lists are the same fact written twice, and only the file can say whether they
still agree. On its first run it found **four** omissions — MINETEST and the
three capture modes.

The capture modes mattered more than they look. A capture is a picture of the
*design*; rendered against the developer's savegame it is a picture of their
afternoon. This had already bitten without being understood: a refit capture came
back showing a 50/50 hold and a Cargo Bay fitted — their fit, not the starter's —
which made `can_equip` refuse the very module the capture existed to photograph,
and produced a shot of the wrong ship with a completely plausible-looking stat
row. The screenshot was wrong in a way that looked right, which is the only kind
of wrong that survives review.

## 39. The Hunt — stage 2, the engines move into the deep

Stage 1 built the door. Stage 2 moves it somewhere worth walking to.

The apex engines used to sit at an authored point about 60% of the way to the
chart edge — visible from the dock, permanently marked on the radar, reachable in
under a minute. Now each one hides at a bearing and a depth this run rolled,
**out past the beacons**, and finding it is the game.

    pyx01  THE DRIFT     260-340u past the chart edge
    pyx02  THE REACHES   620-780u
    pyx03  THE QUIET    1150-1450u

The bands are the difficulty curve of the hunt, not decoration. The first engine
sits in the Drift so a pilot with the tutorial still fresh can brute-force it if
the hints run dry; the last one is an expedition.

`SystemDB.lair_pos(id, run_seed)` is the only function that answers "where". The
builder calls it, the free hint calls it, the world generator calls it, every
harness calls it — because the moment two places derive that position
independently they will disagree, and **a hunt whose hints point somewhere the
boss is not is worse than no hints at all.** It draws from its own salted stream,
never from the generator the expanse rolls on: one draw taken from that linear
sequence would move every rock, hulk, nest and station in the game.

### Both blockers were the same assumption

Two rules stood in the way, and neither was wrong when it was written. Both
assumed the fight happens near the origin.

`_wake_apex` **refused to wake the engine while the player was outside charted
space.** Sound reasoning for a boss at the origin: waking it from four hundred
units out would lock every console for a fight that was not visible, not
reachable and not started. With the engine now *living* out there, depth is
exactly the wrong question — the old rule would refuse to wake it anywhere it can
now be found. The question that always meant something is proximity: **is the
hunter here yet.** The timer kept its shape and became that poll.

Crossing the chart edge mid-fight **auto-disengaged**, for the same reason and
with the same fix. It is now a leash measured from the engine, not from the
chart. Three ranges, and the ordering is the design:

     60u  WAKE    the engine notices you. Arriving is deliberate.
     90u  DETECT  the radar finally marks it. You are committed by then.
    120u  LEASH   the fight ends. Leaving is deliberate too.

The gap between wake and leash is what stops the encounter flickering on and off
while a ship drifts at the boundary.

### Breaking off no longer sends you home

This was found while inverting the second blocker, and it is an exploit fix
rather than a difficulty preference. BREAK OFF used to pull the ship back to
spawn, which was the whole point of the button when the fight happened in sight
of the dock. With the engine in the Quiet it would have been **a free instant
trip home from fourteen hundred units out** — on a button, with a full hold,
ignoring the raid taper and every band in between. Fly out heavy, tap the boss,
break off, arrive home. The single best cargo route in the game, shipped
alongside the horizon built to make the trip home matter.

Breaking off now ends the **fight** and nothing else: the engine resets, you keep
your position and your problem. Dying still warps you out, which is what keeps
dying the expensive exit rather than the convenient one.

### The radar was answering the question

The apex marker rendered at **any** distance: top tier, never dropped by the
twelve-slot cap, alpha floored at 0.3 so distance could not fade it out.
Harmless while the engine stood in plain sight. Fatal the moment it hides — a
permanent red arrow pointing at the lair answers the entire hunt before the first
hint is ever bought. It is now gated on `DETECT_RANGE`, apex group only.

`RADARTEST`'s cap assertion had to move out to the lair with it. Staged at the
origin the boss is 300u away and no longer on the board at all, so `apex_kept`
was reporting *the cutoff working* rather than *the cap sparing the boss* — and
it was only ever printed, never asserted, so it would have said `false` forever
without failing. It is asserted now, from where the engine is detectable.

### The arena, and why the keep-out is not in `plan_cell`

The engine now stands in generated space, which is where stations, nests and
guarded hulks come from. Left alone the game would eventually roll a dock, a nest
or a standing garrison into the middle of a boss arena. So nothing that offers a
berth and nothing that fields its own hostiles exists within `LAIR_KEEPOUT` of
the lair — **which is `ApexBoss.LEASH_RANGE`, restated as world generation.** The
leash is the radius inside which the game says you are in the fight; anything
inside it that is not the fight is the game contradicting itself.

The approved plan put this in a `plan_cell` post-pass. Checking the fingerprint
window first showed why that was wrong. `PYXIS_MINETEST`'s `WORLD FINGERPRINT`
hashes cells -5..5 — a square reaching ~384u per axis — and pyx01's lair lands at
radius 308, in cell (-5, -2), squarely inside it. Subtracting the lair's
neighbours there would move a hash recorded to police the **seam roll**, and the
recorded constant would need re-deriving every time the salt or a depth band
changed.

`_populate_cell` turned out to draw from no generator at all, so the whole
keep-out runs at **instantiation** instead. `plan_cell` is the generator's word
and stays untouched; `built_plan` is the world's, and every consumer that turns a
cell into nodes, obstacles, armed nests or a save-file validation goes through
it. The fingerprint is safe **by construction** rather than by assertion — and
the assertion that proves it (`THE KEEP-OUT NEVER REACHES THE FINGERPRINT`) is
written to fail if a future band ever pushes the lair out past the hashed window,
because at that point it would stop meaning anything and should say so rather
than keep passing.

Four consumers, and the least obvious is the most important. `_register_cell` is
the half of a cell that has **no mesh**: filter the station out of the meshes but
not out of the obstacles and you leave a docking ring's worth of invisible wall
in the middle of the arena, with nothing on screen to explain it. `cell_has_bay`
goes through it too — a bay the generator describes but the world never builds
would survive every validation pass and hold cargo the player could never reach.

What the keep-out does **not** touch: rocks, seams and the supercell's landmark.
240u of genuinely empty space would read as a hole in the world rather than a
feature of it. The hulk *is* suppressed, despite carrying no hostiles by default:
it is the thing guard posts ride on — a standing garrison is a nest by another
name — and the thing `TRAP_CHANCE` rigs to spawn a pack the moment it is cracked.
Suppressing nests while leaving the object that mints one would be a rule that
only half held.

### A constant that could not be derived

`const LAIR_KEEPOUT := ApexBoss.LEASH_RANGE` is the obvious way to make two
numbers agree, and it does not work here. It is a compile-time dependency, and
the chain closes: DeepSpace names ApexBoss, ApexBoss names HUD, HUD names
DeepSpace. **Godot answers a cycle in the global class list by declaring every
`class_name` in the project undeclared** — a wall of parse errors in files nobody
touched, in a boot that hangs rather than fails, and not one of them pointing at
the line responsible. So the constant is written out and the two agree by
assertion instead. `THE ARENA IS THE ENGINE'S REACH` reads both and fails if they
ever part company.

(Worth knowing before the next fresh worktree: the same wall of "not declared in
the current scope" errors is also what a missing `.godot/` import cache looks
like, and that was the *actual* cause the first time. Run the import once before
concluding anything about your own code.)

### The assertion that measured the geometry

Red-first caught one of this stage's own assertions doing nothing. `NOTHING ELSE
LIVES IN THE ARENA` closed with `dressed > 0` — the clause meant to stop "clear
the arena" quietly becoming "delete the arena". Told to delete every rock and
seam inside the keep-out, the world still handed back three seams and the
assertion **passed on an arena with more than half its dressing missing**.

`> 0` was a property of the geometry, not of the rule: a 120u sphere overlaps
cells it does not contain, so something always survives. It now counts like
against like — what `plan_cell` stages inside the keep-out, over exactly the
cells the streamer made live, against what the world built — and rocks are
counted through the **obstacle registry** rather than the meshes, because "seams
still there, rocks gone" is the shape of a hole the mesh count would miss. Three
different ways of deleting the dressing now go red; before, none did.

That is the third time this project has shipped a green assertion that tested
nothing, and the second time the tell was the same: a threshold that any
plausible world satisfies.

### The one suite that had to be re-staged

`PYXIS_BALANCE` fights the engine to a conclusion with six fits, and it staged
every one of them at spawn. Under a proximity wake that fight never starts: the
suite would have spent three minutes per fit flying and reported six timeouts as
a balance result. It is boss-relative now, taken from the node rather than
recomputed.

Its second problem only appears once the first is fixed. **Dying emergency-warps
the ship home** — a blip when the engine sat 25u from spawn, and the end of the
run when it sits 300u away, because the leash fires, the engine resets, and every
second after a fit's first death would have measured a ship parked at the dock
with nothing to shoot. The harness makes the trip back instantly, because the
trip is not what it measures; `warps` already carries the cost and the reset
engine carries the rest.

### The interim hint

Stage 3 buys intel. Until it ships, the lane-obstructed broadcast gives the band
and the quadrant for free — "transmitting from THE DRIFT, bearing WEST". No
bearing, no distance, deliberately too vague to fly straight to: a quadrant of
the Drift is still tens of thousands of square units of nothing. It is the
difference between a hunt and a needle in an infinite haystack.

### What re-staging the boss suites turned up

Moving the engine meant every harness that stages a fight had to be re-aimed at
it. Four of them were arming the wake from spawn, which under a proximity poll
means the fight never starts — and three of those four could not have failed for
it, because they print observations rather than PASS lines.

`PYXIS_BOSSTEST` was the worst of them. It reported `woke: boss_active=false`,
`HUB EXPLOIT took_damage=false (must be true)`, `WARP-OUT boss_active=true (must
be false)` and `WAVES RESUMED: swarm_count=0 (must be > 0)` — four checks, every
one of them stating its own expectation and every one of them reporting the
opposite — and the sweep counted the run as green, because zero PASS lines and
zero FAIL lines is what a clean observation harness looks like. It also needed
`open_lane` on top of `mark_breached`: under §38's two-tier gate, breaching only
charts the next system, so its warp-out step was being refused and every
observation after it described a ship that never left.

`PYXIS_COLLISIONTEST`'s apex-damage check would have limped rather than failed —
its loop parks the ship on the boss every frame, so the wake poll caught up a few
seconds in and it measured whatever was left of the window. A sample that starts
partway through the thing it is sampling is not a sample. It now reads
`hp 1700 -> 968` instead of nothing at all.

`PYXIS_DOCKTEST`'s boss lock reads differently from out here, and the change is
worth stating: the keep-out guarantees **no berth exists within the leash**, so
the only way to be in a fight and ask to dock is to ask about a station 300u
away. `request_dock` checks `boss_active` before it checks range, so the refusal
is still the lock rather than the distance — but the rule is now a defensive one
covering a situation the world's geometry no longer produces.

### The armament that had never fired

Re-staging `PYXIS_APEXTEST` uncovered a defect older than this horizon, in the
final boss.

**The Meridian's graviton tether has never moved anybody.** `_tether_pull` adds
`inward * 6.5 * delta` to `player.velocity`, and the next thing that happens to
that value is PlayerShip's own integration:
`velocity.move_toward(desired, accel * delta)`. For a ship with no move target
`desired` is **zero**, so the autopilot brakes at `accel` — 9.0 on the bare hull —
against a pull of 6.5, and clamps it to exactly zero every frame before a single
unit of travel is integrated. `apex_boss.gd`'s own comment reasons that "the
weakest drive in the catalog accelerates at 9+ — the tether only wins against a
player who is not flying", which has the case precisely backwards: **the ship
that is not flying is the one braking hardest.**

The check that should have caught this could not fail. Its `grav_tether` branch
only ever *read* `park.distance_to(player)` and never assigned `park`, so
`displaced` was the distance from the engine to wherever the ship already
happened to be standing — clearing its 1.5u bar on the first frame with the
tether doing nothing at all. The relocation is what made it visible: the same
clause started reporting a **1,143u drag**, a number no armament in this game
could produce.

The measurement is correct now and reports `0.0u`. It is deliberately an
observation rather than an assertion, because the fix is not a bug fix: making
the tether work means choosing a pull that survives the autopilot *and* stays
out-runnable by the weakest legal fit (`max_speed` floors at 1.6), and that is a
balance decision about the final boss to be made in the hand rather than in a
harness. It is on record here and in the harness output until it is.

Two lessons, and the second is the one worth keeping. An observation harness
cannot fail, so a `(must be true)` printed beside `false` is not a warning — it
is a silence. And **the relocation did not break any of this**; it made four
already-broken things loud enough to read.

### The assertion the relocation recalibrated

`PYXIS_BALANCE` was the one suite that had never been run since the move, and
running it produced the stage's last finding: **the encounter it measures is not
the encounter it was calibrated on.**

Its `PHASE INTEGRITY` check has two clauses. The floor — every run engages at
least one seal — held in all thirty fight samples taken across five runs, never
once reading zero. That is the clause carrying the real design catastrophe, the
one apex_boss.gd's header names: a fit that bursts through "would never meet a
seal, a probe, or the sweep".

The median clause is the one that moved, and the cause is three lines in
`_process`:

    # Waves are the CHARTED system's pacing and they stop at its edge.
    if depth > 0.0:
        return

Swarm waves do not spawn past the chart edge. Every previous calibration of that
bar was taken from a fight near the origin **with waves arriving every 22 seconds
into it**; the fight now happens 308u out and has none. Fewer incidental targets
means the bot spends less time not shooting the boss, phases fall faster, and the
fit meets fewer seals. Measured, seals per fit across five runs:

    LANCE     2, 2, 2, 1, 1, 2      MIXED     2, 3, 3, 4
    ARC       5, 4, 10, 3           TORP      3, 1, 3, 1, 4, 2
    PULSE     2, 2, 1, 1, 3, 2      TORP+LNC  2, 2, 1, 1, 2

Three of five runs failed, on four different fits, standalone and in-sweep alike
— so it is not machine load, and it is not the stand-off distance either: the
same spread appears at 8u and at the historically-matched 30u.

**It is left failing on purpose.** The bar is a threshold to re-derive from the
distribution above, and this suite's own comments record two previous rewrites
caused by precisely the opposite instinct — v1 compared a number against a
ceiling that capped it, v2 set a bar of 2 from six runs of a distribution nobody
had measured, and PULSE's real floor turned out to be 1. Nudging the number until
the sweep goes quiet would be the third instance of the same mistake, made by
someone who had just finished writing up the first two.

Arguably the new measurement is the better one: the suite's own header calls
itself "the acceptance test for the encounter", and the encounter is now measured
in isolation rather than with a swarm fight layered over it. That is an argument
for re-deriving the bar, not for restoring the waves.
## 40. THE MERIDIAN's tether, and the check that could not fail

THE MERIDIAN is the last engine in the game, and its graviton tether is the one
armament in the trio that deals no damage at all. It drags you toward the hub,
the sweep arm, and the inner edge of the survey field: the armament *is* the
positioning. It had never worked. Not "was weak" — an idle ship parked in front
of it moved **0.0u**, and had done since the armament shipped.

### The brake was what beat it

`_tether_pull` did the obvious thing:

    player.velocity += inward * pull * delta

and `PlayerShip` integrates a few lines later with

    velocity = velocity.move_toward(desired, accel * delta)

For a ship with no move target and no attack target, `desired` is `Vector3.ZERO`
— so that line is not steering, it is **braking**, at `accel`: 9.0 on the bare
hull and never below the 3.0 ModuleDB floors it to. Both beat a 6.5 u/s² pull, so
`move_toward` clamped the velocity back to exactly zero every frame, before
`global_position` was touched. Net displacement across a full 2.8s window: none.

The comment above that line reasoned that "the weakest drive in the catalog
accelerates at 9+ — the tether only wins against a player who is not flying." The
shape of that error is worth keeping, because it is a comfortable one to make: it
read `accel` as a *thrust* budget, something the player spends on going
somewhere. `accel` is the rate at which velocity converges on `desired` in either
direction. The ship spending all of it on braking is precisely the ship that is
not flying — so the only ship the armament existed to catch was the only one it
could never move, and the comment asserted the opposite with total confidence.

### The fix goes around the brake, not through it

The pull cannot live on `velocity`, because `velocity` is the thing being braked.
It now rides the same channel `_recoil` already used: a separate vector summed
into the position step, never passed through `move_toward`.

    var travelled := (velocity + _recoil + _tick_tether(delta)) * delta

`ApexBoss` pushes into it through `PlayerShip.apply_tether()` and the ship spends
it. The player's own thrust still fights the tether, because the two velocities
add — a ship burning outward keeps the difference. What it no longer does is win
by standing still.

The parameter that matters is not the pull, it is **`drag_cap` — a terminal
speed rather than an acceleration**, at 1.15 u/s. An acceleration cap has no
ceiling on where a long window ends up; a terminal speed makes the guarantee
arithmetic. ModuleDB floors `max_speed` at 1.6, so the worst hull the game will
let you fly still burns outward at a net 0.45 u/s against a live tether. That
promise is load-bearing enough that `PlayerShip` re-clamps it at
`TETHER_DRAG_CEILING` rather than trusting the caller's data: the boss's table
may be tuned, and no tuning of it may build a cage.

Three smaller decisions fell out of the same reasoning. The drag survives an EMP,
because an unpowered hull is exactly what a tether should catch and letting it
lapse there would make the stun the cheapest escape. It is cleared by warp, dock
and death, none of which a tether should follow you through. And `Obstacles`
kills its component into a surface the same way it does `velocity`, or a tether
that pins you against a rock grinds there for the rest of its window.

### The check that could not fail

The assertion that should have caught all of this was green the entire time. It
measured

    park.distance_to(player.global_position)

against a `park` the ship was **never placed at**. The other two bosses' branches
pin the ship to `park` every frame; the tether's branch has to let the ship move,
so it measured displacement instead — and nothing anywhere put the ship on the
mark to begin with. What it actually reported was the gap between a point near
the boss and wherever `_load_system` had left the ship, a number that started
large, never moved, and cleared a `> 1.5` threshold on the first frame.

The last run before the fix printed it plainly, and nobody had read it:

    [apex] pyx03 ARMAMENT grav_tether dragged an idle ship 1143.2u toward the hub -> PASS

That 1143.2 is not noise. It is the Meridian's own lair depth — `system_db.gd`
puts it at `[1150.0, 1450.0]` out in the deep — so the harness was reporting the
distance from the player's spawn to the far side of the map and calling it drag.
A number three orders of magnitude past anything the mechanic could produce was
sitting in the log of a passing sweep, because nothing reads a PASS.

Staging it correctly took two corrections, not one. The ship is now placed on the
mark once, before the loop. And the mark moved **out to 9.0u**, because
`_tether_pull` stops pulling inside `HUB_RADIUS + 1.0` — 3.2u. A ship staged at
the 4.5u the pinned bosses share has **1.3u** of room to be dragged through
before the armament lets go, against a threshold of 1.5u: a perfect tether would
have come up short of the old bar by the width of the coast at the end of it. The
old check was unable to fail twice over — it measured the wrong thing, and the
right thing had almost nowhere to happen.

The measurement is also now **closure on the hub** rather than distance from the
park point, so the number means what the line says. Distance-from-park counts a
shove in any direction, including outward — which is the one direction that would
mean the armament was broken in the opposite way.

### Both halves asserted, both made to fail first

Two assertions, because the mechanic is two promises:

| Assertion | Broken | Fixed |
|---|---|---|
| an idle ship gets dragged | 0.0u | **3.3u** (threshold 2.0) |
| the weakest legal fit escapes | **−1.2u** (dragged in anyway) | **+1.0u** |

The first was verified red the honest way: harness fixed, armament left broken,
and it printed `0.0u -> FAIL`. That is the run that proves the check has teeth,
and it is the run the old staging could not produce at any threshold. The second
was made to fail by raising `drag_cap` above the `max_speed` floor — the exact
hazard it exists to catch — which required lifting `TETHER_DRAG_CEILING` too,
since the ceiling alone already refuses to build the cage.

The escape assertion is deliberately written against ModuleDB's **floors** rather
than a chosen module list. 1.6 u/s and 3.0 accel is the worst hull any legal fit
can produce, so a ship that escapes on those numbers means every fit escapes. A
named fit would only have proven something about that fit, and would have quietly
stopped meaning anything the next time the catalog moved.

### It happened again while it was being written

The escape assertion failed on its first run, reporting `gained 0.0u`. The
armament was fine. The harness was burning outward from frame zero, so the ship
left the tether's 13.0u range before a window ever opened, and no tether ever
latched — `0.0u` was not a measurement, it was the absence of one, printed in the
same shape as a measurement.

That is the *same* defect as the one this whole section is about, committed in
new code written immediately after diagnosing it: a number reported against a
state the ship was never in. The **verdict** was right by luck of construction —
a strict `> 0.0` and an explicit "did a window ever open" guard both refused it —
but the **message** was indistinguishable from a real zero-gain result, and only
going and looking established which one it was. A green version of that same
confusion is exactly what had hidden the tether for its whole life.

So the print now names the difference — `(NO TETHER EVER LATCHED)` — because "no
window opened" and "the ship gained nothing" are different failures with
different fixes, and a harness that renders them identically is one flipped
comparison away from being green about nothing. The staging was corrected to the
order the mechanic is actually played in: hold the mark, take the latch, *then*
burn.

## 41. Green the sweep — the bar, the pocket, and the suite that could not fail

The slice after the tether fix spent itself on the sweep's own credibility. The
baseline stood at 400 PASS / 1 FAIL, and a standing FAIL — however well
documented as "known-stale" — trains everyone to read the FAIL column as noise.
Restoring 0 FAIL meant re-deriving one threshold from data instead of nudging
it, and pulling one suite out of observation-land entirely.

### PHASE INTEGRITY, fourth version — the statistic was wrong, not the sampling

v3 of `PYXIS_BALANCE`'s `PHASE INTEGRITY` asserted a per-fit **median ≥ 2
seals**, resampling any fit whose first run engaged fewer. It was written as the
cure for v2's disease — a bar set from too few samples — and it reproduced the
disease with better bookkeeping, because the bar was still placed without
measuring where the distribution's mass actually sits.

The measurement pass this section exists to record: five standalone runs on a
pristine worktree, 30 fresh samples, pooled with the relocation pass's 31 and
the sweep run that failed — 66 samples, and not one zero among them. Per-fit
mass AT exactly 1 seal: PULSE 4/14, TORP 3/13, TORP+LNC 2/10, LANCE 2/11. Put a
median-of-three bar at 2 against ~25% mass at 1 and it fails
P(≥2 of 3 samples = 1) ≈ **43% of sweeps** — which is precisely the observed
"failed 3 of 5 runs, standalone and in-sweep alike." The median was resting on
the distribution's own median. **No sample count fixes a bar placed on the
statistic's own center — the statistic has to move.**

What 66 samples actually guarantee, and what v4 therefore asserts:

- **Every run ≥ 1 seal** — unchanged, zero violations ever observed. This is
  the design catastrophe clause ("a fit that bursts through would never meet a
  seal").
- **Every fit lands at least one run ≥ 2** — no fit is *consistently* shut out
  of the mechanic's full shape. Resampling now runs *until* a ≥ 2 lands, capped
  at five samples: the longest observed run of 1s is two, and five straight
  would be ~0.2% at the worst fit's measured rate. Residual flake moved from
  ~43% to ~0.3% — not by loosening the claim, but by making a claim the
  distribution supports.

What a typical 1–2 seal fight *feels* like — whether the deep fights are too
short on pressure now that no swarm waves wander through them — is deliberately
left as a playtest question. An assertion is for what the design guarantees,
not for what it hopes.

Red-first: phase HP dropped 1700 → 700 so every fit bursts phases inside single
windows — the exact catastrophe the floor names — and the assertion fired.

### The suite that could not fail, finished

§39 called `PYXIS_BOSSTEST` "the worst of them" — four checks, each printing
its own expectation and its own violation, counted green because zero PASS
lines and zero FAIL lines is what a clean observation harness looks like. This
slice converted every line to a real assertion, and the red-first pass on those
conversions was where the actual discoveries were:

- **The hub safe pocket does not exist, and never did in the way the check
  feared.** The ship physically cannot park at the centre: SystemBuilder
  registers the hub as an obstacle at `HUB_RADIUS * 0.75` (1.65u), PlayerShip
  resolves out of it every frame, and a ship teleported to the boss's own
  position settles at **2.60u, measured**. The old `took_damage=false` reading
  was a 3.0-second window closing before the first hit lands (~4s in). Parked
  for one full blade revolution (18s), the ship loses 58 shield. The check now
  asserts over the revolution, not the coffee break.
- **`HUB_CRUSH_RADIUS` is unreachable today** — the obstacle floor (2.60u) is
  more than double the crush radius (1.3u). Kept, as a documented backstop: it
  guards the degenerate bearing maths, and the EMP integrator already skips
  `Obstacles.resolve`, so a future force applied during a stun is a real path
  back into that zone. The comment now says which mechanism actually keeps
  ships out.
- **A one-shot `_arm.active = false` does not stick** — the boss state machine
  re-enables the arm on every SURVEY/SEAL transition. Found because the first
  red run refused to go red: 6 damage leaked through a supposedly disabled
  arm, in the arm's exact `DAMAGE_PER_SECOND * TICK` = 2.0 increments. The red
  harness had to disable the blade check itself.
- **The warp-out clear is redundantly guarded** — `_load_system` clears
  `boss_active` on the load path AND the leash fires `disengage_apex` during
  the warp. The second red run also refused to go red until *both* were
  stranded. The assertion protects the pair; losing either alone is invisible,
  losing both is what it catches.
- **RETURN was vacuous** — it asserted a full-strength engine on return
  without ever damaging the engine, so it would also have passed in a world
  where damage persisted, which is the exact defect it exists to rule out. The
  suite now halves the boss before warping out and asserts 1.00 on return.

Every conversion was verified red by breaking its actual mechanism — the wake
staging, the blade check, both boss-state clears, the spawner, the phase HP
init — never by inverting the comparison.

### The stale table

`sweep_arm.gd`'s header still analysed park radii against `SWEEP_RADIUS 6.0`;
the constant is 8.0. Recomputed against the current catalog, the conclusion
changed, not just the number: "Lance → outside it, safe" is now true only of
the Mk II at 8.40, the Mk I parks at 7.70 — *under* the blade — and
`CORE_RANGE` (7.0) drags any core-shooting Lance back inside regardless; the
rim park is only safe for probe work. A comment that does arithmetic ages like
an assertion that measures nothing: silently.

## 42. The Hunt — stage 3, the intel dossier

Stage 2 hid the engines and gave the player one free sentence: a band and a
quadrant. That is enough to make the deep a place you search rather than a place
you cross, and not enough to make searching it a *game*. Stage 3 is the ladder
between them — six ways to learn more, priced in credits, distance and risk
rather than in time.

### The dossier holds claims, never the answer

`GameState.apex_intel` is per-system arrays of hints in two shapes: a bearing
cone taken from a stored origin, and a `{band, quadrant}` rumour. **Nothing in it
is ground truth.** `SystemDB.lair_pos` is, and it is never written down — every
hint is derived from it at the moment it is earned and then stands on its own.

That separation buys three things at once. A save file cannot leak the answer.
A contradictory dossier stays contradictory instead of being silently
reconciled. And the estimate can be recomputed live, so a bought reading tightens
the plot the instant it is filed rather than at the next checkpoint.

The cap is eight, **widest error evicted first** — a ±5° reading bought at the
Last Watch must never spend itself evicting a ±15° guard-post rumour already on
file. Rumours score as 90° (a quadrant), which puts them at the front of the
queue to go. The entry is deleted on the kill: intel about a dead engine is
clutter that would keep drawing a survey plot for a hunt that is over.

### Six channels, priced in three different currencies

| channel | error | what it costs |
|---|---|---|
| survey mast | ±8° | free, but only within 220u of the lair |
| cartographic index | ±12° | a relic, and a lab to read it at |
| cleared guard post | ±15° | a fight, band 2 or deeper |
| open shear | ±4° | being there, once, while it is open |
| Embers Cantina | band+quadrant | 500 salvage |
| The Last Watch | ±5° | 900 salvage, 1,200u past the chart edge |

The spread is the design. The **vaguest** channel is the one you can earn by
fighting, so combat never substitutes for the desks that sell precision. The
**sharpest** is the one that cannot be sought out — a shear opens where it opens,
on a fuse. And the two paid rungs are separated by geography rather than by
price alone: the Cantina sells the cheap word in charted space, the Watch sells
the sharp one from further out than the thing being hunted. `deep_port_db.gd`
used to say flatly that rumours were the Cantina's trade; that is still true of
market gossip and no longer true of the hunt, and the header now says which is
which.

Every channel files through one function. Six call sites that each decided
independently what a hint costs and what the player sees would be six chances
for the answer to leak.

### Precision is bought, never farmed

Two rules fall out of that and both are asserted. The same instrument read twice
from the same spot is **one** reading — otherwise parking on a mast and
re-triggering it narrows the estimate for free. And the error is **seeded, not
rolled**: a pure function of system, run, channel and observer position, so
saving before a purchase and reloading is not a reroll for a better cone. A hunt
where the optimal play is to reload is not a hunt.

### The estimator, and three ways it was wrong

`Hunt.estimate` intersects the cones with the authored depth band on a polar
grid. Not algebra: intersecting N cones with an annulus analytically is N-body
case analysis — cones crossing the annulus twice, cones missing it, pairs
meeting in two disjoint lenses — and every branch is a chance to return a
plausible `Vector3` that is wrong, which is the exact failure this project keeps
writing assertions about. A grid has no special cases and degrades honestly.

The band is a **clamp**: hints choose where in the annulus, never the annulus, so
no stale or hand-edited dossier can put the ghost in charted space. `strength`
counts hints the agreed region actually satisfies, so three cones that
contradict each other yield 2 — and the radar's threshold does not fire on a
dossier that disagrees with itself.

Then the harness took the estimator apart three times.

**It under-claimed.** A two-hint dossier reported a 209u search radius with the
lair 213u away — a circle that confidently excluded the answer. The grid holds
POINTS; the hints admit CELLS. At radius 1300 a 3° step is a 68-unit arc, so
measuring to the samples under-claims the region by up to half a cell diagonal.

**It widened when intel was bought.** Twice, in two different repairs. First
because a coarse pass that cannot resolve a narrow agreement falls back to a
SUPERSET ("points satisfying all but one"). Then, once refinement fixed that,
because the measured extent *dips before it rises*: while the window is much
larger than the region only a sample or two lands inside, so the radius is
mostly cell inflation, and it grows again as the window closes. Stopping on "two
passes agree" caught the dip; keeping the widest pass moved the wobble to a
different fixture. A player paying 900 salvage and watching the circle grow has
been told the hunt is broken, whatever the arithmetic says.

What shipped bounds **the window rather than the samples inside it**. The window
is a genuine superset of the agreed region, so it cannot under-claim; it shrinks
as constraints are added instead of jittering with sample placement; and six
passes run every time so measurement DEPTH is uniform and two dossiers are
comparable.

And then the residual is **named rather than tuned away**. `RESIDUAL_FRACTION`
is 5%, chosen against what a player can see: the ghost only appears under a 200u
radius, where 5% is ten units — less than one marker width on the radar. Three
formulations each moved the noise somewhere else rather than removing it, which
is the signature of a method's noise floor rather than a bug hiding inside it.
The honest move at that point is to say what the number means, not to keep
adjusting until one fixture comes out clean.

### The assertion a new channel broke, and the one it was hiding

The full sweep came back 421 PASS / 1 FAIL, and the failure was `LOGTEST`'s
`FIVE SITES WIRED` reporting `shear 2 line`. Nothing was wrong with it. Its
staging parks the ship four units from a shear and counts what the shear writes
to the captain's log — and working a shear from close up now also files a
bearing, which writes its own line. One assertion, two systems, both behaving
correctly. The ship now stands outside `Rift.INTEL_READ_RANGE`, so the check
measures the thing it names.

**That collision was worth more than the fix.** It pointed at a gap: the
channels' proximity gates were load-bearing design with nothing driving them.
`HUNTTEST`'s channel battery calls `file_apex_intel` directly, which is right for
testing the dossier and proves nothing about whether a shear checks how far away
you are. A shear that talks from any distance is a bearing you collect by flying
past, and the entire paid ladder above it stops meaning anything.

So `A SHEAR ONLY TALKS TO WHOEVER IS THERE` drives the real node: pulsed from
78u it files nothing, pulsed from 3u it files once, pulsed again it still holds
one. Red-verified by deleting the distance check, which files a bearing from 78u
away. The far case runs FIRST on purpose — the one-shot flag must not have been
spent by a read that should never have happened, and testing near-then-far would
pass on an implementation that had no gate at all.

### What the checkout cost

A `git checkout` of two files, run to revert red-test edits without checking
whether those files held anything else, discarded the entire refinement rework
and one channel hook. Both were rebuilt from the session's own record within the
hour and the harness confirmed the rebuild, so nothing shipped wrong — but the
rule it broke exists precisely because "I know what is in this file" is a belief,
not a fact. **Check `git status` before any command that discards, every time,
including the times it is obviously unnecessary.**

## 43. The hold, as a place rather than a list

The cargo manifest lived inside the **Refit** modal, and `refit_panel.gd` said
why in its own words:

> THE HOLD, READABLE ANYWHERE … REFIT is the console that is open everywhere
> except a boss fight and a dock, **which makes it the one place this can live.**

That is a workaround written down honestly. It cost two things: Refit was ~37%
code about cargo rather than modules, and the hold rendered as `ALLOYS x6` — a
list that never showed the one fact a pilot needs. Goods cost 1, 2 or 3 space
each, so `RELICS x8` and `ISOTOPE x8` read identically while occupying 24 and 8
units of a 24-unit hold.

The hold now has its own console, opened from the HUD readout, drawn as a grid
where **one cell is one unit of space**. A three-space relic visibly takes three
times the room of an isotope. Everything else here follows from that and from
one measurement.

### The measurement that decided the visual design

Run this project's own `_confusion_distance`/`_simulate` over all 561 pairs of
the 34 commodity colours:

| mode | worst pair | pairs under ACCESSTEST's 0.20 threshold |
|---|---|---|
| normal | **0.0224** (`lattice_data`/`chart_reaches`) | **212 / 561** |
| deutan | **0.0095** | 372 / 561 |

`palette.gd` records the *shipped band set* at 0.173 under deuteranopia and
calls that "the whole reason for this". **The good colours are an order of
magnitude worse, in normal vision.** No seven-colour subset of this game's
tokens clears 0.20 in all four modes; the best is 0.163. And 26 pairs of goods
share family *and* bulk *and* an indistinguishable colour.

So the grid does not try to name anything. **A cell says what KIND of thing is
there and how much room it eats; the strip beneath names the good in words.**
Seven families derived from markers already in the data — `ore_class`,
`is_salvage`, `is_chart`, `is_component`, `trade_only_at` — each with a glyph,
and the glyph is the primary channel rather than a redundancy. That is a
consequence of a measurement, not a preference.

`CommodityDB.family()` stores nothing, which is how it answers the warning above
the ore block: that hazard is about a *key* shadowing `band` and letting
`spawn_loot`'s regrade mint the wrong good. Its branch order is load-bearing —
`is_ore` first, because all eight ores carry `trade_only_at` and an
allowlist-first version files every ore beside the contraband. That partition is
still total and still 34, which is exactly why the assertion names the ores
instead of counting them.

### Four assertions that were wrong before they were right

This section exists mostly to record those, because each was wrong in a way the
project already has a name for.

**`THE FAMILY GLYPHS ARE DRAWABLE` shipped a renderability check that could not
see.** `font.has_char()` failed `▽` — and then, probed against the font a Label
actually resolves, reported *every* geometric shape missing, including `◈ ▲ ● ◆`
(the band glyphs the manual draws) and `✕` (the close button on all four
panels). The project ships no font, so those reach the screen through Godot's
system-font fallback **at draw time**, which `has_char` cannot observe. A clause
that fails on glyphs the game already displays is worse than no clause. It is
gone, the attempt is recorded, and what it leaves unguarded is named: a glyph no
system font carries draws as tofu and the line stays green. That is a windowed
check, not a headless one.

**`THE READOUT FOLLOWS THE HOLD` passed first time and was wrong to.** Written
naively, both its legs were no-ops — `spill_unread` returns 0 inside charted
space, and `on_docked` settles only an *accepted* delivery whose port and
quantity match. It compared nothing against nothing and reported green **over
two live bugs**: dying past the chart edge left the HUD reading `HOLD 10/24`
against a true 4, and settling a delivery left `12/24` against a true 0. It now
stages the ship past the chart edge, accepts the real contract, docks where it
points, and asserts both paths moved cargo *before* comparing any readout. The
fix was `GameState.cargo_changed` rather than a twentieth hand-written refresh
call — nineteen sites enforcing a rule by memory was the defect.

**`A FINGER FITS` asserted a constant against itself.** It is the project's
first tap-target assertion at all: `UIKit.button` floors height at 42,
`RoundButton` is 80×80, nothing had ever checked either, and `port_panel` ships
32×32 swatches, so the convention was not even held. But as first written it
required cells to be at least `CELL` — the grid's own design constant — which
would still pass if someone set `CELL` to 30. It now asserts against a separate
`TAP_MIN`, and derives the expected cell size from the **laid-out container**
rather than the grid's arithmetic, so it fails both if the layout starves the
grid and if the grid's maths drifts from the box it lives in.

**`THE CLAMP HOLDS` found two real bugs and one behaviour, which is the entire
argument for writing it in the recomputing shape** rather than `SHEET FITS`'s:

- `_clamp_height` computed chrome as `_col.get_combined_minimum_size().y -
  _scroll.custom_minimum_size.y`, which is **circular** — the column's minimum
  includes the scroll's, so each call folds its own previous output back in. It
  looks correct while the strip is two labels; it diverged to a measured room of
  **−26,506** once the strip grew.
- An autowrapping `Label` with no minimum **width** computes its wrap at nearly
  zero width, so the three pilot skill lines reported a minimum **height of
  2,415 rows**, which became the column's minimum and drove the sheet negative.
  `manual_screen` and `pause_menu` both pin wrapped labels to 300 for exactly
  this reason.
- Godot settles container layout over a frame, so chrome measured during
  `_refresh` is the pre-settle height and the sheet sat 34 rows short at capacity
  104. The screen re-measures on the following frame; the assertion waits two,
  the way the layout harness already does after a resize.

Written as `sheet <= viewport` — `SHEET FITS`'s shape — none of those would have
been visible, and deleting the clamp outright would still have passed, because a
collapsed sheet fits a viewport beautifully.

### Two decisions worth keeping

**The door is the HOLD readout, not a fourth dock button.** Four buttons leave no
centre slot, and ABILITY would sit ~49 design units off centre against the
dock's own rule that it "gets the position the eye returns to" because it is
"the button pressed under pressure". The readout costs no dock width and is
already where a player looks to ask the question.

**The screen is not locked during a boss fight**, unlike REFIT and CHART. The
instinct that prompted it — dump cargo to run — does not work: cargo has no mass
model, and dumping before dying is strictly worse than not, since
`_emergency_warp` spills unread salvage as recoverable cubes while
`JETTISON SPAWNS NOTHING` forbids dumped cargo from floating at all. The real
reason is smaller and true: `apex_wreck` seeds 4 isotopes and 3 relics among its
spill — **13 units of space against a bare hold of 24** — so dumping ore to make
room for the drop is a genuine play, and locking the screen would delete it.
Note `set_panels_locked` has two callers, docking and the boss, so leaving HOLD
out is also what keeps the docked stash exit reachable.

## 44. Two bugs that were not where they were reported

Both of these arrived with a diagnosis attached, and both diagnoses were wrong in
the same instructive way: they described the symptom's *neighbourhood* rather
than its cause. Chasing either as written would have produced a plausible change
that fixed nothing.

### The mining audio was never a mining bug

Reported as "after mining ore, the mining sound keeps looping", with the sharp
observation that only a swarm's arrival ever stopped it — "which suggests the
loop is never stopped, merely overwritten." That instinct was exactly right and
pointed one layer below where it was aimed.

There is no mining loop. `mineable_seam` has no `AudioStreamPlayer` of its own
and never calls `attached_loop`; the sound is a single fire-and-forget one-shot
at the end of a cut, `Sfx.play("crack", -4.0, 0.75)`. Every other way out of a
hold — cancel, drift, stun, dock, warp, recall, death — makes no sound at all, so
the instruction to audit all of them would have added teardown code to fifteen
paths that had nothing to tear down.

What actually happened is one line:

```gdscript
static func loopify(stream: AudioStream) -> AudioStream:
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD   # mutates
	return stream                               # the same object
```

`_streams[name]` holds **one** resource per sound — `load()` returns Godot's
cached instance — so this never made *a player* loop. It made **the sound** loop,
process-wide, permanently. `Derelict` takes a crack loop in `_ready`, on spawn
rather than on breach, so entering any system containing a hulk was enough. From
that moment every completed cut handed an endless stream to a pool with no
`stop()`, and the only thing that could ever silence it was `_next` wrapping
twenty sounds later and stealing the player back. A swarm turning up is precisely
that.

`crack` is the **only** name in the project used both as a loop and as a
one-shot, which is why this surfaced as a mining bug and nothing else. The fix is
a memoised duplicate — `_looped_stream(name)` — so the loop players get a looping
copy and `_streams` stays pristine. Not in the `.import` files, incidentally:
every one of them carries `edit/loop_mode=0`. All looping in this project is
runtime mutation, which is worth knowing before hunting the next one.

**Two assertions were reading the bug as though it were the feature.** FEELTEST's
`LOOP END` asked the shared one-shot cache for its `loop_end` after a
`loop_start` — a question that only had an answer because the cache was being
corrupted, and which would have gone red *on the fix*. It now reads the loop
player's own stream, and additionally asserts the one-shot copy comes back
unlooped. `CRACK OUTLASTS HOLD` was fine: it read the player's stream all along.

The new check, `THE CUT FALLS SILENT`, waits for silence **before** cutting.
Written the obvious way it read six sounds still ringing from earlier sections,
so "something is playing" was true whether or not the cut made a noise. Red, it
prints `5 sounding before, 6 at the cut, 6 after 4.0s`; green, `0 / 1 / 0`.

### The apex respawn, and the assertion that was not what it looked like

`SystemBuilder._build_apex` never asked whether the engine was dead, and its
comment — "only exists once this system's derelict has been breached" — was
describing a rule that lives somewhere else entirely (breaching arms the *wake*,
never the build). That much was reported accurately.

What was not: `PYXIS_BOSSTEST`'s step 4 was said to assert the old behaviour and
to need inverting. It does not. It **halves** the engine and warps out, then
asserts a full read on return — it is about a *damaged* engine, and §41 had
rewritten it specifically so it could not pass vacuously. Retreat resetting the
fight is correct design: failure costs tempo, never salvage. Only a **win** must
stick. Inverting step 4 would have deleted a good assertion and replaced it with
a false one; the suite needed three new checks instead, and step 4 passes
untouched.

**The third state.** `apex_killed` is not "this engine is dead" — stage 1 split
the two deliberately, and HUNTTEST's `OPENING A LANE DOES NOT SPEND THE BONUS`
pins the split. So killed-but-not-yet-cracked had nowhere to live:

| state | flag | rebuilt on entry |
|---|---|---|
| alive | neither | the engine |
| killed, wreck uncracked | `apex_down` | the **wreck** |
| killed and cracked | `+ apex_killed` | nothing |

**The wreck survives the warp, and that is the decision worth writing down.**
Losing a 15,000–32,000 credit first-kill bonus to a jump the player had every
reason to make is a silent punishment for leaving. The wreck is rebuilt at the
same deterministic `lair_pos` until somebody actually breaches it, and the new
check asserts the *bonus it carries*, not merely that a node exists — a wreck
rebuilt from defaults would otherwise pass while quietly paying 15,000 in a
system authored for 32,000.

`apex_down` is written by `on_apex_defeated`, **not** by `open_lane`. `lanes_open`
looked like a free answer that would have avoided the save bump, and is not one:
BOSSTEST's own staging opens a lane purely as a travel permit without anything
dying, and the v15 grandfather seeds `lanes_open` from `breached`, so a save old
enough would report living engines as dead and delete their bonus.

### The grandfather, and choosing which way to be wrong

A v16 save cannot say which engines are down; it only records which ones **paid**.
So v17 seeds `apex_down` from `apex_killed`, which under-counts by exactly one
case — killed, warped out, never cracked.

That is the right direction to be wrong. Under-counting rebuilds an engine the
player already beat, which is merely today's behaviour left unchanged for one
system. Over-counting would delete a wreck worth up to 32,000 credits that they
can still see on the radar. `SAVETEST=migrate16` asserts both halves: `pyx01`
paid and is grandfathered down, `pyx02` has an open lane and is **not** — which
is the same assertion twice, once for what the rule does and once for what it
refuses to guess.

One subtlety the validator leg exists for: **absent** and **empty** must not read
alike. Absent means "infer from `apex_killed`"; an empty list in a v17 save means
"this player has collected nothing", and reading the second as the first would
resurrect every engine they had put down.

### What comes back, and what does not

Worth recording because the report asked about "sentries" and there is no such
thing as an apex sentry. Three separate populations were checked before changing
anything: the engine's own probes (vented mid-fight, cleared by `reset_fight`),
the authored garrison in `def["sentries"]` (hundreds of units away, unrelated to
the lair), and deep-space nests (already suppressed inside `LAIR_KEEPOUT`). Only
the engine node itself was ever the problem. Ambient pacing keeps respawning, as
it should.

### The suite the fix broke, and why it was the right kind of break

`PYXIS_BALANCE` went red on the first full sweep after the apex fix, and the
failure mode is worth keeping: **every fit after the first reported `NO BOSS`**,
and `PHASE INTEGRITY` printed a row of zeros — `ARC 0/0/0/0/0; PULSE 0/0/0/0/0;
…` — which is a suite measuring nothing rather than a balance result.

The cause is the fix working. `_balance_run` fights pyx01's engine to a
conclusion with six fits and a four-run resample pass, calling `_load_system`
between each. The first fit killed the engine; from v17 on, a killed engine is
not rebuilt, so the remaining twenty-odd runs had nothing to shoot at.

The repair is one line in the harness, not a softening of the rule:
`GameState.apex_down = []` at the top of each run, the same shape HUNTTEST
already uses to restore `apex_killed` after asserting on it. A harness that
deliberately replays an encounter the game gives **once** has to put the world
back itself; that is a property of the measurement, not a hole in the fix.

Two things make this a good failure rather than an annoying one. It was loud —
`NO BOSS` on every line and a visible row of zeros, not a plausible-looking
number that happened to be wrong. And it was caught by the *full sweep* rather
than by the suites under change: `BOSSTEST`, `MINETEST`, `HUNTTEST` and
`FEELTEST` were all green when it appeared. The per-suite runs during
development would never have found it, which is the argument for the sweep being
the gate rather than the suite you happen to be editing.

### One standing FAIL that is not ours

The same sweep surfaced `HOLDTEST`'s `THE READOUT FOLLOWS THE HOLD` failing, and
it reproduces identically on a clean `fb03037` worktree — so the recorded
"437 PASS / 0 FAIL" was already off by one before this change. Instrumented, the
cause is immediate:

```
[dbg] accept=false active=[sweep_swarm, haul_small] slots_free=0
```

`ACTIVE_SLOTS` is 2 and both are still held from an earlier section of the same
suite, so `contracts.accept("haul_alloys")` returns **false** and the assertion
does not check. The delivery half of it has never executed; its `both_fired`
clause compares pre-spill cargo against post-delivery cargo, two quantities from
different phases, and is false for a reason unrelated to what the line claims to
measure. Left for whoever owns the hold — the fix is to drop the two contracts
first or to assert on `accept` — but recorded here because an assertion that has
never once run is exactly the defect class §41 and §43 were written about, and
finding a third one in the suite added most recently is the argument for reading
every new check's *red* run rather than trusting its green one.

## 45. Saying what a module actually does

The design contract at the top of `module_db.gd` claims every module is
"legible — few stats, **all surfaced as deltas in the refit console**". Two
halves of that sentence were untrue, and had been since the console shipped.

### The audit, which is the part worth repeating

`summary_lines` is a hardcoded list of seven columns, and the way to find what
it misses is mechanical: diff every key any module *writes* against every key
that function *reads*. Six came back, plus core abilities:

| silent stat | carried by | what the player saw |
|---|---|---|
| `shield_regen` | `util_repair` +11, `util_repair_2` +19, `util_shield` +5, `util_shield_2` +9, `rig_bulwark` +4 | **nothing at all** for both Repair Bays |
| `accel` | every drive, three rigs | the Vector Drive read as SPEED −2.5 and no upside |
| `magnet_range` | both tractors, `rig_prospector` | half the tractor's pitch |
| `survey_speed` | both scanners | — |
| `chain` | `arc_1` 2, `arc_2` 3 | the Arc family's entire identity |
| `splash` | `torp_1` 2.2, `torp_2` 2.9 | the Torpedo family's entire identity |
| `ability` | all three cores (`stats: {}`) | **nothing at all**, on a 9,400-credit part |

`util_repair` is 5,200 credits and `util_repair_2` is 13,500, and fitting either
moved **not one number on the screen built to compare modules**. The three cores
were in the same state.

**`chain` and `splash` are not flat keys, and that is why they were missed.**
`compute_stats` folds drive/utility/core stats into the top level but keeps
weapon stats *per weapon* inside `stats["weapons"]`, so `stats["chain"]` reads
nothing and always did. A fix that added `["CHAIN", stats["chain"]]` would have
rendered a confident zero.

### The second half: a promise with no implementation

`GameState.preview_stats(slot, id)` existed, was correct, and had **zero callers
in the repository** — while `refit_panel.gd`'s own header comment advertised a
"stat delta preview". The arithmetic had been sitting there unused the whole
time; nothing had ever drawn it.

**The delta lives on each module ROW, not on a hovered or selected one.** This is
a 720-wide portrait touch console. There is no hover on a phone, so a preview
that appears on focus would be dead on the target device — the answer has to sit
next to the thing you are about to press. The store gets the same treatment, and
also gains the `"%d PWR"` the refit console has always printed and the store
never did: before this, a 19,500-credit Targeting Scanner Mk II was sold on a
name, one line of flavour text and a price.

### The layout constraint was real, and the old note was right about it

The previous comment defended seven columns on the grounds that these are cells
in a plain `HBoxContainer` on a phone. That was correct, and it is why the six
stats could not simply be appended: **an `HBoxContainer` of `EXPAND_FILL` cells
does not overflow visibly, it squeezes.** Fourteen columns is reachable — an Arc
and a Torpedo for `CHAIN` and `SPLASH`, a Prospector and an Assay Rig for `CUT`,
`ORE` and `PULL` — and fourteen labels shaved to 46px each would have shipped as
"the console looks tight" rather than as a defect.

The row is an `HFlowContainer` now and wraps, which the chip row above it already
did for the same reason. Measured at the catalog's widest fit: **14 columns,
narrowest cell 62px against a 62px floor, 0px overflow.** Against the old
container the same fit runs 868px wide inside a 720px sheet.

### The assertion was the instance, not the rule

`THE CONSOLE DRAWS THE UPSIDE` checked three mining modules for a `CUT` or `ORE`
column. It was green for as long as it existed, and the rule it was named after
was being broken three rows away the entire time. Replaced by two:

- **`THE CONSOLE DRAWS EVERY MODULE`** — all 36, each compared against the same
  fit with that slot *emptied* rather than against the starter. Comparing to the
  starter would let every weapon pass merely by displacing the pulse it replaces.
- **`EVERY STAT REACHES A COLUMN`** — per key rather than per module, because a
  module can be legible by accident: `util_cutter`'s `turn_rate` penalty already
  moved `HANDLING` while `mining_rate` itself was undrawable. Perturbing one key
  at a time is what isolates that.

The five keys `compute_stats` folds into DPS and REACH are **named in the output**
rather than quietly skipped. A silent skip list is how the first version of this
line came to cover three modules and read like it covered the catalog.

Red-first, each against the mechanism it names rather than an inverted
comparison: deleting the `REGEN` column gives `mute: 2, first: util_repair` and
`undrawable: shield_regen`; deleting the ability column gives `mute: 3, first:
core_overcharge` and `undrawable: ability`; reverting the row to an
`HBoxContainer` fails the strip check; and removing the delta from either screen
fails `THE DELTA IS AT THE DECISION` on that screen alone.

That last one is asserted against the **rendered panel** — walking the built tree
for the text — rather than against `preview_stats`'s return value. The function
has always returned the right numbers. Not one of them had ever reached a screen,
and only the rendered tree can tell the difference.

## 46. The power budget, measured before it was changed

The report was "the power budget is too tight", with one concrete example: you
cannot run a mining fit and a defensive fit at once. The measurement came first,
and it disagreed.

### What the numbers said

| tier | power | price |
|---|---|---|
| Mk I | 12 | 0 |
| Mk II | 15 | 10,000 |
| Mk III | 18 | 32,000 |

Six slots: two weapons, a drive, a core, **two** utilities. Starter fit draws 8.

**The player could already buy tiers.** `port_panel._reactor_row` is the first row
of the outfitter body at every port carrying the service, flat-priced and
unaffected by port multipliers, and the field console correctly says "AT PORT".
The upgrade path was neither missing nor broken — which was worth establishing,
because "the ladder does not exist" and "the ladder is expensive" are very
different fixes.

**And the example was false at Mk III.** `rig_prospector` + `rig_bulwark` over
starter weapons, drive and core draws **16 of 18** — it fits, with 2 spare. What
actually stops a player pairing mining with defence is the **two utility slots**,
and `MINING COSTS A MOUNT` asserts that limit on purpose. No amount of reactor
moves it. A tier sold to relieve that complaint would not have relieved it.

Where power genuinely binds at Mk III is narrower: two heavy mounts plus anything
(dual `torp_2` is 12 before a drive), and two good utilities *plus* two good
weapons (21–27).

### So Mk IV has one job, and it is the one the assertion already named

`MINING COSTS A MOUNT` says the prospector commit (16) leaves a Mk III without
room for the `lance_1` (4) the pacing band is denominated in — "a prospector
gives up the Lance to be a prospector". **Mk IV at 20 buys exactly that back, and
nothing else.** 55,000 credits to stop giving up your gun. The step is 2 rather
than 3 for that reason: all-best is 27 and stays out of reach, and the slot limit
is untouched.

### The stale name that the new tier exposed

`MINING COSTS A MOUNT` computed:

```gdscript
var mk3 := ModuleDB.reactor_power(ModuleDB.REACTOR_TIERS.size() - 1)
```

A variable called `mk3`, holding *whatever the top tier happens to be*, inside an
assertion whose every surrounding word says "Mk III". Adding a fourth tier did not
make it lie — it made it **stop being about Mk III**, silently. Run against Mk IV
before the fix, it prints `the commit draws 16 of Mk III's 20`, which is the
defect saying itself out loud.

This is the third instance of the same class in three sections: `_build_apex`'s
comment (§44), `sweep_arm.gd`'s radius table (§41), and now a variable name inside
a live check. The pattern is a name that encodes an assumption and a value that
does not. Pinned to `MK3_TIER := 2`, with `THE TOP REACTOR BUYS THE MOUNT BACK`
added beside it so the top tier's claim is asserted rather than assumed.

### The economy, re-measured rather than reasoned about

The house rule is that a new tier sold for credits is a SINK and therefore
house-legal, and that a price cut is a raise. Both halves were checked rather
than trusted:

| assertion | before | after |
|---|---|---|
| `MIDTIER` (binding) | 2.88–2.93 × `lance_1` | **2.91** |
| `CEILING` | 0.047 vs 0.15 cap | **0.041** |
| `ROUTE PARITY` | — | 1.0% vs 20% allowed |

`MIDTIER` is `EARNED / lance_1`'s price — an **income-only** measure with no
expenditure term — so a sink cannot move it, and did not. `CEILING` divides by
`_pacing_catalog_cost`, which the new tier's 55,000 joins, so the already-slack
ratio got slacker: 358,200 → 413,200 in the denominator, and the full catalog
moved from ~21 to **24 sessions**.

Worth recording for whoever next reaches for this lever: the one number in the
price table that genuinely endangers `MIDTIER` is `lance_1`'s own 5,800, because
three assertions are denominated in it. Cutting it to 5,000 would read 3.34
against a 3.00 ceiling and fail immediately. Every other price — including every
reactor — is invisible to it.

## 47. Factions — stage 1, the allegiance layer

The design is in `docs/HORIZON-4-FACTIONS.md`: fourteen factions in four tiers,
staged across six pieces of work. This section records the first of them.

**Stage 1 ships no content, and that is the whole point.** The world after it
is bit-identical to the world before it. What changed is that "who does this
machine shoot" stopped being a hardcoded answer and became a rule — and that
combat now knows *who killed what*, which nothing in this codebase has ever
tracked.

### `hostiles` had to keep meaning "hostile to you"

The obvious implementation is to make faction membership a group and let
`hostiles` be derived. It does not survive contact with the code. That group is
read by the radar, by `_count_raiders`, by the torpedo's splash sweep, by
Overcharge's blast, by every harness that sweeps the system, and by
PACINGTEST's yield loop — all of which mean *things opposed to the player*. An
allied picket in it would be painted red, blasted by the player's own
area weapons, and counted as a live raid.

So allegiance got its own group, `combatants`, and `hostiles` was left alone.
Two group memberships instead of one derived membership, and the cost is one
extra `remove_from_group` in four teardown paths.

### `take_damage`'s missing argument was the dangerous part

Adding an attacker means touching every call site. The tempting move —
`take_damage(amount, attacker = null)` — compiles all of them silently, and
**neither default is safe**:

- `null` means "nobody" → every legacy call stops dropping loot, and the
  economy dies quietly. PACINGTEST would report a yield of zero and the pacing
  band would collapse.
- `null` means "the player" → every future NPC caller that forgets the argument
  mints player credit for a kill nobody made.

The argument is therefore **required, with no default**, on both hostile
classes. A forgotten attacker is a parse error rather than a mis-booking.
`ATTRIBUTION IS EXPLICIT` reads both files and fails if a default ever appears,
because the dynamic check cannot see a call site that is never exercised.

`ApexBoss.take_damage` is the one exception and takes `_attacker` with a
default. Its death is attributed by a different mechanism entirely
(`on_apex_defeated` → `mark_apex_down`, with the bonus riding on cracking the
wreck), and nothing but the player has ever been able to damage one.

### The change nobody asked for, found by making attribution honest

The apex scraps its own pending probes on a phase change and on death.
`probe.take_damage(99999.0)` went through the ordinary swarm death path, so
**every one of those probes paid the player two loot crates and ticked a
`kill_swarm` contract.** They are specifically the probes the player *failed*
to kill during the seal — the ones that were about to weld a plate shut.

They now pay nothing. This is a deliberate behaviour change, not a refactor
artifact, and it is recorded here because it is invisible in a diff that looks
like a signature change. It does not move `PACING_LOOP`, which has no apex term
at all (the first-kill bonus is excluded by omission from a hand-written sum),
and it does not move BALANCE, which measures seals and phases rather than loot.

### A matrix that can be asserted

The user chose a **full dynamic matrix** over a scalar-plus-static-table, and
**player actions only** over seeded drift. That combination is what makes it
defensible: `shift_faction` is the only mutator, nothing calls it from a timer,
and `NO INPUT, NO DRIFT` runs the world for real, advances the clock an hour,
and requires the delta store to still be **empty**.

Empty is the load-bearing word. Deltas are **sparse by invariant** — a value
driven back to zero is erased rather than stored — so "the player has changed
nothing" and "the dict is empty" are the same statement, and one check covers
all 240 ordered pairs instead of touring them. `ZERO IS ABSENCE` in
`SAVETEST=migrate17` is what stops that invariant quietly lapsing.

The baseline lives in `FactionDB` and the arithmetic lives in `GameState`, and
the split is §39's cycle lesson: `FactionDB` names no scene class and no
autoload, because `hostile.gd`, `swarm_hostile.gd` and `main.gd` all name *it*.
An autoload is outside the `class_name` registry, so it is the one place that
can read both the table and the save without closing a loop that would declare
every class in the project undeclared.

### v18 is the first migration with nothing to grandfather

v15 could revoke a lane; v17 had to guess which engines were down. v18 needs
neither, and the reason is worth stating: **the authored baseline IS the world a
v17 save was written in.** Every hostile is `feral`, `feral` is HOSTILE to the
surveyor, nobody is allied with anybody. An absent key arriving at the baseline
reproduces that save's reality exactly, so there is nothing to infer and nothing
that could be taken away.

### Two defects the review caught before the harness could

Both are recorded because neither would have failed loudly.

**A lambda captures a local by value.** The kill counter was
`var kills := 0` with `kills += 1` inside a signal handler — which increments a
copy and leaves the outer variable at 0 forever. The assertion would have read
"no kills were credited", which is exactly what half of
`ATTRIBUTION GATES THE PAYOUT` wants to hear. It is a one-element Array now, and
the reason is written above it.

**A self-pair is canonically ordered.** `pair_key("gsa", "gsa")` is legitimately
`"gsa|gsa"`, so the load path's canonical-ordering check waved a self-delta
straight through — the one entry `faction_attitude` can never read back, since
it short-circuits on `a == b`. Rejected explicitly now, and
`THE MATRIX REJECTS RUBBISH` fires four separate attacks at that function.

A third was caught in the moved code rather than the new code: `SwarmHostile`'s
`_departing` branch had drifted *below* the target lookup, so a paid-off raider
whose target docked would have stuttered from burn-out into idle drift at
exactly the moment a raid ends. It is back above the lookup, with a comment
saying why it lives there.

## 48. The hull gives a bearing

The tutorial's finale ends on the PYX-01 breach, and until now that breach
handed over a *statement*: PYX-02 is charted, the lane is jammed, silence THE
GNOMON. It never handed over a **direction**.

### The gap was that the free hint was spoken but never filed

The lane-obstructed broadcast (`main.gd`, on `system_unlocked`) already tells
the player the band and the quadrant — "transmitting from THE DRIFT, bearing
WEST". It calls `hud.show_broadcast` and stops there. It does **not** call
`file_apex_intel`, so nothing enters `apex_intel`, and the chart panel goes on
saying *"no intel. It is transmitting from somewhere in the shaded band."*

So the opening of the hunt was a sentence the player had to hold in their head
against a plot that disagreed with it. That is the gap this closes.

### One rule, three systems, and the geometry does the difficulty

**Cracking a system's own derelict reads a bearing on that system's engine off
the hull's log.** It is filed through `file_apex_intel` like every other
channel — the sixth thing that could teach you where the engine hides is now
the seventh — so it narrows the ghost, shrinks the search circle, and prints
the same `INTEL — THE GNOMON · BEARING 137 ±20° · SEARCH ±NNNu` line the paid
readings print.

It sits **inside the `counts_as_survey` guard**, beside `mark_breached` and
`arm_apex_wake`, for exactly the reason charting does: a deep hulk is a payday
found by going looking, and letting one 400u off the map hand over the opening
lead would let the expanse skip the hunt as well as the spine.

It is filed **after** `mark_breached`, and the order is the beat. Charting
fires `system_unlocked`, whose handler broadcasts "…silence it and the way is
yours" — the player is told there is a hunt, and *then* told which way to
point. Filing first would answer a question nobody had asked yet.

### 20°, and why it must stay the widest cone in the game

Every other bearing channel is earned or bought:

| channel | cone | how |
|---|---|---|
| **hull (this)** | **±20°** | **given, once per system** |
| cleared guard post | ±15° | earned, out in the deep |
| read relic | ±12° | earned |
| survey mast | ±8° | earned |
| the Last Watch | ±5° | 900 salvage, band 4 |
| rift | ±4° | rare |

The free one has to be strictly worse than all of them or the intel economy is
undercut by the thing the player gets for nothing in the first twenty minutes.
`THE OPENING BEARING IS THE WIDEST` asserts it against the real constants —
except `guard` and `relic`, which are inline literals with no constant to read
and are therefore restated in the harness. That gap is named in the comment
rather than papered over; naming those two is worth doing next time either
file is open.

One number serves all three systems because the lair radii do the scaling. A
±20° cone spans `2·r·tan(20°)`:

    PYX-01   lair at radius  300- 380   cone  218- 277u across
    PYX-02   lair at radius  668- 828   cone  486- 603u
    PYX-03   lair at radius 1194-1494   cone  869-1088u

A real lead on the first hunt and nearly worthless on the last, which is the
correct shape: the deep hunts are supposed to be bought, not given.

### What did NOT need building

"PYX-02 should only be reachable after the PYX-01 engine dies" was already
true, and checking before building is the only reason it did not get
reimplemented. `on_apex_defeated` calls `open_lane`; `travel_to` refuses a lane
that is not open; breaching only ever *charted*. That is §38's two-tier gate,
shipped in v15, working as designed.

### The assertion that drives two real hulls

`THE HULL GIVES A BEARING, AND ONLY FOR A SURVEY` builds a charted derelict and
a deep hulk, breaches each through `hold_begin`/`hold_tick` against a real
player ship, and requires **1 hint + charted** from the first and **0 hints +
not charted** from the second. Both directions in one measurement, because
either half alone passes on broken code: "a deep hulk files nothing" is
satisfied by a game where nothing files anything.

Two details in it are lessons already paid for elsewhere. The player is
re-pinned inside the loop every frame, because `hold_tick` releases the hold
and issues a move order the moment the ship drifts out of `CRACK_RANGE` — a
single teleport before the loop is a hold that silently stops progressing.
And `breached` is snapshotted and restored rather than cleared, because five
more assertions run after this one and a harness that empties world state on
its way past is how the next check inherits a failure it did not cause.

### §47/§48 postscript — what running the engine actually caught

Both sections above were written without a Godot binary to hand. Fetching a
headless 4.6 and running the sweep turned up three defects, and the split
between them is the lesson.

**Two were parse errors no static review could reach.** A multi-line boolean
missing its `\` continuations (GDScript only continues implicitly inside
brackets), and a `var charted` colliding with one declared earlier in the same
function — GDScript scopes to the whole function, so a second declaration is an
error rather than a shadow. Both stop the project loading *entirely*. A
bracket-and-duplicate linter reported both files clean; the engine did not.

**One was a real regression, and it is the interesting one.**
`SAVETEST=write`'s new v18 fixture was filed *after* the captain's-log fill —
and `shift_faction` notes a log line whenever the player is party to a shift
(finding A10: standing the player changed and cannot see is a haunting, not
politics). So the fixture pushed `THE GRIN — STANDING RISES` into a
ten-entry ring, evicted `LOGBOOK ENTRY 02`, and failed `v12 CAPTAIN'S LOG`.

The assertion was working perfectly. What it caught was **a side effect of the
new code reaching a suite that had nothing to do with factions** — which is
exactly the failure mode a save harness with distinct sentinels exists to
surface, and it surfaced it on the first run. The fixture moved above the log
block; nothing about `shift_faction` changed, because its logging is the
feature.

Write it down for whoever adds the next standing-aware harness: **`shift_faction`
mutates the logbook.** Any suite that pins log contents must file its standing
changes before it fills the ring.

**And the economy did not move**, which was the whole risk of the attribution
rewrite. Measured against the numbers §46 recorded:

| assertion | §46 recorded | measured at v18 |
|---|---|---|
| `MIDTIER` (binding) | 2.91 | **2.92** |
| `CEILING` | 0.041 | **0.041** |
| `ROUTE PARITY` | 1.0% | **1.1%** |

with `swarm 98/kill` and `sentry 671/kill` — non-zero, which is the direct
evidence that player-attributed kills still pay. Had attribution been wired
backwards, those two would have read zero and `MIDTIER` would have collapsed
through its floor. The 0.01 is loot-roll noise.

## 49. Factions — stage 2a, the Cordon

The Authority gets ships. Nine patrol routes across three systems — two in
PYX-01, three in PYX-02, four in PYX-03, scaling with how much the Authority
has to lose — walked as loops by `Hostile` nodes flying the `gsa` flag.

**A picket is not a new class.** It is the same machine the expanse already
dresses out as *"GSA PICKET — DECOMMISSIONED"* (`GUARD_DESIGNATION[1]`), alive
and painted, and the tell is paint rather than a new silhouette — the raider
precedent, applied again. Stage 1 had already built the hard half: a `gsa`
picket refuses to fire on the player at any standing, and pays nothing when it
kills, both asserted before a single route existed. **Stage 2a writes movement,
not targeting.**

### The routes are the entity budget

Each route is drawn to pass within engage range of exactly **one** sentry post.
A system therefore has as many standing skirmishes as it has routes and no
more, which is what keeps NPC-vs-NPC combat legible on a 720-wide phone and the
frame cost knowable. This is the §7 promise — "the entity count of ambient
NPC-vs-NPC combat is a route-authoring decision, not an emergent one" — made
literal in the data.

### Three decisions that removed code rather than adding it

**There is no "returning" state.** A picket with nothing to shoot walking to
its next waypoint *is* returning. A third state would be a second thing to keep
true for no visible difference.

**The route is a loop.** Ping-pong needs a direction flag and an end-detection
branch to say the same thing on screen.

**The chart-edge rule is policed by the harness, over the authored table.**
Three options, two rejected: a runtime clamp would drag a picket home and
satisfy the assertion while hiding the authoring mistake; an `assert()` is
stripped from release builds *and* would be the first in this codebase
(`assert(` appears zero times). A data-level check fires on the authoring
mistake before a picket is ever built, which is strictly earlier than either —
the shape `DeepPortDB.violations()` and STATIONTEST's guard-rail sweep already
use.

### The anchor, and why measuring from the picket is fatal

`_worth_leaving_the_beat` measures engage range from **the waypoint the picket
is walking to**, never from the picket. A picket measuring from itself drifts
outward along its own engagements — every individual step looking correct while
charted space quietly goes unguarded. The beat is the anchor, and the hysteresis
pair (12 to pick a fight, 25 to keep one) is the same shape as the apex's
WAKE 60 against LEASH 120.

### Two branches that cannot be unified

Station-keeping **assigns** `_home + wander`; a patrol **adds** `wander * delta`.
A moving picket whose position were assigned from a wander term would have its
travel overwritten every frame and never leave the spot — this file's own
`_home`-on-frame-one defect, reintroduced from the other direction. `PICKETS
WALK THEIR BEAT` red-verifies to `moved 0.4u, 0 waypoints`.

### The parley is the player's conversation

`break_parley` fires when a raider takes damage from *anyone*, so a picket that
peeled onto a pack mid-standoff would answer the demand on the player's behalf
and delete the choice the interdiction is built around — permanently, everywhere
in charted space. Finding A3, closed: a picket refuses to engage a raider whose
`standoff` is live, and the assertion checks the **refusal to engage** rather
than "the standoff survived", because the picket must not pick the fight in the
first place.

### What the engine caught that review did not

**A crash in stage 1's shipped code.** `_targetable(n: Node3D)` dies on a
cached `_aggro`/`_target` that has since been freed: GDScript validates an
Object argument against its declared class **at the call boundary**, so the
freed node fails there, before `is_instance_valid` inside can run. Six script
errors per run. Stage 1's own suite never froze a node mid-test, so it never
saw one; the Cordon's longer runs do. Both hostile classes take an untyped
parameter now, with the reasoning written above it.

**And an assertion of mine that passed on broken code — the third time this
project has shipped one.** `THE BEAT IS THE ANCHOR` originally marched a chain
of contacts away from the route to prove a picket would not ratchet outward.
It cannot: `_combat_target` returns the *nearest* enemy, so the picket locks
onto the first contact and stays put under the bug exactly as under the fix.
The setup was elaborate and measured a world in which the defect cannot express
itself.

The rewrite is a **contact near the middle of a leg and far from both
endpoints** — 10u from a picket standing mid-leg, 22.4u from the waypoint it is
walking to. Route-measuring ignores it; self-measuring chases it. Asserted as a
pure-function call at a placed position rather than over frames: no timing, no
flake, and both clauses flip when the bug returns. A positive control (a contact
genuinely near the waypoint, which *must* be engaged) sits beside it, because
"returns false" is otherwise satisfied by a function that always refuses.

Two lessons, and the second is the general one. Frame counts are not time —
headless Godot runs frames as fast as it can, so `for i in range(360): await
process_frame` was an unknown and machine-dependent amount of simulated time,
and it measured 8u of a 12u leg on the first run. Both timed checks are
specified in seconds now, because the thing they measure is specified in units
per second. And: **be most suspicious of an assertion whose setup is elaborate.**
The elaborate ones are where a world that cannot express the bug hides.

### One assertion got stronger rather than excluded

The sweep came back with `SENTRY POSTS` failing — it sweeps every `Hostile` and
requires each within 0.6u of an authored post, and a picket is a `Hostile` 36u
away by design. The cheap fix is to skip pickets. That makes the line *weaker*:
a Cordon that silently failed to deploy would make every remaining clause
happier and nothing would say so.

So pickets are excluded, **counted, and the count asserted against the routes
the system authored** — following this line's own precedent, where the
deep-guard count was already printed rather than swallowed for exactly that
reason. It now catches two distinct failures where it caught one.

## 50. Factions — stage 2b, the hulls move outside the cordon

The survey hull no longer sits twenty units from the Anchor. It is 100u past
PYX-01's chart edge, 130u past PYX-02's, 150u past PYX-03's — and each one sits
on **the bearing its old authored point already lay on** (243, 304, 257
degrees), so the fiction is that the field drifted rather than that a designer
moved it.

`SystemDB.derelict_pos` is the only function that answers "where", for the same
reason `lair_pos` is: two places deriving it independently will disagree, and
the tutorial's broadcast, the expanse's keep-out and four harnesses all need
the same answer. It draws from **no RNG at all** — an authored bearing takes
no number out of the sequence the expanse rolls from — so `WORLD FINGERPRINT`
cannot move.

### Clearances that are provable rather than lucky

    depth 100 / 130 / 150   all band 1, where PACK_CHANCE is 0.0
    hull-to-lair gap        >= 160u against LAIR_KEEPOUT 120, for ANY bearing

The band matters because the Shoals generate **no procedural packs at all**, so
a tutorial-fresh pilot's first trip past the marker meets exactly the authored
sentries and nothing else. The gap is checked against the authored band
*minimum* rather than against this run's rolled lair: the two bearings are
independent, so a seed that happens to separate them proves nothing about the
seed that does not.

`HULL_KEEPOUT` is **40**, not the lair's 120, and the difference is what each
protects. A lair is an ARENA — the leash says everything inside it is the
fight, so nothing that is not the fight may be there. A hull is a DESTINATION
with a 6.5u interaction range: it needs elbow room, not solitude. It suppresses
stations and hulks — two crackables a few units apart, one of which charts the
next system, is the most confusing object this game could produce — and
deliberately leaves nests alone, because something drifting in to guard a wreck
out past the cordon is the fiction working rather than the generator misfiring.

### The tutorial ends one step earlier than it used to

It used to finish by OPENING the world: the breach charted PYX-02 and handed
over a frontier. The survey hull is outside charted space now, so the guided
run teaches the verb on a small **training hull** on the old berth and then
tells you where to go and use it — a bearing and a distance, read from
`derelict_pos` so the copy cannot disagree with the world.

`counts_as_survey` carries the progression, and the flag already existed: deep
hulks have used it since the expanse shipped, and it already means "charts
nothing, wakes nothing, files no bearing". **No new gate was designed and no
new class was added.** With two crackables in PYX-01, three call sites that
said `get_first_node_in_group("crackable")` stopped having a defensible answer
and now go through `_find_survey_hull()`; the tutorial's own two go through a
`training_hull` group.

### The relocation was a stealth pay rise, and PACINGTEST caught it

`spawn_loot` re-grades a fraction of every drop by **the band it is spilled
in**. Move the hull from depth 0 to depth 100 and the identical hull, cracked
identically, starts paying band-1 salvage:

| | before | after the move | after compensation |
|---|---|---|---|
| derelict yield | 5022/hull | **5423/hull** | 5067/hull |
| `MIDTIER` (binding) | 2.92 | **2.98** | **2.92** |
| `CEILING` | 0.041 | 0.042 | 0.041 |

2.98 against a hard ceiling of 3.00 **passes**, and is still wrong. Nobody
asked for that raise; it fell out of a geometry change. And 0.02 of headroom is
not headroom — the next change to touch loot anywhere would have broken the
binding assertion for a reason that had nothing to do with it.

Loot came down 70 → 64, 95 → 87, 130 → 119 to hand it back, and the reasoning
is written into `system_db.gd` rather than only into a commit. The player gets
**the same hull for the same work, further away.**

This is finding A8 of HORIZON-4 resolved the way the doc demanded — "the number
will move, and it must be recorded rather than reasoned about" — and it is the
second time this horizon that the honest answer was to measure, decide, and
measure again rather than to argue about whether a change was neutral.

## 51. Factions — stage 3, the engines own their systems

Every ambient machine in a charted system now flies its host engine's flag.
The sentries standing over the lanes, the waves that keep arriving, the probes
an apex vents — all of it belongs to THE GNOMON, THE ARMILLARY or THE MERIDIAN,
which retcons something that was always latent: the dead frontier's automata
were never masterless, and silencing an engine is **taking a system off a
government** rather than switching off a machine.

The interdiction raiders become **THE TITHE**, pulled forward from stage 5
because it costs one line and because stage 2a's picket parley exemption was
guarding a case that could not occur while raiders were `feral` and the Cordon
was neutral to `feral`. Crimson paint, a demand, a toll and a parley all
shipped long before the faction layer; now they have an owner.

**Bands 3 and 4 stay unflagged**, and that restraint is the design. The Reaches
and the Quiet belong to the three powers nobody has a word for yet, and the
shipped data already says so — `GUARD_DESIGNATION[3]` is *"UNFLAGGED — NO
PATTERN ON FILE"* and `[4]` is *"UNREADABLE — IT DOES NOT ANSWER"*. Claiming
them for a known faction now would spend stage 6's reveal early **and make the
designation a lie.** `THE DEEP IS STILL UNCLAIMED` asserts the rule rather than
a node, so a future band edit cannot quietly annex them.

### The problem stage 3 creates, and the fix that was not enough

A picket and a sentry are **the same machine** — both `Hostile`, both taking
the system's `difficulty`, neither setting `hp_scale`:

    120 hp against 14 damage every 1.15s = 12.17 dps -> 9.9 SECONDS to a kill

and because `difficulty` scales hp and damage *together*, it is 9.9 seconds in
every system. Left alone, the moment sentries became `gnomon` and pickets were
already `gsa`, ambient skirmishing would have traded the Cordon away within half
a minute of the player arriving — tier 1's entire visible payload deleting
itself while the player was somewhere else.

The disengage timeout (finding A6) is the obvious answer, and **on its own it
does not work.** Breaking off does not undo damage: three six-second bursts
still land 219 against 120. `AMBIENT COMBAT DEPLETES NOTHING` caught it at
**census 9 → 5** in 54 unattended seconds, and it would have shipped otherwise
looking entirely correct.

So there is a second half. `SKIRMISH_HP_FLOOR` — fire from another combatant
wears a machine down but **cannot take it below half hull**. A sentry sitting
at half strength is visible evidence that the border is contested, which is the
whole reason the routes were drawn to cross a post in the first place; the last
half of any hull belongs to the player.

> **The property this protects, stated once so nobody trades it away later:
> ONLY THE PLAYER DEPLETES THE WORLD.** Sentries do not respawn, and that has
> always been fine because clearing a post is work the player did. A world that
> empties itself unwatched is a different thing, and not one anybody asked for.

Census now holds 9 → 9, and red-verifies to 9 → 8 with the floor removed.

### The floor's own trap, caught before the sweep

Gated on *"the attacker is not the player"*, the floor would have caught
`ApexBoss` scrapping its own pending probes — `take_damage(99999, self)` on a
phase change — and left them alive at half hull **through the phase they exist
to be cleared by**. It is gated on the `combatants` group instead, which
`ApexBoss` is not in. The lesson generalises: "not the player" and "another
combatant" are not the same set, and the gap between them is every machine that
damages something without being a faction.

### Three assertions re-aimed rather than weakened

Making picket-vs-sentry combat real broke three checks written for a world
where it was not. Each was rewritten to its actual claim:

| was | is | why |
|---|---|---|
| `FERAL IS THE ONLY THING HUNTING YOU` | `ONE FLAG HUNTS YOU, AND IT OWNS THE SYSTEM` | `feral` is no longer in the sky at all; the surviving claim is *stronger* — exactly one player-hostile flag, and it is the host |
| Cordon floor: target `== null` | target is **not the player** | a picket with sentries around it legitimately has a target; asserting emptiness fails on correct code and says nothing about the floor |
| `PICKETS WALK THEIR BEAT` on a central route | same test in empty sky | it was measuring a firefight instead of a patrol |

The first is the pattern worth naming: **when a stage makes an assertion's
world obsolete, find the property that survived and state it more strongly.**
Deleting the check loses the guarantee; loosening it keeps a check that cannot
fail. This is the second time this horizon that widening produced a better
assertion than the one it replaced.

### §51 postscript — two numbers, measured rather than argued about

Stage 3's sweep read `MIDTIER` at **2.95** against 2.92 the run before, and a
5% jump in the derelict term. The instinct is to cut loot again. **Six samples
of identical code say do not:** 2.84, 2.89, 2.90, 2.92, 2.94, 2.95 — mean
**2.91**, exactly where it sat before stage 3. The derelict term alone swings
4771–5339 per hull, ±6%, which is most of the spread.

So the stage-2b compensation was right and stage 3 moved nothing. Tuning from
the single 2.95 would have been the mistake §41 records this project making
twice with `PHASE INTEGRITY` — setting a bar against one look at a
distribution nobody had measured — with the sign flipped.

**Write the spread down, because the ceiling is close.** `MIDTIER` is 2.91 ±
0.05 against a hard 3.00, so a good roll reads 2.95 and real headroom is about
0.04. Anyone adding income needs four samples, not one.

The same session's `STREAMTEST` failure is the same shape. Its **mean** is
stable across every sweep — 6.93, 6.97, 6.98, 7.37, 7.40ms — and did not move
when stage 3 put NPC-vs-NPC combat into a live system. Its **worst** clause is
a single-spike measure ranging 17–48ms against a bound of 40; it went red once
in-sweep and passed 4 of 4 alone. That is a third flaky assertion, and the fix
is the one §41 already describes: re-derive the bar from the distribution
rather than nudge it until the sweep goes quiet. Recorded, not done.

## 52. Factions — stage 4, THE MUSTER

A massed column gathers 75u outside the charted volume and marches in. The
Cordon amasses **at the chart edge** and holds the line there.

### The fiction resolves the constitutional problem

The band-1 beacon has promised since v13 that *"security patrols do not operate
beyond this marker"*, DEEPTEST pins the words, and stage 2a turned them into an
assertion about ships. A relief fleet sallying out to meet the column would
break all three at once.

So it does not sally. **The Cordon forms up ON the marker and waits.** The
player can fly out and meet the column early — alone, past the line, exactly as
the beacon warned — or stand with the Cordon and let it come. The event
*teaches* the game's territorial rule instead of bending it, and `THE LINE IS
THE EDGE` asserts no cordon ship is ever past the marker.

The column comes down the **survey hull's bearing**, which already means
"outside" in every system: the direction the hull drifted, the direction the
unlock hint sends you, and now the direction things come from.

### The march

`SwarmHostile` gained its first non-orbit movement. Everything it has ever done
is expressed relative to a thing it is circling; a column is expressed relative
to a *place*, at 2.8u/s — `MAX_SPEED` 7.5 would cross 75u in ten seconds and
the event would be over before the advisory finished reading.

It is held until something is genuinely in reach, checked against
`ATTACK_RANGE`, not against "has a target": `_combat_target` returns the
nearest hated thing at *any* distance, so a column that halted the moment it
could see the far side of the line would never cross at all.

### Set-piece ships are exempt from the ambient floor

§51's `SKIRMISH_HP_FLOOR` exists so the world does not empty itself unwatched.
A muster is announced, bounded and cleaned up after — and **supposed to
resolve.** A line that could not break and a column that could not be stopped
would be two crowds of machines shooting each other forever, which is the
opposite of a set-piece.

### Nothing bankable, and the printer that revealed

The muster drops no loot, pays no salvage, and reports kills as `"muster"` —
a kind no contract in `contract_db` asks for, so the fastest `kill_swarm`
filler in the game cannot be farmed. `PACING_LOOP` sits at 97% of its ceiling
and a recurring event that paid would be recurring income whatever it was
called.

Writing that gate exposed **a money printer stage 2a shipped.**
`Hostile._die` paid loot and kill credit on *any* player kill, so a Cordon
picket was worth 14 crates and a `kill_sentry` tick. Pickets never return fire
— the WARY floor guarantees it — and they **rebuild on every `_load_system`**.
Warp out and back and you minted a fresh row of non-retaliating piñatas on
demand. That is §27's deep-hulk printer with a badge on.

The rule is now three questions, not one:

    1. did the PLAYER do it        (stage 1's attribution)
    2. was it HOSTILE to them      (closes the picket printer)
    3. is it a MUSTER ship         (closes the event)

and shooting something that was not shooting at you costs standing instead.

### Radar clusters by force

32 machines on a 12-marker board is a border of identical arrows. A muster
renders **one marker per force**, at the centroid, by marking every muster node
`seen` — the dedup mechanism that already existed — so the cap is sidestepped
rather than the tier system reworked.

### The assertion that was passing on timing

`THE MUSTER CARRIES NOTHING` originally ran *after* the budget sweep. That loop
runs until the column is exhausted, so the muster had often already resolved
and there was nothing left to shoot: it reported `-1 cubes` and passed or
failed on timing rather than on the payout ban. Moved above the sweep, the
red-verify reports the real failure — **2 cubes dropped**.

That is the fourth green-assertion-testing-nothing this project has caught, and
the third this horizon. The tell each time was the same: **elaborate setup.**

## 53. Factions — stage 6, the deep gets its names

THE TALLY holds the Reaches. THE HOLLOWING holds the Quiet. THE STILLNESS
keeps the light on at the Last Watch.

They are **named for what they leave behind**, because nobody has ever spoken
to one. Every other faction in this game is named by somebody who deals with
it — a charter, a combine, a banner. These are named by the survey register
describing an effect it cannot account for. The ids were fixed in stage 1 as
`unknown_a/b/c` precisely so this moment cost no migration: ids are permanent
save keys, names are copy.

### Bands 3 and 4 change hands, and the designations stay true

Stages 3–5 deliberately left the Reaches and the Quiet unflagged so the shipped
data stayed honest: `GUARD_DESIGNATION[3]` is *"UNFLAGGED — NO PATTERN ON
FILE"* and `[4]` is *"UNREADABLE — IT DOES NOT ANSWER"*. Those bands were never
nobody's — they were **nobody the register could name.** Now they have names
and both lines are still literally true: the register still cannot read them,
and band 4's beacon still does not answer.

`THE DEEP IS STILL UNCLAIMED` became `THE DEEP BELONGS TO THE UNKNOWNS`, and
the replacement is the stronger claim — a host engine reaching past band 2 or a
chart power owning a nest out there now both fail, and **nothing is `feral` any
more**, because `feral` meant "no owner yet" and there is no yet left.

### One tell each, not one weapon each

§13 binds the unknowns too: alien has to read as a convention broken **in the
open**, never as a mechanic the player cannot see.

| | the tell |
|---|---|
| **THE TALLY** | No leash. Everything the expanse seeds carries `HOSTILE_LEASH` so a pack picked up far out does not follow you home. This one has none. It does not lose you. |
| **THE HOLLOWING** | Cannot take your last point of shield. It strips a ship to a sliver and cannot finish it. |
| **THE STILLNESS** | Neutral, and it trades. Two of these kill you on sight; the third sells you a drink and nothing explains why. |

The Stillness is the answer to *"Still lit. Nobody is sure who is paying for
it"*, which has been in `deep_port_db.gd` since the deep ports shipped. Its
neutrality is load-bearing in both directions: stage 5's fence gate shuts a
back room to a HOSTILE player, so a hostile Stillness would have **bricked the
deepest fence in the game as a side effect of a name.**

### The design error, and the test that could not be written

The Hollowing was first built to clamp its fire to the shield **remaining** —
"it drains your shield but never your hull". That describes a two-layer health
model **this game has never had.** `PlayerShip` has no hull: `shield` *is* its
health, and `take_hit` downs the player at `shield <= 0.0`. Clamping to the
shield remaining lands exactly on zero.

So the faction whose entire identity is *cannot kill you* would have killed
you — reliably, out in the Quiet, where dying costs the most.

**It was found because the assertion crashed**, on a `hull` property that does
not exist. That is the first time in this project's history that a wrong TEST
exposed a wrong DESIGN rather than a wrong implementation: the check could not
even be *written* against the model that had been assumed. The clamp leaves the
last point now, and `THE HOLLOWING CANNOT KILL YOU` red-verifies to
`shield 0.00 left, still flying=false`.

### The Cordon's line was a chord across a circle

`THE LINE IS THE EDGE` went red at **0.4u past the marker**. The muster's line
was strung straight across the bearing — but `chart_edge()` is a RADIUS, so a
straight line on a circular boundary bulges outside it at the ends, and
`Hostile`'s 0.4 station-keeping wander pushed the outermost picket over.

Small, silent, and a direct breach of the promise the band-1 beacon has been
making since v13. Stage 2a turned those words into an assertion about ships
exactly so this could not creep in, and three stages later it caught it. The
line sits on an **arc** now — fixed radius, spread of bearings — with a 3u
inset the wander cannot overcome.

### An ambient event that logs also saves

`SAVETEST`'s captain's-log fixture came back with `THE PROCESSION — IN PYX-01`
as its tenth entry. `note_log` calls `_queue_save()`, so the convoy's arrival
fired a debounced write a second after the harness had explicitly saved, and
overwrote it.

The fix is a design call rather than a test fix. The log is ten slots and it is
for **things that happened to you**; a convoy arriving every twenty minutes
would own three of them within an hour and push out the tolls, the kills and
the frontier. The toast announces it; the log stays the player's.

That is the third time this horizon a *logging* side effect reached a suite
with nothing to do with the feature. Written down as a rule:
**anything ambient that logs, saves.**

### Two of my own assertions were measuring the wrong quantity

Both passed alone and failed in-sweep, which is the worst way for a check to be
wrong.

`PICKETS WALK THEIR BEAT` measured **net displacement on a closed loop** — a
picket that walks its route perfectly ends up where it started, so the reading
was decided by where in the loop the clock stopped. It read 15.0u, 4.2u and
1.8u across runs of identical code. It sums path length now.

`AMBIENT COMBAT DEPLETES NOTHING` parked the player at depth 360 to keep them
out of the fight — **inside the band where the expanse seeds nests**, so the
census grew by two while the assertion watched for it to shrink. It disables
deep generation first now, as every harness that puts a ship outside `bounds`
already did.

The second is the assertion working: it noticed machines appearing in a census
that was supposed to hold still. It simply could not tell me they were its own.
