extends Node
# Autoloaded as `GameState`. Owns persistent player state and is the only
# thing that writes the save file. Serialization is explicit (never
# store-the-whole-object) so this layer can move behind a server later.

signal fit_changed(stats: Dictionary)
signal salvage_changed(total: int)
signal system_unlocked(id: String)

const SAVE_PATH := "user://save.json"
const SAVE_VERSION := 12
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

# v2 fields — travel, progression, and first-run state.
var current_system := ""
var breached: Array[String] = []
var contract_state := {}
var barks_seen: Array[String] = []

# v3: systems whose apex engine has been put down at least once (first-kill
# bonus is one-time). The fight itself is never persisted — it always resets.
var apex_killed: Array[String] = []

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
	var tree := get_tree()
	if tree != null:
		var win := tree.root.get_window()
		if win != null:
			UILayout.apply_scale(win)


func shake_enabled() -> bool:
	# Reduced motion subsumes shake: someone who asked for less movement is not
	# asking to keep the camera lurching. The reverse is not true.
	return bool(setting("shake")) and not reduce_motion()


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
	salvage = 0
	owned = []
	for id in ModuleDB.STARTER_OWNED:
		owned.append(id)
	fit = ModuleDB.STARTER_FIT.duplicate()
	reactor_tier = 0
	current_system = SystemDB.START_SYSTEM
	breached = []
	contract_state = {}
	barks_seen = []
	apex_killed = []
	cargo = {}
	played_seconds = 0.0
	docked_at = ""
	market_pressure = {}
	market_events = []
	archeology = 0
	archeology_xp = 0
	smuggling = 0
	smuggling_xp = 0
	warehouse = {}
	# A new survey is a new logbook. ship_name is deliberately NOT reset — see the
	# field comment: what you called your ship outlives the run that named it.
	ledger = DEFAULT_LEDGER.duplicate()
	captains_log = []
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


func is_system_unlocked(id: String) -> bool:
	var req := String(SystemDB.get_system(id).get("unlocked_by", ""))
	return req == "" or breached.has(req)


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


func mark_apex_killed(id: String) -> void:
	if apex_killed.has(id):
		return
	apex_killed.append(id)
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
const ARCHEOLOGY_TIERS := [0, 12, 34, 78]
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


func bluff_odds() -> float:
	if smuggling < SMUGGLING_BLUFF_TIER:
		return 0.0
	return SMUGGLING_BLUFF_BASE + SMUGGLING_BLUFF_PER_TIER \
		* float(smuggling - SMUGGLING_BLUFF_TIER)


func smuggling_line() -> String:
	var next_at := smuggling_next_at()
	var tail := ("%d TO NEXT" % (next_at - smuggling_xp)) if next_at >= 0 \
		else "NOTHING LEFT TO LEARN"
	var perk := "THE LANES DO NOT KNOW YOU YET"
	if smuggling >= SMUGGLING_ACCESS_TIER:
		perk = "DEEP FENCES DEAL IN ANYTHING YOU CARRY"
	elif smuggling >= SMUGGLING_BLUFF_TIER:
		perk = "YOU CAN TALK YOUR WAY PAST A PACK · %d%%" % int(bluff_odds() * 100.0)
	elif smuggling >= 1:
		perk = "THE LANES WARN YOU EARLY"
	return "SMUGGLING %d — %s · %s" % [smuggling, perk, tail]


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
	var tail := ("%d TO NEXT" % (next_at - archeology_xp)) if next_at >= 0 \
		else "NOTHING LEFT TO LEARN"
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
	var probe := fit.duplicate()
	probe[slot] = id
	return ModuleDB.compute_stats(probe)


func _recompute() -> void:
	stats = ModuleDB.compute_stats(fit)
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
		"warehouse": warehouse,
		"ledger": ledger,
		"ship_name": ship_name,
		"captains_log": captains_log,
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
	_load_warehouse(data.get("warehouse", {}))

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

	livery = DEFAULT_LIVERY.duplicate()
	var saved_livery: Dictionary = data.get("livery", {})
	for key in DEFAULT_LIVERY:
		if saved_livery.has(key):
			livery[key] = int(saved_livery[key])

	# Key by key onto the defaults, so a v9 save arrives with every counter at 0
	# rather than with the dict missing. Floored at 0: a hand-edited negative
	# would print as a nonsense logbook line forever.
	ledger = DEFAULT_LEDGER.duplicate()
	var saved_ledger: Dictionary = data.get("ledger", {})
	for key in DEFAULT_LEDGER:
		if saved_ledger.has(key):
			ledger[key] = maxi(0, int(saved_ledger[key]))
	ship_name = _sanitize_ship_name(str(data.get("ship_name", DEFAULT_SHIP_NAME)))

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
