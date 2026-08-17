# Horizon 6 — The Known Frontier

**Status: commits 0–4 BUILT (§73, §74, §75, §76, §78). Commits 5–6 specced, not built.** When any of
them is adopted, record it in `docs/STRATEGY.md` §64 in the same commit, per the
house rule.

> **Commits 0, 1 and 2 are swept and green: 657 PASS / 0 FAIL / 0 script errors
> across 65 runs, save intact, Godot 4.6.stable headless, 2026-08-17.** The delta
> from §73's 643/64 reconciles exactly (§74 +4, §75 +10 in one new run), which is
> the check worth doing every time: a total that moves by any other amount means
> an assertion was lost. Commits 3-6 are written in an environment with **no
> Godot binary**, so each must be swept on the owner's machine before its numbers
> are believed. `tools/run_harness.sh` now proves the binary exists and
> parse-checks before it starts, after a run was very nearly launched against a
> project whose class registry had never been rebuilt (§75's postscript).

This horizon comes from a week of playtesting rather than from a design gap: the
loop works, three-hour sessions happen, and five specific things got in the way.
The theme they share is that **the frontier is unknowable in ways it does not
need to be** — every Pyx reads the same past its chart, a beacon is a bookmark
you cannot return to, and the one picture of the deep is drawn for a different
purpose. The name is the fix: a frontier you can come to know.

Every fork below was put to the owner as an explicit question and answered; the
answers are recorded as settled. Where the reconnaissance pass changed a
decision, the change and its reason are recorded with it.

---

## 1. The ask, and what was settled

| # | The playtest note | Settled scope |
|---|---|---|
| 1 | *"Other than the small charted area, they all feel the same once you explore further out."* | Data identity **plus** one signature content class per Pyx |
| 2 | *"No way to auto-navigate to a beacon… only beacons in the same Pyx."* | **Both** verbs — free set-course autopilot and a paid instant jump |
| 3 | *"Surveys show on the chart but it is extremely hard to understand."* | **Persistent** per-Pyx coverage **plus** a full legibility pass |
| 4 | *"More hot keys / keyboard shortcuts."* | Three new rebindable actions; keyboard stays an additive desktop layer |
| 5 | *"Create an account… save multiple games to experiment with different builds."* | **Local pilot profiles now**, shaped so cloud sync bolts on later; no network code |

Note 5 was asked as "accounts" and answered as profiles-now-cloud-later
deliberately. §2 keeps the game single-player and offline-capable, and §5 rules
out MMO/social/live-ops — but §2 also says the local save is explicitly
serialized to *"keep a server port possible without building one now"*, and
`game_state.gd`'s own header repeats it. Profiles spend none of that option.
What the owner actually asked for — multiple builds, side by side — needs no
server at all.

---

## 2. Ground truth, verified against the code this session

The first draft of this plan was checked claim by claim against the source.
Nine load-bearing assumptions were wrong. These are the ones that changed the
design, and they are recorded here so the next pass does not re-derive them.

**A live crash existed and is fixed (§73, commit 0).** `plan_cell`'s band-0
early return set 7 keys while `built_plan` indexed `plan["hulk2"]` with no
`.get`. PYX-02 is the only system with band-0 cells. Fixed, and the assertion
that missed it now derives its key set instead of listing it.

**Per-Pyx density multipliers are unsafe at most sites.** Multiplying a chance
threshold spends the same draw only where every draw precedes the gate. Verified
site by site in `plan_cell`:

| site | safe to multiply? | why |
|---|---|---|
| `CONVOY_CHANCE` | **yes** | all seven draws taken before the gate |
| `GRAVE_CHANCE` (hulk2) | **yes** | same shape, written under the same rule |
| `DEEP_STORAGE_CHANCE` | **yes** | last draw of the station block |
| `STATION_CHANCE` | no | pass draws up to 5 more, and `keep_out` then moves which rocks `continue` |
| rocks row | no | pass draws `2 + N`, and a rejected rock skips three more |
| hulk row | no | pass draws 3–6 |
| `TRAP_CHANCE` | no | `randi_range` sits inside a lazy ternary |
| `PACK_CHANCE` | no | pass draws 3–4 |
| `SEAM_CHANCE` | no | `continue` skips two further draws |

Two facts to lean on instead of the broken one: the shared `rng` is never drawn
again after the pack block, so everything past it is on its own salted stream;
and every seed already includes `_id`, so **cross-system leakage is impossible by
construction** regardless of draw counts. The real cost of a station or rocks
multiplier is a cascade *within the same cell*, which is exactly what
`THE DRAW COUNT DID NOT MOVE` asserts against for pyx02.

**PYX-01 is barred from a `deep` block by assertion**, and it is where the
tutorial and the manual's first hour live. `IDENTITY IS ADDITIVE` asserts
`deep_of("pyx01").is_empty()`, and the world fingerprint is measured over PYX-01.

**Survey coverage cannot be persisted as it stands.** `_surveyed` is keyed by
bare `Vector2i` with no system id, so PYX-01 cell (7,-3) and PYX-02 cell (7,-3)
are the same key. It has a second consumer (deep-station docking), a raw private
read that bypasses the accessor, a sentinel key that serializes at ~8.6e9 units,
and an income assertion that would over-report while staying green.

**An unbounded beacon jump breaks the colony jump's bound.**
`A FOOTHOLD, NOT A FARM` derives its ratio from
`bounds_of("pyx03") + HYPER_DEPTH_MAX` (4200u). Beacons have no depth bound and
band 6 starts at 5200u.

**Settings live inside the per-run save**, so a per-profile save silently makes
key bindings, colour vision, volumes and UI scale per-pilot.

**`beacons_in` returns the live store by reference**, unsorted and keyless —
`colonies_in` copies and sorts, and only the latter is safe to build UI from.

**A naive `_jump_beats` extraction moves recall's camera six units.** Recall puts
the rig at `(0,0,2)` while the ship goes to `SPAWN_POINT (0,0,6)`; colony uses
`arrive + (0,0,2)`.

**Nothing can be verified without a Godot binary**, and the README's baseline was
stale twice over. Corrected in commit 0 to 46 tags + 18 SAVETEST modes = 64 runs.

---

## 3. The commit ladder — settled

Two departures from the obvious order, both load-bearing:

- **Profiles move early (commit 2), not last.** They change where saves live and
  split device settings out. Doing that before any new key exists turns two save
  bumps into one and avoids migrating a migration.
- **The chart splits in two.** Legibility (commit 4) is what answers the note and
  touches no doc, no save and no assertion. Persistence (commit 6) reverses a
  recorded decision and moves income, so it lands last and alone.

| # | commit | save | status |
|---|---|---|---|
| 0 | preconditions | none | **BUILT** — §73 |
| 1 | hotkeys | none | **BUILT** — §74 |
| 2 | pilot profiles + prefs split | none | **BUILT** — §75 |
| 3 | per-Pyx identity + signature content | none | **BUILT** — §76 |
| 4 | chart legibility | none | **BUILT** — §78 |
| 5 | beacon navigation | none | not built |
| 6 | persistent survey coverage | **v21** | not built |

---

## 4. Commit 1 — hotkeys

`chart` (C), `drop_beacon` (B), `pause` (P) — **BUILT, §74**. Ids are chosen to
read as UI copy,
because `pause_menu.gd` upper-cases the action id verbatim into the settings row.

Rejected: `refit` (a dock-context surface), `recall` (a one-key teleport with no
confirm), target-cancel (Esc rung 3 already is that key).

**Each key routes through a guarded wrapper, never the panel.** The chart lock
lives on the *button* — `set_panels_locked` flips `chart_button.enabled` — so a
key calling `chart_panel.open()` bypasses it and reopens the chart mid-apex
fight, which `disengage_apex`'s comment relies on being impossible. **Pause is
handled inside `PauseMenu`**, not `CameraRig`, which has no `process_mode`
override and stops receiving input once paused; it must sit after the rebind
capture guard, which swallows the next keypress while a row is armed.

Mandatory in the same commit: append all three to `REBINDABLE`, or ACCESSTEST's
set-equality check fails. The manual's desktop page also drops its hardcoded
`"W A S D"` / `"SPACE"` / `"I"` literals for `_binding_name()` — it is already
false under rebinding and more literals deepen the drift.

---

## 5. Commit 2 — pilot profiles

`user://profiles/<id>/save.json` per pilot, `user://profiles.json` as the
registry, and **`user://prefs.json` for device-level settings shared by all
pilots**. Ids are opaque (`"p_" + 8 hex`), never derived from the name.

**The settings split is the load-bearing part, not the path redirect.**
`reset_to_starter` deliberately does not clear `commissioned`, `ship_name` or
`audio_muted`, and never touches `livery` or `settings`. Left alone, pilot two
boots wearing pilot one's paint and name, already commissioned.

| per-pilot (`save.json`) | device-level (`prefs.json`) |
|---|---|
| salvage, cargo, modules, fit, systems, intel, beacons, colonies, ledger, skills, faction deltas, `barks_seen`, `tutorial_step`, `played_seconds`, **`ship_name`, `livery`, `commissioned`** | all of `settings` — bindings, `ui_scale`, volumes, `colorblind`, `haptics`, `reduce_motion`, `telemetry` — plus `audio_muted` and `tutorial_seen` |

**Identity is per-pilot — settled with the owner, 2026-08-17.** This is the
decision the whole feature turns on, because the three fields
`reset_to_starter` preserves are described in their own comments as things that
*"outlive the run"*, and profiles split that phrase in half: a thing can outlive
the run and still belong to the pilot rather than the device.

Each pilot names their own ship, starts in default paint, and earns their own
commission. That makes a second pilot a genuinely separate run rather than the
same captain in a different save slot, which is what "experiment with different
builds" asks for. The accepted cost is stated rather than hidden: a second pilot
re-earns the commission and the accent colours ≥8 it unlocks, and the deep's
`from_commissioned` broadcast copy reverts with it. `commissioned` gates flavour
and cosmetics, never a system or a lane, so this costs a new pilot nothing they
cannot reach.

`audio_muted` goes the other way for the reason its own comment already gives —
it is a device preference, not run state.

**Five slots.** Enough for parallel builds without the page becoming a list to
manage, and five rows fit the title screen's fixed 240px button column without a
ScrollContainer.

**The tutorial runs once per device, not once per pilot** — a player building a
fourth fit does not want six steps of onboarding again. Note the implementation
subtlety: `tutorial_step` **stays per-pilot**, because it is genuinely run state
and moving it wholesale would share mid-tutorial progress between pilots. What
moves to `prefs.json` is a single `tutorial_seen` flag, and a newly created
pilot starts at `tutorial_step = -1` (complete) when the device has already set
it. `barks_seen` stays per-pilot as before.

**The switch verb is one function**, because `save_path = X; load_game()` is not
a reset — it no-ops on a missing file and leaves the previous pilot loaded. It
must cancel the pending `_save_timer`, force-save the outgoing profile, set the
path, `if not load_game(): reset_to_starter()`, `_recompute()`, and clear
`last_read_tiered` and `diverts`.

**`save_path` stays a plain var set once, never a live-derived property.** Three
harnesses assign it and never restore it, so a recompute mid-harness would stomp
the probe path and write the real save. `scripts/profiles.gd` is pure registry IO
with no other class references, so it cannot close the class-list cycle that once
produced forty parse errors and a hanging boot. GameState does its **own** env
scan for harness detection — it cannot call `main.harness_running()`, which runs
after `GameState._ready()`.

Also here, because the save layer is open: a `NOTIFICATION_APPLICATION_PAUSED`
handler (backgrounding a phone currently relies on the 1s debounce having fired),
a pilot id on telemetry rows, and the sweep's md5 guard widened to the profiles
directory.

---

## 6. Commit 3 — per-Pyx identity + signature content

Four channels that cannot move the RNG stream, plus density only where verified:

1. **`band_names`** — per-Pyx region naming, display-only.
2. **`wash`** — cold-sphere and mote/star tints, applied in `configure()`, which
   already resolves `_deep` before it builds them. Hashes nothing.
3. **Weighted picks** — the existing `station_weights` / `landmark_weights`
   mechanism, authored harder than v19's token rows.
4. **`broadcasts`** — a copy overlay; the deep speaks differently per Pyx.
5. **`density`** — `convoy`, `grave`, `deep_storage` only. See §2's table.

**Per-Pyx band recolouring is rejected**, and for two reasons worth keeping:
`Palette.BAND_SETS` is accessibility-audited as a *set* (§30 records hand-picked
"safe" palettes scoring materially worse than the shipped one), and
`THE TABLES GREW TOGETHER` pins a literal count of 25 band-indexed tables.

**PYX-01 gets identity, and the assertion gets stronger.** Rewrite
`IDENTITY IS ADDITIVE` from *"PYX-01's block is empty"* to **"PYX-01 authors none
of the shared-stream keys"**, with the forbidden set (`station_weights`,
`landmark_weights`, `density`) enumerated as a const the assertion reads.
Red-verify by authoring a `station_weights` row on PYX-01: the fingerprint must
go red at both call sites. If it moves for any *other* reason, that is a defect
to chase, not a constant to re-pin.

