class_name SystemBuilder
extends Object
# Turns a SystemDB definition into live scene content under a container node.
# Extracted from main.gd so every system is built the same way and a new one
# costs a data entry, not code.
#
# The container is freed wholesale on warp, so nothing here may parent itself
# to the scene root.


static func build(def: Dictionary, container: Node3D, opts := {}) -> void:
	# The registry belongs to the system currently in the tree; SystemRoot is
	# freed wholesale on warp, so its obstacles must go with it.
	Obstacles.clear()
	_build_environment(def, container)
	_build_lattice(def, container)
	_build_starfield(def, container)
	_build_haze(def, container)
	_build_bodies(def, container)
	_build_asteroids(def, container, String(opts.get("system_id", "")))
	_build_derelict(def, container, String(opts.get("system_id", "")))
	_build_training_hull(def, container)
	_build_apex(def, container, String(opts.get("system_id", "")))
	_build_hyper(def, container, String(opts.get("system_id", "")))
	_build_port(def, container)
	_build_deep_space(def, container, String(opts.get("system_id", "")))
	# Attract mode and the guided first run want the place without the ambush.
	# The Cordon is behind the SAME flag rather than a new one: nothing shoots
	# at a menu, and a title screen playing over a picket-vs-sentry skirmish is
	# noise. The tutorial suppresses both for the reason it already suppresses
	# sentries.
	if not bool(opts.get("skip_sentries", false)):
		build_garrison(def, container, String(opts.get("system_id", "")))


static func _build_hyper(def: Dictionary, container: Node3D, system_id: String) -> void:
	# v20 HUNT STAGE 6. Three to five instruments, always present, on the boss's
	# precedent — a thing whose job is to be seen from a thousand units away
	# must not wait for the cell streamer to reach it.
	#
	# POSITION AFTER add_child, like every spawner in this file: inside the
	# node's own _ready the position is still the origin, and _build_mesh reads
	# nothing positional, but the ordering rule holds so the next field added
	# here cannot break it quietly.
	if system_id == "":
		return
	var spots := SystemDB.hyper_positions(system_id, GameState.run_seed)
	for i in range(spots.size()):
		var h := HyperStructure.new()
		h.system_id = system_id
		h.index = i
		container.add_child(h)
		h.global_position = spots[i] as Vector3


static func _build_deep_space(def: Dictionary, container: Node3D, system_id: String) -> void:
	# Everything outside the charted volume. A child of SystemRoot like all other
	# content, so a warp tears it down with the rest of the system.
	var deep := DeepSpace.new()
	deep.name = "DeepSpace"
	container.add_child(deep)
	deep.configure(def, system_id)
	# The unsounded structures live PAST the last band edge, so they belong to
	# the deep the way the hyper structures do -- always present, never waiting
	# for the cell streamer, because a thing whose job is to stand at the end of
	# the world must actually be standing there when the player arrives. Built
	# here rather than in build() because placement needs this deep instance:
	# the reject loop below asks plan_cell where the stations are.
	_build_unsounded(deep, container, system_id)
	# And the network's buoys past even those, for the identical reason: a thing
	# the channel quotes a bearing to must be standing at that bearing when the
	# pilot arrives, whatever the cell streamer has reached.
	_build_far_marks(deep, container, system_id)


# HOW FAR A MARK MAY BE MOVED OFF THE GENERATOR'S ANSWER, in arc length, tried
# in this order: the nominal point first, then alternating sides at growing
# distance. A station's keep-out is 34u across, so the first step already clears
# any single station by construction (68 - 34 = 34), and the rest are for the
# rare case of a second one. THE HARNESS READS THIS LIST rather than a literal,
# so the bound it asserts is the bound the builder actually honours.
const MARK_ARCS := [0.0, 68.0, -68.0, 136.0, -136.0, 204.0, -204.0]

# THE PROVING DRIFT's numbers. Loot is sized against the band-6 deep hulk (70 x
# 4.6 = 322) and set above it: this is a windfall found at the end of a
# seven-thousand-unit flight, not a wreck the streamer put in your way. The
# crack is longer than a hulk's for the same reason a workshop is not a wreck.
const DRIFT_LOOT := 420
const DRIFT_CRACK_TIME := 3.6
# How far a legend stands off its buoy, so a tap near the mark can still reach
# the mark. Comfortably past Derelict.CRACK_RANGE (6.5) in screen terms without
# putting the legend out of sight of the lamp that names it. Shared by every
# kind that stands a node beside the spar.
const LEGEND_STANDOFF := 26.0

# THE VEIN's numbers (§101), provisional like the drift's and gathered the same
# way. Sixteen units of the richest band-6 ore is ~2.7x what the deepest rolled
# seam pays -- "richer than anything on the charted side" made arithmetic --
# and at space 1 it fits a starter hold, because a windfall the ship cannot
# carry is a taunt. The cut is the longest in the game for the same reason the
# archives hold longest: depth is time.
const VEIN_UNITS := 16
const VEIN_MINE_TIME := 9.0

# THE LAYUP's numbers (§101). The withdrawal sits between the band-6 deep hulk
# (322) and the drift (420): a cache is stores, not a workshop.
const LAYUP_LOOT := 380
const LAYUP_CRACK_TIME := 3.2


