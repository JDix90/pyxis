class_name CommissionDB
extends Object
# The Grand Commission: four stages of the survey authority acknowledging you.
#
# Names are past participles -- what the register says about you -- not verbs.
# The grammar is load-bearing, and it is the tripwire: IF A STAGE DESCRIPTION
# NEEDS AN IMPERATIVE VERB IT HAS BECOME A QUEST. With a participle directly
# above it, an imperative clashes audibly instead of relying on discipline to
# catch it. PYXIS_GSATEST's NO IMPERATIVE assertion checks the copy as data,
# because a structural rule nothing checks is worth nothing.
#
# It also sets up the finale: the commissioned beacon says CHARTS ON FILE, and
# "on file" was stage one.
#
# THRESHOLDS. Derived from PACING_LOOP's "survey": 2 per eight-minute standard
# loop against survey_mast.gd's YIELD_UNITS = 2 -- so a standard loop yields four
# chart units. 100 units is ~25 loops, which puts the finale at roughly the
# length of buying the whole catalog (337,400 salvage, ~20 loops, ~2.7 hours).
# That is the right size for a *Grand* Commission: it finishes when the game
# does. An earlier draft asked 320 units, which is ~10.7 hours inside a single
# run, since every counter here is run-scoped.
#
# These came from harness output, not from play. They are named constants in one
# table so a playtest moves four numbers and nothing else.
#
# EXCLUDED KEYS, deliberately: `tolls_paid`, because §26 killed toll-fed XP on
# the grounds that a toll is the losing move and paying for it twice is worse;
# and `distance_flown`, which is farmable in circles -- the printer shape §17's
# leash rule exists to prevent.
const STAGES := [
	{
		"name": "ON FILE",
		# Depth 1, not 160. The clause is "beyond the marker", and the marker is
		# the band-1 beacon, which fires at any depth above zero. Requiring two
		# bands out let a player cross the marker, file ten Shoal surveys, and be
		# told they had not done the thing the stage describes.
		"desc": "A first survey packet, logged against your registry.",
		"chart_data_sold": 8,
		"deepest_depth": 1,
		"hulks_cracked": 0,
		"posts_cleared": 0,
		"pays": 1800,
	},
	{
		"name": "CORROBORATED",
		"desc": "Independent readings agree with yours. The file thickens.",
		"chart_data_sold": 30,
		"deepest_depth": 160,
		"hulks_cracked": 20,
		"posts_cleared": 0,
		"pays": 2200,
	},
	{
		"name": "COMMENDED",
		# 440 is genuinely past the last repeater: BROADCASTS[2] is GSA RELAY --
		# LAST REPEATER and fires at 160.
		"desc": "Work of record, past the last repeater.",
		"chart_data_sold": 60,
		"deepest_depth": 440,
		"hulks_cracked": 45,
		"posts_cleared": 8,
		"pays": 2600,
	},
	{
		"name": "COMMISSIONED",
		"desc": "The register carries your name. Nothing out there answers to it.",
		"chart_data_sold": 100,
		"deepest_depth": 1100,
		"hulks_cracked": 80,
		"posts_cleared": 20,
		"pays": 2900,
	},
]

# The ledger keys a stage can gate on, and how each reads in a shortfall line.
# Order is the order they print, so a citation always reads the same way.
const REQUIREMENTS := [
	{"key": "chart_data_sold", "noun": "SURVEYS ON FILE"},
	{"key": "hulks_cracked", "noun": "HULLS OPENED"},
	{"key": "posts_cleared", "noun": "POSTS CLEARED"},
	{"key": "deepest_depth", "noun": "DEPTH REACHED"},
]

# NO IMPERATIVE's word list. A stage description is a statement of record; the
# moment one instructs, the Commission has become a quest board.
const IMPERATIVES := [
	"go", "fly", "find", "kill", "collect", "gather", "reach", "bring",
	"deliver", "destroy", "explore", "survey", "crack", "clear", "sell",
	"earn", "visit", "return", "complete", "defeat", "obtain", "acquire",
]


static func count() -> int:
	return STAGES.size()


static func stage(i: int) -> Dictionary:
	# Clamped rather than wrapped. posmod would turn a hand-edited 99 into a
	# plausible stage and pay out for it; a clamp turns it into "you are done".
	return STAGES[clampi(i, 0, STAGES.size() - 1)]


static func shortfalls(i: int, ledger: Dictionary) -> Array:
	# What is still outstanding, as STATEMENTS OF RECORD -- "44 OF 60 SURVEYS ON
	# FILE" -- never as instructions. There is deliberately no HUD tracker for
	# this anywhere in the game: the Commission is the authority describing you,
	# and the moment it starts telling you what to do next it is a quest log.
	var out: Array = []
	if i < 0 or i >= STAGES.size():
		return out
	var s: Dictionary = STAGES[i]
	for req_v in REQUIREMENTS:
		var req: Dictionary = req_v
		var need := int(s.get(req["key"], 0))
		if need <= 0:
			continue
		var have := int(ledger.get(req["key"], 0))
		if have < need:
			out.append("%d OF %d %s" % [have, need, req["noun"]])
	return out


static func met(i: int, ledger: Dictionary) -> bool:
	return shortfalls(i, ledger).is_empty()
