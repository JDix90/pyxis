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
officer/crew collection; a three-tier map hierarchy; and any lookalike of the
reference's licensed IP (ship silhouettes, insignia, HUD layout, naming).
Divergence is checked at every art review — the amber-cartography identity is
the mitigation.

### Base building: exclusion LIFTED (2026-08-04, user decision)

It was on that list and it is not any more. The reasoning for removing it, and
the boundary that survives, both matter more than the removal.

**Why it was there.** Read the company it kept — timer monetization, energy
gates, crew gacha. Base building was excluded as one more *free-to-play
retention pattern lifted from the reference*, where a base is a thing you queue
upgrades on and come back to when a clock says so. That objection is intact and
is not what has been lifted.

**What is now allowed.** A place in the world the player owns and changes, in a
single-player game with no clocks, no queues, no currency sink pretending to be
a decision, and nothing that rewards logging in rather than flying. If a
structure takes time to become something, the time is *spent flying to it with
what it needs* — the trip is the cost, which is the trade the whole game already
rests on. Nothing may be built by waiting.

**The user's reason, recorded as given:** it makes the game endlessly more
interesting, and the complexity is accepted.

**What this does NOT authorise.** It is a lifted exclusion, not a queued
feature. Colonies (§64's stage 6, and the horizon that builds it) remains
**claim-and-travel**: you find a structure, clear its wardens, and it becomes a
fast-travel anchor. Nothing is constructed there yet. Base building, if it is
built, is its own horizon with its own spec and its own economic argument.

**And that argument is the open question, stated now so it is not discovered
late.** `PACING_LOOP` sits at ~97% of its ceiling with `MIDTIER` at 2.90 against
a hard 3.00 (§51, §63). Every construction system ever built is a sink that
becomes a source; this one has roughly 0.1 of a lance in headroom to be wrong
in. A base-building horizon starts by re-deriving the pacing band, not by
authoring a build tree.

**One thing this changes today, cheaply.** Because a claimed colony is exactly
where a construction layer would hang, stage 6 persists `colonies` as a
**dict per instance rather than a set of keys** — the same shape `apex_intel`
uses. It costs nothing now and means a later horizon adds fields instead of a
save migration.

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

*(v21, §80: survey coverage now persists, and it does not breach this rule —
it is not a visited-cells array. It records only cells where a mast was
**worked**, one write per deliberate act rather than per minute flown — §26's
"passive growth" distinction, applied a second time — and it is capped per
system with oldest-first eviction. The generation itself remains pure and
unsaved; what is stored is what the player did, never what the world is.)*

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

### A survey resets on warp ~~, and that is asserted on purpose~~ — REVERSED, v21

**This rule was reversed by §80.** It stood from v16 to v21 and worked as
designed to the end: `SESSION RESET` existed to force a conversation before
anyone persisted the dict, and that is exactly what happened — the leg was
flipped to `THE CHART REMEMBERS` in the same commit that answered its
objection. The original text follows, kept because the *argument* still
constrains the shape of what replaced it:

`_surveyed` was session-only, like `_sprung`, because persisting it naively
would be a visited-cells array by another name — the thing §17 refuses because
it grows every minute the player flies. §80's answer is a store that records
**worked** cells only, capped per system with oldest-first eviction: growth per
deliberate act, bounded by construction. `_sprung` and `_cracked` and `_mined`
remain session-only; the growth argument still holds for all three.

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

## 54. The playtest found what 489 assertions could not (v18)

The horizon shipped, the sweep was green, and the first thing the player said
was: *"I'm not really seeing the factions, and I'm not seeing the local
security patrols at all. The massive swarm formed, came to the edge of charted
space, and then just left without any battle."*

All three observations were correct. Three defects, and every one of them was
sitting behind an assertion that passed.

### The garrison had two halves and only one was restored

A new game builds its system with the garrison held back — nothing shoots at a
player still being told which key moves the ship — and then restores it **in
place** five seconds after the finale, because a rebuild there would delete the
breach loot the player just earned.

Stage 2a added the Cordon to the hold-back and did not add it to the put-back.
`SystemBuilder.build()` gained `_build_patrols`; `spawn_sentries()` did not. So
a player who pressed NEW SURVEY got sentries and **no pickets at all** until
they warped out of PYX-01 — the headline feature of the horizon, invisible for
the whole first session, on the one path every new player takes.

Every Cordon assertion in FACTIONTEST drives `SystemBuilder.build()`. Not one
drove the path out of the tutorial. And `TUTORIALTEST` — which *does* drive the
real path — printed `sentries=%d` from a counter that lumped pickets in with
standing machines, so "sentries=6" was equally true with the Cordon deployed
and without it.

The suppress list and the restore list are one function now
(`SystemBuilder.build_garrison`), so the next thing added to the garrison
cannot go missing from one of them. `_count_sentries` excludes pickets,
`_count_pickets` exists, and both harnesses assert against the authored route
count.

**The rule: assert the path the player takes, not the function it wraps.**

### The muster could never have been a fight

Measured over a whole event, twice: line 960hp → **960hp**, column 816hp →
**816hp**, closed at 23.75s. Twenty-four ships marched seventy-five units,
touched the edge, and dissolved. Not one point of damage in either direction,
every single run.

Two independent causes, and each alone was enough.

**The breach test measured the wrong circle.** The Cordon stands *inside* the
marker — it must, because the band-1 beacon has promised since v13 that patrols
do not operate beyond it. "The line breaks when a column ship gets inside the
marker" therefore fires the instant the first attacker closes to engage the
line, by construction, before a shot. Two decisions that were individually
right and jointly fatal. Breach is measured against the **line** now, plus
`MUSTER_BREACH_MARGIN` — 10.0, derived from the orbit envelope of a ship that
is merely *fighting* the line (ORBIT_RADIUS 3.2 + weave 1.2 + separation 1.8 =
6.2 worst case).

**The skirmish clock counted acquisition, not fire.** `_pick_target` returns the
nearest hated thing at *any* distance — deliberately, since that is what lets a
picket decide whether something is worth leaving the beat for. But the clock
started ticking the moment that pointer went non-null, so a machine spent its
six seconds on a contact eighty units away that it could not shoot, broke off,
and was resting when the contact arrived. `SKIRMISH_TIME`'s own comment says
*"six seconds of FIRE cannot finish that"*. It was written as a weapons timer
and implemented as an acquisition timer.

This one was never about the muster. It made **every** faction fight in the
game invisible — a picket walking its beat past a sentry thirty units away
burned its clock the whole way in and was standing down by the time it arrived.

The clock now counts only while the target is inside weapons range
(`ENGAGE_RANGE` for Hostile, `ATTACK_RANGE` for SwarmHostile). Player targets
are exempt exactly as before, so no balance figure ever measured against these
classes moves.

Measured after both fixes: first contact at 24s, sustained exchange to 43.5s,
line 960 → 745hp, column 24 ships → 3, LINE HELD. A set-piece.

### Why the sweep was happy

`AMBIENT COMBAT DEPLETES NOTHING` is satisfied *perfectly* by a world in which
nobody ever fires. It asserted a guarantee with no partner asserting that
anything happens, so the cheapest way to satisfy it was to break combat
entirely — and that is what shipped, green, for three stages.

Section 19 checks the muster's warning, its line position, its budget, its
payout ban and its logging. Every one of those is true of an event where not
one shot is fired.

**A guarantee needs a partner.** `THE BORDER IS CONTESTED` now requires a picket
and a sentry to *both* lose hull and *both* still be flying — the contested
border and the depletion guarantee in one line, neither clause satisfiable by
breaking the other.

It took **two** red-verifies to make it true, and each revealed a different way
the same assertion lied.

*First:* the pair was placed 4u apart, so acquisition and fire coincided and the
clock never got the chance to burn on an approach. It passed on reverted code.
The picket now starts ~32u out and has to close — 7.8s of travel against a 6s
clock, which under the old rule meant breaking off *before* arrival and standing
down on the doorstep.

*Second:* it still passed. Staged inside charted space, the pair sat among
PYX-01's four authored sentries and the two pickets the garrison check had just
deployed, and **both fixtures were taking fire from machines that were not the
other fixture**. It is staged at radius 200 with generation off now, where
nothing else exists.

Only then did it read what it claims to: reverted, picket **120/120**, sentry
**120/120** — two machines four units apart for eight seconds, neither firing.

Neither flaw was visible in the test's own text; both were found by reverting
the fix and watching the check stay green. **A fixture that starts in range
cannot see a bug about getting there, and a fixture with company cannot see who
shot it.** `THE MUSTER IS A FIGHT` requires both
sides to lose hull before the event ends, and deliberately does not require the
line to win: who wins is emergent and is supposed to be.

### And the tutorial could not be finished by playing it

The `WORLD REOPENED` line above — the observation promoted to a PASS/FAIL —
failed on its very first sweep, with everything at zero: no sentries, no
pickets, no waves. Not the garrison bug. Something worse.

Step 5 completed when the hull left its group:

    var derelict := get_tree().get_first_node_in_group("training_hull")
    # The derelict leaves the group the instant it is breached.
    if derelict == null:
        _complete_step()

The comment is false. `Derelict._breach()` removes itself from `crackable` and
from nothing else, and the node is **never freed** — it stays in the scene as
an opened wreck and stays in `training_hull` forever. The condition could never
become true.

So a player who did what the tutorial asked and breached the hull sat at step 5
with the world still held back — no sentries, no pickets, no waves, no events,
permanently. **The only working exit was the SKIP button**, which calls
`_finish()` directly, and which lands straight on the half-restored garrison.
That is why the playtest reported a live world with no Cordon in it: the two
bugs are the same path.

Shipped in stage 2b, when the step was re-pointed from `crackable` to the new
`training_hull` group without the matching removal. `TUTORIALTEST` drove the
whole sequence every single sweep and printed `sentries=0` next to the words
`(expect >0)`. Fifty-five runs a time, for four stages, printing the answer.

**An observation is not an assertion.** A harness that prints numbers for a
human to read is a harness whose numbers nobody reads. If it is worth printing
`(expect >0)`, it is worth failing on.

### And an event with no bound

Both of the muster's exits are emergent — the column is wiped, or one gets
through. A balance change making neither happen would leave `_muster_active`
true forever, and since `muster_eligible()` and `interdiction_eligible()` both
refuse while one is live, a single stall would silently brick **both** event
systems for the session. `MUSTER_TIMEOUT` (300s, against a measured 43s) closes
it as held and prints why.

### The honest summary

489 assertions, 55 runs, green, and the feature did not work. Not one of the
three defects was subtle in play — a player found all three in a single
session. They were subtle only to a suite that measured positions, counts and
payouts, and never once measured whether anybody shot at anybody.

## 55. Chartfolk convoys: the deep gets traffic (v18)

The known seven had desks and set-pieces and nothing in the sky. Now bands
2–3 (200–1000u out) carry sparse faction convoys: 1–2 escorts walking a 24u
beat plus 3–5 darts marching it, painted in their faction's colour, sprung
once per cell per session off the nest machinery. Roughly 7% of eligible
cells; a cell rolls a pack or a convoy, never both.

### Territory versus traffic

`THE DEEP BELONGS TO THE UNKNOWNS` was in direct tension with this feature,
and the resolution is a distinction, not a workaround: the claim is about
**territory** — `flag_for_band`, who the nests and guard posts answer to —
and territory stays the unknowns' alone. A convoy is **traffic**: it holds
no ground, springs once, walks its beat and leashes away. The assertion body
is untouched; its comment now says which half it pins, and `THE DEEP IS
TRAVELLED` pins the other.

### The nests never knew their band

The prerequisite fix. `plan_cell`'s pack dict carried no `"band"` key and
`_spring` read `pack.get("band", 0)` — so every nest in the Reaches and the
Quiet flew the HOST ENGINE's flag with a 140u leash. The Tally's one tell —
no leash, it does not lose interest — never once fired from a real nest.

`THE DEEP BELONGS TO THE UNKNOWNS` stayed green the whole time because it
asserts `flag_for_band()`, the rule, and never looked at a ship. The rule
was right; every node was wrong. **Assert on nodes, not only on rules** —
the same lesson §54 taught about the tutorial, from the other direction.
`THE PACK REMEMBERS ITS BAND` now springs a real Reaches nest and reads the
flag and the leash off every member.

### The Tally counts what crosses its ground

`unknown_a` went from WARY to HOSTILE toward the seven chart powers. The
convoys' own rows still say nothing about the unknowns — they never fire
first, they answer through the aggro path. So the Reaches is now dangerous
for everyone: a Tally pack will cross to a convoy and open fire, both sides
grind to the ambient HP floor, and the player can stumble into a border
skirmish a long way from any border. Two accepted consequences, recorded:
a Tally pack fighting a convoy is not chasing the player (the tell softens
while the traffic lives), and it will also hunt deep tithe raiders.

### Six factions got paint the day they got ships

bastion cobalt, combine forge-yellow, embers coal-orange, grin acid
chartreuse, league relay-green, procession ash-lavender — chosen against
what shares a deep screen (band violet/bile, Tally bone, tithe crimson,
THREAT beams, TEAL/AMBER markers). The weakest co-occurring pair is
procession vs the Drift's band violet; saturation is the separator. The
colour-vision audit owed since stage 2 is still owed, and now covers 14
tints.

### What the red-verify taught about the fingerprint

The stream-purity red failed to fail: a draw from the shared per-cell rng
placed at the END of `plan_cell` moved nothing, because trailing the stream
is exactly what makes appending safe — every consumed draw already
happened. The same draw at the TOP moved the fingerprint immediately
(3962927774 vs 3836096557). So the WORLD FINGERPRINT guards stream
**order**, not stream **touching**, and the convoy's salted stream is not
protecting today's cells from the convoy block — it is protecting the
convoy from tomorrow's edits, and the next appended feature from the
convoy. A red-verify that passes is not always a broken test; sometimes it
is the rule being more precise than the person who wrote it down.

### The two hazards that are features until they are not

A convoy kill at NEUTRAL pays nothing and costs −1 standing; four kills
flip the pair HOSTILE and from the fifth every kill pays full loot. That
ramp is accepted because the real price is elsewhere: HOSTILE standing
closes that faction's fence — and the grin, league, combine and bastion
fences are the deep stations. The income side is bounded per cell per
session by `_sprung`, the same contract as nests.

Convoy members force-join `"hostiles"` (both classes do, structurally), so
neutral traffic reads as red on an unclustered radar and trips the threat
music at close range. Accepted for now; the radar cluster (one marker per
convoy, faction-tinted, TIER_SITE) is the visible half of the fix.

## 56. The cockpit could not read its own game (v18, playtest round 2)

A playtester reported four things. Three had one root: **the game speaks in
bearings and standings that nothing on the ship reads back.**

### The hint was right and the instrument was missing

"The engine is towards the north" was correct — computed from the boss's
real position, no sign error, no spawn gate. The player still could not
find it, for four compounding reasons:

1. **Nothing said which way north was.** Six channels hand out a `%03d`
   bearing or a compass word and the HUD had no heading instrument at all.
   Worse, the one compass-shaped object in the world — the cartography
   lattice, eight radial spokes on a ring — turned a full revolution every
   240 seconds. Anyone navigating by it drifted 1.5°/s and was never told.
2. **The word was spoken once and destroyed.** The relay broadcast lived
   7.6 seconds on a plate and was never logged and never filed, while the
   chart panel two taps away said *"no intel"* and shaded all 360°,
   contradicting the sentence the player was trying to act on. §48 named
   this gap and closed only the hull-cone half of it.
3. **The search area was enormous and the detection footprint tiny.** One
   straight run due north finds the engine about a third of the time.
4. **The keep-out makes the lair QUIETER than its surroundings** — it
   strips stations, nests, hulks and convoys — so "nothing here, keep
   moving" is exactly the wrong instinct.

The fixes: a `HDG 271 · NORTH` readout that ASKS `quadrant_of` rather than
re-deriving the sector maths; the lattice stops turning; cardinal letters
on the chart plot; the relay's word is filed as a ring hint; the copy says
QUARTER instead of bearing and quotes the authored 80u annulus instead of
the band's 280u name; and a CARRIER WASH line inside the keep-out that says
*here* and never *that way*.

The wash is deliberately not a marker, has no direction, and its 120u
boundary sits outside the 90u radar cutoff it precedes — **it can never be
more precise than the instrument it announces.** Its assertion measures
*no marker at either sample*, so reimplementing it as a marker reddens two
assertions instead of one.

### Good standing already worked; you just could not see it

`enemies_of` has only ever listed HOSTILE factions, so a neutral convoy
never picked the player unprovoked. The complaint was entirely feedback
and affordance:

- Standing moved **silently** — one line into a ten-slot logbook you open
  a menu to read, and only for kills. All three positive movers passed
  `quiet=true` and put nothing anywhere. A `standing_shifted` signal now
  fires from the one mutator, coalesced per volley because the toast label
  has no queue and six kills would clobber each other.
- **Tapping a neutral convoy ordered an attack.** Return fire could swing
  onto one mid-brawl, cycling toured them, and flying alongside raised
  combat music. Four consumers read `"hostiles"` as "things to shoot"; they
  now ask one dispatcher.
- Attacking a neutral deliberately still works and **has to** — four
  unprovoked kills closing a faction's fence is the whole ramp. First tap
  names them and arms, second engages; anything already shooting at you is
  an ordinary target on one tap. That last clause is the load-bearing one.

### One toll bought permanent peace

Found by reading, not by playing. The Tithe baseline sat at −4, *exactly*
on the HOSTILE/WARY boundary, so a single toll crossed a band. Raiders then
had no target and no leash in charted space, drifted forever,
`_count_raiders()` never reached zero, `_raid_active` latched — and because
`muster_eligible` reads the same flag, **every future raid and every future
muster stopped for the session.** Only a warp cleared it, and nothing said
so. Baseline → −6 (three tolls is an arc, one was a switch), plus a
lapsed-pack exit and an eligibility gate.

### What the assertions cost, and what they caught

Four of the fifteen failed first on the assertion rather than the code:

- One banned the word "bearing" in copy that deliberately says *"not a
  bearing"* — the sentence doing the teaching.
- One trusted `chart_panel.open()`'s default selection; `open()` returns
  early when the sheet is already up, so it could read a stale screen.
- One read a port's first service tab when the desk renders on another,
  and separately depended on preconditions (system loaded, engine alive)
  that earlier sections of the same harness destroy. **A desk that never
  rendered and a row correctly suppressed produce the same silence.**
- One called `manual._show_page()`, which does not exist. It stalled the
  whole suite instead of failing loudly.

And one caught a real hole in the tooling: **`_panel_text_contains` has
only ever walked `Label` nodes.** Half of what a port sheet says is written
on its buttons, so the helper eight assertions rely on to read "the
rendered tree" was blind to all of it. The tell was that the assertion
failed in BOTH directions — a measurement that cannot distinguish its two
outcomes is not measuring.

## 57. The engine that would not wake (v18, playtest round 3)

A playtest screenshot: the ship parked a few units off THE GNOMON, three
hundred units out in the Drift, `CARRIER WASH` on the band line — and the
engine asleep. No wake, no refusal, no line. An inert prop at the end of a
three-hundred-unit hunt.

### The gate was in the wrong function

Breaching this system's survey hull is what arms the apex (§38): the breach
charts the next system, and killing the engine opens the lane to it. That gate
is real and it is load-bearing — `travel_to` asks only about the lane, so an
engine that woke for anyone who found it could be killed into a lane leading
somewhere the player had never charted.

The defect was **where the gate was asked**, not what it decided.
`_load_system` armed the proximity poll only for an already-breached system:

```gdscript
if GameState.breached.has(id) and _find_apex() != null:
    _apex_wake_timer = APEX_WAKE_DELAY
```

So in an unbreached system the poll never ran at all. Nothing was watching for
the player's arrival, so arriving produced nothing — not a wake, and not a
refusal either. The gate did not *decline* to open; it was never asked.

The poll now runs wherever there is a live engine, and `_wake_apex` asks the
survey question one step later — where there is a player standing in front of
it to answer. Same gate, same verdict, and now a sentence: the engine states
its terms once per visit on the GSA relay, with the hull's bearing and depth,
because the player is three hundred units past the thing they need to breach.
The poll stays armed either way, so breaching and returning wakes it with no
further ceremony — and, as the assertion proves, breaching *without moving*
wakes it where the ship already stands.

### Why it became reachable in v18, and why 30 assertions could not see it

Reachable the day the tutorial stopped breaching the survey hull. Before v18
the guided run ended on the real hull, so every player was breached before they
could fly anywhere; §54 moved the finale to a training hull and put the survey
hull a hundred units past the marker. From that day "fly out, get rich, find
the lair" was an ordinary way to play — and the first thing it met was scenery.

The assertions could not see it because **all thirty of them wrote
`_apex_wake_timer = 0.2` by hand** after teleporting to the lair. That skips
the arming step entirely and starts the poll at its proximity test, so the one
question that mattered — *does the poll ever run?* — had no coverage anywhere
in a suite of thirty apex checks. This is the same shape as §54's tutorial
step: a harness that stages the state it is supposed to be measuring.

`A DORMANT ENGINE SAYS WHY` is driven by flying and waiting and touches
`_apex_wake_timer` nowhere. It asserts all three halves — it sleeps, it says
which way the hull is, and the breach wakes it from the same berth.

Moving the gate also cost `PYXIS_DEEPTEST` a free pass: it staged a boss fight
in an unbreached system and got away with it for as long as hand-arming skipped
the check. It marks the breach now, the way SHIPTEST and RADARTEST always have.

### One corner for everything navigational

Same screenshot, second finding. `HDG 181 · WEST` sat top-left under `HULL`;
the band, the range and the carrier wash sat bottom-left. "Which way am I
pointing" and "how far out am I, in what" are one question asked twice, and the
answer was split across two corners of a phone screen. The heading moved down
to sit directly above the band line. The top-left stack keeps SALVAGE / HOLD /
HULL — the *ship's* state, read while looking at the ship. The bottom-left
corner is the *chart's*, read while deciding where to point.

## 58. Covering somebody, and saying what you meant (v18, playtest round 3)

### The favour was real and almost nobody could earn it

Stage 5 gave the matrix its first positive mover: kill something that was
attacking a **convoy** and the convoy's flag remembers it. That fixed the
one-way ratchet in principle — four of the seven chartfolk flags had no way up
at all — and left it unreachable in practice, because a convoy is one of half a
dozen kinds of flagged ship in the sky. Sentries hold lanes, pickets patrol the
cordon, guards sit on posts, the Procession moves. Every one of them can be
caught in a fight it did not pick, and helping any of them counted for nothing.

`credit_defence` now takes anything in `combatants` carrying a flag. Two bounds,
because a favour that pays per corpse is a standing printer:

- a **convoy** keeps its per-convoy-per-session bound — a column fights one
  action, and a per-ship bound would pay six times for one rescue;
- **everything else** is bounded per flag per system visit. A brawl is worth one
  step to the flag it was fought for however many hulls burn in it, so parking
  beside a border skirmish and farming it is worth exactly what helping once is.
  Warping out and back re-arms it, deliberately — a second trip is a second
  favour — and `DELTA_SPAN` still caps where the arc can end.

It is **not** gated on the flag's current band. Covering the ships of a faction
that despises you is the one way back that does not involve a toll, and it
should read as exactly that: you turned up, and it counted.

The muster is excluded, for HORIZON-4 §8's reason applied to a second currency:
a recurring event that pays is recurring income whatever it is denominated in.

### Standing moved and never said why

`_flush_standing_toast` named the faction and the band — "THE RELAY LEAGUE —
STANDING RISES · FRIENDLY" — which is the A10 complaint one layer up. The player
watches a number move and cannot tell which of the last ten seconds moved it, so
they cannot choose to do it again. A mover may now attach a **cause**, and the
toast leads with it: "COVERED THEIR SHIP — THE RELAY LEAGUE · NOW FRIENDLY".
Movers that are self-evident where they fire — a toll paid on a sheet the player
is looking at — pass no cause and read exactly as they did.

### The copy that named things without explaining them

A separate pass over the lines a player meets while something is shooting at
them. The rule applied was not "write it plainly" — the game's voice is terse
and diegetic on purpose — but **every line must either use a word the game has
taught, or say what to do about it**. What failed that test:

| was | is | why |
|---|---|---|
| `IRIS SEALED — CLEAR THE PROBES` | `CORE SEALED — DESTROY THE PROBES TO OPEN IT` | "iris" is never taught; the core is the thing being shot |
| `IRIS PARTIAL — n PLATE(S) WELDED` | `CORE PART-SEALED — n PLATE(S) STILL WELDED SHUT` | said a state, not a consequence |
| `IRIS OPEN — FULL EXPOSURE` | `CORE FULLY OPEN — HIT IT NOW` | exposure *of what*, and *so what* |
| `VENTING PROBES` | `VENTING PROBES — DESTROY THEM TO REOPEN THE CORE` | named an event with no verb attached |
| `CARRIER WASH` | `JAMMED — SOMETHING IS CLOSE` | the old line was pure jargon; the new one still says HERE and never THAT WAY, which is the constraint that matters |
| `THE SHEAR IS FAILING — n OF m` | `THE SHEAR IS COLLAPSING — n OF m · TAKE THE CRATES NOW` | a countdown the player could not read as one |
| `ARCHEOLOGY n — X NOW READS IN THE FIELD` | `ARCHEOLOGY n — IDENTIFY X SALVAGE WITHOUT DOCKING` | "reads in the field" is the codebase's phrase, not the player's |
| `NO ROOM TO STOW THAT READ` | `HOLD FULL — NO ROOM FOR WHAT IT IDENTIFIES AS` | "a read" as a noun appears nowhere the player has been taught |
| `THE CORDON IS STANDING TO` | `THE CORDON IS MUSTERING — A LINE IS FORMING` | military idiom, and the game already has a word for this event |
| `SLOT OPEN — TAKE ANOTHER AT ANY PORT` | `CONTRACT SLOT FREE — PICK UP ANOTHER AT ANY PORT` | which slot? |
| `BERTH LOGGED — X xN` | `NEW BERTH CHARTED — X xN` | "logged" hid that this was the charting payout |
| `THERMAL SINK ABSORBED THE WASH` | `THERMAL SINK ABSORBED THE BLAST — LESS DAMAGE TAKEN` | the module has to be seen paying for itself |

`CARRIER WASH` is the one worth arguing about, because §56 chose it
deliberately: it had to say HERE and never THAT WAY, and never be more precise
than the radar cutoff it precedes. `JAMMED — SOMETHING IS CLOSE` keeps both
properties — byte-identical at 119 units and at 5 — and drops the only part that
was doing no work, which was the word "carrier".

### The assertion an unrelated dice roll could poison

`RAIDTEST`'s `THE HOLD IS NOT A SHIELD` went red on the first sweep after §57,
and the shape of the failure was the tell: `parked+open ineligible=true,
moving+open eligible=false`. Both halves of one question came back "not
eligible", which is not what a broken *rule* looks like — it is what a blocked
*precondition* looks like.

`_tick_interdiction` rolls a raid of its own accord once `_raid_timer` reaches
zero, and P9 and P10 both leave that timer at exactly `0.0`. So the first frame
in which the tick finds nothing else blocking it decrements past zero and
spawns; `_raid_active` latches true; and every `interdiction_eligible()` after
that returns false regardless of where the ship is or what sheet is up. The
parked half then passes *for the wrong reason* and the moving half fails, which
is precisely the printed line.

It needs the roll to land inside one specific frame, and what decides that is
how much other work `_process` is doing that tick — so it sat dormant for as
long as the frame budget happened not to line up, and surfaced when §57 added a
proximity poll that runs in every system rather than only breached ones. The
poll is not the bug and removing it would only re-hide this.

`_pin_raid_idle()` now sets the three fields the check *assumes* immediately
before it reads, in both P10 and P11. `_raid_timer` is the one that matters:
zeroing `_raid_active` and `_raid_cooldown` without it leaves the roll armed and
merely moves which frame it fires in. Three consecutive runs at 26/0, matching
the pre-§57 baseline exactly.

The general lesson is the one §54 already paid for once: **a measurement an
unrelated dice roll can poison is not measuring the thing it names.** Staging
belongs where it is read, not several statements and an `await` earlier.

### The sweep after round 3

**55 runs | 517 PASS | 1 FAIL | 0 script errors | save intact.** Up three on the
514 baseline, which is exactly the three assertions this round added:
`A DORMANT ENGINE SAYS WHY`, `COVERING ANYBODY IS EARNED, AND BOUNDED PER FLAG`,
and `A STANDING TOAST SAYS WHAT EARNED IT`. The one failure is the standing
HOLDTEST readout issue, untouched by any of this.

The dormant-engine check was red-verified the way the house rules require —
the breach test put back into `_load_system`, and the assertion prints
`slept=true, said …=false, woke=false` against its green
`slept=true, said …=true, woke=true`. Both halves of what it claims move when
the defect returns, which is the only thing that makes it worth its runtime.

## 59. Damage control, and the one console that stops the clock (v18)

A panel off the `HULL` readout: which parts of the ship the damage has reached,
and the ability to burn a broken one to overcharge a working one. Requested as a
last-ditch move, and built as one.

### The readout was never hull

`HULL 92%` is `PlayerShip.shield_fraction()` and always has been. There is one
survivability pool, no second number, and no located damage anywhere in the
game. So "which sections are damaged" was not a display problem — it was a
model that did not exist, and the first decision was where to get it from.

**Derived, not tracked.** `SectionDB` reads the one number the game already
keeps and says which parts of the ship that number has taken with it. Nothing
about combat changed, no save migration was needed, and — critically — no death
spiral was created. The pool *is* the shield array, so a model where a damaged
array cut `shield_max` would knock out more sections, which would cut it again.
Derivation makes that structurally impossible: **being damaged costs nothing by
itself.** The integrity it is read from has already been paid. Damage only means
a section is a legal thing to spend.

The ladder is outside-in — starboard mount, drive coil, port mount, shield array
— because a survey hull takes hits on its mounts before its spine. The reactor
core never fails, and that is not generosity: the core performs the diversion, so
a ship whose core was out could not divert, and the panel would go dead in
exactly the moment it exists for.

### What makes it desperate rather than routine

Diverting burns the source section out **until the ship docks**. That is the
entire cost side, and it is what stops this being a free loadout: you are
spending a real capability to survive the next sixty seconds. The numbers are
deliberately large in both directions (a mount is half the guns; an overcharge
is +45–75%), because a trade that cost a mount for +10% would never be worth
taking and the panel would be decoration.

`diverts` is deliberately **not saved**. It is a wound you are still carrying,
and writing it to disk would mean a pilot who quit mid-fight loads back into a
burned-out mount with no memory of trading it away — punishment for closing the
game. Everything else is derived from live integrity, so an empty dictionary at
load is the correct and complete state.

### The rule that was living in the rendering

The first draft let the panel decide which rows were tappable and had
`divert_power` trust that. The rule *you may only burn something already broken*
therefore lived in a `disabled` flag — it would have held exactly as long as
nobody added a second caller, and no assertion could reach it without driving a
UI. `GameState` cannot read the ship's shields, so integrity is now an argument
and the rule lives where it can be tested. This is the house rule stated
plainly, caught on its own feature.

### Pausing, which nothing else does

§14's rule is that a raid must not begin behind a sheet the player cannot see
past, and `console_camping()` exists because a sheet open at speed is a shield
rather than a document. Damage control is the exception, and it earns it: a
decision made at 12% integrity with a swarm on you is not a decision anybody can
make while flying.

It still registers in `console_open()` even though pausing already stops the
raid roll dead — the pause goes up and comes down a frame either side of the
sheet, and a rule that holds only in the frames nobody was looking at is not a
rule. It is deliberately **not** in `close_consoles_for_raid()`: the klaxon
clearing the desk is about sheets read while the world moved, and slamming this
one shut would drop the pause back onto a ship with a pack on top of it.

`Escape` is handled by the panel itself. `CameraRig`'s ladder stops receiving
input the instant the tree pauses — its own comment says so about the pause menu
— so a sheet that pauses has to own its way out or the key does nothing and the
game reads as hung.

### On the word "overcharge"

It was already taken: `core_overcharge` is a fitted ability and `OVERCHARGE` is
a button in the action dock. Spending the same noun twice is the confusion §58
had just finished undoing, so the verb here is **DIVERT** and the resulting
state is **OVERCHARGED** — the requested word survives where it describes a
condition, and the button keeps its meaning.

### The sweep with damage control in it

**56 runs | 524 PASS | 1 FAIL | 0 script errors | save intact.** Seven up on the
517 baseline, which is exactly the seven `DAMAGETEST` assertions; the run count
moves 55 → 56 because the tag is new. The one failure remains the standing
HOLDTEST readout issue.

Two of the seven were red-verified rather than merely observed passing. Removing
the damaged-source test turns `intact source refused=true` into `false`;
removing the un-pause in `close_panel` turns `closed -> running=true` into
`false`. Each fails on precisely the clause that names the defect, which is the
only property that makes an assertion worth its runtime.

### What an adversarial review found in §59 before anyone played it

Five independent lenses over the damage-control commit, each finding verified by
a separate agent told to refute it. Four of the survivors falsified claims the
commit message itself had made, which is the useful kind of finding.

**The death spiral was rebuilt on the boost side.** §59 argues at length that
deriving damage from the pool makes a spiral structurally impossible, and then
`_scale` multiplied `shield_max` — the denominator of `shield_fraction`, which is
the very integrity every section is derived from. Overcharging the SHIELD ARRAY
raised `shield_max` while `_apply_fit` left current shield alone, so integrity
fell 30% → 20% and the array crossed its own 0.22 threshold **one line after
being sent the power**. Burning it was worse in the other direction: capacity
fell, integrity jumped 30% → 50%, and sections healed as a reward for destroying
one. Derivation had closed the loop on the damage side and the diversion reopened
it on the boost side. Fixed by making the shield system scale **regeneration
only** — capacity is fixed by the fit and nothing the player can reach moves what
the model reads.

**A system could pay itself.** Both mounts govern `dps`, so burning one into the
other multiplied the same key by 0.50 and then 1.60: a net **0.80**, a strict
loss, rendered as `OVERCHARGED` in gold with a toast and a logbook line. It is
also the most obvious move on the sheet — route the broken gun's power to the
good gun — so it could not merely be undocumented.

**And the ordering comment was vacuous.** `SectionDB.apply` carried a confident
note that burning before boosting was load-bearing. Both are multiplications on
the same key, so the two loops cannot be told apart by any measurement. The
comment documented away the same-system case instead of catching it. It now says
what actually prevents it.

**One boost per target was in the rendering.** `divert_power` checked three of
the four double-spends and missed "this target already carries power", so four
taps into the core gave `core_boost` of 1.75⁴ = 9.4 and a discharge at nine times
its rated burst. The panel refused it by greying the row — the exact failure §59
congratulates itself for having caught for the damaged-source rule, repeated one
field over. `can_divert` is now the single predicate the panel *and* the mutator
both ask.

**`diverts` outlived the run.** "Not saved" was mistaken for "empty at the start
of a run". It is only cleared by docking, so ABANDON TO TITLE → NEW SURVEY
carried a burned-out mount into a brand-new ship — `reset_to_starter` ends in
`_recompute()`, which folded the stale dictionary straight back in, and the new
pilot could not open the panel to find out why because it refuses during the
tutorial.

Also fixed: the sheet could be raised mid-warp (`toggle_pause` guards on
`warping`; this handler did not, and `create_timer` defaults to `process_always`,
so the jump ran to completion behind a stopped scrim); `SectionDB.apply` ran
after `compute_stats` and multiplied straight through the catalog's floors, which
`TETHER_DRAG_CEILING` is sized against; refit deltas were rendered against a
diverted baseline and a non-diverted preview, advertising a fabricated +100% DPS
on every weapon; the panel dead-ended below 22% by accepting an arm with no legal
target; and the sheet was 460px against a 450px minimum logical canvas at the
maximum UI scale.

The lesson is not that review is useful. It is that **every one of these lived
under a comment asserting the opposite**, and the comments were written in good
faith at the moment the code was. A confident note about an invariant is a claim,
and a claim is exactly the thing worth testing.

### The second wave: the assertions were the weak part

A further pass over the same commit turned on the harness rather than the code,
and found that several of the checks §59 leaned on could not fail.

- **`AN OVERCHARGED CORE HITS HARDER` read a field nothing spends.** Its baseline
  half was `stats.get("core_boost", 1.0)` compared against `1.0` — with no
  diversion the key is absent, so the assertion compared its own default to a
  literal and could not fail on any code. Rewritten to compute the burst the way
  `PlayerShip` does, **it immediately went red on real code**: the discharge is
  priced in fitted DPS, so burning a mount into the core multiplied dps by 0.50
  and the boost by 1.75 for a net **0.875** — the most obvious way to feed the
  reactor made the reactor weaker. The core's multiplier is now derived rather
  than chosen (`1 / BURN.dps = 2.0` is the floor; it sits at 2.4), and the
  assertion stages from a mount because that is the worst source there is.
- **Two `NOTHING IS SPENT TWICE` columns passed for the wrong rule.** "Onto a
  dark section" targeted `mount_b` at 30% integrity, where `mount_b` is damaged
  anyway — the damaged-target rule refused it and the burned-target rule was
  never reached. "Out of a carrier" used the core as a source, which can never be
  a source at any integrity. Both printed `true` with the rule they name deleted.
  Isolating them needs integrity to **move**, which is what shields do: a section
  burned at 30% is no longer damaged at 90%, and a section boosted at 50% is
  damaged at 10%.
- **The shield leg measured the boost case twice.** Its "burned array" trade sent
  the array into the *drive* at 10% integrity, where the drive is damaged too, so
  the trade was refused, nothing happened, and the reading came from the previous
  staging. Staging that silently did not happen is worse than none — every leg
  now asserts that its own setup took.
- **The ladder check was a declaration-order check.** `damaged_ids` walks
  `SECTIONS` in order, so the expected lists matched whatever the thresholds were
  as long as the table kept its order. The thresholds are now asserted to descend.
- **The core check could not tell "never fails" from "not a section"** —
  `is_damaged` returns false for an unknown id too.

Two real bugs came out of the same pass. The panel's headline contradicted its
own rows: shields regenerate, so a ship can be back above every threshold while
sections it burned are still dark, and the sheet read `ALL SECTIONS NOMINAL …
nothing to trade yet` directly above two rows saying DARK and OVERCHARGED. And
**the confirmation of an irreversible action was invisible** — `show_toast`
raises a label from alpha 0 with a tween on the HUD, which is pausable, so while
this panel holds the pause the tween never advances; the toast surfaced minutes
later on resume, describing something the player had forgotten doing. The sheet
states the outcome itself now.

The through-line from both waves: **the code was reviewed and the harness was
trusted.** Six of the eleven checks were weaker than their names, and one of them
was hiding a live balance bug that the rewrite surfaced within a second of
running. An assertion is a claim like any other.

### The sweep after the harness pass

**56 runs | 529 PASS | 1 FAIL | 0 script errors | save intact.** Five up on 524:
the fourth `NOTHING IS SPENT TWICE` column, the refit-preview check that the
earlier fix shipped without, and the legs that were rewritten to assert their own
staging. The one failure remains the standing HOLDTEST readout issue, which
nothing in either wave touched.

### Third attempt at one column, and the first two failed the same way

The verification stage of the review pass — thirty-eight agents, each survivor
handed to a separate skeptic told to refute it — cleared almost everything and
left exactly one finding standing at HEAD: **the fix for a vacuous assertion was
itself vacuous.**

`NOTHING IS SPENT TWICE`'s burned-target column, three times:

| | staging | what actually refused it |
|---|---|---|
| v1 | `drive -> mount_b @ 0.30` | the damaged-**target** rule (mount_b fails at 0.78) |
| v2 | `drive -> mount_b @ 0.90` | the damaged-**source** rule — 0.78 is the highest threshold in the table, so at 90% *nothing* is damaged, including the source |
| v3 | burn `mount_a @ 0.30`, then `drive -> mount_a @ 0.50` | `diverts.has(target)` — the rule it names |

v2 was written specifically to fix v1, with a conjunct (`not is_damaged(target)`)
that excluded v1's cause and said nothing about the new one. The vacuity moved
instead of dying, and the commit that shipped it described the defect correctly
while reproducing it.

The rule is only load-bearing when the source is damaged and the target is dark
**but repaired**, which needs two different integrities — burn low, attempt
higher. Red-verified: deleting `diverts.has(target)` from `can_divert` turns that
column, and only that column, false.

The general shape is worth keeping: **a conjunct that rules out the previous
cause is not the same as one that establishes the intended cause.** The cheap
check is to delete the rule and watch the column; anything that still passes is
still measuring something else.

## 60. The compass said 270 was north (v18, playtest round 3 follow-up)

A rendered frame from §57's HUD check read `HDG 270 · NORTH`. It was internally
consistent — fly to a quoted bearing and you arrive — but no compass any player
has ever used puts north at 270, so the instrument read as broken whether or not
it was.

### The world convention and the displayed one are now different numbers

Everything internal uses `atan2(z, x)`, where +X is 0: the lair derivation, the
authored `bearing_deg` in every system def, Hunt's search cone, and — decisively
— the bearings **already written into players' saves** as apex hints. Rotating
that would have needed a save migration, and a hint that pointed 90° wrong is
worse than no hint: it costs credits *and* sends you the wrong way.

So the rotation happens at the glass. `DeepSpace.compass_deg` is the only thing
that converts, every readout and every quoted bearing goes through it, and not
one stored number moves. A save written last night still points where it always
did. The offset is +90 because +X has to go from 0 to 90.

`quadrant_of` is now derived from the displayed number rather than from its own
copy of the sector maths, so the word and the digits on one line cannot
contradict each other. They agreed before only because two tables happened to
match.

### The assertion that would have passed on the broken compass

`THE READOUT FOLLOWS THE HEADING` staged a yaw *from a number* and expected the
same number back. That is true of **any** convention — it would have passed just
as happily on the version that printed `HDG 270 · NORTH`, which is exactly what
it did for as long as that shipped.

It names the four cardinals and the digits a player expects beside them now:

| direction | reads |
|---|---|
| `-Z` | `HDG 000 · NORTH` |
| `+X` | `HDG 090 · EAST` |
| `+Z` | `HDG 180 · SOUTH` |
| `-X` | `HDG 270 · WEST` |

That is the form that can fail when the compass is wrong, and it is the third
assertion this round rewritten for the same reason: a check that restates its own
staging is not measuring the thing it names.

## 61. Two doors nobody had tried, found looking for a different bug

A second hunt over the wake path — four lenses, every candidate handed to a
skeptic — looking for a way a *breached* system could still leave the engine
dormant. It did not find one. It found two other things, both reachable in two
taps from the pause menu, and both real.

The shared cause is that `rebuild_visuals` (Settings → COLOUR VISION) routes
through `_load_system`, which frees every child of `SystemRoot` — and nothing
gated the door. `set_panels_locked` disables only the refit and chart buttons, so
the pause menu opens during a boss fight *and* while docked, and the colour
cycler changes value on every press.

### A colour setting ended boss fights

The engine is a `SystemRoot` child. Mid-encounter the rebuild handed back a
**dormant boss at full HP** with every probe and weld gone and `boss_active`
cleared — a fight the player was winning, reset by a menu, with no message.

Deferred rather than refused: it is a colour change and the player asked for it.
`_set_boss_active(false)` is the one place every ending of an encounter passes
through — kill, break off, death, leash — so that is where the retint is spent.
Both halves are asserted, because a rebuild that was merely *refused* would drop
the player's setting silently.

### And it welded the ship to the berth

The `Port` is a `SystemRoot` child too. `_load_system` cleared `live_rift` and
`_procession` for exactly this reason and never cleared `docked_port` — and
`undock()` opens with `if docked_port == null: return`, which **a freed
reference satisfies**. So DEPART became a silent no-op, `player.docked` never
cleared, and movement is gated on that flag.

A ship clamped to a berth that no longer exists, with no button in the game that
could release it. Dock, pause, cycle COLOUR VISION. The file's own comment eight
lines above the free loop already says a freed reference compares equal to null;
the danger was known and the one field it applied to was missed.

Released before the free, so `set_docked_visual` and `dock_point` still run
against a live node — the same order `abandon_to_title` already used.

### On the bug that was actually being hunted — this WAS the second path

The first reading of this finding dismissed it: the rebuild re-arms the poll, so
the engine returns in about six seconds rather than staying dark. Both halves of
that were wrong.

`Main` has no `process_mode` override, so it is PAUSABLE — `_process` does not
tick while the pause menu is open, and the wake timer does not count down. The
dormant window is **the whole time the settings menu stays up**, plus six seconds
of flight after resuming, plus `WAKE_TIME` on top. And the evidence being
explained is a *screenshot*: a single frame. Ten seconds is ample; unbounded is
more than ample.

So the photographed state — ship parked a few units off THE GNOMON, ~287u out,
engine DORMANT, HUD panels unlocked, no boss bar — is reachable with
`breached` containing `pyx01`, by pressing Escape mid-fight and cycling one
accessibility setting. That is a second, independent path to the same symptom,
and §57's fix does not touch it.

It is also the path a colour-vision player is *most* likely to hit, because the
reason they are reaching for that toggle is that they cannot read the phase tint.

The fix above closes it. What is worth recording is the reasoning error: "it
recovers in six seconds" was offered as grounds for dismissal without checking
whether six seconds was long enough to matter, or whether the clock was even
running.

### The sweep after the compass and the two doors

**56 runs | 531 PASS | 1 FAIL | 0 script errors | save intact.** Two up on 529 —
the berth softlock and the colour-setting check. The one failure is still the
standing HOLDTEST readout issue.

Measured on a quiet machine, deliberately. An earlier run of this same tree came
back 528/2, the extra failure being `STREAMTEST`'s frame time at a worst frame of
50.7ms against a 40ms bound — while a review workflow was doing local file I/O
alongside it. Three isolated runs gave 26.2 / 22.4 / 24.8ms, in line with the
21.5 and 27.4 of the sweeps either side, and the mean never moved. A performance
bound measured under contention is not a measurement, and the number was not
written down until it had been taken properly.

## 62. The world does not come back, and the sentence that was never there (v19, playtest round 4)

Four items from a play session. Three were asked for as live-world behaviour and
one was reported as a missing feature; the missing feature turned out to be
built, on screen, and invisible for a reason nobody had guessed.

### What was actually removing the sentries

The report was that a swarm closed in, the galactic forces killed it, and then
the sentries were gone. All three candidates offered — dying to the swarm,
`_give_up`, a rebuild — are wrong, and the code says so plainly.

**It was the muster line, departed by `_close_muster`.** The instant the last
column ship dies, every surviving line and column ship is put through `depart()`
and shrinks away over 1.8 seconds. Eight GSA machines evaporating the moment
they win reads exactly like "they were not there any more".

The tell that pins it is the ambient floor. `SKIRMISH_HP_FLOOR` caps any damage
from anything in `combatants`, so **no ordinary machine in this game can kill
another one**; the muster's `and not muster` exemption is the only place in the
game where NPC-versus-NPC fire is lethal. So "the galactic forces killed it"
could only have happened inside a muster, and the swarm-kills-the-garrison
reading is not merely unlikely, it is impossible.

The standing garrison was never involved. It has no leash, no lifetime and no
distance cull, and `_load_system` rebuilds it in the same frame it frees it — so
a warp *restores* sentries. **The only thing that has ever removed one is the
player**, which is §51's rule working exactly as written. What the playtest
found is the half §51 did not cover: that rule is about depletion and says
nothing about recovery, and a volume that only ever empties is backwards for one
that is supposed to feel patrolled.

### The Cordon re-forms, and the sentries do not

The split is economic and it is not a compromise. A sentry flies the host
engine's flag, so it is HOSTILE and killing one **pays** — `PACING_LOOP` budgets
five sentry kills for an eight-minute loop and `MIDTIER` sits at 2.91 against a
hard 3.00. A respawning sentry is an income source bolted to a loop at 97% of
its ceiling. A GSA picket pays nothing, so the Cordon can come back on a clock
and the pacing band cannot notice.

It is also the half that was actually asked for. A sentry stands on a post; a
**picket** is the thing that patrols. And the fiction was already written and
unimplemented: `LINE BROKEN` has been promising *"expect elevated activity until
we can re-form"* since stage 4.

Three parts. A relief walks back onto an unmanned beat every 120 seconds,
entering at the waypoint furthest from the player so relief never materialises
in front of them. Survivors of a muster line are **kept** rather than departed,
up to the same cap — which at full strength retains nobody, so it is a recovery
mechanism and never an inflation one. And a standing sentry now orbits its post
at 1.2u instead of holding still, because a post should read as crewed.

**HORIZON-4 §5 said "no mid-session respawn (a respawn timer is a knob, not a
design)" and §51 said "sentries do not respawn".** Both are reopened here
deliberately rather than contradicted quietly: the first is now a cadence with a
cap and a flag that pays nothing, and the second still holds for sentries, which
is the clause that was carrying the economics.

