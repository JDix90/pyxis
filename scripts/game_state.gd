extends Node
# Autoloaded as `GameState`. Owns persistent player state and is the only
# thing that writes the save file. Serialization is explicit (never
# store-the-whole-object) so this layer can move behind a server later.

signal fit_changed(stats: Dictionary)
signal salvage_changed(total: int)
# v16. THE HOLD CHANGED, whoever changed it. Cargo is the one piece of state the
# WORLD mutates while a screen is looking at it -- loot picked up, a toll taken,
# a delivery settled on docking, salvage spilled on death -- so the nineteen
# hand-written hud.refresh_cargo() calls were a rule enforced by memory, and two
# sites had already forgotten: spill_unread and Contracts.on_docked both unload
# and neither refreshes. Emitted from load_cargo and unload_cargo, which grep
# confirms are the only two functions in the game that write `cargo` outside of
# a reset or a save load.
signal cargo_changed
signal system_unlocked(id: String)
# v15. The lane to `id` is now flyable — its jamming engine is dead. Deliberately
# a second signal rather than a flag on the first: charting and opening happen at
# different places, for different reasons, and a listener usually wants one.
signal lane_opened(id: String)
# A standing shift the PLAYER is party to. Emitted from the ONE mutator, so
# every mover that exists now and every mover added later is covered by
# construction rather than by somebody remembering to announce it.
#
# DELIBERATELY NOT GATED ON `quiet`. That flag governs the LOGBOOK -- ten slots,
# and a redundant line there took LOGTEST's FIVE SITES WIRED red once already
# (see shift_faction's note). A toast is not a slot. The three POSITIVE movers
# all pass quiet=true and all three had nothing on screen at all, which is the
# half of finding A10 the dock-sheet row never covered: a consequence you can
# only discover by docking somewhere and reading a line is not feedback for an
# act you committed four hundred units away.
signal standing_shifted(other: String, delta: int, band: int)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 20
const SAVE_DEBOUNCE := 1.0

# v6 defaults. Kept as one dictionary each so a migration only has to merge
# missing keys rather than know the whole shape — adding a fifth setting later
# costs a line here and nothing in load_game().
const DEFAULT_SETTINGS := {
	"music_vol": 0.75,
	"sfx_vol": 0.90,
	"shake": true,
	"ui_scale": 1.0,
	# On by default: this is a phone game whose loudest moments (a hull giving
	# way, a claim at a dock) are otherwise carried by colour and a camera lurch,
	# both of which someone may have turned off or be unable to use.
	"haptics": true,
	# Separate from "shake" on purpose. Shake predates this and some players turn
	# it off because they dislike shake specifically, not because they want every
	# transition in the game to stop moving. Merging the two would silently
	# reinterpret a preference they already expressed.
	"reduce_motion": false,
	# OFF by default, and it stays off unless someone deliberately turns it on.
	# The file never leaves the device and nothing in the game reads it -- see
	# scripts/telemetry.gd -- but a recorder running because the player never
	# found the switch is not a recorder they consented to.
	"telemetry": false,
	# Palette.Vision: 0 normal, 1 deutan, 2 protan, 3 tritan. Materials are baked
	# at node construction, so changing this rebuilds the world through the
	# existing build paths rather than retinting in place -- see main.rebuild_visuals.
	"colorblind": 0,
	# Rebindable actions, as {action: [physical keycodes]}. Empty means "whatever
	# project.godot says", so a save written before this existed keeps the
	# defaults instead of arriving with no controls at all.
	"bindings": {},
}
const DEFAULT_LIVERY := {
	"hull": 0,
	"accent": 0,
}

# v10. The logbook: what this run has DONE, as opposed to what it owns. Same
# shape as settings and livery — a defaults dict merged key by key on load — so
# a key added later arrives at 0 on an older save rather than missing entirely.
const DEFAULT_LEDGER := {
	"deepest_depth": 0,
	"distance_flown": 0,
	"hulks_cracked": 0,
	"posts_cleared": 0,
	"chart_data_sold": 0,
	"tolls_paid": 0,
}
const SHIP_NAME_MAX := 24
const DEFAULT_SHIP_NAME := "SURVEYOR"

# v12. The captain's log: the ledger counts, this one remembers. Ten lines, and
# deliberately NOT a seventh DEFAULT_LEDGER key — that dict's load-side merge is
# `maxi(0, int(...))`, an int contract that would turn an array into 0. It gets
# its own field and its own sanitizer, the shape market_events already uses.
#
# Bounded because an unbounded one is a visited-cells array by another name (17):
# it would grow every minute the player flies. Ten is what fits the pause sheet
# without scrolling and what a player can read at a glance.
const LOG_MAX := 10
const LOG_LINE_MAX := 48

var salvage := 0
var owned: Array[String] = []
var fit := {}
var reactor_tier := 0
var stats := {}

# Live power diversions: burned-out section id -> the section carrying its power.
#
# DELIBERATELY NOT SAVED, and that is the design rather than an omission. A
# diversion is a wound you are still carrying, and it lasts exactly until you
# reach a dock (clear_diverts, called from the dock completion). Writing it to
# the save would mean a pilot who quit mid-fight loads back into a burned-out
# mount with no memory of trading it away -- punishment for closing the game.
# Everything else about this mechanic is derived from live integrity, so an
# empty dictionary at load is the correct and complete state.
var diverts := {}

# v2 fields — travel, progression, and first-run state.
var current_system := ""
var breached: Array[String] = []
var contract_state := {}
var barks_seen: Array[String] = []

# v3: systems whose apex engine has been put down at least once (first-kill
# bonus is one-time). A DAMAGED engine is still never persisted — retreat from a
# fight and it is whole again, because failure costs tempo and never salvage.
# What IS persisted, since v17, is the kill itself: see apex_down.
var apex_killed: Array[String] = []

# v15. THE HUNT — progression is now TWO tiers, and this is the second.
#
#   breached   -> the next system is CHARTED. It appears on the map, named,
#                 with its lane jammed by the engine still transmitting.
#   lanes_open -> the lane is OPEN. Travel is permitted.
#
# Before v15 the breach did both and `apex_killed` gated nothing whatsoever —
# the engine was an optional windfall parked at 60% of the charted radius, in
# plain sight, and the frontier opened twenty minutes into a run. Splitting the
# two is what makes the hunt the spine instead of a side errand.
#
# Kept SEPARATE from apex_killed rather than derived from it, because the two
# answer different questions: apex_killed is "has this engine ever paid its
# first-kill bonus", lanes_open is "may this lane be flown". A save written
# before v15 has the second without the first (see _load_lanes_open) and must
# not be charged a bonus it already collected, nor refused a lane it already had.
var lanes_open: Array[String] = []

# v17. THE ENGINE STAYS DOWN. Systems whose apex engine has been DESTROYED.
#
# There are three states, and before v17 only two of them had somewhere to live,
# which is why a cleared system rebuilt a full-strength engine the moment you
# warped out and back — SystemBuilder had nothing to ask:
#
#   neither flag  -> the engine is alive. Build it.
#   apex_down     -> killed, wreck not yet cracked. Build the WRECK.
#   + apex_killed -> killed and cracked. Build nothing.
#
# Kept SEPARATE from both neighbours above, and neither of them could stand in:
#
#   apex_killed is "has the first-kill bonus been paid", which is only true once
#   the WRECK is cracked — a second trip the player may not survive. Gating the
#   build on it would leave exactly the window this field exists to close.
#
#   lanes_open is "may this lane be flown", which is not the same question: the
#   pre-v15 grandfather seeds it from `breached`, so a save from before the split
#   would mark living engines dead and silently delete their bonus.
#
# Written by Main.on_apex_defeated — deliberately NOT by open_lane(), which is
# also called to grant passage without anything having died.
var apex_down: Array[String] = []

# v15. The run's own salt, and the only source of per-playthrough hiding.
#
# Everything the hunt conceals derives from this and nothing else, which buys
# both halves of what a hunt needs: DETERMINISM WITHIN A RUN — fly away and come
# back and the lair has not moved, so a bearing you were told an hour ago is
# still true — and a FRESH HUNT ACROSS RUNS, so a second playthrough is not a
# walk to a remembered coordinate.
#
# Rolled exactly once, at reset_to_starter. Never re-rolled mid-run: re-rolling
# would silently invalidate every hint the player has paid for and flown for.
# Harnesses PIN it (Main.RUN_SEED_PINNED) — a harness whose world moved on every
# run would be measuring the dice.
var run_seed := 0

# v4: the economy.
var cargo := {}                # good id -> units held
var played_seconds := 0.0      # drives market drift; never wall-clock
var docked_at := ""            # port id, so a reload resumes docked
var market_pressure := {}      # "port|good" -> -0.25..0.25
# v8. How much salvage this pilot can read. Not a power stat and deliberately not
# spendable: it is a record of what you have actually done that opens doors, the
# same shape as `breached`. See identify() for the one rule it drives.
var archeology := 0
var archeology_xp := 0
# v11. SMUGGLING. Fed by ONE thing — contraband and stolen goods sold at a fence
# — and the two feeds that were cut are worth recording, because both were
# arithmetic rather than taste:
#
#   XP for TOLLS PAID rewards the losing move. Fighting a raid nets about +700
#   in drops, running costs nothing, and paying costs 400 or more; a skill that
#   levelled on tolls would pay a player for choosing worst. It also grants
#   retroactive XP out of every v10 ledger, which already counts tolls.
#
#   XP for ESCAPING is a free ninety-second loop between two systems, which is
#   the exact printer shape the leash rule was written against.
#
# What is left competes honestly with ARCHEOLOGY: the good-sets are disjoint,
# and the Void-to-Cantina run is a different flight plan from cracking hulks —
# different bands, different hold, different exposure. 19's warning is that
# skills all fed by "playing the game" rise together and become a clock.
var smuggling := 0
var smuggling_xp := 0

# v14. MINING. Fed by SEAMS CUT, weighted by band — never by ore SOLD, which a
# smuggler's dock visit would also trigger and which would make the three feeds
# rise together (19's clock warning, and FEEDS COMPETE asserts the good-sets are
# disjoint). Ore carries neither `band` nor `parent`, so it belongs to neither
# ARCHEOLOGY's salvage set nor SMUGGLING's, and the three stay honest rivals.
var mining := 0
var mining_xp := 0

# v19. PERSUASION. Fed by ONE thing — a parley you TALKED your way out of — and
# the two feeds that were cut here are the same two SMUGGLING cut above, for the
# same arithmetic. A skill must never pay for paying and must never pay for
# running, so a toll settled moves this ladder by exactly nothing.
#
# WHAT MADE IT POSSIBLE AT ALL is that a talk-down now carries a stake. A bluff
# has always burned a Forged Manifest whether it worked or not, precisely so it
# could not strictly dominate paying; a talk-down needs no manifest, so without
# a cost of its own it would be a free roll on every demand and levelling on it
# would be levelling on showing up. Failing one costs a step of Tithe standing —
# they remember being lied to — which is the mirror of the step paying earns.
#
# It competes honestly with the other three by EVENT rather than by good-set:
# reading salvage, fencing contraband and cutting seams are three flight plans,
# and this one is not a flight plan at all. It is the thing you do when a fourth
# party interrupts one.
var persuasion := 0
var persuasion_xp := 0

# v14. Charted seams already cut, keyed "system:asteroid_index" ("pyx01:2").
#
# PERSISTENT, unlike the expanse's session-only `_mined`, and the split is the
# whole design. There are eleven finite authored rocks in the game; respawning
# them on every warp is the deep-hulk farm bug that DeepSpace._build_post's
# comment already records once. The expanse can reset safely because its defence
# is the band gradient (see WARP FARM); eleven fixed rocks have no such defence.
#
# It cannot grow without bound the way 17's rejected visited-cells array would:
# it is capped at the number of authored asteroids in the game, which is 11.
# The KEY is the system id and the asteroid's ARRAY INDEX, so reordering an
# `asteroids` array in system_db.gd silently rekeys a player's cut seams.
var seams_cut := {}

# v16. THE INTEL DOSSIER. Keyed by system id; each value is an Array of hint
# dictionaries the player has PAID FOR or EARNED, and together they are the only
# thing standing between "somewhere past the chart edge" and a bearing to fly.
#
# Two shapes, and the difference is what each channel can honestly claim:
#
#   {"kind": <channel>, "ox": float, "oz": float, "bearing": float, "err": float}
#       A bearing taken FROM somewhere. `ox`/`oz` is where the instrument stood
#       — stored, never recomputed, because a cone drawn from the wrong origin
#       is worse than no cone — and `err` is the half-angle it can promise.
#   {"kind": "ring", "band": int, "quadrant": String}
#       A rumour. No origin and no bearing: an annulus and a compass sector.
#
# NOTHING here is ground truth. `SystemDB.lair_pos` is, and it is never written
# down: every hint is derived from it at the moment it is earned and then stands
# on its own, so a save file cannot leak the answer and a contradictory dossier
# stays contradictory. `Hunt.estimate` does the intersecting, live, from these.
#
# The entry is DELETED on the kill (mark_apex_killed): the hunt is over, the
# hints are worthless, and a dossier that outlives its quarry is just clutter
# that would redraw a survey plot for a system with nothing left to find.
var apex_intel := {}

# v20 HUNT STAGE 5. Dropped waypoint beacons, keyed by system id, each entry
# {"x": float, "z": float}. The STOCK is derived, never stored — BEACON_STOCK
# minus every entry across every system (§59's derived-not-tracked rule, so the
# save cannot disagree with itself about how many beacons exist). Validated on
# load by _load_beacons, entry by entry, the apex_intel loader's shape.
var beacons := {}