**One signature class per Pyx**, appended on its own salted stream after `hulk2`,
drawing before it gates, gating on nothing the shared stream produced, and
present in **both** the band-0 early-return literal and the harness key set.
Follow `mineable_seam.gd` — the most recent of the six duck-typed hold-contract
implementations and the one documenting the group-choice tradeoff.

- **PYX-01 — THE DROWNED RELAYS** (bands 1–2): dead watch-buoys that answer once
  with a degraded broadcast, using the `_hailed` session-dict shape.
- **PYX-02 — THE SLAG TIDES** (bands 2–4): a drifting industrial cluster that
  ticks mild hull heat and carries a rich metal seam.
- **PYX-03 — THE SOUNDING LINES** (bands 3–5): a plumb-line pylon quoting a free
  bearing to the nearest deep station, through `compass_deg`.

Widening the deep block trips two width assertions; any new landmark kind or deep
archetype widens **every authored row in every system** in the same commit.

---

## 7. Commit 4 — chart legibility

The plot's coordinate system is currently derived from the apex lair band, and
`_hunt_is_live` rejects any system with an empty `apex` dict — so a **new scale
source comes first**: fit-to-content over `bounds`, surveyed extent, beacons,
colonies and (when live) the hunt band. That also fixes beacons past `r_max`
drawing outside the rect.

