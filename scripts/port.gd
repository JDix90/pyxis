class_name Port
extends Node3D
# A dockable place. Seven silhouettes over one contract, so adding a port is a
# data entry rather than a new class — and each shape is used by exactly one
# archetype at any depth a player can reach it, because a port's NAME only
# appears at DOCK_RANGE and a shape shared by two counters at the same band
# means flying four hundred units to find out which one you picked.
#
# Docking is the game's only safe state: clamped on, nothing can hurt you and
# nothing hunts you. It is refused during an apex fight, because breaking off a
# boss by parking is not a decision, it is an exit.
#
# Speaks the same duck-typed interaction contract as Derelict/ApexWreck
# (`pick_anchor`, `on_tapped`), so CameraRig needs no special case.

const DOCK_RANGE := 5.0
const APPROACH_STOP := 3.2

var port_id := ""
# Which bonded store this station's bay is. For a charted port it is the port id;
# for a deep station it is its CELL, set by DeepSpace — because port_id out there
# is the archetype, shared by every station of that kind in every system.
var bay_key := ""
var port_name := "PORT"
var kind := "station"

# The port's own definition, set by whoever built it. Empty for a charted port,
# which looks itself up in SystemDB exactly as it always has; set by DeepSpace
# for a station out past the chart, which is not in SystemDB and must never be —
# `SystemDB.port_ids()` drives market events, the rumour engine and three
# STATIONTEST sweeps, and none of them should ever see the expanse.
var def := {}

var dock_point := Vector3.ZERO
var docked := false

var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _beacon_mat: StandardMaterial3D
var _in_range_last := false
var _spin := 0.0
# Nav strobes. Three is enough to read as "maintained" and cheap enough that a
# deep-space window full of stations costs nothing.
const STROBE_COUNT := 3
var _strobes: Array[StandardMaterial3D] = []
var _strobe_phase: Array[float] = []
var _strobe_rate: Array[float] = []


const HULL_OBSTACLE_RADIUS := 3.0


func _ready() -> void:
	add_to_group("dockable")
	_build()
	# NOTE: the obstacle is registered by SystemBuilder *after* this node is
	# positioned. Registering here would place it at the origin, because _ready
	# runs on add_child and `position` is assigned afterwards.


func pick_anchor() -> Vector3:
	return dock_point


# --- construction -----------------------------------------------------------

func _build() -> void:
	match kind:
		"colony":
			_build_colony()
		"military":
			_build_military()
		"cantina":
			_build_cantina()
		"depot":
			_build_depot()
		"den":
			_build_den()
		"bulwark":
			_build_bulwark()
		"lantern":
			_build_lantern()
		_:
			_build_station()
	_build_dock_ring()
	_build_strobes()


func _build_cantina() -> void:
	# A pleasure ring lit like a sign. The only warm, inviting silhouette in the
	# game — everything else out here is industrial or hostile.
	var core := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.5
	cm.bottom_radius = 1.1
	cm.height = 2.4
	core.mesh = cm
	core.material_override = Palette.matte(Color(0.26, 0.14, 0.2))
	add_child(core)

	# Stacked neon hoops, widest at the base.
	for i in range(3):
		var hoop := MeshInstance3D.new()
		var tm := TorusMesh.new()
		tm.inner_radius = 2.4 - float(i) * 0.5
		tm.outer_radius = 2.62 - float(i) * 0.5
		tm.ring_segments = 26
		hoop.mesh = tm
		hoop.position.y = -0.6 + float(i) * 0.7
		hoop.scale.y = 0.3
		var hues: Array[Color] = [Color(1.0, 0.3, 0.5), Color(1.0, 0.62, 0.2), Color(0.5, 0.85, 1.0)]
		var hue: Color = hues[i]
		hoop.material_override = Palette.emissive(hue, 2.8)
		add_child(hoop)

	for i in range(8):
		var ang := TAU * float(i) / 8.0
		var lamp := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.15
		lm.height = 0.3
		lm.radial_segments = 6
		lm.rings = 3
		lamp.mesh = lm
		lamp.position = Vector3(cos(ang) * 1.9, 1.35, sin(ang) * 1.9)
		lamp.material_override = Palette.emissive(Palette.GOLD, 3.2)
		add_child(lamp)