### The picket printer had a second half, open since stage 2a

§52 closed it by gating **loot** on `pays`. `report_kill` was gated on
`player_kill` alone and handed its kind straight to `contracts.on_kill`, so a
Cordon picket dropped no crates and still advanced `cull_sentries` — 1,550
salvage for three, 3,500 for six — bounded only by the route count and re-armed
by every `_load_system`. The gate was written, and it was applied to one of the
two payouts.

A kill that does not pay now reports its own kind, the mechanism the muster
already used: `kill_neutral` is a key no contract asks for.

### Shooting a neutral brings its friends

The bookkeeping half has been in `_die` since stage 1 — kill a non-hostile and
its flag remembers. The reaction half did not exist: the machine you hit
answered, and the four identical machines beside it watched.

**25 units**, which is `PATROL_RELEASE`'s twin — the distance this codebase
already calls "still this machine's business" — and 3.6x the OVERCHARGE blast,
so the whole discharge fits inside it plus the ring of neighbours who saw it.
The apex numbers were the wrong scale entirely: a charted system is 40–48u in
radius, so 60 or 90 would mean one stray torpedo summoning the entire chart.

**Aggro, never standing.** A kill keeps its existing −1; chip damage moves no
band and writes nothing to the save. Any damage provokes, including one point of
splash, because a hidden "how much is too much" threshold is a rule the player
cannot read — and the response costs them thirty seconds of being shot at rather
than a faction. This also leaves HORIZON-4 §2's settled GSA clamp untouched:
nothing here moves a band, so the Cordon still cannot be farmed into HOSTILE,
and docking safety and the tutorial are as they were.

**It lapses, and lapsing has two halves.** Finding A6 is the standing warning —
a pack that never stopped caring latched `_raid_active` for a session — and the
grudge would have reintroduced it one layer down, because the skirmish clock
*exempts the player* and therefore never clears an `_aggro` pointing at one.
That was already true before this change: a picket the player clipped once
stayed angry until it died or the player docked. The expiry clears the pointers
as well as the clock, so the release is the fix for a latch that was already
shipping.

A provoked picket converges by having its reach widened from `PATROL_ENGAGE` to
`WITNESS_RANGE` **inside `_worth_leaving_the_beat`** — not by a bypass one level
up in `_walk_beat`, which would have left `THE BEAT IS THE ANCHOR` green while
the property it names stopped holding. The anchor is still the waypoint, so no
picket can get further from its route than it could before. And the chase now
stops at the marker, closing a gap that predates the grudge: a waypoint 30u out
plus a 25u release already reached past a 40u edge, and the live edge check was
scoped to the `muster_line` group so nothing could see it.

### The raider toll was built, on screen, and unreadable

This is the item worth reading twice, because the answer is not the one the
report implies. `show_parley` is called unconditionally and inline with the
prompt; the plates render centred and unoccluded at every supported UI scale.
Nothing was missing and nothing was off-screen.

**The prompt named three answers and the UI shipped one control.** RUN was
advertised and is not implemented inside a charted system at all — raiders
spawned inside the marker carry no leash, so flying away never ends a raid — and
FIGHT was an undocumented side effect of landing a shot. Refusal now has a
plate, the prompt names what is on the screen, and the manual has a paragraph
about tolls, which it did not: the word did not appear in that file, and the
tutorial structurally cannot teach the parley because `interdiction_eligible`
excludes an active tutorial.

**And the sentence explaining the plates could be gone before they were read.**
Three ways, in increasing order of how badly they explain the report:

1. A fixed 3.2-second `create_timer` cleared the prompt at the halfway mark of a
   six-second window.
2. The prompt is one label with a dozen writers — barks, derelict range, seam
   range, port range, traps — and every one of them writes and clears
   unconditionally. `first_hostiles` is by definition unfired the first time a
   player is ever interdicted, so it landed on the pilot least able to guess.
3. **`prompt()` faded in over 0.2s and `clear_prompt()` faded out over 0.25s,
   and neither killed the other's tween.** Two tweens on one property both keep
   running, so a prompt raised inside a clear's fade got the right text, the
   right visibility and **alpha 0.00**. `spawn_interdiction` calls
   `close_consoles_for_raid` — which clears the prompt — one line before raising
   the demand. The demand could extinguish its own explanation on arrival.

The third is a playtester looking straight at a PAY button and reporting that
there was no way to accept. The demand now **holds** the prompt line for its
window, released through `hide_parley` so the lock cannot outlive the plates,
and a suppressed bark is deferred rather than spent — a line that fires once
ever must not be consumed by being silenced.

The plates also grew from 40px to 44 against this project's own 42px tap floor,
and the stack was re-laid at 8px gaps. `_bluff_button` had never been in
`band_controls()`, so the layout probe had never measured the plate that sits
directly above the toll button: it was four design px away against a rule of
six, and at the maximum UI scale on a wide window it landed on `BROADCAST_TOP`,
which a rift advisory can occupy at the same moment.

**Why 531 assertions could not see any of it.** Every parley check tested the
rendering — rect position, centre offset, button *text*. `pay_toll()` is
exercised as a function in twelve places and the button was never pressed, its
`visible` flag never read. The new line asserts the rule instead: for every verb
the prompt names there is a visible, enabled, thumb-sized control whose press
resolves the standoff, driven off the prompt text itself so the copy and the
controls cannot drift apart.

### Persuasion, and the feed that was already forbidden

A fourth ladder beside archeology, smuggling and mining. The obvious feed —
XP for settling a toll — is **already ruled out in writing**: this project cut
two of smuggling's three feeds by arithmetic, and both cuts apply unchanged.
Paying is the losing move, and escaping is a free loop between two systems. A
skill must never pay for either.

So the single feed is a parley **talked down**, and making that legal required
giving it a stake. A Forged Manifest is consumed whether the bluff works or not
precisely so a bluff cannot strictly dominate paying; a talk-down needs no
manifest, so without a cost of its own it would be a free roll on every demand
and levelling on it would be levelling on showing up. **A failed talk-down costs
a step of Tithe standing** — the mirror of the step paying earns, denominated in
something other than salvage.

`bluff_odds` is now two ladders summed and capped: a persuasion component every
pilot has, plus the manifest-gated smuggling component, which is byte-identical
to what it always was. A smuggling-2 save holding a manifest still reads 40%, so
**no existing save loses anything**, and `manifest_odds` is smuggling naming its
own contribution rather than taking credit for the total.

The non-zero base at tier 0 is also the fix for what the playtest hit: the bluff
plate used to require smuggling 2 *and* an item, so a new pilot met a three-verb
demand with one button. Everybody can try talking; being good at it is what is
earned.

`BLUFF GATED` had to be re-aimed rather than deleted, and it is worth recording
why it was weak: it computed a `no_manifest` term and never used it, so the only
clause deciding PASS was "odds are zero at smuggling 1" — a fact about the old
gate rather than about the rule it was named for. The surviving property is that
**the manifest half is worth nothing without both the tier and the item**, which
is now four readings that each fail on their own, plus the cap.

### Two harness defects found by adding one assertion

A Cordon-strength check went red on a count nobody had questioned, and the cause
was three probe pickets in `FACTIONTEST` that were **never freed** — each
carrying a route, and therefore counted as a picket by every counter in the file
for the rest of the run. That is the "inherits state from the one above it"
shape the README warns about, sitting in the suite that warns about it.

And a new assertion printed its own format string. Nine placeholders, nine
arguments, two of them transposed — so GDScript returned the unsubstituted
template, the line contained no `-> PASS` or `-> FAIL`, and the sweep counted it
as neither. It was caught by the run count being one short of what had been
added, not by anything going red. **A malformed assertion is a silent absence,
and the PASS counter cannot tell it from a check that was never written.**

### The sweep after round 4

**57 runs | 546 PASS | 0 FAIL | 0 script errors | save intact.** Fourteen lines
up, and the run count moves 56 → 57 because `SAVETEST=migrate18` is new. Every
one of the fourteen was red-verified: 24 defect injections across two rounds,
each confirming the naming assertion — and, where the injection was narrow
enough to expect it, only that assertion — went red.

`MIDTIER` read **2.95 / 2.94 / 2.91 / 2.90**, mean **2.925**, against a
pre-round-4 pooled mean of 2.918 and a recorded maximum of 2.95. No new maximum
and no movement in the mean, which is what "the Cordon pays nothing" was
supposed to buy. Four samples, on an idle machine, because the README's own note
says a single reading of 2.95 is the top of the distribution rather than a
regression.

### And the "1 FAIL" was stale

The baseline this round started from was recorded as 531 PASS / 1 FAIL, the one
failure being `HOLDTEST`'s `THE READOUT FOLLOWS THE HOLD`. It passed in the
round-4 sweep — and it also passes on a checkout of **unmodified `3843b43`**,
run in a throwaway worktree for no other purpose than to settle the question. So
the true starting point was 532 / 0, and nothing in this round touched it.

Two explanations were written down before that control was run. The first was
"round 4 fixed it". The second, offered after the first was doubted, was that
round 4's change to what a non-hostile kill *reports* had freed a contract slot
— and `_run_hold_test` contains no kills at all, so that one was impossible on
its face rather than merely unproven.

The lesson is not "check before claiming", which this file already says four
times. It is narrower and worth having: **a baseline is a measurement with an
age on it.** This one was accurate when it was taken and had quietly stopped
being true, and because a stale baseline is indistinguishable from a live one in
the file that records it, two plausible causal stories arrived to fill the gap
before anybody thought to re-measure the thing itself.

## 63. The ladder that levelled in silence (v19, playtest round 5)

Two questions after round 4: is "Colonies" implemented, and why is archeology
the only skill that levels?

### Colonies is specced, and it is not in the game

Not half-built — absent. There is no `hyper_structure.gd`, no `hyper_positions`,
no `COLONY_JUMP*`, no `colonies` key. The design is real and it is the user's
own, but it lives in a plan file rather than in `docs/`: Stage 6 of "Pyxis —
Horizon: The Hunt". That horizon shipped stages 1–3 (§38, §39, §42) and stopped;
stage 4 (per-PYX deep identity) and stage 5 (waypoint beacons) are unbuilt too,
and the save versions the plan reserved were spent elsewhere — v17 became the
`apex_down` grandfather and **v18 became the faction matrix.** Horizon 4 was
built instead of the Hunt's back half, and the plan's own cut order had already
nominated Colonies as the first thing to defer.

