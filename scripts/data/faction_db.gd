class_name FactionDB
extends Object
# Factions as data. Stage 1 of Horizon 4 (docs/HORIZON-4-FACTIONS.md): the
# whole roster exists as ROWS from day one, but only the "feral" row is
# behaviour-live — it reproduces the shipped world exactly, so every existing
# spawner is untouched by construction. Later stages consume rows; they do not
# add columns.
#
# THIS CLASS IS A PURE LEAF, and that is a load-bearing constraint rather than
# tidiness. DeepSpace→ApexBoss→HUD→DeepSpace already demonstrated what Godot
# does with a cycle in the global class list: every class_name in the project
# becomes undeclared at once, in a boot that hangs rather than fails (STRATEGY
# §39). So FactionDB names NO scene class and NO autoload — anything that needs
# both a faction fact and game state goes through GameState, which is an
# autoload and therefore outside the class_name registry entirely. Attitude
# arithmetic that needs the player's deltas lives THERE, not here.

# --- the bands ---------------------------------------------------------------
# Five named bands, not a float. module_db.gd's design contract — constrained,
# legible, few stats — applies to diplomacy too: the band is the ONLY thing a
# targeting rule or a line of copy may read. The underlying attitude int exists
# so that standing can MOVE in steps smaller than a whole band; it is never
# shown and never compared against directly outside this file and GameState.
enum Band { ALLIED, FRIENDLY, NEUTRAL, WARY, HOSTILE }

const BAND_NAMES := ["ALLIED", "FRIENDLY", "NEUTRAL", "WARY", "HOSTILE"]

# The attitude scale. -6..6 with authored baselines at the extremes, so a
# faction that starts HOSTILE stays meaningfully hostile through a couple of
# good deeds — crossing a band boundary is supposed to be an arc, not a tap.
const ATTITUDE_MIN := -6
const ATTITUDE_MAX := 6
# How far a stored player-caused delta may run in either direction. Wider than
# the attitude span so a long grudge can be dug out of, bounded so the save can
# never carry an int that grew without limit.
const DELTA_SPAN := 12

# --- the skirmish clock (stage 3, finding A6) --------------------------------
# ONLY THE PLAYER DEPLETES THE WORLD. Once machines shoot each other, ambient
# combat has to be unable to resolve, or the world empties itself while nobody
# is watching.
#
# The numbers come from a measurement, not from taste. A picket and a sentry
# are the SAME MACHINE — both Hostile, both taking the system's difficulty,
# neither setting hp_scale — so 120hp against 14 damage every 1.15s is 9.9
# seconds to a kill, and because difficulty scales hp and damage together it is
# 9.9 seconds in EVERY system. Six seconds of fire cannot finish that, and
# twelve of standing down makes the border flare and settle rather than grind.
#
# HERE rather than on Hostile, so the two hostile classes share one number
# instead of two that agree by assertion — FactionDB is a pure leaf both of
# them already name, so this costs no new dependency and cannot cycle.
#
# The player is exempt from the clock entirely: fighting the player has no
# break-off, which is what keeps every balance figure ever measured still valid.
const SKIRMISH_TIME := 6.0
const SKIRMISH_REST := 12.0

# AND THE CLOCK ALONE IS NOT ENOUGH — measured, not assumed. Breaking off does
# not undo damage: at 12.17 dps a six-second burst lands 73, and three cycles
# inside a minute still pass 120hp. The first version of this shipped a census
# going 9 -> 5 in 54 unattended seconds, and AMBIENT COMBAT DEPLETES NOTHING is
# what caught it.
#
# So NPC-inflicted damage cannot take a machine below this fraction of its
# hull. Ambient skirmishing WEARS — a sentry sitting at half strength is
# visible evidence that the border is contested, which is the whole point of
# staging the fight where the player can find it — but the last half of any
# hull belongs to the player. Only the player depletes the world.
#
# HALF rather than a sliver: a machine that ambient fire could take to 5% would
# be a free kill left lying around, which is a stealth difficulty change nobody
# asked for. At 0.5 the player still does the majority of the work.
const SKIRMISH_HP_FLOOR := 0.5

# The one clamp settled at design time (HORIZON-4 §2): the Authority never
# treats the surveyor as HOSTILE. -3 is the WARY floor — one step short of the
# band where the Cordon would open fire. Outlaw-vs-the-Authority play is a
# deliberate design nobody has done yet, not an emergent accident.
const GSA_SURVEYOR_FLOOR := -3