static func _build_far_marks(deep: DeepSpace, container: Node3D, system_id: String) -> void:
	# 98, THE FAR MARKS. Five buoys per system at 6,500-9,000u, where the
	# FarMarks generator says they stand and carrying the kind it deals them.
	# No draw of the shared stream moves: positions and kinds come off their own
	# salted seeds (far_marks.gd), and the keep-out below reads plan_cell, which
	# is pure.
	if system_id == "":
		return
	var spots := FarMarks.positions(system_id, GameState.run_seed)
	# THE PLAN ONCE, not per mark. kind_at builds the whole run's assignment on
	# every call -- it has to, because "at most once in an entire game" cannot be
	# decided one system at a time -- so asking it five times would rebuild the
	# same dictionary five times and call positions() fifteen more.
	var plan := FarMarks.run_plan(GameState.run_seed, SystemDB.ids())
	for i in range(spots.size()):
		var kind := String(plan.get("%s:%d" % [system_id, i], ""))
		if kind == "":
			# A MARK WITH NO NOTATION MUST NOT STAND. Unreachable while the
			# generator deals every slot, which is exactly why it is checked
			# here: a buoy whose plate is blank is a monument to nothing.
			continue
		var m := SoundingMark.new()
		m.system_id = system_id
		m.index = i
		m.kind = kind
		container.add_child(m)
		m.global_position = _mark_pos(deep, spots[i] as Vector3)
		# AND WHATEVER THE MARK HAS ALREADY BEEN READ INTO BEING. A legend is
		# built on the LOAD path and on the READ path, and both go through
		# build_legend -- the build_garrison rule one shelf down: the list that
		# raises a thing and the list that raises it again after a warp must be
		# the same list by construction, because being two lists is how a
		# headline feature ships invisible for a whole session.
		build_legend(container, system_id, i, kind, m.global_position)


static func build_legend(container: Node3D, system_id: String, index: int,
		kind: String, at: Vector3) -> Node3D:
	# §99. WHAT STANDS AT A MARK THE PILOT HAS READ. One function, two callers:
	# SystemBuilder above (every rebuild, for marks read in an earlier session)
	# and Main.legend_arrives (once, at the moment of reading, so the legend
	# does not wait for a warp).
	#
	# UNREAD MARKS BUILD NOTHING, and that is the horizon's own rule rather than
	# an optimisation: reading a mark is what resolves it, so a pilot who has
	# not read one has not found what stands there. SPENT marks build nothing
	# either -- a workshop is cracked once.
	var key := GameState.mark_key(system_id, index)
	if not GameState.is_mark_read(key):
		return null
	# THE SPENT CHECK IS PER KIND (§101), because "spent" does not mean one
	# thing: a spent drift or vein is GONE -- windfalls do not rebuild -- while
	# a spent layup is an OPEN CACHE, standing forever for deposits. Hoisting
	# the check above the match was correct for one kind and wrong the day the
	# second one shipped.
	match kind:
		"drift":
			if GameState.is_mark_spent(key):
				return null
			return _build_proving_drift(container, system_id, index, at)
		"vein":
			if GameState.is_mark_spent(key):
				return null
			return _build_vein(container, key, at)
		"layup":
			return _build_layup(container, key, at)
		"stillness":
			# The ground outlives its reading -- the layup's posture. The mark
			# spends when the reading is finally carried home, but every entry
			# becalms, forever: the place stays what it is.
			return _build_stillness(container, key, at)
		"order":
			if GameState.is_mark_spent(key):
				return null
			return _build_standing_order(container, key, at)
		"orrery":
			if GameState.is_mark_spent(key):
				return null
			return _build_orrery(container, key, at)
		"forge":
			# NEVER SPENDS ITS MARK -- a forge is a place, the serpent's rule.
			# It pays nothing (escorts are not currency), the wing it prints
			# cannot survive a warp, and arming it costs a kill, so rebuilding
			# it whole on every visit is a journey rather than a farm.
			return _build_forge(container, key, at)
		"serpent":
			# NEVER spent -- S2's rule enforced by never asking. The serpent
			# leaves rather than dies, so the mark keeps its warning and the
			# fight rebuilds whole on every visit. Not a respawn exploit,
			# because it has never once paid.
			return _build_serpent(container, key, at)
		_:
			# THE ONGOING FOUR ARRIVE IN COMMIT 5, and until they do a read
			# mark is exactly what its plate says it is: a record of a sounding,
			# in the past tense, which is why the plates were written that way.
			# The absence is stated here rather than left as a silent fallthrough
			# so the next commit has one obvious place to add a line.
			return null


static func _build_proving_drift(container: Node3D, system_id: String,
		index: int, at: Vector3) -> Node3D:
	# THE WORKSHOP HULL. A Derelict with two fields set, not a new class: §17's
	# rule, and this class is already a gradient of hull kinds -- the authored
	# survey hull, the tutorial's hull, the deep hulks and the grave-field pairs
	# are all the same node carrying different flags.
	#
	# counts_as_survey is FALSE for the deep hulk's exact reason, harder out
	# here: charting the next system by cracking something seven thousand units
	# past the chart edge would let the far deep skip the game's spine
	# altogether. counts_for_contract stays TRUE, also the deep hulk's rule --
	# you did breach a hull, and a contract that says so should say so.
	var d := Derelict.new()
	d.loot_total = DRIFT_LOOT
	d.crack_time = DRIFT_CRACK_TIME
	d.counts_as_survey = false
	# Set BEFORE add_child: _ready is what applies these, the ordering every
	# spawner in this file keeps.
	d.owns_mark = GameState.mark_key(system_id, index)
	d.prototype = FarMarks.drift_prototype(system_id, index, GameState.run_seed,
		ModuleDB.prototype_ids())
	container.add_child(d)
	# Offset off the buoy so the mark stays tappable beside it. The hull is the
	# thing you fly to; the mark is the thing that told you to.
	d.global_position = at + Vector3(LEGEND_STANDOFF, 0.0, 0.0)
	d.rotation_degrees.y = 34.0
	return d


