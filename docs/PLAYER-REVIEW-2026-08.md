# Pyxis — Advance Play Review

**Reviewer:** independent play review, advance access build (main @ `5b77fa7`, save format v22)
**Platform tested:** Godot 4.6.stable, Linux headless + rendered capture at 720×1280 portrait (the design viewport). Full assertion sweep, scripted demo playthrough, tutorial run, and every observational harness executed this session.
**Date:** 2026-08-20

---

## Verdict up front

Pyxis is the most mechanically honest mobile-shaped game I have reviewed in years. It is a single-player salvage-cartography game with one loop — fly out past the edge of the map, crack what you find, sell the chart of where you went — and every system in the build bends toward that loop instead of away from it. No timers, no energy, no gacha, no second currency. The difficulty is fitting and positioning rather than reflexes; the economy is a designed machine with printed odds and no money printers; and the world's most distinctive idea — that danger rises and surveillance *falls* as you go deeper, so contraband is safest exactly where everything else will kill you — is genuinely novel and genuinely playable.

The build is deep, dense, and remarkably finished at the systems level: I measured **711 of 712 assertions green across 70 headless runs** on a fresh clone, and the one red line is a defect in the newest *test*, not in the game. What holds Pyxis back today is not correctness, it is **presentation and discoverability**: the game's own playtest record admits that six of the last nine player complaints were fully built systems the game had never introduced. That pattern is real and I felt it — this is a game that teaches its verbs beautifully in the first ten minutes and then goes quiet for the next ten hours while entire subsystems (the forge, the commission, two of the four skill ladders) wait to be stumbled on. The art direction is coherent and occasionally striking, but it is a systems-first build wearing placeholder-grade dressing, and THE UNSOUNDED — the band the whole difficulty curve points at — is still, in the developer's own words, "an expensive door with a supply closet behind it" until the authored endgame site ships.

**Would I play it? Yes — and I'd keep playing.** The loop is an eight-minute bite that respects a phone session, the deep is a real place with real weather, and the rival cartographer quietly filing the shallows behind you is the best invisible antagonist I've seen in a mobile game. **Would I recommend it to a general audience today?** Not yet — it needs its endgame payoff, its teaching surfaces, and a real device performance pass first. For players who liked the idea of EVE more than the reality of it, or who wanted Subnautica's depth-dread in a five-minute session, this is already special.

---

## 1. What the game is

You fly a survey vessel in a dead frontier: three charted systems (PYX-01/02/03) run by an absent Grand Survey Authority, and an uncharted expanse beyond each chart edge measured in bands of depth — THE SHOALS, THE DRIFT, THE REACHES, THE QUIET, THE FATHOMS, THE UNSOUNDED. The war that killed the frontier is over; its machines are not. You crack derelict hulls, mine seams, read unidentified salvage, fight automated swarms, dodge storms, and sell *charts* — the game's signature good — of places nobody has filed a return from.

