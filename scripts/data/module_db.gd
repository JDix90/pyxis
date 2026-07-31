class_name ModuleDB
extends Object
# The fitting catalog. Every module is a data row; adding content means adding
# a dictionary entry, never code.
#
# Design contract (see docs/STRATEGY.md):
#   constrained - every module draws power against one reactor budget
#   legible     - few stats, all surfaced as deltas in the refit console
#   tested      - weapon families are sidegrades that different enemies punish
#   reversible  - salvage buys modules; swapping owned modules is always free
#   visible     - every module changes the kitbashed hull

# UTILITY_B is the "build more onto the ship" slot (save v7). It is deliberately
# a SECOND utility rather than a new category: the interesting question was never
# "what kind of thing can I bolt on", it was "which two of these four do I want",
# and one more utility slot turns a single pick into a real pairing decision.
enum Slot { WEAPON_A, WEAPON_B, DRIVE, UTILITY, CORE, UTILITY_B }

const SLOT_NAMES := {
	Slot.WEAPON_A: "WEAPON I",
	Slot.WEAPON_B: "WEAPON II",
	Slot.DRIVE: "DRIVE",
	Slot.UTILITY: "UTILITY",
	Slot.CORE: "CORE",
	Slot.UTILITY_B: "UTILITY II",
}

# Which catalog category may be equipped in which slot.
const SLOT_CATEGORY := {
	Slot.WEAPON_A: "weapon",
	Slot.WEAPON_B: "weapon",
	Slot.DRIVE: "drive",
	Slot.UTILITY: "utility",
	Slot.CORE: "core",
	Slot.UTILITY_B: "utility",
}

# Budget curve. Starter fit draws 8, so Mk I leaves room to add a utility and
# try one weapon swap. The squeeze arrives when you want two heavy mounts, and
# even Mk III cannot carry a fit of all-best modules — there is always a call
# to make.
#
# Phase 2 pricing: the reactor is the single most build-defining purchase in the
# game, so it should be the thing you save several sessions for, not an early
# formality. Mk III is deliberately the most expensive line in the catalog.
const REACTOR_TIERS := [
	{"name": "Reactor Mk I", "power": 12, "price": 0},
	{"name": "Reactor Mk II", "power": 15, "price": 10000},
	{"name": "Reactor Mk III", "power": 18, "price": 32000},
]

# --- base hull stats, before modules ---------------------------------------
const BASE := {
	# +15% over the phase-1 value: the systems roughly doubled in size, so
	# crossing one should feel bigger without taking proportionally longer.
	"max_speed": 5.75,
	"accel": 9.0,
	"turn_rate": 7.0,
	"shield_max": 100.0,
	"shield_regen": 6.0,
	"magnet_range": 6.0,
	"salvage_mult": 1.0,
	"crit_chance": 0.0,
	"weapon_range_bonus": 0.0,
	"cargo_space": 24.0,
}