static func _build_vein(container: Node3D, key: String, at: Vector3) -> Node3D:
	# §101. THE VEIN. A MineableSeam at band-6 parameters -- the machinery the
	# spec promised it would ride, with three fields moved and one added. The
	# good is the RICHEST of the band-6 table, picked by price rather than
	# rolled: the plate promises "richer than anything on the charted side",
	# and a roll that could land on the cheapest entry would make the plate a
	# liar one time in four. Deterministic, so the same vein pays the same ore
	# on every rebuild it survives.
	var table: Array = CommodityDB.seam_yields(6)
	if table.is_empty():
		return null
	var best := String(table[0])
	for g_v in table:
		if CommodityDB.base_price(String(g_v)) > CommodityDB.base_price(best):
			best = String(g_v)
	var seam := MineableSeam.new()
	seam.good = best
	seam.units = VEIN_UNITS
	seam.band = 6
	seam.mine_time = VEIN_MINE_TIME
	seam.owns_mark = key
	container.add_child(seam)
	seam.global_position = at + Vector3(LEGEND_STANDOFF, 0.0, 0.0)
	return seam


static func _build_layup(container: Node3D, key: String, at: Vector3) -> Node3D:
	# §101. THE LAYUP. A Derelict that takes deposits: the crack is the
	# withdrawal, once ever (the mark spends), and the open cache then stands
	# FOREVER -- built cracked on every rebuild after, which is the one legend
	# whose spent state means "still here" rather than "gone". counts_as_survey
	# false for the drift's reason; the deposit verb lives on the node.
	var d := Derelict.new()
	d.loot_total = LAYUP_LOOT
	d.crack_time = LAYUP_CRACK_TIME
	d.counts_as_survey = false
	d.takes_deposits = true
	d.owns_mark = key
	d.cracked = GameState.is_mark_spent(key)
	container.add_child(d)
	d.global_position = at + Vector3(LEGEND_STANDOFF, 0.0, 0.0)
	d.rotation_degrees.y = -28.0
	return d


static func _build_stillness(container: Node3D, key: String, at: Vector3) -> Node3D:
	# §102. Centred ON the mark, no standoff, and that is the drama working as
	# designed rather than an ambush: the buoy that warned you stands inside
	# the ground it warned you about, so the first becalming can begin where
	# you finished reading -- and the plate's promise ("they will come back")
	# is kept ninety seconds later, exactly as written.
	var g := StillnessGround.new()
	g.owns_mark = key
	container.add_child(g)
	g.global_position = at
	return g


static func _build_standing_order(container: Node3D, key: String, at: Vector3) -> Node3D:
	var o := StandingOrder.new()
	o.owns_mark = key
	container.add_child(o)
	o.global_position = at + Vector3(LEGEND_STANDOFF, 0.0, 0.0)
	return o


static func _build_orrery(container: Node3D, key: String, at: Vector3) -> Node3D:
	var o := Orrery.new()
	o.owns_mark = key
	container.add_child(o)
	o.global_position = at + Vector3(LEGEND_STANDOFF, 0.0, 0.0)
	return o


static func _build_forge(container: Node3D, key: String, at: Vector3) -> Node3D:
	var f := PatternForge.new()
	f.owns_mark = key
	container.add_child(f)
	f.global_position = at + Vector3(LEGEND_STANDOFF, 0.0, 0.0)
	return f


static func _build_serpent(container: Node3D, key: String, at: Vector3) -> Node3D:
	# Standing off twice the usual distance: the serpent's idle circuit is a
	# forty-unit orbit of its home point, and a home on the buoy would drag
	# the fight through the one thing out here the player must stay able to
	# tap calmly.
	var sp := SoundingSerpent.new()
	sp.owns_mark = key
	container.add_child(sp)
	sp.global_position = at + Vector3(LEGEND_STANDOFF * 2.0, 0.0, LEGEND_STANDOFF)
	return sp


static func _mark_pos(deep: DeepSpace, nominal: Vector3) -> Vector3:
	# THE GENERATOR SAYS WHERE; THIS SAYS HOW FAR IT MAY BE NUDGED. Band 6 runs
	# to the end of the world and STATION_CHANCE[6] is 0.135, so a deep station
	# can stand at eight thousand units — and a station's keep-out is 34u across
	# a 64u cell, which makes "a buoy inside one" a routine event rather than a
	# curiosity. Left alone, roughly one mark per run would sit inside a station
	# it did not know about, where the tap ladder resolves to the dock ring and
	# the mark is unreachable.
	#
	# WHY IT NUDGES INSTEAD OF REROLLING, which is where this parts company with
	# _unsounded_pos above: that function IS the generator for its own positions,
	# so it can throw an angle away and take another. A mark's position has a
	# second consumer — the channel quotes a bearing and a range to it at filing
	# time, off FarMarks.positions — so the built buoy has to stay where the
	# quote said. The offsets are ARC LENGTHS at a fixed radius, capped at 204u,
	# which at seven thousand units is 1.7 degrees and no change of range at all:
	# the quoted bearing still flies you to the lamp.
	#
	# THE 3x3 NEIGHBOURHOOD, not just the containing cell. STATION_INSET is 22
	# and STATION_SAFE_RADIUS is 34, so a station can be 22u from its own cell's
	# edge and therefore inside the keep-out of a point in the NEXT cell. Asking
	# only the containing cell (which is what _unsounded_pos does, at depths
	# where a station is rarer) would miss that band entirely.
	var radius := Vector2(nominal.x, nominal.z).length()
	if radius <= 0.0:
		return nominal
	var base := atan2(nominal.z, nominal.x)
	for arc in MARK_ARCS:
		var ang := base + float(arc) / radius
		var p := Vector3(cos(ang), 0.0, sin(ang)) * radius
		if _clear_of_stations(deep, p):
			return p
	# BOUNDED, and it ends by standing where it was told. Seven tries spanning
	# 408u of arc against a 68u obstacle cannot all fail unless the volume is
	# wall to wall with stations, and an unbounded search in a builder is how a
	# retune becomes a hang instead of a slightly awkward buoy.
	return nominal


