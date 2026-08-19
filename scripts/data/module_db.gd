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
enum Slot { WEAPON_A, WEAPON_B, DRIVE, UTILITY, CORE, UTILITY_B,
	# v24 (§94). THE BERTHS. Three slots no ship has until it is paid for, and
	# they are appended rather than inserted: the enum's integer values are
	# what `fit` is keyed by and what every save on disk holds, so putting a
	# new name in the middle would silently re-slot every fitted module in
	# every existing pilot's file.
	UTILITY_C, DRIVE_B, WEAPON_C }

const SLOT_NAMES := {
	Slot.WEAPON_A: "WEAPON I",
	Slot.WEAPON_B: "WEAPON II",
	Slot.DRIVE: "DRIVE",
	Slot.UTILITY: "UTILITY",
	Slot.CORE: "CORE",
	Slot.UTILITY_B: "UTILITY II",
	Slot.UTILITY_C: "UTILITY III",
	Slot.DRIVE_B: "DRIVE II",
	Slot.WEAPON_C: "WEAPON III",
}

# Which catalog category may be equipped in which slot.
const SLOT_CATEGORY := {
	Slot.WEAPON_A: "weapon",
	Slot.WEAPON_B: "weapon",
	Slot.DRIVE: "drive",
	Slot.UTILITY: "utility",
	Slot.CORE: "core",
	Slot.UTILITY_B: "utility",
	Slot.UTILITY_C: "utility",
	Slot.DRIVE_B: "drive",
	Slot.WEAPON_C: "weapon",
}

# v24 (§94). THE BERTHS, AND WHY THEY CARRY POWER.
#
# The playtest asked for purchasable slots. Research (the horizon doc's commit-2
# pass) found the obvious version is a bad product: greedy best-per-slot already
# draws 32 against the Mk V reactor's 24, and this file's own reactor note ends
# "and the second utility bay still empty". A pilot at the top of the game
# ALREADY owns a slot the reactor cannot feed, so selling them another would be
# ninety thousand credits for a bay that stays empty.
#
# So a berth is a slot AND the power to use it, and it is paid for in MASS --
# permanently, in the one axis the deep punishes hardest. That is what makes a
# fully berthed ship a deliberate build rather than a strict upgrade, and it
# cannot be bought back.
#
# EVERY BERTH ADDS LESS POWER THAN THE BEST MODULE THAT COULD OCCUPY IT
# (weapon 7, drive 4, utility 5), so the margin in ALL-BEST IS STILL OUT OF
# REACH narrows and never closes: with all three bought, greedy is 48 against a
# cap of 33. The assertion re-derives that from the live catalog rather than
# being re-pinned to a new constant, so a cheap new module still cannot close
# it and neither can a generous berth.
const BERTHS := {
	"berth_utility": {
		"name": "UTILITY BERTH", "slot": Slot.UTILITY_C,
		"price": 60000, "power": 3, "speed_cost": 0.25,
		"desc": "A third tool bay cut into the spine, with the bus to feed it. The hull was not designed around it.",
	},
	"berth_drive": {
		"name": "DRIVE BERTH", "slot": Slot.DRIVE_B,
		"price": 80000, "power": 2, "speed_cost": 0.30,
		"desc": "A second coil mount. Heavier bare — and the only berth whose own slot can pay the mass back.",
	},
	"berth_weapon": {
		"name": "WEAPON BERTH", "slot": Slot.WEAPON_C,
		"price": 120000, "power": 4, "speed_cost": 0.45,
		"desc": "A third hardpoint and the capacitors under it. The heaviest thing you can bolt to this hull.",
	},
}