func _build_depot() -> void:
	# Gantries and tanks. Reads as a place that makes things, not sells them.
	var spine := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(1.3, 1.3, 5.2)
	spine.mesh = sm
	spine.material_override = Palette.matte(Color(0.22, 0.21, 0.18))
	add_child(spine)

	for z in [-1.5, 0.0, 1.5]:
		var gantry := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(4.4, 0.24, 0.3)
		gantry.mesh = gm
		gantry.position = Vector3(0, 0.75, z)
		gantry.material_override = Palette.matte(Color(0.3, 0.28, 0.24))
		add_child(gantry)

		for side in [-1.0, 1.0]:
			var tank := MeshInstance3D.new()
			var tm := CylinderMesh.new()
			tm.top_radius = 0.5
			tm.bottom_radius = 0.5
			tm.height = 1.1
			tank.mesh = tm
			tank.rotation_degrees.z = 90.0
			tank.position = Vector3(side * 2.0, 0.75, z)
			tank.material_override = Palette.matte(Color(0.34, 0.3, 0.26))
			add_child(tank)

	for i in range(5):
		var strip := MeshInstance3D.new()
		var stm := BoxMesh.new()
		stm.size = Vector3(0.1, 0.1, 0.7)
		strip.mesh = stm
		strip.position = Vector3(0.72, 0.2, -2.0 + float(i) * 1.0)
		strip.material_override = Palette.emissive(Color(1.0, 0.55, 0.15), 2.2)
		add_child(strip)


func _build_den() -> void:
	# A hollowed rock with a hatch. Nothing announces itself; that is the point.
	var rock := MeshInstance3D.new()
	var rm := SphereMesh.new()
	rm.radius = 1.0
	rm.height = 2.0
	rm.radial_segments = 9
	rm.rings = 6
	rock.mesh = rm
	rock.scale = Vector3(2.9, 2.1, 2.6)
	rock.rotation_degrees = Vector3(14, 32, 8)
	rock.material_override = Palette.matte(Color(0.11, 0.1, 0.12))
	add_child(rock)

	# Bay mouth cut into the near face, lit from inside.
	var mouth := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(1.5, 0.9, 0.5)
	mouth.mesh = mm
	mouth.position = Vector3(0, 0, 2.0)
	mouth.material_override = Palette.emissive(Color(1.0, 0.2, 0.45), 1.8)
	add_child(mouth)

	for cfg in [Vector3(-1.5, 0.7, 0.9), Vector3(1.7, 0.4, -0.6), Vector3(0.3, 0.9, -1.8)]:
		var vent := MeshInstance3D.new()
		var vm := BoxMesh.new()
		vm.size = Vector3(0.22, 0.22, 0.22)
		vent.mesh = vm
		vent.position = cfg
		vent.material_override = Palette.emissive(Color(0.35, 1.0, 0.65), 2.0)
		add_child(vent)

	# One mast, deliberately unlit: it is not advertising.
	var mast := MeshInstance3D.new()
	var mstm := CylinderMesh.new()
	mstm.top_radius = 0.05
	mstm.bottom_radius = 0.1
	mstm.height = 2.0
	mast.mesh = mstm
	mast.position = Vector3(-0.8, 1.6, 0.4)
	mast.material_override = Palette.matte(Color(0.2, 0.19, 0.22))
	add_child(mast)


func _build_station() -> void:
	# Trade ring on spokes around a hub — reads as neutral infrastructure.
	var hub := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.9
	hm.bottom_radius = 0.9
	hm.height = 1.6
	hub.mesh = hm
	hub.material_override = Palette.matte(Color(0.2, 0.2, 0.24))
	add_child(hub)

	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.5
	tm.outer_radius = 3.1
	tm.ring_segments = 32
	ring.mesh = tm
	ring.material_override = Palette.matte(Color(0.26, 0.26, 0.3))
	add_child(ring)

	for i in range(4):
		var ang := TAU * float(i) / 4.0
		var spoke := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.3, 0.3, 2.6)
		spoke.mesh = sm
		spoke.position = Vector3(cos(ang), 0, sin(ang)) * 1.5
		spoke.rotation.y = -ang + PI / 2.0
		spoke.material_override = Palette.matte(Color(0.22, 0.22, 0.26))
		add_child(spoke)

	for i in range(10):
		var ang := TAU * float(i) / 10.0
		var light := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.16, 0.16, 0.16)
		light.mesh = lm
		light.position = Vector3(cos(ang), 0.18, sin(ang)) * 2.8
		light.material_override = Palette.emissive(Palette.AMBER, 2.2)
		add_child(light)