static func _clear_of_stations(deep: DeepSpace, p: Vector3) -> bool:
	var cell := DeepSpace.cell_of(p)
	for dx in range(-1, 2):
		for dz in range(-1, 2):
			var station: Dictionary = deep.plan_cell(cell.x + dx, cell.y + dz)["station"]
			if station.is_empty():
				continue
			if p.distance_to(station.get("pos", Vector3(1e9, 0.0, 1e9))) \
					< DeepSpace.STATION_SAFE_RADIUS:
				return false
	return true


static func _build_unsounded(deep: DeepSpace, container: Node3D, system_id: String) -> void:
	# v23, THE UNSOUNDED. One authored record per system plus, in PYX-01, the
	# rival's wreck on the way out. Which kind stands where is DATA
	# (SystemDB.unsounded_kind_of), consumed here and never by the generator:
	# no draw moves, the world fingerprint stands.
	if system_id == "":
		return
	var kinds: Array = []
	var main_kind := SystemDB.unsounded_kind_of(system_id)
	if main_kind != "" and UnsoundedSite.DEPTHS.has(main_kind):
		kinds.append(main_kind)
	if SystemDB.rival_wreck_in(system_id):
		kinds.append("wreck")
	for kind_v in kinds:
		var kind := String(kind_v)
		var site := UnsoundedSite.new()
		site.kind = kind
		site.system_id = system_id
		container.add_child(site)
		site.global_position = _unsounded_pos(deep, system_id, kind)


static func _unsounded_pos(deep: DeepSpace, system_id: String, kind: String) -> Vector3:
	# A fixed DEPTH and a rolled bearing, on its own salted stream -- the
	# charted-seam rule: this thing persists a read across sessions, so its
	# position must be a pure function of (system, kind, run_seed), and it must
	# not touch the shared cell stream or every later draw in the system moves.
	#
	# The reject loop keeps it out of a deep station's keep-out. Sixteen tries
	# is not hope arithmetic: a station occupies at most STATION_SAFE_RADIUS of
	# a 64u cell on a circumference of thousands of units, so one rejection is
	# already rare and sixteen consecutive is beyond the age of the universe --
	# but the loop is bounded because unbounded loops in a builder are how a
	# bad retune becomes a hang instead of a bad place.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|unsounded|%s|%d" % [system_id, kind, GameState.run_seed])
	var radius := SystemDB.bounds_of(system_id) + float(UnsoundedSite.DEPTHS[kind])
	var pos := Vector3.ZERO
	for _i in range(16):
		var ang := rng.randf_range(0.0, TAU)
		pos = Vector3(cos(ang), 0.0, sin(ang)) * radius
		var cell := DeepSpace.cell_of(pos)
		var station: Dictionary = deep.plan_cell(cell.x, cell.y)["station"]
		if pos.distance_to(station.get("pos", Vector3(1e9, 0.0, 1e9))) \
				>= DeepSpace.STATION_SAFE_RADIUS:
			break
	return pos


static func _build_environment(def: Dictionary, container: Node3D) -> void:
	var e: Dictionary = def.get("env", {})
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = e.get("bg", Palette.SPACE_BG)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = e.get("ambient", Color(0.3, 0.35, 0.5))
	env.ambient_light_energy = float(e.get("ambient_energy", 0.6))
	env.glow_enabled = true
	env.glow_intensity = float(e.get("glow", 0.95))
	env.glow_bloom = 0.2
	env.glow_hdr_threshold = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	container.add_child(we)

	var sun := DirectionalLight3D.new()
	sun.light_color = e.get("sun_color", Color(0.8, 0.85, 1.0))
	sun.light_energy = float(e.get("sun_energy", 0.9))
	sun.rotation_degrees = Vector3(-50, 35, 0)
	container.add_child(sun)

	# From here the Environment has exactly one writer. The values set above are
	# the system's BASELINE; Atmosphere expresses depth and threat as multiples of
	# them, so a system authored dim stays dim. See scripts/atmosphere.gd.
	var air := Atmosphere.new()
	air.name = "Atmosphere"
	air.add_to_group("atmosphere")
	container.add_child(air)
	air.bind(env, sun)