# Budget curve. Starter fit draws 8, so Mk I leaves room to add a utility and
# try one weapon swap. The squeeze arrives when you want two heavy mounts, and
# not even the top tier carries a fit of all-best modules (27) — there is always
# a call to make.
#
# Phase 2 pricing: the reactor is the single most build-defining purchase in the
# game, so it should be the thing you save several sessions for, not an early
# formality. The top tier is deliberately the most expensive line in the catalog.
#
# MK IV, and what it is FOR. The budget was measured before it was changed, and
# the complaint that prompted it — "you cannot run a mining fit and a defensive
# fit at once" — turned out to be false at Mk III: rig_prospector + rig_bulwark
# over starter weapons, drive and core draws 16 of 18. What actually blocks that
# pairing is the TWO UTILITY SLOTS, which MINING COSTS A MOUNT asserts on
# purpose, and no amount of reactor would move it.
#
# So Mk IV does not exist to relieve that. It buys back the one trade the same
# assertion names: at 18 the prospector commit (16) cannot also carry a lance_1
# (4), and at 20 it can, exactly. That is the whole product — 55,000 credits to
# stop giving up your gun to be a prospector — and it is why the step is 2 and
# not 3. All-best is still 27 and still out of reach.
#
# Sold for credits, which makes it a SINK: PACINGTEST's binding MIDTIER clause is
# EARNED / lance_1's price, an income-only measure with no expenditure term, so a
# new tier cannot move it. It joins _pacing_catalog_cost's denominator instead
# and makes the already-slack CEILING ratio slacker. Re-measured, not reasoned
# about — see the sweep in STRATEGY §46.
const REACTOR_TIERS := [
	{"name": "Reactor Mk I", "power": 12, "price": 0},
	{"name": "Reactor Mk II", "power": 15, "price": 10000},
	{"name": "Reactor Mk III", "power": 18, "price": 32000},
	{"name": "Reactor Mk IV", "power": 20, "price": 55000},
	# v20 THE FRONTIER. A step of FOUR where every other step was two or three,
	# and like Mk IV's it is one named product rather than a percentage.
	#
	# At 20, a pair of Mk III heavy mounts (lance_3 6 + torp_3 7 = 13) plus a
	# Vector Mk II (4) and an Aegis (4) is 21 and does not fit. At 24 it fits
	# with exactly one 3-power tool — a Torch, a Runner Frame, a Repair Bay —
	# and the second utility bay still empty. That is the entire product: ninety
	# thousand credits to bring two Mk III mounts AND one tool to the Unsounded,
	# and no more than one.
	#
	# All-best stays out of reach, which is the invariant Mk IV was built to hold
	# and this must not break: greedy best-per-slot is 32 against 24, a margin of
	# 8 where Mk IV's was 7. Asserted from the live catalog rather than from these
	# numbers, so a cheap new module cannot quietly close it.
	{"name": "Reactor Mk V", "power": 24, "price": 90000},
]
# WHICH TIERS A COUNTER MAY SELL. A port def carries `reactor_cap`; absent, it
# means this — Mk IV, the shipped ceiling — so every charted counter keeps its
# behaviour by construction and only a def that says otherwise sells the Mk V.
#
# Without this the reactor row is money-only: GameState.upgrade_reactor checked
# nothing but the price, so the deepest purchase in the game would have been for
# sale at the Waypoint Anchor to anyone holding ninety thousand.
const REACTOR_CAP_DEFAULT := 3