Then, in order of what a reader needs: **a you-are-here marker** (nothing in
`chart_panel.gd` references the player node at all), **depth-band rings from
`BAND_EDGES`** labelled with commit 3's names and `Palette.band_glyph` — today
the only rings are the amber apex band, meaning something entirely different — **a
legend and scale bar**, **beacons and colonies always visible**, and **pan / zoom
/ tap**.

Both `_hunt_is_live` gates must be addressed (the visibility flag *and* the draw
early-return), plus `_plot.custom_minimum_size`, the only thing giving the plot
height. `_plot.mouse_filter` becomes `STOP`; it receives no input today. The
gesture algorithm from `camera_rig.gd` is reusable as ~15 lines of logic, not as
code — every state var there is a world-camera `Vector3`.

Every new layer needs a **glyph or shape**, not only a colour (§30: redundancy
first). Measure the layer stack the way `BANDS SEPARATE` measures simulated
colours rather than eyeballing it.

All of this lives inside a sheet, so the world's tap/hold grammar is untouched
and §64's deferred contact-menu audit stays deferred.

---

## 8. Commit 5 — beacon navigation

**Same-Pyx is structural**: the store is keyed by system id, and every surface
reads only the current system, copying the colony-row gate. No cross-system path
exists to disable.

**Rows need a copying accessor.** Add `beacon_rows(system_id)` in `colonies_in`'s
shape, returning `{x, z, label, depth}` with the **label synthesized at read
time** — which removes the designation field and with it a whole save bump. Rows
key on the `(x,z)` pair, matching `recover_beacon`'s 0.5u tolerance, because
`remove_at` reindexes.