# v20 HUNT STAGE 6. Founded colonies, keyed "system:index" — the seams_cut key
# shape, with a sharper hazard: seams_cut's index names an AUTHORED array, and
# reordering it rekeys a player's cuts. A colony's index names a SEED-DERIVED
# position, which is strictly weaker — so the value carries the POSITION rather
# than a bare flag, and the jump reads the stored coordinates. A change to the
# seed policy, the depth band or the candidate count can then never strand a
# founded colony or point a jump row at empty space.
#
# A DICT PER INSTANCE rather than a set of keys, deliberately: §5's base-building
# exclusion was lifted this horizon, and a claimed colony is exactly where a
# construction layer would hang. Fields cost nothing to add to a dict and a save
# migration to add to a set.
var colonies := {}
# When the last colony jump was taken, on played_seconds. ONE stamp for all of
# them — never one per colony — so founding five never multiplies how often the
# player can be outbound. THE COOLDOWN IS THE MECHANISM here, not the fee: see
# Main.COLONY_JUMP_COOLDOWN.
var last_colony_jump := -1.0e9
# Eight is where the plot stops teaching. Past it the cones overlap so heavily
# that another one moves the estimate by less than the marker is wide, and the
# widest-error hint is dropped first — buying a ±5° reading should never be
# spent evicting itself in favour of a ±15° one already on file.
const HINT_CAP := 8
# Bumped whenever the dossier changes, so a renderer can cache an estimate
# without recomputing a 120x24 grid every frame. Deliberately NOT saved: it
# numbers edits within a session, not the dossier's contents.
var intel_version := 0

# v9. Bonded stores, keyed by PLACE.
#
#   chart station   the port id      ("anchor")
#   deep station    the CELL         ("pyx01:3:-7")
#
# The cell, emphatically not the archetype id. Every deep station carries its
# archetype as `port_id` (deep_space.gd sets it from the def), so every Shoal
# Relay in every system is "deep_relay" — a bay keyed on that would be ONE bay
# shared across an infinite map, and stashing 200u out of PYX-01 to withdraw
# 200u out of PYX-03 would teleport a hold between systems.
#
# This does not make the expanse saved state in 17's sense. That section
# refuses a visited-cells array because it "would grow every minute the player
# flies" — passive growth proportional to distance travelled. A bay grows only
# when you deliberately put something down. Generation stays a pure function of
# hash(system|cx|cz), and BECAUSE it does, every key here can be re-derived and
# validated against the generator on load rather than trusted.
var warehouse := {}

# One number, printed on the tab, identical at every station. Never a port-def
# key: a cap that VARIES turns storage capacity into a thing you shop for and
# compare across stations, which is a second budget with its own shopping trip —
# and 9 rule 1 allows exactly one.
const WAREHOUSE_SPACE := 60
var market_events: Array = []  # [{kind, port, good, mult, remaining}]

# v5: front door and first run.
var audio_muted := false
var tutorial_step := -1        # -1 = complete or never started

# v6: device preferences and ship identity. Both are deliberately NOT reset by
# reset_to_starter — how loud you like the music and what colour you painted the
# hull are yours, not the run's.
var settings := {}
var livery := {}
# The logbook is RUN state — a new survey is a new logbook, so reset_to_starter
# clears it. The ship's NAME is not: like the paint, what you called your ship is
# yours and outlives the run that named it.
var ledger := {}
var ship_name := DEFAULT_SHIP_NAME
# Run state too, cleared beside the ledger. Typed Array[String] on purpose: it is
# what forces the str() coercion on load that makes a hand-edited save safe, the
# same reason `owned`, `breached`, `barks_seen` and `apex_killed` carry the type.
var captains_log: Array[String] = []

# v13. The Grand Commission.
#
# `commission_claimed` is RUN state: how many stages this survey has claimed,
# cleared by reset_to_starter beside the ledger it reads from. Top-level rather
# than a seventh DEFAULT_LEDGER key, which was the other candidate: that dict's
# load merge is `maxi(0, int(...))`, a floor with no ceiling, so a hand-edited 99
# would reach STAGES[99] and crash AT A DOCK -- and the SAVETEST write leg
# assigns a literal six-key dict, so a seventh key would round-trip untested.
# This is the shape captains_log already shipped as, for the same reasons.
var commission_claimed := 0
# PERSISTENT, and the only thing here that is. What you earned outlives the run
# that earned it -- the livery and ship_name precedent.
#
# THE RULE, written down so the next reader does not "fix" it: `commissioned` is
# a strict monotone derivative of "stage 4 was ever claimed", and it is read by
# exactly three things -- the title screen's registry line, the accent lock, and
# the beacons. THE CLAIM COUNTER MUST NEVER READ IT, or stage 4 becomes
# unclaimable on every run after the first.
var commissioned := false

# v18. THE FACTION MATRIX — Horizon 4 stage 1 (docs/HORIZON-4-FACTIONS.md §4).
#
# Player-caused deltas over FactionDB.BASELINE, keyed by FactionDB.pair_key
# (canonical "a|b", a <= b), value clamped to ±FactionDB.DELTA_SPAN. SPARSE BY
# INVARIANT: a delta that returns to 0 is erased rather than stored, so "the
# player has changed nothing" and "the dict is empty" are the same statement —
# which is what lets NO INPUT, NO DRIFT assert on emptiness instead of on a
# tour of every pair.
#
# The baseline lives in FactionDB and the arithmetic lives HERE, not there:
# FactionDB is a pure leaf outside the class_name registry's reach (§39's
# cycle), and an autoload is the one place that can read both the table and
# the save without joining that graph.
var faction_deltas := {}
# Bumped whenever any attitude may have changed (shift, load, reset), so a
# hostile can cache its enemy list against a version instead of recomputing
# per frame — the apex_intel/intel_version pattern.
var faction_version := 0

# Overridable so scripted demos and tests never touch the player's real save.
var save_path := SAVE_PATH
# Guarded by _save_locked below: a harness that has said "never write" cannot be
# talked back into writing by any code path it later runs through.
var save_enabled := true:
	set(v):
		save_enabled = v and not _save_locked

var _save_locked := false
var _save_timer: SceneTreeTimer = null


func lock_saving() -> void:
	# One-way. Harnesses used to just assign `save_enabled = false`, but
	# start_new_game() assigns it back to true — and PYXIS_TITLETEST's entire job
	# is to press NEW SURVEY. The result was a headless test run silently
	# overwriting the player's actual save with a fresh starter run. A flag that
	# only travels in one direction is the fix; nothing may opt back in.
	_save_locked = true
	save_enabled = false


func saving_locked() -> bool:
	return _save_locked


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	settings = DEFAULT_SETTINGS.duplicate()
	livery = DEFAULT_LIVERY.duplicate()
	ledger = DEFAULT_LEDGER.duplicate()
	if not load_game():
		reset_to_starter()
	_recompute()
	apply_settings()


# --- v6 settings ------------------------------------------------------------

func setting(key: String) -> Variant:
	# Always answers, even for a key a v5 save never had.
	return settings.get(key, DEFAULT_SETTINGS.get(key))


func set_setting(key: String, value: Variant) -> void:
	if not DEFAULT_SETTINGS.has(key):
		push_warning("Pyxis: unknown setting '%s'" % key)
		return
	settings[key] = value
	apply_settings()
	_queue_save()


func apply_settings() -> void:
	# One place that pushes preferences at the systems that own them, called on
	# load and on every change, so there is no path where the save and the running
	# game disagree about the volume.
	Sfx.set_bus_volume(Sfx.BUS_MUSIC, float(setting("music_vol")))
	Sfx.set_bus_volume(Sfx.BUS_SFX, float(setting("sfx_vol")))
	UILayout.user_scale = clampf(float(setting("ui_scale")), 0.7, 1.6)
	var want_vision := clampi(int(setting("colorblind")), 0, Palette.Vision.size() - 1)
	var vision_changed: bool = want_vision != Palette.vision
	Palette.vision = want_vision
	apply_bindings()
	var tree := get_tree()
	if tree != null:
		var win := tree.root.get_window()
		if win != null:
			UILayout.apply_scale(win)
		if vision_changed:
			# Only on an actual CHANGE: apply_settings runs on every slider drag,
			# and rebuilding the world on each frame of a volume tweak would be a
			# hitch with no cause the player could see.
			var main := tree.get_first_node_in_group("main")
			if main != null and main.has_method("rebuild_visuals"):
				main.rebuild_visuals()


# --- v13 the Grand Commission ------------------------------------------------

# Index of the earned accent in Palette.LIVERY_ACCENTS. Named rather than a
# literal 8 because two files gate on it and a ninth bought accent added later
# must not silently become the earned one.
const REGISTRY_ACCENT := 8


func commission_stage() -> int:
	# Which stage is up for claiming. Equals STAGES.size() when all four are in.
	return clampi(commission_claimed, 0, CommissionDB.count())


func commission_complete() -> bool:
	return commission_claimed >= CommissionDB.count()


func commission_ready() -> bool:
	# Deliberately does NOT read `commissioned`: that flag is persistent, and a
	# claim counter that consulted it would find stage 4 already done and make it
	# unclaimable on every run after the first.
	if commission_complete():
		return false
	return CommissionDB.met(commission_stage(), ledger)


func claim_commission() -> Dictionary:
	# Re-checks stage AND thresholds at its own top rather than trusting the
	# caller -- survey_mast.gd's lesson, and the harness is exactly the second
	# caller that comment warns about. Returns {} on refusal so a caller cannot
	# mistake "nothing happened" for a payout.
	if not commission_ready():
		return {}
	var stage := commission_stage()
	var paid := int(CommissionDB.stage(stage).get("pays", 0))

	# STATE BEFORE MONEY. add_salvage emits salvage_changed, and PortPanel
	# re-enters _refresh() from that signal -- so incrementing after the payout
	# would rebuild the sheet reading the pre-claim stage and redraw the button
	# that was just paid for.
	commission_claimed = stage + 1
	if commission_claimed >= CommissionDB.count():
		commissioned = true
	add_salvage(paid)
	note_log("%s — GSA REGISTRY" % String(CommissionDB.stage(stage).get("name", "")))
	_queue_save()
	return {"stage": stage, "name": String(CommissionDB.stage(stage).get("name", "")), "pays": paid}


func accent_unlocked(index: int) -> bool:
	# The single question both renderers ask. The lock lives here and at the load
	# path, never in set_livery -- set_livery is also how a save restores a
	# colour, so a refusal there would rewrite a legitimately earned livery.
	return index < REGISTRY_ACCENT or commissioned


# --- the faction matrix (v18, Horizon 4 stage 1) -----------------------------

func faction_attitude(a: String, b: String) -> int:
	# How a feels about b: authored baseline plus the symmetric player-caused
	# delta, clamped at READ time — clamping the read rather than the pieces is
	# what keeps an asymmetric baseline plus a symmetric delta from pushing one
	# direction of a pair out of range while the other stays in.
	var att := clampi(FactionDB.baseline_attitude(a, b)
		+ int(faction_deltas.get(FactionDB.pair_key(a, b), 0)),
		FactionDB.ATTITUDE_MIN, FactionDB.ATTITUDE_MAX)
	# The one authored floor (HORIZON-4 §2): the Authority never reaches the
	# band where the Cordon would fire on the surveyor. Applied to both
	# directions of the pair — a player hostile to a power that is merely wary
	# of them would have pickets returning fire "in defence", which is the same
	# broken world by a side door.
	if (a == FactionDB.SURVEYOR and b == "gsa") or (a == "gsa" and b == FactionDB.SURVEYOR):
		att = maxi(att, FactionDB.GSA_SURVEYOR_FLOOR)
	return att


func faction_band(a: String, b: String) -> int:
	return FactionDB.band_of(faction_attitude(a, b))


func enemies_of(faction: String) -> Array:
	# Every faction id `faction` would fire on unprovoked. Callers cache the
	# result against faction_version rather than calling per frame — this walks
	# the whole roster and is priced for "attitudes changed", not "every tick".
	var out: Array = []
	for other_v in FactionDB.ids():
		var other := String(other_v)
		if other == faction:
			continue
		if faction_band(faction, other) == FactionDB.Band.HOSTILE:
			out.append(other)
	return out


func has_ring_hint(system_id: String) -> bool:
	# Whether the dossier already holds a band-and-quarter reading for this
	# system. The free relay files one the moment the lane closes, so a desk
	# selling the same thing needs to know not to offer it twice.
	for h_v in apex_hints(system_id):
		if String((h_v as Dictionary).get("kind", "")) == "ring":
			return true
	return false


func hostile_to_player(node) -> bool:
	# The one dispatcher every consumer asks, so "is this thing my enemy" has a
	# single answer instead of four that agree by luck.
	#
	# UNTYPED, for _auto_targetable's reason: a typed parameter is checked
	# before the call, and freed nodes arrive here routinely from group walks.
	#
	# NO METHOD MEANS HOSTILE. ApexBoss is in "hostiles" and carries no faction
	# at all -- it IS the fight -- and a default that spared it would make the
	# engine untappable and silent. Anything else unflagged is hostile by
	# construction too, which is the shipped world exactly.
	if not is_instance_valid(node):
		return false
	if not (node as Node).has_method("fights_the_player"):
		return true
	return bool(node.fights_the_player())


func shift_faction(a: String, b: String, amount: int, quiet := false) -> void:
	# THE ONLY MUTATOR, and it moves both directions of one pair at once —
	# deltas are symmetric by design (HORIZON-4 §2), so there is nothing else a
	# caller could mean. Player actions are the only legitimate callers; nothing
	# in the game may call this from a timer, a spawn, or another faction's
	# fortunes. NO INPUT, NO DRIFT is asserted against exactly this property.
	if amount == 0 or not FactionDB.is_faction(a) or not FactionDB.is_faction(b) or a == b:
		return
	var key := FactionDB.pair_key(a, b)
	var cur := int(faction_deltas.get(key, 0))
	var nxt := clampi(cur + amount, -FactionDB.DELTA_SPAN, FactionDB.DELTA_SPAN)
	if nxt == cur:
		return
	# Sparse by invariant: zero is absence, never a stored value.
	if nxt == 0:
		faction_deltas.erase(key)
	else:
		faction_deltas[key] = nxt
	faction_version += 1
	# The A10 line: politics the player changed and cannot see is not politics,
	# it is a haunting. One log line, only for shifts the player is party to —
	# third-party shifts get their line from the contract copy that caused them.
	# `quiet` is for callers that have ALREADY narrated the cause. A toll writes
	# "TOLL PAID — 400 IN CARGO" and a held muster writes "THE LINE HELD"; a
	# second entry stating the obvious consequence burns another of only ten
	# logbook slots on one moment, and LOGTEST's FIVE SITES WIRED went red
	# proving it. Finding A10 — politics you cannot see is a haunting — is
	# satisfied without the line now: stage 5 put a permanent STANDING row on
	# every dock sheet. Callers with no other record stay loud.
	if not quiet and (a == FactionDB.SURVEYOR or b == FactionDB.SURVEYOR):
		var other := b if a == FactionDB.SURVEYOR else a
		note_log("%s — STANDING %s" % [FactionDB.display_name(other),
			"RISES" if amount > 0 else "FALLS"])
	# The on-screen channel, for every mover regardless of `quiet`. The early
	# returns above mean a no-op never reaches here, and the SURVEYOR test means
	# a third-party shift never does either -- both are asserted.
	if a == FactionDB.SURVEYOR or b == FactionDB.SURVEYOR:
		var moved := b if a == FactionDB.SURVEYOR else a
		standing_shifted.emit(moved, amount,
			FactionDB.band_of(faction_attitude(FactionDB.SURVEYOR, moved)))
	_queue_save()