The two things that get mistaken for it are both cosmetic: CINDERWORKS carries
`"kind": "colony"`, which selects a silhouette — domes on a rock instead of a
ring station — and THE DRIFT's landmark is "the frame of a colony", which §32
states is scenery with no loot and no collision.

### The skills answer was a save file, not a code read

Reading the code would have produced a plausible essay about tuning. The real
save produced arithmetic:

- **archeology 48 xp = 12 hulks × 4 per breach, exactly.** The other feed —
  reading salvage at +1 — had contributed **zero** in 68 minutes.
- **mining 22 xp with `seams_cut` empty.** Every point came from the deep, and
  no charted seam had ever been cut.
- **smuggling 0, while carrying two `stolen`.**
- `tolls_paid: 0`.

**The headline is that mining had already reached tier 1 and never said so.**
Archeology toasts a tier-up in `derelict.gd`, smuggling in `port_panel.gd`,
persuasion in `main.gd` — and `mineable_seam.gd` called `mark_mining(band)` and
**discarded the bool**, leaving a captain's-log line the player had to go and
read. Four stages of a ladder levelling in silence, reported from the cockpit as
"only archeology progresses". That is what an unannounced ladder looks like, and
it is not a tuning problem.

### Three reachability defects behind it

**Charted mining cannot reach tier 1, and that is the design.** There are eleven
authored seams in the whole game, every one band 0, worth `maxi(band, 1)` = 1 xp,
each a save-persisted one-shot: **11 lifetime xp against a threshold of 18.**
`_build_charted_seam` already calls charted mining "a WINDFALL rather than an
income", so the numbers are right and the silence was the defect. The tier-0 line
now names the marker.

**The top mining perk unlocked only once the ladder was finished.**
`MINING_DEEP_TIER` was 3 — which *is* `MINING_TIERS`' max index — so band-4
access, the only 4-xp rung on the board, arrived when there was nothing left to
earn with it. The tuning note prices the ladder in "sessions of working the
Quiet", a rate no live ladder could reach: **the constant and the comment
contradicted each other, and the comment was the honest one.** Access and the
core sample swapped tiers, so every rung still buys something.

**And paying a toll permanently deleted the interdiction.**
`interdiction_eligible` required the Tithe to be *exactly* HOSTILE. Baseline −6,
HOSTILE spans −6..−4, `pay_toll` grants +1 — so **three paid tolls walked the
banner to WARY and no raid ever spawned again**, taking the parley and
PERSUASION's only feed with it, for the rest of the save. The most reasonable
answer to a demand switched the encounter off, and a closed tap is
indistinguishable from a run of quiet dice.

Round 4 made the parley discoverable and added a ladder fed by winning it. **The
feature and the trap shipped in the same session** — which is the argument for
playing a build rather than sweeping it.

The gate is a gradient now: WARY-or-worse is eligible, and `TITHE_WARY_ODDS`
(0.4) prices the difference. Paying still buys real peace; peace is a rate rather
than a switch, and no sequence of legal play can end the encounter for good.

### On assertions written over sets

Three of the four new checks assert over a *set* rather than an instance, which
is this file's "assert the invariant, not the pair" rule applied to a case that
kept producing instances: every ladder names a verb at tier 0 **and the count is
asserted too**, because "every line in this list says what to do" is satisfied
perfectly by a list somebody forgot to add to; and every mining perk must sit on
a reachable tier **with the top rung still buying something**, so a future
reshuffle that strands any perk fails, not just the one that was wrong.

`A MINING TIER SAYS SO` carries its own negative control: a cut that does *not*
tier must still print the haul, or a build that toasts the skill line after every
single cut would satisfy the headline clause while destroying the readout the
player is actually cutting for.

### The copy check accepted a noun, and GSATEST had already written the fix

`EVERY LADDER NAMES ITS VERB AT TIER 0` first searched each line for verb
vocabulary anywhere in it. Red-verify put the old mining line back — `ORE READS
AS GREY ROCK` — and the assertion **stayed green**, because "READS" contains
"READ". A line that instructs nobody satisfied a check named for instructions.

`GSATEST`'s `NO IMPERATIVE` had already solved this, in the opposite direction
and with the reasoning written out: *"Checked on the FIRST word, not on
vocabulary anywhere in the line. English imperatives lead with their verb …
a contains-check would ban the noun too, and the rule is about mood."* The
Commission's rule is that a stage must **not** open on a verb; a skill line
**must**. Same test, opposite sign — and the second one was written from scratch,
badly, next door to a working precedent.

It now checks the first word of the perk clause and prints what each line opens
on (`archeology:breach smuggling:fence mining:cut persuasion:talk`), so the
reading is legible rather than a bare boolean. Re-verified: restoring mining's
line reports `mining:ore` and goes red; restoring archeology's reports
`archeology:reads` and goes red.

**One injection stayed green and should have.** Persuasion's pre-existing line
already opened on `TALK`, so the tier-0 variant added for it is better copy and
was never a fix. The check reporting no defect where there is none is the check
working; recorded because "all three verified" would have been the easy sentence
and the false one.

### And a literal wearing a derivation's comment

The mining-tier probe first staged from `const MINING_TIER_PROBE_XP := 15` under
a note claiming it was "derived rather than a literal, so re-tuning the ladder
cannot leave the probe on the wrong side of the rung". It was a literal 15. That
is this project's most-repeated failure — a comment asserting the opposite of the
code — authored **into a check written to catch that class of thing**. It reads
`MINING_TIERS[1] - 3` now.

### The sweep after round 5

**57 runs | 550 PASS | 0 FAIL | 0 script errors | save intact.** Four up, which
is exactly the four assertions this round added. Nine defect injections
red-verified them, and **two of the nine found faults in the new assertions
rather than in the code** — the contains-check above, and a probe staged from a
literal wearing a derivation's comment.

`MIDTIER` read **2.92 / 2.90 / 2.89 / 2.90**, mean **2.9025**, against round 4's
2.925 and a hard 3.00. No new maximum, and the mean moved down rather than up —
which is what "Part A changes no rate" was supposed to look like. Four samples on
an idle machine, per this file's own rule that one reading is not evidence.

One number was briefly written down wrong before being taken properly: a summary
was computed from placeholder values typed in place of the measured ones, and
printed a mean of 2.9225 from samples that did not exist. Caught on re-reading
the harness output. Worth recording next to §61's dismissal-without-checking,
because it is the same failure in miniature — the arithmetic was fine and the
inputs were invented, which a plausible-looking answer hides perfectly.

## 64. What is specced and not built

Every other section in this file records something that SHIPPED. That is a
useful document and a misleading one, because a reader who searches it for gaps
finds none — the unbuilt work is not written down, so it cannot show up as
unbuilt. `HORIZON-4-FACTIONS.md` says "All six are built"; the README's layout
table said `HORIZON-3-COMMISSION.md` was "not built" **eight months after it
shipped as §28**. The repo was wrong in both directions at once, and neither
error was visible from inside it.

This section is the inventory. **It is the only forward-looking list in the
repo, and it is load-bearing: if you build or defer something, update it in the
same commit.**

### Outstanding

**Horizon 6 — the known frontier** (opened 2026-08-17 after a week of
playtesting; specced in `docs/HORIZON-6-THE-KNOWN-FRONTIER.md`). Six feature
commits, none built yet:

| # | what | save | status |
|---|---|---|---|
| 0 | preconditions: the band-0 key crash, the save-destroying downgrade path, the stale inventory | none | **BUILT** — §73 |
| 1 | hotkeys: `chart` / `drop_beacon` / `pause`, each behind a guarded wrapper | none | **BUILT** — §74 |
| 2 | pilot profiles: per-profile save paths, a registry, and device settings split into `prefs.json` | none | **BUILT** — §75 |
| 3 | per-PYX deep identity + one signature content class per system | none | **BUILT** — §76 |
| 4 | chart legibility: fit-to-content scale, ship marker, band rings, legend, pan/zoom | none | **BUILT** — §78 |
| 5 | beacon navigation: set-course autopilot and a depth-capped paid jump, same-PYX only | none | **BUILT** — §79 |
| 6 | persistent per-PYX survey coverage | **v21** | **BUILT** — §80 |
| — | a static parse pre-flight that runs without the Godot binary | none | **BUILT** — §77 |

Both reversals are now done and neither was quiet: commit 6 reversed §22's
session-only survey rule (the `SESSION RESET` assertion forced exactly the
conversation it existed to force — §80), and commit 3 rewrote `IDENTITY IS
ADDITIVE` (§76). **§41's `MIDTIER` re-derivation is still owed, and commit 6
sharpened it rather than paying it**: persistence moved surveys OUT of the
recurring term — income-negative, not income-positive — so `STEADY MIDTIER`
now measures an honestly poorer loop against the same [0.60, 3.00] band. If
the next sweep turns that leg red, that IS the re-derivation arriving: the
answer is a decision about yields or the band, taken in the open, not a nudge
to whichever number makes it green.

**Horizon 7 — the filed frontier** (opened 2026-08-18; specced in
`docs/HORIZON-7-THE-FILED-FRONTIER.md`). Six commits, **all built**:

| # | what | save | status |
|---|---|---|---|
| 0 | pay §41's `MIDTIER` re-derivation | none | **PAID** — §86: the reference moves to `rig_strike`, the yields and band stand, `THE YARDSTICK IS MID-TIER` keeps it paid |
| 1 | marks: `survey_filed` as a second set, and `structures_seen` for hyper structures seen but not claimed | **v22** | **BUILT** — §82 |
| 2 | the counter pays a first-filing bonus, once ever per cell | none | **BUILT** — §83 |
| 3 | a rival cartographer — evidence only, a pure function, zero save | none | **BUILT** — §84; the wreck deferred to the writing pass landed in commit 4 |
| 4 | THE UNSOUNDED answers: one authored structure per system past 5,200u, plus the rival's hull in band 5 | **v23** | **BUILT** — §91; fragments approved as drafted, the per-visit meter cut (the flight is the gate) |
| 5 | beacon stock re-derived against §79's navigation; band-entry teaching through §76's broadcasts | none | **BUILT** — §85 (teaching), §87 (stock 8 → 3, decided from live play, legacy saves grandfathered) |

**Commit 0 is PAID (§86).** The measurement found the reference at the 18th
percentile of the catalog; it moved to `rig_strike`, the yields and band stand,
and `THE YARDSTICK IS MID-TIER` reddens the next drift instead of letting it
sit for two more horizons.

**One live gap is folded into commit 1 rather than filed separately.** A hyper
structure the player has SEEN but not claimed has nowhere to be recorded —
`colonies_in` reads the claimed store and there is no radar tier — so flying
past one and being driven off by its wardens loses information the player
earned. The silhouette design (`hyper_structure.gd:15`) is deliberate and
stands; the missing record is not.

**Long expeditions are deferred on purpose**, not forgotten: provisioning is the
idea most likely to become tedium, and it only earns its place once commit 4
gives THE UNSOUNDED something worth the trip. Commit 4 has now shipped that
trip, so the question is live again — and §91 records the argument against a
first provisioning system dressed as a fragment cap: a refusal with no fiction
behind it is manufactured tedium, whatever it is called.

**From the nine-note playtest of 2026-08-18** (triage and fixes in §88–§90),
the two items that remain open and are genuinely new design:

| what | status |
|---|---|
| purchasable slot expansion (Utility III, Weapon III…) with power/section/speed tradeoffs | **Horizon 8 commit 2** — touches the fit dict, refit UI, section damage, and every BALANCE/PACING assertion; still wants its own research pass before it is specced in detail |
| faction contracts offered on hail, with standing gain; standing LOSS already exists (witnessed kills, fence deals) | **Horizon 8 commit 3** — the offer verb is the one new piece, rides existing contract + faction machinery |
| rival-remnant inspection with staged reveals (hold on a foreign beacon = read it) | **SPECCED as Horizon 8 commit 1** — the rival's hull and log shipped in §91; the foreign-beacon read is now the delivery channel for Directive 9's pages, pure function, zero save |

**Horizon 8 — the closed file** (opened 2026-08-19; specced in
`docs/HORIZON-8-THE-CLOSED-FILE.md`, prose gated on
`docs/DIRECTIVE-NINE-DRAFT.md`). Four commits, **none built**:

| # | what | save | status |
|---|---|---|---|
| 0 | the second register, STAGED: the private beat at the read, the living voices only at the whole record | none | **BUILT** — §92; no save bump, both flags derived from v23 |
| 1 | the refusers' network: Directive 9's pages on band-3+ foreign beacons | none | **BUILT** — §93; the band gate lives in one pure function so no spawn site can re-decide the pacing |
| 2 | purchasable slot expansion | likely v24 | specced only as a row; wants its own research pass |
| 3 | faction contracts offered on hail | TBD | specced only as a row |

**The finding that shaped it, and the rule it hands the pass.** The authority's
voice CANNOT change, because bands 1–4 of `BROADCASTS` are recordings and THE
LAST RETURN's final entry already says the machines were never told. So the
chart-edge beacon goes on telling a commissioned pilot *"the bearing is yours,
and it is written down"* forever — which becomes the most frightening line in
the game the moment somebody has read the order. What changes is what is alive:
bands 5 and 6 (never the GSA's), the player's own file, the player's own ship.
`THE MACHINES DO NOT KNOW` is that rule as an assertion, and it goes red the
moment somebody tries to finish the table.

**The first read-aloud set a register rule worth keeping beyond this horizon:**
every line is understandable on first read — eeriness comes from what a line
MEANS, never from being hard to parse. The player always knows what they were
just told; what grows with depth is how much they wish they had not been told
it. And the reveal is STAGED to protect the slow burn: pages hint from band 3,
the archive read changes only what is private (bark, log, Commission field —
which per R4 appears only after the read, corroborating rather than teasing),
and the two living voices answer only a pilot holding all nine fragments.

**And the verb the last fragment asks for is deferred on purpose.** Filing
returns with the refusers instead of the Authority is what *"file a return for
us"* is asking, it rides existing fence machinery, and it must not ship in the
same horizon as the revelation. A discovery that immediately becomes a menu
option was never a discovery.

**The README's harness counts should be derived, not typed** (open 2026-08-17,
§77). Three numbers — tag count, SAVETEST mode count, total runs — are
maintained by hand in a paragraph that itself warns the reader it has been
wrong before. It has now drifted twice: §73 found it claiming 44 and 61 in two
places that disagreed with each other, and §77 found it claiming 46 and 64
against a `TAGS` array holding 48 and a sweep of 66. Both times the fix was to
retype the numbers, which is the fix that expires. `run_harness.sh` already
knows all three and could print them (`--counts`), or a check could assert the
README against the array the way `THE MANUAL IS TRUE TO THE CANCEL LADDER`
asserts prose against a constant. Small, and it removes a recurring class of
staleness rather than one instance of it.

**Should an ALLIED ship be spared the player's area weapons?** (open 2026-08-07,
§72). Splash catching a flag is deliberate and measured — `WITNESS_RANGE` is
dimensioned by `OVERCHARGE_RADIUS` — so this is not a bug to fix but a line to
draw: sparing the two positive bands would honour HORIZON-4:234-236's *"allied
ships are emphatically not in `hostiles`"*, at the cost of a band-shaped hole in
a group six systems read as uniform, area fire getting safer as the stakes rise,
and a torpedo-only fit unable to open on an ALLIED ship (a torpedo's only damage
vector is that sweep). The concrete harm that prompted the question — an escort
parked inside the blast — is fixed independently by moving the station.

**The contact menu has no touch gesture** (deferred 2026-08-06, §72). Right-click
opens it; a phone has no way in. This is the one place in the game where a verb
is desktop-only, and it is deferred rather than dropped because the reason is a
gesture-vocabulary problem rather than a scoping one: tap-on-ship already means
two things (arm an engage, and fall through to a move order) and press-and-hold
already means "work this" against a four-group pick ladder, so a third meaning
on either needs an audit of the whole touch grammar, not a branch. **What a
touch player is not missing today is the information** — the first tap's toast
already names the flag and the band. What they are missing are the verbs.

**Nothing outstanding from the frontier.** Stages 1–4 shipped as §68–§70 plus
stage 4's own commit; §71 adds storms on top. The historical table is kept below
as the record of how it resolved.

**The frontier, stages 2–4** (owner-commissioned 2026-08-05 after the 8000u
playtest; stage 1 shipped as §68). The full plan is in
`~/.claude/plans/you-are-continuing-work-kind-lemur.md`.

| stage | what | save | status |
|---|---|---|---|
| 1 | bands 5/6 (THE FATHOMS, THE UNSOUNDED): edges, every band table, threats, commodities, landmarks, palette, `PYXIS_FRONTIERTEST` | none | **BUILT** — §68 |
| 2 | the Mk III line: 4 Mk III weapons, 3 Mk III utilities, Breaching Torch / Surge Capacitors / Expedition Frame, **Reactor Mk V** (24 power), `reactor_cap` port-def gating | none | **BUILT** — §69 |
| 3 | **THE BREAKWATER** (band 5) and **THE FAR LANTERN** (band 6): the first deep ports that sell what the chart cannot, plus `station_weights` rows for pyx02/pyx03 and two new silhouettes | none | **BUILT** — §70 |
| 4 | deep weather (optional): band-6 grave-fields on a `"\|hulk2"` salted stream, pyx03 rift depth extension, `LANDMARK_KINDS` growth **with every authored row widened in the same commit** | none | **BUILT** — verified by sentinel, §73 |

**The commissioned loop is closed** (2026-08-05): stages 1-3 shipped as §68,
§69 and §70, and stage 4's pieces landed across §70's commit and §71's storms —
which is why no single section number owns it, and why it was confirmed built by
its three sentinels in the code rather than by the prose: `GRAVE_CHANCE` and the
`"|hulk2"` stream, pyx03's rift at `depth_max: 2400.0`, and `LANDMARK_KINDS` at
six. **Nothing is outstanding from this horizon.** The three paragraphs around
this one said otherwise for two weeks after it shipped; see §73.

**One piece of debt survives it.** §41's re-derivation of the `MIDTIER` bar has
been outstanding since §65 and stage 4 was the work that made it due — a rift
depth extension is INCOME, not a sink, and stages 1-3 could be measured against a
bar nobody had re-derived only because none of them could move it. Stage 4 shipped
without it. **It is still owed, and it is now owed by whatever moves income next**
— which Horizon 6's survey-coverage persistence did, in the negative
direction: §80 moved surveys out of the recurring term, so the steady loop is
measured poorer, not richer. See the §64 note above on what a red `STEADY
MIDTIER` now means. No save bump was spent
anywhere in this horizon: deep space persists nothing, and module and commodity
ids flow through the existing generic `owned`/`fit`/cargo paths.

The Hunt's stages 4–6 shipped as §65, §66 and §67 (2026-08-04). The table below
is kept as the record of what was outstanding and how it resolved; **the
discipline stands** — if you defer something, it goes here in the same commit.

**The Hunt, stages 4–6.** The horizon is specced in full in
`~/.claude/plans/i-have-indeed-tested-fuzzy-parnas.md` — outside the repo, which
is most of why these went unnoticed. Stages 1–3 shipped as §38, §39 and §42.

| stage | what | reserved | status |
|---|---|---|---|
| 4 | per-PYX deep identity + deep rifts (landmark/station weights, per-system rift depth) | no save bump | **BUILT** — §65 |
| 5 | waypoint beacons (drop/pick-up at depth, dots on the survey plot) | save v17 | **BUILT** — §66, at v20 |
| 6 | hyper-structures and **Colonies** (claim past 1600u, then in-system warp) | save v18 | **BUILT** — §67, at v20 |

**The save versions they reserved were spent by a different horizon**: v17
became the `apex_down` grandfather and v18 became the faction matrix. Horizon 4
was built instead of the Hunt's back half. That was a legitimate choice — the
Hunt plan's own cut order ends *"defer Colonies to their own horizon"* — but
nothing recorded it, so "v18" pointed at two different features depending on
which document you were holding.

Stage 6 was **not blocked by 4 and 5**: it needed `run_seed` (stage 1), the
`lair_pos` salted-placement precedent (stage 2) and the deep-space streamer, all
of which shipped. The sentence that stood here — *"beacons and per-PYX identity
can stay unbuilt indefinitely"* — was true when it was written and stale the day
§65 and §66 shipped, which is the whole failure mode this section exists to
prevent. Both are built, and Horizon 6 extends both.

### Built, despite what the docs said

`HORIZON-3-COMMISSION.md` — **built**, and recorded as §28. `commission_db.gd`
exists with 28 call sites across `game_state.gd`, `main.gd` and `port_panel.gd`,
and `GSATEST` carries a full suite for it. The README's "not built" line has been
corrected.

Audited 2026-08-04 by cross-checking every Pyxis plan file against the code for a
sentinel symbol per feature: the hold console, mining, the expanse, the hunt, the
commission, damage control and sections all resolve. Nothing else is outstanding.

### The Hunt's back half: decisions taken before building (2026-08-04)

The three outstanding stages are now in progress, and four decisions were
settled with the user before any code:

- **Base building's exclusion is lifted** — §5 carries the amendment and the
  boundary that survives it (no clocks, no queues, nothing built by waiting).
- **One save bump, v20, carrying both stores** (`beacons` and `colonies`). The
  spec reserved a bump per stage; neither store needs a grandfather, so a second
  version would buy nothing. Consequence worth knowing: a stage-5-era v20 save
  has `beacons` and no `colonies`, which is harmless (absent keys default) but
  means v20 describes two shapes.
- **Three PRs, a full green sweep between each** — the spec's own "each
  independently green + shippable", enforced at the review boundary.
- **Colony discovery is by silhouette at range (~1000u), not proximity at
  150u.** The spec's number fails its own arithmetic: 3–5 structures at 150u
  detection cover **0.73%** of the 1500–4200u annulus, a systematic sweep is
  ~161,000u of flying (**≈7.8 hours**), and the deepest point in the real save
  is 1225u. It also re-creates the exact problem stage 3's intel dossier was
  built to solve — the apex, *with* six intel channels, sits in a search space
  ~80× smaller. The pillar ("no intel, found with your eyes") survives; the
  detection radius was the defect. A camera check confirms the default 4000u
  far plane renders a 1000u silhouette without a clip change; the cost is that
  a hyper-structure must be modelled ~7× the apex's silhouette, which the
  fiction wanted anyway.

And one correction to the spec, found by survey before it could mislead:
**`_apply_lair` does not exist** — the shipped keep-out is `built_plan`
(`deep_space.gd:911`), which draws from *no generator at all* rather than from
"its own salt" as the spec instructs. Purely-subtractive-with-no-stream is the
pattern stages 4 and 6 follow; it is strictly stronger than what was specced.

### Why this is not an assertion

The instinct in this codebase is to make a claim checkable rather than trust it,
and that instinct is right often enough that departing from it needs a reason.
The reason is that every honest version costs more than it returns: parsing this
table out of markdown at runtime makes the harness depend on prose, and asserting
"symbol X does not exist" needs reflection GDScript does not offer for free.
A brittle check here would be a fifth entry on this session's list of assertions
that were weaker than their names.

So it is a **discipline, stated once**: the inventory is part of the commit that
changes it. The failure mode it replaces — a repo that implies completeness by
omission — was silent and lasted months; this one is at least visible in a diff.

## 65. The deep gets an accent (v19, Hunt stage 4)

Stages 1–3 of the Hunt gave every system its own hidden engine; stage 4 gives
every system its own *expanse*. A `"deep"` block in the system def authors
station-archetype weights, landmark-kind weights, and the system's weather —
`rift: {depth_max, rich_mult}` — and pyx01 deliberately authors none of it.

### The determinism argument is structural, not statistical

