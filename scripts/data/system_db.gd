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
		# v18. OUTSIDE THE CORDON. The survey hull no longer sits 20u from the
		# Anchor -- it drifted out past the marker, on the SAME BEARING its wreck
		# used to lie on (the old authored point was (-9, 0, -18), which is 243
		# degrees), so the fiction is that the field drifted rather than that a
		# designer moved it.
		#
		# AUTHORED, NOT ROLLED, and that is the difference between this and the
		# lair. The engine hides and finding it is the game; the hull is a
		# DESTINATION the unlock hint sends you to, and a second searchable thing
		# in the deep would dilute the hunt rather than double it.
		# LOOT CUT 70 -> 64 (and 95 -> 87, 130 -> 119) BECAUSE THE HULL MOVED,
		# not because the hull was too rich. spawn_loot re-grades a fraction of
		# every drop by the BAND IT IS SPILLED IN, so the identical hull cracked
		# the identical way started paying ~8% more purely for standing at
		# depth 100 instead of depth 0 — measured, 5022 -> 5423 per hull, which
		# pushed PACINGTEST's binding MIDTIER from 2.92 to 2.98 against a hard
		# ceiling of 3.00. A relocation is not a pay rise, and 0.02 of headroom
		# is not headroom. The cut hands the difference back so the player gets
		# the same hull for the same work, further away.
		"derelict": {"bearing_deg": 243.0, "depth": 100.0, "rot_y": 25.0,
			"loot": 64, "crack_time": 1.8},
		# The tutorial's hull, on the old berth. Small, and it charts NOTHING --
		# `counts_as_survey` false, the same flag a deep hulk has carried since
		# the expanse shipped, so no new gate is designed for it. It teaches the
		# verb; the hull outside the cordon opens the world.
		"training_hull": {"pos": Vector3(-9, 0, -18), "rot_y": 25.0,
			"loot": 16, "crack_time": 1.4},
		# v15. THE LAIR. The engine no longer sits at an authored point inside the
		# charted volume -- it hides out in the expanse, at a bearing and depth
		# derived from the run salt (SystemDB.lair_pos). `depth` is the band it
		# hides in, measured past this system's chart edge, and it is the whole
		# difficulty curve of the hunt: the Drift for the first one, so a pilot
		# with the tutorial still fresh can brute-force it if the hints run dry.
		"apex": {"lair": {"depth": [260.0, 340.0]},
			"difficulty": 1.0, "loot": 90, "bonus": 15000,
			# The sundial's blade. Its shadow lance locks a firing line where you
			# were standing and fires down it a beat later — the starting boss
			# teaches the series' one rule: standing still is what kills you.
			"name": "THE GNOMON", "attack": "shadow_lance"},
		# v20 HUNT STAGE 6. THE ARCHITECTURAL FAMILY. Every hyper-structure in
		# this system is an instance of one instrument -- the sundial's system builds models of moving skies --
		# and instances are named by index ("THE ORRERY - SECOND INSTRUMENT"),
		# so finding a second one reads as recognition rather than as a new
		# noun. The engine names (THE GNOMON / ARMILLARY / MERIDIAN) are the
		# same vocabulary one scale down: this frontier measured things.
		"hyper": {"family": "THE ORRERY"},
		# v18 stage 3. WHO OWNS THIS SYSTEM. The engine was never masterless: the
		# sentries standing over the lanes and the swarms that keep arriving are
		# its forces, and silencing it is taking a system off a government rather
		# than switching off a machine. One key, read once by the builder and
		# handed to every spawner, so "whose side is this" has a single answer.
		"faction": "gnomon",
		# Freeport: neutral prices and a narrow spread. The market you learn on.
		"port": {
			"id": "anchor",
			"name": "WAYPOINT ANCHOR",
			"kind": "station",
			# v18 stage 5. WHO RUNS THE DESK. The five port-grown factions get
			# their names on doors they already own (HORIZON-4 §3); standing with
			# the owner is what the fence gate and the dock line read. The
			# Anchor is the Authority's — it carries the Commission desk.
			"owner": "gsa",
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
				"owner": "embers",
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
				# v16. THE CHEAP RUNG OF THE HUNT. `hunt_error` 0 means the ring
				# tier -- a band and a quadrant, no bearing -- which is the same
				# shape the free lane-obstructed broadcast gives. What 500
				# salvage buys is hearing it for a system you have not been
				# jammed out of yet, over a bar, in the charted volume. The
				# Watch sells the sharp version, and it is 900 and 1,200 units
				# past the edge of the map.
				"hunt_price": 500,
				"hunt_error": 0.0,
				# The back room takes both kinds of awkward cargo. Stolen goods
				# are on this list because they are restricted to here, the Void
				# and the Anchor — and a port that is named as one of a good's
				# only three buyers had better actually have a counter for it.
				"fence_goods": ["contraband", "stolen",
					"plate_ablative", "cell_fuel", "rod_decay", "sink_thermal", "lattice_data", "index_cartographic", "servo_prewar", "heart_reliquary", "lens_unsounded", "manifest_forged", "charge_unstable"],
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
		# v18. THE CORDON'S BEAT. Absolute world waypoints, walked as a loop.
		#
		# THE ROUTES ARE THE ENTITY BUDGET. Ambient picket-vs-sentry combat is
		# an AUTHORING decision, not an emergent one: each route is drawn to
		# pass within engage range of exactly ONE sentry post, so a system has
		# as many standing skirmishes as it has routes and no more. That is what
		# keeps the count legible on a 720-wide phone and the frame budget
		# knowable — see HORIZON-4 §7.
		#
		# Every waypoint must sit inside `bounds`: the band-1 beacon has
		# promised since v13 that patrols do not operate past the marker, and
		# THE CORDON STOPS AT THE MARKER checks this table rather than waiting
		# for a picket to be built and then dragging it home.
		#
		# Route 1 covers the Anchor approach and the derelict lane, crossing the
		# post at (-6, 0, -12). Route 2 walks the Cantina side and crosses
		# (8, 0, -16)'s neighbourhood on its northern leg.
		"patrols": [
			[Vector3(-16, 0, 3), Vector3(-9, 0, -9), Vector3(-2, 0, -14), Vector3(-10, 0, 6)],
			[Vector3(11, 0, 21), Vector3(17, 0, 6), Vector3(9, 0, -13), Vector3(2, 0, 12)],
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
		# Same rule, same bearing its wreck used to lie on (304 degrees), pushed
		# further out because PYX-02 is further from home.
		"derelict": {"bearing_deg": 304.0, "depth": 130.0, "rot_y": -40.0,
			"loot": 87, "crack_time": 2.1},
		# THE REACHES. Past where the beacons reliably answer — a hunt you fit for.
		"apex": {"lair": {"depth": [620.0, 780.0]},
			"difficulty": 1.45, "loot": 120, "bonus": 22000,
			# The ringed instrument for the ringed system. Flare mortars lob onto
			# your position under a ground-ring telegraph — area denial where the
			# Gnomon was a line, so the dodge you learned needs re-learning.
			"name": "THE ARMILLARY", "attack": "flare_mortar"},
		# v20 HUNT STAGE 6. THE ARCHITECTURAL FAMILY. Every hyper-structure in
		# this system is an instance of one instrument -- the ringed system measures by falling water --
		# and instances are named by index ("THE CLEPSYDRA - SECOND INSTRUMENT"),
		# so finding a second one reads as recognition rather than as a new
		# noun. The engine names (THE GNOMON / ARMILLARY / MERIDIAN) are the
		# same vocabulary one scale down: this frontier measured things.
		"hyper": {"family": "THE CLEPSYDRA"},
		# v19 HUNT STAGE 4. THE DEEP HAS AN ACCENT HERE. Authored identity for
		# the expanse, absent from pyx01 BY CONSTRUCTION: the weighted branch in
		# DeepSpace.weighted_index only engages when a row exists, so the system
		# with no block plans exactly the cells it always did and WORLD
		# FINGERPRINT cannot move. Weight rows are authored against
		# DeepPortDB.for_band's OUTPUT length per band (1/3/4/5/6/7 for bands 1-6),
		# never against ARCHETYPES — for_band filters by min_band in declaration
		# order, and a row sized to the wrong list would silently misweight.
		#
		# PYX-02 reads industrial: the Combine's COLD FORGE dominates where it
		# can exist (band 2+), and the skeleton "frame" landmark — the deep's
		# unfinished construction — is the monument you meet most.
		"deep": {
			# band -> weights over for_band(band): b1 [relay], b2 [relay, haven,
			# forge], b3 [+blackwatch], b4 [+last watch], b5 [+breakwater],
			# b6 [+far lantern]. Widths 1/3/4/5/6/7 — a row of the wrong length is
			# silently ignored by weighted_index, which falls back to the uniform
			# pick and switches this system's whole accent off without a word.
			"station_weights": {
				2: [1.0, 1.0, 2.5],
				3: [1.0, 1.0, 2.5, 0.8],
				4: [1.0, 1.0, 2.2, 0.8, 1.0],
				# The Forge keeps its pull outward, but the Breakwater is what a
				# player past 2600u is actually looking for, so it is not buried:
				# 1.6 of 7.6 total, roughly one station in five.
				5: [1.0, 1.0, 2.2, 0.8, 1.0, 1.6],
				# And the Lantern is the rarest thing on the list without being a
				# lottery: 1.4 of 9.0, about one in six, which at band 6's station
				# density is a window or two of flying.
				6: [1.0, 0.8, 1.8, 0.8, 1.0, 2.2, 1.4],
			},
			# band -> weights over LANDMARK_KINDS, which is SIX wide as of v20's
			# stage 4: ["pylon", "frame", "monolith", "marker", "gate", "cairn"].
			# Every row here grew with it in the same commit — a row left at four
			# does not error, it silently drops this system's whole accent back to
			# a uniform pick.
			#
			# The frontier's two kinds are ZERO inside the Quiet rather than rare:
			# a gate is a threshold and a cairn is a grave-marker, and meeting one
			# in the Shoals would spend both. They are the deep's own vocabulary
			# and they start where the deep stops being surveyed.
			"landmark_weights": {
				1: [1.5, 2.5, 0.4, 0.4, 0.0, 0.0],
				2: [0.6, 3.0, 0.6, 0.4, 0.0, 0.0],
				3: [0.4, 2.2, 1.6, 0.6, 0.0, 0.0],
				4: [0.3, 1.4, 1.2, 1.6, 0.0, 0.0],
				# PYX-02 builds things and stops: the unfinished arch is its
				# frontier monument, the way the unfinished frame is its inner one.
				5: [0.2, 1.0, 0.8, 0.8, 2.6, 0.4],
				6: [0.1, 0.6, 0.6, 0.8, 1.4, 2.2],
			},
			# The weather reaches the Reaches here. 700 keeps every rift shy of
			# the lair band's floor at 620 only by rejection (spawn_rift's
			# keep-out loop) — the raw windows overlap by design, because a
			# hard ceiling at 619 would author the lair's position into the
			# weather table.
			"rift": {"depth_max": 700.0, "rich_mult": 1.25},
		},
		"faction": "armillary",
		# Mining colony: digs alloys and volatiles, starves for isotopes and cores.
		"port": {
			"id": "cinderworks",
			"name": "CINDERWORKS",
			"kind": "colony",
			"owner": "combine",
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
				"owner": "combine",
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
		# Three routes: PYX-02 is the Combine's industrial heart and the
		# Authority escorts its shipping. Crossing (6,0,-7), (-9,0,-11) and
		# (19,0,-15) respectively — one post each, per PYX-01's note.
		"patrols": [
			[Vector3(26, 0, 16), Vector3(12, 0, 2), Vector3(4, 0, -9), Vector3(16, 0, 8)],
			[Vector3(-30, 0, 25), Vector3(-18, 0, 8), Vector3(-7, 0, -9), Vector3(-22, 0, 12)],
			[Vector3(30, 0, -22), Vector3(21, 0, -13), Vector3(8, 0, -20), Vector3(24, 0, -28)],
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
		# 257 degrees -- the bearing of the old authored point (-6, 0, -25).
		"derelict": {"bearing_deg": 257.0, "depth": 150.0, "rot_y": 70.0,
			"loot": 119, "crack_time": 2.4},
		# THE QUIET. No colour left, nothing transmitting, and the last engine.
		"apex": {"lair": {"depth": [1150.0, 1450.0]},
			"difficulty": 2.0, "loot": 160, "bonus": 32000,
			# The anchorage's anchor. The graviton tether deals no damage at all:
			# it drags you toward the hub and the sweep arm, so the final boss
			# weaponizes the positioning the other two only pressured.
			"name": "THE MERIDIAN", "attack": "grav_tether"},
		# v20 HUNT STAGE 6. THE ARCHITECTURAL FAMILY. Every hyper-structure in
		# this system is an instance of one instrument -- the anchorage's instrument takes the height of stars --
		# and instances are named by index ("THE ASTROLABE - SECOND INSTRUMENT"),
		# so finding a second one reads as recognition rather than as a new
		# noun. The engine names (THE GNOMON / ARMILLARY / MERIDIAN) are the
		# same vocabulary one scale down: this frontier measured things.
		"hyper": {"family": "THE ASTROLABE"},
		# v19 HUNT STAGE 4. The Quiet's accent: military and mute. BLACKWATCH
		# YARD dominates its bands, and the deep is marked by monoliths and
		# markers — things that say somebody measured this place and left.
		# Same authoring rules as pyx02's block above.
		"deep": {
			# Widths 4/5/6/7 for bands 3-6, against for_band's output.
			"station_weights": {
				3: [1.0, 0.8, 0.8, 2.6],
				4: [1.0, 0.8, 0.8, 2.4, 1.2],
				# PYX-03 reads military, so its frontier leans the same way: the
				# Breakwater is an armoury and this is the system that posts
				# armouries. 2.0 of 7.8.
				5: [1.0, 0.8, 0.8, 2.4, 1.2, 2.0],
				# Band 6 tilts hardest of anywhere toward the last light: 2.0 of
				# 9.2. The mute system is where the lit place matters most.
				6: [1.0, 0.6, 0.6, 2.0, 1.0, 2.0, 2.0],
			},
			# Six wide, matching LANDMARK_KINDS. See the note in PYX-02's block.
			"landmark_weights": {
				1: [2.0, 0.5, 1.2, 0.8, 0.0, 0.0],
				2: [0.8, 0.5, 2.4, 0.8, 0.0, 0.0],
				3: [0.5, 0.4, 2.6, 1.2, 0.0, 0.0],
				4: [0.3, 0.3, 1.6, 2.4, 0.0, 0.0],
				# The mute system marks its dead. PYX-03 leans on the cairn where
				# PYX-02 leans on the gate — one system builds and abandons, the
				# other buries and moves on.
				5: [0.2, 0.2, 1.2, 1.4, 1.6, 1.4],
				6: [0.1, 0.1, 0.8, 1.0, 0.8, 3.0],
			},
			# v20 STAGE 4: THE WEATHER REACHES FURTHER, AND PAYS THE SAME. 1200 -> 2400
			# doubles the volume PYX-03's shears can occur in and leaves the deepest
			# one squarely in band 4, which is the whole point.
			#
			# 2800 was the obvious number and it is the one this stage refused.
			# band_of(2800) is 5, and Rift.GRADE_CEILING is pinned at 4 — so a
			# band-5 shear would pay QUIET salvage while standing in the Fathoms,
			# i.e. worse than the band it is in. Fixing that means raising the
			# ceiling, and at band-6 grades one shear pays 27,900-33,480 against a
			# best-case eight-minute loop of ~17,000: a single windfall worth two
			# loops, in the one part of the game no harness measures. Range is
			# content; grade is economy. This stage ships the first.
			"rift": {"depth_max": 2400.0, "rich_mult": 1.5},
		},
		"faction": "meridian",
		# Military yards: refines its own isotopes, pays well for alloys and relics.
		# Alloys Cinderworks->Bastion and isotopes Bastion->Cinderworks are the two
		# routes that fall out of these numbers without anyone scripting them.
		"port": {
			"id": "bastion",
			"name": "BASTION YARDS",
			"kind": "military",
			"owner": "bastion",
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
				"owner": "grin",
				"pos": Vector3(30, 0, 24),
				"freeport": true,
				# The supply end: the Void is where contraband comes from, so it
				# is cheap here and dear at the Cantina, two systems away.
				"bias": {"relics": 1.15, "cores": 1.10, "contraband": 0.72, "stolen": 1.0},
				"services": ["market", "fence", "outfitter", "contracts"],
				"fence_goods": ["relics", "cores", "stolen",
					"plate_ablative", "cell_fuel", "rod_decay", "sink_thermal", "lattice_data", "index_cartographic", "servo_prewar", "heart_reliquary", "lens_unsounded", "manifest_forged", "charge_unstable"],
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
		# Four routes, the heaviest presence on the chart: Bastion Yards is the
		# Authority's own military yard, and PYX-03 is where the Cordon has the
		# most to lose. Crossing (0,0,-6), (-11,0,-13), (7,0,-11) and
		# (14,0,-19).
		"patrols": [
			[Vector3(-18, 0, 12), Vector3(-8, 0, 2), Vector3(2, 0, -8), Vector3(-12, 0, 4)],
			[Vector3(-26, 0, -4), Vector3(-16, 0, -10), Vector3(-9, 0, -15), Vector3(-20, 0, -6)],
			[Vector3(16, 0, 4), Vector3(9, 0, -6), Vector3(5, 0, -13), Vector3(13, 0, -2)],
			[Vector3(28, 0, -22), Vector3(19, 0, -16), Vector3(12, 0, -21), Vector3(24, 0, -27)],
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


# --- the deep block (v19, Hunt stage 4) --------------------------------------
# Authored expanse identity. EVERY accessor's default IS the shipped behaviour,
# which is the whole determinism argument: a system with no block (pyx01, and
# any system a harness builds by hand) reads back exactly the world that existed
# before this key did, so the weighted branches never engage and the fingerprint
# cannot move. bounds_of's one-line .get(default) shape, applied five times.

static func deep_of(id: String) -> Dictionary:
	return get_system(id).get("deep", {})


static func rift_depth_max(id: String, fallback: float) -> float:
	# The fallback is Main.RIFT_DEPTH_MAX, passed in rather than restated here —
	# one authored 260.0 in the game, not two that agree by luck.
	return float((deep_of(id).get("rift", {}) as Dictionary).get("depth_max", fallback))


static func rift_rich_mult(id: String) -> float:
	return float((deep_of(id).get("rift", {}) as Dictionary).get("rich_mult", 1.0))


static func station_weights(id: String, band: int) -> Array:
	# Empty means "the shipped uniform pick", which DeepSpace.weighted_index
	# honours with a byte-identical modulo. Keyed by int band.
	return (deep_of(id).get("station_weights", {}) as Dictionary).get(band, [])


static func landmark_weights(id: String, band: int) -> Array:
	return (deep_of(id).get("landmark_weights", {}) as Dictionary).get(band, [])


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


static func faction_of(id: String) -> String:
	# The host power of a system. Defaults to FERAL's id rather than to "" so a
	# system def that forgets the key produces the SHIPPED world (unflagged
	# automata hostile to the player) instead of a node with no allegiance at
	# all -- the same fail-safe direction Hostile.faction's own default takes.
	return String(get_system(id).get("faction", "feral"))


static func derelict_pos(id: String) -> Vector3:
	# WHERE THE SURVEY HULL IS. One pure function, for the same reason lair_pos
	# is one: the builder calls it, the tutorial's bearing broadcast calls it,
	# the expanse's keep-out calls it, and every harness calls it -- and the
	# moment two places derive it independently they will disagree.
	#
	# It draws from NO RNG AT ALL, which is what keeps DEEPTEST's WORLD
	# FINGERPRINT still: an authored bearing takes no number out of the linear
	# sequence the expanse rolls from.
	#
	# Depth is measured PAST THE CHART EDGE, the rule the bands and the lairs
	# already follow, so a bigger system pushes its own hull out with it.
	var s := get_system(id)
	var d: Dictionary = s.get("derelict", {})
	if d.is_empty():
		return Vector3.ZERO
	# An absolute `pos` still wins where one is authored -- the training hull
	# uses that shape, and so would any future hull that wants a hand-placed
	# berth rather than a bearing.
	if d.has("pos"):
		return d["pos"]
	var bearing := deg_to_rad(float(d.get("bearing_deg", 0.0)))
	var radius := float(s.get("bounds", 40.0)) + float(d.get("depth", 100.0))
	return Vector3(cos(bearing) * radius, 0.0, sin(bearing) * radius)


static func derelict_depth(id: String) -> float:
	# What the hull's depth past the chart edge actually is. Recomputed from
	# derelict_pos rather than read back out of the def, so it can never
	# disagree with where the thing was built -- lair_depth's rule.
	var p := derelict_pos(id)
	if p == Vector3.ZERO:
		return 0.0
	return maxf(p.length() - float(get_system(id).get("bounds", 40.0)), 0.0)


static func derelict_bearing_deg(id: String) -> int:
	# WHICH WAY THE SURVEY HULL LIES, as a compass number the player can fly.
	#
	# Derived from derelict_pos rather than read back out of `bearing_deg`, for
	# derelict_depth's reason: a hull authored with an absolute `pos` has no
	# bearing field at all, and reading the def would hand back 0 for it -- a
	# confident heading pointing at nothing. Two callers now say this number out
	# loud (the tutorial's survey assignment and the dormant engine's re-point),
	# and the moment they derive it independently they will disagree.
	var p := derelict_pos(id)
	if p == Vector3.ZERO:
		return 0
	# A COMPASS NUMBER, because both callers say it out loud. The def's authored
	# `bearing_deg` stays in the world convention -- derelict_pos builds a
	# position from it -- and this is the only place that converts.
	return DeepSpace.compass_deg(p)


static func lair_pos(id: String, run_seed: int) -> Vector3:
	# WHERE THE ENGINE HIDES. One pure function, called by the builder, by the
	# intel channels, by the dressing and by every harness -- because the moment
	# two places derive this independently they will disagree, and a hunt whose
	# hints point somewhere the boss is not is worse than no hints at all.
	#
	# Salted on its OWN stream. It must never draw from the shared generator the
	# expanse rolls from: that sequence is linear, and a draw taken from it here
	# would move every rock, hulk, nest and station in the game.
	#
	# Depth is measured PAST the chart edge, so a bigger system pushes its own
	# lair out with it -- the same rule the bands already follow.
	var s := get_system(id)
	var lair: Dictionary = (s.get("apex", {}) as Dictionary).get("lair", {})
	if lair.is_empty():
		return Vector3.ZERO
	var band: Array = lair.get("depth", [200.0, 300.0])
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|lair|%d" % [id, run_seed])
	var bearing := rng.randf_range(0.0, TAU)
	var depth := rng.randf_range(float(band[0]), float(band[1]))
	var radius := float(s.get("bounds", 40.0)) + depth
	return Vector3(cos(bearing) * radius, 0.0, sin(bearing) * radius)


# --- hyper-structures (v20, Hunt stage 6) ------------------------------------
# WHERE THE INSTRUMENTS STAND. lair_pos's contract, three to five times over:
# one pure function, one salted stream, every consumer calls it.
#
# THE FLOOR IS DERIVED, NOT CHOSEN. The spec said 1500u, which is 6u past
# pyx03's worst-case lair depth and only 50u clear of its lair RADIUS (bounds 44
# + depth 1450 = 1494) -- inside LAIR_KEEPOUT 120, so a structure could roll
# into the apex arena. 1600 clears every authored system's lair ceiling by at
# least 150u, and OUTSIDE THE ARENA asserts that from the authored bands rather
# than from a lucky roll.
const HYPER_DEPTH_MIN := 1600.0
const HYPER_DEPTH_MAX := 4200.0
const HYPER_MIN := 3
const HYPER_MAX := 5
# How far apart any two instances in a system must stand. Finding one must tell
# you nothing about where the others are, and 700u is comfortably past the
# ~1000u silhouette range's usefulness as a lead -- you cannot see one from
# another.
const MIN_HYPER_SEPARATION := 700.0
# The fixed oversample. A rejection sampler's draw count varies with its luck,
# which makes the stream's shape a function of its own outcome; drawing a FIXED
# 16 candidate pairs and selecting from them keeps the shape invariant -- the
# same discipline deep_space.gd applies to its salted sub-streams.
const HYPER_CANDIDATES := 16


static func hyper_family(id: String) -> String:
	return String((get_system(id).get("hyper", {}) as Dictionary).get("family", ""))


static func hyper_designation(id: String, index: int) -> String:
	# "THE ORRERY - THIRD INSTRUMENT". Ordinals rather than numbers because the
	# game names things, and a numbered one reads as inventory.
	const ORDINALS := ["FIRST", "SECOND", "THIRD", "FOURTH", "FIFTH"]
	var fam := hyper_family(id)
	if fam == "":
		return ""
	var ord_name: String = ORDINALS[index] if index >= 0 and index < ORDINALS.size() \
		else str(index + 1)
	return "%s · %s INSTRUMENT" % [fam, ord_name]


static func hyper_positions(id: String, run_seed: int) -> Array:
	# Deterministic given (system, run_seed), and the ONE place any consumer
	# asks. Empty for a system with no hyper block, checked BEFORE the RNG is
	# constructed so an unauthored system costs nothing.
	var s := get_system(id)
	if (s.get("hyper", {}) as Dictionary).is_empty():
		return []
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|hyper|%d" % [id, run_seed])
	var bounds := float(s.get("bounds", 40.0))
	# COUNT FIRST, then a FIXED oversample regardless of it -- so the number of
	# draws this function makes does not depend on the count it rolled or on how
	# many candidates the separation test rejects.
	var want := HYPER_MIN + (rng.randi() % (HYPER_MAX - HYPER_MIN + 1))
	var cand_b: Array = []
	var cand_d: Array = []
	for i in range(HYPER_CANDIDATES):
		cand_b.append(rng.randf_range(0.0, TAU))
		# INDEPENDENT depth per candidate. One shared depth would put every
		# instance on one ring, and finding one would tell you the radius of
		# all the others -- the exact inference this pillar exists to deny.
		cand_d.append(rng.randf_range(HYPER_DEPTH_MIN, HYPER_DEPTH_MAX))
	var out: Array = []
	for i in range(HYPER_CANDIDATES):
		if out.size() >= want:
			break
		var radius: float = bounds + float(cand_d[i])
		var p := Vector3(cos(float(cand_b[i])) * radius, 0.0, sin(float(cand_b[i])) * radius)
		var clear := true
		for q_v in out:
			if p.distance_to(q_v as Vector3) < MIN_HYPER_SEPARATION:
				clear = false
				break
		if clear:
			out.append(p)
	return out


static func lair_depth(id: String, run_seed: int) -> float:
	# The lair's depth past the chart edge — what a bearing hint quotes and what
	# the band name is derived from. Recomputed rather than stored, so it can
	# never disagree with lair_pos.
	var p := lair_pos(id, run_seed)
	return maxf(p.length() - float(get_system(id).get("bounds", 40.0)), 0.0)


static func unlock_hint(id: String) -> String:
	# What stands between the player and this system, in one line. Two tiers, so
	# two hints — and the second one NAMES THE ENGINE, because "kill the boss" is
	# a chore and "silence THE GNOMON" is a hunt. The engine that jams a lane is
	# the one in the system you are flying FROM, which is `req`.
	var s := get_system(id)
	var req := String(s.get("unlocked_by", ""))
	if req == "":
		return ""
	var req_name := String(get_system(req).get("name", req))
	if not GameState.is_system_charted(id):
		return "BREACH THE %s DERELICT TO CHART" % req_name
	var engine := String((get_system(req).get("apex", {}) as Dictionary).get("name", "THE ENGINE"))
	return "LANE JAMMED — %s IS STILL TRANSMITTING. SILENCE IT." % engine