func _load_faction_deltas(saved: Variant) -> void:
	# Rebuilt entry by entry — the seams_cut/warehouse posture. A key must name
	# two real factions in canonical order, a value arrives clamped, and a zero
	# is dropped rather than stored so the sparse invariant survives a
	# hand-edited file. Anything else is rejected by name, not tolerated.
	faction_deltas = {}
	faction_version += 1
	if not (saved is Dictionary):
		return
	for k_v in (saved as Dictionary):
		var key := String(k_v)
		var parts := key.split("|")
		if parts.size() != 2:
			continue
		if not FactionDB.is_faction(parts[0]) or not FactionDB.is_faction(parts[1]):
			continue
		# A faction's relationship with ITSELF is a constant, not state. Rejected
		# explicitly because pair_key("gsa", "gsa") is legitimately "gsa|gsa", so
		# the canonical-ordering check below waves a self-pair straight through —
		# and a stored self-delta would be the one entry faction_attitude can
		# never read back, since it short-circuits on a == b.
		if parts[0] == parts[1]:
			continue
		if FactionDB.pair_key(parts[0], parts[1]) != key:
			continue  # non-canonical ordering: the same pair under a second name
		var val := clampi(int((saved as Dictionary)[k_v]),
			-FactionDB.DELTA_SPAN, FactionDB.DELTA_SPAN)
		if val != 0:
			faction_deltas[key] = val


func shake_enabled() -> bool:
	# Reduced motion subsumes shake: someone who asked for less movement is not
	# asking to keep the camera lurching. The reverse is not true.
	return bool(setting("shake")) and not reduce_motion()


# Actions a player may rebind. Deliberately not every action in the InputMap:
# `cancel` is the escape hatch out of every console and the pause menu, and a
# player who binds it to a key they cannot reach has no way back to the settings
# page that would let them fix it. It stays on Escape.
#
# `toggle_hold` IS IN THIS LIST AND HAS TO BE. The list drives two things that
# look unrelated: the settings rows, and rebind()'s conflict-stealing loop
# below. An action outside it is INVISIBLE to that loop, so a player could bind
# move_up to I and end up with two live actions on one key -- which is exactly
# what NO SHARED KEY forbids, arriving through the one door that assertion
# cannot see.
const REBINDABLE := ["move_up", "move_down", "move_left", "move_right",
	"ability", "cycle_target", "toggle_hold"]


func apply_bindings() -> void:
	# Rebuilt from the saved dict on every settings change and on load, so the
	# InputMap and the save can never disagree. An action missing from the dict
	# keeps whatever project.godot gave it.
	var saved: Dictionary = setting("bindings")
	if not (saved is Dictionary):
		return
	for action in REBINDABLE:
		if not saved.has(action) or not InputMap.has_action(action):
			continue
		var codes: Array = saved[action]
		if not (codes is Array) or codes.is_empty():
			continue
		InputMap.action_erase_events(action)
		for code in codes:
			var ev := InputEventKey.new()
			ev.physical_keycode = int(code)
			InputMap.action_add_event(action, ev)


func rebind(action: String, physical_keycode: int) -> bool:
	# One key per action, replacing whatever was there. Returns false rather than
	# silently doing nothing so the UI can say why.
	if not REBINDABLE.has(action) or physical_keycode == 0:
		return false
	# A key already spoken for is TAKEN AWAY from its old owner rather than
	# shared. Two actions on one key is not a binding, it is a bug the player
	# discovers mid-flight.
	var binds: Dictionary = (setting("bindings") as Dictionary).duplicate(true)
	for other in REBINDABLE:
		if other == action:
			continue
		if binds.has(other):
			var kept: Array = []
			for c in binds[other]:
				if int(c) != physical_keycode:
					kept.append(int(c))
			# Never leave an action with nothing bound: an unreachable action is
			# worse than a shared key, because there is no way to notice it until
			# the moment it is needed.
			if not kept.is_empty():
				binds[other] = kept
			else:
				return false
	binds[action] = [physical_keycode]
	set_setting("bindings", binds)
	return true


func reset_bindings() -> void:
	set_setting("bindings", {})
	# Erasing the overrides is not enough -- InputMap still holds whatever was
	# applied. load_from_project_settings puts every action back to project.godot.
	InputMap.load_from_project_settings()


func haptics_enabled() -> bool:
	return bool(setting("haptics"))


func reduce_motion() -> bool:
	return bool(setting("reduce_motion"))


# --- v6 livery --------------------------------------------------------------

func livery_index(part: String) -> int:
	return int(livery.get(part, DEFAULT_LIVERY.get(part, 0)))


func set_livery(hull: int, accent: int) -> void:
	livery["hull"] = hull
	livery["accent"] = accent
	_queue_save()
	# The hull is rebuilt from the fit, so re-emitting is what repaints the ship.
	fit_changed.emit(stats)


func reset_to_starter() -> void:
	# DIVERSIONS DIE WITH THE RUN, and missing this made "not saved" a false
	# comfort. `diverts` is only ever emptied by docking, so ABANDON TO TITLE
	# followed by NEW SURVEY carried a burned-out mount into a brand-new ship:
	# this function ends in _recompute(), which folds the stale dictionary
	# straight back in, and the new pilot flies at half DPS with no way to see
	# why -- the damage panel refuses to open during the tutorial.
	diverts = {}
	salvage = 0
	owned = []
	for id in ModuleDB.STARTER_OWNED:
		owned.append(id)
	fit = ModuleDB.STARTER_FIT.duplicate()
	reactor_tier = 0
	current_system = SystemDB.START_SYSTEM
	breached = []
	lanes_open = []
	# A NEW SURVEY is a new frontier. This is the one place the run's salt is
	# rolled, and it is rolled from the system clock rather than the seeded
	# global stream — every other roll in this game is deterministic by design,
	# and this is the single number that must not be.
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.randomize()
	run_seed = seed_rng.randi()
	contract_state = {}
	barks_seen = []
	apex_killed = []
	apex_down = []
	cargo = {}
	played_seconds = 0.0
	docked_at = ""
	market_pressure = {}
	market_events = []
	archeology = 0
	archeology_xp = 0
	smuggling = 0
	smuggling_xp = 0
	mining = 0
	mining_xp = 0
	persuasion = 0
	persuasion_xp = 0
	seams_cut = {}
	apex_intel = {}
	beacons = {}
	colonies = {}
	last_colony_jump = -1.0e9
	intel_version += 1
	# A new survey is a new political slate: the deltas are RUN STATE, cleared
	# with the ledger. The baseline needs no reset — it is a const table.
	faction_deltas = {}
	faction_version += 1
	warehouse = {}
	# A new survey is a new logbook. ship_name is deliberately NOT reset — see the
	# field comment: what you called your ship outlives the run that named it.
	ledger = DEFAULT_LEDGER.duplicate()
	captains_log = []
	# Run state, cleared with the ledger it reads from. `commissioned` is NOT
	# cleared: it is the one thing here that outlives the run, same as the paint
	# and the ship's name.
	commission_claimed = 0
	tutorial_step = 0          # a fresh survey starts at step one
	# audio_muted is a device preference, not run state: deliberately preserved
	# across a new game.
	# Derived stats must be rebuilt here, not left to the next equip: starting a
	# new game from a save with (say) a Cargo Bay fitted otherwise kept the old
	# hold size and the old hull mesh until the player happened to refit, because
	# nothing else emits fit_changed.
	_recompute()


# --- travel & progression ---------------------------------------------------

func set_current_system(id: String) -> void:
	if current_system == id:
		return
	current_system = id
	_queue_save()


func is_system_charted(id: String) -> bool:
	# On the map and named. Breaching the previous system's derelict does this,
	# exactly as it always has — the tutorial's finale still opens the world.
	var req := String(SystemDB.get_system(id).get("unlocked_by", ""))
	return req == "" or breached.has(req)


func is_lane_open(id: String) -> bool:
	# Flyable. Requires the previous system's engine to be dead.
	var req := String(SystemDB.get_system(id).get("unlocked_by", ""))
	return req == "" or lanes_open.has(req)


func is_system_unlocked(id: String) -> bool:
	# Kept as the TRAVEL question, which is what every caller of the old name
	# actually meant, so a missed call site fails closed (refuses a lane) rather
	# than open (grants one). New code should say which tier it means.
	return is_lane_open(id)


func mark_breached(id: String) -> Array[String]:
	# Returns systems this breach newly charted, so callers can announce them.
	if breached.has(id):
		return []
	breached.append(id)
	var newly: Array[String] = []
	for other in SystemDB.ids():
		if String(SystemDB.get_system(other).get("unlocked_by", "")) == id:
			newly.append(other)
			system_unlocked.emit(other)
	_queue_save()
	return newly


# --- cargo hold -------------------------------------------------------------

func cargo_capacity() -> int:
	return int(stats.get("cargo_space", ModuleDB.BASE.get("cargo_space", 24)))


func cargo_used() -> int:
	var used := 0
	for good in cargo:
		used += int(cargo[good]) * CommodityDB.space_of(String(good))
	return used


func cargo_free() -> int:
	return maxi(0, cargo_capacity() - cargo_used())


func cargo_count(good: String) -> int:
	return int(cargo.get(good, 0))


func cargo_over() -> int:
	# How much is aboard BEYOND capacity. cargo_free() clamps at zero and so
	# cannot express this state at all, and cargo_overflow() answers a different
	# question -- what a PROSPECTIVE swap would leave over -- and needs a slot to
	# do it. A screen that is not a fitting screen has no slot to give it.
	return maxi(0, cargo_used() - cargo_capacity())


func hold_value(weighted := false) -> int:
	# Base-price valuation of the hold. `weighted` applies each good's
	# interdiction weight, which is what the raider roll reads: a hold of
	# contraband is worth stopping for three times as badly as its sticker price.
	var total := 0.0
	for good in cargo:
		var id := String(good)
		var v := float(CommodityDB.base_price(id)) * float(cargo[good])
		total += v * (CommodityDB.interdiction_weight(id) if weighted else 1.0)
	return int(total)


func can_load(good: String, units: int) -> bool:
	return cargo_free() >= CommodityDB.space_of(good) * units


func load_cargo(good: String, units: int) -> int:
	# Loads as many units as fit and returns how many were actually taken, so
	# callers can decide what to do with the remainder rather than silently
	# dropping it.
	if units <= 0 or not CommodityDB.exists(good):
		return 0
	var per := maxi(1, CommodityDB.space_of(good))
	var room := cargo_free() / per
	var taken := mini(units, room)
	if taken > 0:
		cargo[good] = cargo_count(good) + taken
		_queue_save()
		cargo_changed.emit()
	return taken


func unload_cargo(good: String, units: int) -> int:
	# Returns how many were actually removed.
	var have := cargo_count(good)
	var removed := mini(units, have)
	if removed <= 0:
		return 0
	if have - removed <= 0:
		cargo.erase(good)
	else:
		cargo[good] = have - removed
	_queue_save()
	cargo_changed.emit()
	return removed


func has_save() -> bool:
	return FileAccess.file_exists(save_path)


func set_tutorial_step(step: int) -> void:
	if tutorial_step == step:
		return
	tutorial_step = step
	_queue_save()


func set_audio_muted(v: bool) -> void:
	audio_muted = v
	Sfx.set_muted(v)
	_queue_save()


func advance_clock(delta: float) -> void:
	played_seconds += delta


func set_docked(port_id: String) -> void:
	if docked_at == port_id:
		return
	docked_at = port_id
	_queue_save()


func has_killed_apex(id: String) -> bool:
	return apex_killed.has(id)


func open_lane(id: String) -> Array[String]:
	# The engine has stopped transmitting. Returns the lanes this newly opened,
	# the same shape mark_breached returns for charting — the two are halves of
	# one progression and should read alike.
	#
	# DELIBERATELY SEPARATE from mark_apex_killed, and the separation is
	# load-bearing rather than tidiness. The lane opens when the engine DIES;
	# the first-kill bonus is paid when its WRECK IS BREACHED, which is a second
	# trip the player may not survive. Folding them together would mean the
	# bonus guard (`has_killed_apex`) was already true by the time the wreck was
	# cracked, and the bonus would never pay at all.
	#
	# It also opens on a repeat kill whose bonus is long spent: a player who has
	# put the engine down twice should never be held behind that door.
	var newly: Array[String] = []
	if lanes_open.has(id):
		return newly
	lanes_open.append(id)
	for other in SystemDB.ids():
		if String(SystemDB.get_system(other).get("unlocked_by", "")) == id:
			newly.append(other)
			lane_opened.emit(other)
	_queue_save()
	return newly


func mark_apex_killed(id: String) -> void:
	# Records that this system's first-kill bonus has been collected. The LANE is
	# open_lane's business — see the note there.
	if apex_killed.has(id):
		return
	apex_killed.append(id)
	# The hunt is over, so the dossier goes with it. Kept here rather than in
	# open_lane because the intel is about the ENGINE, not about the lane. Since
	# v17 mark_apex_down is the earlier and more literal "the engine is dead", and
	# it clears the dossier too — by the time the wreck is cracked there is
	# normally nothing left to clear. This stays as the backstop for the one order
	# that skips it: a save grandfathered from v16, where the kill was inferred.
	clear_apex_intel(id)
	_queue_save()


