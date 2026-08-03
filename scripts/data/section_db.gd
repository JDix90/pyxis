class_name SectionDB
extends Object
# THE SHIP IN PIECES, and which of them the damage has reached.
#
# The ship has exactly one survivability pool. `HULL 92%` on the readout is
# `PlayerShip.shield_fraction()` and always has been -- there is no second
# number and no located damage anywhere in the game. So this file does not
# INVENT damage; it READS the one number the game already keeps and says which
# parts of the ship that number has taken with it.
#
# That choice is what keeps combat untouched. A section being DAMAGED costs the
# player nothing by itself -- the integrity it is derived from has already been
# paid. Being damaged only means the section is a legal thing to DIVERT, which
# is the whole mechanic. Any other arrangement builds a death spiral: the pool
# IS the shield array, so letting a damaged array cut shield_max would knock out
# more sections, which would cut it again.
#
# The ladder is outside-in, which is the only order the fiction allows: a survey
# hull takes hits on its mounts before its spine, and whatever is doing the
# routing has to be the last thing standing or there is nobody to route with.
const SECTIONS := [
	{"id": "mount_b", "name": "STARBOARD MOUNT", "governs": "dps",
		"fails_at": 0.78, "blurb": "Outboard weapon hardpoint."},
	{"id": "drive", "name": "DRIVE COIL", "governs": "speed",
		"fails_at": 0.58, "blurb": "Main thrust and manoeuvring."},
	{"id": "mount_a", "name": "PORT MOUNT", "governs": "dps",
		"fails_at": 0.40, "blurb": "Inboard weapon hardpoint."},
	{"id": "array", "name": "SHIELD ARRAY", "governs": "shield",
		"fails_at": 0.22, "blurb": "Emitters and regeneration."},
	# NEVER FAILS, and that is not generosity. The core is what performs the
	# diversion; a ship whose core was out could not divert, so the panel would
	# go dead in exactly the moment it exists for.
	{"id": "core", "name": "REACTOR CORE", "governs": "core",
		"fails_at": -1.0, "blurb": "Routes power. Cannot be knocked out."},
]

# What an overcharge is worth, per governed system. Deliberately large: this is
# spent by permanently burning a section out, and a trade that costs a mount for
# +10% would never be worth taking, which would make the whole panel decoration.
const BOOST := {
	"dps": 1.60,
	"speed": 1.45,
	"shield": 1.50,
	"core": 1.75,
}

# What a burned-out section costs. A mount is half the guns, so burning one is
# the harshest of these by design -- weapons are what the player notices.
const BURN := {
	"dps": 0.50,
	"speed": 0.55,
	"shield": 0.60,
}


static func ids() -> Array:
	var out: Array = []
	for s_v in SECTIONS:
		out.append(String((s_v as Dictionary)["id"]))
	return out


static func section(id: String) -> Dictionary:
	for s_v in SECTIONS:
		var s: Dictionary = s_v
		if String(s["id"]) == id:
			return s
	return {}


static func is_section(id: String) -> bool:
	return not section(id).is_empty()


static func is_damaged(id: String, integrity: float) -> bool:
	# Pure over (section, integrity), so the panel, the assertions and any future
	# consumer all get the same answer instead of three that agree by luck.
	var s := section(id)
	if s.is_empty():
		return false
	var at := float(s["fails_at"])
	if at < 0.0:
		return false     # the core, which never fails
	return integrity < at


static func damaged_ids(integrity: float) -> Array:
	var out: Array = []
	for id_v in ids():
		var id := String(id_v)
		if is_damaged(id, integrity):
			out.append(id)
	return out


static func apply(stats: Dictionary, diverts: Dictionary) -> Dictionary:
	# Folds every live diversion into a fitted stat block. Called from
	# GameState._recompute so that everything downstream -- the ship, the refit
	# sheet, the balance harness -- reads one already-correct number rather than
	# each remembering to ask about diversions.
	#
	# BURN FIRST, THEN BOOST, and the order is load-bearing: a player who burns
	# a mount into the other mount must not have the boost computed against dps
	# that the burn is about to remove. Applied the other way round the trade
	# pays out on strength the ship no longer has.
	if diverts.is_empty():
		return stats
	for src_v in diverts:
		var src := SectionDB.section(String(src_v))
		if src.is_empty():
			continue
		_scale(stats, String(src["governs"]), float(BURN.get(String(src["governs"]), 1.0)))
	for src_v in diverts:
		var dst := SectionDB.section(String(diverts[src_v]))
		if dst.is_empty():
			continue
		_scale(stats, String(dst["governs"]), float(BOOST.get(String(dst["governs"]), 1.0)))
	return stats


static func _scale(stats: Dictionary, governs: String, mult: float) -> void:
	# The one place that knows which fitted keys a section actually moves. A
	# section governs a SYSTEM, not a stat key -- "speed" is two keys and
	# "shield" is two more -- so spelling that out here keeps the callers from
	# having to know it.
	match governs:
		"dps":
			stats["dps"] = float(stats.get("dps", 0.0)) * mult
		"speed":
			stats["max_speed"] = float(stats.get("max_speed", 0.0)) * mult
			stats["accel"] = float(stats.get("accel", 0.0)) * mult
		"shield":
			stats["shield_max"] = float(stats.get("shield_max", 0.0)) * mult
			stats["shield_regen"] = float(stats.get("shield_regen", 0.0)) * mult
		"core":
			# The core governs the fitted ability rather than a scalar, so an
			# overcharged core is read by PlayerShip at discharge time. Recorded
			# as a stat key so the panel has something to show and so nothing
			# downstream has to special-case the core's existence.
			stats["core_boost"] = float(stats.get("core_boost", 1.0)) * mult