static func band_of(attitude: int) -> int:
	# Symmetric thresholds, written out as ranges so the next reader does not
	# have to re-derive them:  -6..-4 HOSTILE, -3..-1 WARY, 0 NEUTRAL,
	# +1..+3 FRIENDLY, +4..+6 ALLIED. HOSTILE starting at -4 is what makes the
	# WARY floor of -3 (one step short) mean what it says.
	if attitude <= -4:
		return Band.HOSTILE
	if attitude <= -1:
		return Band.WARY
	if attitude == 0:
		return Band.NEUTRAL
	if attitude <= 3:
		return Band.FRIENDLY
	return Band.ALLIED


# --- the roster --------------------------------------------------------------
# Ids are SAVE KEYS and therefore permanent; display names are copy and can
# move. The three unknowns ship under stable placeholder ids with the deep
# guards' own designation as their display string — their names are stage-6
# session work (HORIZON-4 §9), and an id chosen now that presumed a name would
# be a save-migration waiting to happen.
#
# "surveyor" is the player. The player being an ordinary row is what makes
# standing and inter-faction attitude one mechanism instead of two.
#
# "feral" is the dead frontier's automated leftovers — every hostile the game
# spawns today. Its row is the shipped world: HOSTILE to the surveyor,
# indifferent to everything else. Stage 3 re-attributes each system's machines
# to its host engine; until then feral is the default every spawner gets for
# free.
const SURVEYOR := "surveyor"
const FERAL := "feral"

const FACTIONS := {
	"surveyor": {"name": "THE SURVEYOR"},
	"feral": {"name": "UNFLAGGED AUTOMATA"},
	"gsa": {"name": "GALACTIC SURVEY AUTHORITY", "force": "THE CORDON"},
	"gnomon": {"name": "HOST OF THE GNOMON"},
	"armillary": {"name": "HOST OF THE ARMILLARY"},
	"meridian": {"name": "HOST OF THE MERIDIAN"},
	"bastion": {"name": "THE BASTION CHARTER"},
	"combine": {"name": "THE FORGELINE COMBINE"},
	"embers": {"name": "THE EMBERS"},
	"grin": {"name": "THE GRIN"},
	"league": {"name": "THE RELAY LEAGUE"},
	"tithe": {"name": "THE TITHE"},
	"procession": {"name": "THE PROCESSION"},
	"unknown_a": {"name": "NO PATTERN ON FILE"},
	"unknown_b": {"name": "NO PATTERN ON FILE"},
	"unknown_c": {"name": "NO PATTERN ON FILE"},
}

# --- faction paint -----------------------------------------------------------
# THE PRECEDENCE RULE, written down as data because colour is the one
# glance-legible channel on a phone and it is already double-booked: band tint
# on deep guards, raid crimson on interdiction ships (HORIZON-4 finding A2).
#
#     faction > raid > band
#
# Allegiance outranks both because it is the thing combat decisions hang on.
# NOT WIRED IN STAGE 1 — no spawner reads this yet, which is what "the world
# is visibly unchanged" means. Stage 2 wires the Cordon's paint and owes the
# palette audit (14 faction tints x 3 band tints x colour-vision modes).
# feral carries no tint at all: unflagged machines keep whatever the band and
# the raid system were already painting, which is the whole meaning of the
# word.
const TINTS := {
	"gsa": Color(0.30, 0.75, 0.95),        # authority teal-blue, reads as "lawful"
	"gnomon": Color(0.85, 0.25, 0.85),     # the glitch-magenta the apex already flies
	"armillary": Color(1.00, 0.45, 0.20),  # ember orange, its system's palette
	"meridian": Color(0.45, 0.40, 1.00),   # anchorage indigo, likewise
	"tithe": Color(0.86, 0.12, 0.20),      # RAID_TINT verbatim: the raiders ARE the Tithe
}