# --- catalog ----------------------------------------------------------------
# PRICING RULE (phase 2): prices are ~1.8x their phase-1 values. Phase 1 let a
# normal run buy nearly everything with change left over, which quietly turned
# the fitting console from a set of choices into a shopping list. Halving loot
# (see LootCube) and roughly doubling prices puts one mid-tier module inside an
# eight-minute loop and the full catalog several sessions out. The band is
# asserted by PYXIS_PACINGTEST — change a price here and re-run it.
#
# Weapon families are deliberate sidegrades:
#   pulse - generalist, cheap, unremarkable
#   lance - long reach, big alpha, slow. Great vs. tanky sentries, wasteful on swarms.
#   arc   - short reach, chains to nearby targets. Shreds swarms, weak vs. single tanks.
const MODULES := {
	"pulse_1": {
		"name": "Pulse Repeater",
		"category": "weapon",
		"family": "pulse",
		"tier": 1,
		"power": 2,
		"price": 0,
		"desc": "Balanced rapid-fire mount. Dependable, unspectacular.",
		"stats": {"damage": 20.0, "interval": 0.34, "range": 7.0, "chain": 0},
	},
	"pulse_2": {
		"name": "Pulse Repeater Mk II",
		"category": "weapon",
		"family": "pulse",
		"tier": 2,
		"power": 3,
		"price": 8000,
		"desc": "Tighter coils, faster cycle.",
		# Pulse is the power-efficient generalist. It must NOT out-damage a Lance
		# of the same tier, or Lance's reach has to carry the whole family alone.
		"stats": {"damage": 28.0, "interval": 0.32, "range": 7.5, "chain": 0},
	},
	"lance_1": {
		"name": "Lance Array",
		"category": "weapon",
		"family": "lance",
		"tier": 1,
		"power": 4,
		"price": 5800,
		"desc": "Long-range particle lance. Heavy hits, slow cycle.",
		"stats": {"damage": 68.0, "interval": 1.05, "range": 11.0, "chain": 0},
	},
	"lance_2": {
		"name": "Lance Array Mk II",
		"category": "weapon",
		"family": "lance",
		"tier": 2,
		"power": 5,
		"price": 18000,
		"desc": "Overbored lance. Punches through hull plating.",
		# Highest single-target damage in the catalog, paid for in power: a dual
		# Lance fit costs 10 of your budget and forces a utility sacrifice.
		"stats": {"damage": 105.0, "interval": 0.98, "range": 12.0, "chain": 0},
	},
	"arc_1": {
		"name": "Arc Projector",
		"category": "weapon",
		"family": "arc",
		"tier": 1,
		"power": 3,
		"price": 6500,
		"desc": "Short-range discharge that jumps to nearby contacts.",
		"stats": {"damage": 16.0, "interval": 0.42, "range": 5.5, "chain": 2},
	},
	"arc_2": {
		"name": "Arc Projector Mk II",
		"category": "weapon",
		"family": "arc",
		"tier": 2,
		"power": 4,
		"price": 19000,
		"desc": "Wider arc envelope, one more jump.",
		"stats": {"damage": 22.0, "interval": 0.40, "range": 6.2, "chain": 3},
	},
	# torp - slow area detonation. The only weapon that does not hit instantly,
	# and the only one whose target can walk out of the shot. Deliberately
	# useless against the strafers Arc was built for, and brutal against
	# anything holding station: sentries, docked probes, a bunched pack.
	"torp_1": {
		"name": "Torpedo Rack",
		"category": "weapon",
		"family": "torp",
		"tier": 1,
		"power": 5,
		"price": 7600,
		"desc": "Lobbed charge. Detonates where it lands, not where you aimed.",
		"stats": {"damage": 92.0, "interval": 1.6, "range": 9.0, "chain": 0, "splash": 2.2},
	},
	"torp_2": {
		"name": "Torpedo Rack Mk II",
		"category": "weapon",
		"family": "torp",
		"tier": 2,
		"power": 6,
		"price": 17500,
		"desc": "Heavier charge, wider kill radius. Eats the power budget.",
		# 6 power is the most expensive mount in the catalog on purpose: a dual
		# torpedo fit costs 12 of an 18-point Mk III reactor, which leaves no
		# room for a utility. Area damage should have to give something up.
		"stats": {"damage": 128.0, "interval": 1.6, "range": 10.0, "chain": 0, "splash": 2.9},
	},
	"drive_cruise": {
		"name": "Cruise Drive",
		"category": "drive",
		"tier": 1,
		"power": 2,
		"price": 0,
		"desc": "High sustained speed, lazy handling.",
		"stats": {"max_speed": 3.5, "accel": 5.0, "turn_rate": 2.0},
	},
	"drive_vector": {
		"name": "Vector Drive",
		"category": "drive",
		"tier": 1,
		"power": 3,
		"price": 5000,
		"desc": "Vectored thrust. Sharp handling at the cost of top speed.",
		"stats": {"max_speed": 1.0, "accel": 13.0, "turn_rate": 6.0},
	},
	# Mk II drives and utilities. Same identity, higher numbers, heavy prices —
	# deliberately NOT new mechanics. The catalog's job is to make the five slots
	# argue with each other; a tier that changed what a module DOES would make it
	# a sixth family instead, and the power budget already has enough to say.
	"drive_cruise_2": {
		"name": "Cruise Drive Mk II",
		"category": "drive",
		"tier": 2,
		"power": 3,
		"price": 12000,
		"desc": "Longer burn, same lazy hands.",
		"stats": {"max_speed": 5.0, "accel": 6.5, "turn_rate": 2.4},
	},
	"drive_vector_2": {
		"name": "Vector Drive Mk II",
		"category": "drive",
		"tier": 2,
		"power": 4,
		"price": 14000,
		"desc": "Tighter gimbals. Turns inside anything out here.",
		"stats": {"max_speed": 1.6, "accel": 17.0, "turn_rate": 8.0},
	},
	"util_tractor": {
		"name": "Tractor Rig",
		"category": "utility",
		"tier": 1,
		"power": 2,
		"price": 2700,
		"desc": "Wide-field collector. More reach, richer yield.",
		"stats": {"magnet_range": 5.0, "salvage_mult": 0.25},
	},
	"util_shield": {
		"name": "Shield Capacitor",
		"category": "utility",
		"tier": 1,
		"power": 3,
		"price": 4700,
		"desc": "Buffer bank. Absorbs more, recovers faster.",
		"stats": {"shield_max": 70.0, "shield_regen": 5.0},
	},
	"util_cargo": {
		"name": "Cargo Bay",
		"category": "utility",
		"tier": 1,
		"power": 2,
		"price": 4000,
		"desc": "Expanded hold. Room for what the ports actually want.",
		# Competes with shield/tractor/scanner for the one utility slot, so a
		# trading build has to give something up to a combat build.
		"stats": {"cargo_space": 26.0},
	},
	"util_scanner": {
		"name": "Targeting Scanner",
		"category": "utility",
		"tier": 1,
		"power": 3,
		"price": 6100,
		"desc": "Firing solutions at range, and a lens that reads a wreck.",
		"stats": {"weapon_range_bonus": 2.0, "crit_chance": 0.22, "survey_speed": 0.35},
	},
	"util_repair": {
		"name": "Repair Bay",
		"category": "utility",
		"tier": 1,
		"power": 2,
		"price": 5200,
		"desc": "Automated hull crew. Recovers between fights, not during them.",
		# Deliberately regen-only, with no buffer: it competes with the Shield
		# Capacitor, and the choice between "survive a bigger hit" and "be ready
		# sooner" is the interesting part. Regen is gated behind SHIELD_CALM_DELAY,
		# so this never turns a fight into a stalemate.
		"stats": {"shield_regen": 11.0},
	},
	"util_repair_2": {
		"name": "Repair Bay Mk II",
		"category": "utility",
		"tier": 2,
		"power": 3,
		"price": 13500,
		"desc": "Full fabrication crew. You are never down for long.",
		"stats": {"shield_regen": 19.0},
	},
	"util_tractor_2": {
		"name": "Tractor Rig Mk II",
		"category": "utility",
		"tier": 2,
		"power": 3,
		"price": 12500,
		"desc": "Wider field, finer sorting. Nothing drifts past.",
		"stats": {"magnet_range": 9.0, "salvage_mult": 0.45},
	},
	"util_shield_2": {
		"name": "Shield Capacitor Mk II",
		"category": "utility",
		"tier": 2,
		"power": 4,
		"price": 17000,
		"desc": "Deeper bank, faster recovery between waves.",
		"stats": {"shield_max": 120.0, "shield_regen": 9.0},
	},
	"util_cargo_2": {
		"name": "Cargo Bay Mk II",
		"category": "utility",
		"tier": 2,
		"power": 3,
		"price": 15000,
		"desc": "Racked deep. A trading run stops being two trips.",
		# A hold this size is what makes contraband running viable, and also what
		# makes an interdiction expensive — the two halves of the same choice.
		"stats": {"cargo_space": 46.0},
	},
	"util_scanner_2": {
		"name": "Targeting Scanner Mk II",
		"category": "utility",
		"tier": 2,
		"power": 4,
		"price": 19500,
		"desc": "Reads plating like a map, and the dark like a page.",
		"stats": {"weapon_range_bonus": 3.2, "crit_chance": 0.34, "survey_speed": 0.60},
	},
	# --- mining tools ---------------------------------------------------------
	# The fit half of the mining verb. Deliberately TWO axes rather than one
	# bigger number: the Cutting Head buys SPEED and the Assay Rig buys YIELD, so
	# a prospector with one slot spare has a question to answer rather than a
	# strictly-better module to buy.
	#
	# Neither is a rig. rig_prospector is the whole-ship commitment that pays for
	# mining in reach, punch and hull; these are tools, and each costs one clean
	# thing. There are only TWO utility slots, so the three mining modules can
	# never all be fitted at once — that is the constraint that stops a
	# prospector from also being a warship, and PYXIS_MINETEST asserts it rather
	# than trusting it.
	"util_cutter": {
		"name": "Cutting Head",
		"category": "utility",
		"tier": 1,
		"power": 3,
		"price": 5600,
		"desc": "A boom, a torch and a grapple. Rock opens faster; corners do not.",
		"stats": {"mining_rate": 0.35, "turn_rate": -1.6},
	},
	"util_assay": {
		"name": "Assay Rig",
		"category": "utility",
		"tier": 2,
		"power": 4,
		"price": 15200,
		"desc": "Reads the face before the cut, and takes what an eye would leave.",
		# ore_yield is FLAT (+1 unit), not a multiplier, and that is the anti-farm
		# gradient talking: one more unit of band-1 ore is 65 credits, one more of
		# band-4 is 196. A multiplier rounded to whole units would have paid the
		# shallow band best in percentage terms, which is exactly backwards — the
		# expanse resets on a warp, so the reachable band must stay the poor one.
		"stats": {"ore_yield": 1.0, "shield_max": -30.0},
	},

	# --- specialist rigs (v7) -------------------------------------------------
	# Every one of these is a TRADE, expressed as negative stats on the same
	# additive pile everything else uses. A hauler really is slower; a strike rig
	# really does throw cargo overboard to get there. Nothing here is a strict
	# upgrade, which is the whole point of giving the ship a second utility slot:
	# two specialist rigs make a ship that is unmistakably built FOR something,
	# and unmistakably bad at the rest.
	# --- phase 6: the forge ---------------------------------------------------
	# Craftables. Four things no counter anywhere will sell you, made from what
	# archeology reads out of the deep — which is the whole gate: components are
	# `no_retail`, they exist only as reads, and a read is band-locked, so the
	# forge is transitively ARCHEOLOGY-gated with no new machinery at all. A
	# CHEMISTRY skill would have been circular (19: craft to level crafting to
	# unlock crafting), and found-recipes would put a die roll inside the one
	# system whose doctrine is that there is no roll in the conversion.
	#
	# Every one carries a WORLD effect — something that changes what happens to
	# you, never a number on the stat strip — and every one is DELIBERATELY
	# WEAKER than the carried item it is made from. A Baffle Array quietens you
	# less than a Forged Manifest does. If a craft were strictly better, one trip
	# to the forge would permanently obsolete carrying anything, and 19's pair
	# design ("the most valuable haul is also the loudest") would be deleted by
	# a bench.
	#
	# `price: 0` and never stocked: GameState.buy() would SUCCEED at price 0, so
	# the guarantee is absence from every stock list, asserted rather than priced.
	"mod_baffle": {
		"name": "Baffle Array",
		"category": "utility",
		"tier": 2,
		"power": 4,
		"price": 0,
		"desc": "Reads cold to a passing scan. Not as cold as a good forgery.",
		"craft": {"manifest_forged": 1, "plate_ablative": 2},
		"stats": {"shield_max": -25.0},
	},
	"mod_sink_lattice": {
		"name": "Sink Lattice",
		"category": "utility",
		"tier": 2,
		"power": 4,
		"price": 0,
		"desc": "Drinks a pulse before it reaches the drives. Heavy with it.",
		"craft": {"sink_thermal": 1, "rod_decay": 2},
		"stats": {"max_speed": -0.9},
	},
	"mod_survey_array": {
		"name": "Survey Array",
		"category": "utility",
		"tier": 2,
		"power": 5,
		"price": 0,
		"desc": "Answers a berth beacon from a long way out. Nothing else.",
		"craft": {"index_cartographic": 1, "lattice_data": 2},
		"stats": {"crit_chance": -0.10, "weapon_range_bonus": -1.0},
	},
	"mod_resonance": {
		"name": "Resonance Probe",
		"category": "utility",
		"tier": 2,
		"power": 4,
		"price": 0,
		"desc": "Hums when a hull is rigged. Costs you a mount to hear it.",
		"craft": {"heart_reliquary": 1, "servo_prewar": 2},
		"stats": {"turn_rate": -1.2},
	},

	"rig_hauler": {
		"name": "Hauler Frame",
		"category": "utility",
		"tier": 2,
		"power": 3,
		"price": 11500,
		"desc": "Racked out for volume. Handles like the warehouse it is.",
		"stats": {"cargo_space": 34.0, "max_speed": -1.4, "turn_rate": -2.2, "accel": -2.5},
	},
	"rig_prospector": {
		"name": "Prospector Rig",
		"category": "utility",
		"tier": 2,
		"power": 4,
		"price": 13000,
		"desc": "Cutting gear and ore sorters. Everything else gives way to it.",
		# This comment used to read "this game's mining IS salvage yield, so a
		# prospector is a salvage specialist" -- an honest description of a game
		# that had no mining verb. It does now (see mineable_seam.gd), so the rig
		# is the mining rig, and hauling more salvage is the second thing it does
		# rather than the whole of it. It pays for both in reach and punch.
		#
		# mining_rate is a new stat key and needed no schema change: compute_stats
		# sums unknown keys additively, exactly as survey_speed already relies on.
		"stats": {"mining_rate": 0.55,
			"salvage_mult": 0.85, "magnet_range": 8.0, "cargo_space": 12.0,
			"max_speed": -1.1, "weapon_range_bonus": -1.5, "shield_max": -20.0},
	},
	"rig_strike": {
		"name": "Strike Frame",
		"category": "utility",
		"tier": 2,
		"power": 4,
		"price": 14500,
		"desc": "Everything not bolted to a gun has been thrown out of the airlock.",
		"stats": {"crit_chance": 0.20, "weapon_range_bonus": 1.8, "max_speed": 1.2,
			"accel": 3.0, "cargo_space": -14.0, "shield_max": -25.0},
	},
	"rig_bulwark": {
		"name": "Bulwark Plating",
		"category": "utility",
		"tier": 2,
		"power": 4,
		"price": 15500,
		"desc": "Ablative slabs over every face. Nothing gets through quickly.",
		"stats": {"shield_max": 150.0, "shield_regen": 4.0, "max_speed": -1.6,
			"turn_rate": -2.6, "cargo_space": -8.0},
	},
	"rig_runner": {
		"name": "Runner Frame",
		"category": "utility",
		"tier": 2,
		"power": 3,
		"price": 12500,
		"desc": "Stripped to the spars. Outruns anything that wants a word.",
		"stats": {"max_speed": 2.6, "accel": 7.0, "turn_rate": 3.0,
			"cargo_space": -10.0, "shield_max": -30.0},
	},
	"core_overcharge": {
		"name": "Overcharge Core",
		"category": "core",
		"tier": 1,
		"power": 2,
		"price": 0,
		"desc": "Discharge blast, then the mounts run hot for four seconds.",
		"ability": {
			"id": "overcharge",
			"name": "OVERCHARGE",
			"duration": 4.0,
			"cooldown": 12.0,
			"accent": "amber",
		},
		"stats": {},
	},
	"core_surge": {
		"name": "Surge Core",
		"category": "core",
		"tier": 1,
		"power": 3,
		"price": 5400,
		"desc": "Emergency burn. Closes or breaks distance fast.",
		"ability": {
			"id": "surge",
			"name": "SURGE",
			"duration": 2.5,
			"cooldown": 10.0,
			"accent": "teal",
		},
		"stats": {},
	},
	"core_aegis": {
		"name": "Aegis Core",
		"category": "core",
		"tier": 1,
		"power": 4,
		"price": 9400,
		"desc": "Projects a hardened bubble. Nothing gets through.",
		"ability": {
			"id": "aegis",
			"name": "AEGIS",
			"duration": 3.0,
			"cooldown": 16.0,
			"accent": "teal",
		},
		"stats": {},
	},
}