func _build_colony() -> void:
	# Domes clustered on a rock. Industry, not elegance.
	var rock := MeshInstance3D.new()
	var rm := SphereMesh.new()
	rm.radius = 1.0
	rm.height = 2.0
	rm.radial_segments = 10
	rm.rings = 6
	rock.mesh = rm
	rock.scale = Vector3(3.6, 1.5, 3.2)
	rock.position.y = -0.6
	rock.material_override = Palette.matte(Color(0.16, 0.12, 0.11))
	add_child(rock)

	for cfg in [
		{"pos": Vector3(0, 0.5, 0), "r": 1.15},
		{"pos": Vector3(1.9, 0.3, 0.9), "r": 0.75},
		{"pos": Vector3(-1.7, 0.3, -1.0), "r": 0.85},
		{"pos": Vector3(0.5, 0.25, -2.0), "r": 0.6},
	]:
		var dome := MeshInstance3D.new()
		var dm := SphereMesh.new()
		dm.radius = float(cfg["r"])
		dm.height = float(cfg["r"]) * 1.5
		dm.radial_segments = 12
		dm.rings = 6
		dome.mesh = dm
		dome.position = cfg["pos"]
		dome.material_override = Palette.matte(Color(0.3, 0.24, 0.22))
		add_child(dome)

		var glow := MeshInstance3D.new()
		var gm := BoxMesh.new()
		gm.size = Vector3(float(cfg["r"]) * 1.1, 0.1, 0.1)
		glow.mesh = gm
		glow.position = cfg["pos"] + Vector3(0, float(cfg["r"]) * 0.45, 0)
		glow.material_override = Palette.emissive(Color(1.0, 0.55, 0.25), 2.4)
		add_child(glow)

	for i in range(3):
		var stack := MeshInstance3D.new()
		var sm := CylinderMesh.new()
		sm.top_radius = 0.16
		sm.bottom_radius = 0.24
		sm.height = 2.2
		stack.mesh = sm
		stack.position = Vector3(-2.4 + i * 0.7, 0.9, 1.9)
		stack.material_override = Palette.matte(Color(0.2, 0.16, 0.15))
		add_child(stack)


func _build_military() -> void:
	# Slab hull with gun towers. Unwelcoming on purpose.
	var core := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(4.4, 1.6, 2.6)
	core.mesh = cm
	core.material_override = Palette.matte(Color(0.17, 0.18, 0.22))
	add_child(core)

	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(1.2, 1.0, 4.2)
		wing.mesh = wm
		wing.position = Vector3(side * 2.4, 0, 0)
		wing.material_override = Palette.matte(Color(0.15, 0.16, 0.2))
		add_child(wing)

		for z in [-1.4, 1.4]:
			var tower := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(0.36, 1.2, 0.36)
			tower.mesh = tm
			tower.position = Vector3(side * 2.4, 0.9, z)
			tower.material_override = Palette.matte(Color(0.22, 0.23, 0.28))
			add_child(tower)

			var muzzle := MeshInstance3D.new()
			var mm := BoxMesh.new()
			mm.size = Vector3(0.14, 0.14, 0.5)
			muzzle.mesh = mm
			muzzle.position = Vector3(side * 2.4, 1.4, z)
			muzzle.material_override = Palette.emissive(Palette.TEAL, 1.8)
			add_child(muzzle)

	for i in range(6):
		var strip := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.5, 0.08, 0.08)
		strip.mesh = sm
		strip.position = Vector3(-1.8 + i * 0.72, 0.85, 1.2)
		strip.material_override = Palette.emissive(Color(0.6, 0.68, 1.0), 2.0)
		add_child(strip)