static func _build_lattice(def: Dictionary, container: Node3D) -> void:
	# The compass cartography: concentric survey rings + radial bearing lines.
	var cfg: Dictionary = def.get("lattice", {})
	var color: Color = cfg.get("color", Palette.AMBER)
	var lattice := Node3D.new()
	lattice.name = "Lattice"
	container.add_child(lattice)
	lattice.position.y = -0.6

	for radius in cfg.get("radii", [7.0, 13.0, 20.0]):
		var mi := MeshInstance3D.new()
		var torus := TorusMesh.new()
		torus.inner_radius = float(radius) - 0.045
		torus.outer_radius = float(radius) + 0.045
		torus.ring_segments = 96
		mi.mesh = torus
		mi.material_override = Palette.emissive(Color(color.r, color.g, color.b, 0.28), 1.4)
		lattice.add_child(mi)

	# Spokes run the full width of the outermost survey ring, so the lattice
	# scales with the system instead of hanging in the middle of a big one.
	var radii: Array = cfg.get("radii", [7.0, 13.0, 20.0])
	var outer := 20.0
	for r_v in radii:
		outer = maxf(outer, float(r_v))

	var spokes := int(cfg.get("spokes", 8))
	for i in range(spokes):
		var ang := TAU * float(i) / float(spokes)
		var line := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.05, 0.01, outer * 1.7)
		line.mesh = box
		line.position = Vector3(cos(ang), 0, sin(ang)) * (outer * 0.58)
		line.rotation.y = -ang + PI / 2.0
		line.material_override = Palette.emissive(Color(color.r, color.g, color.b, 0.12), 1.2)
		lattice.add_child(line)

	# NO SPIN, AS OF THE COMPASS. This lattice turned a full revolution every
	# 240 seconds -- 1.5 degrees a second -- which was harmless while nothing in
	# the game claimed a fixed north. It is not harmless beside a HDG readout:
	# eight radial spokes rotating slowly past an instrument that says NORTH is
	# the world contradicting the cockpit, and a player navigating by the spokes
	# (which look exactly like a compass rose, because they are one) drifts a
	# degree and a half every second without being told.
	#
	# Left at rotation zero, spoke i sits at TAU*i/spokes, so the authored eight
	# put a spoke on each of DeepSpace.QUADRANTS' four cardinals. It becomes the
	# instrument it always resembled.
	#
	# WHAT ELSE THE TWEEN TOUCHED: nothing. Only this node's own rotation.y; the
	# rings are surfaces of revolution and never looked different for it, and no
	# code anywhere reads lattice.rotation. It also ignored reduce_motion(),
	# which it should not have -- so this closes an accessibility gap by
	# deletion rather than by another branch.
	lattice.add_to_group("lattice")


static func _build_starfield(def: Dictionary, container: Node3D) -> void:
	var cfg: Dictionary = def.get("starfield", {})
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := SphereMesh.new()
	mesh.radius = 0.05
	mesh.height = 0.1
	mesh.radial_segments = 6
	mesh.rings = 3
	mesh.material = Palette.emissive(cfg.get("tint", Color(0.85, 0.9, 1.0)), 1.6)
	mm.mesh = mesh
	mm.instance_count = int(cfg.get("count", 350))
	var spread := float(cfg.get("spread", 70.0))
	for i in range(mm.instance_count):
		var pos := Vector3(randf_range(-spread, spread), randf_range(-40, -6),
			randf_range(-spread, spread))
		var s := randf_range(0.5, 1.6)
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3.ONE * s), pos))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	container.add_child(mmi)


static func _build_haze(def: Dictionary, container: Node3D) -> void:
	# Cheap nebula: huge low-alpha unshaded spheres below the play plane. Costs
	# almost nothing and does most of the work of giving a system its color.
	for blob in def.get("haze", []):
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 12
		sm.rings = 8
		mi.mesh = sm
		mi.position = blob["pos"]
		mi.scale = Vector3.ONE * float(blob["scale"])
		var mat := Palette.emissive(blob["color"], 1.1)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.cull_mode = BaseMaterial3D.CULL_FRONT
		mi.material_override = mat
		container.add_child(mi)


static func _build_bodies(def: Dictionary, container: Node3D) -> void:
	# Celestial landmarks. Planets and moons are solid and give each system
	# something to navigate by; comets are scenic and deliberately not solid.
	for cfg_v in def.get("bodies", []):
		var cfg: Dictionary = cfg_v
		match String(cfg.get("kind", "moon")):
			"comet":
				_build_comet(cfg, container)
			_:
				_build_world(cfg, container)


static func _build_world(cfg: Dictionary, container: Node3D) -> void:
	var radius := float(cfg.get("radius", 6.0))
	var pos: Vector3 = cfg.get("pos", Vector3.ZERO)

	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = radius
	sm.height = radius * 2.0
	sm.radial_segments = 24
	sm.rings = 14
	body.mesh = sm
	body.position = pos
	body.position.y = -radius * 0.25   # sits slightly below the play plane
	body.material_override = Palette.matte(cfg.get("color", Color(0.2, 0.2, 0.24)))
	container.add_child(body)

	if bool(cfg.get("cracked", false)):
		# A rift across the surface, so the moon reads as broken rather than bald.
		for i in range(3):
			var rift := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(radius * 0.12, radius * 0.1, radius * 1.7)
			rift.mesh = bm
			rift.position = body.position + Vector3(
				randf_range(-radius * 0.4, radius * 0.4), radius * 0.82,
				randf_range(-radius * 0.3, radius * 0.3))
			rift.rotation.y = randf_range(-0.5, 0.5)
			rift.material_override = Palette.matte(Color(0.06, 0.06, 0.08))
			container.add_child(rift)

	var ring: Dictionary = cfg.get("ring", {})
	if not ring.is_empty():
		var r := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = radius * float(ring.get("inner", 1.5))
		tm.outer_radius = radius * float(ring.get("outer", 2.2))
		tm.ring_segments = 64
		r.mesh = tm
		r.position = body.position
		r.scale.y = 0.05          # flatten the donut into a disc
		var mat := Palette.emissive(ring.get("color", Color(0.9, 0.5, 0.25, 0.5)), 1.1)
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		r.material_override = mat
		container.add_child(r)

	# Collide against the visible silhouette on the play plane.
	Obstacles.add(pos, radius * 0.95)