const STARTER_FIT := {
	Slot.WEAPON_A: "pulse_1",
	Slot.WEAPON_B: "pulse_1",
	Slot.DRIVE: "drive_cruise",
	Slot.UTILITY: "",
	Slot.UTILITY_B: "",
	Slot.CORE: "core_overcharge",
}

const STARTER_OWNED := ["pulse_1", "drive_cruise", "core_overcharge"]


static func get_module(id: String) -> Dictionary:
	return MODULES.get(id, {})


static func exists(id: String) -> bool:
	return MODULES.has(id)


static func modules_for_slot(slot: int) -> Array:
	# Catalog order, filtered to what this slot accepts.
	var category: String = SLOT_CATEGORY.get(slot, "")
	var out := []
	for id in MODULES:
		if MODULES[id]["category"] == category:
			out.append(id)
	return out


static func default_slot(id: String, fit: Dictionary) -> int:
	# Where this module would go if the player bought it now. The store sells
	# without a slot chip to point at, so a delta shown there has to pick one, and
	# picking wrong makes the preview a lie: previewing a second Cargo Bay into
	# the slot already holding one would report no change at all.
	#
	# First EMPTY slot of the right category, falling back to the first of that
	# category -- which is what equipping into a full pair actually does.
	if not exists(id):
		return -1
	var category: String = MODULES[id]["category"]
	var first := -1
	for slot in SLOT_CATEGORY:
		if SLOT_CATEGORY[slot] != category:
			continue
		if first < 0:
			first = slot
		if not exists(String(fit.get(slot, ""))):
			return slot
	return first


