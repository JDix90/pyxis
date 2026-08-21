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
	# Mining's contract, and the reason it is FERRITE: a band-1 seam is the only
	# ore a player can reach on their first warp out, and ferrite is the metal it
	# yields. A consignment the new prospector cannot fill would teach the wrong
	# thing about the verb it exists to advertise.
	#
	# 1,650 is chosen against the pacing band rather than for flavour.
	# _pacing_contract_yield measures the MEAN reward of everything PYX-01 offers,
	# and PACING_LOOP already sits at ~97% of its ceiling, so a ninth contract is
	# a lever on the whole economy. At 1,650 the mean moves 1,667.5 -> 1,665.6, so
	# EARNED falls by two credits. A round 2,000 would have raised it by 37 and
	# spent a tenth of the remaining headroom on a number nobody chose carefully.
	"haul_ore": {
		"title": "FOUNDRY CONSIGNMENT",
		"kind": "deliver",
		"good": "ore_ferrite",
		"target": 6,
		"dest": "cinderworks",
		"reward": 1650,
		"systems": [],
	},
	"crack_hull": {
		"title": "BREACH THE DERELICT",
		"kind": "breach",
		"target": 1,
		"reward": 1750,
		"systems": [],
	},

	# --- commissions (§95) ---------------------------------------------------
	# WORK POSTED BY A FACTION, and the first contract in this file that pays in
	# something other than credits. Two keys make a contract a commission:
	#
	#   "faction"  who posted it. It is offered ONLY to a pilot the faction
	#              already trusts (FRIENDLY or better), which is the same band
	#              their convoys will speak to you at -- so a commission is not
	#              a way IN, it is what being in is FOR.
	#   "standing" what finishing it is worth, and abandoning it costs DOUBLE.
	#              Keeping a promise is ordinary; breaking one is news.
	#
	# The credit rewards are deliberately BELOW the equivalent survey contract:
	# a commission trades money for a name, and a pilot who only wants money
	# should take the other row on the same board. The kinds are all shipped
	# kinds -- no new progress plumbing, so a commission cannot advance in a way
	# an ordinary contract cannot.
	#
	# Four of the seven convoy factions post work. The other three are data
	# away, deliberately left: a board where every faction always has something
	# is a board where the faction is decoration.
	"commission_league": {
		"title": "KEEP THE LANE OPEN",
		"kind": "kill_swarm",
		"target": 10,
		"reward": 900,
		"faction": "league",
		"standing": 1,
		"systems": [],
	},
	"commission_combine": {
		"title": "FEED THE FORGELINE",
		"kind": "earn_salvage",
		"target": 9000,
		"reward": 1200,
		"faction": "combine",
		"standing": 1,
		"systems": [],
	},
	"commission_bastion": {
		"title": "THIN THE ANCHORAGE WATCH",
		"kind": "kill_sentry",
		"target": 4,
		"reward": 1800,
		"faction": "bastion",
		"standing": 1,
		"systems": [],
	},
	"commission_grin": {
		"title": "OPEN SOMETHING THAT WAS SHUT",
		"kind": "breach",
		"target": 2,
		"reward": 1400,
		"faction": "grin",
		"standing": 1,
		"systems": [],
	},
}

# What abandoning a commission costs, as a multiple of what finishing it pays.
# TWO, and the asymmetry is the design: a pilot who takes a faction's work and
# walks away has told them something about themselves, and the board says so
# before the row is accepted.
const COMMISSION_BREAK_MULT := 2

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


static func faction_of(id: String) -> String:
	# Empty for an ordinary survey contract. One accessor so nothing else has to
	# know that a commission is "a contract with an extra key".
	return String(get_contract(id).get("faction", ""))


static func standing_of(id: String) -> int:
	return int(get_contract(id).get("standing", 0))


static func break_cost(id: String) -> int:
	return standing_of(id) * COMMISSION_BREAK_MULT


static func available_for(system_id: String, trusted := []) -> Array:
	# `trusted` is the list of faction ids this pilot is FRIENDLY or better
	# with, PASSED IN rather than read: this file is data and reaches for
	# nothing (0 references to GameState, and that is worth keeping -- the
	# contract catalog being pure is what lets a harness ask what a board would
	# hold for a standing the player does not have). Contracts.board is the one
	# caller that knows the player, and it is the one caller that fills this in.
	var out := []
	for id in CONTRACTS:
		var systems: Array = CONTRACTS[id].get("systems", [])
		if not (systems.is_empty() or systems.has(system_id)):
			continue
		var flag := faction_of(String(id))
		if flag != "" and not trusted.has(flag):
			continue
		out.append(id)
	return out


static func board_bucket(played_seconds: float) -> int:
	return int(played_seconds / BOARD_ROTATE_SECONDS)


static func board_for(port_id: String, system_id: String, played_seconds: float,
		trusted := []) -> Array:
	# Deterministic shuffle seeded by the port and the time bucket. Same port,
	# same bucket, same board — however many times you dock.
	var pool := available_for(system_id, trusted)
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