func _build_strobes() -> void:
	# Nav strobes: three tiny emissive markers on a slow asynchronous blink.
	#
	# A station that pulses one ring and nothing else reads as a prop. Real
	# structures out in the dark are covered in lights that are not synchronised
	# with each other, and that lack of synchronisation is most of what says
	# "somebody maintains this". The phase offsets come from the port id, so a
	# given station always blinks its own way and two of the same archetype in
	# the same system do not beat in lockstep -- which would look more artificial
	# than not blinking at all.
	var seed_rng := RandomNumberGenerator.new()
	seed_rng.seed = hash(port_id + port_name)
	for i in range(STROBE_COUNT):
		var mi := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.09
		sm.height = 0.18
		sm.radial_segments = 6
		sm.rings = 3
		mi.mesh = sm
		var mat := Palette.emissive(Palette.AMBER, 1.0)
		mi.material_override = mat
		var ang := seed_rng.randf_range(0.0, TAU)
		var r := seed_rng.randf_range(1.6, 2.8)
		mi.position = Vector3(cos(ang) * r, seed_rng.randf_range(-0.5, 1.4), sin(ang) * r)
		add_child(mi)
		_strobes.append(mat)
		_strobe_phase.append(seed_rng.randf_range(0.0, TAU))
		_strobe_rate.append(seed_rng.randf_range(0.55, 0.95))


func _build_bulwark() -> void:
	# THE BREAKWATER, band 5. A wall, and everything else is behind it.
	#
	# Its own silhouette rather than `military`, because BLACKWATCH YARD already
	# wears that one and both are eligible from band 5 out. A port's name only
	# appears at DOCK_RANGE 5.0, so two identical shapes at the same depth means
	# committing to a four-hundred-unit approach to find out which counter you
	# flew to. The landmarks make the same argument for the same reason: a second
	# tell that is also the first tell says nothing new.
	var slab := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(6.4, 3.0, 0.9)
	slab.mesh = bm
	slab.material_override = Palette.matte(Color(0.17, 0.18, 0.19))
	add_child(slab)

	# Buttresses on the deep-facing side only. The wall has a FRONT, which is
	# what makes it read as a breakwater rather than as a block.
	for i in range(4):
		var rib := MeshInstance3D.new()
		var rm := BoxMesh.new()
		rm.size = Vector3(0.55, 2.2, 2.6)
		rib.mesh = rm
		rib.material_override = Palette.matte(Color(0.13, 0.14, 0.15))
		rib.position = Vector3(-2.4 + float(i) * 1.6, -0.2, -1.5)
		rib.rotation_degrees.x = -12.0
		add_child(rib)

	# Gun galleries: three hard points along the top, lit like something on
	# watch rather than something for sale.
	for i in range(3):
		var mount := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.26
		cm.bottom_radius = 0.42
		cm.height = 1.1
		mount.mesh = cm
		mount.material_override = Palette.emissive(Palette.THREAT, 1.5)
		mount.position = Vector3(-2.1 + float(i) * 2.1, 1.9, -0.2)
		add_child(mount)


func _build_lantern() -> void:
	# THE FAR LANTERN, band 6. One light on a mast, and nothing behind it.
	#
	# Deliberately the SMALLEST silhouette of any port in the game and the
	# brightest single element — the opposite of the Cantina's ring of signs. A
	# place that is keeping a light on, not advertising one.
	var mast := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.22
	mm.bottom_radius = 0.34
	mm.height = 5.2
	mast.mesh = mm
	mast.material_override = Palette.matte(Color(0.15, 0.16, 0.18))
	add_child(mast)

	# The lamp, and it is enormous for the mast carrying it.
	var lamp := MeshInstance3D.new()
	var lm := SphereMesh.new()
	lm.radius = 1.15
	lm.height = 2.3
	lamp.mesh = lm
	lamp.position.y = 3.2
	lamp.material_override = Palette.emissive(Palette.WHITE_HOT, 4.2)
	add_child(lamp)

	# A single hoop under it, unlit: the housing of something that used to be
	# bigger. The one detail that says this was not built to be the last thing.
	var housing := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.5
	tm.outer_radius = 1.72
	tm.ring_segments = 20
	housing.mesh = tm
	housing.position.y = 3.2
	housing.scale.y = 0.35
	housing.material_override = Palette.matte(Color(0.19, 0.20, 0.22))
	add_child(housing)

	# Two habitation cans clamped low on the mast. Somebody lives here.
	for i in range(2):
		var can := MeshInstance3D.new()
		var cm2 := CapsuleMesh.new()
		cm2.radius = 0.36
		cm2.height = 1.5
		can.mesh = cm2
		can.rotation_degrees.z = 90.0
		can.position = Vector3(0.0, -0.4 + float(i) * 0.9, 0.62 if i == 0 else -0.62)
		can.material_override = Palette.matte(Color(0.22, 0.21, 0.20))
		add_child(can)