static func power_draw(fit: Dictionary) -> int:
	var total := 0
	for slot in fit:
		var id: String = fit[slot]
		if exists(id):
			total += int(MODULES[id]["power"])
	return total


static func reactor_power(tier: int) -> int:
	var t := clampi(tier, 0, REACTOR_TIERS.size() - 1)
	return int(REACTOR_TIERS[t]["power"])


static func is_craftable(id: String) -> bool:
	return get_module(id).has("craft")


static func recipe(id: String) -> Dictionary:
	return get_module(id).get("craft", {})


static func craftable_ids() -> Array:
	var out: Array = []
	for id in MODULES:
		if (MODULES[id] as Dictionary).has("craft"):
			out.append(String(id))
	return out


static func compute_stats(fit: Dictionary) -> Dictionary:
	# Single source of truth for derived stats. Additive by design: it stays
	# legible in the console, and nothing needs stacking-penalty rules yet.
	var s := BASE.duplicate(true)
	s["weapons"] = []

	for slot in [Slot.WEAPON_A, Slot.WEAPON_B]:
		var id: String = fit.get(slot, "")
		if not exists(id):
			continue
		var m: Dictionary = MODULES[id]
		var w: Dictionary = (m["stats"] as Dictionary).duplicate()
		w["id"] = id
		w["family"] = m.get("family", "pulse")
		w["slot"] = slot
		(s["weapons"] as Array).append(w)

	for slot in [Slot.DRIVE, Slot.UTILITY, Slot.UTILITY_B, Slot.CORE]:
		var id: String = fit.get(slot, "")
		if not exists(id):
			continue
		for key in (MODULES[id]["stats"] as Dictionary):
			s[key] = s.get(key, 0.0) + MODULES[id]["stats"][key]

	var core_id: String = fit.get(Slot.CORE, "")
	s["ability"] = MODULES[core_id].get("ability", {}) if exists(core_id) else {}

	# Specialist rigs carry real negative stats and two of them can stack, so the
	# floors below are load-bearing: a hauler plus a bulwark must be sluggish, not
	# stationary or reversing.
	s["max_speed"] = maxf(float(s["max_speed"]), 1.6)
	s["accel"] = maxf(float(s["accel"]), 3.0)
	s["turn_rate"] = maxf(float(s["turn_rate"]), 1.5)
	s["shield_max"] = maxf(float(s["shield_max"]), 40.0)
	s["cargo_space"] = maxf(float(s.get("cargo_space", 24.0)), 6.0)
	s["weapon_range_bonus"] = maxf(float(s["weapon_range_bonus"]), -2.0)

	# Headline numbers the console shows as deltas.
	var dps := 0.0
	var reach := 0.0
	for w in s["weapons"]:
		dps += float(w["damage"]) / maxf(float(w["interval"]), 0.01)
		reach = maxf(reach, float(w["range"]))
	s["dps"] = dps * (1.0 + float(s["crit_chance"]) * 0.5)
	s["reach"] = reach + float(s["weapon_range_bonus"]) if reach > 0.0 else 0.0
	return s