static func _build_comet(cfg: Dictionary, container: Node3D) -> void:
	# Scenic and non-solid: something moving in the sky, nothing to crash into.
	var comet := Node3D.new()
	container.add_child(comet)
	comet.position = cfg.get("from", Vector3(-40, 0, -30))

	var head := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 10
	sm.rings = 6
	head.mesh = sm
	head.material_override = Palette.emissive(cfg.get("color", Color(0.7, 0.9, 1.0)), 2.6)
	comet.add_child(head)

	var tail := CPUParticles3D.new()
	tail.amount = 90
	tail.lifetime = 2.4
	tail.local_coords = false
	tail.direction = Vector3.ZERO
	tail.spread = 12.0
	tail.initial_velocity_min = 0.2
	tail.initial_velocity_max = 0.9
	tail.gravity = Vector3.ZERO
	tail.scale_amount_min = 0.08
	tail.scale_amount_max = 0.3
	tail.color = cfg.get("color", Color(0.7, 0.9, 1.0))
	var pm := SphereMesh.new()
	pm.radius = 0.16
	pm.height = 0.32
	pm.radial_segments = 6
	pm.rings = 3
	pm.material = Palette.emissive(cfg.get("color", Color(0.7, 0.9, 1.0)), 2.0)
	tail.mesh = pm
	comet.add_child(tail)

	var tw := comet.create_tween().set_loops()
	tw.tween_property(comet, "position", cfg.get("to", Vector3(40, 0, 30)),
		float(cfg.get("period", 90.0)))
	tw.tween_property(comet, "position", cfg.get("from", Vector3(-40, 0, -30)), 0.01)


static func _build_asteroids(def: Dictionary, container: Node3D, system_id := "") -> void:
	var index := -1
	for cfg in def.get("asteroids", []):
		index += 1
		var rock := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 10
		sm.rings = 6
		rock.mesh = sm
		rock.position = cfg["pos"]
		rock.scale = cfg["scale"]
		rock.rotation_degrees = Vector3(randf_range(0, 360), randf_range(0, 360), 0)
		rock.material_override = Palette.matte(Color(0.13, 0.12, 0.13))
		container.add_child(rock)
		# Collide against the rock's footprint on the play plane, using the
		# smaller horizontal axis so the sphere sits inside the visible mesh.
		var s: Vector3 = cfg["scale"]
		var radius := minf(s.x, s.z) * 0.82
		Obstacles.add(cfg["pos"], radius)
		_build_charted_seam(container, cfg, radius, system_id, index)


static func _build_charted_seam(container: Node3D, cfg: Dictionary, radius: float,
		system_id: String, index: int) -> void:
	# One seam per authored asteroid: eleven in the whole game, and the reason
	# charted mining is a WINDFALL rather than an income. They are placed here from
	# authored data rather than rolled, because they PERSIST and a persistent thing
	# needs a stable identity -- the key is the system id and this rock's array
	# INDEX, so reordering an `asteroids` array rekeys a player's cut seams.
	if system_id == "":
		return
	# DETERMINISTIC angle, on its own local stream. Two reasons it cannot use the
	# shared randf() the rock rotation above uses: that stream would shift every
	# later draw in the system, and a seam whose angle re-rolled on each rebuild
	# would move a SPENT face somewhere new every time the player warped home.
	var srng := RandomNumberGenerator.new()
	srng.seed = hash("%s|%d|chartseam" % [system_id, index])
	var table: Array = CommodityDB.seam_yields(0)
	if table.is_empty():
		return
	var seam := MineableSeam.new()
	seam.good = String(table[srng.randi() % table.size()])
	seam.units = DeepSpace.SEAM_UNITS[0]
	seam.band = 0
	seam.mine_time = 4.0 + 0.6 * (0 - 1)
	seam.charted_key = GameState.seam_key(system_id, index)
	seam.mined = GameState.is_seam_cut(seam.charted_key)
	container.add_child(seam)
	# The rock sits below the play plane; the seam stands off its collision sphere
	# ON the plane, which is the one geometry rule that makes a single MINE_RANGE
	# correct at every rock size. See mineable_seam.gd's header.
	var ang := srng.randf_range(0.0, TAU)
	var flat: Vector3 = Vector3(cfg["pos"].x, 0.0, cfg["pos"].z)
	seam.position = flat + Vector3(cos(ang), 0.0, sin(ang)) \
		* (radius + DeepSpace.SEAM_STANDOFF)


static func _build_derelict(def: Dictionary, container: Node3D, system_id := "") -> void:
	# THE SURVEY HULL, now outside the cordon. Position comes from
	# SystemDB.derelict_pos and nowhere else -- the builder does not compute a
	# bearing of its own, because the tutorial's broadcast and the expanse's
	# keep-out both have to agree with wherever this thing ends up.
	var cfg: Dictionary = def.get("derelict", {})
	if cfg.is_empty():
		return
	var d := Derelict.new()
	d.loot_total = int(cfg.get("loot", 70))
	d.crack_time = float(cfg.get("crack_time", 1.8))
	container.add_child(d)
	d.position = SystemDB.derelict_pos(system_id) if system_id != "" \
		else cfg.get("pos", Vector3(-9, 0, -15))
	d.rotation_degrees.y = float(cfg.get("rot_y", 25.0))
	# Two modest spheres along the hull spine rather than one big one. Sized and
	# tucked in deliberately: a collision volume must never encroach on the
	# interaction affordance it belongs to. At 2.4/±3.0 the ship parked 6.8 from
	# the breach point against CRACK_RANGE 6.5 and could never start the hold.
	var fwd := d.global_transform.basis.z
	Obstacles.add(d.position - fwd * 2.6, 1.9)
	Obstacles.add(d.position + fwd * 2.6, 1.9)