func has_apex_down(id: String) -> bool:
	return apex_down.has(id)


func mark_apex_down(id: String) -> void:
	# The engine is DESTROYED, and unlike its hit points that outlives the system
	# teardown: SystemBuilder asks this before it builds anything at the lair.
	#
	# Separate from mark_apex_killed on purpose — see apex_down's declaration. The
	# bonus is still owed at this point, and the wreck carrying it is rebuilt on
	# re-entry until somebody cracks it.
	if apex_down.has(id):
		return
	apex_down.append(id)
	# Nothing left to hunt, so the dossier goes now rather than at the wreck.
	clear_apex_intel(id)
	_queue_save()


func has_seen_bark(key: String) -> bool:
	return barks_seen.has(key)


func mark_bark(key: String) -> void:
	if barks_seen.has(key):
		return
	barks_seen.append(key)
	_queue_save()


func set_contract_state(state: Dictionary) -> void:
	contract_state = state
	_queue_save()


# --- salvage ---------------------------------------------------------------

func add_salvage(amount: int) -> void:
	salvage += amount
	salvage_changed.emit(salvage)
	_queue_save()


func spend_salvage(amount: int) -> bool:
	if salvage < amount:
		return false
	salvage -= amount
	salvage_changed.emit(salvage)
	_queue_save()
	return true


# --- fitting ---------------------------------------------------------------

func power_cap() -> int:
	return ModuleDB.reactor_power(reactor_tier)


func power_draw() -> int:
	return ModuleDB.power_draw(fit)


func owns(id: String) -> bool:
	return owned.has(id)


func cargo_after(slot: int, id: String) -> int:
	# Hold size the ship WOULD have with this swap applied.
	var probe := fit.duplicate()
	probe[slot] = id
	return int(ModuleDB.compute_stats(probe).get("cargo_space",
		ModuleDB.BASE.get("cargo_space", 24)))


func cargo_overflow(slot: int, id: String) -> int:
	# How much cargo would not fit. Zero means the swap is safe.
	return maxi(0, cargo_used() - cargo_after(slot, id))


func can_equip(slot: int, id: String) -> bool:
	if id == "":
		# Not a blanket allow any more: pulling a Cargo Bay out from under a
		# loaded hold used to leave cargo_used above cargo_capacity, which every
		# other system then had to tolerate as a silently invalid state. The
		# refit console offers to jettison down to the threshold instead.
		return cargo_overflow(slot, id) == 0
	if not ModuleDB.exists(id) or not owns(id):
		return false
	if ModuleDB.SLOT_CATEGORY.get(slot, "") != ModuleDB.get_module(id)["category"]:
		return false
	if cargo_overflow(slot, id) > 0:
		return false
	var probe := fit.duplicate()
	probe[slot] = id
	return ModuleDB.power_draw(probe) <= power_cap()


func _load_seams_cut(saved: Dictionary) -> void:
	# Validated against the GENERATOR, exactly as _load_warehouse validates bay
	# keys against the places that actually exist. A raw dictionary keyed by
	# strings the player never types is still a raw dictionary: a hand-edited save
	# — or an `asteroids` array that lost an entry between builds — must not leave
	# this holding a rock that is not there any more.
	seams_cut = {}
	for key_v in saved:
		var key := String(key_v)
		var bits := key.split(":")
		if bits.size() != 2:
			continue                       # 1. shape
		var sid := String(bits[0])
		if not SystemDB.exists(sid):
			continue                       # 2. the system must still exist.
			                               #    REDUNDANT today and kept anyway: the
			                               #    red pass showed filter 4 already
			                               #    rejects an unknown system, because
			                               #    get_system() returns {} and an empty
			                               #    asteroids array fails the bounds
			                               #    check. That is an implementation
			                               #    detail of SystemDB, not a promise,
			                               #    so the explicit test stays.
		if not String(bits[1]).is_valid_int():
			continue                       # 3. the index must be a number
		var idx := int(bits[1])
		var rocks: Array = SystemDB.get_system(sid).get("asteroids", [])
		if idx < 0 or idx >= rocks.size():
			continue                       # 4. and must still name a real rock
		if bool(saved[key_v]):
			seams_cut[key] = true          # 5. falsey values dropped, not kept


# --- waypoint beacons (v20, Hunt stage 5) ------------------------------------

const BEACON_STOCK := 8


func beacon_stock_left() -> int:
	# DERIVED. Eight minus every dropped entry across every system — the one
	# arithmetic, computed where it is asked, so a save edited by hand cannot
	# carry "stock: 9" beside eight standing beacons.
	var dropped := 0
	for sid_v in beacons:
		dropped += (beacons[sid_v] as Array).size()
	return BEACON_STOCK - dropped


func beacons_in(system_id: String) -> Array:
	return beacons.get(system_id, [])


func drop_beacon(system_id: String, x: float, z: float, depth: float) -> bool:
	# THE RULE LIVES HERE, not in the button that calls it — §59's lesson about
	# rules that live in a disabled flag. Depth is an ARGUMENT for the same
	# reason integrity is one in divert_power: GameState cannot read the world,
	# and a rule it cannot be handed is a rule it cannot enforce.
	#
	# Refused inside the chart because the chart already remembers every place
	# in it — a beacon there would be a second bookmark on a page that has one.
	if depth <= 0.0:
		return false
	if beacon_stock_left() <= 0:
		return false
	if not SystemDB.exists(system_id):
		return false
	var row: Array = beacons.get(system_id, [])
	row.append({"x": x, "z": z})
	beacons[system_id] = row
	note_log("BEACON DROPPED — %d IN STOCK" % beacon_stock_left())
	_queue_save()
	return true


func recover_beacon(system_id: String, x: float, z: float) -> bool:
	# Keyed by POSITION, never by index: an index held on a live node goes stale
	# the moment a sibling is recovered first, and a position cannot. 0.5u of
	# tolerance is generous against float drift and far under the 34u any two
	# beacons the drop verb places can plausibly sit apart.
	var row: Array = beacons.get(system_id, [])
	for i in range(row.size()):
		var e: Dictionary = row[i]
		if absf(float(e["x"]) - x) < 0.5 and absf(float(e["z"]) - z) < 0.5:
			row.remove_at(i)
			if row.is_empty():
				beacons.erase(system_id)   # sparse, the faction-delta rule
			else:
				beacons[system_id] = row
			_queue_save()
			return true
	return false


func _load_beacons(saved: Dictionary) -> void:
	# Entry-by-entry validation, the apex_intel loader's shape: a file is input,
	# not truth. Unknown systems are dropped, malformed entries are dropped,
	# non-finite coordinates are dropped, and anything past BEACON_STOCK in
	# total is dropped — in file order, so which eight survive a corrupt file is
	# deterministic rather than dictionary-order luck.
	beacons = {}
	var kept := 0
	for sid_v in saved:
		var sid := String(sid_v)
		if not SystemDB.exists(sid):
			continue
		if not (saved[sid_v] is Array):
			continue
		var row: Array = []
		for e_v in saved[sid_v]:
			if kept >= BEACON_STOCK:
				break
			if not (e_v is Dictionary):
				continue
			var e: Dictionary = e_v
			if not e.has("x") or not e.has("z"):
				continue
			var ex := float(e["x"])
			var ez := float(e["z"])
			if not (is_finite(ex) and is_finite(ez)):
				continue
			row.append({"x": ex, "z": ez})
			kept += 1
		if not row.is_empty():
			beacons[sid] = row


# --- colonies (v20, Hunt stage 6) --------------------------------------------

func colony_key(system_id: String, index: int) -> String:
	return "%s:%d" % [system_id, index]


func is_colony_claimed(key: String) -> bool:
	return colonies.has(key)


func claim_colony(key: String, x: float, z: float) -> bool:
	if colonies.has(key):
		return false
	colonies[key] = {"x": x, "z": z, "founded_at": played_seconds}
	note_log("COLONY FOUNDED — %s" % key)
	_queue_save()
	return true


func colonies_in(system_id: String) -> Array:
	# [{key, x, z}] for one system, in key order so a UI built from it is
	# stable between frames.
	var out: Array = []
	var prefix := system_id + ":"
	var keys: Array = colonies.keys()
	keys.sort()
	for k_v in keys:
		var k := String(k_v)
		if not k.begins_with(prefix):
			continue
		var e: Dictionary = colonies[k]
		out.append({"key": k, "x": float(e["x"]), "z": float(e["z"])})
	return out


func _load_colonies(saved: Dictionary) -> void:
	# A file is input, not truth. Key shape, system existence, a non-negative
	# index and finite coordinates — each checked, each failure dropping only
	# its own entry.
	#
	# THERE IS DELIBERATELY NO "DOES THIS AGREE WITH run_seed" FILTER. The
	# stored position IS the colony; recomputing hyper_positions and discarding
	# disagreements would delete a founded colony the day the depth band was
	# retuned. _load_apex_intel makes the same choice for the same reason.
	colonies = {}
	for k_v in saved:
		var k := String(k_v)
		var parts := k.split(":")
		if parts.size() != 2:
			continue
		if not SystemDB.exists(String(parts[0])):
			continue
		if not String(parts[1]).is_valid_int() or int(String(parts[1])) < 0:
			continue
		if not (saved[k_v] is Dictionary):
			continue
		var e: Dictionary = saved[k_v]
		if not e.has("x") or not e.has("z"):
			continue
		var ex := float(e["x"])
		var ez := float(e["z"])
		if not (is_finite(ex) and is_finite(ez)):
			continue
		colonies[k] = {"x": ex, "z": ez,
			"founded_at": float(e.get("founded_at", 0.0))}


func _load_apex_intel(saved: Dictionary) -> void:
	# Validated the way _load_seams_cut is, and for a sharper reason: every value
	# here is a NUMBER THE RENDERER TRUSTS. A bearing of NaN or an error of -40
	# does not fail loudly — it silently poisons the estimate, and the survey
	# plot draws a confident cone pointing at nothing.
	#
	# There is deliberately no filter for "does this hint agree with the current
	# run_seed's lair". Contradiction is a legal state of a dossier: a stale
	# rumour and a fresh mast reading disagreeing is the mechanic working, and a
	# loader that quietly discarded the losing hint would be answering the hunt.
	apex_intel = {}
	for sid_v in saved:
		var sid := String(sid_v)
		if not SystemDB.exists(sid):
			continue                       # 1. the system must still exist
		if not (saved[sid_v] is Array):
			continue                       # 2. shape
		var kept: Array = []
		for h_v in (saved[sid_v] as Array):
			if not (h_v is Dictionary):
				continue                   # 3. every entry is a hint dict
			var h: Dictionary = h_v
			var kind := String(h.get("kind", ""))
			if kind == "":
				continue                   # 4. an unattributed hint is unplottable
			if kind == "ring":
				var band := int(h.get("band", -1))
				if band < 0 or band >= DeepSpace.BAND_NAMES.size():
					continue               # 5. must name a band that exists
				if not DeepSpace.QUADRANTS.has(String(h.get("quadrant", ""))):
					continue               # 6. and a real compass sector
				kept.append({"kind": "ring", "band": band,
					"quadrant": String(h.get("quadrant", ""))})
				continue
			# Bearing hints: every number finite, the error a sane half-angle.
			var ox := float(h.get("ox", 0.0))
			var oz := float(h.get("oz", 0.0))
			var bearing := float(h.get("bearing", 0.0))
			var err := float(h.get("err", 0.0))
			if not (is_finite(ox) and is_finite(oz) and is_finite(bearing) and is_finite(err)):
				continue                   # 7. NaN/inf poisons the estimate silently
			if err <= 0.0 or err > 90.0:
				continue                   # 8. a cone with no width, or wider than
				                           #    the rumour that costs a tenth as much
			kept.append({"kind": kind, "ox": ox, "oz": oz,
				"bearing": fposmod(bearing, 360.0), "err": err})
		# 9. Trim to the cap on the way in as well as on the way out: a
		#    hand-edited save must not hand anyone a nine-cone dossier.
		while kept.size() > HINT_CAP:
			var widest := 0
			for i in range(kept.size()):
				if hint_error(kept[i]) > hint_error(kept[widest]):
					widest = i
			kept.remove_at(widest)
		if not kept.is_empty():
			apex_intel[sid] = kept         # 10. empty arrays dropped, not kept
	intel_version += 1


# --- bonded stores ----------------------------------------------------------

func _load_warehouse(saved: Dictionary) -> void:
	# Four filters, every one with precedent above. A raw dictionary is the one
	# save field that arrives with no structure guaranteeing itself, so it gets
	# validated rather than trusted.
	warehouse = {}
	for key_v in saved:
		var key := String(key_v)
		if not _bay_key_is_real(key):
			continue           # 1. the place must exist, and for a deep bay that
			                   #    means the generator must still put a station
			                   #    with a bay in that cell
		var bay := {}
		var contents: Dictionary = saved[key_v]
		for good_v in contents:
			var good := String(good_v)
			if not CommodityDB.exists(good):
				continue       # 2. same filter cargo gets
			if not can_store(good):
				continue       # 3. the bonded rule holds on LOAD too, not only on
				               #    deposit — a good that stops being no_retail in
				               #    some later build must not leave illegal stock
				               #    sitting in bays
			var n := int(contents[good_v])
			if n > 0:
				bay[good] = n  # 4. non-positive counts dropped, not kept at zero
		if not bay.is_empty():
			warehouse[key] = bay
	# Over-capacity bays shed cheapest-first, so a reload is idempotent. Same
	# posture as a fit over its power budget falling back to STARTER_FIT: 16
	# refuses an invalid state rather than tolerating it.
	for key in warehouse.keys():
		for g_v in _stashable_order():
			var g := String(g_v)
			while warehouse_used(String(key)) > WAREHOUSE_SPACE \
					and warehouse_count(String(key), g) > 0:
				var bay2: Dictionary = warehouse[key]
				bay2[g] = int(bay2[g]) - 1
				if int(bay2[g]) <= 0:
					bay2.erase(g)
				warehouse[key] = bay2