# v24 (§94). WHICH COUNTERS CUT BERTHS IN. The same key that decides whether the
# Mk V is on the rack, read as a floor: a yard that cannot sell the reactor to
# run a berth has no business selling the berth. So berths appear exactly where
# the Mk V does — the deep yards — and the Waypoint Anchor does not become the
# place a new pilot buys a third hardpoint with their first windfall.
const BERTH_YARD_TIER := 4

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

	# --- Mk III: v20, THE FRONTIER, and sold only past the Quiet --------------
	# The Mk II doctrine one rung further out: same identity, higher numbers,
	# heavy prices, +1 power each. Deliberately NOT new mechanics — the new
	# MECHANICS in this stage are the three tools below, each of which carries a
	# cost, because 9 rejects a ladder whose rungs are all upside.
	#
	# WHY A LADDER IS ALLOWED TO EXIST AT ALL, given 9 calls "Mk I -> II -> III,
	# +10% each" a salvage sink rather than a decision: the decision is not WHICH
	# Mk III, it is whether a Mk III fits. Every one of these costs a power point
	# its Mk II did not, against a budget that grows by 4 and a catalog whose
	# best-in-slot draw grows by more. The choice a Mk III forces is what you take
	# OFF.
	#
	# The family shape is unchanged and still asserted: Pulse stays the efficient
	# generalist and must not out-damage a Lance of its own tier (133 against
	# 168), Arc buys chain and pays in reach, Torpedo buys splash and pays in
	# everything.
	"pulse_3": {
		"name": "Pulse Repeater Mk III",
		"category": "weapon",
		"family": "pulse",
		"tier": 3,
		"power": 4,
		"price": 21000,
		"desc": "Cycles faster than the eye follows. The cheap gun, grown up.",
		"stats": {"damage": 40.0, "interval": 0.30, "range": 8.0, "chain": 0},
	},
	"lance_3": {
		"name": "Lance Array Mk III",
		"category": "weapon",
		"family": "lance",
		"tier": 3,
		"power": 6,
		"price": 42000,
		"desc": "One shot, one hull. Reach nothing else in the game has.",
		# The longest reach and the highest single-target damage, and a dual
		# Lance fit is 12 of a 24-point Mk V — which is the whole budget minus a
		# drive and a core. Still a sacrifice, one tier up.
		"stats": {"damage": 158.0, "interval": 0.94, "range": 13.0, "chain": 0},
	},
	"arc_3": {
		"name": "Arc Projector Mk III",
		"category": "weapon",
		"family": "arc",
		"tier": 3,
		"power": 5,
		"price": 44000,
		"desc": "Four jumps. Built for whatever the deep sends in numbers.",
		# THE FRONTIER'S ANSWER TO ITS OWN PACKS. Bands 5 and 6 run 7-13 hostiles
		# with two escorts, and a fourth chain jump is the only thing in the
		# catalog that scales with how many of them there are.
		"stats": {"damage": 30.0, "interval": 0.38, "range": 7.0, "chain": 4},
	},
	"torp_3": {
		"name": "Torpedo Rack Mk III",
		"category": "weapon",
		"family": "torp",
		"tier": 3,
		"power": 7,
		"price": 40000,
		"desc": "A charge with a horizon. Nothing else empties a nest this fast.",
		# 7 power: the dearest mount in the game, and a dual torpedo fit is 14 of
		# 24 — a drive, a core and ONE tool, with a utility bay left empty. That
		# emptiness is the price, and it is meant to be felt.
		"stats": {"damage": 176.0, "interval": 1.55, "range": 11.0, "chain": 0, "splash": 3.6},
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

	# --- Mk III utilities: the defensive and survey line only ------------------
	# THREE, NOT SEVEN. Cargo and Tractor deliberately stop at Mk II: hauling
	# deeper is answered by the Expedition Frame below, which is a trade, and a
	# Mk III of everything would be a shopping list rather than a fitting
	# decision. What earns a third rung here is what the frontier actually kills
	# you with — a longer fight against more of them, further from a dock.
	"util_repair_3": {
		"name": "Repair Bay Mk III",
		"category": "utility",
		"tier": 3,
		"power": 4,
		"price": 30000,
		"desc": "Rebuilds between volleys. The reason a long fight is survivable.",
		"stats": {"shield_regen": 30.0},
	},
	"util_shield_3": {
		"name": "Shield Capacitor Mk III",
		"category": "utility",
		"tier": 3,
		"power": 5,
		"price": 38000,
		"desc": "A bank deep enough to cross a guarded wreck and still be standing.",
		"stats": {"shield_max": 180.0, "shield_regen": 13.0},
	},
	"util_scanner_3": {
		"name": "Targeting Scanner Mk III",
		"category": "utility",
		"tier": 3,
		"power": 5,
		"price": 42000,
		"desc": "Reads a hull, a seam and a horizon, and is wrong about none of them.",
		"stats": {"weapon_range_bonus": 4.5, "crit_chance": 0.45, "survey_speed": 0.85},
	},

	# --- the frontier's three tools -------------------------------------------
	# The NEW MECHANICS of this stage, and each one answers something the deep
	# past 2600u does specifically. Every one carries a cost, which SHIPTEST
	# asserts of the rigs and 16 states as the rule for all of them: a module
	# with no downside is a stat stick, not a fitting decision.
	#
	# Deliberately NOT built, and both for the same reason: an EMP-resist module
	# and a scan-masking module. The carried Thermal Sink and the crafted Sink
	# Lattice already own the first axis and the Forged Manifest and Baffle Array
	# the second, and a shop module that did their job would delete the
	# carried-beats-bought ladder those exist to teach.
	"util_torch": {
		"name": "Breaching Torch",
		"category": "utility",
		"tier": 3,
		"power": 3,
		"price": 22000,
		"desc": "Cuts a hull in half the time. Steers like a barge while it is lit.",
		# The frontier's crack times are 2.8s and 3.0s, held under three guns and
		# a trap — long enough that the hold itself is the danger. This is the
		# only module in the game that shortens it.
		"stats": {"breach_speed": 0.5, "turn_rate": -1.4},
	},
	"util_haste": {
		"name": "Surge Capacitors",
		"category": "utility",
		"tier": 3,
		"power": 4,
		"price": 30000,
		"desc": "The core comes back sooner. There is less of you while it does.",
		# Band 5/6 fights are longer, so a core that fires once per fight fires
		# twice. Paid for in the pool those fights are measured against.
		"stats": {"ability_haste": 0.25, "shield_max": -25.0},
	},
	"rig_expedition": {
		"name": "Expedition Frame",
		"category": "utility",
		"tier": 3,
		"power": 5,
		"price": 34000,
		"desc": "Rigged to stay out. Carries more, mends between fights, hits softer.",
		# The whole-ship commitment to a long way from home: hold, pull and regen
		# for crit and reach. A frame you fit to SURVIVE the trip rather than to
		# win the fight, which is the trade the other four rigs already model.
		"stats": {"cargo_space": 16.0, "magnet_range": 5.0, "shield_regen": 5.0,
			"max_speed": 0.4, "crit_chance": -0.10, "weapon_range_bonus": -1.0},
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


static func enforce_floors(s: Dictionary) -> Dictionary:
	# THE FLOORS, IN ONE PLACE, so anything that scales a fitted stat can put
	# them back afterwards. They used to be inline at the end of compute_stats,
	# which was fine while compute_stats was the last word on a stat block --
	# SectionDB.apply now runs AFTER it, and multiplied straight through them. A
	# legal Mk IV fit with two shield-negative rigs floors at 40 and came out of
	# a burned array at 27; PlayerShip.TETHER_DRAG_CEILING is sized directly
	# against the 1.6 max_speed floor with the note that being out-runnable by
	# any legal fit is the one promise that mechanic has to keep.
	s["max_speed"] = maxf(float(s["max_speed"]), 1.6)
	s["accel"] = maxf(float(s["accel"]), 3.0)
	s["turn_rate"] = maxf(float(s["turn_rate"]), 1.5)
	s["shield_max"] = maxf(float(s["shield_max"]), 40.0)
	s["cargo_space"] = maxf(float(s.get("cargo_space", 24.0)), 6.0)
	s["weapon_range_bonus"] = maxf(float(s["weapon_range_bonus"]), -2.0)
	return s


static func berth_power(berths) -> int:
	# What the bought berths add to the reactor's cap. Summed here rather than
	# in GameState so the number and the table that defines it cannot drift.
	var total := 0
	for id_v in berths:
		total += int((BERTHS.get(String(id_v), {}) as Dictionary).get("power", 0))
	return total


static func berth_mass(berths) -> float:
	# And what they cost in speed, permanently. Same argument as berth_power:
	# one table, one reader.
	var total := 0.0
	for id_v in berths:
		total += float((BERTHS.get(String(id_v), {}) as Dictionary).get("speed_cost", 0.0))
	return total


static func slots_of(category: String) -> Array:
	# EVERY SLOT OF A KIND, DERIVED. compute_stats used to carry two hand-written
	# slot lists, which is a trap with a name: a slot added to the enum and
	# forgotten in those lists would be purchasable, equippable and POWERED, and
	# would contribute nothing at all to the ship -- silently, with no error
	# anywhere. Reading SLOT_CATEGORY instead means the lists cannot go stale,
	# and EVERY SLOT REACHES THE STATS asserts it from the same table.
	var out: Array = []
	for slot_v in SLOT_CATEGORY:
		if String(SLOT_CATEGORY[slot_v]) == category:
			out.append(slot_v)
	return out


static func compute_stats(fit: Dictionary, berths := []) -> Dictionary:
	# Single source of truth for derived stats. Additive by design: it stays
	# legible in the console, and nothing needs stacking-penalty rules yet.
	#
	# `berths` is an OPTIONAL trailing argument (v24, §94) carrying the mass a
	# berthed hull is permanently down. Optional because this function is probed
	# speculatively all over -- cargo_after, the refit sheet's delta rows -- and
	# every one of those probes asks about cargo or DPS, where the berth mass is
	# irrelevant; the callers that describe the ship's SPEED pass it.
	var s := BASE.duplicate(true)
	s["weapons"] = []

	for slot in slots_of("weapon"):
		var id: String = fit.get(slot, "")
		if not exists(id):
			continue
		var m: Dictionary = MODULES[id]
		var w: Dictionary = (m["stats"] as Dictionary).duplicate()
		w["id"] = id
		w["family"] = m.get("family", "pulse")
		w["slot"] = slot
		(s["weapons"] as Array).append(w)

	for slot in slots_of("drive") + slots_of("utility") + slots_of("core"):
		var id: String = fit.get(slot, "")
		if not exists(id):
			continue
		for key in (MODULES[id]["stats"] as Dictionary):
			s[key] = s.get(key, 0.0) + MODULES[id]["stats"][key]

	# THE MASS, AFTER THE MODULES AND BEFORE THE FLOORS. A berth is welded to
	# the hull, so it is not a module that can be unfitted to get the speed
	# back -- and it goes through enforce_floors like everything else, so three
	# berths on a hauler cannot reverse the ship.
	if not berths.is_empty():
		s["max_speed"] = float(s.get("max_speed", 0.0)) - berth_mass(berths)

	var core_id: String = fit.get(Slot.CORE, "")
	s["ability"] = MODULES[core_id].get("ability", {}) if exists(core_id) else {}

	# Specialist rigs carry real negative stats and two of them can stack, so the
	# floors below are load-bearing: a hauler plus a bulwark must be sluggish, not
	# stationary or reversing.
	enforce_floors(s)

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
	# v20. The Breaching Torch's entire upside, and without this row it reads on
	# the console as HANDLING -1.4 and nothing else — the exact state the Cutting
	# Head and the Assay Rig shipped in, recorded in the paragraph above. A tool
	# whose benefit the strip cannot draw is a tool nobody buys.
	if float(stats.get("breach_speed", 0.0)) != 0.0:
		out.append(["BREACH", "+%.0f%%" % (float(stats["breach_speed"]) * 100.0)])

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
		# THE COOLDOWN IS SHOWN HASTED, because that is the number the ship will
		# actually run at and the Surge Capacitors have to be seen paying for
		# themselves here or they read as SHIELD -25 and nothing else. Same
		# arithmetic as PlayerShip.activate_ability, and one source for it:
		# ability_cooldown() is what both call.
		out.append([String(ability.get("name", "ABILITY")),
			"%.1fs/%.0fs" % [float(ability.get("duration", 0.0)),
				ability_cooldown(stats)]])
	return out


static func ability_cooldown(stats: Dictionary) -> float:
	# What the fitted core's cooldown actually is, haste folded in. The clamp is
	# not decoration: haste is additive across utilities, and two hypothetical
	# 0.25 modules in both bays would otherwise approach a free ability. 0.60 is
	# the floor, so the deepest possible discount is 40%.
	var ability: Dictionary = stats.get("ability", {})
	if ability.is_empty():
		return 0.0
	var haste := clampf(float(stats.get("ability_haste", 0.0)), 0.0, 0.40)
	return float(ability.get("cooldown", 0.0)) * (1.0 - haste)


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