**Set-course gets its own entry point**, not a flag inside `command_move` —
twelve callers share that verb, and every hold-approach and empty-space tap would
read as a plotted course. Note `command_move` silently no-ops while docked,
warping or EMP-stunned; the button must refuse with §58 copy rather than appear
to work.

**An unattended course is otherwise a death sentence.** A 4,000u course is ~730s
across ~62 cells; at band 4 roughly half arm a nest within trigger range of a
straight line, and `_tick_return_fire` never sets `attack_target`, so being shot
does not interrupt it. The course **self-cancels** on threat, EMP or low hull and
**toasts every abort** — a silently dropped 700-second course reads as a bug. It
needs visible state: a CRS row in the nav corner (bearing via `compass_deg`,
never raw `atan2`) and the destination beacon promoted to cap-exempt on the
radar, reusing `TIER_HOME`'s exemption rather than adding a tier.

**The jump reaches no further than the instruments do** — capped at
`HYPER_DEPTH_MAX`; beyond that, set-course only. That preserves
`A FOOTHOLD, NOT A FARM`'s derivation exactly and keeps band 6 a place you fly
to. Fee scales with depth, capped at `COLONY_JUMP_FEE`. The cooldown is the
existing shared stamp, **renamed** to something kind-neutral with both comment
blocks amended rather than silently reused. Copy `A JUMP IS NOT A RAISE` for the
beacon verb.