func _bay_key_is_real(key: String) -> bool:
	# A chart bay is a port id that declares storage. A deep bay is a cell, and
	# it is checked by RE-DERIVING it: ask the generator what is in that cell and
	# keep the key only if the answer is a station with a bay.
	#
	# This is only possible because the expanse is a pure function (17). A save
	# that has been edited, or written by a build with different station odds,
	# self-corrects instead of carrying phantom bays forever.
	if not key.contains(":"):
		var pdef := SystemDB.port_def_by_id(key)
		return not pdef.is_empty() and port_has_bay(pdef)
	var parts := key.split(":")
	if parts.size() != 3:
		return false
	if not SystemDB.exists(parts[0]):
		return false
	if not parts[1].lstrip("-").is_valid_int() or not parts[2].lstrip("-").is_valid_int():
		return false
	# The live DeepSpace, because re-derivation needs the system that is loaded.
	# A key for a system other than the current one cannot be checked, so it is
	# KEPT — dropping it would silently delete a bay in PYX-02 every time the
	# player saved while standing in PYX-01.
	var main := get_tree().get_first_node_in_group("main") if is_inside_tree() else null
	if main == null or main.deep_space == null:
		return true
	if String(parts[0]) != String(main.system_id):
		return true
	return main.deep_space.cell_has_bay(String(parts[0]), int(parts[1]), int(parts[2]))


func can_store(good: String) -> bool:
	# THE BONDED RULE, and it is one line on purpose.
	#
	# A bay accepts only what the game will never sell you. That closes a money
	# printer no shipped assertion can see: market events last 240-360s, so with
	# an open bay you buy alloys under a 0.55x glut, put them down, wait for the
	# event to lapse, and sell at the SAME counter for 1.61x — no travel, no raid
	# exposure, and the Cantina's rumour tab sells you the event locations.
	# NO ROUND-TRIP PROFIT cannot catch it: it prices both legs in one loop
	# iteration, at one instant, under one market_events array.
	#
	# Closed at the source rather than by capping anything, which is 11's own
	# fix pattern ("a fence buys and does not sell"). No buy leg exists for a
	# no_retail good at any counter, so there is no round trip left to price.
	#
	# It also earns its keep as design rather than as a guard: at Archeology 2 a
	# hold of Reaches and Quiet Salvage is unreadable everywhere and is dead
	# weight. A bay is where you put it down and come back for it at tier 3.
	return CommodityDB.no_retail(good)


func port_has_bay(port_def: Dictionary) -> bool:
	return (port_def.get("services", []) as Array).has("storage")


func warehouse_of(key: String) -> Dictionary:
	return warehouse.get(key, {})


func warehouse_used(key: String) -> int:
	# Measured in SPACE, like the hold, so a bay and a hold are the same currency.
	var used := 0
	for good in warehouse_of(key):
		used += int(warehouse_of(key)[good]) * CommodityDB.space_of(String(good))
	return used


func warehouse_free(key: String) -> int:
	return maxi(0, WAREHOUSE_SPACE - warehouse_used(key))


func warehouse_count(key: String, good: String) -> int:
	return int(warehouse_of(key).get(good, 0))


func store_cargo(key: String, good: String, units: int) -> int:
	# Returns how many units actually moved, like load_cargo.
	if key == "" or units <= 0 or not can_store(good):
		return 0
	var held := cargo_count(good)
	if held <= 0:
		return 0
	var per := maxi(1, CommodityDB.space_of(good))
	var room := warehouse_free(key) / per
	var moved := mini(mini(units, held), room)
	if moved <= 0:
		return 0
	# Out of the hold FIRST, so a failure can never duplicate cargo.
	unload_cargo(good, moved)
	var bay: Dictionary = warehouse.get(key, {})
	bay[good] = int(bay.get(good, 0)) + moved
	warehouse[key] = bay
	_queue_save()
	return moved


func withdraw_cargo(key: String, good: String, units: int) -> int:
	if key == "" or units <= 0:
		return 0
	var stored := warehouse_count(key, good)
	if stored <= 0:
		return 0
	var want := mini(units, stored)
	# load_cargo reports what it actually took; only remove that much from the
	# bay. Nothing may vanish — the same discipline identify() carries.
	var taken := load_cargo(good, want)
	if taken <= 0:
		return 0
	var bay: Dictionary = warehouse[key]
	bay[good] = stored - taken
	if int(bay[good]) <= 0:
		bay.erase(good)
	if bay.is_empty():
		warehouse.erase(key)
	else:
		warehouse[key] = bay
	_queue_save()
	return taken


func _stashable_order() -> Array:
	# Cheapest-first, and for a DIFFERENT reason than jettison_to_fit's.
	#
	# Jettison dumps the cheapest because the player should lose the least. A
	# stash loses nothing, so that argument does not apply and reusing that
	# function would leave a comment that lies. The reason here is that what
	# stays in the hold is what you fly away with — and what you fly away with is
	# what you sell and what draws raiders. So the dense valuable cargo stays
	# aboard deliberately.
	var goods := CommodityDB.ids().filter(func(g) -> bool: return can_store(String(g)))
	goods.sort_custom(func(a, b) -> bool:
		return CommodityDB.base_price(String(a)) < CommodityDB.base_price(String(b)))
	return goods


func stash_would_fit(slot: int, id: String, key: String) -> bool:
	# Can the bay absorb the WHOLE overflow? Asked before anything moves.
	var over := cargo_overflow(slot, id)
	if over <= 0:
		return true
	var room := warehouse_free(key)
	var freed := 0
	for g_v in _stashable_order():
		var g := String(g_v)
		var per := maxi(1, CommodityDB.space_of(g))
		var movable := mini(cargo_count(g), room / per) if per > 0 else 0
		freed += movable * per
		room -= movable * per
		if freed >= over:
			return true
	return false


func stash_to_fit(slot: int, id: String, key: String) -> int:
	# ALL OR NOTHING. A stash that half-fills the bay, still fails the equip and
	# leaves the player over-full with a partly-emptied hold is the worst failure
	# available here — it is READ REFUSED's lesson exactly: nothing may be
	# consumed by an operation that does not complete.
	if not stash_would_fit(slot, id, key):
		return 0
	var moved := 0
	for g_v in _stashable_order():
		var g := String(g_v)
		while cargo_overflow(slot, id) > 0 and cargo_count(g) > 0:
			if store_cargo(key, g, 1) <= 0:
				break
			moved += 1
	return moved


func stash_would_fit_now(key: String) -> bool:
	# The slot-free twin of stash_would_fit, for a console that has no fitting
	# slot to name. The originals take a PROSPECTIVE swap (slot, id) and ask what
	# it would leave over; here the hold is ALREADY over capacity and the
	# question is only whether the bay can take the difference. Passing an
	# arbitrary slot to get at the same answer would be a lie in the code even
	# where the arithmetic happened to come out right.
	var over := cargo_over()
	if over <= 0:
		return true
	var room := warehouse_free(key)
	var freed := 0
	for g_v in _stashable_order():
		var g := String(g_v)
		var per := maxi(1, CommodityDB.space_of(g))
		var movable := mini(cargo_count(g), room / per) if per > 0 else 0
		freed += movable * per
		room -= movable * per
		if freed >= over:
			return true
	return freed >= over


func stash_to_fit_now(key: String) -> int:
	# ALL OR NOTHING, exactly as stash_to_fit is. A stash that half-fills the bay
	# and leaves the player still over-full with a partly-emptied hold is the
	# worst outcome available here.
	if not stash_would_fit_now(key):
		return 0
	var moved := 0
	for g_v in _stashable_order():
		var g := String(g_v)
		while cargo_over() > 0 and cargo_count(g) > 0:
			if store_cargo(key, g, 1) <= 0:
				break
			moved += 1
	return moved


# --- reading salvage --------------------------------------------------------
# ARCHEOLOGY. One skill, three tiers past the start, and it gates INFORMATION
# rather than power — which is what keeps it out of 9's "linear upgrade
# ladder" objection. A higher tier does not make you stronger; it makes a thing
# you were already carrying legible.
#
# One rule covers where you can read:
#
#     in the field   band <= archeology
#     at a lab       band <= archeology + 1
#
# so the lab is always exactly one band ahead of you. There is always a reason to
# carry something home, and always a reason to raise the skill, at every tier.
# v20 THE FRONTIER: two more rungs, because the frontier's salvage grades are
# band 5 and band 6 and the rule above is `band <= archeology (+1 at a lab)`.
# Without them Fathom Salvage is unreadable forever by anybody and the deepest
# loot in the game is a crate you can only sell.
#
# 108 AND 140 ARE A BUDGET, NOT A CURVE. The first draft read 150 and 260,
# extrapolating the ~1.9x/2.3x ratios above, and TIERS caught it: a standard loop
# cracks one hull and reads a hold, which is ARCHEOLOGY_PER_BREACH 4 + 8 reads =
# 12 xp, so a 260 cap is 21.7 loops against a stated ceiling of 12. The rule that
# ceiling protects is "a tier needing fifteen derelicts is content you can see
# and never use" — and the failure it describes is exactly the one these two
# rungs exist to PREVENT, so shipping them out of reach would have made the
# deepest loot in the game a crate you can only sell for hours of play.
#
# So the cap is 144 (12 loops) and the ladder finishes at 140 = 11.7. The
# increments dip from +44 to +30/+32 as a consequence; that is what a fixed
# budget spent over six rungs instead of four looks like, and it is preferable to
# a curve nobody can climb. Raising ARCHEOLOGY_PER_READ to fit was considered and
# refused: it pulls tiers 1-3 in as well and brings forward reading the Quiet's
# salvage, which is an income change against a loop at 97% of its ceiling.
#
# THE UNSOUNDED STAYS LAB-ONLY FOREVER, which is not an oversight: tier 5 is the
# last rung, so band 6 is only ever readable at `archeology + 1`. That is exactly
# the note band 4 used to end on, moved outward — there is still always a reason
# to carry something home.
const ARCHEOLOGY_TIERS := [0, 12, 34, 78, 108, 140]
const ARCHEOLOGY_PER_READ := 1
const ARCHEOLOGY_PER_BREACH := 4

# Set by identify(): true when THAT read crossed a tier threshold. Session-only —
# it is a notification, not state.
var last_read_tiered := false


const SMUGGLING_TIERS := [0, 14, 38, 84]
# What the lanes do for you, tier by tier. NOT credits, and that exclusion is the
# design: a toll discount is a stat denominated in salvage, and a fence premium
# would move _pacing_trade_yield's best legal route and drag the pacing band with
# it. These buy TIME, a CHOICE, and ACCESS — 19's "gates how the world treats
# you, never what your ship can do".
const SMUGGLING_STANDOFF_BONUS := 3.0   # t1: three more seconds to read a demand
const SMUGGLING_BLUFF_TIER := 2         # t2: the bluff button appears
const SMUGGLING_BLUFF_BASE := 0.40      # printed on the button, never hidden
const SMUGGLING_BLUFF_PER_TIER := 0.10
const SMUGGLING_ACCESS_TIER := 3        # t3: deep fences deal in more of it
# Which goods pay. Deliberately a small explicit set rather than "anything a
# fence takes": components are fenced too, and letting them count would level
# smuggling off the same salvage run that levels archeology.
const SMUGGLING_GOODS := ["contraband", "stolen"]


func smuggling_next_at() -> int:
	var next := smuggling + 1
	return SMUGGLING_TIERS[next] if next < SMUGGLING_TIERS.size() else -1


func mark_smuggling(units: int) -> bool:
	if units <= 0 or smuggling >= SMUGGLING_TIERS.size() - 1:
		return false
	smuggling_xp += units
	var gained := false
	while smuggling < SMUGGLING_TIERS.size() - 1 \
			and smuggling_xp >= SMUGGLING_TIERS[smuggling + 1]:
		smuggling += 1
		gained = true
	# ONE line naming the tier the player LANDED on, not one per tier crossed.
	# The loop can cross two at once on a big sale, and the toast the player
	# actually saw announces only the final tier — a log that disagreed with the
	# announcement would be a log describing a different evening.
	if gained:
		note_log("SMUGGLING %d — THE LANES KNOW YOU" % smuggling)
	_queue_save()
	return gained


# --- PERSUASION (v19) --------------------------------------------------------
# Counted in PARLEYS TALKED DOWN, not in units of anything — which is why the
# numbers are small next to the other three ladders. A raid needs RAID_MIN_HOLD
# aboard and clears a cooldown before it can roll at all, so nine successes is a
# long acquaintance with the Tithe rather than an afternoon.
const PERSUASION_TIERS := [0, 2, 5, 9]
# WHAT A TIER BUYS: better odds on the same conversation, and nothing else. Never
# credits and never a cheaper toll — a toll discount is a stat denominated in
# salvage, which is the exclusion SMUGGLING_TIERS states above and the reason
# NO PRICE TIERS exists.
#
# THE BASE IS NON-ZERO AT TIER 0, deliberately, and it is also the fix for what
# the playtest actually hit. bluff_odds returned 0.0 below smuggling 2, and the
# plate was gated a second time on holding a Forged Manifest, so a new pilot met
# a demand that named three answers with one button on the screen. Everybody can
# try talking; being good at it is what is earned.
const PERSUASION_BLUFF_BASE := 0.15
const PERSUASION_BLUFF_PER_TIER := 0.10
# What a failed talk-down costs the Tithe's opinion of you. The mirror of the +1
# pay_toll books, and the stake without which this would be a free roll.
const PERSUASION_FAILURE_COST := -1
# Both ladders can raise the same plate, so their sum needs a ceiling. 0.80 keeps
# the top of the game an honest bet rather than a formality — 12's standard is an
# honest bad bet you can SEE, and a 100% "gamble" is a button, not a wager.
const BLUFF_ODDS_CAP := 0.80


func persuasion_next_at() -> int:
	var next := persuasion + 1
	return PERSUASION_TIERS[next] if next < PERSUASION_TIERS.size() else -1


func mark_persuasion(wins: int) -> bool:
	if wins <= 0 or persuasion >= PERSUASION_TIERS.size() - 1:
		return false
	persuasion_xp += wins
	var gained := false
	while persuasion < PERSUASION_TIERS.size() - 1 \
			and persuasion_xp >= PERSUASION_TIERS[persuasion + 1]:
		persuasion += 1
		gained = true
	# ONE line naming the tier the player LANDED on, like the other three.
	if gained:
		note_log("PERSUASION %d — THEY LISTEN TO YOU" % persuasion)
	_queue_save()
	return gained


