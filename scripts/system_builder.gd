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
	_build_port(def, container)
	_build_deep_space(def, container, String(opts.get("system_id", "")))
	# Attract mode and the guided first run want the place without the ambush.
	# The Cordon is behind the SAME flag rather than a new one: nothing shoots
	# at a menu, and a title screen playing over a picket-vs-sentry skirmish is
	# noise. The tutorial suppresses both for the reason it already suppresses
	# sentries.
	if not bool(opts.get("skip_sentries", false)):
		build_garrison(def, container, String(opts.get("system_id", "")))


static func _build_deep_space(def: Dictionary, container: Node3D, system_id: String) -> void:
	# Everything outside the charted volume. A child of SystemRoot like all other
	# content, so a warp tears it down with the rest of the system.
	var deep := DeepSpace.new()
	deep.name = "DeepSpace"
	container.add_child(deep)
	deep.configure(def, system_id)


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

	var spin := lattice.create_tween().set_loops()
	spin.tween_property(lattice, "rotation:y", TAU, 240.0).from(0.0)


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
	var mult := float(def.get("difficulty", 1.0))
	for route_v in def.get("patrols", []):
		var route: Array = route_v
		if route.is_empty():
			continue
		var h := Hostile.new()
		h.difficulty = mult
		h.faction = "gsa"
		var pts: Array[Vector3] = []
		for p_v in route:
			pts.append(p_v as Vector3)
		h.patrol = pts
		container.add_child(h)
		# After add_child, like every other spawner in this file: a node has to
		# be in the tree before global_position means anything, and Hostile._home
		# is captured on the first frame precisely because of it.
		h.position = pts[0]