**Teaching surfaces, which the drop verb never got**: the word "beacon" appears
four times in the manual and none of them says how to drop one; barks has no
beacon key; the tutorial never mentions them. This commit adds a manual row for
all three verbs and one bark.

**The cancel rung is a four-site change**: the rung, the docstring enumeration,
the manual prose, **and** the hand-written `3 if touchscreen else 4` literal in
MANUALTEST.

---

## 9. Commit 6 — persistent survey coverage (v21)

**The reversal, stated precisely.** §17 and §22 refuse a *visited-cells array*
because it *"would grow every minute the player flies"*. The amendment must
answer that argument, not wave at it: this records only cells where a mast was
**worked** — earned, not travelled — and ships with a **bounded construction**: a
per-system cap with oldest-first eviction, enforced on write and re-enforced in
the loader. §17's deep-stations-off-the-chart clause needs no amendment; it
governs registry fan-out, not display.

**System-qualified from the start**: keys are `DeepSpace.cell_key(...)` strings
(`"pyx01:7:-3"`), the shape `warehouse` already uses. `_load_surveyed` follows
`_load_seams_cut`'s posture.

**All three read paths move together** or the feature half-works in a way the
existing assertion still passes: `is_surveyed()`, the raw private read at the
mast gate, and deep-station docking — whose comment states the exact contract
being reversed.

**Reject the rift sentinel in `note_surveyed` itself**, not the loader, so the
in-memory set stays clean and a fit-to-content scale cannot blow up on it.

**Close the colour-vision path**: `rebuild_visuals` → `DeepSpace.rebuild` →
`_despawn_all` → `_surveyed.clear()` means changing colour vision wipes coverage
today, two taps from the pause menu, undocumented.

**Fix the income assertion that would silently over-report.** `PACING_LOOP`
counts `"survey": 2` as recurring at 280 credits each, and `STEADY` subtracts only
the derelict as one-time. Persistence gives near-home surveys the derelict's
once-only shape while leaving them in the steady-state term. Move `survey` into
the one-time bucket (`PACING_PROSPECT` too) and say why.

**The accepted trade, recorded rather than hidden**: this does not cap chart
income. The expanse is unbounded, so persistence converts a warp-reset farm into
an outward treadmill and permanently burns the near ring — the region a low-tier
ship can reach. **§41's `MIDTIER` re-derivation is due before this ships.**