func persuasion_line() -> String:
	var next_at := persuasion_next_at()
	var tail := ("%d TO NEXT" % (next_at - persuasion_xp)) if next_at >= 0 \
		else "NOTHING LEFT TO LEARN"
	if persuasion < 1:
		return "PERSUASION 0 — TALK A RAIDER PACK DOWN INSTEAD OF PAYING · %d%% · %s" % [
			int(persuasion_odds() * 100.0), tail]
	return "PERSUASION %d — TALK A PACK DOWN · %d%% · %s" % [
		persuasion, int(persuasion_odds() * 100.0), tail]


func persuasion_odds() -> float:
	return PERSUASION_BLUFF_BASE + PERSUASION_BLUFF_PER_TIER * float(persuasion)


func manifest_odds() -> float:
	# SMUGGLING's half, unchanged in value and now named for what it is. It was
	# always the social mechanic in this game in everything but title; what moved
	# is only that it is no longer the ONLY way to raise the plate.
	if smuggling < SMUGGLING_BLUFF_TIER:
		return 0.0
	return SMUGGLING_BLUFF_BASE + SMUGGLING_BLUFF_PER_TIER \
		* float(smuggling - SMUGGLING_BLUFF_TIER)


func bluff_odds() -> float:
	# TWO LADDERS, SUMMED, CAPPED. A pilot who has never talked to anybody but
	# carries a manifest at smuggling 2 reads exactly 40% — the number that
	# shipped — so nothing is taken away from a save that already earned it. The
	# manifest half is only counted when the manifest is actually aboard, because
	# it is the stake being wagered rather than a stat.
	var odds := persuasion_odds()
	if hold_has("manifest_forged"):
		odds += manifest_odds()
	return minf(odds, BLUFF_ODDS_CAP)


func smuggling_line() -> String:
	var next_at := smuggling_next_at()
	var tail := ("%d TO NEXT" % (next_at - smuggling_xp)) if next_at >= 0 \
		else "NOTHING LEFT TO LEARN"
	# TIER 0 NAMES THE VERB AND THE DESK, per §58's copy rule. "THE LANES DO NOT
	# KNOW YOU YET" states an absence, and this ladder needs the opposite more
	# than any other: XP comes ONLY from a FENCE sale (Market.fences), and in
	# charted space exactly two counters qualify. THE GRINNING VOID is the trap —
	# it sells contraband, calls itself the smuggler's den and has a fence tab,
	# but contraband is absent from its fence_goods, so selling it back there
	# completes, pays credits, and moves the ladder by nothing. A playtester
	# reached 68 minutes at smuggling 0 while carrying stolen goods.
	var perk := "FENCE CONTRABAND OR STOLEN — THE CANTINA TAKES BOTH"
	if smuggling >= SMUGGLING_ACCESS_TIER:
		perk = "DEEP FENCES DEAL IN ANYTHING YOU CARRY"
	elif smuggling >= SMUGGLING_BLUFF_TIER:
		# NAMES ITS OWN CONTRIBUTION, not the total. Since v19 two ladders raise
		# the bluff plate, and printing the sum here would have SMUGGLING taking
		# credit for what PERSUASION earned — the A10 complaint (a number moved
		# and nothing said which of the last ten seconds moved it) reproduced in
		# a skill readout.
		perk = "A FORGED MANIFEST BUYS YOU +%d%% ON A BLUFF" % int(manifest_odds() * 100.0)
	elif smuggling >= 1:
		perk = "THE LANES WARN YOU EARLY"
	return "SMUGGLING %d — %s · %s" % [smuggling, perk, tail]


# v14. MINING. Tops out higher than the other two ladders (78 and 84), and that
# is not an inconsistency: the three are earned in DIFFERENT UNITS, so comparing
# their top values is a category error. What matters is sessions-to-max, and the
# weighting is what sets it — a seam pays XP equal to its BAND, so 110 is about
# fourteen sessions of working the Shoals and three and a half of working the
# Quiet. The shallow grind being genuinely slow is the same anti-farm gradient
# the ore prices encode, said again in the skill.
const MINING_TIERS := [0, 18, 50, 110]
# What the tiers buy: INFORMATION, a CHOICE, and ACCESS. Never credits, never a
# yield — util_assay already owns the yield axis, and a tier that paid would put
# a second earner under a loop already at 97% of its ceiling. TIERS BUY NO
# CREDITS asserts it rather than trusting the comment.
const MINING_READ_TIER := 1     # t1: the radar marker takes the ore's colour
# ACCESS BEFORE CONVENIENCE, and these two were the other way round until the
# playtest. MINING_DEEP_TIER was 3 — which is MINING_TIERS' MAX index — so
# band-4 access, the only 4-XP rung on the board, unlocked exactly when there was
# nothing left to earn with it. The perk bought nothing, and the tuning note
# above (which prices the whole ladder as "three and a half sessions of working
# the Quiet") described a rate no live ladder could ever reach: the constant and
# the comment contradicted each other, and the comment was the honest one.
#
# Swapped rather than lowered, so every tier still buys something. Access is what
# a climbing skill needs; taking a core sample and moving on is a convenience,
# which is the right shape for the top of a ladder.
const MINING_DEEP_TIER := 2     # t2: band-4 seams can be worked at all
const MINING_SAMPLE_TIER := 3   # t3: release past halfway and keep half the cut
const MINING_SAMPLE_FRACTION := 0.5


func mining_next_at() -> int:
	var next := mining + 1
	return MINING_TIERS[next] if next < MINING_TIERS.size() else -1


func mark_mining(band: int) -> bool:
	# Weighted by BAND, and fed by the CUT rather than the SALE. Selling ore is a
	# dock visit, which a smuggler makes anyway; cutting rock is the verb this
	# skill is about. MINING PAYS ON SEAMS, NOT SALES asserts the distinction.
	var xp := maxi(band, 1)
	if mining >= MINING_TIERS.size() - 1:
		return false
	mining_xp += xp
	var gained := false
	while mining < MINING_TIERS.size() - 1 and mining_xp >= MINING_TIERS[mining + 1]:
		mining += 1
		gained = true
	# One line naming the tier LANDED on, matching mark_smuggling: a big band-4
	# cut can cross two at once, and the log must not disagree with the toast.
	if gained:
		note_log("MINING %d — THE ROCK READS DIFFERENTLY NOW" % mining)
	_queue_save()
	return gained


func can_work_band(band: int) -> bool:
	# t3 is ACCESS: the deepest seams are refused until the skill is there. A
	# locked seam stays visible and says why -- a thing you can see and cannot
	# have is a goal, and a thing that is simply absent is nothing at all.
	return band < 4 or mining >= MINING_DEEP_TIER


func mining_line() -> String:
	var next_at := mining_next_at()
	var tail := ("%d TO NEXT" % (next_at - mining_xp)) if next_at >= 0 \
		else "NOTHING LEFT TO LEARN"
	# HIGHEST TIER FIRST, and the order follows the CONSTANTS rather than the
	# names — the sample and the deep perk swapped tiers, and a chain that still
	# tested DEEP first would report the tier-2 perk to a tier-3 pilot.
	var perk := "ORE READS AS GREY ROCK"
	if mining >= MINING_SAMPLE_TIER:
		perk = "YOU CAN TAKE A CORE SAMPLE AND MOVE ON"
	elif mining >= MINING_DEEP_TIER:
		perk = "THE QUIET'S SEAMS WILL OPEN FOR YOU"
	elif mining >= MINING_READ_TIER:
		perk = "YOU READ A SEAM'S ORE AT A DISTANCE"
	# AND THE TIER-0 LINE NAMES THE VERB, per §58's rule that a line must either
	# use a word the game has taught or say what to do about it. "ORE READS AS
	# GREY ROCK" describes an absence to a pilot who has no idea the ladder
	# exists — and mining's is the one that most needs saying, because the
	# ELEVEN authored charted seams are worth 11 XP against a tier-1 threshold of
	# 18. A player who never crosses the marker cannot reach tier 1 at all. That
	# is the design (charted mining is a windfall, not an income); the silence
	# about it was not.
	if mining < MINING_READ_TIER:
		perk = "CUT SEAMS PAST THE MARKER — THE DEEP ONES ARE WORTH MORE"
	return "MINING %d — %s · %s" % [mining, perk, tail]


# --- charted seams ----------------------------------------------------------

func seam_key(system_id: String, index: int) -> String:
	return "%s:%d" % [system_id, index]


func is_seam_cut(key: String) -> bool:
	return seams_cut.has(key)


func note_seam_cut(key: String) -> void:
	if key == "":
		return
	seams_cut[key] = true
	_queue_save()


# --- the intel dossier ------------------------------------------------------

func apex_hints(system_id: String) -> Array:
	# A COPY. Callers plot from this every frame; handing out the live array
	# invites a renderer to sort it in place and quietly reorder what the cap
	# evicts next.
	return (apex_intel.get(system_id, []) as Array).duplicate()


func apex_hint_count(system_id: String) -> int:
	return (apex_intel.get(system_id, []) as Array).size()


func add_apex_hint(system_id: String, hint: Dictionary) -> bool:
	# Returns whether the dossier actually took it, so a channel that charges
	# for a reading can refuse to charge for one it could not file.
	#
	# A system with no engine left cannot accumulate intel: the kill deletes the
	# entry, and without this guard the next mast in a cleared system would
	# start a fresh dossier for a hunt that is already over.
	if not SystemDB.exists(system_id) or apex_killed.has(system_id):
		return false
	if not apex_intel.has(system_id):
		apex_intel[system_id] = []
	var list: Array = apex_intel[system_id]

	# Same channel, same origin, same bearing: a re-read of the same instrument
	# from the same spot. Refused rather than stacked — otherwise parking on a
	# mast and re-triggering it would narrow the estimate for free, and the
	# whole design is that precision is bought.
	for h_v in list:
		var h: Dictionary = h_v
		if String(h.get("kind", "")) != String(hint.get("kind", "")):
			continue
		if String(hint.get("kind", "")) == "ring":
			if int(h.get("band", -1)) == int(hint.get("band", -2)) \
					and String(h.get("quadrant", "")) == String(hint.get("quadrant", "")):
				return false
		elif is_equal_approx(float(h.get("ox", 0.0)), float(hint.get("ox", 0.0))) \
				and is_equal_approx(float(h.get("oz", 0.0)), float(hint.get("oz", 0.0))):
			return false

	list.append(hint)
	# Widest error evicted first, and ONLY once over the cap — a stable sort on
	# every insert would reorder equal-error hints for no reason.
	if list.size() > HINT_CAP:
		var widest := 0
		for i in range(list.size()):
			if hint_error(list[i]) > hint_error(list[widest]):
				widest = i
		list.remove_at(widest)
	intel_version += 1
	_queue_save()
	return true


func hint_error(hint: Dictionary) -> float:
	# A ring hint has no half-angle of its own, so it is scored as the quadrant
	# it names: 90 degrees, wider than any bearing channel in the game. That is
	# what makes the cap evict rumours before it evicts instrument readings.
	if String(hint.get("kind", "")) == "ring":
		return 90.0
	return float(hint.get("err", 90.0))


func clear_apex_intel(system_id: String) -> void:
	if not apex_intel.has(system_id):
		return
	apex_intel.erase(system_id)
	intel_version += 1
	_queue_save()


func archeology_line() -> String:
	# ONE RULE, three renderers — the lab head, the pause menu and the refit
	# strip. The string was written once inside the lab tab, which meant the only
	# place a pilot could read their own skill was a console they had to fly to a
	# station to open. There is deliberately no skill SCREEN ("a skill with its
	# own screen is a skill that has become bookkeeping"); what was missing was
	# never a tree, it was visibility.
	var readable: String = DeepSpace.BAND_NAMES[mini(archeology + 1,
		DeepSpace.BAND_NAMES.size() - 1)]
	var field: String = DeepSpace.BAND_NAMES[mini(archeology,
		DeepSpace.BAND_NAMES.size() - 1)]
	var next_at := archeology_next_at()
	# FLOORED AT ZERO. The subtraction was unguarded, and it only ever showed a
	# sane number because the ladder's top rung was also the last one: xp could
	# not sit above a threshold that did not exist. Adding two rungs made
	# `next_at` a real number where it used to be -1, and a hold carrying more xp
	# than the next tier costs printed "· -891 TO NEXT" on the pilot strip.
	# Nothing about the arithmetic was frontier-specific; the frontier only made
	# it reachable.
	var tail := ("%d TO NEXT" % maxi(next_at - archeology_xp, 0)) if next_at >= 0 \
		else "NOTHING LEFT TO LEARN"
	# AND AT TIER 0 IT SAYS WHAT TO DO. Breaching hulls is the feed that carries
	# this ladder on its own — a playtester's 48 xp was 12 breaches x 4 exactly,
	# with ZERO from the other feed — so the verb worth naming is the one nobody
	# uses: reading. It is also the hub, because Reaches salvage reads as the
	# Forged Manifest that smuggling's and persuasion's bluff both want.
	if archeology < 1:
		return "ARCHEOLOGY 0 — BREACH HULLS, AND READ WHAT THEY HOLD AT A LAB · %s" % tail
	return "ARCHEOLOGY %d — READS %s IN THE FIELD, %s AT A LAB · %s" % [
		archeology, field, readable, tail]


func archeology_next_at() -> int:
	# XP needed for the next tier, or -1 at the cap.
	var next := archeology + 1
	return ARCHEOLOGY_TIERS[next] if next < ARCHEOLOGY_TIERS.size() else -1


func mark_archeology(xp: int) -> bool:
	# Returns true if a tier was gained, so callers can announce it.
	if xp <= 0 or archeology >= ARCHEOLOGY_TIERS.size() - 1:
		return false
	archeology_xp += xp
	var gained := false
	while archeology < ARCHEOLOGY_TIERS.size() - 1 \
			and archeology_xp >= ARCHEOLOGY_TIERS[archeology + 1]:
		archeology += 1
		gained = true
	# One line, final tier only — see mark_smuggling for why.
	if gained:
		note_log("ARCHEOLOGY %d — READS %s" % [archeology,
			DeepSpace.BAND_NAMES[mini(archeology, DeepSpace.BAND_NAMES.size() - 1)]])
	_queue_save()
	return gained