static func _build_training_hull(def: Dictionary, container: Node3D) -> void:
	# THE TUTORIAL'S HULL, on the berth the survey hull used to hold. PYX-01
	# only, and it exists because the guided first run ends on a breach and the
	# survey hull is now a hundred units past the marker — an expedition is the
	# wrong sixth step for a pilot who has just been taught which key moves the
	# ship.
	#
	# `counts_as_survey = false` is the WHOLE mechanism: it is the flag deep
	# hulks have carried since the expanse shipped, and it already means
	# "charts nothing, wakes nothing, files no bearing". No new gate, no new
	# class, and no second thing that can claim the progression.
	var cfg: Dictionary = def.get("training_hull", {})
	if cfg.is_empty():
		return
	var d := Derelict.new()
	d.loot_total = int(cfg.get("loot", 16))
	d.crack_time = float(cfg.get("crack_time", 1.4))
	d.counts_as_survey = false
	container.add_child(d)
	# Its own group, so the tutorial can name the hull it means. With two
	# crackables in PYX-01, get_first_node_in_group("crackable") answers
	# "whichever is first in the tree", which is not a rule anything should
	# depend on.
	d.add_to_group("training_hull")
	d.position = cfg.get("pos", Vector3(-9, 0, -18))
	d.rotation_degrees.y = float(cfg.get("rot_y", 25.0))
	var tfwd := d.global_transform.basis.z
	Obstacles.add(d.position - tfwd * 2.6, 1.9)
	Obstacles.add(d.position + tfwd * 2.6, 1.9)


static func _build_apex(def: Dictionary, container: Node3D, system_id := "") -> void:
	# What stands at the lair depends on what the player has already done here.
	# The old comment claimed the engine "only exists once this system's derelict
	# has been breached" and nothing in this function ever checked that; breaching
	# gates the WAKE (main.gd's `_apex_wake_timer`), never the build.
	#
	# v17. AND THE KILL IS NOW ASKED ABOUT AT ALL. Every child of SystemRoot is
	# freed and rebuilt on entry, so with no question asked here a cleared system
	# handed back a full-strength engine the moment the player warped out and
	# came home — which stopped being a windfall the day stage 1 made the engine
	# the gate to the next system, and started being a toll.
	var cfg: Dictionary = def.get("apex", {})
	if cfg.is_empty():
		return

	if GameState.has_apex_down(system_id):
		# The engine is dead and stays dead. Its WRECK, though, outlives the warp:
		# cracking it is a second trip, and the first-kill bonus riding on it is
		# 15,000-32,000 credits. Losing that to a jump the player had every reason
		# to make would be a silent punishment for leaving, so the wreck is rebuilt
		# until somebody actually breaches it.
		if not GameState.has_killed_apex(system_id):
			_build_apex_wreck(cfg, container, system_id)
		return

	var boss := ApexBoss.new()
	boss.difficulty = float(cfg.get("difficulty", 1.0))
	boss.loot_total = int(cfg.get("loot", 90))
	boss.first_kill_bonus = int(cfg.get("bonus", 15000))
	# Identity is data like everything else: the name on the HUD bar and the
	# armament the hub fires with both come off the system def.
	boss.boss_name = String(cfg.get("name", "THE GNOMON"))
	boss.attack_kind = String(cfg.get("attack", "shadow_lance"))
	container.add_child(boss)
	# v15. OUT IN THE DEEP, at a place this run picked. The engine used to sit at
	# an authored point ~60% of the way to the chart edge, in plain sight on the
	# radar, gating nothing. Now it hides, and finding it is the game.
	boss.position = SystemDB.lair_pos(system_id, GameState.run_seed) \
		if system_id != "" else cfg.get("pos", Vector3(6, 0, -18))
	# Registered here, after positioning: inside the node's own _ready the
	# position is still the origin.
	Obstacles.add(boss.position, ApexBoss.HUB_RADIUS * 0.75)


static func _build_apex_wreck(cfg: Dictionary, container: Node3D, system_id: String) -> void:
	# The same three fields ApexBoss._become_wreck hands it, off the same system
	# def the engine was built from, so a wreck that survived a warp is the wreck
	# that died here rather than a default-valued lookalike carrying 15,000.
	#
	# No Obstacles.add: the hub's keep-out belongs to the engine that was flying
	# it, and _become_wreck never registered one either. A wreck is something you
	# park against on purpose.
	var wreck := ApexWreck.new()
	wreck.loot_total = int(cfg.get("loot", 90))
	wreck.first_kill_bonus = int(cfg.get("bonus", 15000))
	wreck.system_id = system_id
	container.add_child(wreck)
	wreck.position = SystemDB.lair_pos(system_id, GameState.run_seed) \
		if system_id != "" else cfg.get("pos", Vector3(6, 0, -18))