# --- the baseline matrix -----------------------------------------------------
# Authored attitudes, ASYMMETRIC where the fiction is (the Authority is wary of
# the Grin; the Grin is hostile to the Authority). Only non-NEUTRAL entries are
# written; an absent pair is 0. Player-caused deltas (GameState.faction_deltas)
# apply symmetrically on top and are the only thing that ever moves — NO INPUT,
# NO DRIFT is the first assertion of PYXIS_FACTIONTEST.
#
# Only the "feral" and "surveyor" rows are consumed by any shipped behaviour in
# stage 1. Every other row is authored now so its save shape exists and its
# stage inherits data instead of inventing it — and is EXPECTED to be re-tuned
# by the stage that first consumes it. Do not treat these numbers as balanced;
# treat the feral row as frozen.
const BASELINE := {
	"feral": {"surveyor": -6},
	"surveyor": {"feral": -6, "gnomon": -6, "armillary": -6, "meridian": -6,
		"tithe": -4},
	# The Authority: order, democracy, prosperity — stated values, and a cordon
	# that shoots machines, not people. WARY of the smuggling network it cannot
	# catch, HOSTILE to the engines jamming its lanes and to the banner taxing
	# its charts.
	"gsa": {"gnomon": -6, "armillary": -6, "meridian": -6, "tithe": -5,
		"grin": -2, "bastion": 2, "league": 3, "embers": 1,
		"unknown_a": -2, "unknown_b": -2, "unknown_c": -2},
	# The engines hold their systems against everything that flies. They do not
	# hold opinions; they hold territory. Neutral to each other — they have
	# never met, and nothing in the data says they ever will.
	"gnomon": {"surveyor": -6, "gsa": -6, "bastion": -4, "combine": -4,
		"embers": -4, "grin": -4, "league": -4, "tithe": -4, "procession": -4},
	"armillary": {"surveyor": -6, "gsa": -6, "bastion": -4, "combine": -4,
		"embers": -4, "grin": -4, "league": -4, "tithe": -4, "procession": -4},
	"meridian": {"surveyor": -6, "gsa": -6, "bastion": -4, "combine": -4,
		"embers": -4, "grin": -4, "league": -4, "tithe": -4, "procession": -4},
	"bastion": {"gsa": 3, "tithe": -4, "grin": -2,
		"gnomon": -5, "armillary": -5, "meridian": -5},
	"combine": {"gsa": 1, "bastion": 1, "grin": 1, "embers": 1, "league": 2,
		"gnomon": -4, "armillary": -4, "meridian": -4},
	"embers": {"gsa": 1, "grin": 2, "combine": 1, "tithe": -1,
		"gnomon": -4, "armillary": -4, "meridian": -4},
	"grin": {"gsa": -4, "bastion": -2, "embers": 2, "tithe": -1, "combine": 1,
		"gnomon": -4, "armillary": -4, "meridian": -4},
	"league": {"gsa": 3, "combine": 2, "tithe": -3,
		"gnomon": -4, "armillary": -4, "meridian": -4},
	# The banner demands, it does not hate: hostile to the law and to the
	# surveyor's cargo, merely unwelcome everywhere else.
	"tithe": {"surveyor": -4, "gsa": -5, "bastion": -4, "league": -3,
		"gnomon": -4, "armillary": -4, "meridian": -4},
	"procession": {"gsa": -1, "bastion": -1, "combine": -1, "embers": -1,
		"grin": -1, "league": -1, "tithe": -2,
		"gnomon": -4, "armillary": -4, "meridian": -4},
	# The unknowns are WARY of everyone and everyone should be wary back — but
	# nobody on the chart has met them, so the known factions' rows say nothing
	# about them and these rows do not move until their stage.
	"unknown_a": {"surveyor": -2, "gsa": -2, "bastion": -2, "combine": -2,
		"embers": -2, "grin": -2, "league": -2, "tithe": -2, "procession": -2},
	"unknown_b": {"surveyor": -2, "gsa": -2, "bastion": -2, "combine": -2,
		"embers": -2, "grin": -2, "league": -2, "tithe": -2, "procession": -2},
	"unknown_c": {"surveyor": -2, "gsa": -2, "bastion": -2, "combine": -2,
		"embers": -2, "grin": -2, "league": -2, "tithe": -2, "procession": -2},
}


static func ids() -> Array:
	return FACTIONS.keys()


static func is_faction(id: String) -> bool:
	return FACTIONS.has(id)


static func display_name(id: String) -> String:
	return String((FACTIONS.get(id, {}) as Dictionary).get("name", "UNKNOWN"))


static func tint_of(id: String) -> Color:
	# Alpha 0 = "no faction paint": the same no-op sentinel Hostile.tint and
	# SwarmHostile.tint already use, so a spawner can pass it through blindly.
	return TINTS.get(id, Color(0.0, 0.0, 0.0, 0.0))


static func pair_key(a: String, b: String) -> String:
	# One canonical key per unordered pair, because deltas are symmetric: the
	# save must never carry both "a|b" and "b|a" with room to disagree.
	return "%s|%s" % [a, b] if a <= b else "%s|%s" % [b, a]


static func baseline_attitude(a: String, b: String) -> int:
	# DIRECTIONAL: how a feels about b. A pair with no authored entry is
	# NEUTRAL, which keeps the table above down to the pairs somebody actually
	# decided something about.
	if a == b:
		return ATTITUDE_MAX  # a faction is always ALLIED with itself
	return int((BASELINE.get(a, {}) as Dictionary).get(b, 0))