The whole risk of this stage was one line: `plan_cell`'s station archetype pick,
`kinds[rng.randi() % kinds.size()]`, sitting mid-stream in a roll sequence whose
order is load-bearing ("a roll inserted anywhere in it reshuffles every cell in
the game"). The substitution keeps the draw **verbatim** — still `rng.randi()`,
still one draw — and derives the index from the returned uint32 in a pure
`weighted_index(roll, count, weights)` whose first line returns the shipped
modulo whenever no row is authored. So the fingerprint's system cannot move
*by construction*: the branch that could move it does not exist for a def with
no block. `IDENTITY IS ADDITIVE` states the meaning; `WORLD FINGERPRINT`
(unchanged at 3836096557) is the enforcement; and `THE DRAW COUNT DID NOT MOVE`
plans 100 pyx02 cells against a `deep`-stripped twin and requires every
shared-stream product byte-identical while the archetype strings differ — the
only check in the suite that can catch a `randi()`→`randf()` swap.

The landmark pick was a **zero-draw table lookup**, so its weighted form is
gated on row presence and salted on its own stream. The hole that mattered:
nothing in all 57 runs watched landmark *rotation* — the fingerprint hashes no
landmark field and ENVTEST asked kinds and election only — so a kind roll
inserted before `rot_y` would have turned every landmark in the game silently.
`THE LANDMARKS DID NOT TURN` is self-deriving (authored vs stripped def, 81
landmarks, rotations identical, kinds differing on 52) rather than pinned to
recorded literals, so a re-authored row cannot orphan it.

### The weather reaches the Reaches

`RIFT_DEPTH_MAX` was a global 260 — the Reaches and the Quiet, most of two
systems' expanse, had no weather at all. It is now per-system (260/700/1200)
through an accessor whose fallback is the shipped constant passed in, so 260.0
is authored once. `rich_mult` (1.0/1.25/1.5) scales the pot's crate count, not
its grade — `rich_band` is already clamped at band 4, so in the Quiet a richer
shear pays in volume, which is the only richer it has left. And what comes
through a shear now carries the band's owner and its loot like a nest does:
this block predated stage 6 and was spawning flagless FERAL darts with no drop
in bands the unknowns own, with the Tally's no-leash tell missing exactly there.

### Two latent defects the stage surfaced

**A rift could spawn inside the apex arena, and always could.** pyx01's lair
floor is 260 and its rift cap is 260 — the collision has been reachable since
rifts shipped, rare (a sub-1% joint roll) and never asserted. The deep windows
made it likelier, not possible. `spawn_rift` now rejects and re-rolls, with a
**constructive fallback**: the antipode of a colliding roll is at least
2·(chart_edge + RIFT_DEPTH_MIN) − LAIR_KEEPOUT = 140u > 120u clear, for every
authored system. The loop exists so the fallback is almost never the answer;
the fallback exists so "almost" is not the guarantee. `THE SHEAR CLEARS THE
LAIR` is deterministic rather than sampled — it searches seeds for one whose
first roll collides, pins the global RNG, and drives the real spawn; the
sampled version passes ~94% of the time on a build with the loop deleted.

**And the advisory quoted the wrong compass.** The rift broadcast used
`rad_to_deg(bearing)` on the world-convention angle while `rift_rumor` used
`compass_deg` — the §60 defect, surviving in one line, so the advisory and the
rumor named two different bearings for the same shear. Through the glass now.

### Assertions that separate, not overlap

`A RICHER SYSTEM'S WEATHER PAYS MORE` checks the wiring on equality (authored
1.25 vs carried) and the arithmetic with a **3.0× probe**, because 3·CRATE_MIN
= 90 > CRATE_MAX = 36 makes broken and working code fully disjoint — no
authored multiplier separates the ranges, so the test value is deliberately
not an authored one. The pinned-seed idiom recurs in `SPAWNS`: a build that
quietly kept the global cap passes every windowed clause (a shallow roll
satisfies a wide window), so a seed whose first roll lands past 260 under the
authored ceiling is pinned and driven — under the broken build the same seed
compresses into [90, 260] and fails every run.

In passing: `built_plan`'s keep-out assertion now checks all **four** keys it
filters (convoy had been unasserted since v18), and its header comment no
longer claims there is one keep-out when there are two.

### Two injections that stayed green, and were right to

The red-verify battery ran ten injections; eight went red on the assertion that
names them, and two stayed green because **the injections were not defects**,
which is worth recording as precisely as the reds:

- Swapping the archetype pick's `rng.randi()` for `rng.randf()` moves nothing —
  both consume exactly one step of the PCG stream, so every downstream draw
  lands where it did. The hazard the assertion actually guards is a draw-COUNT
  change, and the corrected injection (skip the draw entirely when no row is
  authored — the "why waste a draw on a modulo" refactor someone will one day
  propose) shears the two probes apart and goes red, pulling the fingerprint
  with it because pyx01's cells shift too.
- Flattening an authored weight row to uniform tracks green because `IDENTITY
  IS REAL` reads its expectation **from the authored row** — a retune moves the
  world and the expectation together, which is the design. The defect it
  guards is `weighted_index` consuming its row and ignoring it; that injection
  drops the observed COLD FORGE share to ~25% against an authored ~47% and
  goes red.

An injection that stays green is only a verdict after you know whether it was a
defect. Both of these looked like defects when written and were not; saying so
costs three sentences and saves the next reader from "fixing" either.

### The ceiling was touched by code this stage never modified

Four post-stage MIDTIER samples read 2.92 / 2.94 / 2.90 / **2.97** — a new
recorded maximum, twice in eight draws. Two hypotheses were tested in order,
and both parts of the outcome matter.

**The mechanism hypothesis failed.** Stage 4 upgraded band-2 rift-pack drops,
and the pacing harness pins the wave and event clocks but never pinned the rift
clock — §58's exact shape. Pinned diagnostically: the readings did not move
(2.86–2.99 with the pin). The pin is kept anyway, because it enforces the
harness's own stated rule; it is not the fix because there was nothing to fix.

**The control settled it.** Six samples on the **unmodified parent commit**,
same machine, same hour: 2.88 / 2.92 / 2.93 / 2.95 / 2.97 / **3.00 — a FAIL on
code containing none of this stage.** Stage 4 is exonerated the same way
HOLDTEST's stale baseline was caught in §62: by running the control instead of
writing the story.

**What stands after the exoneration is the real finding: the binding economy
assertion can fail on an unchanged catalog under machine load.** The historical
record said 2.91 ± 0.05 with a max of 2.95; today's machine, mid-session, puts
the tail at 3.00 exactly. MIDTIER's own seed comment says variance comes from
frame-count-dependent interleaving, so load widens the spread — which makes
this the third member of the family STREAMTEST's `worst` clause and PHASE
INTEGRITY already belong to, and it wants the same medicine §41 prescribed
twice: **re-derive the bar from the measured distribution rather than nudge
it.** That is an economy decision (the ceiling is the design), recorded here as
due rather than taken mid-stage. Until then: four samples minimum, idle
machine, and a 2.9x reading proves nothing in either direction.

## 66. Eight bookmarks for a place with no pages (v20, Hunt stage 5)

The deep has no lattice and no chart, so a place worth returning to could only
be remembered by writing its bearing on paper. A beacon is that memory: dropped
where the ship stands, persisted in the save, standing in the world until it is
recovered. **Eight in stock, and the stock is the design** — enough to thread a
route across a system's deep, few enough that each one is a decision. An
unlimited supply would be spray-paint, and the recover verb would never once be
used.

### Where the rules live, and what is derived

The stock is **derived** — `BEACON_STOCK` minus every entry across every system
— never stored, so a hand-edited save cannot carry "stock: 9" beside eight
standing beacons (§59's rule). The drop rule lives in `GameState.drop_beacon`,
with depth as an **argument**, §59's other rule: GameState cannot read the
world, and a rule it cannot be handed is a rule it cannot enforce. The chart
refuses a beacon because the chart already remembers every place in it.

Recovery is **keyed by position, never by index** — an index held on a live
node goes stale the moment a sibling is recovered first, and a position cannot.
The node itself is a projection: the store is authoritative, rebuilt on every
`_load_system`, and `_recover` writes the store before the theater so a ghost
cannot respawn on the next warp.

### The verbs sit where the game already taught them

Dropping lives on the hold console — the one sheet that opens in flight by
design (§43's premise) — with the stock printed on the button (§12's
odds-on-the-button rule), shown only in the deep so it never has to explain a
refusal the world makes visible. Recovery is the mast's hold gesture, because
the deep already taught it, and a flyover pickup would delete the marker at the
exact moment the player arrives at the thing it marks. On the radar a beacon is
`TIER_BEACON`, **below even the ghost**: it is the one marker whose position
the player already knows, so when the 12-marker cap bites it is the cheapest
thing to shed.

### What the probes got wrong before the assertions got it right

Three findings from this stage's own verification, each a probe defect rather
than a code defect, and each worth keeping:

- **The radar is an edge-arrow instrument, not a minimap.** The first board
  probe dropped a beacon on top of the ship and read the board while standing
  on the thing it was looking for — a marker exists only for what is off
  screen, which the collect loop says in its own comment.
- **`teleport_to` moves the ship and not the camera.** The second probe flew
  away and read the board from a seat 400u behind the ship. `start_new_game`
  moves the rig by hand after its teleport for exactly this reason.
- **A full board is not a failure.** The probe then failed because the 12-cap
  had bitten and the beacon was shed first — **which is the design certifying
  itself against a one-sided check**. The final leg asserts both directions:
  on a full board the beacon is absent while twelve others stand; thinned, it
  appears. Either half alone is satisfiable by a beacon that never reaches the
  collection at all.

And one assertion vacuity caught by its own battery: the position-keyed
recovery leg originally recovered in storage order and checked return values,
which remove-the-first-entry-regardless satisfies perfectly — every call
returns true, the stock comes home, and the wrong beacon died every time.
Rewritten around **the survivor's coordinates**, which no remove-something
implementation can fake; the same injection now goes red on exactly that
clause.

### The save

v19 → v20, the four-times-shipped pattern, plus a loader that treats the file
as input rather than truth: unknown systems, malformed entries, non-finite
coordinates and anything past the stock cap are dropped **in file order**, so
which eight survive a corrupt file is deterministic rather than
dictionary-order luck. `migrate19` proves a v19 save arrives with an empty
store and a full rack, and its rubbish pass feeds the loader five broken
shapes and keeps exactly the one valid entry.

## 67. Instruments the size of moons (v20, Hunt stage 6)

The Hunt's back half ends where it was always going to: three to five
hyper-structures per system, past 1,600u, each an instance of the system's own
architectural family — THE ORRERY, THE CLEPSYDRA, THE ASTROLABE, the same
vocabulary as the engines one scale up, because this frontier measured things.
Clear the wardens and it is a Colony: a place you own, and a place the chart can
put you back at.

### The spec's discovery number did not survive its own arithmetic

It said "findable visually at ~150u", with no intel and no radar. Measured:
3–5 objects at 150u cover **0.73%** of the annulus, and a systematic sweep is
~161,000u of flying — **the better part of eight hours**. It also re-created
precisely the problem §42's intel dossier was built to solve: the apex, *with*
six intel channels narrowing a cone, sits in a search space about **80× smaller**
than this, and even §39 could not ship without "an interim bridge: the
hunt-start broadcast includes a free coarse ring".

**The pillar was right and one number was wrong.** A *hyper*-structure visible
only from 150u is the contradiction. `SILHOUETTE_SPAN` is 140u and the thing
reads at ~1,000u, which makes the same sweep about seventy minutes — an
expedition rather than a lottery — and lets "no intel, found with your eyes"
be true instead of aspirational. The camera needed no change: it never sets
`far`, so Godot's 4,000u default already renders it.

### The floor is derived, not chosen

1,500u is 6u past pyx03's worst-case lair *depth* and only **50u** clear of its
lair *radius* (bounds 44 + depth 1450 = 1494) — inside `LAIR_KEEPOUT` 120, so a
structure could roll into the apex arena. 1,600 clears every authored system's
ceiling by at least 150u, and `OUTSIDE THE ARENA` derives that from the two
**authored bands** rather than from this run's lucky roll — the shape
`main.gd`'s survey-hull clearance check already uses.

### A fixed oversample, because a rejection sampler's shape is its own luck

`lair_pos` takes exactly two draws and is auditable at a glance. A
separation-enforcing sampler loops, which makes the stream's shape a function of
its outcome. `hyper_positions` draws a **fixed 16 candidate pairs** regardless
of the count it rolled and selects the first N that clear
`MIN_HYPER_SEPARATION` — invariant shape, deterministic given the salt. Depths
are drawn **independently per candidate**: one shared depth would put every
instance on one ring, and finding one would give you the radius of all the
others, which is the exact inference this pillar exists to deny. Measured over
600 draws: worst pairwise gap **709u** against a 700 floor, worst depth spread
**121u**.

### Where the anti-farm actually lives

The obvious reading is backwards. **Recall home is free and uncapped**
(`_recall_sequence` says why), so a colony jump does not save a one-way trip —
it halves a round one. And 500 credits amortised over five minutes is 100
cr/min, a rounding error against the loop. **Only the cooldown bounds anything**,
and it is one shared stamp, never one per colony: per-colony stamps would make
founding five colonies mean five times the outbound frequency, and that is the
one defect a single-colony test cannot see. `ONE CLOCK FOR ALL OF THEM` stages
two instruments and jumps between them.

`A FOOTHOLD, NOT A FARM` states the number rather than hiding behind a verdict:
the deepest instrument is 4,244u ≈ **738s of flying**, against a 300s cooldown —
**2.46 saved-seconds per cooldown-second**. That ratio exceeding 1.0 is the
*point* of an earned foothold, not a defect, and the deep does not regenerate
within a session anyway. The bound of 3.0 is a guard on the *clock*: it pins the
cooldown above ~245s, so "someone tuned it to 30s" cannot ship.

### Two tautologies this stage's own battery caught

- `NOTHING POINTS AT THEM`'s radar clause was literally `board_clean =
  board_clean` inside a conditional — an assignment that cannot fail, written
  into the check whose whole job is proving an absence. It reads marker instance
  ids against the live structures now.
- `A V19 SAVE ARRIVES WITH A FULL RACK` could not see the colony loader at all.
  Gutting `_load_colonies` entirely left it **green**, because an *absent* key
  and a *rejected* one are indistinguishable from an empty store. The fixture
  now feeds seven broken colony shapes — no colon, unknown system, non-numeric
  index, negative index, non-dict value, missing coordinate — and asserts
  exactly the one valid entry survives.

Both were found by injection, not by reading, and both are the same species as
§65's and §66's: **the assertions are where the defects hide, because nobody
red-verifies the thing they just wrote to catch defects.**

### And the position is persisted at claim

Per instance, in a **dict** rather than a flag — because §5's base-building
exclusion was lifted this horizon and a claimed colony is exactly where a
construction layer would hang; fields cost nothing to add to a dict and a save
migration to add to a set. The stored coordinates *are* the colony: the loader
deliberately has no "does this agree with `run_seed`" filter, because
recomputing and discarding disagreements would delete a founded colony the day
the depth band was retuned. `_load_apex_intel` makes the same choice for the
same reason.

---

## 68. THE QUIET had no far edge (the frontier, stage 1)

A playtest flew to **~8000u** past the chart. The report was that it was brutal
and fight-heavy, and that the ports out there were identical to ones at 500u.
The code said something sharper, and it is worth stating exactly:

- **`BAND_EDGES` ended at 1100.** Every generator table in the game is a
  five-element array indexed by band, so a player at 8000u was reading *the same
  row* as one at 1100u — the same pack HP, the same guard curve, the same five
  shopfronts, the same trap odds.
- **And past 4244u the deep is strictly poorer.** Convoys stop at depth 1000 by
  design (§17). Rifts cap at pyx03's authored 1200. The instruments (§67) end at
  4200. `bounds_of("pyx03") + HYPER_DEPTH_MAX` = **4244u is the deepest authored
  thing in the game**, and the player was at nearly twice that. The reward for
  the second half of that trip was less content than the first half, at
  identical difficulty.

So the complaint was not "the ports don't scale". It was that **distance stopped
meaning anything at 1100u**, and the ports were where that became visible.

### Two bands, appended rather than inserted

`BAND_EDGES` gains 2600 and 5200; `BAND_NAMES` gains **THE FATHOMS** and **THE
UNSOUNDED**. The edges are chosen, not spaced:

- **2600** sits inside the instruments' span (1600–4200), so the Fathoms
  inherits them as authored landmarks in its lower half rather than starting on
  empty ground.
- **5200** is past 4244 — past *everything* authored. That is what the Unsounded
  is: the band where the only thing out there is what the generator makes.

**The fingerprint is safe by construction, not by luck.** `band_of` walks
`BAND_EDGES` from the top down, so every depth under 2600 skips the new entries
and takes a byte-identical path. `WORLD_FINGERPRINT_BEFORE_SEAMS` cannot move,
and the existing assertions check it for free. The interesting risk was the
other one.

### The outer bays, recorded before the change

Cells past 2600u exist *today* as band-4 cells, and after this they re-plan as
band 5/6 — different chance rolls, different content. Nothing out there persists
**except deep bays**, which are keyed by cell and saved. So the argument was:
the bay-relevant draws (station chance, archetype, position, storage) come first
in `plan_cell` and their *count* does not change, because `weighted_index`
derives its index from a returned uint32 and only the modulo can move.

That is an argument. `OUTER_BAYS_BEFORE_FRONTIER` is the measurement: the
station position and storage flag of every bay along four radial lanes through
the 2600–5200 shell in all three systems, **hashed on the commit before the
edges grew** — 23, 22 and 21 bays. The bay count is asserted beside the hash,
because `hash("") == hash("")` is how a probe that stopped finding anything
reports success.

### The palette had to be re-searched, not appended to

§53's band sets were chosen by a 60,000-candidate grid search scored on
*simulated* dichromat separation, with a floor of 0.20. The obvious move was to
append two colours per set. Measured, the best appendable pair scores **0.214 /
0.216 / 0.215** — over the threshold, with **one seventh** of the headroom the
shipped sets have (0.307 / 0.317 / 0.333).

Clearing a floor by 0.014 is how a palette that "meets the standard" ships
unreadable. Each set was re-run whole by the same method — farthest-point seed
then swap refinement, same luminance and peak floors, **near-white pinned at
index 4** because THE QUIET is the band about having no colour left. Seven
colours in a space that comfortably held five costs a little separation:
**0.283 / 0.304 / 0.317**. That is the honest price, and it is recorded rather
than smoothed over.

The default palette is untouched — mode 0 is still byte-identical, which
ACCESSTEST asserts. The new bands come back **wrong** rather than whiter: there
is nowhere whiter to go than the Quiet, and a band that got paler would make the
band about absence stop being the end of anything.

### The bug this stage nearly shipped, found by reading a clamp

`Rift.rich_band()` clamped to `BAND_NAMES.size() - 1`. Appending two bands would
have moved that ceiling from 4 to 6 — and since rifts stop at depth 1200, the
*only* effect would have been a band-4 shear at 1200u paying **Fathom Salvage
(480) instead of Quiet Salvage (340)**. A 41% raise, in content the player
already reaches, delivered by a change whose entire purpose was to add content
1400u further out.

That is §50's stealth pay rise exactly, caught this time by reading the clamp
rather than by measuring the loop afterwards. The ceiling is now a pinned
`GRADE_CEILING` with the reasoning written above it, and `THE WEATHER DID NOT
GET RICHER` asserts the **rule** — a shear pays a grade a rift can actually be
found in — rather than the number 4, so authoring weather further out moves it
deliberately instead of silently.

**The general lesson, and it is new:** a derived bound is safer than a literal
right up until the thing it derives from grows. `BAND_NAMES.size() - 1` was
correct for four years and became a pay rise the moment the array changed. Every
`.size() - 1` in this codebase is a clamp *and* a policy, and the two only look
identical while the array is fixed.

### What makes 5 feel unlike 4, and 6 unlike 5

Not just larger numbers — the tables continue their own tapers (`GUARD_DIFFICULTY`
steps +0.20 where the earlier step was +0.30, keeping an Unsounded guard's shot
at 28.7 against PYX-03's authored sentries at 30.8, still under the chart's
hardest gun on purpose). What changes in kind:

- **THE FATHOMS** — `PACK_ESCORTS` goes to **2**. One escort is a fight with an
  anchor in it; two is a fight with a *formation*, and arc-kiting the swarm stops
  being the whole answer. Its landmark is a **gate**: an arch somebody started
  and stopped, the first landmark in the game you can fly *through*. Its
  broadcast is the first voice out there that is not the GSA.
- **THE UNSOUNDED** — `FAR_LEASH` **260** against the shipped 140. Breaking off
  costs real distance for the first time. Traps run at 0.68 with 3.5s of EMP,
  which finally gives the carried Thermal Sink and the crafted Sink Lattice a
  job. Its landmark is a **cairn** — hull plate stacked by hand, made of *ship*,
  so whoever stacked it was not leaving in that ship. Its broadcast inverts band
  4's closing line one word at a time.

**The Tally's tell stays the Tally's.** `FAR_LEASH` is a *longer* chase, never
an unending one; a zero leash belongs to `unknown_a` alone, and a second faction
owning it would spend the one thing that makes being followed home mean
something. Asserted both directions. For the same reason `flag_for_band` is
unchanged: the frontier deliberately does **not** introduce a fourth unknown —
the Stillness is neutral to the surveyor, and its neutrality is what keeps the
Last Watch's fence open.

### The sweep found eleven defects, and only two were visible

The bands landed green on their own suite — 14 `FRONTIERTEST` assertions, all
red-verified by injection. The full sweep then failed **eleven** assertions in
ten other suites, and the split is the interesting part: two would have been
obvious in play, and nine would not have been found by playing at all.

**What a player would have hit:**

- **The Quiet was re-lit.** `Atmosphere.set_depth` read `DeepSpace.BAND_EDGES`
  as the anchor list of a normalised 0..1 ramp and divided by `size() - 1`, so
  the array's LENGTH set how dark every band was. Appending two edges moved the
  Shoals from 0.333 to 0.200, the Drift from 0.667 to 0.400, and **THE QUIET
  from 1.0 to 0.6** — the band whose entire identity is having no light left.
  Nothing in the lighting was touched and nobody would have looked there. It has
  its own `LIGHT_ANCHORS` now, a copy rather than a reference, saturating at the
  Quiet for the same reason the palette does.
- **The hold offered impossible advice.** `locked_need` is the band itself, and
  band 6 is one rung past the top of `ARCHEOLOGY_TIERS` on purpose, so the strip
  read `ARCHEOLOGY 6` at a game whose ladder stops at 5. §58's rule is that a
  line must use a word the game has taught **or say what to do about it**; this
  said what to do about it and the thing was unreachable. It names the lab now.

**What only the harness would have caught:** reading the two new grades LOST
money (`salvage_unsounded` 660 read into a 420 part — the comment above it,
"a crate is already worth carrying home unread", was the broken rule written out
as if it were a feature); the archeology ladder's new rungs needed 21.7 loops
against a stated ceiling of 12, pricing out of reach the exact rungs that exist
to make frontier salvage readable; band-6 guard posts cost 258 against Bulwark's
250 pool, so the deepest posts were the ones **no fit could hold, including the
fit built to hold them**; the two new ores broke the ceiling stated in their own
block ("every one of them under Intact Relics (260)"); the pilot strip printed
`· -891 TO NEXT` from an unfloored subtraction that was only ever safe because
the top rung used to be the last one; and the manual said "Each has 3 tiers",
denying the existence of the two rungs the frontier had just added.

### The derived bound is a policy, and this stage found three of them

`.size() - 1` is a clamp and a decision at once, and the two only look identical
while the array is fixed. Three separate places had quietly encoded "and the
Quiet is the last band" as arithmetic:

| site | what it meant | what growing the array did |
|---|---|---|
| `Rift.rich_band` | clamp to the best grade | a band-4 shear paying Fathom (480) not Quiet (340) — **+41% at 1200u** |
| `Atmosphere.set_depth` | ramp knots | re-lit every existing band |
| three `for band in range(0, 5)` loops | "all of them" | blind to exactly the bands under test |

The first was caught by reading the clamp before shipping. The second and third
were caught by the sweep. **The lesson is not "prefer literals" — it is that a
derived bound must derive from the thing it actually means.** The light ramp
means "how dark does it get by the Quiet", which is not "how many bands exist".

### Three of the proposed fixes were tautologies

Every "the test was merely stale" verdict was put to three independent
skeptics, and six of seven came back refuted. The most valuable catches were
fixes that would have made assertions *weaker* than the numbers they replaced:

- `ore_goods.size() == CommodityDB.ore_ids().size()` is **x == x** — `ore_goods`
  IS `ore_ids()`. Worse, that literal is the clause's only non-vacuity guard:
  every overlap check runs inside `for o_v in ore_goods`, so an empty ore set
  prints "mining on 0 ores, overlap=none -> PASS". Renaming the `ore` marker key
  — the precise failure the clause exists to detect — would have gone green.
- Deriving the archeology cap makes `NOTHING LEFT TO LEARN` an identity:
  `archeology_next_at()` returns -1 exactly when `archeology + 1 >= size()`, so
  the check holds for a table of four rungs, sixty, or one.
- Re-staging the manual clamp by opening the sheet makes `worst <= avail`
  unfailable, since a live panel is clamped by construction — the shape §36
  records `SHEET FITS` being rewritten to escape.

Those literals stayed literal. What replaced the *count* was the completeness it
had been standing in for: the ores a seam can yield and the ores the mining feed
pays on must be the same set, checked both ways.

### Measurements

`MIDTIER` **2.94 / 2.88 / 2.90 / 2.90, mean 2.905** on an idle machine, against
§63's recorded 2.9025 — the frontier moves the measured loop by 0.003, which is
what "the pacing loop runs at depth 0" is supposed to mean. `CEILING` 0.040-0.041
against 0.15. `ROUTE PARITY` 1.4-2.2% against 20%.

Two notes on how those were taken, both §51's rule earning itself again. A first
set read 2.95/2.97/2.95/2.89 and was **discarded**: a hung Godot process was
eating a core throughout, and §65 records that `MIDTIER` reads high under load.
And the hang itself is worth naming — a harness whose `main.gd` fails to compile
does not error, it boots the game normally and runs forever, so a broken run and
a slow one look identical. One sat for four hours before anyone checked.

Final: **61 runs | 588 PASS | 0 FAIL | 0 script errors | save intact.**

### And `LANDMARK_KINDS` deliberately did not grow (frontier stage 1)

Appending "gate" and "cairn" to it would silently widen the target of every
authored 4-wide weights row in `system_db`, because `weighted_index` falls back
to the uniform pick on a size mismatch — turning pyx02's and pyx03's landmark
accents off and rolling frontier kinds into the Shoals. The new bands take their
kind from the unweighted `LANDMARKS` path, which needs no row. Growing the list
and every authored row **in one commit** is its own change, and it is deferred to
§64 rather than done carelessly here.

---

## 69. Ten modules nobody can buy yet (the frontier, stage 2)

The catalog half of the frontier: four Mk III weapons, three Mk III utilities,
three new tools and a fifth reactor. **Stocked nowhere.** The forge craftables
are the precedent — a catalog row with no counter carrying it is invisible to
the player and safe to ship, and it lets the stage that authors the gear be
separate from the stage that authors the shopfronts.

### Why a Mk ladder is allowed here at all

§9 calls "Mk I → II → III, +10% each" a salvage sink rather than a decision, and
that objection is still right. What makes this line a decision is that the
question is never *which* Mk III — it is **whether a Mk III fits**. Every one
costs a power point its Mk II did not, and the choice it forces is what comes
*off*. The new MECHANICS live in the three tools, each carrying a cost, which is
where §9 says novelty belongs.

Cargo and Tractor deliberately stop at Mk II. Hauling deeper is answered by the
Expedition Frame, which is a trade; a Mk III of everything would be a shopping
list.

### The Mk V is one named product, not a percentage

24 power for 90,000, a step of four where every earlier step was two or three —
and justified the way Mk IV's was, by naming the fit it exists to permit:

    lance_3 (6) + torp_3 (7) + drive_vector_2 (4) + core_aegis (4) + torch (3)
    = 24 exactly, with the second utility bay still empty.

That emptiness is the price. **All-best stays out of reach at 32 against 24** —
a margin of 8 where Mk IV's was 7 — and the assertion computes both from the
live catalog rather than from the numbers in this paragraph, so a cheap new
module cannot quietly close the gap.

### Two defects found in the wiring, both introduced by this stage

- **The HUD ring would have lied.** `ability_cooldown_fraction` divided the
  *hasted* timer by the *unhasted* cooldown, so a fit carrying Surge Capacitors
  would show the ring starting at 0.75 and never reaching full — the readout
  claiming an ability was three-quarters recharged at the instant it fired. Both
  sites read one `ModuleDB.ability_cooldown()` now, so the console's ability row
  and the ship's real timer cannot disagree.
- **The Mk V was for sale at the Anchor.** `upgrade_reactor` checked nothing but
  the price. The cap arrives as an argument now, the way `drop_beacon`'s depth
  does — GameState cannot read the world, and a rule it cannot be handed is a
  rule it cannot enforce — defaulted to the shipped ceiling so every charted
  counter keeps its behaviour by construction. A counter that does not stock it
  says **NOT SOLD HERE** rather than MAX, because MAX would be a lie about the
  ship instead of a fact about the shop.

### A stat key with an untested consumer is a stat key with no consumer

Both new keys were wired, and both were drawn on the refit console per the
`summary_lines` rule — and *nothing asserted either one did anything*. That is
the same defect as an unconsumed stat, wearing better clothes: correct on the
sheet, inert in play, and the store row is a lie.

Both are measured through the REAL code path rather than by re-deriving the
arithmetic, which would assert the formula against itself: a live `Derelict`'s
hold moves **0.100 bare and 0.150 lit**, and the core runs **12.00s → 9.00s**
with the ring reading **1.00** at the instant it fires.

`THE TORCH CUTS FASTER` failed on its first run reading 0.000 both ways —
`hold_tick` measures range from `breach_point`, not the hull centre, so a probe
parked on the hull is out of range and the tick returns having done nothing.
Both samples would have been zero and their *ratio* meaningless. Caught because
the number was obviously wrong, not because the verdict was.

### The weapons could not join the shipped tier sweep

`STRICTLY BETTER` demands every stat RISE, and `interval` is the one stat where
lower is better — which is why it covers six drives and utilities and no guns at
all. `EVERY MK III EARNS ITS RUNG` states the direction per key, which is the
only way a typo'd interval is caught, and it re-checks the family rule the
catalog states about itself: Pulse at 133 dps stays under Lance's 168.

### Measurements

**61 runs | 592 PASS | 0 FAIL | 0 script errors | save intact.** No save bump:
module ids ride `owned`/`fit` as strings, and `reactor_tier`'s loader already
clamps against `REACTOR_TIERS.size()`.

Six new assertions, **eight injections, 8/8 red with zero collateral** — and the
run took 4 minutes against the previous round's 37, because the agents were
given two things learned the hard way: a fresh worktree has no `.godot` cache
and hangs forever without an import pass, and `--check-only --script` answers in
0.6s. **That command always exits 0** — the Parse Error count is the signal, not
the exit code. Three silent hangs this horizon, one of four hours, were all this
failure and all preventable by one line.

---

## 70. The counters that sell it (the frontier, stage 3)

THE BREAKWATER at band 5 and THE FAR LANTERN at band 6, and with them the loop
closes: fly past 2600u, fight band-5 threats with band-5 guns bought at band-5
prices, come home loaded or do not. Both owned by **THE STILLNESS** — the
Stillness keeps the lights, at 1100, 2600 and 5200, and a fourth unknown would
have spent a fresh mystery to say a thing the Last Watch already said.

### The audit ran before the code, and found six defects in the proposal

Four adversarial readers went at the two archetypes as a *specification* — no
file written — against the arbitrage rails, the generator and save contract,
reachability and the copy, and the stock/fence/service wiring. **Two of what
they found would have shipped.**

**The fence would have sold what the market hid.** `trades_at` short-circuits on
`is_component` BEFORE the deep-port exemption, so a component stays restricted to
its own `trade_only_at` list however deep the counter sits. The Far Lantern's
`fence_goods` names eleven components; its market tab would have listed none of
them, its fence tab would have sold all eleven at 1.45x, and the two data
sources would have disagreed at one desk with nothing going red — `STATIONTEST`
sweeps `SystemDB.port_ids()` only, and `EVERY NAMED BUYER BUYS` walks each
good's own list, which never named the port. This is §11's rule pointing the
other way: **declared tradeable must mean actually tradeable**, and a fence is a
declaration.

**And `repair_price` 1600 broke a property nobody had written down.** Every
shipped deep repair bay is cheaper than the charted 1400, and from the Reaches
outward the tail gets *kinder*: 900, then 800. The first draft put 1600 on the
band with the highest `PACK_HP` in the game — the only repair above the chart's
own price, at the place furthest from any alternative. It reads
**[900, 800, 750, 700]** now and is asserted never to rise. "You pay for the
address" was already said once by `outfit_mult` 1.10; saying it twice was just a
worse number.

The other four were caught the same way and cost nothing because the code did
not exist yet: a duplicated `lens_unsounded` in a fence list that already had it
(the UI iterates the array, so it renders twice), the `for_band` row widths, the
`(1/3/4/5 for bands 1-4)` legend that would have stopped one band short of the
rows beneath it, and two comments that go false — dealt with in §68's own note.

### Two silhouettes, because a marker is all you get before the flight

Both ports were specced wearing shapes another archetype already wears at a band
where both spawn — `military` against BLACKWATCH YARD, `cantina` against THE
LAST WATCH. A port's NAME only reaches the player at `DOCK_RANGE` 5.0, so the
silhouette is the entire content of a marker until you have committed to the
approach. That is the argument `landmarks.gd` makes for giving each band a
different shape rather than one shape in six colours, and it applies harder here
because the wrong guess costs a four-hundred-unit flight rather than a glance.

THE BREAKWATER is a wall with its buttresses on the deep-facing side — it has a
FRONT, which is what makes it read as a breakwater rather than a block. THE FAR
LANTERN is the smallest silhouette of any port in the game carrying the
brightest single element: a mast, one enormous lamp, an unlit housing for
something that used to be bigger, and two habitation cans, because somebody
lives there. `ONE SHAPE, ONE COUNTER` asserts the rule over every band.

### The staleness trap, caught in my own guard

`EVERY AUTHORED ROW IS THE RIGHT WIDTH` first read `rows_checked >= 18` — a
literal that is nothing but today's count, and the precise species of defect
§68 spent eleven failures learning. It is the rule now: bands 5 and 6 must be
**authored** somewhere, because a sweep over zero rows passes perfectly.

### Measurements

**61 runs | 598 PASS | 0 FAIL | 0 script errors | save intact.** No save bump —
the third stage in a row that needed none.

`NO ARBITRAGE` widened from 11 counters and 121 pairs to **13 and 169**, picking
the new defs up with zero edits because it iterates `ARCHETYPES` directly, and
the binding pair did not move: the Grinning Void's x0.80 against Forgeline
Depot's x0.75, −0.05. Both new defs clear the guard rails with room (0.70/1.10
and 0.72/1.05), and the self-pairs are −0.40 and −0.33.

`MIDTIER` **2.86 / 2.95 / 2.90 / 2.93, mean 2.91** on an idle machine against
stage 1's 2.905 — a prediction confirmed rather than a hope: ports are sinks,
and `PACINGTEST`'s route search reads `SystemDB.port_ids()`, which deep stations
are excluded from by construction. `CEILING` **halved, 0.041 → 0.020**, because
the Mk III line and the Mk V roughly doubled the catalog denominator. That is
exactly what a sink is supposed to buy.

Six new assertions across stages 2 and 3, **six injections, 6/6 red with zero
collateral.** Two of them test things that were nearly wrong in the assertions
themselves rather than in the game: one deletes the frontier weight rows outright
to prove the non-vacuity clause catches an empty sweep, and one removes a single
port from a single component's `trade_only_at` to reproduce the fence/market
disagreement the audit caught before it existed.

---

## 71. Weather in the Unsounded

Four hundred units across, wandering, and the only thing in this game that kills
you without shooting at you. Asked for as *"random, massive space storms out
beyond 5000u, hurricane-esque… ships without a Mk II drive or higher pulled in
slowly, unable to escape without specialized equipment… these destroy anything
unable to escape their pull."*

### Three collisions, asked about before anything was built

Each part of that sentence hit a rule this repo already enforces, so all three
went to the owner as questions rather than to the compiler as assumptions.

- **"Unable to escape" is forbidden by a constant.** `apply_tether` ends
  `minf(cap, TETHER_DRAG_CEILING)` at 1.5, `enforce_floors` floors `max_speed` at
  1.6, and §40 adds *"no tuning of it may build a cage."*
- **"Destroyed" had no precedent.** §18, of the deep's nastiest trap: *"It can
  cost you the run; it cannot trap you in one."*
- **"Beyond 5000u" is not a band edge**, and §17 rejects "an absolute number that
  happens to suit PYX-01".

Answered: band 6, the game's existing worst death (emergency warp +
`spill_unread`, which at 5200u is a ~15-minute flight home and every unread crate
left behind), and a pull that goes **through `apply_tether`** so the promise holds
by construction rather than by this file remembering it.

### The gradient replaces the gate

Thrust and drag add; an EMP kills thrust while drag keeps applying. So net
progress is `max_speed·(1 − duty) − drag` and the break-even speed is
`drag / (1 − duty)` — which means **the storm needs no rule about drive tiers at
all**, only a gradient:

| dist | drag | duty | break-even speed |
|---|---|---|---|
| 200 | 0.300 | — | 0.30 |
| 36 (eyewall) | 1.202 | 0.000 | **1.20** |
| 18 | 1.301 | 0.608 | 3.32 |
| 0 | 1.400 | 0.860 | **10.00** |

The eyewall threshold sits **under the 1.6 floor**, so every legal fit escapes
from anywhere outside the eye, always. The centre sits at exactly 10.00 —
between the best tier-1 drive (9.25) and the best tier-2 (10.75). `DRAG_MAX` is
*derived* from that threshold rather than chosen, and `THE CEILING IS THE
PROMISE` reads the drive totals out of the live catalog, so **a Mk III drive
turns the clause red and makes somebody re-decide the boundary** instead of
silently moving it.

**The pull is not the trap**, and the header says so in the first paragraph: the
radii where a real drive is genuinely pinned are single digits (Vector 5.1u,
Cruise 0.8u, Cruise Mk II never). The teeth are the **cancelled move order** —
`emp_stun` clears `has_move_target`, every 4–5s in the eye — and a damage clock
ramping to 14/s. From dead centre a Cruise Mk II behind Bulwark's 250 shield
still dies; with a carried Thermal Sink it is a seven-second walk out costing 57.
**The specialised equipment already existed and had never had a job.**

### Wandering turned out to be free

The plan flagged "genuinely wandering" as the expensive option because the deep
is stateless. It is not: **the deep's purity rule governs CELLS**, which must be
pure functions of position and seed. `Rift` is already the precedent for weather
that is not — `spawn_rift` uses the unsalted global `randf()` because *"this is
session weather, not world generation"*, and a rift *"is weather you were present
for… a reload never owed it to you."* A storm is a `system_root` child: no cell,
no salted stream, no fingerprint, no saved byte.

§14 — being jumped must be something you could have reacted to — is answered by
one clamp rather than by making it stationary: inside the warning ring the drift
is projected onto the tangent, so **a storm never closes the last 520u; the
player does.**

### Six defects, and the one that matters most is a class

Three in the object, caught in two harness runs: the pull was guarded on
`is_protected()` (which would have made the Aegis core a tractor immunity nobody
designed); the session-weather check searched `storm.gd` for `note_log` and was
**defeated by the header comment promising it never calls it**; and the standoff
clamp had its sign inverted, so a storm that "never closes" walked 8.5u straight
down the ship's throat — caught only because that clause is two-sided.

And three in the assertions themselves, which is the pattern worth naming:

**`TWO STORMS CANNOT BUILD A CAGE` was vacuous.** It staged the ship exactly
midway between two storms, so their inward unit vectors cancelled and it measured
**0.000 — a number it would print with no clamp at all.** It was asserting that
two opposed unit vectors sum to zero. The proof it was blind rather than lucky:
its neighbour moved 2.4u → 4.4u in the *same process*. It now stages them 60°
apart at equal distance so the pulls add, and asserts the channel actually
filled — the missing clause that let zero pass.

### Assertions that fail by CRASHING, not by printing FAIL

Three times this horizon now, and it deserves its own name because the remedy is
different from the vacuity remedy:

| where | what happened |
|---|---|
| §68, `TRAP_EMP` | shortening a band table threw out-of-bounds in the next clause; 9 of 14 never printed |
| §70 (stage 4) | the orphan grave-field branch recorded the orphan, then read `["pos"]` off the hull that was missing |
| §71 | `_load_system` freed the probe storm; two later clauses read a freed node |

In every case the run did not fail — it **aborted or hung**, which a sweep
reports as a timeout or a script error rather than a red line, and which a
summary line renders as *fewer passes* rather than as a failure. The rules that
follow:

- **An assertion must survive the defect it describes.** Bound every loop by the
  array's own length; `continue` after recording a missing thing rather than
  falling through to arithmetic on it.
- **An assertion that tears down the world belongs last**, and one that frees a
  group must spare the fixtures its neighbours are standing on.
- Red-verify now reports **`harness_completed` separately from
  `target_went_red`**, because those two failures look identical in a summary and
  have opposite fixes.

### A bound with one side cannot tell "softly" from "not at all"

`NOTHING IN A STORM OUT-HITS THE CHART` compared three storm constants against
three chart constants with `<`, and shipped that way. A red-verify that happened
to zero `EYE_DPS_MAX` produced:

    per-tick 0.00 ... sustained 0.0/s ... -> PASS

**Zeroing the constants made it pass harder.** The rule was never "the storm hits
softly"; it is "the storm hits, AND softer than the chart" — and a one-sided
bound cannot express the conjunction. Floors added, and the line now says "(and
it does hit)" so the shape of the claim is legible from the output alone.

Fourth vacuity this horizon, and the pattern across all four is one sentence:
**every bound needs the side that proves the thing exists**, because absence
satisfies every inequality pointing away from it.

### And a number that was wrong while its verdict was right

`THE TELEGRAPH READS FROM FURTHER OUT THAN THE POINT OF NO RETURN` walked inward
assigning on every match instead of stopping at the first, so it printed the
*smallest* radius where the floor fit is beaten: **0.5u for a true 33.2u**. The
PASS beside it was correct throughout. This is the third instance this session,
and it is the argument for printing the measurement next to the verdict rather
than the verdict alone — a bare PASS would have hidden all three.

### Measurements

**62 runs, 612 PASS, 0 FAIL** at PR 1; the instruments add four more clauses.
`MIDTIER` untouched and structurally so: the storm generates no income, the
pacing profiles are measured at depth 0, and a storm cannot exist inside 5400.
What it *is* is a **denial** of income that `MIDTIER` is blind to — and its real
economic teeth are emergent rather than authored: **you cannot work a site inside
a storm's pull ring**, because the drag pulls a parked ship out of `CRACK_RANGE`
and `hold_tick` releases.

One adjacent fix, found on the way: **`FX.vortex` had never honoured
`reduce_motion()`** — every other effect in that file does. §30's rule is
gate-at-the-function, and it is gated there now; both callers already discarded
the return.

---

## 72. The ships that were red for no reason

Asked for as *"some friendly forces appear as if they are hostile… let's also
allow the player to right click on the friendly units to display a list of
options to help them interact. Each reputation level with the factions should
dictate the options available."*

Two complaints, and the first one was written down in this file two horizons
ago. §47's own text, on why `hostiles` could not be derived from faction:

> An allied picket in it would be painted red, blasted by the player's own area
> weapons, and counted as a live raid.

The fix chosen there was a SECOND group, `combatants`, leaving `hostiles`
untouched — which resolved the counting and the targeting, and left the
**painting** exactly as described. A GSA picket cannot fire on the surveyor at
any standing (`GSA_SURVEYOR_FLOOR`), patrols charted space specifically so it
reads as patrolled, and drew the same THREAT red as the thing hunting you. The
player reported it as a bug three horizons later. It was a documented,
predicted, unbuilt half of a fix.

### The rule is one sentence

**Red means it shoots at you. Any other colour is a flag.**

`marker_color()` on both hostile classes, routed through
`GameState.hostile_to_player()` — not through the band. The distinction is the
whole reason the ramp still works: a neutral you pick a fight with turns red the
frame it *answers*, which is the same test `cycle_target`, the music and the
selection ladder already use. Three surfaces now ask it and cannot disagree:

| surface | was | is |
|---|---|---|
| radar marker | `Palette.THREAT` for everything in `hostiles` | `marker_color()`, via the per-node override that already existed at `hud.gd:372` and had one implementor |
| target reticle | one THREAT material, always | recoloured on change; goes red when the ship answers, not when you give the order |
| HP bar (fill **and** backing) | THREAT fill on a red backing | both from `marker_color()`, refreshed per frame against a cached colour |

**Faction tint rather than a new "friendly" swatch**, against HORIZON-4 finding
A2's warning that the colour channel is already double-booked (band tint, raid
tint, faction tint). A fourth booking would have been the easy answer. The
convoy clusters and the muster marker already speak faction tint *on this very
instrument*, so this spends a booking that was already made rather than making
one.

**And a fourth instrument had already drifted.** `Main._threat_near_player()`
carries the comment *"the same question Music asks, asked once here and handed
to both — the lighting and the score must never disagree"*. Music's copy grew
the IFF filter when a neutral convoy was found raising the combat layer; this
one did not. The lighting had been calling a GSA picket a fight ever since. Same
defect as the radar, one instrument over, found by the repair verb's combat gate
refusing to fire beside a friendly ship — and then caught twice more by the new
harness before the fixture was right.

### What a flag will discuss (the contact menu)

The second complaint is the larger one: fourteen flags, a full attitude matrix,
and exactly one verb the player could aim at any of them. Right-click a flagged
ship that is not shooting at you and it says what it will discuss.

**The band opens a door; the world decides what is behind it.** An ALLIED ship
with no circumstances offers exactly what a NEUTRAL one does plus its bearings —
asserted, because a ladder that reads as a reward list is a ladder that promises
things the situation cannot deliver.

| band | options |
|---|---|
| HOSTILE | *none — it is not taking questions, and left-click already engages it* |
| WARY / NEUTRAL | HAIL · ENGAGE |
| FRIENDLY | + BEARINGS · SELL HOLD *(convoys, non-empty quote)* |
| ALLIED | + REQUEST REPAIRS *(damaged, out of combat)* · REQUEST ESCORT *(route pickets, off cooldown)* · MARK MY TARGET *(live locked target)* |

**GATES, NEVER PRICES.** `NO PRICE MOVES WITH STANDING` is asserted against
Market's own functions, and the brief's "free or discounted at ALLIED" would
have broken it. What a band buys is whether a line is on the menu at all; every
figure is flat. A field repair costs `missing * PortPanel.REPAIR_FULL_PRICE` —
the dock's own const, so the two can never drift and the deep mercies' authored
discount is never undercut.

**The escort is the only verb that puts a second gun on the board**, and it
needed no new rules to stay honest:

* it **cannot deplete the world** (§51) — `SKIRMISH_HP_FLOOR` already clamps
  damage from any combatant at half hull, and every payout in `_die` is gated on
  player attribution. It softens; you still have to land the kill. *(2000 damage
  from an ally leaves a 120hp machine on exactly 60, alive — asserted.)*
* it **does not strip the beat** — `unmanned_routes()` counts a route manned by
  its picket's `route_i` meta, which an escorting picket keeps, so the cordon
  tick spawns no relief and the Cordon never doubles.
* it **stops at the marker** — the band-1 beacon has promised since v13 that
  patrols do not operate past the chart edge. An escort is the first Cordon ship
  that could ever have been invited across it, so crossing the line is how you
  say goodbye to your escort.
* it **does not answer the player's parley** — finding A3's exclusion, applied to
  the guard scan as well as to the beat.

Movement is at `PATROL_SPEED` 3.2 against the player's 5.75, deliberately: a
player running farming loops outruns their own escort. That is the pacing valve
and the characterisation at once — *a patrol is a presence, not a pursuer*.

**A plate, not a console.** `console_open()` gates interdiction and muster
eligibility, so a right-click on a passing convoy that registered as a console
would quietly hold the world's events off for as long as it stood. Asserted
directly. It is also deliberately absent from `band_controls()`: that inventory
is every centre-anchored plate, and this one is positioned over a moving ship.

### What the harness caught

`PYXIS_CONTACTTEST`, 19 assertions. Four of them found nothing wrong with the
game and everything wrong with the test, which is worth recording because each
was a real property stated badly:

1. **The reticle assertion raced the mounts.** It ordered an attack and checked
   the colour one frame later. But `fights_the_player()` reads `_aggro` and
   `_target`, and an *order* sets neither — the first shot landing does. The
   test was asserting the wrong moment of a mechanism the code describes
   correctly. It now asserts the answer, through the path a player's shot
   actually takes.
2. **The skirmish clock broke off mid-assertion.** Six seconds of fire and a
   machine stands down for twelve, nulling `_target`. A sub-assertion landing in
   that window read "the escort did not take the target" when what happened was
   "the escort had already fought it". Reported opposite results on consecutive
   runs.
3. **The parley exclusion was tested with a ship the exclusion never saw.** The
   GSA is HOSTILE to the Tithe at baseline, so a Tithe raider is picked up by the
   ordinary enemy scan whatever the escort thinks. The test proved nothing and
   looked like it proved something. It uses a League sentry now — FRIENDLY to the
   GSA, in no enemy list — so the guard scan is the only thing that can select
   it.
4. **The events were not pinned.** A muster firing mid-run calls `end_escort()`,
   correctly, and the escort assertions then failed about one run in six. §33's
   pinning list exists for exactly this and the wave timer alone does not cover
   it.

### The half of §47 that turned out not to be a defect

§47's sentence named three consequences of leaving allies in `hostiles`: painted
red, blasted by the player's own area weapons, counted as a live raid. The first
is fixed above. The third was never live — raid counting reads the `raider`
group, which no ally joins. The second was put to an evidence pass before
anything was changed, and **the evidence says it is deliberate**:

* `FactionDB.WITNESS_RANGE` is 25.0 and its own comment dimensions it as *"3.6x
  OVERCHARGE_RADIUS (7.0), which is the case this feature exists for: the whole
  blast fits inside it"*. You cannot call a case an oversight when its radius
  set the constant.
* `SwarmHostile` carries the grudge because *"a convoy is the commonest thing an
  OVERCHARGE discharge catches by accident"*.
* §62: *"Any damage provokes, including one point of splash."*

So splash catching a flag is a measured mechanic, and the price of the accident
was deliberately set at half a minute of aggro rather than a faction. It stays.

**And the blanket filter that looked like the fix would have broken something
else.** A torpedo has no direct-hit path at all — `_detonate`'s sweep of
`hostiles` is its ONLY damage vector, and the shell carries a position and a
shooter, never an intended target. Gating that sweep on `hostile_to_player()`
would make a torpedo-only fit unable to ever damage a neutral, because a neutral
becomes hostile-to-player only by first being damaged. §56 states the rule that
would have broken in as many words: *"Attacking a neutral deliberately still
works and has to."*

### What was actually wrong was the escort, and it was ours

`OVERCHARGE_RADIUS` is 7.0. `ESCORT_FOLLOW` was written at 4.0. Nobody put those
two numbers beside each other, so REQUEST ESCORT stationed an **ALLIED** Cordon
picket permanently inside the player's own blast radius, taking **69% of full
burst** on every discharge — from the starter core, on the one ability button
the game gives away free, which cannot be declined. `take_damage` then sets
`_aggro` to whoever fired and `_pick_target` returns `_aggro` above every other
branch, so the game sold the player a bodyguard and had it turn and shoot them.

The escort is the new thing, so the escort is what moves: `ESCORT_FOLLOW` is 8.0
and `THE ESCORT STANDS CLEAR OF YOUR OWN BLAST` asserts the RELATIONSHIP between
the two constants rather than either literal — the failure was not a wrong
number, it was two right numbers in different files that nothing compared. It is
deliberately not written as `OVERCHARGE_RADIUS + 1.0`: that is a compile-time
edge from `Hostile` to `PlayerShip`, and §39's class-cycle lesson is why this
file does not reach for one. `BASE_HP`'s comment established the pattern — let
the harness compute what the constant should be.

**Still open, and it is a design call rather than a defect** (see §64): whether
an ALLIED ship should be spared the player's area weapons at all. Sparing only
the positive bands is defensible — HORIZON-4:234-236 already asserts *"allied
ships are emphatically not in `hostiles`"*, a rule the code never implemented —
but it puts a band-shaped hole in a group six systems read as uniform, it makes
careless area fire strictly safer exactly as the stakes rise, and it leaves a
torpedo-only fit unable to open on an ALLIED ship at all. The escort fix removes
the systematic harm without paying any of that, so the question can wait for
somebody who wants to answer it on purpose.

### The pacing band, measured rather than argued

The escort is the only thing in this change that could move money: it puts a
second gun on the board, and §51 records `MIDTIER` sitting at 2.91 against a
hard 3.00 with about 0.04 of real headroom. One post-change run came back at
2.96, which is close enough to the bar to be worth stopping for — and §41's
standing instruction is that this number takes **four samples, not one**.

Five samples on each side of the change, same machine, same binary:

| | samples | mean | sd | range |
|---|---|---|---|---|
| before (fda5150) | 5 | 2.898 | 0.016 | 2.88 – 2.92 |
| after (escort + fixes) | 5 | 2.910 | 0.025 | 2.88 – 2.94 |

A shift of **+0.012** against a documented noise band of ±0.05, Welch t = 0.88 —
not significant, and the two ranges overlap almost entirely. The 2.96 was
scatter. The escort's duty cycle (60s of escort against a 240s cooldown, walking
at PATROL_SPEED 3.2 against the player's 5.75, with SKIRMISH_HP_FLOOR meaning it
can never land a killing blow) costs the pacing band nothing measurable.

Worth stating what this does NOT do: it is ten samples of one metric, not the
re-derivation of the `MIDTIER` bar that §64 still lists as outstanding debt. The
bar is still un-re-derived. This says only that the escort did not move the
measurement against it.

### What an adversarial review found that 634 green assertions did not

The sweep was green and the feature harness was green, and a five-lens review of
the diff still found four real defects. Every one of them lives at a **seam**
between the new code and a rule written down somewhere else — which is precisely
where a harness written by the author of the change does not look, because the
author is asserting the thing they just built.

**1. The parley exclusion was on the feet and not on the gun.** (critical)
`_worth_leaving_the_beat` has refused to WALK to a raider under a standoff since
finding A3. `_weapon` fires at whatever `_combat_target` returns on distance
alone and never asks that question. The guard scan added for the escort
carefully excluded standoff raiders — and then fell through to the ORDINARY
enemy scan, which did not, and the GSA is HOSTILE to the Tithe at baseline. So:
take an escort, get interdicted, and a GSA picket parked 4.0u off the player has
a pack orbiting at 3.2u well inside its 9.0u `ENGAGE_RANGE`. One shot calls
`break_parley` and **an NPC deletes the player's PAY / BLUFF / REFUSE choice.**
The hole was reachable by luck before; the escort made it reachable on demand.
Fixed at the SOURCE — the exclusion is now in `_pick_target` in both hostile
classes, so movement, the gun and the skirmish clock all inherit it — and
`spawn_interdiction` now releases an escort outright, which is the third set
piece that owns the ships around the player.

**2. The station was clamped against the player, not against the marker.**
(high) `_tick_escort` ends an escort when the PLAYER crosses `chart_edge()`. A
player sitting just inside the line with their nose pointed inward put the
station up to `ESCORT_FOLLOW` **past** it, plus `_process`'s 0.4 wander on top.
THE LINE IS THE EDGE was written after a muster picket sat 0.4u over; this could
put a Cordon ship 4.4u over. The station now carries the same 3u inset the
muster line does.

**3. `hail_contact` read a property half the eligible ships do not have.** (high)
`designation` is declared on `Hostile` and not on `SwarmHostile`. `Object.get()`
answers null for a property a script does not have, and `String(null)` renders
`"<null>"` — so every hail to a convoy dart would have ended in `· <null>`.
Asked with `in` now.

**4. A favour became a vendetta.** (high) `_release_grudge` let go of the
PLAYER specifically. Every caller before the contact menu was
`Main.witness_attack`, which always passes the player, so "release the player"
and "release what the grudge named" were the same sentence and the narrower one
got written. MARK MY TARGET points an ALLY at an NPC: the thirty-second clock
ran out, the pointer did not, and a bounded favour became permanent until one of
them died — **the exact unbounded latch that function exists to prevent, reached
from the one direction it did not cover.** Both classes now remember what the
grudge was about and let go of that.

The lesson is §54's, arrived at from the other side. That section says *assert
the path the player takes, not the function it wraps*; this adds **assert the
seams you did not write**. All four defects are now assertions in
`PYXIS_CONTACTTEST`, and each was confirmed to go red with its fix removed.

**Moving a station-keeper does not move it** — `Hostile._process` assigns
`global_position` from `_home` every frame, so a fixture shoved aside is back on
its post next frame. That is also why a station-keeper cannot be offered an
escort: one that ended anywhere else would teleport home.

---

## 73. Three things that were true when they were written

Horizon 6 opens with a commit that builds nothing. A week of playtesting
produced five asks — per-PYX identity past the chart, beacon navigation, a
legible chart, more hotkeys, multiple pilots — and the reconnaissance pass for
them turned up a live crash, a save-destroying downgrade path, and an inventory
that had been contradicting itself for two weeks. None of that is worth carrying
under a feature commit, so it went first, alone.

The three defects share a shape, and it is the one this document exists to
catch: **each was correct the day it was written and was made false by something
that never looked at it.**

### The comment was right, the line under it was not

`plan_cell` has an early return for band 0 and eight lines of comment above it
explaining that every content key must be present on every path, because
`built_plan` indexes `plan["convoy"]` with no `.get` — a keep-out filter that
tolerated a missing key would silently stop filtering. It even records the
arithmetic: cell centres at `(64i+32, 64k+32)` put the four innermost at 45.25u,
PYX-02's bounds are 48.0, so those four sit at depth -2.75 and PYX-02 is the only
system with band-0 cells at all.

Then `landmark`, `seams` and `hulk2` were appended to the band>0 path across
three horizons, and none of them was added to the early return. `hulk2` is in
`built_plan`'s **own** keep-out loop, so from v20 onward, flying near the PYX-02
origin threw `Invalid access to key 'hulk2'` — the identical defect the comment
was written about, reintroduced three feet underneath it.

**The assertion was the actual failure.** `EVERY CELL ANSWERS EVERY QUESTION`
swept all three systems and both signs of the boundary, and stayed green through
all of it, because it asked for the seven keys that existed the day it was
written. A hand-written expectation agrees with whatever it is given. It now
derives the key set from a deep cell — `plan_cell(64, 64)`, ~5838u out, band 6 in
every system — so the next append cannot be silent. That is the general form of
§54's rule: *a list of what should be there is a claim; asking the thing that
knows is a measurement.*

### Refusing to load was never the dangerous half

`load_game` has always declined a save whose version is higher than the build's.
What it did not do was stop the **write**: `_ready` calls `reset_to_starter()`
when load returns false, and the debounced save a second later put a starter run
on top of a file this build merely could not read. Run a newer build once and an
older one after — a rollback, a second machine, a beta lane — and the pilot was
gone, not locked. The only notice was a `push_warning`, which on a phone is no
notice at all.

The fix is the existing one-way `lock_saving()`, which is exactly the right
shape: nothing downstream can opt back in, so the file survives whatever the
player does next. Two details it forced:

- **A version of 0 is not a version from the future.** An unreadable save is
  rubbish and there is nothing there to protect, so that case keeps the old
  start-fresh behaviour. The two are now separate branches saying separate things.
- **`has_save()` is true for a file that did not load**, so the title screen
  offered CONTINUE into what was actually a fresh starter run. It now hides
  CONTINUE and says what happened, because *"your save is fine, this build cannot
  read it"* is the only part of this a player needs.

`SAVETEST=future` asserts both halves — refused **and** intact, compared on the
bytes, since a save that reloads to the same values would satisfy anything
softer. Refusing to load while still being able to write is the bug wearing the
fix's clothes.

### The inventory that needed the discipline it describes

§64 is the only forward-looking list in the repo and its own opening calls it
load-bearing: *if you build or defer something, update it in the same commit.*
Three of its passages were stale — the frontier's stage 4 row read "not built"
nine lines under a paragraph saying the frontier had nothing outstanding, and a
sentence still read *"beacons and per-PYX identity can stay unbuilt
indefinitely"* after both shipped as §65 and §66. Stage 4 was verified built by
its three sentinels (`GRAVE_CHANCE` and the `"|hulk2"` stream, pyx03's
`depth_max: 2400.0`, `LANDMARK_KINDS` at six) rather than by reading the prose
that got it wrong.

The README was wrong in the same direction and twice over: 44 tags and 61 runs in
one paragraph, 62 in another, against a `TAGS` array of 46 and a `SAVE_MODES` of
17 — and `SAVETEST` is not in `TAGS` at all, so the arithmetic it implied was
never the arithmetic the sweep did. It is 46 + 18 = 64 runs now. **The PASS total
was not incremented, it was retired**: a number measured beside a wrong run count
cannot be adjusted, only taken again.

The lesson is not "check the docs." Every one of these was written by somebody
being careful, and each was falsified by a later change that had no reason to
look at it. What actually holds is the assertion that derives rather than
declares, and the discipline of putting the inventory edit in the same commit —
which is what §64 already said, and what this section is the cost of not doing.

---

## 74. Three keys, and the two doors that were already open

Horizon 6's second commit, and the smallest of the six: `chart` (C),
`drop_beacon` (B), `pause` (P). Asked for as *"more hot keys / keyboard
shortcuts so that the player is more easily able to access various actions or
interface tools."*

The keys themselves are four lines of dispatch. Everything below is what adding
them found, which is the usual ratio.

### The stance did not change, and that is what picked the list

§30's line still holds: touch is the primary platform and a hotkey is an
**additive desktop layer, never the advertised door**. So every one of these
opens something that already has a touch door — the chart button, the hold
console's DROP A BEACON row, the pause button — and none of them is a new verb.

That rule is also what rejected three candidates. `refit` is a dock-context
surface and a global key would need docked-state gating to buy what one tap
already gives. `recall` is a one-keypress teleport with no confirm, and every
other key on the list is undone by pressing it again. Target-cancel is Escape
rung 3 already.

The ids are the copy. `pause_menu` renders a settings row as
`action.to_upper().replace("_", " ")` with no display-name table anywhere, so
the id IS what the player reads — which is why the beacon action is
`drop_beacon` ("DROP BEACON") and not `beacon` ("BEACON", which names a thing
rather than a verb).

### The chart's lock was on the button, not on the chart

`set_panels_locked` flips `refit_button.enabled` and `chart_button.enabled`, and
that was sufficient for as long as a Button was the only way in. It is called
from three places — docking, undocking, and `_set_boss_active` — and
`disengage_apex`'s own comment leans on the result: a player who had bitten off
more than they could chew **had to stand there**, because the chart was shut.

A hotkey that called `chart_panel.open()` would have walked straight past all of
that. The fix is not a second copy of the condition in `Main.toggle_chart` —
`docked_port != null or boss_active` spelled out a fourth time is a copy free to
drift the next time a caller is added. The HUD now **stores** the lock it was
already applying, and the wrapper asks for it. One rule, two doors, no
derivation.

### One key, two nodes, and the seam was already there

P cannot be handled in one place, and the reason is structural rather than
awkward:

- **CameraRig is `PROCESS_MODE_INHERIT`**, so it stops receiving input the
  instant the tree pauses. It can open and can never close.
- **PauseMenu is `PROCESS_MODE_ALWAYS`**, but `_unhandled_input` drops every
  event behind `if not is_open`. It can close and can never open.

Either half alone ships a key that pauses and cannot unpause. Escape is already
split down exactly this seam, and PauseMenu's own header says why it must be:
*"handling it in both places would close a console and pause at once."* So P
copies Escape's division and nothing new was invented.

Two deliberate differences from Escape, both worth stating because they look
like oversights:

- **P resumes from any page, rather than backing out one step.** `cancel` means
  "back out of what I opened"; `pause` means "unpause". A player on the settings
  page pressing the pause key is asking for the game, not for the root page.
- **P is inert while the manual is up**, because the manual guard returns first.
  The manual owns its own back-out, and a key that resumed the game out from
  under an open page would leave the player flying with a page in their face.

### The manual had been lying since it shipped

The desktop page printed `W A S D`, `SPACE` and `I` as hand-typed strings while
the settings page two taps away let the player change all three. The manual was
false for anyone who used the feature the manual describes, and adding three
more literals would have deepened it by half again.

`_binding_name` — which reads the live InputMap, and which PauseMenu had kept
private — moved to `GameState.binding_name` and both readers now share it. It
reads the InputMap rather than the saved `settings` dict on purpose: an action
still on its project.godot default has no entry in that dict, so the dict would
answer "—" for most actions on a fresh install.

### What the assertions asked for

`EVERY ACTION IS REBINDABLE OR RESERVED` is exact sorted-array equality between
the InputMap and `REBINDABLE + ["cancel"]`, so it is **two-sided**: declaring
the actions without listing them fails, and listing them without declaring them
fails too. Both halves in one commit, which is the point of writing it that way.

`REBINDABLE` is not bookkeeping. It drives `rebind`'s conflict-stealing loop, so
an action outside it is invisible to that loop and a player could put two live
actions on one key — the thing `NO SHARED KEY` forbids, reached through the one
door it cannot see.

Three legs added to `PYXIS_INPUTTEST`, each measured in both directions because
a refusal clause alone is satisfied perfectly by a dead key:

- **THE CHART KEY OBEYS THE LOCK** — opens, closes, refuses while panels are
  locked, and opens again once clear.
- **THE BEACON KEY REFUSES THE CHART** — standing at depth 0 the rack does not
  move, because the key reaches `drop_beacon_here`'s refusal rather than
  carrying a copy of it.
- **PAUSE IS ONE KEY** — pauses, and unpauses from the same key, which is the
  assertion that would have caught either half of the two-node split being
  missing.

`_press_hold_key` became `_press_key(code)` and kept its old caller. §54's rule
is why these push real `InputEventKey`s through `Input` rather than calling the
panels: calling `chart_panel.open()` would pass with no action declared, no key
bound and no dispatch written.

### What the adversarial pass found, after the keys worked

The three keys were written, self-checked and committed before a verification
sweep ran over the diff. It came back with four defects, and the pattern in them
is worth more than the fixes: **every one was a rule that had only ever been
tested through the door that could not violate it.**

**A toggle key is not a button pressed twice.** `ChartPanel.close_panel` ended
with an unguarded `tween_callback(func(): visible = false)`, and `create_tween`
does not kill the earlier tween. Close and reopen inside `SLIDE_TIME` and that
callback fires on a panel that is open again, leaving `is_open` true with
`visible` false — an invisible chart the next press "closes", read by the player
as a key that did nothing. It was unreachable for as long as the HUD button was
the only door, because **a button only ever opens**. PauseMenu has carried the
guard since it shipped, and its comment says why; it was the one panel that
already had a toggle. Chart now carries it too.

**A default is a binding.** `rebind`'s conflict-stealing loop read the saved
overrides dict — which holds only actions the player has *already moved*. An
action still on its project.godot default has no entry there at all, which is
precisely what leaves the default in place. So on a fresh install, binding
`move_up` to C returned true and left `chart` on C as well: two live actions on
one key, produced by the function written to prevent that, while
`NO SHARED KEY` stayed green because its first rebind puts the action into the
dict and its second one therefore finds it. The loop now reads the live
InputMap, the same source `binding_name` was moved to GameState for.

**Reserved has two directions.** Keeping `cancel` out of REBINDABLE stops it
being moved *off* Escape. Nothing stopped an action being moved *onto* Escape,
because the conflict loop walks REBINDABLE and `cancel` is not in it. For
`chart` and `drop_beacon` the result was a dead key — CameraRig tests `cancel`
first. For `pause` it was worse: PauseMenu tests `pause` before `cancel`, so
Escape stopped backing out one step and started resuming from any page, which
falsifies the manual's numbered ladder **from the settings screen**. `rebind`
now refuses `KEY_ESCAPE` outright, since the only other repair is taking Escape
away from `cancel`.

**A refusal clause alone is a dead key's alibi.** This section claimed all three
new legs were measured in both directions. The beacon leg was not: it pressed B
at depth 0 and asserted the rack had not moved, which a missing action, a wrong
keycode, a deleted dispatch branch and a typo'd `has_method` all satisfy
perfectly. It measured that a keypress does nothing. The leg now flies out past
the chart edge, drops a beacon, checks the rack fell and a node stands, and only
then comes home to be refused.

Two smaller things the same pass caught. `OS.get_keycode_string` answers
`"Space"`, `"Tab"`, `"Escape"` — mixed case, in an all-caps interface — so
`binding_name` upper-cases. And the commit's own thesis was half-delivered: the
manual started reading the live map while `tutorial.gd` and `barks.gd` went on
printing `W A S D`, which left the **first sentence in the game** as the lying
surface and the two-menus-deep page as the honest one. Both now read the map;
the bark table carries `{MOVE}` and `{TARGET}` tokens because a `const` cannot
call anything.

Two new assertions, `ESCAPE IS RESERVED BOTH WAYS` and
`A DEFAULT IS A BINDING TOO`, each red-verified against the code as it stood
before this pass.

---

## 75. Five pilots, and the half of the save that was never the run's

Asked for as *"allow users to create an account so they are able to save their
progress and save multiple of their games so they can experiment with different
builds."* Answered as **local pilot profiles**, and the distinction is not a
dodge — it is what the ask actually needs. §2 keeps this game single-player and
offline-capable and §5 refuses live-ops, but §2 also says the local save is
explicitly serialized to *"keep a server port possible without building one
now"*. Profiles spend none of that option. Multiple builds side by side need no
server at all, and this leaves the one that might exist later exactly as reachable
as it was.

### The load-bearing part is the split, not the path

The obvious reading of this feature is "point `save_path` at a folder per
pilot", and that reading is a data-loss bug. The save was a flat 42-key dict
holding two different kinds of thing, and nobody had needed to tell them apart
while there was exactly one save:

- **The run.** Salvage, cargo, fit, systems, intel, beacons, colonies, ledger.
- **The device.** Key bindings, volumes, UI scale, colour-vision mode, haptics,
  reduce-motion, the telemetry opt-in, and the audio mute.

Made per-pilot without separating them, **switching pilots rebinds the player's
keyboard and changes their colour-vision mode** — an accessibility setting, lost
by picking a different save. So the device half moved to `user://prefs.json` and
`set_setting` now writes there immediately instead of dirtying the run.

An upgrading player's bindings live in their old save and nowhere else, so
`load_game` still READS those keys — once, to seed the new file — and nothing
writes them again. `_prefs_loaded` is what makes that a one-way door: once
prefs.json exists it wins, and a pilot saved muted no longer mutes the device for
everyone else.

### "Outlives the run" turned out to be two claims

`reset_to_starter` preserves three fields and its comments call each of them
something that *outlives the run*: the ship's name, the paint, and the
commission. Profiles split that phrase, because a thing can outlive the run and
still belong to the pilot rather than to the machine.

Settled with the owner: **identity is per-pilot.** Each pilot names their own
ship, starts in default paint, and earns their own commission. That is what makes
a second pilot a separate RUN rather than the same captain in another slot, which
is what "experiment with different builds" asks for. The cost is recorded rather
than hidden — a second pilot re-earns the commission, the accent colours ≥ 8 it
unlocks, and the deep's `from_commissioned` broadcast copy. It gates flavour and
cosmetics, never a system and never a lane, so it costs a new pilot nothing they
cannot reach.

`audio_muted` went the other way, for the reason its own comment already gave.

**The tutorial runs once per device.** Somebody building a fourth fit does not
want six steps of onboarding again. The subtlety is written down because it is
the kind that gets discovered later: `tutorial_step` STAYS in the save, because a
pilot halfway through step three is run state and sharing that between pilots
would be its own bug. What moved is a single `tutorial_seen` flag, which only
decides whether a new pilot starts at −1 instead of 0.

### The switch is one function, because the obvious two lines are wrong

`save_path = X; load_game()` looks like a switch and is not one. `load_game`
no-ops on a missing file and returns false, which leaves the OUTGOING pilot fully
loaded in memory under the incoming pilot's name — and the first thing that saved
would write one run into another's folder. `switch_profile` flushes the outgoing
run synchronously (the one-second debounce is pending on almost every switch),
moves the path, loads or lays down a starter run, and then clears the three
things that are in neither the save nor `reset_to_starter`: `diverts`,
`last_read_tiered`, and the derived stats.

### Where each piece had to live, and why

**`Profiles` is a leaf.** It references no other class in the project. §39
records a compile-time dependency from a widely-preloaded script closing a
class-list cycle: forty parse errors in files nobody had touched, and a boot that
hung rather than failed. A registry that speaks only FileAccess, DirAccess and
JSON cannot join that.

**The profile is resolved in `GameState._ready`, not by Main.** GameState is an
autoload and its `_ready` runs before the main scene exists, so anything waiting
for Main to point `save_path` at a pilot would already have loaded the wrong
file. That is also why the harness check there cannot call
`Main.harness_running()` — it asks `DisplayServer.get_name() == "headless"`
instead, which is the right question rather than a cheap proxy: every suite runs
`--headless`, a player's game never does, and the thing being prevented is a
headless run moving the player's real save into a pilot folder.

**`save_path` stays a plain var, set once.** Three harnesses assign it and never
restore it, so a live-derived property would stomp a probe path mid-suite and
write the real save.

**The registry write is double-guarded**, and the second guard is the one that
matters: `save_path == the active pilot's path`. A harness redirects `save_path`
without redirecting the registry, so that equality is what proves a write belongs
to a real pilot rather than to a test running past.

### Two things fixed because the save layer was open

`NOTIFICATION_APPLICATION_PAUSED` now saves. Until this, the only triggers were
the desktop window closing and the object being deleted — so on the platform this
game is actually for, everything since the last debounced write depended on the
player returning to the app, and a task-switch the OS then reclaimed took it.

Telemetry rows carry the opaque pilot id. Without it, up to five runs interleave
in one file with nothing to tell them apart, which destroys the file's stated
purpose: every question it exists to answer is asked of one run.


### What the adversarial pass found, and the shape of it

Four verifiers went over this commit before it merged. They returned five
blockers, and the pattern is worth more than the list: **every one was a rule
that had exactly one instance until this commit gave it a second.**

**The feature's own decision was not implemented.** `switch_profile` called
`reset_to_starter()` and stopped — and `reset_to_starter` deliberately preserves
`ship_name`, `livery` and `commissioned`, because for a NEW SURVEY on one pilot
that is right. A brand-new pilot therefore booted wearing the outgoing pilot's
paint, under their ship's name, already commissioned, and wrote all three into
their own file on the first save. The settle recorded above was in the doc and in
the commit message and nowhere in the code. `reset_to_starter` is unchanged; the
three lines belong where the PILOT changes, not where the run does.

**A fresh install never got a pilot at all.** With no legacy save there is
nothing to migrate, so the registry was written empty, `active_id` was `""`, and
`save_path` stayed on the old single-save path. The player pressed NEW SURVEY,
played a whole run into `user://save.json`, and the first time they opened PILOTS
and made one, `switch_profile` moved the path with `active_profile` still empty —
so the outgoing save was skipped and the run was stranded in a file nothing would
read again. The migration could not rescue it either: it is keyed on the
registry's absence, and the registry existed. A player now has a pilot from the
first boot.

**A second file needed the rule the first one had.** `_save_prefs` is reached
from `set_setting`, and SAVETEST's `write` leg sets three settings while
ACCESSTEST rebinds a dozen keys — so the sweep would have rewritten the
developer's real bindings and volumes on every run. `lock_saving()` is not the
fix, because the three suites most likely to trip it deliberately do not lock:
the file layer is what they test. Prefs are off under a harness instead, with an
empty path as the switch, checked before `save_enabled` for exactly that reason.
Off rather than pointed at a shared scratch file, which is cross-run coupling by
another name — and which would have taken `migrate5` (asserts
`settings == DEFAULT_SETTINGS`) and `partial6` (whose whole subject is the
key-by-key settings merge) down with it.

**One future-dated pilot locked all five.** `lock_saving()` is one-way and
process-wide, and `switch_profile` gated on `save_enabled` — so a single save
from a newer build made every row on the pilots page a dead button for the
session, with four readable runs behind them. The lock is about the FILE it
refused; switching is moving away from that file. It gates on the refusal now,
and the page asks `can_switch_profile()` BEFORE creating, because
`Profiles.create` stamps the new id active and discovering the refusal afterwards
left an empty folder holding the active flag.

**The migration recorded itself before it moved anything.** Writing the registry
first makes `needs_migration()` false forever — it IS "the registry exists" — so
a rename that failed could never be retried, and the player kept a registry
naming an empty folder while their run sat in `save.json`. The file moves first
now, and a failure leaves the disk clean enough that the next boot tries again.
The window that remains — moved, not yet recorded — is covered by rebuilding the
registry from the folders on disk, because a folder holding a real save is a
pilot whatever the registry says.

Three smaller ones worth naming. Deleting the pilot you are standing in left
`save_path` pointing into a removed folder while the session played on, every
save failing silently against a missing directory. `_refresh_pilots` measured its
own container in the same frame it `queue_free`d the old rows, so the page laid
out at roughly double height and hung off the bottom of the screen permanently.
And the pilots page had no scroll and no Escape: five pilots want ~480px of a
band that is ~250px on the project's own default desktop window, which pushed
BACK — the only exit — off the screen.

### The sweep's guard had to grow with the thing it guards

`run_harness.sh` md5'd `save.json` before and after, and after this change that
file does not even exist on a migrated install — so a harness could scribble over
pilot two while the guard compared a missing file to itself and called it clean.
It now digests the whole save surface: the legacy file if present, the registry,
the prefs, and every pilot's save.

### The second file was a leak nobody had a rule for yet

Splitting device settings into their own file created a second player-owned file,
and every rule this repo has about not writing the player's data named the first
one. `_save_prefs` is reached from `set_setting`, `set_audio_muted` and
`set_tutorial_step(-1)`, and the suites call those constantly — ACCESSTEST alone
rebinds keys a dozen times, and SAVETEST's `write` leg sets three settings. So
the sweep would have been rewriting the developer's real bindings, volumes and
colour-vision mode on every run.

`lock_saving()` is not the fix, because the three suites most likely to trip it —
SAVETEST, LIVERYTEST, HUNTTEST — deliberately do NOT lock: the file layer is what
they test. The fix is that **prefs are off under a harness**, with an empty
`prefs_path` as the switch, checked before `save_enabled` precisely because those
suites leave saving on.

Off rather than pointed at a shared scratch file, because a shared scratch file
is cross-run coupling by another name: one suite's leftover volume becomes
another suite's starting state, across a sweep that runs them in a fixed order.
With the layer off, `_prefs_loaded` stays false, `load_game` seeds settings from
the save exactly as it did before this commit, and **every existing assertion
keeps the meaning it was written with** — which matters most for `migrate5`,
which asserts `settings == DEFAULT_SETTINGS`, and `partial6`, whose entire
subject is merging a v6 save's settings key by key.

The two suites that want the layer assign a path and call `reload_prefs()`, which
makes a redirect take effect for READS as well — `_ready` is the only other
reader and it has long since run. SAVETEST sets that state **per mode**: the bare
read is the one leg that consumes what another wrote (it is the other half of
`=write`, which is why run_harness.sh keeps the pair adjacent), and every other
mode starts from no prefs file at all.

`PYXIS_PROFILETEST` is the second harness after SAVETEST that cannot call
`lock_saving()`, for the same reason: the file layer IS the subject. It redirects
every path — registry, base dir, legacy, prefs and save — **before the world is
built**, because the state pinning has already queued a debounced save by then
and "the debounce is slower than the harness" is luck rather than a guarantee.
Eight assertions, of which two carry the feature: `NO BLEED BETWEEN PILOTS`
compares every serialized key of a fresh pilot against a starter and names the
field that crossed, and `A PILOT SURVIVES THE ROUND TRIP` is its other half —
because "the new pilot is clean" is also satisfied by a switch that quietly
discarded the old one.

### A postscript: the gate that could not fail

Found the first time somebody ran the §75 commands on a machine where `godot`
is not on `PATH` — which on macOS is the normal state, because the binary lives
inside the `.app` bundle and `run_harness.sh` has always defaulted to the full
path rather than the bare name.

```
$ godot --headless --path . --import
zsh: command not found: godot
$ godot --headless --path . --check-only --script scripts/main.gd 2>&1 | grep -c 'Parse Error'
0
```

**That `0` is a pass.** `2>&1` pipes `command not found` into `grep`, which
counts zero occurrences of "Parse Error" and prints the number that means clean.
The parse gate reported a healthy parse from a compiler that never ran, one line
after the import pass had also silently not run — and the sweep was then started
against a project whose class registry had no entry for a brand-new
`class_name`. Every one of the 65 runs would have hung for the full 1500s
backstop: the better part of a day to discover a missing `--import`.

Three things came out of it, and only the first is the obvious one:

- **The check now lives in `run_harness.sh`**, which proves the binary exists,
  then parse-checks once, and refuses to start on either failure with exit 2 and
  no summary line. A sweep that measured nothing must not print a line that looks
  like a sweep.
- **It greps three strings, not one.** A missing `--import` does not produce
  `Parse Error`; it produces `Could not find type "X"` followed by a cascade of
  `Cannot infer the type`. The idiom everyone had been running could not have
  caught the case that actually happened.
- **The by-hand form short-circuits on `--version`**, so a missing binary prints
  nothing instead of a convincing zero.

The shape is the one §73 already named, arriving from a new direction: a check
whose failure mode is indistinguishable from its success. §73's baseline was a
number nobody could have known was stale; this was a gate that answered "fine"
when asked a question it never heard. The remedy is the same both times — make
the check derive its answer from something that must be true, rather than from
the absence of a string.

---

## 76. Three systems that stop reading the same

The first of the five playtest notes, and the one the horizon is named for:
*"other than the small charted area in each Pyx, they all feel the same once the
user begins exploring further out."* True, and true by construction — past
`bounds` every system read from the same band tables, the same landmark list and
the same palette, and the only per-Pyx data that reached the deep was §65's
accent: two weight tables and a rift ceiling.

### Four channels that cannot move a draw, and one that can

The obvious lever is density — more packs here, fewer stations there — and it is
mostly unavailable. A chance multiplier spends the same draw only where the
gate's body draws nothing conditionally, and in `plan_cell` that is true at
exactly three sites: convoy, grave and deep-storage, all written under the
"every draw happens before the gate" rule stated above the convoy block.
Everywhere else a passing roll draws two to six more values, so scaling the
threshold changes the draw COUNT and shears every later position in the cell
apart — which is what `THE DRAW COUNT DID NOT MOVE` exists to catch, and not a
rule to route around. `SAFE_DENSITY_KINDS` is that list, and `_mult` refuses
anything outside it rather than trusting the caller.

So identity comes from four channels that touch no draw at all:

- **Names.** `band_names` per system. PYX-01's are an authority's filing
  language degrading with distance (THE OUTER GRID → THE UNFILED → NO RETURN
  FILED); PYX-02 names its ground by what came out of it (THE TAILINGS, THE
  CINDER DRIFT, THE UNSMELTED); PYX-03 speaks in soundings (THE DEEP MARKS, THE
  LEADLINE, NO BOTTOM FOUND). `BAND_NAMES` stays the default and the fallback,
  and only the readouts meaning *"where you are right now"* go through
  `band_name_in` — the skill ladders use those same strings as RANK names and
  must not start varying by system.
- **Wash.** Three tints applied in `configure`, where the dressing is built
  rather than where the world is generated. PYX-01 keeps the shipped cold blue,
  PYX-02 is iron-oxide and ember, PYX-03 is a dark green sea. Nothing here is
  hashed and no draw is taken, which makes it the cheapest identity in the game.
- **Weights.** §65's mechanism, authored harder.
- **Broadcasts.** A copy overlay. Whether a post exists and where it stands stay
  the shared stream's business; this replaces the words.

### The starter system was the one that could not have any

`IDENTITY IS ADDITIVE` asserted that PYX-01 authors no `deep` block at all. That
was true, enforceable, and the wrong rule: the world fingerprint is measured over
PYX-01, so the assertion was protecting the hash by forbidding the *dictionary* —
and PYX-01 is where the tutorial runs and where the manual's first hour sends
you. Identity that skipped it was identity the complaining player met last.

The real invariant was narrower: no key that changes the **shared RNG stream** in
the hashed system. Names, wash, broadcasts and a signature drawn on its own
salted stream are none of those. So `SHARED_STREAM_KEYS` names the three that
are — `station_weights`, `landmark_weights`, `density` — the assertion reads that
list from `SystemDB` rather than restating it, and PYX-01 authors everything
else. A second clause, `THE STARTER SYSTEM HAS A CHARACTER`, asserts it actually
does: the first clause is a refusal, and a refusal is satisfied perfectly by the
empty block this section spent two horizons in.

### One thing each, and one class

`SignatureSite` is the thing a player points at, and it is **one class with three
kinds** because §17 already settled that: *the gradient is parameters, not new
classes*. Three near-identical Node3Ds differing in a mesh and a reward would be
three files to keep in step with the pick ladder, the radar table and the
spawner.

- **THE DROWNED RELAYS** (PYX-01, bands 1–2) — dead GSA watch-buoys. The thing
  you find in the near deep of the authority's own system is the authority's own
  equipment, unmaintained. Answers once with a degraded transmission.
- **THE SLAG TIDES** (PYX-02, bands 2–4) — cooling spoil that ticks hull heat
  inside its radius. Hazard and reward in one object, which is the whole of the
  works' character. It goes through `take_hit`, the same door storms use, so
  mitigation and the death path behave identically; and per §18 it *cannot* trap
  you in a run, at 1.4/s against any hull that reached it.
- **THE SOUNDING LINES** (PYX-03, bands 3–5) — plumb-line pylons that quote a
  free bearing to the nearest deep station, through `compass_deg` (§60), asked
  of the **world** rather than the generator so a station `built_plan` suppressed
  is never pointed at. The only object in the deep that points *down*, which is
  the joke the mute system is making.

The roll is appended last, on its own salted stream, drawing before it gates, and
its gate reads nothing the shared stream produced — the three rules every
appended block in `plan_cell` lives under. It joins both of `built_plan`'s
keep-out lists, because content does not get an exemption from the arena for
being new. `TIER_SIGNATURE` is appended at the bottom of the radar tiers, lowest
priority and first shed at the marker cap: a site does not move, does not shoot,
and will still be there next pass.

### What the assertions had to grow

`THE DRAW COUNT DID NOT MOVE` now compares `seams` and `landmark` as strictly as
the shared stream, because identity gained channels that could have reached them.
`DENSITY IS ALIVE` counts convoys across 576 cells with the def authored and
stripped and requires the authored count to be strictly higher — a stream that
did not move is also satisfied by a multiplier of no effect. And
`SCALING A THRESHOLD ONLY MOVES THE BAR` asserts the nesting property that makes
the whole approach safe: scaling a threshold up can only ADD cells, because the
roll is the same number and only the bar moved, so every convoy the stripped
probe placed must still be there, in place. A multiplier that *moved* one would
be a reshuffle, which is what a changed draw count looks like from outside.

## 77. The line that Godot never names

§76 shipped and `main` would not boot. Not a failed assertion, not a red
harness — the project did not load at all:

```
SCRIPT ERROR: Parse Error: Could not parse global class "DeepSpace"
              from "res://scripts/deep_space.gd".
ERROR: Failed to create an autoload, script 'res://scripts/game_state.gd'
       is not compiling.
ERROR: Failed to load script "res://scripts/main.gd" with error "Parse error".
```

Between those three lines sat roughly four hundred more: `Could not resolve
class "DeepSpace"` at `game_state.gd:1638`, at `:2352`, and at two hundred and
fifty separate lines of `main.gd` — every file that names the type, none of
which had been touched. The class list printed during `update_scripts_classes`
carried a blank entry where a name should have been.

The defect was one tab, at `deep_space.gd:1204`.

### A comment is not a body

Reviewing the signature block had turned up a real bug — placements were being
measured from `base`, the cell's minimum corner, rather than its centre, so
three sites in four landed inside a neighbouring cell while parented to this
one's node. The fix was correct and the explanation written above it was
correct. What went wrong is that the explanation and the line it explained were
pasted back at one tab instead of two:

```gdscript
	if not sig.is_empty() and ...:
		# FROM THE CELL CENTRE, NOT `base`. ...
	# polar offset from it put three sites in four inside a NEIGHBOURING cell
	...
	var sp2 := cell_centre(cx, cz) + ...
		if depth_at(sp2) >= CONTENT_MIN_DEPTH ...
```

GDScript sees an `if` with no body, then an indent that opens nothing. A human
sees twelve lines of prose sitting exactly where the body belongs and reads
straight past it — **which is a cost of this file's own house style.** Every
block here opens with a paragraph. That is worth keeping, and it means the one
place a body-less block could hide is the place this project always puts text.

### Why review did not catch it, and why the gate did not either

The gate for this already existed. §73 added a parse check to
`run_harness.sh` that greps for exactly these strings and refuses to start the
sweep. It would have caught this in 0.6 seconds. It did not run, because the
sweep is run on the machine that has Godot and the merge happened before it —
the order was build, review, merge, sweep, and only the last step could see it.

That ordering is not going to change: the binary lives on one machine and the
edits are written on another. So the check has to be able to run where the
edits are written. `tools/check_scripts.py` is that check — plain Python, no
binary, two rules:

- a block opener whose next logical line does not indent under it;
- `SomeClass.member` naming something that class does not declare.

Both are chosen for the same reason: they take down the entire class registry,
and neither is visible in a diff. It is strictly weaker than Godot's parser and
that is fine — it runs first, and it prints the line number that Godot's four
hundred lines never mention.

### The checker that could not fail

Worth recording because it is the fourth time this shape has appeared here.
The first version of the reference check resolved a member by walking `extends`
and returning "fine" the moment it reached a class it did not know — reasoning
that an engine base like `Node3D` has members it cannot enumerate. Run against
the whole project it reported **0 unresolved references**, and that number was
worth nothing: every class in this project bottoms out at `Node3D`, `Control`
or `RefCounted`, so every lookup reached that bail and every reference
resolved. Pointed at a deliberate `DeepSpace.compass_degrees` typo, it stayed
green.

What fixed it was not a better heuristic but the right rule.
`ClassName.member` is a **static** access: Godot resolves it against static
functions, consts, enums and inner classes only, and an inherited *instance*
member is not reachable through a class name at all. So running out of the
project's own `extends` chain is a real answer rather than a missing one, and
the engine contributes only `new` plus the SCREAMING_CASE notification and enum
constants — a set small enough to name in one line and concede deliberately.

The pattern, stated once more because it keeps recurring: **an assertion that
cannot fail for the reason it exists is worse than no assertion,** because it
occupies the space where a real one would go and reports a number that reads
like evidence. Red-verify or do not ship it. Both checks here go red against a
fixture that reintroduces their defect, and the fixture is the thing that made
the first version's vacuity visible.

### Also in this commit

The README's harness counts were stale again — it claimed 46 tags and 64 runs
against a `TAGS` array holding 48 and a sweep of 66, drifting by exactly the
two tags §75 and §76 added (`PROFILETEST`, `SIGTEST`). The paragraph that
carries those numbers already warns that it has been wrong before and tells the
reader to check `run_harness.sh` instead. It was wrong again anyway. Numbers
that must be maintained by hand will drift; the only durable fix is to derive
them, which is filed in §64 rather than done here.

## 78. The chart was mostly not there

The third playtest note: *"the Chart needs enhancement — the surveys show but
are extremely hard to understand."* Read as written, that is a request for
better labels. It is not. The plot was drawn behind a gate that closed most of
the time, and the largest legibility win available was to open it.

`_refresh_plot` set `_plot.visible = _hunt_is_live(_selected)`, and
`_hunt_is_live` requires the system to be charted, to have an `apex` block, AND
for that engine to still be alive. So the picture of the deep was absent for any
system whose engine you had killed — which is every system you have finished —
and absent again for any system without an authored apex. A player who had done
the thing the game asks them to do opened the chart and found the deep
represented by nothing at all. "Hard to understand" was, more often than not,
"hard to understand because it is not there."

### Four things a reader needs, in the order they need them

**The canvas is unconditional.** The bar is now CHARTED, which is the bar the
rest of the sheet already uses. Everything the hunt owns — the band, the cones,
the estimate ring, the caption — still gates on `_hunt_is_live` inside the draw.
Only the surface is always drawn.

**The scale fits the content, not the hunt.** The old scale was
`(half the rect) / (bounds + band[1])` — derived from the apex band's outer
edge, which is not a bound on anything the player owns. A beacon dropped past it
projected outside the rect; in pyx01 that edge is 340u out, which is not far at
all. It was not *missing*, which is how this was first written up and is worth
correcting here: a Control does not clip its own draw calls, so the beacon was
painted over whatever sibling widget occupied that pixel. See the clipping note
below. `fit_radius_for` now takes the maximum over
`bounds`, every beacon, every colony, the ship, and the hunt band when it is
live. **The ship is an argument rather than a scene lookup**, for the reason
`drop_beacon` takes depth as one: a function that reaches into the tree for half
its answer cannot be handed a case, and this one has to be checkable without a
world.

**The rings say what the depths are.** `BAND_EDGES` drawn at `bounds + edge`,
because depth is measured from the charted edge and `depth_at` subtracts
`bounds`. Each is labelled through `band_name_in`, so a system that renamed its
bands in §76 says its own names here, and through `band_glyph`, so the ring is
identified by shape as well as hue. That conversion lives in one function,
`band_ring_radius`, because a ring drawn at the wrong radius is a lie the reader
cannot detect — every other layer would still agree with itself.

**You are on it.** Nothing in `chart_panel.gd` referenced the player node at
all. The ship is now a triangle pointing where the ship points, drawn last so
nothing buries it. A dot would have been easier and would have thrown away the
heading, which is the half of "where am I" that makes the plot flyable — the
orientation contract at the top of `_draw_plot` is what lets a bearing be read
off this picture and flown, and the marker is now the thing that demonstrates it.

### The legend is shapes, not a colour key

§30's redundancy rule says a new layer needs a glyph or a shape, never only a
colour. Beacons and colonies deliberately share the livery accent, because
"mine" is what that colour means here — so the distinction between them is
carried entirely by outline: a square for a colony, a ringed dot for a beacon, a
triangle for the ship, a hollow circle for the estimate. The legend draws those
same primitives rather than describing them, so an entry cannot drift from the
layer it labels.

No new glyph vocabulary was invented, which was the first instinct and the wrong
one. `BAND_GLYPHS` and `FAMILY_GLYPHS` already carry a rule that one shape must
not mean two things in this game, and a third text alphabet would have had to be
checked against both forever. Drawn shapes are outside that namespace entirely.

### The rings were one band out, and looked perfect

`BAND_EDGES` is off by one from the band number, and nothing says so: `band_of`
returns `i + 1` for the largest edge it clears, so `BAND_EDGES[4]` is 2600 —
the floor of band **5**, THE FATHOMS. The first version of the ring loop walked
edge indices, drew at `bounds + BAND_EDGES[i]`, took the glyph and colour from
`i`, and took the name from the depth. So every ring carried the right word
beside the wrong mark, one band low.

**It renders a completely convincing picture.** The rings are still evenly
nested, still in the right order, still coloured in the right sequence — there
is no visual tell at all, which is exactly why a drawing change needs assertions
and not only eyes. Only the world's own `band_of` could say the marks were
wrong, and it did, on the first run.

The fix is not just the index. The loop now walks BAND NUMBERS, and the radius,
name, glyph and colour are all keyed off that one number: `band_ring_radius`
converts band → radius and holds the off-by-one in one documented place, and
`ring_label` composes the drawn string so that **the assertion reads what the
plot draws** rather than rebuilding it from the same two accessors. That
distinction is the whole value of the leg — a test that composed the label
itself would agree with a draw that had gone back to keying the glyph off the
edge index, since both would be making the same mistake. Red-verified against
both reintroductions: a bad radius and a bad glyph key each go red, on band 1.

The depth round-trip is gone too. `band_name_in` takes a depth, and band 1's
edge is depth 0, which `band_of` maps to CHARTED rather than THE SHOALS — the
boundary is the one value that belongs to neither side. Names come from
`band_name_of` by index; only the assertion crosses the two, deliberately.

### A test that shared a bug with the thing it tested

`THE BAR IS A ROUND NUMBER` failed on `1627.5 -> 1000.0 is not 1/2/5`. 1000 is
plainly 1×10³. The bar was right; the assertion was wrong — it recovered the
leading digit with `floor(log(u) / log(10.0))`, and that expression is
`2.9999999999999996` in doubles at every exact power of ten, so it read 1000 as
leading with a 10.

Two things came out of it worth keeping. The assertion now peels the leading
digit by division and **must not reach for the same function the code under test
uses**, or a shared numerical quirk becomes a shared blind spot instead of a
red. And `scale_bar_units` turns out to survive that same quirk *by luck*: its
magnitude comes out an order of magnitude low at every power of ten, and the
`10.0` in its step list is what recovers it. That is now stated in the function,
along with the reason not to "fix" it with an epsilon — floor's underestimate is
harmless because the loop only accepts a step that fits, while an overestimate
would return a bar wider than the space it was given.

### The legend was a closure, and closures copy

Found by re-reading rather than by a red: the legend was written as a `swatch`
lambda advancing a captured `lx` cursor. **GDScript lambdas capture locals by
value**, so `lx += ...` moved the lambda's own copy and the outer variable never
went anywhere — every entry would have drawn at the same x, one on top of
another.

It is worth recording as a shape rather than as a typo. Nothing could see it: it
is not visible in a diff, it does not fail to compile, and no assertion that can
only watch draw calls can tell a legend from a smear. The fix was to stop
needing the closure — `legend_words` returns which layers are on screen and
`legend_layout` returns their x positions, so the layout is a list of numbers
and `THE LEGEND LAYS ITSELF OUT` checks that the numbers strictly advance. The
general move: when the only symptom of a bug is what the pixels look like,
extract the arithmetic until there is something with a value to assert on.

`AND ONLY FOR LAYERS THAT ARE DRAWN` came out of writing that one. It names the
three entries that must move — YOU, BEACON, ESTIMATE — rather than asserting the
legend is empty, because a pilot with a founded colony legitimately carries
COLONY in both lists and an emptiness check would fail them for having played
the game.

### Two more bugs found by writing the assertions

**The zoom disagreed with the drawing about where the centre was.** The plot
reserves `FURNITURE_H` off its bottom for the bar and legend, so the picture's
origin sits above the rect's centre. `_zoom_about` was computing the origin as
`size * 0.5` while the draw used the reserved-height version — thirteen pixels
apart, which is not a wrong picture but a zoom that slides the map a little
further every step, with no cause a player could see. Both now call
`plot_home()`, and the assertion calls it too rather than recomputing the centre
locally: a test that made the same mistake would have agreed with the bug.

**The sheet fitted by exactly zero pixels.** The first plot height was 190,
which left `704 - 636 = 68px` for colony rows — precisely two rows, precisely
zero margin. That is not a design, it is a coincidence that would have become a
defect the first time any minimum in that column moved by a pixel. 180 leaves
78. The arithmetic is now asserted rather than done once in my head, and it
carries the two-row floor as its reason: a founded colony must not be the thing
that pushes WARP off the bottom of the sheet.

### What an adversarial pass found after all of that

Five independent lenses over the finished commit, each finding handed to a
separate agent whose instruction was to REFUTE it: 24 candidates, 16 confirmed,
8 refuted. After collapsing duplicates — four lenses independently found the
same sheet-arithmetic bug — it is six real defects, in code that had already
been self-reviewed twice and had a green suite.

**Nothing clipped the plot.** The worst of them, and it invalidates a sentence
written twice in this file. `Control.clip_contents` defaults to false, Godot does
NOT scissor a CanvasItem's own draw calls to its rect, and nothing anywhere in
this project sets it. At the design resolution pyx01's band-4 ring is 183px
across in a rect 180px tall — so the ring was painting over `_detail`, `_title`
and the bottom of the system map, **in the default view of the starting
system.** The culls in the draw loop are visibility heuristics and were silently
doing duty as containment, which they cannot do now that `_pan` is unbounded and
`_zoom` reaches 8. One line fixes it and one assertion pins it.

It also corrects the claim this section opened with. A beacon past the old scale
was never "simply not drawn" — it was drawn on top of the title bar. The
difference matters, because "missing" reads as a scale problem and "painted over
the header" is a containment problem, and only the second one explains what a
player was actually looking at.

**THE PLOT STILL FITS ITS SHEET could not fail.** Both of its numbers were wrong
in the direction that made it pass. `col` has nine children, so a VBoxContainer
inserts eight 8px gaps, not the seven budgeted; and a colony row is a 42px Button
with 4px of container separation, so two rows are 88px, not the 68 asserted. The
check understated the column by 28px — and its stated purpose was "a founded
colony must not push WARP off the bottom of the sheet", which is exactly what two
colonies then did while it printed PASS. The fix is not just the arithmetic:
`COL_SEP`, `MAP_MIN_H`, `COLONY_ROW_H` and `COLONY_ROW_SEP` are now named
constants that `_build` reads, so the budget cannot drift from the layout again,
and the map's floor drops 170 → 150 to buy the room the plot needs. The map is
the only child in that column that expands, so lowering its minimum costs nothing
except in the crowded case this is about.

**The reset gesture did not exist on the platform this game is for.**
`project.godot` sets `emulate_mouse_from_touch=false` deliberately, so a finger
raises no `InputEventMouseButton` at all — the `double_click` branch is
desktop-only. On a phone there was no way back to the fit. `InputEventScreenTouch`
carries its own `double_tap`, which is now handled.

**And three smaller ones**: no branch called `accept_event()`, leaving a
wheel-zoom resting on the assumption that an ancestor's `MOUSE_FILTER_STOP`
absorbed it, while `CameraRig._unhandled_input` also binds the wheel — the exact
shape `project.godot`'s own comment records a bug from; `_pinch_ref` was left
measured against a pair of fingers that no longer existed when going from three
touches to two, so the next drag divided by a stale reference and jumped; and a
panel closed mid-drag never receives the matching touch-up, so `_touches` kept an
entry and the next open began with a phantom finger down.

**One of the twelve assertions was tautological.** `THE PLOT FITS ITS CONTENT`
checked `old_r < far` with `far := old_r * 2.0` — which is `old_r < 2 * old_r`,
true for any positive radius. The clause the comment called load-bearing asserted
nothing, and the leg rested entirely on its other half. It now fits the system
twice, with the beacon and without, and requires the beacon to be what moved the
scale: a `fit_radius_for` that ignored beacons would return the same number twice
and go red.

The lesson is not "run more passes". It is that **this commit's three worst
defects were all invisible to the thing that was supposed to catch them** — the
ring off-by-one drew a convincing picture, the legend closure would have compiled
and smeared, and the containment bug was hidden behind a check whose own numbers
were wrong. Drawing code has more surface than an assertion suite can reach, and
the honest response is to say so rather than to treat green as finished.

### What is deliberately not here

Survey coverage is not fitted to and not drawn. It is session-only until the
persistence commit, and fitting the scale to something that vanishes on every
warp would make the picture jump for a reason the player cannot see. A tap on
the plot pans and zooms and nothing else — there is no verb to attach to a
world position until beacon navigation lands, and a tap that selects something
with nothing to do about it is worse than a tap that moves the map.

## 79. A bookmark you could not return to

The second playtest note: *"there is no way to navigate back to a beacon I
dropped."* Eight beacons in stock, a drop verb, a recovery verb, a radar tier
and a chart layer — and no verb that took you to one. The bookmark existed; the
page turn did not.

### Two verbs, because there are two answers

**COURSE is free, unbounded and slow. JUMP is paid, capped and instant.** One
button that silently picked between them would hide the only decision the
feature offers. A beacon at 900u is a two-minute flight you might prefer to make
— there is salvage on the way. A beacon at 3,000u with a full hold is what the
fee is for.

`command_course` is a separate entry point rather than a flag on `command_move`,
because twelve callers share that verb — every hold-approach and every tap on
empty space — and all of them would start reading as plotted courses. It also
had to be *refusable* visibly: `command_move` silently no-ops while docked,
warping or EMP-stunned, so a course verb that assumed success would light the
CRS row for a flight the ship never took. `has_move_target` is the receipt.

### The flag that would have drifted, and the one that cannot

The obvious build is a `course_active` boolean set by the course verb and
cleared wherever a course should end. `has_move_target` is cleared at **eight**
sites in `player_ship.gd` — input disabled, EMP begin, EMP tick, stick input,
arrival, dock, and two respawn paths — so that flag would have to be cleared at
all eight, and would start lying the first time somebody added a ninth.

So it is derived: `course_active()` returns `_course_on and has_move_target`.
Every existing clear already ends the course, including the two the design
actually wants — **the stick breaks it**, and **an EMP drops it** — and a ninth
clear site gets the behaviour for free. The cost is that the eight sites report
no *reason*, so main keeps its own edge detector and answers "why did it end"
with geometry: within `COURSE_ARRIVE_U` of the destination is an arrival,
anything else is an abort.

### An unattended course is otherwise a death sentence

A 4,000u course is about 730 seconds of flight across ~62 cells. At band 4
roughly half of them arm a nest within trigger range of a straight line, and
`_tick_return_fire` never sets `attack_target` — so **being shot at does not
interrupt the flight**. The course therefore drops itself on threat contact, on
a hull below 55%, on an awake engine and on an EMP, and **toasts every one**,
because a silently abandoned 700-second course reads as a bug rather than as a
decision. The threat radius is deliberately wider than a nest's trigger: the
course must die before the first shot, not in response to it.

It also needs visible state, which is what CRS is. An autopilot with no readout
is indistinguishable from a ship that has stopped taking input. CRS sits above
HDG in the nav corner, in the same three-figure compass digits, so the two
compare directly — when they agree you are flying the course.

### The jump reaches no further than the instruments do

Beacons have no depth bound; the drop verb only refuses *inside* the chart.
Band 6 starts at 5,200u. An unbounded jump would therefore be a permanent
500-credit door into the richest seams in the game — and, worse, it would move a
number another assertion depends on: `A FOOTHOLD, NOT A FARM` derives the
deepest reachable point as `bounds_of("pyx03") + HYPER_DEPTH_MAX`, and would go
on passing while the real maximum walked out from under it. The cap is
`HYPER_DEPTH_MAX` exactly, and `AND NO FURTHER THAN THE FOOTHOLD ASSUMES` ties
the two together rather than hoping they stay equal.

It has an in-fiction reason too, which is the test of whether a bound belongs:
the colony network is what a jump rides, and past the deepest structure there is
nothing to ride to. **Beyond the cap the beacon still takes a course.** The
refusal removes the shortcut, never the destination — and the refusal copy says
so, per §58.

The clock is the existing shared stamp, and it was **renamed**:
`last_colony_jump` → `last_outbound_jump`. Founding five colonies must not
multiply how often you can leave, and neither may dropping eight beacons — one
stamp is the whole mechanism. A field still called "colony" would have been a
name that lied about half of what it governs. The loader reads both keys, so a
v20 save keeps its cooldown and no version bump was needed.

### Rows are a copy, and the label is not saved

`beacons_in` hands out the **live save array by reference**. Every existing
caller only reads it, but a chart that sorted it for display would be sorting
the file. `beacon_rows` copies and sorts nearest-first, `colonies_in`'s shape
for `colonies_in`'s stated reason.

The label — "BEACON 1" — is synthesized from sorted position at read time and
deliberately not stored. A designation in the save would be a new field to
migrate, a new thing to keep unique, and a new way for the file to disagree with
the screen, all for a string the player never types and cannot choose.

### The row container had to start scrolling

Caught by checking one thing rather than by a full pass, and it is the same
defect as §78's sheet budget arriving a second time through a different door.

Beacon rows are added to `_colony_rows` — the container the chart already used
for colony jump rows. That container was written when colonies were the only
thing in it, three to five at the outside, and §78's `THE PLOT STILL FITS ITS
SHEET` budgeted **two rows**. Beacon stock is EIGHT. So the column could be
asked for ten rows: 364px of content against 90px of spare, pushing WARP off
the bottom of the screen, while the assertion went on printing PASS.

The fix is not a bigger number. `_colony_rows` now sits in a `ScrollContainer`
with a fixed viewport, so **the column's height stops depending on how many rows
exist at all** — and the assertion was rewritten to test that property directly:
it adds ten rows and requires the container's minimum height not to move. A
budget that merely had a large enough number in it would go stale the next time
somebody put a row type in there, which is precisely what just happened.

It also refuses the tempting alternative. Capping the list at "the four nearest
beacons" would have fitted too, and would have silently hidden half the
player's own waypoints — the no-silent-caps rule, on a UI surface.

The map's floor came down again, 150 → 126, to leave ~26px of margin. That is
deliberately not smaller: four rows in the budget have no `custom_minimum_size`
and are font-derived, so the sum is a model rather than a measurement, and a
2px spare would be a coincidence dressed up as a design — which this file has
already shipped once.

### Four sites, one rung

Adding "a course is set → drop it" to the Escape ladder touches the rung, the
docstring enumeration above it, the manual's prose, **and** the hand-written
`3 if touchscreen else 4` in `THE MANUAL IS TRUE TO THE CANCEL LADDER`. Miss
either of the last two and the assertion goes red — which is the assertion
working. It is appended *below* the target lock so the three rungs above keep
the numbers the manual already prints, and because dropping a lock is the
cheaper backout of the two.

### And the readout got documented in the same commit

`CRS` is a new cockpit readout, and the manual's HUD coverage sweep checks a
**hand-written** list of readouts — so it could not have caught a missing entry
for a readout nobody added to the list. The row and the list entry land
together, which is the only thing that keeps a hand-written coverage check
honest. The radar promotion needed no such row: the destination beacon borrows
`TIER_HOME`'s exemption rather than taking a tier of its own, precisely so
`TIER_NAMES` does not grow and demand a legend row for a *state* rather than a
kind of thing.

## 80. The chart remembers (v21)

The last of the five playtest notes to land, and the one that reverses a
recorded decision: survey coverage now persists in the save. §22's session-only
rule stood from v16 to v21, and its `SESSION RESET` assertion did the job its
comment promised — it forced this conversation instead of letting someone
quietly save the dict. This section is the conversation.

### The growth argument, answered rather than waved at

§17 refuses a **visited-cells** array because it grows every minute the player
flies — passive growth, proportional to distance. What ships is not that array:

- **Worked, not travelled.** A cell enters the store when a mast is worked or a
  deep berth is first docked — one write per deliberate act. Flying charts
  nothing. This is §26's passive-growth distinction, applied a second time.
- **Capped by construction.** 400 cells per system, oldest evicted first — the
  intel dossier's posture. Enforced on write, and the loader inserts through
  the same cap so the two enforcement points cannot disagree: an over-cap file
  loads as its newest 400, the same set the write path would have left.
- **System-qualified from the first key.** The old dict keyed on bare
  `Vector2i`, so pyx01's (7,-3) and pyx02's (7,-3) were one key. Persist that
  and a survey here marks a cell *there*. Keys are `"pyx01:7:-3"` — the
  warehouse's shape — and the store lives in GameState, where qualified keys
  belong.

### There is no session dict any more, and that is the fix

`_surveyed` is deleted, not seeded. `note_surveyed` and `is_surveyed` write and
read GameState directly, which makes the two old wipe paths impossible by
construction rather than guarded against: a warp frees the DeepSpace node, and
a colour-vision change calls `rebuild()` → `_despawn_all()` → clear-every-dict
— **two taps from the pause menu used to erase every survey of the session**,
undocumented. Neither path can erase state the node does not hold.
`COVERAGE SURVIVES A COLOUR CHANGE` pins that against anyone reintroducing a
cache here. `_cracked`, `_mined` and `_sprung` stay session-only — the growth
argument still holds for all three, and §22's amended text says so.

The rift sentinel is rejected at `note_surveyed` itself, not in the loader. A
rift stamps its mast with cell `(0x7ffffff, 0x7ffffff)`; stored, that key
survives to the chart, whose fit-to-content scale would be asked to span 8.6e9
units. In-memory hygiene, not just file hygiene — the loader filters it too,
but the loader is the second line, not the first.

### One version bump, no migration branch

`SAVE_VERSION` 20 → 21. An absent `survey_coverage` key is an empty store,
which is exactly what every v20 pilot effectively had between sessions —
nothing is lost that anyone ever kept. The `migrate20` SAVETEST leg carries the
usual rubbish pass (shapes, unknown systems, non-integer coordinates, the
sentinel, falsey values, and a flood past the cap), because an absent key and a
rejected one look identical from an empty store — migrate19's red-verify
lesson, inherited.

The v20 `last_colony_jump` → `last_outbound_jump` rename from §79 rides the
same fixture: the loader reads the legacy key as the default for the new one,
so a hot cooldown does not come back cold.

### The income model stops pretending

`PACING_LOOP` counted two surveys per loop as recurring income, priced at band
2 — the ring a standard loop reaches. Persistence burns that ring: each cell
pays once ever, so a recurring rate that includes them over-reports by two
readings a loop, silently, while every assertion passes. `STEADY` now subtracts
surveys the way it subtracts the derelict, and the prospector's route subtracts
its own survey term so `ROUTE PARITY` compares recurring against recurring.

Stated as the accepted trade, not hidden: **chart income is not capped, it is
converted** — from a warp-reset farm into an outward treadmill. The expanse is
unbounded, so there is always a fresh cell, but it is always further out, and
the burned near ring is precisely the region a low-tier ship can reach. That
is the design speaking: depth is the difficulty axis, and the chart now
enforces it instead of refunding it every warp.

### What the chart shows for it

Surveyed cells draw on the plot as faint filled squares, world-sized — they
scale with zoom, which is what separates them by shape from the colony marker's
fixed-size outline under §30's rule — in the band colour of where they sit,
under every other layer. The legend gains SURVEYED only when coverage exists.

Coverage is drawn but **not fitted to**, and since §78 promised this decision
would be made when persistence landed: the fit frames what you can act on now —
ship, beacons, colonies, the live hunt. Coverage is history, and one far cell
surveyed months ago would zoom every future look at the system out to it,
permanently, shrinking the working picture to pay for a memory. The chart pans
and zooms; history is reachable, not resident.

### What flipped, what grew

`SESSION RESET` became `THE CHART REMEMBERS`, asserted in both directions — a
loader that marked everything surveyed passes the survival half perfectly, so
the never-surveyed cell must still read false after the same rebuild. New:
`THE STORE IS SYSTEM-QUALIFIED`, `THE SENTINEL NEVER LANDS`,
`COVERAGE SURVIVES A COLOUR CHANGE`, `THE CAP EVICTS THE OLDEST` (in one
system only — pyx02's coverage must not be what pyx01's four-hundred-and-first
mast evicts), the `v21 COVERAGE` write/read sentinels, and `migrate20`.
MINETEST's unrelated `SESSION RESET` — mined state — is deliberately untouched,
and `note_mined`'s comment now draws the earned-versus-travelled line that
keeps it session-only on §17's original grounds.

`DOCK GRANTS` needed no assertion change — first-berth-grants, redock-grants-
nothing holds under persistence — but its comment claimed once-per-session, and
now says once ever: a berth you charted last week stays charted, which is the
same statement the chart itself now makes.

## 81. The suite measured a playthrough

The first full sweep of Horizon 6 came back 691 of 692 — one red, in HOLDTEST,
a suite none of the horizon's commits touched:

```
[hold] THE READOUT FOLLOWS THE HOLD spill 3 units 'HOLD 10/24'->'HOLD 4/24'
(want 'HOLD 4/24'); delivery settled 12->12 ... both paths fired=false -> FAIL
```

Every string in that line matches its want. What failed was the staged
precondition: `contracts.accept("haul_alloys")` refused, so there was no
delivery to settle and `12->12` was the delivery not existing.

### Why it refused, and why only now

The pin block in `main._ready` exists for exactly this: GameState has already
loaded the developer's real save by the time harnesses run, so
`reset_to_starter()` pins the state "or every assertion in the suite is
measured against whatever that person last did." Its own words.

But `Contracts` is a **node**, created a hundred lines earlier, and its
`_ready` → `_restore()` had already copied the pilot's active contracts into
its own `active` array. Resetting GameState cleared `contract_state` and left
that copy alive. `ACTIVE_SLOTS` is 2; a week of playtesting had both slots
full; `accept()` returned false on `slots_free() <= 0`. The leg had been green
on every earlier sweep only because the developer's save happened to have a
slot open — a latent dependency on live state, sitting inside the very
mechanism built to remove it.

CONTRACTTEST and PACINGTEST never saw it because both clear `contracts.active`
by hand before using it — each leg quietly not trusting the pin, without
anyone noticing that was what the clearing meant.

### The first fix was wrong, in the way that teaches

The pin block now re-syncs the node — `contracts._restore()` immediately after
`reset_to_starter()` — and the first version of this section claimed that gave
every harness "clean slots". It does not, and the very next run of the leg
proved it: `_restore` on an unseeded state auto-assigns the **starter pair**,
whose documented purpose is to *fill both slots* so the HUD tracker has
content during the tutorial. A fresh run's slots are FULL BY DESIGN.

So the pin fix changed the failure from environmental to deterministic — red
because of whatever the developer's save held became red identically on every
machine — which is progress, and is also not green. The two halves of the real
fix are owned by different layers:

- **The pin owns determinism.** Same state on every machine, and the rule
  stands: any future node that caches save state in `_ready` must be
  re-synced there too.
- **The leg owns its preconditions.** A leg that needs a free slot clears one
  — `contracts.active = []` — which is what CONTRACTTEST and PACINGTEST were
  already doing. Their hand-clearing was never distrust of the pin; it was
  this exact fact about fresh runs, known in two harnesses and written down in
  none.

And the leg now captures what it stages: `accept()`'s return is printed by
name and joined to the PASS clause. That single word is what turned the second
red from three files of digging into one glance — `accepted=false` names the
refusal — and it is why the wrong first fix cost one re-run rather than an
afternoon.

## 82. What the chart records (v22)

Horizon 7's first build, and the smallest useful piece of it: the two stores the
rest of the horizon needs, with no pricing attached to either. §80 made the deep
remember where you worked; this records **what that memory is worth so far** —
which of those cells you have sold, and which structures you have merely seen.

### Two sets, not a flag, and the migration is the reason

The obvious shape is `survey_coverage[key] = {"filed": bool}` — one store, one
concept. It was rejected for what it does to the file: changing the value shape
means every v21 pilot's real work migrates through a new branch on load.

`survey_filed` as a **separate set** means `survey_coverage` is untouched, byte
for byte, and loads through the loader it always did. An absent `survey_filed`
is "nothing filed yet", which is exactly true of every v21 pilot — and it is the
generous reading as well as the correct one: work already done keeps its
first-filing bonus. Defaults-not-branches with no branch at all.

The cost is an invariant to hold rather than a shape that enforces itself:
**filed is a subset of coverage.** `note_survey_filed` refuses a cell that is
not in coverage, `_load_survey_filed` filters against coverage rather than
against a shape, and `_enforce_survey_cap` evicts from both together — because a
filed key outliving its coverage key would be a second store growing without a
bound of its own, which is the thing §17 refuses and §80 answered by
construction. Three enforcement points, one assertion each way.

### A sighting was information the player earned and the game threw away

Hyper structures are 3–5 per system, always present, at depth 1600–4200, with no
radar tier and no chart layer until claimed. The silhouette argument in
`hyper_structure.gd` is deliberate and stands: the mesh reads at ~1000u, so
finding one is roughly a fifty-minute circumferential sweep — an expedition, not
a lottery.

What did not stand is losing the result. Fly past one, get driven off by its
three wardens, and there was **nowhere for "it is THERE" to live.** Fifty
minutes of search, and the only record was the player's memory.

`structures_seen` is keyed `"system:index"` — `colonies`' own shape, because it
is the same thing at an earlier stage — and the sighting is recorded at
`SIGHT_RANGE`, derived from the silhouette argument rather than picked. It is
checked **before** the claimed/woken early return in `_process`, because being
driven off is precisely the case it exists for.

It stores **no position.** `hyper_positions` is a pure function of
`(system, run_seed)` and the chart already calls it, so a stored coordinate
would be a second copy that could disagree with the generator. The store answers
one question — *have you seen this one* — and the generator answers where.

**It needs no cap**, and that is a property rather than an oversight: the
generator authors at most `HYPER_MAX` per system, so the store is bounded at
fifteen entries across the whole game. Asserted against `hyper_positions()`
rather than against a literal, so a retune of `HYPER_MIN`/`HYPER_MAX` moves the
bound with it.

The chart draws a sighting as a **hollow diamond** — the colony's square turned
forty-five degrees. The shape says "this kind of thing", the rotation says "not
yours yet", and neither reading depends on colour (§30).

### What is deliberately not here

**No pricing.** The first-filing bonus is the next commit, and it lands *after*
§41's `MIDTIER` re-derivation, because adding an income shape on top of an
unresolved bar means tuning two things at once and knowing which moved neither.
This commit adds a store and changes no economy at all.

Worth recording alongside it: §80 spent **0.097 mid-tier modules** of the
[0.60, 3.00] band — 4% of its width — so the debt §64 has been carrying is
smaller than it reads. What §41 actually asks is whether `lance_1` is still a
mid-tier reference after the Mk II tiers grew the catalog 84%, and that is a
question for PACINGTEST's printed numbers rather than its verdict.

## 83. The counter pays for being first

Horizon 7 commit 2, and the point of the whole horizon: the premise — *selling
charts of places nobody has filed a return from* — finally has a mechanic that
knows which places, and whether anybody had.

### The sale splits into a market half and a provenance half

The market half is untouched: `port_panel._sell` unloads the units and pays
`Market.sell_price`, with every fence rule, pressure effect and smuggling feed
exactly where it was. The provenance half runs after it: selling a reading's
worth of a band's chart data files your oldest unfiled cells of that band — one
cell per `YIELD_UNITS` sold, because one reading is what a mast yields — and
pays `FIRST_FILING_RATE` (0.5) of the reading's **base** value per cell, once
ever.

Base price, deliberately not market price. The market half answers "where did
you sell it and what does this port think of that good today"; provenance is a
fact about the *cell*, and a fact should not pay differently at a fence.

Depth is carried by the existing price ladder rather than a second table: a
band-5 cell pays more than a band-2 cell only because `chart_fathom`'s base is
higher than `chart_drift`'s. One rate, no new numbers to keep in step.

### What this converts

§80 recorded, as an accepted trade, that persistence burns the near ring and
turns chart income into an outward treadmill. The bonus is what makes that a
pull rather than a tax: the near ring is *filed*, so first-filings — the good
money — are always further out than the last trip. The sentence the game rests
on ("the further out you go the better it pays") stops being only about band
tables and starts being about the player's own history.

The ledger gains `cells_filed` beside `chart_data_sold` — volume versus firsts,
and the first version of "places I put on the map".

### The three refusals that keep it honest

- **The bonus is a bonus.** `file_charts_on_sale` touches the filed set and the
  wallet and nothing else — no cargo, no coverage. A player who never thinks
  about filing loses nothing they had yesterday. Asserted as a property.
- **A half-reading files nothing, and the remainder does not carry.** Selling
  one unit of a two-unit reading is selling half a coordinate. The counter
  files whole cells or none, statelessly — a carried remainder would be save
  state for a bookkeeping trick.
- **Filing is not a raise.** The bonus is once-only by construction, so
  `PACING_LOOP` must never name it — the exact over-report §80 removed from
  surveys, rebuilt one commit later, is what `FILING IS NOT A RAISE` goes red
  on. Both profiles are checked, because `PACING_PROSPECT` surveys too and
  would be the quieter place to slip it in.

### The sequencing note, honestly

The plan ordered this after §41's `MIDTIER` re-derivation. It landed first, and
the reason is structural rather than impatient: the bonus never enters the
recurring loop — asserted, not promised — so it cannot move the bar §41 is
about. What §41 still owes is a judgement (is `lance_1` still mid-tier after
the catalog grew 84%?) that needs PACINGTEST's printed numbers from a real run,
and it stays open in §64 until those numbers exist. A one-time income stream
orthogonal to the bar does not have to wait on a question about the bar.

## 84. The other cartographer

Horizon 7 commit 3. Somebody else is working the same deep, and the player only
ever meets the evidence: a cell already filed when they sell, a mast whose
reading comes back annotated *somebody was first*, a beacon in a livery that is
not theirs. Nothing is ever seen moving. Nothing shoots.

### A rival with no save, racing the player's own clock

`Rival` is a leaf class of two pure functions. A cell's rival-arrival time
derives from `(cell key, depth, run_seed)`; whether the rival has filed it is
that arrival compared against `played_seconds`. Zero bytes of save — §17's
"revisiting a sector costs zero bytes" untouched — and because `played_seconds`
is the player's own accumulated clock, the rival races exactly the person
playing. Pause the run for a month and nothing moves. There is no rival while
nobody is flying, which is both the cheapest implementation and the right
fiction.

The gradient is the design. `BASE_S` (half an hour) means a brand-new pilot's
first sortie is never pre-empted — `A FRESH PILOT MEETS NOBODY` holds that at
zero played seconds nothing anywhere is filed. `S_PER_U` (60) means the
shallows go in single sessions while the earliest possible arrival at the
band-4 floor is ~18.8 hours of play — `THE DEEP OUTRUNS THEM` measures that
over the jitter rather than restating the formula, and holds the latest
200u arrival strictly before the earliest 1100u one. The near ring burns with
a hand attached to it; the deep belongs to whoever flies there.

Per-cell jitter of [1, 3] exists for `hyper_positions`' reason: a flat front
would let one found cell date every other cell at its depth, and denying that
inference is a pillar, not a preference.

### The stride holds the world still

The clock is quantised to ten-minute strides before any comparison. This is
not flavour: the cell streamer consults `Rival.filed` when it dresses a cell,
and STREAMTEST's `SAME WORLD EITHER WAY` compares a synchronous build against
an amortised one — two builds seconds apart must not disagree about whether a
beacon stands in a cell. Within a stride the world is stable; progress happens
between strides, like a tide coming in while you looked away. Which is also
the right fiction for somebody you never see.

### They take the chance, never the goods

The one design risk named in the horizon plan was a rival that punishes. The
implementation makes the safe property structural:

- **At the mast**, a rival-filed cell still pays its full cargo — the data is
  yours; only the counter's first-filing bonus is gone, and the toast says so
  in the deep rather than letting the counter be the first to mention it a
  session later.
- **At the counter**, rival-filed cells are swept out of the unfiled ledger
  without pay and **without consuming a reading slot** — your readings' bonus
  slots go to cells that can still pay. Coverage never loses an entry: the
  chart you drew stays drawn.
- **A player-filed cell can never be un-filed** by any amount of rival
  advance. `THE RIVAL NEVER TAKES WHAT YOU HAVE` drives all three through the
  real counter with the clock pushed past the shallows.

Both the mast's heads-up and the counter's verdict read depth through
`main.cell_depth_of_key` — one source, so the two surfaces cannot disagree
about where a cell is.

### The evidence in the world

A sparse fraction (4%) of rival-reached cells carry one of their beacons — the
same `Beacon` node the player drops, reusing mesh, breath, pick group and
radar tier, because it *is* a beacon; what differs is a `foreign` flag. It
lives and dies with its cell, never touches `GameState.beacons`, never counts
against stock, and refuses the recovery hold with copy that says why. Its
presence, angle and radius all derive from one salted hash: no draw from any
stream, so `THE DRAW COUNT DID NOT MOVE` cannot see it — correctly, because
there is nothing to see.

`Palette.RIVAL` (violet) is the one new colour: not a band (place), not the
livery accent (yours), not THREAT (danger), because a rival beacon is none of
those things. Per §30 the hue is the at-a-glance channel and ownership is
carried by the refusal itself.

Beacon also gained `marker_color()` — own beacons now wear the livery accent
on the radar as well as in the world, closing a small radar/world disagreement
the Horizon 6 plan had noted and not built.

### Deferred from this commit, deliberately

**The rival's wreck** — the one authored site where the rival stops being a
rate and becomes a person. It is content rather than arithmetic, it wants the
same writing pass as THE UNSOUNDED's fragments, and it should land with them.

## 85. The deep teaches itself

Horizon 7 commit 5, the half that could ship: four lines, one per band from
THE REACHES out, fired beside the band's own broadcast on first crossing —
once ever, on the bark contract, so a returning player is never re-taught.
The tutorial covers the first hour and band 4 is where the interesting game
lives; until these, nothing between the two said a word about mechanics.

Each line teaches exactly one true thing the band contains — convoy etiquette
at 3, nest geometry at 4, the end of the jump network at 5, weather and
self-reliance at 6 — and none names a gesture, so the manual's device sweep
stays clean on every input. Two voices on one threshold, deliberately: the
authority on the broadcast plate, the ship in the corner. The bark fires even
where a band has no authored broadcast, which is itself in character — the
ship keeps talking after the grid goes quiet.

The other half of commit 5 — whether eight beacons is still the right stock
now that §79 made each one a free destination — is a playtest question, is
recorded as one in §64, and no number was moved without a session behind it.

## 86. The yardstick was lying short (§41, paid)

Horizon 7 commit 0, and the oldest debt in §64. §41 asked, when the Mk II
tiers grew the catalog 84%, whether `lance_1` was still a mid-tier reference.
The question sat unanswered through two horizons because answering it needed
PACINGTEST's printed numbers from a real machine. 2026-08-18, it got them.

### The measurement

The sweep read: EARNED 16,788 per loop (2.89× the reference, brushing the 3.00
ceiling), STEADY 11,095 (1.91×), PROSPECT parity 5.1% against 20% allowed,
CEILING ratio 0.020 against 0.15. Everything green. And the distribution said
why the green was too comfortable: **39 priced modules, median 14,000, and
`lance_1` at 5,800 sitting at the 18th percentile.** The catalog's middle had
moved and left the yardstick behind. "1.91× mid-tier per loop" was actually
0.79× of a genuinely median module — the economy was on the design's target
("a loop is worth roughly one mid-tier module") and the *instrument* was
reporting nearly double, with the 0.60 floor so far below the reading that it
had drifted most of the way to vacuous.

### The decision, in §41's own terms

Of the three things that could move — the band, the yields, the reference —
**the reference moves and nothing else does.** The yields are demonstrably on
target once measured against an honest middle; the band's semantics become
true again the moment the ruler is right.

`PACING_MIDTIER` is now `rig_strike` (Strike Frame, 14,500). Chosen over the
exactly-median `drive_vector_2` because the reference's plain-language job is
"the first real I-chose-this purchase", and in today's catalog that means a
**frame** — a build identity — not a Mk II upgrade, which is more of what you
already had. It carries the same power draw as `lance_1`, so `MINING COSTS A
MOUNT` measures exactly what it measured before.

Predicted post-change readings, from the same sweep's numbers: STEADY 0.77×,
best-case 1.16×, PROSPECT 0.82× — all inside [0.60, 3.00], with the floor now
22% below the steady reading instead of 219%. The floor can bite again, which
is the whole point of having one.

### And the instrument that keeps it paid

`THE YARDSTICK IS MID-TIER`: the reference must sit in the middle third of the
priced catalog, computed from the live module list at run time. The next 84%
of catalog growth turns a leg red and forces this conversation again, instead
of quietly shortening the ruler for another year. Red-verify by pointing the
reference back at `lance_1` — the leg names the middle third it fell out of.

Worth recording beside it: the best-case loop brushing the old ceiling (2.89
of 3.00) dissolves under the honest ruler to 1.16 — that near-red was the
mis-calibration, not the economy. And the CEILING catalog-fraction ratio at
0.020 against 0.15 is now pure catastrophic-printer insurance; the MIDTIER
band is the working bound, which is what §41 predicted when it split them.

## 87. Three beacons (§79's number, re-derived)

The last open half of Horizon 7's commit 5, decided the way §85 said it had to
be — from play, not from a desk. Weeks of sessions on both sides of §79 are the
derivation: before navigation, eight beacons threaded a route and the recover
verb existed; after navigation made every beacon a free course destination and
a jump target, eight was a fast-travel network and recovery went unused — the
exact failure `beacon.gd`'s own header warned about ("the recover verb would
never once be used"), arrived from the opposite direction it expected.

**`BEACON_STOCK` is 3.** At three, placing a beacon is a commitment again, and
recovering one is routine rather than never.

### A retune must never delete a placed beacon

The loader capped entries at `BEACON_STOCK`, which was correct until the day
the constant moved — then it would have silently deleted beacons from any save
standing more than three, on load, with the player's own markers as the
casualty. The cap now bounds against `BEACON_LEGACY_CAP` (8, the largest stock
ever shipped): a corrupt file is still refused, a retune deletes nothing, and a
grandfathered pilot simply cannot drop until recovery brings them under the new
stock. `beacon_stock_left()` clamps at zero for the same reason — "-2 IN
STOCK" in a toast would be the arithmetic showing through the fiction.
`A RETUNE NEVER DELETES A BEACON` drives the whole arc: five legacy entries
kept, stock clamped, drop refused, recovery re-opening it.

### And the prose is derived now

The manual said "eight in stock" in two hand-written places, which is exactly
the drift class the cancel-ladder lesson closed for rungs: both now format
`GameState.BEACON_STOCK` into the sentence, so this number cannot go stale in
copy again. The ledger leg's print derives its count the same way.

## 88. The features that existed and could not be seen

A nine-note playtest, and the triage is the finding: of nine notes, one was a
real layout bug, one was a wired verb with no invitation, one was
architectural, and *six* were systems working as built that the game never
introduced. The best possible playtest result, and the most damning — the work
was done and the door was shut. This section covers the two interaction fixes;
§89 the audio; §90 the teaching verdicts.

### The sheet grew upward (the chart bug)

`SHEET_RATIO` is a portrait constant: 55% of 1280 holds the chart column's
~680px of minimums. On a wide desktop window, 55% of ~1090 does not — and a
VBoxContainer refuses to shrink children below their minimums, so the overflow
came out of the *bottom*, which is the WARP button. The playtest filed it as
two symptoms — "the chart opens too low" and "cannot travel to the new Pyx" —
and both were one bug: the button was there, below the window edge, while the
top 45% of the screen sat empty.

`_apply_layout` now treats the ratio as a floor: the sheet takes more of a
short window only when the column's own measured minimums demand it, capped at
95%. Portrait is untouched byte for byte. `AND EVERY WINDOW FITS THE SHEET`
asserts both directions at a landscape resolution — the leg the portrait-only
model of leg 12 was structurally unable to provide — and it measures *after*
the slide animation, because a rect read mid-slide sits below where the sheet
will rest and fails a correct layout.

### The monument answers a tap

The claim hold was wired from the day hyper structures shipped: `hold_begin`
prompts the warden count, `_approach` flies you in, the gauge runs. The
playtest still reported "no way to interact" — because the verb every player
tries first on the biggest object in the game is a *click*, and CameraRig's
select ladder picked crackable / mineable / dockable and never `hyper`.

**`on_tapped` already existed.** The first version of this section said it did
not, and that was written from inference rather than from the file — the
select ladder's silence was read as the function's absence, and the fix
duplicated a function the file already had, which GDScript rejects outright.
The correction matters more than the typo: the defect was ONE line in the
ladder, and the file was collateral damage from not looking.

What the tap genuinely lacked was answers. It returned silently when claimed,
and in the unlocked case — a player standing in front of a takeable monument —
it said nothing at all while quietly flying them in. A tap that moves the ship
without a word is the affordance problem one layer down. Every branch now
prompts, and `hyper` joins the ladder last, for the hold ladder's own stated
reason: the biggest thing on screen should lose every contested tap to the
smaller thing in front of it.

**And its assertion was wrong on first measurement, in the direction worth
recording.** `THE MONUMENT ANSWERS A TAP` shipped here and was first actually
run two commits later (§91's sweep), where it came back red quoting a prompt
that was *correct*: `THE ORRERY · FIRST INSTRUMENT — CLAIMED. THE CHART CARRIES
ITS JUMP.` The leg took whatever `get_nodes_in_group("hyper")` returned first
and demanded the unclaimed wording — but `ONE CLOCK FOR ALL OF THEM`, four legs
earlier in the same suite, claims `pyx01:0` and `pyx01:1` by hand. First-in-tree
was a claimed monument answering its claimed branch perfectly. The leg now
picks by STATE rather than by tree order and taps BOTH, which is the promise
this section actually made: every branch answers. A test that depends on tree
order is depending on something nothing guarantees — the same class of mistake
as reading a function's absence off a caller's silence, one paragraph up.

### And the checker gained a third rule

The duplicate above passed `check_scripts.py` clean and detonated on Godot as
the §77 cascade — `Could not parse global class "HyperStructure"`, with the
duplicate named nowhere in the output and the gate's own hint pointing at
`--import`, which could not have helped: `HyperStructure` was never a new
class. Duplicate declarations at file scope are exactly what scripted editing
produces, so they are now the checker's third rule, alongside the body-less
block and the unresolved member. File scope only — an inner `class` may
legitimately redeclare a name, and its members are indented by construction.

The general lesson, worth its sentence: **a wired verb without an affordance
is indistinguishable from an unbuilt feature, and the player's report will
correctly say "cannot interact" either way.**

## 89. Combat sound has a distance

`Sfx.play` is a flat sixteen-player pool — every caller anywhere in the
streamed window played at authored volume. A swarm fighting a picket three
hundred units away was as loud as one on the hull, forever; the playtest
called it "really annoying," which for a mobile game is a death sentence
politely phrased.

`play_at(pos, …)` reads the player's distance: unchanged inside 40u, a linear
dB roll-off to −22 at 120u, culled entirely past it. The world's fire, hit and
explode calls route through it; the cockpit — UI, pickups, the player's own
ship — keeps the flat path, because feedback for your own actions is not
diegetic and must never fade. The curve is a pure static (`attenuation_for`),
so `COMBAT SOUND FALLS OFF WITH DISTANCE` holds it without listening: flat
zone, floor at the cull edge, monotone between, and the cull strictly beyond
the flat zone so the two constants cannot be tuned past each other.

## 90. Three verdicts of teaching, one of evidence

**The forge (§4 of the playtest).** The loop was intact end to end — crack,
carry unread, read at your archeology tier, components fall from reads, forge
consumes them — and deliberately market-proof. The comment above `_build_forge`
even claimed "a component names the read that produces it." **It never did**:
the bill printed have/need and nothing else — prose above code with nothing
connecting the two, §73's oldest shape. The bill now derives each missing
component's source from `READS_AS` itself ("SRV-P FALLS FROM READING BAND 2+
SALVAGE"), so the line cannot drift from the table that makes it true.

**The Commission (§5).** Working as designed, failing as communication. The
statement-of-record posture stands — but a page that refuses to be a quest log
still owes the reader one sentence saying what it *is*. It now opens with what
the registry does, the stages-on-file count, and what the full commission
confers. Describing the page is not instructing the player.

**The skills (§8).** The verdict is evidence, not code: all four skills have
live feeds, XP tables, tier walks, tier-up toasts, refusal copy that names the
tier you need (the hold screen's locked-reads strip), and a permanent home on
the pause menu's root page. Nothing was added, and that is the finding worth
recording: the answer to "is this implemented?" was yes four times over, and
the player asking after weeks of play means the *surfaces* are quiet, not
absent. If a future playtest asks again, the answer is louder surfaces — not
doubt about the machinery.

## 91. The unsounded answers (v23)

Horizon 7 commit 4, and the last of the horizon. Past the last band edge each
system carries one authored structure, and PYX-01 carries a second thing in
band 5: the other cartographer's hull, found. They are the places that say what
killed the frontier.

Nothing here is a fight — §76's rule at full volume. The deep already has
hulks, packs, traps and standing guards; these are graves with paperwork, and
the reward for reaching one is an **answer**. `IT IS NOT A FIGHT` asserts that
as an emptiness over ten groups: an `UnsoundedSite` joins `"unsounded"` and
nothing else. Not `"hyper"` (the warden sweeps iterate that group and cast to
`HyperStructure`), and not `"crackable"` — the radar collects that group, and a
permanent arrow pointing 5,600 units out would spoil exactly the expedition the
silhouette design exists to create. Both interaction ladders pick `"unsounded"`
explicitly and last, in the same commit: §88's lesson is that a wired verb with
no affordance is an unbuilt feature, so the hold path and the tap path grew the
rung together.

### One class, four kinds, and the meter that was cut

`UnsoundedSite` is one class carrying four records — §17's "the gradient is
parameters, not new classes", the signature sites' own pattern one shelf up.
Which kind stands in which system is data (`SystemDB.unsounded_kind_of`,
`rival_wreck_in`), consumed by the builder and never by the generator, so no
draw moves and the world fingerprint stands untouched.

The plan called for a per-visit fragment cap, forcing the record to take
several expeditions. **It was cut**, and the reasoning is worth keeping: a cap
like that is a refusal with no fiction behind it — the archive has no reason to
stop talking halfway — and manufactured revisits are precisely the tedium the
long-expedition work was deferred over. The gate is already real and already
expensive: the structures sit past 5,200 units where §79's jump ceiling is
4,200, so the only way to one is a fifteen-minute outbound flight, in band-6
weather, leaving the hull unattended at the far end of it. `ONLY OUT THERE`
pins that per kind rather than as a minimum, so the wreck's band-5 exception —
the rival died *outbound*, which is what their log says — cannot quietly become
a licence for the others to drift inward.

What the hold pays is `chart_unsounded`: the band-6 chart good that shipped
priced and unearnable now has its source. Two units a fragment, and the read
defers on a full hold rather than burning a persisted stage — the survey mast's
own guard, on the store where losing a stage costs the player a six-thousand-
unit flight. A completed archive re-shows its last page and pays nothing, which
keeps a fourteen-second hold from being an income faucet out where the fiction
says everything has stopped, and states its own terms by *being* the last
fragment again (§58).

### The number in the log is the number in the store

The rival's log says four hundred cells filed. `SURVEY_CELL_CAP` is four
hundred (§80). `THE WRECK QUOTES THE REAL CAP` pins both directions, so a
retune of the cap that left the line alone goes red instead of making the
game's strongest sentence quietly false. That is the same posture as the
manual-versus-cancel-ladder assertion: fiction that states a mechanic is
checked against the mechanic.

### The save (v23)

`deep_logs`, keyed `"system:kind"` → the highest fragment reached. An int
rather than a boolean because the record is sequential, and generator-bounded
rather than capped: four entries across the whole game. `note_deep_log`
advances by one and never past the record's total, so no caller can skip to the
end. The loader validates entry-by-entry against what *can* exist — system
authored, kind in `DEEP_LOG_KINDS`, stage in range — and drops rather than
crashes. `migrate22` proves a v22 file arrives having read nothing and keeps
everything else, then feeds it eight entries of rubbish and keeps the two that
are real. No migration branch: defaults-not-branches, and "has read none of the
unsounded" is exactly true of every pilot whose build had none to read.

### What it is for

Horizon 7 asked what the deep is *for* once the chart is legible and somebody
else is racing you for it. This is the answer: the frontier is not a place that
was never surveyed, it is a place that was surveyed, measured, and then
classified out of existence. The three datums are position, time and bearing —
the three things a chart is made of — and each one records the moment it stopped
being able to tell the truth. The last fragment of THE LAST RETURN hands the
job to whoever is reading it, which is the only ending a cartography game can
honestly have.

## 92. The machines were never told

Horizon 8 commit 0, and no save bump — every flag here is derived from v23's
`deep_logs` (§91). The frontier's answer has been readable since the UNSOUNDED
shipped; this is the game hearing it.

### What could not change, and why that is the feature

The plan going in was that the authority's broadcasts would turn cold once the
player had read Directive 9. Reading the table killed that and replaced it with
something better. `BROADCASTS` bands 1–4 are an automated beacon, a relay, a
degraded relay and a dead carrier — **every one of them a recording** — and THE
LAST RETURN's final entry already says it out loud: *SOMEBODY DECIDED THE
MACHINES DID NOT NEED TO KNOW.*

So the chart-edge beacon goes on telling a commissioned pilot *"Charts on file.
This marker stands on your readings… the bearing is yours, and it is written
down"* forever, warmly, to somebody who now knows the returns were refused.
That line was already in the game. It becomes the most frightening one in it
without a word being edited.

`THE MACHINES DO NOT KNOW` is that rule as an assertion: bands 1–4 resolve
identically under every combination of both flags, in every system,
commissioned or not. It goes red the moment somebody "finishes" the table —
which is exactly what the first version of this design would have done.

### The reveal is staged, because the first draft leaked

The playtest note that shaped this: *shouldn't the game feel normal first, and
only get unsettling after several eerie interactions?* Yes — and the first
draft failed that badly. Directive 9's pages were to ride foreign beacons,
which spawn wherever the rival has filed, from `CONTENT_MIN_DEPTH` (24u)
outward. The rival takes the shallows in single sessions, so the order's text
would have been sitting at the chart edge inside a new pilot's first hours.

Three beats now, ordered by geography rather than by a quest flag:

1. **Hints**, band 3 and deeper only (commit 1) — a page at a time, out of
   order, understandable but incomplete.
2. **The order**, past 5,200u — and it changes only what is PRIVATE: the ship
   says one line, the log takes one entry, the Commission page grows one field.
   The world does not react at all. You know, and nothing else does.
3. **The answer**, once all nine fragments are held — the two voices out here
   that were never the authority's say something different.

`knows_directive_9()` and `holds_whole_record()` carry those, both derived by
SCANNING `deep_logs` for a suffix rather than naming pyx03, so a future system
authoring the datum is covered without a second place to edit.
`THE WORLD WAITS FOR THE WHOLE RECORD` pins the staging: at 3/3/2 — two
archives finished and the order itself read — every voice must still say what
it always said.

### The register rule, which outlives this horizon

From the same note: the copy was more cryptic than it needed to be. The rule
now, and it applies to everything written after this:

> **Every line is understandable on first read. Eeriness comes from what a line
> MEANS, never from being hard to parse.** The player always knows what they
> were just told; what grows with depth is how much they wish they had not been
> told it.

The frontier was not closed because something was wrong with it. It was closed
because repeated resurvey produced charts that did not agree, and an authority
that sells charts cannot publish two that disagree. That is the whole twist,
and it is said in those words — not implied, not encoded.

### The two living voices, and the override that correctly wins

Bands 5 and 6 gain `body_after` on the optional-key-with-fallback shape
`broadcast_for` already uses. The sender never changes: it is the same voice
saying more, so there is no `from_after` and no need for one.

The clause sits BELOW the per-system override, and that is a decision rather
than an ordering accident. Two of the three systems replace one of these rows
with their own line — pyx01 speaks band 6 as a GSA repeater, pyx03 speaks band
5 as a sounding mark — and **both of those are machines**. An after-line
jumping the override there would break the governing rule to deliver the
payoff. It does not have to: pyx01 keeps band 5, pyx02 keeps both, pyx03 keeps
band 6, so every system still carries one living voice.
`EVERY SYSTEM KEEPS ONE LIVING VOICE` asserts that per system, because a future
override on the last living band in a system would delete the payoff there and
nothing else would notice.

### The field that was switched off

The Commission page — the authority's file on you — gains one field once the
order is read:

> RETURNS LOGGED FROM THE RECLASSIFIED VOLUME: —
> FIELD RETIRED AT RESURVEY 44. FILINGS FROM THE VOLUME ARE ACCEPTED AND
> COUNTED ABOVE.

Resurvey 44 is THE FIRST MERIDIAN's own fragment, the one that found the datum
had moved. Two records agreeing about a date without either explaining the
other.

**It appears with the order rather than being there all along**, and that was
the fourth review decision. An unexplained dash from the first dock is a
teaser, and §90 settled that this page states rather than teases. After the
order it is corroboration. `THE FIELD ARRIVES WITH THE ORDER` checks all three
halves: absent before, present after, and unmoved by filing more charts — it is
a statement, not a counter.

### And it cost nothing, which is now checkable

`save_dict()` is extracted out of `save_game` so a harness can compare two save
images without writing a file. `NOTHING NEW IS STORED` walks every key and
requires that reading Directive 9 moves `deep_logs` and nothing else. The claim
"this horizon costs zero bytes" was worth exactly as much as the check behind
it, and until this commit there was no way to make that check that did not
involve the disk.

## 93. The pages, and where they are not

Horizon 8 commit 1, and no save bump again. Directive 9 travels the way a
banned document travels: one page at a time, out of order, clipped to the masts
of people who were told not to file and filed anyway.

### It is met first and built second

In play this is the FIRST beat of the reveal — a mid-game pilot finds a page,
reads a clause of an order they have no context for, and understands every word
of it without yet knowing what it is part of. §92's private beat and the two
living voices both come later. It was built second because the pages are
corroboration for a fact the game had to be able to state first; that is a
build order, not a play order, and the distinction is worth writing down
because the two are opposites here.

### The band gate is the whole pacing decision, so it lives in one function

The playtest note that shaped this horizon — *shouldn't the game feel normal
first?* — is answered here or not at all. Foreign beacons stand wherever the
rival has filed, and the rival's arrival begins at `CONTENT_MIN_DEPTH`, 24
units out. The shallows go inside single sessions. An ungated page would
therefore have put the order's own text at the chart edge in a new pilot's
first hours: the twist, delivered before the game has said anything is wrong.

`Beacon.page_for(cell_key, band)` owns the rule — which page, and whether there
is one at all — as a single pure function, with `PAGE_MIN_BAND = 3`. The
spawner calls it and decides nothing. That placement is deliberate: a band
check written at the spawn site is a pacing decision sitting in a place where
the next caller will not think to look for it, and there is now no way to spawn
a foreign beacon that quietly disagrees about where the order is allowed to be.
`THE PAGES KEEP TO THE DEEP` sweeps every band over three hundred keys each,
and red-verifies by dropping the band clause.

Band 3 is also where the shipped broadcast arc already turns strange — the
relay goes to SIGNAL DEGRADED, the ship's own bark starts naming things that
shoot back. The hints arrive exactly when the game has stopped being reassuring,
and the fiction agrees with the pacing: you do not leave contraband where the
authority still sweeps.

### Reading costs nothing and leaves nothing

The rival's covenant (§84), applied to the people the rival was one of. No
cargo, no credits, no stage, no store entry, no seen-set: zero bytes, and the
mast is still standing afterwards. A page that vanished on being read would be
a collectible, and this is not a collectible — it is a thing somebody left
where the next crew through would find it. `THE PAGE LEAVES NOTHING BEHIND`
drives the whole verb on a real node and compares two `save_dict()` images
across it.

There is no counter anywhere. A player who wants the whole order flies until
they have seen six different deep beacons, and the game never tells them how
many they are missing — the same refusal the silhouette design makes (§68) and
for the same reason.

**And that leg was red on its first run, for a reason worth keeping.** It took
its before-image, ran the read, then waited 0.4s for the broadcast plate to
fade in before taking the after-image — and came back red because
`played_seconds += delta` is in the save dict and four hundred milliseconds of
it had gone by. The save had moved; reading had not moved it. The rule the fix
states: **a leg that brackets an act must bracket only the act.** The two
images now sit either side of `hold_tick` with no frame boundary between them,
and the plate wait happens after. This is the second assertion in two horizons
to be red on its first run for a test-side reason (§88's was tree order), and
both had the same shape — the leg measured something true but not the thing it
claimed to measure.

### The refusal did not go away, it got a sibling

A foreign beacon with no page still answers exactly as it did: *NOT YOUR ANCHOR
CODE — THIS BEACON ANSWERS TO SOMEBODY ELSE*. Out in the near ring that is the
whole truth — there is nothing clipped to the mast, and the anchor code is
still not the player's to release. One question, `reading()`, is asked in all
four places the three verbs diverge, so recovery, refusal and reading cannot
drift apart.

`on_tapped` gained what §88 said it should have had all along. It used to pulse
and fly the ship in without a word, which is the affordance problem one layer
down — and it matters more now that a tap can land on three beacons that do
three different things. All three branches say which one this is.

### Not in the manual, deliberately

The manual documents the player's instruments and the player's verbs. A page
clipped to somebody else's mast is neither: it is something found, and the tap
prompt teaches it at the moment it is in front of the player. Writing it into
the manual would turn a discovery into a checklist item — the same argument
§90 made for the Commission page not being a quest log.