static func summary_lines(stats: Dictionary) -> Array:
	# (label, value) pairs for the refit console's stat row.
	#
	# THIS LIST IS THE WHOLE OF WHAT A PLAYER CAN SEE. It is hardcoded, so a
	# module whose upside lives in a key that is not on it reads in the console as
	# pure downside -- which is what both mining tools did when they were first
	# written: the Cutting Head showed a HANDLING penalty and nothing else, and
	# the Assay Rig a SHIELD penalty and nothing else. Nobody buys either. The
	# design contract at the top of this file says every module is "legible - few
	# stats, all surfaced as deltas in the refit console", and a stat the console
	# cannot draw breaks it however correctly the stat behaves at the rock face.
	var out := [
		["DPS", "%.0f" % stats["dps"]],
		["REACH", "%.1f" % stats["reach"]],
		["SPEED", "%.1f" % stats["max_speed"]],
		["HANDLING", "%.1f" % stats["turn_rate"]],
		["SHIELD", "%.0f" % stats["shield_max"]],
		["SALVAGE", "%.0f%%" % (float(stats["salvage_mult"]) * 100.0)],
		["HOLD", "%.0f" % stats.get("cargo_space", 24.0)],
	]
	# CONDITIONAL, and that was once a hard layout ceiling: these were cells in a
	# plain HBoxContainer on a 720-wide portrait phone, so seven was already tight
	# and an eighth had to earn its place. The row is an HFlowContainer now and
	# wraps, which is what makes the block below affordable at all -- but
	# conditional is still right on editorial grounds. A ship with no cutting gear
	# must not spend two columns saying "none", and a pair that appears and
	# disappears together means comparing two tools never moves the other columns.
	var rate := float(stats.get("mining_rate", 0.0))
	var extra := float(stats.get("ore_yield", 0.0))
	if rate != 0.0 or extra != 0.0:
		out.append(["CUT", "%.0f%%" % ((1.0 + rate) * 100.0)])
		out.append(["ORE", "+%d" % int(extra)])

	# EVERYTHING BELOW WAS INVISIBLE, and the two Repair Bays are the reason this
	# had to change: shield_regen was their ONLY stat, so fitting a 13,500-credit
	# module moved not one number on this strip. The player was asked to buy an
	# effect the console could not draw. Six stats were in that state, and the
	# audit that found them is the one worth repeating -- diff every key any
	# module writes against every key this function reads.
	#
	# Each is shown only when something has actually moved it off the hull's own
	# figure, so a bare starter ship still reads as seven columns.
	if not is_equal_approx(float(stats.get("shield_regen", 0.0)), float(BASE["shield_regen"])):
		out.append(["REGEN", "%.0f/s" % float(stats["shield_regen"])])
	if not is_equal_approx(float(stats.get("accel", 0.0)), float(BASE["accel"])):
		# The Vector Drive's whole identity. It reads as SPEED -2.5 against the
		# Cruise and nothing else, which is why it looked like a downgrade.
		out.append(["ACCEL", "%.0f" % float(stats["accel"])])
	if not is_equal_approx(float(stats.get("magnet_range", 0.0)), float(BASE["magnet_range"])):
		out.append(["PULL", "%.0f" % float(stats["magnet_range"])])
	if float(stats.get("survey_speed", 0.0)) != 0.0:
		out.append(["SURVEY", "+%.0f%%" % (float(stats["survey_speed"]) * 100.0)])

	# chain and splash are NOT flat keys. compute_stats folds drive/utility/core
	# stats into the top level but keeps weapon stats per-weapon in `weapons`, so
	# reading stats["chain"] finds nothing and always did -- which is precisely
	# how the Arc and Torpedo families shipped with their defining trait unsaid.
	var chain := 0
	var splash := 0.0
	for w_v in stats.get("weapons", []):
		var w: Dictionary = w_v
		chain = maxi(chain, int(w.get("chain", 0)))
		splash = maxf(splash, float(w.get("splash", 0.0)))
	if chain > 0:
		out.append(["CHAIN", "+%d" % chain])
	if splash > 0.0:
		out.append(["SPLASH", "%.1f" % splash])

	# Cores carry an empty `stats` and all three therefore moved nothing at all.
	# The description says what the ability feels like; these are the two numbers
	# it never gave you, and a 9,400-credit core against a free one is exactly the
	# comparison they decide.
	var ability: Dictionary = stats.get("ability", {})
	if not ability.is_empty():
		out.append([String(ability.get("name", "ABILITY")),
			"%.1fs/%.0fs" % [float(ability.get("duration", 0.0)), float(ability.get("cooldown", 0.0))]])
	return out


static func delta_lines(before: Dictionary, after: Dictionary) -> Array:
	# [label, before, after] for every cell that MOVES, and nothing else. One
	# source of truth so the refit console and the store cannot drift apart.
	#
	# Label-keyed rather than index-keyed, because summary_lines is conditional:
	# fitting a Repair Bay ADDS a REGEN column that was not there a moment ago,
	# and a positional diff would report every column after it as changed. A cell
	# missing from one side reads as an em dash, which is honest -- "this ship has
	# no answer for that yet" is different from "this ship scores zero".
	var b := {}
	var order := []
	for pair in summary_lines(before):
		b[String(pair[0])] = String(pair[1])
		order.append(String(pair[0]))
	var a := {}
	for pair in summary_lines(after):
		a[String(pair[0])] = String(pair[1])
		if not order.has(String(pair[0])):
			order.append(String(pair[0]))

	var out := []
	for label in order:
		var was: String = b.get(label, "—")
		var now: String = a.get(label, "—")
		if was != now:
			out.append([label, was, now])
	return out
