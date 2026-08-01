class_name DeepPortDB
extends Object
# Stations out past the chart.
#
# These are NOT in SystemDB, and that is the whole design of this file.
# `SystemDB.port_ids()` feeds the market-event roll, the cantina's
# O(goods x ports^2) rumour loop, and three separate PYXIS_STATIONTEST sweeps.
# Keeping the expanse out of that list means all of it is untouched by
# CONSTRUCTION rather than by argument — there is no code path by which a
# station 600 units off the map can start a shortage at the Anchor.
#
# What they are instead is a port def hung directly on the node (`Port.def`).
# `port_panel` reads `port.def` when it is set and falls back to
# `SystemDB.port_def_by_id` otherwise, which for every authored port is the same
# dictionary it always read, so docking behaviour is bit-identical.
#
# A def here is an ordinary port shape: `services` drives the tabs, `kind` picks
# the silhouette. No new panel class, no new port class, no new anything.
#
# --- THE ECONOMY'S GUARD RAIL ------------------------------------------------
# A module is bought at one station for `price * outfit_mult` and sold at another
# for `price * sellback`. So the invariant across the WHOLE chart plus everything
# here is:
#
#     max(sellback) < min(outfit_mult)
#
# Today that holds at 0.75 (Forgeline Depot) against 0.80 (the Grinning Void's
# grey market) — by luck, not by assertion, because the shipped check only ever
# compared that one hard-coded pair. Deep stations are exactly the thing that
# breaks it: one archetype at `outfit_mult 0.70`, another at `sellback 0.85`, and
# there is an infinite module laundry flown between two docks. Hence the two
# constants below, the fact that every def is checked against them, and the fact
# that PYXIS_STATIONTEST now does the full pairwise sweep instead of one pair.
const OUTFIT_FLOOR := 0.80
const SELLBACK_CEILING := 0.75