static func _build_port(def: Dictionary, container: Node3D) -> void:
	# Primary plus any secondaries, all through one path: a station is a station,
	# and what makes the Cantina different from the Yards is its services list,
	# not its construction.
	var primary: Dictionary = def.get("port", {})
	var all: Array = []
	if not primary.is_empty():
		all.append(primary)
	for extra in def.get("ports", []):
		all.append(extra)

	for cfg_v in all:
		var cfg: Dictionary = cfg_v
		var port := Port.new()
		port.port_id = String(cfg.get("id", "port"))
		port.port_name = String(cfg.get("name", "PORT"))
		port.kind = String(cfg.get("kind", "station"))
		container.add_child(port)
		port.position = cfg.get("pos", Vector3(-14, 0, 4))
		# Solid hull; the dock ring sits at +Z 4.2, outside this radius, so the
		# approach lane stays open.
		Obstacles.add(port.position, Port.HULL_OBSTACLE_RADIUS)


static func build_garrison(def: Dictionary, container: Node3D, system_id := "") -> void:
	# EVERYTHING `skip_sentries` HOLDS BACK, IN ONE FUNCTION, and that is the
	# whole point of it existing. Public so the tutorial can arm a system in
	# place, without a rebuild that would wipe whatever the player just earned.
	#
	# It was two calls at the top of build() and ONE call on the deferred path,
	# and stage 2a added the Cordon to the first without touching the second.
	# The result shipped: a player who pressed NEW SURVEY got sentries five
	# seconds after the tutorial and NO PICKETS AT ALL until they warped, so
	# the headline feature of the horizon was invisible for the entire first
	# session. Nothing asserted it because the assertions all drove
	# SystemBuilder.build() — the path the player does NOT take out of the
	# tutorial. THE GARRISON IS WHAT THE TUTORIAL HELD BACK now drives the real
	# one.
	#
	# So the suppress list and the restore list are the same list, by
	# construction rather than by agreement, and the next thing added to the
	# garrison cannot go missing from one of them.
	_build_sentries(def, container, system_id)
	_build_patrols(def, container)


static func _build_sentries(def: Dictionary, container: Node3D, system_id := "") -> void:
	# v18 stage 3. The garrison flies the host engine's flag. Defaulting to
	# FERAL when no system id is supplied keeps every harness that builds a
	# system by hand producing the world it was written against.
	var flag := SystemDB.faction_of(system_id) if system_id != "" else FactionDB.FERAL
	var mult := float(def.get("difficulty", 1.0))
	for pos in def.get("sentries", []):
		var h := Hostile.new()
		h.difficulty = mult
		h.faction = flag
		# A POST IS A PLACE YOU STAND, NOT A PLACE YOU FREEZE (v18, playtest
		# round 4). Set HERE and nowhere else: the same class station-keeps every
		# deep guard and every station guard, and those are asserted to sit
		# within 0.6u of a planned post and outside crack range of a breach
		# point, so the orbit is opt-in per node rather than a change to
		# Hostile's station-keeping branch.
		h.beat_radius = Hostile.SENTRY_BEAT_RADIUS
		container.add_child(h)
		h.position = pos


static func _build_patrols(def: Dictionary, container: Node3D) -> void:
	# v18. THE CORDON. A picket is a Hostile with a route and a flag — not a new
	# class. The airframe is the same machine the expanse already dresses out as
	# "GSA PICKET — DECOMMISSIONED"; this is the living version, and the tell is
	# paint, per the raider precedent.
	#
	# This function does NOT police the data. The chart-edge rule is checked by
	# PYXIS_FACTIONTEST's THE CORDON STOPS AT THE MARKER, over the authored
	# table, before anything is built — which is strictly earlier than a runtime
	# clamp (it would drag a picket home and hide the mistake) or an assert
	# (stripped from release builds, and this codebase uses none).
	for i in range((def.get("patrols", []) as Array).size()):
		build_picket(def, container, i)


static func build_picket(def: Dictionary, container: Node3D, route_i: int,
		enter_at := 0) -> Hostile:
	# ONE PLACE THAT KNOWS WHAT A PICKET IS, so the Cordon's first deployment and
	# its re-form (Main._tick_cordon, v18 playtest round 4) cannot drift apart.
	# This is build_garrison's own argument applied one level down: there, the
	# suppress list and the restore list are the same list by construction rather
	# than by agreement, because being two lists is exactly how stage 2a shipped
	# a first session with sentries and no Cordon in it at all.
	var routes: Array = def.get("patrols", [])
	if route_i < 0 or route_i >= routes.size():
		return null
	var route: Array = routes[route_i]
	if route.is_empty():
		return null
	var h := Hostile.new()
	h.difficulty = float(def.get("difficulty", 1.0))
	h.faction = "gsa"
	var pts: Array[Vector3] = []
	for p_v in route:
		pts.append(p_v as Vector3)
	h.patrol = pts
	# WHICH BEAT THIS IS. "Which routes are unmanned" has to be a lookup rather
	# than a geometry guess: two routes can pass within a few units of each other
	# (PYX-03 authors four), so asking "is anything standing near waypoint 0"
	# would call a route manned because a NEIGHBOURING picket happened to be
	# walking past it, and the Cordon would re-form one ship short forever. Set
	# before add_child, like every other field here.
	h.set_meta("route_i", route_i)
	container.add_child(h)
	# After add_child, like every other spawner in this file: a node has to
	# be in the tree before global_position means anything, and Hostile._home
	# is captured on the first frame precisely because of it.
	var at := enter_at if enter_at >= 0 and enter_at < pts.size() else 0
	h.position = pts[at]
	h.enter_beat(at)
	return h