func can_read(salvage_id: String, at_lab: bool) -> bool:
	var band := CommodityDB.band_of(salvage_id)
	if band < 0:
		return false
	return band <= archeology + (1 if at_lab else 0)


func identify(salvage_id: String, output_id: String, at_lab: bool) -> bool:
	# Consumes one unit of salvage and produces one of the chosen output. The
	# player picks the output from CommodityDB.reads_as() — there is no roll here
	# and there must never be one; see the comment on READS_AS.
	if cargo_count(salvage_id) <= 0:
		return false
	if not CommodityDB.reads_as(salvage_id).has(output_id):
		return false
	if not can_read(salvage_id, at_lab):
		return false
	# Space first. A component can be bulkier than the salvage it came out of, and
	# a read that cannot be stowed must fail cleanly rather than half-happen.
	var freed := CommodityDB.space_of(salvage_id)
	var needed := CommodityDB.space_of(output_id)
	if cargo_free() + freed < needed:
		return false
	unload_cargo(salvage_id, 1)
	if load_cargo(output_id, 1) < 1:
		load_cargo(salvage_id, 1)   # put it back; nothing may vanish
		return false
	# Reported, not swallowed. A tier that arrives in silence cannot teach the
	# player anything, and "did 0->1 arrive fast enough" is the whole question the
	# first play-test has to answer.
	last_read_tiered = mark_archeology(ARCHEOLOGY_PER_READ)

	# SOMEBODY ELSE'S CHART, read properly. `index_cartographic` is the one
	# salvage in the catalog that literally IS a survey somebody else made, so it
	# is the natural carrier for a bearing — and reading it is already a
	# deliberate, paid-for act at a lab bench rather than something that happens
	# to you. The reading is taken from where the ship is, because that is where
	# the chart is being cross-referenced against known positions, which is
	# exactly the geometry a cone from here describes.
	#
	# ±12°: wider than a mast, because a mast measures the engine live and this
	# infers it from someone else's decade-old survey.
	if salvage_id == "index_cartographic":
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null:
			var main: Node = tree.get_first_node_in_group("main")
			if main != null and main.has_method("file_apex_intel"):
				var player: Node3D = tree.get_first_node_in_group("player") as Node3D
				var from := Vector3.ZERO
				if player != null:
					from = player.global_position
				main.file_apex_intel("relic", from, 12.0)

	_queue_save()
	return true


func hold_has(good: String) -> bool:
	# What the world reads to decide whether a carried thing is doing something.
	# Deliberately NOT a fitted stat: cargo_after() probes compute_stats(fit) while
	# cargo_capacity() reads live stats, so a good that moved a fitted number would
	# make the hold guard subtract two different piles from each other.
	return cargo_count(good) > 0


func _sanitize_ship_name(raw: String) -> String:
	var clean := raw.strip_edges()
	if clean.length() > SHIP_NAME_MAX:
		clean = clean.substr(0, SHIP_NAME_MAX)
	return clean if clean != "" else DEFAULT_SHIP_NAME


func set_ship_name(raw: String) -> void:
	ship_name = _sanitize_ship_name(raw)
	_queue_save()


func note_ledger(key: String, amount: int) -> void:
	# Deliberately does NOT _queue_save. distance_flown ticks every physics frame,
	# and a save on each would be a disk write per frame — the same reasoning
	# played_seconds already carries. The logbook rides the ambient saves and the
	# close-request flush.
	if not DEFAULT_LEDGER.has(key) or amount <= 0:
		return
	ledger[key] = int(ledger.get(key, 0)) + amount


func note_ledger_max(key: String, value: int) -> void:
	# For records rather than tallies: deepest_depth is a high-water mark, and
	# adding to it every frame would make it a distance counter by accident.
	if not DEFAULT_LEDGER.has(key):
		return
	ledger[key] = maxi(int(ledger.get(key, 0)), value)


func note_log(line: String) -> void:
	# DISCRETE EVENTS ONLY. A per-frame source here would fill all ten slots in
	# under a second and evict the run — which is the same reason note_ledger
	# exists separately from this.
	#
	# Deliberately does NOT _queue_save, and the reason is stronger than
	# note_ledger's disk-write one: this array and `deepest_depth` are written by
	# the SAME save_game() dict, so they can never disagree. Saving the log on its
	# own would let a line naming THE DRIFT outlive a high-water mark that never
	# reached it — and the next crossing would then log the band a second time.
	# They ride the ambient saves together or not at all.
	var clean := line.strip_edges()
	if clean == "":
		return
	if clean.length() > LOG_LINE_MAX:
		clean = clean.substr(0, LOG_LINE_MAX)
	captains_log.append(clean)
	while captains_log.size() > LOG_MAX:
		captains_log.remove_at(0)


func log_lines() -> Array:
	# One read-only accessor, the title_summary() precedent: the text a player
	# sees is worth asserting and nothing else can reach it. A duplicate, so a
	# renderer cannot quietly become a second writer.
	return captains_log.duplicate()


func strip_hottest(target_value: int) -> int:
	# The raiders' half of a paid parley: cargo comes out HOTTEST FIRST —
	# interdiction weight x value — because they take what they came for. The
	# deliberate asymmetry with jettison_to_fit's cheapest-first is the point:
	# there the PLAYER chooses what to lose, here the raiders do. Returns the
	# base value actually removed. Pays nothing, transfers nothing — a departing
	# raider carrying the toll would hand it back to anyone who shot them, which
	# is the printer.
	if target_value <= 0:
		return 0
	var order := CommodityDB.ids().filter(func(g) -> bool: return cargo_count(String(g)) > 0)
	order.sort_custom(func(a, b) -> bool:
		return CommodityDB.interdiction_weight(String(a)) * CommodityDB.base_price(String(a)) \
			> CommodityDB.interdiction_weight(String(b)) * CommodityDB.base_price(String(b)))
	var removed := 0
	for g_v in order:
		var g := String(g_v)
		while removed < target_value and cargo_count(g) > 0:
			unload_cargo(g, 1)
			removed += CommodityDB.base_price(g)
	if removed > 0:
		_queue_save()
	return removed


func jettison(good: String, units: int) -> int:
	# Deliberately pays nothing. Dumping cargo to fit a refit is a cost you chose
	# over flying to a port, and paying for it would make it the better option.
	var removed := unload_cargo(good, units)
	if removed > 0:
		_queue_save()
	return removed


func jettison_to_fit(slot: int, id: String) -> int:
	# Dumps cheapest-first until the swap is legal, so the player loses the least
	# valuable thing in the hold rather than whatever happens to be iterated first.
	var goods := CommodityDB.ids()
	goods.sort_custom(func(a, b) -> bool:
		return CommodityDB.base_price(String(a)) < CommodityDB.base_price(String(b)))
	var dumped := 0
	for g_v in goods:
		var g := String(g_v)
		while cargo_overflow(slot, id) > 0 and cargo_count(g) > 0:
			unload_cargo(g, 1)
			dumped += 1
	if dumped > 0:
		_queue_save()
	return dumped


func equip(slot: int, id: String) -> bool:
	if not can_equip(slot, id):
		return false
	fit[slot] = id
	_recompute()
	_queue_save()
	return true


func fit_has(module_id: String) -> bool:
	# Is this module actually EQUIPPED — not merely owned. Fitted world-effects
	# are read through this at their point of use, exactly the way carried ones
	# are read through hold_has(), and deliberately NOT through compute_stats:
	# 19's rule is that a thing may change what the world does to you or what the
	# ship can do, never both, and the hold guard subtracts two different piles
	# the moment those cross.
	for slot in fit:
		if String(fit[slot]) == module_id:
			return true
	return false


func can_craft(id: String) -> bool:
	var rec := ModuleDB.recipe(id)
	if rec.is_empty() or owns(id):
		return false
	for good in rec:
		if cargo_count(String(good)) < int(rec[good]):
			return false
	return true


func craft(id: String) -> bool:
	# Consumes the components and hands over the module. Costs no salvage: the
	# price is the fence sale you did not make, which for these inputs is over
	# two thousand at a deep haven — dearer than most of the catalog.
	if not can_craft(id):
		return false
	var rec := ModuleDB.recipe(id)
	for good in rec:
		unload_cargo(String(good), int(rec[good]))
	owned.append(id)
	_queue_save()
	fit_changed.emit(stats)
	return true


func buy(id: String) -> bool:
	if not ModuleDB.exists(id) or owns(id):
		return false
	var price := int(ModuleDB.get_module(id)["price"])
	if not spend_salvage(price):
		return false
	owned.append(id)
	_queue_save()
	return true


func upgrade_reactor() -> bool:
	var next := reactor_tier + 1
	if next >= ModuleDB.REACTOR_TIERS.size():
		return false
	if not spend_salvage(int(ModuleDB.REACTOR_TIERS[next]["price"])):
		return false
	reactor_tier = next
	_recompute()
	_queue_save()
	return true


func reactor_name() -> String:
	return ModuleDB.REACTOR_TIERS[reactor_tier]["name"]


func next_reactor_price() -> int:
	var next := reactor_tier + 1
	if next >= ModuleDB.REACTOR_TIERS.size():
		return -1
	return int(ModuleDB.REACTOR_TIERS[next]["price"])


func preview_stats(slot: int, id: String) -> Dictionary:
	# DIVERSIONS ARE FOLDED IN HERE TOO, and leaving them out made every refit
	# delta lie while one was live. UIKit.delta_line renders
	# delta_lines(GameState.stats, after): the BEFORE has diversions in it and
	# the AFTER did not, so with a mount burned into the drive every weapon in
	# the list advertised a fabricated ~+100% DPS gain, and equipping one
	# re-applied the halving the strip had just promised to undo. A delta is only
	# meaningful between two comparable worlds.
	var probe := fit.duplicate()
	probe[slot] = id
	return ModuleDB.enforce_floors(
		SectionDB.apply(ModuleDB.compute_stats(probe), diverts))


func can_divert(source: String, target: String, integrity: float) -> bool:
	# THE WHOLE RULE, ASKED RATHER THAN RE-DERIVED. The panel needs to know which
	# rows to light up and divert_power needs to know what to refuse, and those
	# are the same question -- the moment they are answered in two places they
	# disagree, which is how "you may only burn something broken" ended up living
	# in a `disabled` flag. divert_power is now a thin wrapper over this.
	if not SectionDB.is_section(source) or not SectionDB.is_section(target):
		return false
	if source == target:
		return false
	# Only a damaged section has power going spare, and a working section is
	# never a legal source however desperate the player is.
	if not SectionDB.is_damaged(source, integrity):
		return false
	if SectionDB.is_damaged(target, integrity):
		return false
	# Nothing is spent twice, in any of the four directions.
	if diverts.has(source) or diverts.has(target):
		return false
	if diverts.values().has(source) or diverts.values().has(target):
		return false
	# And a system cannot pay itself -- see divert_power's note.
	if String(SectionDB.section(source).get("governs", "")) \
			== String(SectionDB.section(target).get("governs", "")):
		return false
	return true


func divert_power(source: String, target: String, integrity: float) -> bool:
	# BURN A DAMAGED SECTION TO OVERCHARGE A WORKING ONE. Refuses rather than
	# half-applies, so a caller cannot mistake "nothing happened" for a trade --
	# claim_commission's rule, and the panel reads the return to decide whether
	# to narrate.
	#
	# A THIN WRAPPER OVER can_divert, deliberately. The first draft spelled the
	# rules out here and let the panel decide which rows were tappable, which put
	# "you may only burn something already broken" in the RENDERING -- true only
	# until somebody added a second caller, and invisible to any assertion that
	# did not drive a UI. The panel now asks can_divert too, so there is exactly
	# one answer and the mutator cannot drift from what the sheet offered.
	#
	# INTEGRITY IS AN ARGUMENT because GameState cannot read the ship's shields:
	# the caller passes what it measured.
	if not can_divert(source, target, integrity):
		return false
	diverts[source] = target
	_recompute()
	return true


func clear_diverts() -> bool:
	# Docking is repair. Returns whether anything was actually undone so the
	# dock line can stay quiet on a ship that never diverted.
	if diverts.is_empty():
		return false
	diverts = {}
	_recompute()
	return true


func _recompute() -> void:
	stats = ModuleDB.compute_stats(fit)
	# AFTER the catalog, never inside it. compute_stats is pure over a fit and is
	# probed speculatively by the refit sheet and by cargo_after(); folding a
	# live diversion into it would make those previews describe a ship that only
	# exists while something is burned out.
	stats = SectionDB.apply(stats, diverts)
	# AND THE FLOORS GO BACK ON. compute_stats applies them and SectionDB then
	# multiplies through them, so without this a diversion could put a legal fit
	# under a bound the catalog guarantees to every ship.
	stats = ModuleDB.enforce_floors(stats)
	fit_changed.emit(stats)


# --- persistence -----------------------------------------------------------

func _queue_save() -> void:
	# Debounced: loot pickups fire constantly during a vortex.
	if _save_timer != null:
		return
	_save_timer = get_tree().create_timer(SAVE_DEBOUNCE, true, false, true)
	_save_timer.timeout.connect(func() -> void:
		_save_timer = null
		save_game()
	)