---

## 10. Assertions to write (tagged per commit)

| commit | tag | assertions |
|---|---|---|
| 1 | `INPUTTEST` | THE CHART ANSWERS ITS KEY · **THE CHART KEY OBEYS THE LOCK** · THE BEACON KEY REFUSES THE CHART · PAUSE IS ONE KEY |
| 2 | `PROFILETEST` *(new tag)* | THE LEGACY SAVE MOVES ONCE · **NO BLEED BETWEEN PILOTS** · THE REGISTRY IS INPUT, NOT TRUTH · A HARNESS CANNOT REACH THE REGISTRY · PREFS OUTLIVE THE PILOT |
| 3 | `MINETEST`, `SIGTEST` *(new tag)* | IDENTITY IS ADDITIVE *(rewritten)* · THE DRAW COUNT DID NOT MOVE *(extended to convoy/seams/hulk2/landmark)* · DENSITY IS ALIVE · A SIGNATURE BELONGS TO ITS SYSTEM · THE SIGNATURE TAKES NO SHARED DRAW · THE GIFT GOES THROUGH THE GLASS |
| 4 | `CHARTTEST` | THE PLOT FITS ITS CONTENT · THE PLOT DRAWS WITHOUT A HUNT · THE OVERLAY STILL LAYERS · a `BANDS SEPARATE`-shaped colour-distance leg |
| 5 | `BEACONTEST` | THE SHIP FLIES ITSELF THERE · THE STICK BREAKS THE COURSE · A COURSE THAT DIES SAYS SO · CANCEL DROPS THE COURSE, ONE RUNG · **THE JUMP STOPS WHERE THE INSTRUMENTS DO** · ONE CLOCK FOR ALL OUTBOUND · SAME SYSTEM ONLY, STRUCTURALLY · THE MARKER WEARS YOUR PAINT |
| 6 | `CARTTEST`, `SAVETEST` | SESSION RESET → **THE CHART REMEMBERS** *(both directions)* · THE STORE IS SYSTEM-QUALIFIED · THE SENTINEL NEVER LANDS · COVERAGE SURVIVES A COLOUR CHANGE · cap eviction · `migrate20` |

A new tag touches five places: the `main.gd` dispatch (pick the right one of the
**two** sites), `HARNESS_VARS` (or `THE PINNING LIST IS COMPLETE` fails, which is
its own red-verify), `headless_mode` if it must boot PLAYING, and
`run_harness.sh`'s `TAGS`. `SAVE_MODES` is duplicated at two lines and both need
the new leg.

Do **not** flip MINETEST's `SESSION RESET` — that one pins mined state and is
unrelated to the survey rule.

---

## 11. Facts checked so you do not have to re-check them

- PYX-02 is the only system with band-0 cells: centres at `(64i+32, 64k+32)` put
  the four innermost at 45.25u against `bounds: 48.0`.
- The world fingerprint sweeps PYX-01 over cells (-5..5)² and hashes only
  rocks/hulk/pack/station subfields — no seams, convoy, landmark, hulk2, storage
  or colour. Adding plan keys cannot move it.
- Every deep-space seed includes the system id, so per-Pyx work cannot leak
  across systems whatever it does to draw counts.
- `weighted_index` falls back to a uniform modulo silently on an empty **or
  wrong-width** row; `EVERY AUTHORED ROW IS THE RIGHT WIDTH` is the countermeasure
  and must grow with every new row family.
- Frontier stage 4 is built; its sentinels are `GRAVE_CHANCE` + the `"|hulk2"`
  stream, pyx03's `depth_max: 2400.0`, and `LANDMARK_KINDS` at six.
- The sweep is 46 tags + 18 SAVETEST modes = **64 runs**. `SAVETEST` is not in
  `TAGS` and must be named as an argument to run its stateful sequence.
- There is no CI and no hook: `tools/run_harness.sh` is the entire quality gate
  and is invoked by hand.