func _build_dock_ring() -> void:
	# The affordance: a slowly turning amber ring marking where to clamp on.
	var holder := Node3D.new()
	holder.position = Vector3(0, 0, 4.2)
	add_child(holder)
	dock_point = holder.global_position

	_ring = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.0
	tm.outer_radius = 1.14
	tm.ring_segments = 28
	_ring.mesh = tm
	_ring_mat = Palette.emissive(Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.75), 2.2)
	_ring.material_override = _ring_mat
	_ring.rotation.x = PI / 2.0
	holder.add_child(_ring)

	var beacon := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.22
	bm.height = 0.44
	beacon.mesh = bm
	_beacon_mat = Palette.emissive(Palette.GOLD, 3.0)
	beacon.material_override = _beacon_mat
	beacon.position = Vector3(0, 0.7, 0)
	holder.add_child(beacon)


# --- interaction ------------------------------------------------------------

func _process(delta: float) -> void:
	dock_point = _ring.get_parent().global_position
	_spin += delta
	_ring.rotation.z = _spin * 0.6
	var pulse := 2.4 + sin(_spin * 2.6) * 0.8
	_beacon_mat.emission_energy_multiplier = pulse
	_ring_mat.emission_energy_multiplier = 1.6 + sin(_spin * 2.6) * 0.5

	# Each strobe on its own clock. Raised to a power so the shape is a blink --
	# mostly dark with a short bright peak -- rather than a sine that spends half
	# its time half-lit, which reads as breathing instead of as a signal light.
	for i in range(_strobes.size()):
		var w: float = 0.5 + 0.5 * sin(_spin * float(_strobe_rate[i]) * TAU + float(_strobe_phase[i]))
		(_strobes[i] as StandardMaterial3D).emission_energy_multiplier = 0.25 + pow(w, 6.0) * 5.0

	if docked:
		return
	var in_range := player_in_range()
	if in_range != _in_range_last:
		_in_range_last = in_range
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			if in_range:
				Barks.fire("first_dock_range")
				hud.prompt("TAP %s TO DOCK" % port_name)
			else:
				hud.clear_prompt()


func player_in_range() -> bool:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	return player.global_position.distance_to(dock_point) <= DOCK_RANGE


func on_tapped() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if docked:
		# Tapping the port you are ALREADY clamped to brings the sheet back.
		# Without this the escape ladder is one-way: CameraRig._cancel closes the
		# panel without undocking, request_dock refuses while docked_port is set,
		# and the player is left clamped to a station with no way to reach its
		# counters short of departing and flying back in.
		if main and main.port_panel and not main.port_panel.is_open:
			main.port_panel.open_for(self)
		return
	if main and main.has_method("request_dock"):
		main.request_dock(self)


func approach() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var toward: Vector3 = player.global_position - dock_point
	toward.y = 0.0
	if toward.length() < 0.1:
		toward = Vector3.BACK
	var stand: Vector3 = dock_point + toward.normalized() * APPROACH_STOP
	stand.y = 0.0
	player.command_move(stand)


func set_docked_visual(on: bool) -> void:
	docked = on
	_ring_mat.albedo_color = Color(Palette.TEAL.r, Palette.TEAL.g, Palette.TEAL.b, 0.85) if on \
		else Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.75)