# Services are deliberately limited to the ones that are pure functions of the
# port def: market, outfitter, fence, repair. Contracts name chart destinations
# and paint is an indulgence you fly home for. Out here you trade, you refit,
# you unload what you should not be carrying, and you patch the hull.
#
# v16 ADDED ONE, and only to the furthest station out. This file used to say
# flatly that "rumours are the Cantina's trade in news of a chart these places
# are off", and for market gossip that is still exactly right -- a station 1,200
# units past the edge has nothing to say about a glut at the Anchor. But THE
# HUNT is not news of the chart; it is news of the deep, and the Last Watch is
# the only address in the game that is deeper than the thing being hunted. So it
# sells the sharpest bearing there is (+-5 degrees, 900 salvage) while the
# Cantina sells the vaguest (a band and a quadrant, 500), and the price of
# precision is measured in how far out you were willing to go to ask.
const ARCHETYPES := [
	{
		"id": "deep_relay",
		"name": "SHOAL RELAY",
		"kind": "station",
		# v18 stage 5: the frontier homesteaders. "Somebody has to be first out"
		# was always the League's line.
		"owner": "league",
		"min_band": 1,
		"freeport": true,
		"blurb": "A fuel spar and a shopfront. Somebody has to be first out.",
		# The first thing you find, and it is a MERCY: a market, and a repair bay
		# priced under a charted one. The Shoals have to teach that going out is
		# survivable, or nobody reaches the band where it pays.
		"services": ["market", "repair"],
		"bias": {"alloys": 1.10, "volatiles": 1.15, "isotopes": 1.05},
		"repair_price": 1000,
		"stock": [],
	},
	{
		"id": "deep_haven",
		"name": "THE LONG HAVEN",
		"kind": "den",
		"owner": "grin",
		"min_band": 2,
		"freeport": true,
		"blurb": "Nobody here asks what is in the crate.",
		# The best fence anywhere, and the reason to carry contraband OUTWARD
		# rather than back to a chart port. 1.45 against the Void's and the
		# Cantina's 1.25 — a fatter margin than the marquee smuggling route, paid
		# for by flying it through the Drift with a hold that draws raiders.
		"services": ["market", "fence", "repair"],
		"bias": {"contraband": 1.20, "stolen": 1.15, "relics": 1.10},
		"fence_goods": ["contraband", "stolen", "relics",
			"plate_ablative", "cell_fuel", "rod_decay", "sink_thermal", "lattice_data", "index_cartographic", "servo_prewar", "heart_reliquary", "manifest_forged", "charge_unstable"],
		"fence_mult": 1.45,
		"repair_price": 1300,
		"stock": [],
	},
	{
		"id": "deep_forge",
		"name": "THE COLD FORGE",
		"kind": "depot",
		"owner": "combine",
		"min_band": 2,
		"freeport": false,
		"blurb": "Somebody's yard, a long way from anybody's law.",
		# Where you rotate a fit without flying two systems home. The sell-back is
		# generous but sits UNDER the ceiling; the grey-market discount is real but
		# sits ABOVE the floor. Both numbers exist to be near the guard rail
		# without crossing it — that is what makes them interesting.
		"services": ["market", "outfitter", "repair", "forge"],
		"bias": {"alloys": 0.85, "isotopes": 1.25, "cores": 1.20},
		"sellback": 0.72,
		"outfit_mult": 0.90,
		"bulk_units": 10,
		"bulk_bonus": 0.05,
		"repair_price": 1200,
		"stock": ["drive_vector", "drive_cruise_2", "util_cargo", "util_cargo_2",
			"util_tractor", "util_tractor_2", "util_shield", "util_repair",
			"rig_hauler", "rig_prospector", "rig_runner",
			"util_cutter", "util_assay"],
	},
	{
		"id": "deep_yard",
		"name": "BLACKWATCH YARD",
		"kind": "military",
		"owner": "bastion",
		"min_band": 3,
		"freeport": false,
		"blurb": "Guns for the places nobody is coming to help you.",
		# The armoury of the Reaches. It sells the Mk II line and torpedoes at full
		# catalog — you are not here for a discount, you are here because this is
		# the only counter within four hundred units — and it pays handsomely for
		# what the deep drops.
		"services": ["market", "outfitter", "repair"],
		"bias": {"alloys": 1.35, "cores": 1.30, "relics": 1.35, "isotopes": 0.85},
		"sellback": 0.70,
		"outfit_mult": 1.05,
		"repair_price": 900,
		"stock": ["lance_2", "arc_2", "pulse_2", "torp_1", "torp_2",
			"util_shield_2", "util_scanner_2", "util_repair_2",
			"core_surge", "core_aegis", "rig_strike", "rig_bulwark"],
	},
	{
		"id": "deep_watch",
		"name": "THE LAST WATCH",
		"kind": "cantina",
		# NO OWNER, DELIBERATELY, and do not "fix" it. "Still lit. Nobody is
		# sure who is paying for it" is the hook stage 6 spends — the intended
		# answer is one of the three unknowns, and assigning it to a known
		# faction now would spend the best mystery in the port data on
		# tidiness. THE WATCH ANSWERS TO NOBODY asserts this stays true.
		"min_band": 4,
		"freeport": true,
		"blurb": "Still lit. Nobody is sure who is paying for it.",
		# The furthest thing out, and the best prices in the game for the things
		# only the deep produces. It fences as well as the Haven, because at this
		# range the distinction between a fence and a market has stopped meaning
		# anything to anyone.
		"services": ["market", "fence", "repair", "rumors"],
		"rumor_price": 700,
		"hunt_price": 900,
		"hunt_error": 5.0,
		"bias": {"relics": 1.45, "cores": 1.40, "contraband": 1.25, "stolen": 1.20},
		"fence_goods": ["relics", "cores", "contraband", "stolen",
			"plate_ablative", "cell_fuel", "rod_decay", "sink_thermal", "lattice_data", "index_cartographic", "servo_prewar", "heart_reliquary", "manifest_forged", "charge_unstable"],
		"fence_mult": 1.45,
		"repair_price": 800,
		"stock": [],
	},
]


static func count() -> int:
	return ARCHETYPES.size()


static func ids() -> Array:
	var out := []
	for a in ARCHETYPES:
		out.append(String((a as Dictionary)["id"]))
	return out


static func by_id(id: String) -> Dictionary:
	for a in ARCHETYPES:
		if String((a as Dictionary)["id"]) == id:
			return a
	return {}


static func is_deep_port(port_id: String) -> bool:
	# One prefix test, and it can never be true for a charted port id — which is
	# what keeps the chart's restriction map and STATIONTEST step 6 out of reach
	# of anything decided here.
	return port_id.begins_with("deep_")


static func for_band(band: int) -> Array:
	# Every archetype the expanse is deep enough to have built. The good ones sit
	# further out, so the reward for distance is a better counter and not merely a
	# bigger number on the same one.
	var out := []
	for a_v in ARCHETYPES:
		var a: Dictionary = a_v
		if band >= int(a["min_band"]):
			out.append(a)
	return out


static func violations() -> Array:
	# Self-check, printed by PYXIS_STATIONTEST. A def that breaks the guard rail
	# should be caught here by name rather than found later as a money printer.
	var bad := []
	for a_v in ARCHETYPES:
		var a: Dictionary = a_v
		var sb := float(a.get("sellback", 0.6))
		var om := float(a.get("outfit_mult", 1.0))
		if sb > SELLBACK_CEILING:
			bad.append("%s sellback %.2f > %.2f" % [a["id"], sb, SELLBACK_CEILING])
		if om < OUTFIT_FLOOR:
			bad.append("%s outfit_mult %.2f < %.2f" % [a["id"], om, OUTFIT_FLOOR])
	return bad
