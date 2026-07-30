class_name SystemDB
extends Object
# Star systems as data. Adding a system means adding a dictionary entry —
# SystemBuilder turns any of these into a live scene.
#
# Each system carries its own mood (environment/starfield/lattice/haze), its
# own encounter mix, and its own economy multipliers. The swarm-vs-sentry ratio
# is the important design lever: it makes fit choices situational across space,
# so refitting before a warp is a real decision.
#
# LAYOUT RULE (phase 2): every solid body registers a collision sphere, so
# placements must not overlap. A port sitting inside an asteroid's sphere is no
# longer a cosmetic mistake — it makes the port unreachable. Distances below are
# chosen with that in mind; `bounds` sets the camera pan limit and spawn clamp.

const START_SYSTEM := "pyx01"

const SYSTEMS := {
	"pyx01": {
		"name": "PYX-01",
		"tagline": "DERELICT FIELD",
		"chart_pos": Vector2(0.28, 0.62),
		"connections": ["pyx02"],
		"unlocked_by": "",  # always available
		"bounds": 40.0,
		"env": {
			"bg": Color(0.012, 0.014, 0.022),
			"ambient": Color(0.3, 0.35, 0.5),
			"ambient_energy": 0.6,
			"glow": 0.95,
			"sun_color": Color(0.8, 0.85, 1.0),
			"sun_energy": 0.9,
			# Calm-layer low-pass. Wide open: the starting system is the one you
			# hear clearly, so the other two read as further from home.
			"music_lp": 20500.0,
		},
		"lattice": {"color": Palette.AMBER, "radii": [9.0, 18.0, 28.0, 37.0], "spokes": 8},
		"starfield": {"count": 620, "tint": Color(0.85, 0.9, 1.0), "spread": 96.0},
		# Haze sits entirely BELOW the play plane (y ≈ -(scale+4)). Centred near
		# y=0 the spheres bulge through the plane and read as solid planets —
		# badly misleading now that real bodies are collidable.
		"haze": [
			{"pos": Vector3(-20, -26, -30), "scale": 22.0, "color": Color(0.35, 0.12, 0.10, 0.025)},
			{"pos": Vector3(18, -22, 24), "scale": 18.0, "color": Color(0.18, 0.20, 0.42, 0.022)},
		],
		# Cracked moon: the landmark you navigate by in the starting system.
		"bodies": [
			{"kind": "moon", "pos": Vector3(-27, 0, -11), "radius": 5.6,
				"color": Color(0.24, 0.24, 0.27), "cracked": true},
		],
		"asteroids": [
			{"pos": Vector3(17, -3, 11), "scale": Vector3(6, 4, 5)},
			{"pos": Vector3(21, -4, -19), "scale": Vector3(8, 5, 6)},
			{"pos": Vector3(2, -3, 24), "scale": Vector3(3, 2, 3)},
			{"pos": Vector3(-7, -4, 27), "scale": Vector3(2.6, 2, 2.4)},
			{"pos": Vector3(8, -3, 29), "scale": Vector3(2.2, 2, 2.6)},
		],
		"derelict": {"pos": Vector3(-9, 0, -18), "rot_y": 25.0, "loot": 70, "crack_time": 1.8},
		# The apex wakes only after this system's derelict has been breached.
		"apex": {"pos": Vector3(10, 0, -22), "difficulty": 1.0, "loot": 90, "bonus": 15000,
			# The sundial's blade. Its shadow lance locks a firing line where you
			# were standing and fires down it a beat later — the starting boss
			# teaches the series' one rule: standing still is what kills you.
			"name": "THE GNOMON", "attack": "shadow_lance"},
		# Freeport: neutral prices and a narrow spread. The market you learn on.
		"port": {
			"id": "anchor",
			"name": "WAYPOINT ANCHOR",
			"kind": "station",
			"pos": Vector3(-17, 0, 7),
			"freeport": true,
			"bias": {},
			# PAINT lives at the primary ports (and the Cantina), so a livery is
			# never more than one dock away wherever the player happens to be.
			#
			# COMMISSION is APPENDED, never prepended: port_panel.gd's open_for
			# makes services()[0] the landing tab, so putting the registry first
			# would open every dock at the Anchor on a page about paperwork
			# instead of on the market. It lives only here — one desk, in the
			# system you start in, which is what makes filing feel like going
			# somewhere rather than like opening a menu.
			"services": ["market", "outfitter", "repair", "contracts", "paint", "storage", "commission"],
			# The Cutting Head is stocked HERE, in the system the player starts in,
			# because a verb you cannot buy a tool for is a verb the player never
			# finds. The Assay Rig is not: at 15,200 it belongs at the ports a
			# prospector reaches after deciding mining is the route they want.
			"stock": ["pulse_2", "util_tractor", "util_cargo", "drive_vector",
				"drive_cruise_2", "util_tractor_2", "util_repair", "rig_hauler",
				"util_cutter"],
		},
		# Secondary station: entertainment, no market of its own. Placed far from
		# the Anchor so crossing PYX-01 has a reason and a destination.
		"ports": [
			{
				"id": "cantina",
				"name": "THE EMBERS CANTINA",
				"kind": "cantina",
				"pos": Vector3(12, 0, 26),
				"freeport": true,
				# The demand end of the contraband route: an entertainment
				# station is where the stuff is actually wanted, and it pays
				# accordingly. Paired with the Void's supply-side 0.72 below,
				# this is the fattest margin on the chart — which is the point,
				# because it is also the cargo most likely to get you jumped.
				"bias": {"contraband": 1.15},
				# FENCE, not MARKET, and that is the whole design: the Cantina
				# has no shopfront, it has a back room. The fence tab is
				# sell-only by construction (Market.can_buy refuses fenced
				# goods), which is exactly right — you unload contraband over
				# the bar here, you do not restock from it.
				"services": ["rumors", "games", "fence", "contracts", "paint"],
				# The back room takes both kinds of awkward cargo. Stolen goods
				# are on this list because they are restricted to here, the Void
				# and the Anchor — and a port that is named as one of a good's
				# only three buyers had better actually have a counter for it.
				"fence_goods": ["contraband", "stolen",
					"plate_ablative", "cell_fuel", "rod_decay", "sink_thermal", "lattice_data", "index_cartographic", "servo_prewar", "heart_reliquary", "manifest_forged", "charge_unstable"],
				"fence_mult": 1.25,
				"stock": [],
			},
		],
		# Sentries guard the approaches to the two prizes rather than drifting
		# at random: the derelict lane and the apex lane.
		"sentries": [
			Vector3(-6, 0, -12), Vector3(-14, 0, -13),
			Vector3(8, 0, -16), Vector3(15, 0, -20),
		],
		"swarm": {"interval": 22.0, "pack_min": 4, "pack_max": 6, "cap": 10, "first_delay": 6.0},
		"difficulty": 1.0,
		"loot_mult": 1.0,
	},
	"pyx02": {
		"name": "PYX-02",
		"tagline": "EMBER SHALLOWS",
		"chart_pos": Vector2(0.54, 0.38),
		"connections": ["pyx01", "pyx03"],
		"unlocked_by": "pyx01",  # breach the PYX-01 derelict to chart this
		"bounds": 48.0,
		"env": {
			"bg": Color(0.035, 0.014, 0.012),
			"ambient": Color(0.55, 0.28, 0.2),
			"ambient_energy": 0.75,
			"glow": 1.15,
			"sun_color": Color(1.0, 0.62, 0.42),
			"sun_energy": 1.1,
			# Warm and close — the ember shallows are dust you fly inside of.
			"music_lp": 3400.0,
		},
		"lattice": {"color": Color(1.0, 0.42, 0.22), "radii": [8.0, 16.0, 26.0, 36.0, 45.0], "spokes": 10},
		"starfield": {"count": 820, "tint": Color(1.0, 0.85, 0.72), "spread": 112.0},
		"haze": [
			{"pos": Vector3(14, -30, -18), "scale": 26.0, "color": Color(0.8, 0.22, 0.10, 0.037)},
			{"pos": Vector3(-22, -24, 8), "scale": 20.0, "color": Color(0.7, 0.28, 0.12, 0.030)},
			{"pos": Vector3(4, -28, 28), "scale": 24.0, "color": Color(0.5, 0.15, 0.18, 0.025)},
		],
		# The ringed ember world this system is named for.
		"bodies": [
			# Only the planet body is solid. The ring is kept small and wispy on
			# purpose — a broad opaque disc would read as a surface players
			# expect to collide with, which would contradict everything else.
			{"kind": "planet", "pos": Vector3(20, 0, 1), "radius": 8.0,
				"color": Color(0.42, 0.16, 0.10),
				"ring": {"inner": 1.28, "outer": 1.82, "color": Color(0.9, 0.5, 0.25, 0.3)}},
			{"kind": "moon", "pos": Vector3(7, 0, 22), "radius": 2.6, "color": Color(0.3, 0.22, 0.2)},
			{"kind": "moon", "pos": Vector3(38, 0, -18), "radius": 2.2, "color": Color(0.26, 0.2, 0.18)},
		],
		"asteroids": [
			{"pos": Vector3(-25, -3, 17), "scale": Vector3(5, 4, 5)},
			{"pos": Vector3(-19, -5, -27), "scale": Vector3(9, 4, 7)},
			{"pos": Vector3(-34, -6, -6), "scale": Vector3(4, 3, 4)},
		],
		"derelict": {"pos": Vector3(14, 0, -21), "rot_y": -40.0, "loot": 95, "crack_time": 2.1},
		"apex": {"pos": Vector3(-15, 0, -25), "difficulty": 1.45, "loot": 120, "bonus": 22000,
			# The ringed instrument for the ringed system. Flare mortars lob onto
			# your position under a ground-ring telegraph — area denial where the
			# Gnomon was a line, so the dodge you learned needs re-learning.
			"name": "THE ARMILLARY", "attack": "flare_mortar"},
		# Mining colony: digs alloys and volatiles, starves for isotopes and cores.
		"port": {
			"id": "cinderworks",
			"name": "CINDERWORKS",
			"kind": "colony",
			"pos": Vector3(27, 0, 14),
			"freeport": false,
			"bias": {"alloys": 0.68, "volatiles": 0.72, "isotopes": 1.35, "cores": 1.25, "relics": 1.05},
			"services": ["market", "outfitter", "repair", "contracts", "paint"],
			"stock": ["util_cargo", "util_tractor", "drive_vector", "arc_1", "arc_2", "core_surge",
				"util_cargo_2", "drive_vector_2", "util_repair", "rig_prospector",
				"util_cutter", "util_assay"],
		},
		# Secondary station: industrial. Bulk discounts and honest sell-back, but
		# it will not sell you a weapon — the Yards have that trade.
		"ports": [
			{
				"id": "depot",
				"name": "FORGELINE DEPOT",
				"kind": "depot",
				"pos": Vector3(-31, 0, 27),
				"freeport": false,
				"bias": {"alloys": 0.80, "volatiles": 0.85, "isotopes": 1.20, "cores": 1.15, "relics": 1.0},
				"services": ["market", "outfitter", "repair", "contracts", "lab", "storage", "forge"],
				"bulk_units": 10,        # trades of this size or more get the break
				"bulk_bonus": 0.06,      # 6% either way, in the player's favour
				"sellback": 0.75,        # vs the usual 0.60
				"stock": ["drive_vector", "util_cargo", "util_tractor", "util_shield",
					"util_scanner", "torp_1", "torp_2",
					"drive_cruise_2", "drive_vector_2", "util_tractor_2",
					"util_shield_2", "util_cargo_2", "util_scanner_2",
					"util_repair", "util_repair_2",
					"rig_hauler", "rig_prospector", "rig_bulwark", "rig_runner",
					"util_cutter", "util_assay"],
			},
		],
		# Swarm-heavy: an Arc fit farms this system, a Lance fit struggles.
		"sentries": [
			Vector3(-9, 0, -11), Vector3(6, 0, -7),
			Vector3(19, 0, -15), Vector3(-17, 0, -19),
		],
		"swarm": {"interval": 14.0, "pack_min": 5, "pack_max": 8, "cap": 16, "first_delay": 4.0},
		"difficulty": 1.5,
		"loot_mult": 1.35,
	},
	"pyx03": {
		"name": "PYX-03",
		"tagline": "THE ANCHORAGE",
		"chart_pos": Vector2(0.76, 0.68),
		"connections": ["pyx02"],
		"unlocked_by": "pyx02",
		"bounds": 44.0,
		"env": {
			"bg": Color(0.014, 0.014, 0.032),
			"ambient": Color(0.3, 0.3, 0.62),
			"ambient_energy": 0.55,
			"glow": 0.85,
			"sun_color": Color(0.62, 0.68, 1.0),
			"sun_energy": 0.8,
			# Cold and far: the deepest system gets the darkest bed.
			"music_lp": 1900.0,
		},
		"lattice": {"color": Color(0.55, 0.5, 1.0), "radii": [10.0, 20.0, 31.0, 41.0], "spokes": 6},
		"starfield": {"count": 520, "tint": Color(0.78, 0.82, 1.0), "spread": 104.0},
		"haze": [
			{"pos": Vector3(-10, -32, -26), "scale": 28.0, "color": Color(0.22, 0.20, 0.65, 0.035)},
			{"pos": Vector3(20, -26, 14), "scale": 22.0, "color": Color(0.30, 0.18, 0.55, 0.028)},
		],
		# A dark ice giant, and a comet that crosses the system on a long loop.
		"bodies": [
			{"kind": "planet", "pos": Vector3(19, 0, 16), "radius": 9.0,
				"color": Color(0.13, 0.16, 0.34)},
			{"kind": "comet", "from": Vector3(-42, 0, -34), "to": Vector3(42, 0, 30),
				"period": 95.0, "color": Color(0.7, 0.9, 1.0)},
		],
		"asteroids": [
			{"pos": Vector3(-28, -4, -7), "scale": Vector3(10, 6, 8)},
			{"pos": Vector3(26, -5, -10), "scale": Vector3(7, 5, 6)},
			{"pos": Vector3(-14, -5, 26), "scale": Vector3(5, 4, 4)},
		],
		"derelict": {"pos": Vector3(-6, 0, -25), "rot_y": 70.0, "loot": 130, "crack_time": 2.4},
		"apex": {"pos": Vector3(13, 0, -27), "difficulty": 2.0, "loot": 160, "bonus": 32000,
			# The anchorage's anchor. The graviton tether deals no damage at all:
			# it drags you toward the hub and the sweep arm, so the final boss
			# weaponizes the positioning the other two only pressured.
			"name": "THE MERIDIAN", "attack": "grav_tether"},
		# Military yards: refines its own isotopes, pays well for alloys and relics.
		# Alloys Cinderworks->Bastion and isotopes Bastion->Cinderworks are the two
		# routes that fall out of these numbers without anyone scripting them.
		"port": {
			"id": "bastion",
			"name": "BASTION YARDS",
			"kind": "military",
			"pos": Vector3(-19, 0, 13),
			"freeport": false,
			"bias": {"alloys": 1.30, "volatiles": 1.10, "isotopes": 0.75, "cores": 0.95, "relics": 1.40},
			"services": ["market", "outfitter", "repair", "contracts", "paint", "lab", "storage"],
			"stock": ["lance_1", "lance_2", "arc_2", "pulse_2", "util_shield", "util_scanner",
				"core_surge", "core_aegis", "torp_1", "torp_2",
				"util_shield_2", "util_scanner_2", "util_repair_2", "rig_strike", "rig_bulwark",
				"util_assay"],
		},
		# Secondary station: the smuggler's den. The only place that will fence
		# what you should not be carrying, and the only place that will sell you
		# more of it.
		"ports": [
			{
				"id": "void",
				"name": "THE GRINNING VOID",
				"kind": "den",
				"pos": Vector3(30, 0, 24),
				"freeport": true,
				# The supply end: the Void is where contraband comes from, so it
				# is cheap here and dear at the Cantina, two systems away.
				"bias": {"relics": 1.15, "cores": 1.10, "contraband": 0.72, "stolen": 1.0},
				"services": ["market", "fence", "outfitter", "contracts"],
				"fence_goods": ["relics", "cores", "stolen",
					"plate_ablative", "cell_fuel", "rod_decay", "sink_thermal", "lattice_data", "index_cartographic", "servo_prewar", "heart_reliquary", "manifest_forged", "charge_unstable"],
				"fence_mult": 1.25,      # what the fence pays over the local price
				"outfit_mult": 0.80,     # grey-market modules, 20% off
				"stock": ["arc_1", "arc_2", "pulse_2", "core_surge", "util_scanner", "drive_vector"],
			},
		],
		# Sentry cluster: the Lance fit's system. Swarms are a rare nuisance.
		"sentries": [
			Vector3(-11, 0, -13), Vector3(-2, 0, -17), Vector3(7, 0, -11),
			Vector3(14, 0, -19), Vector3(0, 0, -6), Vector3(-18, 0, -21),
			Vector3(19, 0, -24),
		],
		"swarm": {"interval": 34.0, "pack_min": 3, "pack_max": 4, "cap": 6, "first_delay": 12.0},
		"difficulty": 2.2,
		"loot_mult": 1.8,
	},
}