func save_game() -> void:
	if not save_enabled:
		return
	var fit_out := {}
	for slot in fit:
		fit_out[str(slot)] = fit[slot]
	var data := {
		"version": SAVE_VERSION,
		"salvage": salvage,
		"owned": owned,
		"fit": fit_out,
		"reactor_tier": reactor_tier,
		"current_system": current_system,
		"breached": breached,
		"contract_state": contract_state,
		"barks_seen": barks_seen,
		"apex_killed": apex_killed,
		"apex_down": apex_down,
		"lanes_open": lanes_open,
		"run_seed": run_seed,
		"cargo": cargo,
		"played_seconds": played_seconds,
		"docked_at": docked_at,
		"market_pressure": market_pressure,
		"market_events": market_events,
		"audio_muted": audio_muted,
		"tutorial_step": tutorial_step,
		"settings": settings,
		"livery": livery,
		"archeology": archeology,
		"archeology_xp": archeology_xp,
		"smuggling": smuggling,
		"smuggling_xp": smuggling_xp,
		"mining": mining,
		"mining_xp": mining_xp,
		"persuasion": persuasion,
		"persuasion_xp": persuasion_xp,
		"seams_cut": seams_cut,
		"apex_intel": apex_intel,
		"beacons": beacons,
		"colonies": colonies,
		"last_colony_jump": last_colony_jump,
		"warehouse": warehouse,
		"ledger": ledger,
		"ship_name": ship_name,
		"captains_log": captains_log,
		"commission_claimed": commission_claimed,
		"commissioned": commissioned,
		"faction_deltas": faction_deltas,
	}
	var f := FileAccess.open(save_path, FileAccess.WRITE)
	if f == null:
		push_warning("Pyxis: could not open save for writing")
		return
	f.store_string(JSON.stringify(data, "\t"))
	f.close()


func load_game() -> bool:
	if not FileAccess.file_exists(save_path):
		return false
	var f := FileAccess.open(save_path, FileAccess.READ)
	if f == null:
		return false
	# The save carries no diversions by design, so loading one has to CLEAR them
	# rather than merely not set them -- CONTINUE from the title runs through
	# here with a live dictionary from the abandoned run still in memory.
	diverts = {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Pyxis: save unreadable, starting fresh")
		return false
	var data: Dictionary = parsed
	var version := int(data.get("version", 0))
	if version <= 0 or version > SAVE_VERSION:
		push_warning("Pyxis: save version %d unsupported, starting fresh" % version)
		return false
	# Older saves are migrated, never discarded: any field added after their
	# version simply falls back to its default below.

	salvage = int(data.get("salvage", 0))
	owned = []
	for id in data.get("owned", []):
		if ModuleDB.exists(str(id)):
			owned.append(str(id))
	for id in ModuleDB.STARTER_OWNED:
		if not owned.has(id):
			owned.append(id)

	# v7 adds Slot.UTILITY_B. Starting from STARTER_FIT means any slot a saved fit
	# does not mention simply keeps its default — so a v6 fit loads with the new
	# slot empty and needs no migration branch of its own.
	fit = ModuleDB.STARTER_FIT.duplicate()
	var saved_fit: Dictionary = data.get("fit", {})
	for key in saved_fit:
		var slot := int(key)
		var id := str(saved_fit[key])
		if id == "" or (ModuleDB.exists(id) and owned.has(id)):
			fit[slot] = id

	reactor_tier = clampi(int(data.get("reactor_tier", 0)), 0, ModuleDB.REACTOR_TIERS.size() - 1)

	# v2 fields. A v1 save has none of these and gets sane defaults.
	current_system = str(data.get("current_system", SystemDB.START_SYSTEM))
	if not SystemDB.exists(current_system):
		current_system = SystemDB.START_SYSTEM
	breached = []
	for id in data.get("breached", []):
		if SystemDB.exists(str(id)):
			breached.append(str(id))
	contract_state = data.get("contract_state", {})
	barks_seen = []
	for key in data.get("barks_seen", []):
		barks_seen.append(str(key))
	# v3 field; absent in v1 and v2 saves, which simply start with no apex kills.
	apex_killed = []
	for id in data.get("apex_killed", []):
		if SystemDB.exists(str(id)):
			apex_killed.append(str(id))

	# v17. THE SECOND GRANDFATHER, and it is the conservative one on purpose.
	#
	# Before v17 the kill was not persisted at all, so a v16 save cannot tell us
	# which engines are down — only which ones PAID, in apex_killed. Seeding from
	# that is exact where it speaks and silent where it does not: a player who
	# cracked a wreck never sees that engine again, which is the fix they are
	# owed, and nobody is handed a system they did not clear.
	#
	# It under-counts by exactly one case — killed, warped out, wreck never
	# cracked — and that is the right way to be wrong. Under-counting rebuilds an
	# engine the player already beat, which is today's behaviour and merely
	# unchanged; over-counting would delete a wreck worth up to 32,000 credits
	# that they can still see on the radar. NOT seeded from lanes_open for the
	# same reason: its own pre-v15 grandfather fills it from `breached`, so a save
	# old enough would report living engines as dead.
	apex_down = []
	if data.has("apex_down"):
		for id in data.get("apex_down", []):
			if SystemDB.exists(str(id)) and not apex_down.has(str(id)):
				apex_down.append(str(id))
	else:
		apex_down = apex_killed.duplicate()

	# v15. THE GRANDFATHER, and it is the whole reason this stage is safe to ship.
	#
	# Before v15 a breach opened the lane. A player who breached PYX-01 last night
	# could fly to PYX-02 this morning — and a straight `lanes_open = []` default
	# would take that away, because their save has no such key and their engine is
	# very much alive. Revoking access a player already had is the one migration
	# outcome this codebase will not ship.
	#
	# So an absent key means "this save predates the split": every system they had
	# BREACHED is treated as a lane they had OPEN. It costs them nothing and grants
	# nothing new — it reproduces exactly the reachability the old rule gave them.
	# A v15+ save always writes the key, so this branch is genuinely only ever
	# taken once per save file. Asserted by SAVETEST=migrate14.
	lanes_open = []
	if data.has("lanes_open"):
		for id in data.get("lanes_open", []):
			if SystemDB.exists(str(id)) and not lanes_open.has(str(id)):
				lanes_open.append(str(id))
	else:
		lanes_open = breached.duplicate()

	# 0 means "no run salt yet" — a pre-v15 save, or one written before the field
	# existed. Roll one rather than leaving every such save sharing seed 0, which
	# would hide every lair in the same place for every returning player.
	run_seed = int(data.get("run_seed", 0))
	if run_seed == 0:
		var seed_rng := RandomNumberGenerator.new()
		seed_rng.randomize()
		run_seed = seed_rng.randi()

	# v4 economy fields; absent in v1-v3 saves, which simply start with an empty
	# hold, a fresh clock, and a market at rest.
	cargo = {}
	for good in data.get("cargo", {}):
		var id := str(good)
		if CommodityDB.exists(id):
			cargo[id] = int(data["cargo"][good])
	played_seconds = float(data.get("played_seconds", 0.0))
	docked_at = str(data.get("docked_at", ""))
	market_pressure = {}
	for k in data.get("market_pressure", {}):
		market_pressure[str(k)] = clampf(float(data["market_pressure"][k]),
			-Market.PRESSURE_CAP, Market.PRESSURE_CAP)
	# v5 fields. Anyone loading a v1-v4 save has been playing already, so the
	# tutorial is treated as finished rather than replayed at them.
	audio_muted = bool(data.get("audio_muted", false))
	tutorial_step = int(data.get("tutorial_step", -1))
	# v8. A v7 save simply arrives at tier 0 with nothing read — no branch needed,
	# which is the whole reason load_game has never had one.
	archeology = clampi(int(data.get("archeology", 0)), 0, ARCHEOLOGY_TIERS.size() - 1)
	archeology_xp = maxi(int(data.get("archeology_xp", 0)), 0)
	smuggling = clampi(int(data.get("smuggling", 0)), 0, SMUGGLING_TIERS.size() - 1)
	smuggling_xp = maxi(int(data.get("smuggling_xp", 0)), 0)
	# v14. A v13 save arrives at mining 0 with nothing cut, by the same policy —
	# there is no migration branch here and there never has been one.
	mining = clampi(int(data.get("mining", 0)), 0, MINING_TIERS.size() - 1)
	mining_xp = maxi(int(data.get("mining_xp", 0)), 0)
	# v19. PERSUASION, and there is no migration branch here for the reason there
	# has never been one on this path: an absent key defaults, and tier 0 with no
	# xp is exactly what a pilot who has never talked a pack down should load as.
	# Seeding it from smuggling_xp was considered and refused — migrate13 records
	# why a truthy default that hands a returning player a skill they never
	# touched is the wrong kind of generosity.
	persuasion = clampi(int(data.get("persuasion", 0)), 0, PERSUASION_TIERS.size() - 1)
	persuasion_xp = maxi(int(data.get("persuasion_xp", 0)), 0)
	_load_seams_cut(data.get("seams_cut", {}))
	_load_apex_intel(data.get("apex_intel", {}))
	# v20. Beacons: no migration branch, per this file's standing rule — an
	# absent key is an empty store and a full stock, which is exactly what a
	# pilot who has never dropped one should load as.
	_load_beacons(data.get("beacons", {}))
	# v20 stage 6, riding the same version as beacons — one bump for both stores,
	# since neither needs a grandfather and an absent key is the correct empty.
	_load_colonies(data.get("colonies", {}))
	last_colony_jump = float(data.get("last_colony_jump", -1.0e9))
	_load_warehouse(data.get("warehouse", {}))
	# v18. A v17 save has no key and arrives at the authored baseline — which by
	# construction IS the world that save was written in, so the migration can
	# neither grant nor revoke anything. No grandfather branch needed, and per
	# the v8/v14 precedent there never should be one.
	_load_faction_deltas(data.get("faction_deltas", {}))

	# v6 fields. Merged key-by-key onto the defaults rather than taken wholesale,
	# so a v6 save written before a later setting existed still gets that
	# setting's default instead of a missing key.
	settings = DEFAULT_SETTINGS.duplicate()
	var saved_settings: Dictionary = data.get("settings", {})
	for key in DEFAULT_SETTINGS:
		if saved_settings.has(key):
			settings[key] = saved_settings[key]
	settings["music_vol"] = clampf(float(settings["music_vol"]), 0.0, 1.0)
	settings["sfx_vol"] = clampf(float(settings["sfx_vol"]), 0.0, 1.0)
	settings["shake"] = bool(settings["shake"])
	settings["ui_scale"] = clampf(float(settings["ui_scale"]), 0.7, 1.6)
	settings["colorblind"] = clampi(int(settings["colorblind"]), 0, Palette.Vision.size() - 1)
	if not (settings["bindings"] is Dictionary):
		settings["bindings"] = {}

	livery = DEFAULT_LIVERY.duplicate()
	var saved_livery: Dictionary = data.get("livery", {})
	for key in DEFAULT_LIVERY:
		if saved_livery.has(key):
			livery[key] = int(saved_livery[key])
	# CLAMPED. These were the only ints in load_game with no bound, protected
	# solely by Palette's posmod wrap -- which is not protection, it is a rename:
	# `accent: 17` wraps to 1 and `accent: 8` wraps to 0, so a hand-edited save
	# silently wears a colour it never earned rather than being corrected. That
	# becomes load-bearing the moment an accent is EARNED rather than bought,
	# because player_ship.gd reads Palette.livery_accent(livery_index("accent"))
	# directly and never asks set_livery anything.
	livery["hull"] = clampi(int(livery["hull"]), 0, Palette.LIVERY_HULLS.size() - 1)
	livery["accent"] = clampi(int(livery["accent"]), 0, Palette.LIVERY_ACCENTS.size() - 1)

	# Key by key onto the defaults, so a v9 save arrives with every counter at 0
	# rather than with the dict missing. Floored at 0: a hand-edited negative
	# would print as a nonsense logbook line forever.
	ledger = DEFAULT_LEDGER.duplicate()
	var saved_ledger: Dictionary = data.get("ledger", {})
	for key in DEFAULT_LEDGER:
		if saved_ledger.has(key):
			ledger[key] = maxi(0, int(saved_ledger[key]))
	ship_name = _sanitize_ship_name(str(data.get("ship_name", DEFAULT_SHIP_NAME)))

	# v13. Clamped against STAGES.size() rather than a literal 4, so adding a
	# fifth stage cannot leave a stale bound behind. A v12 save arrives with
	# nothing claimed and uncommissioned, which is the correct reading of a save
	# written before the Commission existed.
	commission_claimed = clampi(int(data.get("commission_claimed", 0)), 0, CommissionDB.count())
	commissioned = bool(data.get("commissioned", false))
	# The accent lock, AT THE LOAD PATH. Finding 2: a hand-edited save never calls
	# set_livery, and the ship reads the index straight out of Palette -- so this
	# is the only place that can refuse it. The clamp above turns 17 into a valid
	# index; this turns a valid-but-unearned one into 0.
	if not commissioned and int(livery["accent"]) >= REGISTRY_ACCENT:
		livery["accent"] = 0

	# v12. Rebuilt element by element rather than taken wholesale — the
	# market_events posture — so a save carrying a number, a null or a 200-char
	# line arrives as a valid log instead of as a crash in the pause menu. Shed
	# from the FRONT, keeping the NEWEST ten: an over-long log is the same
	# invalid state an over-capacity warehouse is, and it self-corrects the same
	# way rather than being tolerated.
	captains_log = []
	for entry in data.get("captains_log", []):
		var line := str(entry).strip_edges()
		if line == "":
			continue
		if line.length() > LOG_LINE_MAX:
			line = line.substr(0, LOG_LINE_MAX)
		captains_log.append(line)
	while captains_log.size() > LOG_MAX:
		captains_log.remove_at(0)

	market_events = []
	for e in data.get("market_events", []):
		var ev: Dictionary = e
		if CommodityDB.exists(str(ev.get("good", ""))) and float(ev.get("remaining", 0.0)) > 0.0:
			market_events.append({
				"kind": str(ev.get("kind", "shortage")),
				"port": str(ev.get("port", "")),
				"good": str(ev.get("good", "")),
				"mult": float(ev.get("mult", 1.0)),
				"remaining": float(ev.get("remaining", 0.0)),
			})
	# Never strand the player in a system they can no longer reach.
	if not is_system_unlocked(current_system):
		current_system = SystemDB.START_SYSTEM

	# A fit that no longer fits the budget (edited save, changed balance) falls
	# back rather than trapping the player in an invalid state.
	if ModuleDB.power_draw(fit) > power_cap():
		fit = ModuleDB.STARTER_FIT.duplicate()
	return true


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_PREDELETE:
		save_game()
		# One row per session, at the same moment the save is written. Guarded by
		# save_enabled for the same reason save_game is: a harness that has said
		# "never write" must not leave a row behind that a later playtest reads
		# as if a person had produced it.
		if save_enabled:
			Telemetry.record_session(played_seconds)