Structure in one paragraph: charted space is the safe, authored, persistent tutorial-and-market layer. The expanse is procedurally derived from a seed (revisiting a sector "costs zero bytes" — it's a pure function), and everything about it deepens with distance: loot grade, enemy pack size, station rarity, weather. Progression is a six-slot fitting system under a hard power budget ("EVE in miniature" is the doc's phrase and it's earned), four skill ladders fed by *doing* (archeology, mining, smuggling, persuasion), an apex boss per system you must *find* before you can fight, and a cartography endgame where the map itself — what you've surveyed, what you filed first, where you dropped your three precious beacons — is the save file that matters.

It is portrait, one-thumb, tap-to-command on phones; WASD and hotkeys on desktop. Sessions are designed around an eight-minute standard loop, and the pacing of that loop is not vibes — it is a tested contract (4–15% of the module catalog per loop, enforced by assertion).

---

## 2. The first hour

The front door sets the tone: a transparent title screen with a compass dial over the *live* starting system drifting behind it — the first thing you see is the actual game, not a still. Four buttons (NEW SURVEY, PILOT'S MANUAL, PILOTS, AUDIO ON), and the manual is readable before you've ever started a run, which is exactly where a new player needs it. Up to five local pilot profiles, each with their own ship name, paint, and commission; device settings (bindings, volumes, color-vision) deliberately live outside the pilot, so switching saves can never rebind your keyboard.

The onboarding is six steps, each one verb, run in the real starting system rather than a sandbox: fly, engage, collect, discharge the core, fit a module, crack a training hull. I verified it completes by actually playing it (the build's own history includes a stretch where it could not be finished except by SKIP — that is fixed and now asserted). It ends the right way: not with a waypoint, but with a bearing — "the survey hull is 100u past the marker on 243°" — which is the game teaching you its central gesture, flying out past the edge on a heading, in the first fifteen minutes.

After that, teaching hands off to the ship's AI: one-shot contextual barks ("CARGO IS WORTH WHAT THE NEXT PORT WILL PAY", "THE QUIET — NESTS ARM AHEAD OF US NOW. A STRAIGHT LINE IS A CHOICE"), each fired once ever per save. The lines are excellent — diegetic, terse, and they never name a gesture the device doesn't have. The four band-crossing barks added recently (one per band from THE REACHES out) are exactly the right idea.

The first real high point arrives on schedule: breaching the survey hull erupts a loot vortex, charts PYX-02 on your map — and then a magenta GSA broadcast tells you PYX-02 is **charted and unreachable**, because something called THE GNOMON is jamming the lane from "the WEST quarter of THE DRIFT, between 260u and 340u past the marker. That is a QUARTER OF THE SKY, not a bearing. Silence it and the way is yours." That is the best locked-door copy I've seen in a mobile game, and it's the whole game in miniature: the obstacle is a place, the place must be found, and finding it is the content.

---

## 3. The core loop, and the economy under it

The loop as played: undock, sweep a wave or two, fly out to something — a hulk, a seam, a rumor — do the verb, run the hold back, sell, refit. Eight to twelve minutes. It works because every leg pays *something* and no leg pays everything:

- **Charted space** is steady income with zero risk of losing cargo (nothing spills inside the chart), and it repopulates.
- **The deep** pays multiples, but dying past the chart edge drops your *unread* salvage at the death site — identified components stay aboard, so reading salvage is also stowing it. That one rule creates the entire push-your-luck texture of a deep run.
- **Contraband** inverts the map: interdiction risk falls with depth (×0.6/×0.3/×0.1/×0.05, never zero), so the smuggler's route is *outward*, through everything that shoots, to a fence paying 1.45×.

I ran the game's own economy demo and market probes. Per-port price spreads are real (alloys 26 at the industrial port, 46 at the bastion; relics 322 at the fence against a base 260), routes emerge from the bias tables rather than from scripts, and the no-arbitrage rule — buy-and-resell must lose money at the same counter, everywhere, at every size — is enforced across 169 buyer/seller pairs by assertion. Dumping cargo visibly depresses the local price. This is a hand-built economy that behaves like one.

The fitting system is the progression spine and it's excellent. Six slots, one power budget, and the budget *binds*: the top reactor (Mk V, 24 power, 90,000) cannot carry an all-best fit (32 power) — by construction, forever, and there's an assertion pinning it. Every module trades: the Hauler Frame buys 34 hold with your speed; Bulwark Plating buys 150 shield with your agility; the complete mining fit costs you the Lance Array. Fits are visible on the hull itself — the kitbashed ship rebuilds from your loadout, so what a ship *is* reads at a glance. My one economy-side worry is at the top: the Mk III line is a +10% ladder whose defense ("the question is whether a Mk III *fits*, not which one") is clever but thin — filling it out with sidegrades rather than increments would age better.

---

## 4. The deep: the best of the game

Everything past the chart edge is where Pyxis stops being a good mobile game and starts being a distinctive one.

The bands have *character*, not just bigger numbers. THE SHOALS is a training slope. THE DRIFT gets convoys and guard posts. THE REACHES formalizes convoy etiquette ("they shoot back in order, not first"). THE QUIET arms nests ahead of your line of flight and turns the score into two detuned sine waves beating over eleven seconds — the audio design out there is doing horror work with almost nothing. THE FATHOMS ends the jump network: "FROM HERE, EVERY RETURN IS FLOWN." And THE UNSOUNDED has storms — 400-unit wandering weather cells, the only thing in the game that kills you without shooting — with a drag gradient designed so that *every legal fit escapes from anywhere outside the eye*: the storm never closes the last few hundred units; you do, chasing the loot ring you can't work from inside the pull. That is threat design of a very high order — the trap is always your own greed, on-screen, legible.

The deep is also *named*: the status line doesn't read coordinates, it reads localities — "◆ THE UNFILED · 1500u OUT", "● THE OUTER GRID · 448u OUT" — and each band's automated broadcast escalates until THE QUIET's, which I'll quote in full because it's the game's thesis in two sentences: *"The beacon net does not reach this far. Nothing is transmitting. Nothing is listening."*

Layered over the bands: guarded hulks (the survey mast on the stern is outside the guard ring, so *surveying* a guarded wreck is the sneak play while *cracking* it contests the post); rigged hulks telegraphing with a cold blue stutter before an EMP; the shear — a rift windfall dying in three telegraphed pulses, a third of the pot each; bonded stores to park salvage your skill can't read yet; and one automated GSA beacon per band whose escalating legalese ("no carrier" by THE QUIET) is the best environmental storytelling in the build.

The Hunt deserves its own paragraph. Each system's apex engine hides at a seeded bearing and depth, and the game hands you an *estimator*, not a waypoint: intel channels (a hull's log ±20°, a cleared guard post ±15°, a survey mast ±8°, The Last Watch ±5° for 900 salvage) narrow a search circle that is honestly wrong by whatever error you haven't bought out. Readings are seeded, so save-scumming doesn't reroll a better cone. The three engines are properly differentiated (shadow lance you sidestep; flare mortars; a graviton tether that does no damage and *drags you into the sweep*), all telegraphed, all dodge-legible, and only vulnerable during their SURVEY window. I watched the demo fight THE GNOMON: the seal-phase structure reads clearly even at capture framerates, and the wreck's loot shower plus the "LANE CLEARED — PYX-02 is open" broadcast is a proper diegetic victory lap.

The newest layer — chart memory — is the endgame this game always implied. Survey coverage persists on the chart (capped, oldest-evicted); selling chart data *files* your cells and pays a one-time first-charted bonus per cell; and a **rival cartographer** works the same deep on your own played-seconds clock — never seen, never armed, zero bytes of save, just cells that are already filed when you get there and, 4% of the time, one of their violet beacons refusing your recovery hold. Pause the game a month and the rival pauses with you. It converts chart income from a farm into an outward treadmill and gives solitude a shape without breaking it. This is the smartest piece of design in the build.

---

## 5. The living world

The faction layer is real but deliberately quiet: fourteen flags, standing that moves for attributable reasons (cover someone under fire and the toast names the cause), a Cordon that patrols authored routes and re-forms, a 24-ship MUSTER you can stand with or meet alone — which pays *nothing*, and is there because watching the line hold is its own reward. NPC-vs-NPC fire can never take a machine below half hull: **only the player depletes the world**, which keeps ambient combat from eating your content. The three unknown-faction presences in the deep (THE TALLY, which never loses you; THE HOLLOWING, which strips you to a sliver and cannot take your last point of shield; THE STILLNESS, which keeps the deep lights and *trades*) are exactly the kind of unexplained furniture a lonely frontier needs.

The tolls-and-parley system (raids open with six seconds of standoff; smuggling tiers buy time, a bluff with printed odds, and access — never credits) is strong, and its history is instructive: the record shows the parley shipped unreadable three separate ways and one paid toll used to *permanently delete all future raids* via a standing edge case. Both fixed, both now asserted — but it's the system I'd watch most closely in playtests, because it has failed quietly before.

---

## 6. Presentation

**Visuals.** Untextured primitives, hard silhouettes on near-black, one amber/gold cartographic palette with magenta/teal signal accents. At its best — the chart sheet with its band rings and jam markers, the breach vortex, the apex boss's pink survey sphere over a black monolith — it looks like a deliberate aesthetic. At its worst — empty mid-band space, the placeholder-grade station lumps — it looks like programmer art that a palette is holding together. The bones are good: silhouette-first design (the deep counters are distinguishable at name-read range by *shape*), a consistent VFX language, MSAA-friendly geometry. It needs a dressing pass, and the roadmap knows it.

**Audio.** The two-axis score (threat × depth, four continuously crossfading stems) is the single most sophisticated system in the presentation layer, and THE QUIET's near-silence is the game's best audio moment. The recent fix giving combat sound distance falloff (flat inside 40u, −22 dB by 120u, culled past) addressed what a playtester rightly called "really annoying." SFX are generated (`tools/gen_sfx.py`) and serviceable, not memorable.

**UI.** The bottom-sheet console vocabulary (chart, refit, hold, port, manual all slide up over a still-visible world) is genuinely right for portrait play — refitting never feels like leaving the game. Docked sheets are data-driven per station (the Waypoint Anchor offers MARKET/OUTFITTER/REPAIR/CONTRACTS/PAINT/STORAGE/COMMISSION; the Embers Cantina offers RUMORS/GAMES/FENCE instead — no market at all), and the paint shop is a quiet delight: hull and accent swatches, a nameplate field, and one honest sentence — "The Core still sets the ability glow and the engine bloom — paint never hides what you are flying." The hold-as-grid (one cell = one unit of space, glyphs not colors as the primary channel) is a small masterpiece of mobile inventory design. Tap targets are floored at 42px and *asserted*. The in-game manual derives every number it prints from the live data tables, so it cannot lie after a rebalance — other games should steal this.

**Accessibility** is far beyond genre norm: rebindable keys (with reserved-escape discipline), grid-searched color-vision palettes (the shipped remaps score 4–6× better than hand-picked "safe" sets on the game's own confusion metric), always-on band glyphs that survive greyscale, reduce-motion that snaps rather than accelerates, haptics gating, and a UI scale slider the layouts are actually tested against. The two nastiest bugs ever found in this area (color-vision cycling resetting a boss fight; welding the ship to a stale berth) were found, fixed, and armored with assertions.

---

## 7. What I measured (QA capability assessment)

This project's testing culture is its superpower and deserves comment in any review of "capabilities."

- **Fresh-clone sweep:** 70 runs, **711 PASS / 1 FAIL / 0 script errors**, save byte-identical. Expected 712 — the predicted number in the README, which itself warns that a predicted baseline is not a measurement. It was right to warn.
- **The one red line** is `COLONYTEST`'s newest assertion ("THE MONUMENT ANSWERS A TAP", added in the latest patch). It is deterministic, reproduces standalone, and is a *harness* defect, not a game defect: an earlier leg of the same harness claims the first monument in the scene tree, and the new leg then re-selects that same monument and expects the unclaimed prompt. The game's actual unclaimed prompt is verified correct by the earlier leg. This is precisely the "inherits state from the leg above it" failure shape the project's own README documents — and this line has plausibly never been green in a full sweep, because the README's 712 was a prediction, not a measurement. Fix: clear `GameState.colonies` (or pick an unclaimed instrument) before the tap leg.
- **The harness runner has a Linux portability hole:** `run_harness.sh` shells out to macOS `md5`, which doesn't exist on Linux, so the save-integrity check printed `save intact ()` — empty hashes, vacuously true. A check that silently proves nothing is the exact failure the script's own comments curse twice. Fix: `md5sum` fallback.
- **The scripted demo capture is stale:** it still calls `travel_to("pyx02")` right after charting it, but the Hunt's jam rule (shipped later) now refuses that warp while the apex lives — so the frames labeled `arrival_pyx02` and `pyx02_combat` are actually taken in PYX-01, and the demo's own log confirms `pyx02 unlocked=false`. Capture modes assert nothing, so nothing caught the drift. The project's own maxim applies: an observation is not an assertion.
- Everything else I ran — tutorial completion, dock safety under fire, boss dock-lock, input device split, market spreads, the whole SAVETEST migration ladder v5→v22 — behaved exactly as documented.

For a solo project, finding *three* defects in a full external audit — all three in the test/tooling layer, none in the game — is an extraordinary result, and the defect classes themselves (state-leaking test, vacuous check, drifted observation) are ones the project has already named in its own documentation. The discipline is real, and it shows up in play as a game that simply does not crash, desync, or eat saves.

---

## 8. Findings and feedback, ranked

### What's exceptional
1. **The depth/surveillance inversion.** Safety from the law and safety from the world run in opposite directions. Every trip out is a portfolio decision. No other mobile game I know is built on this.
2. **The rival cartographer.** An antagonist made of pure arithmetic, racing your own play clock, who never breaks the game's solitude. The 4% violet beacons are the right amount of ghost.
3. **The Hunt's estimator honesty.** The search circle is *derived from your hints and honestly wrong*. Buying intel never widens the search; readings are seeded against save-scumming. Finding the boss genuinely is the content.
4. **The pacing contract as an assertion.** The eight-minute loop's yield is a tested invariant, not a hope. When the yardstick drifted, they re-derived it from measurement (the §86 record of *why* 3.00 was the wrong bar is exemplary design writing).
5. **Storm design.** "The storm never closes the last 520u; you do" should be taught in threat-design courses.
6. **Death has teeth without cruelty.** Spill-unread-only, at the death site, in the deep only — recoverable if you dare, gone if you don't, and never a save-wipe.

### What needs work (player-facing, ranked by how much it would move my score)
1. **The endgame payoff isn't there yet.** THE UNSOUNDED is the band every system points toward — the score, the barks, the storms, the economy ladder — and there is currently one grave hulk past 5,200u where the answer to the game's founding mystery should be. The UNSOUNDED-FRAGMENTS draft (the frontier wasn't killed; it was *written off*, and your return is the filing) is the right story; until it ships, the game's difficulty curve is a staircase to a locked room. This is the single most important missing piece.
2. **Discoverability debt is systemic.** Six of nine notes in the latest playtest were built features players couldn't find. The patch's teaching surfaces (forge bill deriving sources, commission page opening with what it does, band barks) are good triage — but the pattern says the game needs a *structural* answer: a "what just unlocked" surface, or the captain's log doing double duty as a hint ledger, or the manual getting one "things your ship can do now" page. The systems are too good to be secret.
3. **Mobile parity has one real hole:** the contact menu is right-click only — a desktop-only verb in a mobile-first game, acknowledged in the backlog. Long-press is the obvious answer and it should ship before any store build.
4. **Performance on real phones is unproven.** The frame-time harness bounds the *mean* (~7ms) but `worst` spikes to 17–48ms on a desktop-class dev machine, and the whole render stack has never been profiled on a tile GPU per the record. The art is cheap by design, so this is probably fine — but "probably fine" is exactly what the project's culture refuses elsewhere.
5. **Dual-Lance dominance.** The record's own measurement: dual Lance Mk II clears the apex 40–90% faster than every other fit against a stated "no fit >25% faster" bar. In a game where fitting *is* the skill expression, a solved weapon slot is a real hole; it deserves the same re-derivation treatment the pacing bar got.
6. **Small UI collisions.** Floating gain popups (+1 RELICS, +306) land on top of the HOLD/HULL labels in the top-left. Transient and minor, but it's the one place the otherwise disciplined HUD overlaps itself, and this project has an assertion vocabulary (BANDS CLEAR) that could pin it.
7. **The chart's tap does nothing.** Acknowledged as deliberate ("a tap that selects with nothing to do is worse than a tap that moves the map") — but as the chart becomes the endgame surface (coverage, filings, rival presence), a tap-for-cell-detail verb is going to earn its place. Revisit.

### Defects found this session (all test/tooling, none in the game)
| # | Where | What | Severity |
|---|---|---|---|
| 1 | `main.gd` COLONYTEST leg K | State leak from leg E: taps an already-claimed monument, expects unclaimed prompt. Deterministic FAIL; the sweep cannot read 712 until fixed. | Test defect — blocks the green baseline |
| 2 | `tools/run_harness.sh` | macOS-only `md5` → save-integrity check silently vacuous on Linux (`save intact ()`), exit-status contribution lost. | Tooling — a lying gate, per the project's own taxonomy |
| 3 | `main.gd` `_run_demo` | Capture script predates the jam rule; `travel_to("pyx02")` refused, `pyx02`-labeled frames shot in PYX-01. | Capture drift — mislabeled marketing/verification footage |

---

## 9. Suggestions from the pilot's seat

- **Ship the fragments.** Everything else on the backlog is polish; the UNSOUNDED answer is identity. The draft's ending — the game handing you back your own mechanic ("check your clock, trust your own marks, and file a return for us") — is the kind of thing players screenshot and post.
- **Give the ledger a face.** The game tracks everything (cells filed, posts cleared, tiers, standings) and shows almost none of it unprompted. A single end-of-session "survey filed" card — three lines, diegetic, dismissible — would fix half the discoverability debt at a stroke and give the eight-minute loop a punctuation mark.
- **Let me name my finds.** First-charted cells pay a bonus and record provenance; letting the first filer *name* the cell (with the rival naming theirs) would cost nothing and make the chart feel owned. (The Horizon 5 claims-server design already reaches for this — the single-player version is nearly free.)
- **A photo mode is sitting right there.** The capture harnesses already fly the camera and frame shots. Ten lines of UI would turn that into a player-facing photo mode, and this game's silhouettes deserve it.
- **Consider a "second bearing" at the tutorial's end.** It hands you one bearing (the survey hull). Handing two — the hull, and "something is transmitting from the deep" — would seed the Hunt's pull twenty minutes earlier without adding a single system.

---

## 10. The road ahead (briefly)

The Horizon 5 document — a thin claims server, first-charted names shared across players, capsule rumors, free-entry derbies — is out of scope for a play review, but one note belongs here: the single-player game underneath it is *already* built as if the claims server existed (deterministic world, pure-function rival, provenance in the ledger). That is either excellent groundwork or scope gravity, and the difference will be whether the solo loop keeps getting content first. On this build's evidence, the priorities have been right so far.

---

*Method note: review conducted on a fresh clone with Godot 4.6.stable (Linux). Evidence base: the full 70-run assertion sweep (logs retained), the scripted demo and tutorial playthroughs under rendered capture at 720×1280, the observational harnesses (title/input/dock/market/econ), the world-tour and deep-space capture modes, and the complete design record in `docs/STRATEGY.md` §1–§90. Screenshots referenced are committed alongside this document.*

---

## Appendix: captured frames (this session, 720×1280 unless noted)

| frame | what it shows |
|---|---|
| `review-shots/01_title.png` | Title screen — compass dial over the live starting system |
| `review-shots/02_chart_locked.png` | Chart sheet, PYX-02 still locked; band-ring plot, hunt hint below |
| `review-shots/03_breach_vortex.png` | Survey hull breach: loot vortex, GSA "QUARTER OF THE SKY" broadcast, intel line |
| `review-shots/04_chart_hunt_estimate.png` | PYX-02 charted-and-jammed; estimate circle from 2 readings; RETURN TO SYSTEM |
| `review-shots/05_apex_wake.png` | THE GNOMON waking — boss bar, phase pips, JAMMED line |
| `review-shots/06_apex_midfight.png` | Shadow-lance beam, venting probes, AEGIS core on cooldown |
| `review-shots/07_apex_kill_payoff.png` | Wreck loot shower + "LANE CLEARED — PYX-02 is open" |
| `review-shots/08_docked_market.png` | Waypoint Anchor: seven service tabs, per-row trade controls, fenced rows |
| `review-shots/09_cantina_rumors.png` | The Embers Cantina — rumors for sale, free hunt word |
| `review-shots/10_paint_nameplate.png` | Paint shop: hull/accent swatches, nameplate, the honest-paint line |
| `review-shots/11_the_quiet.png` | THE QUIET's broadcast (landscape window) |
| `review-shots/12_deep_nest.png` | A nest and its swarm in the deep (landscape window) |
