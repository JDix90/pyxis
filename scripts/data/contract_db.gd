class_name ContractDB
extends Object
# Survey contracts: small, data-defined objectives that give the loop direction.
# Two are active at a time; completing one immediately offers the next, so
# there is always a reason to keep flying.

#
# Rewards are ~0.7x their phase-1 values. Contracts are the steadiest income in
# the game — they pay for things the player was going to do anyway — so leaving
# them untouched while loot halved would have made them the only sane way to
# earn, and every other activity a rounding error. Asserted by PYXIS_PACINGTEST.
#
# kind: kill_swarm | kill_sentry | earn_salvage | breach
const CONTRACTS := {
	"sweep_swarm": {
		"title": "SWEEP THE SHALLOWS",
		"kind": "kill_swarm",
		"target": 6,
		"reward": 840,
		"systems": [],  # empty = offered anywhere
	},
	"sweep_swarm_big": {
		"title": "CLEAR THE NEST",
		"kind": "kill_swarm",
		"target": 14,
		"reward": 2100,
		"systems": [],
	},
	"cull_sentries": {
		"title": "CULL THE SENTRIES",
		"kind": "kill_sentry",
		"target": 3,
		"reward": 1550,
		"systems": [],
	},
	"cull_sentries_big": {
		"title": "SILENCE THE ANCHORAGE",
		"kind": "kill_sentry",
		"target": 6,
		"reward": 3500,
		"systems": ["pyx03"],
	},
	"haul_small": {
		"title": "FILL THE HOLD",
		"kind": "earn_salvage",
		"target": 4000,
		"reward": 700,
		"systems": [],
	},
	"haul_big": {
		"title": "DEEP SALVAGE RUN",
		"kind": "earn_salvage",
		"target": 12000,
		"reward": 2450,
		"systems": [],
	},
	# Delivery contracts point at ports that actually want the good, so filling
	# one teaches the trade map rather than sending you somewhere arbitrary.
	"haul_alloys": {
		"title": "ALLOY CONSIGNMENT",
		"kind": "deliver",
		"good": "alloys",
		"target": 6,
		"dest": "bastion",
		"reward": 1700,
		"systems": [],
	},
	"haul_isotopes": {
		"title": "ISOTOPE TRANSFER",
		"kind": "deliver",
		"good": "isotopes",
		"target": 4,
		"dest": "cinderworks",
		"reward": 2250,
		"systems": [],
	},
	"crack_hull": {
		"title": "BREACH THE DERELICT",
		"kind": "breach",
		"target": 1,
		"reward": 1750,
		"systems": [],
	},
}

const ACTIVE_SLOTS := 2

# --- the board (B2) ---------------------------------------------------------
# Contracts used to auto-assign: two appeared, and when one completed the next
# arrived unasked. That made them a to-do list handed to the player rather than
# work the player chose, and it meant the tracker could show a delivery contract
# to a port nobody was flying to.
#
# The board is offered at ports instead. The offer set is deterministic from
# (port, time bucket) rather than random, for two reasons: a player who docks,
# undocks and re-docks must not be able to reroll the board, and a board that
# rotates on a visible clock is something you can plan around.
const BOARD_SIZE := 5
const BOARD_ROTATE_SECONDS := 300.0   # a fresh board every five played minutes

# The pair the very first run starts with, so the tracker is never empty before
# the player has seen a port. Deliberately the two simplest objectives.
const STARTER_PAIR := ["sweep_swarm", "haul_small"]


static func get_contract(id: String) -> Dictionary:
	return CONTRACTS.get(id, {})


static func exists(id: String) -> bool:
	return CONTRACTS.has(id)


static func available_for(system_id: String) -> Array:
	var out := []
	for id in CONTRACTS:
		var systems: Array = CONTRACTS[id].get("systems", [])
		if systems.is_empty() or systems.has(system_id):
			out.append(id)
	return out


static func board_bucket(played_seconds: float) -> int:
	return int(played_seconds / BOARD_ROTATE_SECONDS)


static func board_for(port_id: String, system_id: String, played_seconds: float) -> Array:
	# Deterministic shuffle seeded by the port and the time bucket. Same port,
	# same bucket, same board — however many times you dock.
	var pool := available_for(system_id)
	if pool.is_empty():
		return []
	pool.sort()   # a stable base order, so the seed is the only thing that varies

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d" % [port_id, board_bucket(played_seconds)])
	# Fisher-Yates against the seeded stream.
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	return pool.slice(0, mini(BOARD_SIZE, pool.size()))


static func seconds_until_rotation(played_seconds: float) -> float:
	return BOARD_ROTATE_SECONDS - fmod(played_seconds, BOARD_ROTATE_SECONDS)


static func describe(id: String) -> String:
	# One line explaining what the objective actually asks for, so the board can
	# be read without already knowing the catalog.
	var c := get_contract(id)
	var target := int(c.get("target", 0))
	match String(c.get("kind", "")):
		"kill_swarm":
			return "Destroy %d swarm contacts." % target
		"kill_sentry":
			return "Destroy %d sentries." % target
		"earn_salvage":
			return "Bank %d salvage." % target
		"breach":
			return "Breach %d derelict hull%s." % [target, "" if target == 1 else "s"]
		"deliver":
			return "Deliver %d %s to %s." % [target,
				CommodityDB.short_name(String(c.get("good", ""))),
				String(SystemDB.port_def_by_id(String(c.get("dest", ""))).get("name", "?"))]
	return ""