static func get_system(id: String) -> Dictionary:
	return SYSTEMS.get(id, {})


static func exists(id: String) -> bool:
	return SYSTEMS.has(id)


static func ids() -> Array:
	return SYSTEMS.keys()


static func bounds_of(id: String) -> float:
	return float(get_system(id).get("bounds", 40.0))


static func music_lp_of(id: String) -> float:
	return float((get_system(id).get("env", {}) as Dictionary).get("music_lp", 20500.0))


static func display_name(id: String) -> String:
	var s := get_system(id)
	if s.is_empty():
		return "UNKNOWN"
	return "%s :: %s" % [s["name"], s["tagline"]]


static func ports_of(system_id: String) -> Array:
	# Every system has a primary `port` and may add secondaries in `ports`. Kept
	# as two fields rather than one list because "the port of PYX-02" is a thing
	# the tutorial, the chart and the delivery contracts all still mean — the
	# secondaries are colour, not infrastructure.
	var s := get_system(system_id)
	var out := []
	var primary: Dictionary = s.get("port", {})
	if not primary.is_empty():
		out.append(primary)
	for extra in s.get("ports", []):
		out.append(extra)
	return out


static func port_of(system_id: String) -> Dictionary:
	return get_system(system_id).get("port", {})


static func port_ids() -> Array:
	var out := []
	for id in SYSTEMS:
		for p in ports_of(String(id)):
			out.append(String((p as Dictionary)["id"]))
	return out


static func system_of_port(port_id: String) -> String:
	for id in SYSTEMS:
		for p in ports_of(String(id)):
			if String((p as Dictionary)["id"]) == port_id:
				return String(id)
	return ""


static func port_def_by_id(port_id: String) -> Dictionary:
	for id in SYSTEMS:
		for p in ports_of(String(id)):
			if String((p as Dictionary)["id"]) == port_id:
				return p
	return {}


static func unlock_hint(id: String) -> String:
	var s := get_system(id)
	var req := String(s.get("unlocked_by", ""))
	if req == "":
		return ""
	return "BREACH THE %s DERELICT TO CHART" % String(get_system(req).get("name", req))
