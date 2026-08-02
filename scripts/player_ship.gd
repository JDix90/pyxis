class_name PlayerShip
extends Node3D
# Survey vessel. Every stat comes from the equipped fit (GameState.stats), and
# the hull is rebuilt from that fit so a loadout is visible at a glance.
#
# --- FEEL CONSTANTS (tune these first) ---
const BANK_STRENGTH := 0.28
const STRAFE_BANK := 0.85
const HULL_RADIUS := 0.9
const ARRIVE_RADIUS := 3.0
const CHAIN_RADIUS := 4.5
const CHAIN_FALLOFF := 0.5
const CRIT_MULT := 2.0
const SHIELD_CALM_DELAY := 4.0
# Slow enough that a single hit stays readable, fast enough that the ghost is
# gone before the next exchange so two hits never read as one.
const SHIELD_GHOST_DRAIN := 3.2
const WARP_TIME := 1.6
const OFFLINE_TIME := 1.4
const WARP_GRACE := 2.5

# Overcharge discharge. The radius is what the expanding ring has always drawn —
# previously the ring was decoration over a pure fire-rate buff, so players read
# it as an area blast, flew into a pack, and nothing happened. Now the mechanic
# matches the picture.
const OVERCHARGE_RADIUS := 7.0
const OVERCHARGE_BURST_SECONDS := 1.6   # burst damage = fitted DPS × this
const OVERCHARGE_EDGE_FALLOFF := 0.45   # damage multiplier at the rim
const SPAWN_POINT := Vector3(0, 0, 6)

var velocity := Vector3.ZERO
var move_target := Vector3.ZERO
var has_move_target := false
var attack_target: Node3D = null

# --- return fire -------------------------------------------------------------
# `attack_target` is the player's EXPLICIT choice, and it drives three things at
# once: the guns, the autopilot's destination, and the hull's facing. That triple
# duty is why auto-targeting cannot simply assign to it — doing so would fly the
# ship at whatever shot it, which is the opposite of what a player backing out of
# a swarm wants, and would fight them for control of their own stick.
#
# So the guns get their own target. `auto_target` is acquired only while
# something is actually shooting at you, is used ONLY by the weapons, and never
# moves or turns the ship. The player runs; the mounts answer.
var auto_target: Node3D = null
# Only look for something to shoot back at within this long of being hit. Outside
# that window the guns stand down — a ship that keeps firing at whatever wanders
# past is a ship that picks fights the player did not.
const RETURN_FIRE_WINDOW := 4.0
# Tab cannot reach past the largest authored system bounds.
const CYCLE_RANGE := 48.0
var _threat: Node3D = null      # whoever hit us last, preferred over proximity
# Time since anything SHOT AT us, which is deliberately not `_time_since_hit`.
# That one gates shield regen and is only reset by damage that actually lands, so
# a shot absorbed by Aegis leaves it untouched — correct for regen, wrong here.
# Being shot at while protected is still being shot at, and the mounts should
# answer.
var _since_threat := 99.0
# Off during the guided first run. Step 1 asks the player to CLICK a contact to
# engage, and the training drone shoots back — so return fire would kill the
# lesson's target before the lesson could be taught.
var return_fire_enabled := true

# Seconds of EMP lockout remaining. Drives and mounts are dead; the hull is not.
var _emp := 0.0
# What a Thermal Sink in the hold does to an incoming pulse. Half, not immunity:
# a rigged hulk should still cost you the beat it bought, just not the whole
# fight — and an item that switches a hazard off entirely stops being a trade.
const SINK_EMP_FACTOR := 0.5
# The FITTED lattice, weaker than the carried sink: 0.70 against 0.50 halves
# less of the pulse, and costs a slot, four power and 0.9 speed to do it.
const FITTED_SINK := 0.70

var shield := 100.0
var shield_max := 100.0
var invulnerable := false

var _stats := {}
var _weapons: Array = []
var _prev_yaw := 0.0
var _recoil := Vector3.ZERO
var _time_since_hit := 99.0
var _warping := false
var _grace := 0.0
# Sub-unit travel carried between frames, so the ledger counts whole units and
# never loses the remainder to int truncation.
var _flown := 0.0

# --- external drag ------------------------------------------------------------
# THE MERIDIAN's graviton tether pulls through this channel rather than through
# `velocity`, and the distinction is the entire mechanic.
#
# The obvious implementation — `player.velocity += inward * pull * delta` — is
# what the tether was, and it dragged an idle ship exactly 0.0u for as long as
# it existed. The autopilot below brakes `velocity` toward `desired` at `accel`
# every frame, and for a ship with no move target `desired` is ZERO: the brake
# runs at 9.0 on the bare hull and never below the 3.0 ModuleDB floors it to,
# both of which beat a 6.5 pull. So the pull was cancelled to nothing before the
# position step ran, and cancelled HARDEST against exactly the ship the armament
# exists to catch — the one sitting still.
#
# This rides alongside `_recoil` instead: summed into the position step, never
# braked, decayed only once the tether lets go. The player's own thrust still
# fights it, because the two velocities add — a ship burning outward keeps the
# difference. What it no longer does is win by standing still.
var _tether_vel := Vector3.ZERO
var _tether_driven := false
# How fast the drag bleeds off once the tether releases. Short enough that the
# snap reads as a release rather than a long coast.
const TETHER_RELEASE_DECAY := 4.0
# The hard ceiling on tether drag, in u/s. ModuleDB floors max_speed at 1.6, so
# a drag at or above that pins the weakest legal fit in place with no way out —
# and "out-runnable by any legal fit" is the one promise this mechanic has to
# keep. Callers pass their own cap; this is the line none of them may cross.
const TETHER_DRAG_CEILING := 1.5

# Docked: clamped to a port. The only fully safe state in the game — nothing
# can hurt the ship and nothing hunts it.
var docked := false
# True while a movement key is held, so the camera knows to keep up.
var driving := false
# False in attract mode: the ship is scenery behind the title, not a toy.
var input_enabled := true

var _cycle_index := -1

# Current livery hull colour, resolved once per rebuild. Mounts and struts tint
# off this rather than the Palette token, so painting the ship paints all of it
# instead of leaving grey weapon hardware bolted to a black hull.
var _hull_color := Palette.HULL


func set_input_enabled(v: bool) -> void:
	input_enabled = v
	if not v:
		attack_target = null
		has_move_target = false
		velocity = Vector3.ZERO
		clear_tether()
		driving = false

var _ability := {}
var _ability_time := 0.0
var _ability_cd := 0.0

var _parts: Node3D
var _engine_mat: StandardMaterial3D
var _dock_tween: Tween = null
var _thruster: CPUParticles3D
var _shield_bar: MeshInstance3D
var _shield_ghost: MeshInstance3D
var _shield_bar_root: Node3D
# Trails the real fraction downward only, at SHIELD_GHOST_DRAIN per second.
var _shield_ghost_frac := 1.0
var _aegis_bubble: MeshInstance3D


func _ready() -> void:
	add_to_group("player")
	# The ship integrates on the fixed tick, so it is one of the few nodes in the
	# game that benefits from physics interpolation -- and the only one the eye
	# tracks continuously. Most of Pyxis moves in _process (ports, sentries, the
	# boss, every FX tween), where interpolation would quantize smooth motion to
	# 60Hz and add a frame of lag, so the project setting is opted into here
	# rather than inherited. See project.godot's [physics] comment.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	_parts = Node3D.new()
	add_child(_parts)
	GameState.fit_changed.connect(_on_fit_changed)
	_apply_fit(GameState.stats)
	shield = shield_max


func teleport_to(pos: Vector3, face := Vector3.ZERO) -> void:
	# Every jump goes through here. An interpolated node that is repositioned
	# without resetting draws one frame smeared across the line between where it
	# was and where it now is -- from deep space to the spawn point, that streak
	# crosses the entire map. Warps already flash white over the swap, which is
	# exactly the kind of cover that would have hidden this bug for months.
	global_position = pos
	rotation = face
	reset_physics_interpolation()


func _on_fit_changed(stats: Dictionary) -> void:
	_apply_fit(stats)


func _apply_fit(stats: Dictionary) -> void:
	_stats = stats
	shield_max = float(stats.get("shield_max", 100.0))
	shield = minf(shield, shield_max) if shield > 0.0 else shield_max

	_weapons = []
	for w in stats.get("weapons", []):
		var entry: Dictionary = (w as Dictionary).duplicate()
		entry["cooldown"] = randf() * 0.2
		_weapons.append(entry)

	# Refitting must not launder ability state. Zeroing these blindly used to
	# (a) hand out a free cooldown reset on every module swap and (b) strand
	# `invulnerable` at true when Aegis was active, because the clear only ran
	# inside _tick_ability's countdown branch — three taps to permanent god mode.
	# An active ability now only ends when the Core itself changes.
	var new_ability: Dictionary = stats.get("ability", {})
	var core_changed := String(new_ability.get("id", "")) != String(_ability.get("id", ""))
	_ability = new_ability
	if core_changed:
		_end_ability()
	_rebuild_mesh()


func _end_ability() -> void:
	# Single exit point for an ability, so protection can never outlive it.
	_ability_time = 0.0
	_ability_cd = 0.0
	invulnerable = false


func reach() -> float:
	var r := 0.0
	for w in _weapons:
		r = maxf(r, float(w["range"]) + float(_stats.get("weapon_range_bonus", 0.0)))
	return r if r > 0.0 else 5.0


# --- hull construction ------------------------------------------------------

func _rebuild_mesh() -> void:
	for child in _parts.get_children():
		child.queue_free()

	var fit: Dictionary = GameState.fit

	# Livery (save v6). The paint is the player's, so it wins over the Core's
	# default trim — but only over the TRIM. The Core still owns the ability
	# glow, the engine bloom and the Aegis bubble, because those are readouts:
	# a player must never be able to paint away the tell that says which core
	# they are flying.
	_hull_color = Palette.livery_hull(GameState.livery_index("hull"))
	var accent := Palette.livery_accent(GameState.livery_index("accent"))

	var hull := MeshInstance3D.new()
	var hull_mesh := PrismMesh.new()
	hull_mesh.size = Vector3(0.9, 0.28, 1.7)
	hull.mesh = hull_mesh
	hull.rotation_degrees = Vector3(-90, 0, 0)
	hull.material_override = Palette.matte(_hull_color)
	_parts.add_child(hull)

	# Core accent stripe down the spine.
	var stripe := MeshInstance3D.new()
	var stripe_mesh := BoxMesh.new()
	stripe_mesh.size = Vector3(0.1, 0.04, 1.2)
	stripe.mesh = stripe_mesh
	stripe.position = Vector3(0, 0.15, 0.1)
	stripe.material_override = Palette.emissive(accent, 2.0)
	_parts.add_child(stripe)

	_build_mounts(fit)
	_build_drive(fit)
	_build_utility(fit)
	_build_shield_bar()

	_aegis_bubble = MeshInstance3D.new()
	var bubble := SphereMesh.new()
	bubble.radius = 1.5
	bubble.height = 3.0
	_aegis_bubble.mesh = bubble
	_aegis_bubble.material_override = Palette.emissive(Color(0.15, 0.9, 0.85, 0.22), 1.6)
	_aegis_bubble.visible = false
	_parts.add_child(_aegis_bubble)


func _build_mounts(fit: Dictionary) -> void:
	var slots := [ModuleDB.Slot.WEAPON_A, ModuleDB.Slot.WEAPON_B]
	for i in range(slots.size()):
		var id: String = fit.get(slots[i], "")
		if not ModuleDB.exists(id):
			continue
		var side := -1.0 if i == 0 else 1.0
		var family: String = ModuleDB.get_module(id).get("family", "pulse")
		match family:
			"lance":
				_mount_lance(side)
			"arc":
				_mount_arc(side)
			"torp":
				_mount_torp(side)
			_:
				_mount_pulse(side)


func _mount_pulse(side: float) -> void:
	var prong := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.12, 0.1, 1.1)
	prong.mesh = pm
	prong.position = Vector3(side * 0.5, 0.0, -0.55)
	prong.material_override = Palette.matte(_hull_color.darkened(0.2))
	_parts.add_child(prong)

	var tip := MeshInstance3D.new()
	var tm := BoxMesh.new()
	tm.size = Vector3(0.1, 0.12, 0.14)
	tip.mesh = tm
	tip.position = Vector3(side * 0.5, 0.0, -1.1)
	tip.material_override = Palette.emissive(Palette.AMBER, 2.5)
	_parts.add_child(tip)


func _mount_lance(side: float) -> void:
	# Long single rail — unmistakably a sniper mount.
	var rail := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(0.14, 0.14, 2.1)
	rail.mesh = rm
	rail.position = Vector3(side * 0.46, 0.0, -0.95)
	rail.material_override = Palette.matte(_hull_color.darkened(0.35))
	_parts.add_child(rail)

	for z in [-0.35, 0.15]:
		var collar := MeshInstance3D.new()
		var cm := BoxMesh.new()
		cm.size = Vector3(0.24, 0.2, 0.12)
		collar.mesh = cm
		collar.position = Vector3(side * 0.46, 0.0, z)
		collar.material_override = Palette.emissive(Palette.AMBER, 1.6)
		_parts.add_child(collar)

	var muzzle := MeshInstance3D.new()
	var mm := BoxMesh.new()
	mm.size = Vector3(0.09, 0.09, 0.2)
	muzzle.mesh = mm
	muzzle.position = Vector3(side * 0.46, 0.0, -1.95)
	muzzle.material_override = Palette.emissive(Palette.WHITE_HOT, 3.0)
	_parts.add_child(muzzle)


func _mount_torp(side: float) -> void:
	# Boxy cell launcher with visible shells in the tubes. Short and fat where
	# Lance is long and thin, so the two heavy mounts never read as each other.
	var pod := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.3, 0.26, 0.66)
	pod.mesh = pm
	pod.position = Vector3(side * 0.52, 0.0, -0.5)
	pod.material_override = Palette.matte(_hull_color.darkened(0.42))
	_parts.add_child(pod)

	for x in [-0.07, 0.07]:
		var tube := MeshInstance3D.new()
		var tm := CylinderMesh.new()
		tm.top_radius = 0.055
		tm.bottom_radius = 0.055
		tm.height = 0.34
		tube.mesh = tm
		tube.rotation_degrees.x = 90.0
		tube.position = Vector3(side * 0.52 + x, 0.05, -0.86)
		tube.material_override = Palette.emissive(Palette.AMBER, 2.2)
		_parts.add_child(tube)

	var brace := MeshInstance3D.new()
	var brm := BoxMesh.new()
	brm.size = Vector3(0.36, 0.06, 0.1)
	brace.mesh = brm
	brace.position = Vector3(side * 0.52, 0.16, -0.5)
	brace.material_override = Palette.matte(_hull_color.darkened(0.25))
	_parts.add_child(brace)


func _mount_arc(side: float) -> void:
	# Forked emitter — reads as "this thing sprays".
	var base := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 0.12, 0.7)
	base.mesh = bm
	base.position = Vector3(side * 0.5, 0.0, -0.4)
	base.material_override = Palette.matte(_hull_color.darkened(0.25))
	_parts.add_child(base)

	for fork in [-1.0, 1.0]:
		var tine := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(0.07, 0.07, 0.5)
		tine.mesh = tm
		tine.position = Vector3(side * 0.5 + fork * 0.11, 0.0, -0.95)
		tine.rotation.y = fork * 0.16
		tine.material_override = Palette.emissive(Palette.TEAL, 2.6)
		_parts.add_child(tine)


func _build_drive(fit: Dictionary) -> void:
	var id: String = fit.get(ModuleDB.Slot.DRIVE, "")
	var is_vector := id == "drive_vector"
	var color := Palette.THREAT if is_vector else Palette.TEAL
	_engine_mat = Palette.emissive(color, 3.0)

	if is_vector:
		for side in [-1.0, 1.0]:
			var pod := MeshInstance3D.new()
			var em := BoxMesh.new()
			em.size = Vector3(0.2, 0.14, 0.3)
			pod.mesh = em
			pod.position = Vector3(side * 0.3, 0, 0.9)
			pod.material_override = _engine_mat
			_parts.add_child(pod)
	else:
		var engine := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3(0.5, 0.12, 0.18)
		engine.mesh = em
		engine.position = Vector3(0, 0, 0.9)
		engine.material_override = _engine_mat
		_parts.add_child(engine)

	_thruster = CPUParticles3D.new()
	_thruster.amount = 40
	_thruster.lifetime = 0.45
	_thruster.local_coords = false
	_thruster.direction = Vector3(0, 0, 1)
	_thruster.spread = 8.0
	_thruster.initial_velocity_min = 1.5
	_thruster.initial_velocity_max = 3.5
	_thruster.gravity = Vector3.ZERO
	_thruster.damping_min = 3.0
	_thruster.damping_max = 6.0
	_thruster.scale_amount_min = 0.04
	_thruster.scale_amount_max = 0.13
	_thruster.color = color
	var tmesh := BoxMesh.new()
	tmesh.size = Vector3.ONE * 0.12
	tmesh.material = Palette.emissive(color, 2.5)
	_thruster.mesh = tmesh
	_thruster.position = Vector3(0, 0, 1.0)
	_thruster.emitting = false
	_parts.add_child(_thruster)


func _build_utility(fit: Dictionary) -> void:
	match String(fit.get(ModuleDB.Slot.UTILITY, "")):
		"util_tractor":
			var ring := MeshInstance3D.new()
			var torus := TorusMesh.new()
			torus.inner_radius = 0.62
			torus.outer_radius = 0.72
			torus.ring_segments = 24
			ring.mesh = torus
			ring.position = Vector3(0, -0.12, 0.1)
			ring.material_override = Palette.emissive(Palette.GOLD, 2.2)
			_parts.add_child(ring)
		"util_shield":
			for side in [-1.0, 1.0]:
				var plate := MeshInstance3D.new()
				var pm := BoxMesh.new()
				pm.size = Vector3(0.1, 0.34, 0.8)
				plate.mesh = pm
				plate.position = Vector3(side * 0.42, 0.06, 0.25)
				plate.rotation.z = side * 0.3
				plate.material_override = Palette.emissive(Color(0.15, 0.9, 0.85, 0.55), 1.4)
				_parts.add_child(plate)
		"util_scanner":
			var mast := MeshInstance3D.new()
			var mm := BoxMesh.new()
			mm.size = Vector3(0.06, 0.3, 0.06)
			mast.mesh = mm
			mast.position = Vector3(0, 0.3, 0.4)
			mast.material_override = Palette.matte(_hull_color.darkened(0.3))
			_parts.add_child(mast)
			var dish := MeshInstance3D.new()
			var dm := SphereMesh.new()
			dm.radius = 0.16
			dm.height = 0.16
			dish.mesh = dm
			dish.position = Vector3(0, 0.46, 0.4)
			dish.material_override = Palette.emissive(Palette.AMBER, 2.0)
			_parts.add_child(dish)


func _build_shield_bar() -> void:
	_shield_bar_root = Node3D.new()
	_shield_bar_root.position = Vector3(0, -0.55, 0)
	_shield_bar_root.visible = false
	_parts.add_child(_shield_bar_root)

	var bg := MeshInstance3D.new()
	var bgm := BoxMesh.new()
	bgm.size = Vector3(1.1, 0.08, 0.02)
	bg.mesh = bgm
	bg.material_override = Palette.emissive(Color(0.05, 0.2, 0.2, 0.8), 1.0)
	_shield_bar_root.add_child(bg)

	# The ghost sits between the background and the fill and chases it down, so a
	# hit leaves a pale bar that drains over the next half second. It reads as
	# "that is what that cost you" -- the size of the hit stays legible after the
	# frame it landed on, which a bar that simply jumps to its new length cannot
	# do. Added before the fill so the fill draws over it.
	_shield_ghost = MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(1.1, 0.08, 0.02)
	_shield_ghost.mesh = gm
	_shield_ghost.position.z = -0.005
	_shield_ghost.material_override = Palette.emissive(Palette.WHITE_HOT, 1.6)
	_shield_bar_root.add_child(_shield_ghost)

	_shield_bar = MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.1, 0.08, 0.02)
	_shield_bar.mesh = fm
	_shield_bar.position.z = -0.01
	_shield_bar.material_override = Palette.emissive(Palette.TEAL, 2.2)
	_shield_bar_root.add_child(_shield_bar)


# --- commands ---------------------------------------------------------------

func _read_move_input() -> Vector3:
	# Screen-relative, derived from the camera basis rather than world axes, so
	# this keeps working if the rig ever yaws. W is always "up the screen".
	if docked or _warping or not input_enabled:
		return Vector3.ZERO
	var axis := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if axis.length_squared() < 0.0001:
		return Vector3.ZERO

	var cam := get_viewport().get_camera_3d()
	var right := Vector3.RIGHT
	var forward := Vector3.FORWARD
	if cam:
		right = cam.global_transform.basis.x
		forward = -cam.global_transform.basis.z
		right.y = 0.0
		forward.y = 0.0
		if right.length_squared() < 0.001:
			right = Vector3.RIGHT
		if forward.length_squared() < 0.001:
			forward = Vector3.FORWARD
		right = right.normalized()
		forward = forward.normalized()
	return (right * axis.x + forward * -axis.y).limit_length(1.0)


func cycle_target() -> Node3D:
	# Distance-ordered so Tab walks outward from whatever is closest, and wraps.
	# BOUNDED. An unbounded nearest-first sort over every hostile in the system
	# was fine when a system was 48 units across; the expanse turned it into a way
	# to Tab onto a guard post 200u away and have the autopilot fly you into it.
	# 48 is the largest authored `bounds` — anything past that is not a contact
	# you are in a fight with.
	var hostiles: Array[Node3D] = []
	for n in get_tree().get_nodes_in_group("hostiles"):
		var h := n as Node3D
		# Cycling is for picking the next THREAT, not the next object. A
		# neutral convoy in the ring used to be a stop on the tour.
		if is_instance_valid(h) and GameState.hostile_to_player(h) \
				and global_position.distance_to(h.global_position) <= CYCLE_RANGE:
			hostiles.append(h)
	if hostiles.is_empty():
		attack_target = null
		_cycle_index = -1
		return null
	hostiles.sort_custom(func(a: Node3D, b: Node3D) -> bool:
		return global_position.distance_to(a.global_position) \
			< global_position.distance_to(b.global_position))

	var current := hostiles.find(attack_target) if is_instance_valid(attack_target) else -1
	_cycle_index = (current + 1) % hostiles.size()
	command_attack(hostiles[_cycle_index])
	return hostiles[_cycle_index]


func clear_target() -> void:
	attack_target = null
	_cycle_index = -1
	auto_target = null
	_threat = null


func emp_stun(duration: float) -> void:
	# A Thermal Sink in the hold drinks half the pulse. Applied to the INCOMING
	# duration, before the max below, so it works the same whether this is the
	# first pulse or one landing on top of another.
	#
	# Read off the hold at the moment of use, never through compute_stats — a good
	# that moved a fitted number would make the hold guard subtract two different
	# piles from each other (19).
	# The carried sink and the fitted lattice do NOT stack — the better of the two
	# applies. Two dampers multiplying would put a Quiet-band 2.8s pulse under a
	# second, which is not "a bet that cost you the beat it bought", it is the
	# hazard switched off.
	var damped := GameState.hold_has("sink_thermal")
	var latticed := GameState.fit_has("mod_sink_lattice")
	if damped or latticed:
		duration *= SINK_EMP_FACTOR if damped else FITTED_SINK
	# Longest wins rather than accumulating, so two overlapping pulses cannot
	# stack into a lockout nobody could survive.
	_emp = maxf(_emp, duration)
	attack_target = null
	auto_target = null
	has_move_target = false
	Sfx.play("hit", -4.0, 0.45)
	if damped:
		# The mitigation has to be VISIBLE, or the player cannot learn that the
		# thing they are hauling just paid for itself.
		FX.ring_pulse(get_parent(), global_position, Palette.TEAL, 3.2, 0.5)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			hud.show_toast("THERMAL SINK ABSORBED THE BLAST — LESS DAMAGE TAKEN",
				Palette.TEAL)
	FX.shockwave(get_parent(), global_position, Palette.TEAL, 7.0, 0.7)
	FX.burst(get_parent(), global_position, Color(0.55, 0.85, 1.0), 30, 5.0, 0.14, 0.5)
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.shake(0.26)


func is_emp_stunned() -> bool:
	return _emp > 0.0


func clear_emp() -> void:
	# Harness support: emp_stun takes the LONGEST of the pulses it is given, so
	# measuring two in a row needs the first one cleared between them.
	_emp = 0.0


func emp_remaining() -> float:
	return _emp


func gun_target() -> Node3D:
	# What the WEAPONS are pointed at. Explicit orders always win: the moment the
	# player names a target, return fire stops choosing for them.
	if is_instance_valid(attack_target):
		return attack_target
	return auto_target if is_instance_valid(auto_target) else null


func _tick_return_fire() -> void:
	if is_instance_valid(attack_target) or _warping or docked or not input_enabled \
			or not return_fire_enabled:
		auto_target = null
		return
	# Stand down once nothing has hit us for a while. Tying acquisition to being
	# under fire (rather than to anything being in range) is what keeps this from
	# starting fights — and is why it cannot misfire during the tutorial, where
	# nothing shoots at you until the step that says so.
	if _since_threat > RETURN_FIRE_WINDOW:
		auto_target = null
		return
	if is_instance_valid(auto_target) and _in_gun_range(auto_target):
		return

	# Whoever hit us, if they are still there and still in range. Shooting back at
	# your actual attacker beats shooting the nearest thing, which in a pack is
	# usually not the same enemy.
	if _auto_targetable(_threat) and _in_gun_range(_threat):
		auto_target = _threat
		return
	auto_target = _nearest_hostile_in_range()


func _auto_targetable(node) -> bool:
	# UNTYPED on purpose. A typed Node3D parameter is checked BEFORE the call, so
	# passing an already-freed hostile — routine, since packs die mid-frame —
	# raises before is_instance_valid below ever runs.
	#
	# THE APEX HUB IS EXEMPT, and the reason is the encounter's own design.
	#
	# The engine's loop is: clear its probes fast and the iris opens wide, ignore
	# them and it opens a crack. Add-clear speed BUYS structure-damage time — so
	# return fire helping with probes is exactly in keeping with the fight.
	#
	# Free damage on the core is not. When the iris opens you are already parked
	# on the hub with it explicitly targeted; there is nothing to chase and
	# nothing to fix. What the extra uptime did instead was push peak
	# single-window damage into the 1500 hp a phase is worth, which would let a
	# strong fit delete a phase before ever meeting a seal, a probe or the sweep
	# arm — skipping the whole mechanic rather than beating it. `PHASE INTEGRITY`
	# in PYXIS_BALANCE is what caught it.
	if not is_instance_valid(node):
		return false
	return not (node as Node).is_in_group("apex")


func _in_gun_range(node) -> bool:
	# Untyped for the same reason as _auto_targetable.
	if not is_instance_valid(node):
		return false
	return global_position.distance_to((node as Node3D).global_position) <= _max_weapon_range()


func _max_weapon_range() -> float:
	var best := 0.0
	for w in _weapons:
		best = maxf(best, float(w["range"]))
	return best + float(_stats.get("weapon_range_bonus", 0.0))


func _nearest_hostile_in_range() -> Node3D:
	var best: Node3D = null
	var best_d := _max_weapon_range()
	for n in get_tree().get_nodes_in_group("hostiles"):
		var h := n as Node3D
		# AND IT MUST ACTUALLY BE AN ENEMY. Return fire used to swing onto the
		# nearest thing in the group whatever its flag, so a player fighting a
		# Tally pack beside a neutral convoy would start shooting the convoy --
		# and then be blamed for it by the standing rule. Anything that has
		# fired on the player answers true here, so a fight in progress is
		# unaffected.
		if not _auto_targetable(h) or not GameState.hostile_to_player(h):
			continue
		var d := global_position.distance_to(h.global_position)
		if d <= best_d:
			best_d = d
			best = h
	return best


func command_move(pos: Vector3) -> void:
	if _warping or docked or not input_enabled or _emp > 0.0:
		return
	move_target = pos
	has_move_target = true
	attack_target = null


func command_attack(target: Node3D) -> void:
	if _warping or docked or not input_enabled or _emp > 0.0:
		return
	attack_target = target
	has_move_target = false


func ability_info() -> Dictionary:
	return _ability


func ability_ready() -> bool:
	return not _ability.is_empty() and _ability_cd <= 0.0 and not _warping and not docked


func ability_cooldown_fraction() -> float:
	if _ability.is_empty():
		return 0.0
	var total := float(_ability.get("cooldown", 1.0))
	return clampf(_ability_cd / total, 0.0, 1.0)


func ability_active() -> bool:
	return _ability_time > 0.0


func activate_ability() -> bool:
	if not ability_ready():
		return false
	_ability_time = float(_ability.get("duration", 2.0))
	_ability_cd = float(_ability.get("cooldown", 10.0))
	var main := get_tree().get_first_node_in_group("main")
	if main and main.tutorial:
		main.tutorial.on_ability_used()
	match String(_ability.get("id", "")):
		"overcharge":
			_overcharge_discharge()
		"surge":
			FX.ring_pulse(get_parent(), global_position, Palette.TEAL, 2.0)
			Sfx.play("warp", -6.0, 1.2)
		"aegis":
			invulnerable = true
			FX.ring_pulse(get_parent(), global_position, Palette.TEAL, 2.4)
			Sfx.play("warp", -8.0, 0.8)
	return true


# --- simulation -------------------------------------------------------------

func apply_tether(inward: Vector3, pull: float, cap: float, delta: float) -> void:
	# `cap` is the terminal drag speed, and it carries the whole escape guarantee:
	# it must stay under the 1.6 u/s that ModuleDB clamps max_speed to, so even
	# the weakest legal fit still makes outward headway against a live tether.
	# Enforced here as well as in the caller's data, because this is the only
	# place that can promise it.
	_tether_vel = (_tether_vel + inward * pull * delta).limit_length(
		minf(cap, TETHER_DRAG_CEILING))
	_tether_driven = true


func _tick_tether(delta: float) -> Vector3:
	# Held while the boss is driving it, bled off from the frame after it stops.
	# Called exactly once per physics frame on every path that moves the ship —
	# a path that skipped it would let the drag accumulate unspent and then dump
	# the whole of it the moment the ship started integrating again.
	if _tether_driven:
		_tether_driven = false
	else:
		_tether_vel = _tether_vel.move_toward(Vector3.ZERO, TETHER_RELEASE_DECAY * delta)
	return _tether_vel


func clear_tether() -> void:
	_tether_vel = Vector3.ZERO
	_tether_driven = false


func _physics_process(delta: float) -> void:
	_tick_ability(delta)
	_tick_shield(delta)

	if _warping or docked:
		driving = false  # never leave this stale: the camera reads it to follow
		clear_tether()   # a tether cannot follow you into a warp or a dock clamp
		return

	if _emp > 0.0:
		# Drives and mounts are down. NOT the shield regen above, and emphatically
		# not invulnerability — the whole weight of an EMP is that you are being
		# shot at and cannot answer. _emergency_warp still fires if the hull goes,
		# so this can cost you the run but it cannot trap you in one.
		_emp -= delta
		driving = false
		has_move_target = false
		velocity = velocity.move_toward(Vector3.ZERO, 24.0 * delta)
		# The tether keeps its grip on a stunned hull — an unpowered ship is
		# precisely what it catches, and letting the drag lapse here would make
		# an EMP the cheapest way out of it. Ticked on this path too so the pull
		# is spent as it arrives rather than banked and dumped on recovery.
		global_position += (velocity + _tick_tether(delta)) * delta
		rotation.y += delta * (1.4 + _emp)      # tumbling, unpowered
		if _engine_mat:
			_engine_mat.emission_energy_multiplier = 0.15
		if _thruster:
			_thruster.emitting = false
		if _emp <= 0.0:
			_emp = 0.0
			Sfx.play("equip", -8.0, 0.8)
			FX.ring_pulse(get_parent(), global_position, Palette.TEAL, 2.2, 0.5)
		return

	var max_speed := float(_stats.get("max_speed", 5.0))
	if ability_active() and String(_ability.get("id", "")) == "surge":
		max_speed *= 1.9
	var accel := float(_stats.get("accel", 9.0))
	var turn_rate := float(_stats.get("turn_rate", 7.0))

	var desired := Vector3.ZERO
	var goal := Vector3.ZERO
	var stop_dist := 0.4

	if attack_target != null and not is_instance_valid(attack_target):
		attack_target = null

	# Direct control takes precedence over the autopilot, but deliberately does
	# NOT drop the attack target: strafing while continuing to fire is the whole
	# point, and combat stays auto-resolved per the fitting design.
	var drive := _read_move_input()
	driving = drive.length_squared() > 0.0
	if driving:
		has_move_target = false
		desired = drive * max_speed
	else:
		if is_instance_valid(attack_target):
			goal = attack_target.global_position
			stop_dist = reach() * 0.7
		elif has_move_target:
			goal = move_target

		if has_move_target or is_instance_valid(attack_target):
			var to_goal := goal - global_position
			to_goal.y = 0.0
			var dist := to_goal.length()
			if dist <= stop_dist:
				has_move_target = false
			else:
				var speed := max_speed
				if dist < ARRIVE_RADIUS + stop_dist:
					speed = max_speed * clampf((dist - stop_dist) / ARRIVE_RADIUS, 0.15, 1.0)
				desired = to_goal.normalized() * speed

	# Autopilot steers around solids; direct WASD input is left alone so the
	# player is never fought for control of their own stick.
	if not driving:
		desired = Obstacles.steer(global_position, desired, HULL_RADIUS)

	velocity = velocity.move_toward(desired, accel * delta)
	_recoil = _recoil.move_toward(Vector3.ZERO, 12.0 * delta)
	# Note the order: the tether is summed in AFTER the brake above, never into
	# the value the brake operates on. That is what makes it survive an idle ship.
	var travelled := (velocity + _recoil + _tick_tether(delta)) * delta
	global_position += travelled
	# Logged here rather than from a position diff elsewhere: this is the one
	# place that knows the move was flown rather than teleported, so warps,
	# recalls and harness repositioning do not count as distance.
	if not _warping:
		_flown += travelled.length()
		if _flown >= 1.0:
			GameState.note_ledger("distance_flown", int(_flown))
			_flown = fmod(_flown, 1.0)
	var resolved := Obstacles.resolve(global_position, HULL_RADIUS)
	if not resolved.is_equal_approx(global_position):
		# Kill the component pushing into the surface, keep the slide.
		var normal := (global_position - resolved)
		normal.y = 0.0
		if normal.length() > 0.0001:
			normal = normal.normalized()
			velocity -= normal * minf(velocity.dot(normal), 0.0)
			# The drag gets the same treatment, or a tether that pins you against
			# a rock grinds into it for the rest of its window instead of sliding.
			_tether_vel -= normal * minf(_tether_vel.dot(normal), 0.0)
		global_position = resolved

	var throttle := clampf(velocity.length() / maxf(max_speed, 0.01), 0.0, 1.0)
	if _engine_mat:
		_engine_mat.emission_energy_multiplier = 1.2 + throttle * 3.2
	if _thruster:
		_thruster.emitting = throttle > 0.12

	# Facing: point at what you are shooting when engaged, otherwise point where
	# you are going. Strafing around a target while firing should read as
	# deliberate combat, not as flying backwards.
	var target_yaw := rotation.y
	var have_facing := false
	if is_instance_valid(attack_target):
		var to_target := attack_target.global_position - global_position
		to_target.y = 0.0
		if to_target.length() > 0.05:
			target_yaw = atan2(-to_target.x, -to_target.z)
			have_facing = true
	if not have_facing and velocity.length() > 0.3:
		target_yaw = atan2(-velocity.x, -velocity.z)
		have_facing = true

	if have_facing:
		var yaw := lerp_angle(rotation.y, target_yaw, turn_rate * delta)
		var yaw_rate := wrapf(yaw - _prev_yaw, -PI, PI) / maxf(delta, 0.001)
		_prev_yaw = yaw
		rotation.y = yaw

		# Bank from sideways drift in ship-local space, so circle-strafing rolls
		# into the turn even though yaw is locked onto the target.
		# STRAFE_BANK is deliberately strong: when yaw is locked on a target the
		# yaw-rate term nearly vanishes (and partly opposes), so without this a
		# hard circle-strafe rolled about two degrees and read as flat.
		var lateral := velocity.dot(global_transform.basis.x)
		var bank := -yaw_rate * BANK_STRENGTH + (lateral / maxf(max_speed, 0.01)) * STRAFE_BANK
		rotation.z = lerpf(rotation.z, clampf(bank, -0.7, 0.7), 8.0 * delta)
	else:
		rotation.z = lerpf(rotation.z, 0.0, 6.0 * delta)

	_fire(delta)


func _overcharge_discharge() -> void:
	# A real blast at the radius the ring draws. Damage scales off the fitted
	# DPS so this never becomes a dead button after a weapon upgrade, and falls
	# off toward the rim so wading into a pack is genuinely the right play.
	var parent := get_parent()
	var burst := float(_stats.get("dps", 100.0)) * OVERCHARGE_BURST_SECONDS

	FX.flash(parent, global_position, Palette.WHITE_HOT, 2.4, 0.22)
	FX.shockwave(parent, global_position, Palette.AMBER, OVERCHARGE_RADIUS, 0.55)
	FX.ring_pulse(parent, global_position, Palette.GOLD, OVERCHARGE_RADIUS, 0.5)
	FX.burst(parent, global_position, Color(1.0, 0.75, 0.3), 70, 13.0, 0.26, 0.65)
	Sfx.play("explode", -7.0, 1.3)
	Sfx.play("fire", -3.0, 0.55)

	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.shake(0.1)
		rig.punch_zoom(-0.6)

	for node in get_tree().get_nodes_in_group("hostiles"):
		var h := node as Node3D
		if not is_instance_valid(h) or not h.has_method("take_damage"):
			continue
		var offset: Vector3 = h.global_position - global_position
		offset.y = 0.0
		var dist := offset.length()
		if dist > OVERCHARGE_RADIUS:
			continue
		if Obstacles.blocked(global_position, h.global_position) != null:
			continue        # the discharge does not wrap around cover
		var t := clampf(dist / OVERCHARGE_RADIUS, 0.0, 1.0)
		# Arc to each victim so it is obvious what the blast actually caught.
		FX.beam(parent, global_position + Vector3(0, 0.2, 0), h.global_position,
			Palette.AMBER, 0.1, 0.2)
		h.take_damage(burst * lerpf(1.0, OVERCHARGE_EDGE_FALLOFF, t), self)


func _tick_ability(delta: float) -> void:
	if _ability_cd > 0.0:
		_ability_cd = maxf(_ability_cd - delta, 0.0)
	if _ability_time > 0.0:
		_ability_time = maxf(_ability_time - delta, 0.0)
		if _ability_time <= 0.0:
			invulnerable = false
	if _grace > 0.0:
		_grace = maxf(_grace - delta, 0.0)
	if _aegis_bubble:
		_aegis_bubble.visible = invulnerable or _grace > 0.0


func shield_fraction() -> float:
	return clampf(shield / maxf(shield_max, 1.0), 0.0, 1.0)


func shield_ghost_fraction() -> float:
	# Read-back for PYXIS_FEELTEST: the ghost is a world-space mesh scale, which
	# a headless run cannot observe any other way.
	return _shield_ghost_frac


func repair_full() -> void:
	# Instant, and only ever called from a docked repair bay. The slow recovery
	# in _tick_shield is the free option; this is the one you pay to skip.
	shield = shield_max
	_time_since_hit = SHIELD_CALM_DELAY


func is_protected() -> bool:
	return invulnerable or _grace > 0.0 or _warping or docked


func dock_to(point: Vector3) -> void:
	docked = true
	attack_target = null
	has_move_target = false
	velocity = Vector3.ZERO
	clear_tether()
	if _thruster:
		_thruster.emitting = false
	if _dock_tween != null and _dock_tween.is_valid():
		_dock_tween.kill()
	_dock_tween = create_tween()
	_dock_tween.set_parallel(true)
	_dock_tween.tween_property(self, "global_position", point, 0.6).set_ease(Tween.EASE_OUT)
	_dock_tween.tween_property(self, "rotation:z", 0.0, 0.6)


func undock() -> void:
	docked = false
	# The clamp-on animation writes global_position for 0.6s and does not care
	# whether it is still wanted. Undocking inside that window — or being moved by
	# anything else during it, which a recall out of the expanse now can be — left
	# the tween quietly dragging the ship back to a dock ring it had already left.
	if _dock_tween != null and _dock_tween.is_valid():
		_dock_tween.kill()
	_dock_tween = null
	shield = shield_max
	_grace = WARP_GRACE


func _tick_shield(delta: float) -> void:
	_time_since_hit += delta
	_since_threat += delta
	if _time_since_hit > SHIELD_CALM_DELAY and shield < shield_max and not _warping:
		shield = minf(shield + float(_stats.get("shield_regen", 6.0)) * delta, shield_max)

	if _shield_bar_root:
		var frac := clampf(shield / maxf(shield_max, 1.0), 0.0, 1.0)
		_shield_bar_root.visible = frac < 0.999 and not _warping
		# The fill itself is never smoothed. Damage has to be on screen the frame
		# it happens or the bar is lying about the thing it exists to report.
		_shield_bar.scale.x = maxf(frac, 0.001)
		_shield_bar.position.x = -1.1 * (1.0 - frac) * 0.5
		# The ghost only ever trails downward; regen is the fill's job to show, and
		# a ghost that also chased upward would just be a second, laggier bar.
		if frac >= _shield_ghost_frac:
			_shield_ghost_frac = frac
		else:
			_shield_ghost_frac = Smoothing.toward(_shield_ghost_frac, frac, SHIELD_GHOST_DRAIN, delta)
		_shield_ghost.visible = _shield_ghost_frac - frac > 0.004
		_shield_ghost.scale.x = maxf(_shield_ghost_frac, 0.001)
		_shield_ghost.position.x = -1.1 * (1.0 - _shield_ghost_frac) * 0.5
		var cam := get_viewport().get_camera_3d()
		if cam:
			_shield_bar_root.global_transform.basis = cam.global_transform.basis


func _fire(delta: float) -> void:
	var rate_mult := 1.0
	if ability_active() and String(_ability.get("id", "")) == "overcharge":
		rate_mult = 0.35

	_tick_return_fire()
	var tgt := gun_target()

	for w in _weapons:
		w["cooldown"] = float(w["cooldown"]) - delta
		if not is_instance_valid(tgt):
			continue
		var range_total := float(w["range"]) + float(_stats.get("weapon_range_bonus", 0.0))
		if global_position.distance_to(tgt.global_position) > range_total:
			continue
		if float(w["cooldown"]) > 0.0:
			continue
		w["cooldown"] = float(w["interval"]) * rate_mult
		_shoot(w, tgt)


func _shoot(w: Dictionary, tgt: Node3D) -> void:
	var side := -1.0 if int(w["slot"]) == ModuleDB.Slot.WEAPON_A else 1.0
	var family := String(w["family"])
	var muzzle_z := -1.95 if family == "lance" else -1.1
	var muzzle := to_global(Vector3(side * 0.5, 0.0, muzzle_z))
	var hit: Vector3 = tgt.global_position + Vector3(
		randf_range(-0.25, 0.25), 0.1, randf_range(-0.25, 0.25))

	# Torpedoes are projectiles, not beams: they leave now and arrive later, at
	# the spot the target occupied at launch. Everything below this line assumes
	# an instant hit, which is exactly what the family is not.
	if family == "torp":
		_launch_torpedo(w, muzzle, tgt)
		return

	# Cover is real: a rock in the way eats the shot, and you see it land.
	var obstruction = Obstacles.blocked(muzzle, tgt.global_position)
	if obstruction != null:
		FX.beam(get_parent(), muzzle, obstruction, Palette.WHITE_HOT, 0.05, 0.09)
		FX.flash(get_parent(), obstruction, Palette.AMBER, 0.5, 0.12)
		Sfx.play("hit", -16.0, 1.5)
		return

	var damage := float(w["damage"])
	var is_crit := randf() < float(_stats.get("crit_chance", 0.0))
	if is_crit:
		damage *= CRIT_MULT

	# While overcharged the mounts run hot: fatter, brighter bolts, so the
	# fire-rate half of the ability is legible and not just faster ticking.
	var oc := ability_active() and String(_ability.get("id", "")) == "overcharge"
	var w_mult := 1.7 if oc else 1.0
	var f_mult := 1.6 if oc else 1.0

	match family:
		"lance":
			FX.beam(get_parent(), muzzle, hit, Palette.AMBER, 0.15 * w_mult, 0.16)
			FX.flash(get_parent(), muzzle, Palette.WHITE_HOT, 0.8 * f_mult, 0.12)
			Sfx.play("fire", -7.0, 0.62)
			_recoil = global_transform.basis.z * 1.6
		"arc":
			FX.beam(get_parent(), muzzle, hit, Palette.TEAL, 0.05 * w_mult, 0.09)
			FX.flash(get_parent(), muzzle, Palette.TEAL, 0.4 * f_mult, 0.07)
			Sfx.play("fire", -11.0, 1.35)
			_recoil = global_transform.basis.z * 0.3
		_:
			FX.beam(get_parent(), muzzle, hit, Palette.WHITE_HOT, 0.06 * w_mult, 0.1)
			FX.flash(get_parent(), muzzle, Palette.AMBER, 0.45 * f_mult, 0.08)
			Sfx.play("fire", -9.0, 1.0)
			_recoil = global_transform.basis.z * 0.6

	_damage_target(tgt, damage, is_crit)

	var chain := int(w.get("chain", 0))
	if chain > 0:
		_chain_from(tgt, hit, damage, chain)


func _launch_torpedo(w: Dictionary, muzzle: Vector3, tgt: Node3D) -> void:
	# Aimed at the target's CURRENT position and then forgotten. No tracking, no
	# lead: what the shot is worth depends entirely on whether the thing you shot
	# at is the kind of thing that moves.
	var damage := float(w["damage"])
	if randf() < float(_stats.get("crit_chance", 0.0)):
		damage *= CRIT_MULT

	var shell := Torpedo.new()
	shell.damage = damage
	shell.splash_radius = float(w.get("splash", 2.2))
	# Carried through the flight so the blast is still attributable when it
	# lands 0.7s from now — the player may well be dead or docked by then, but
	# the shot was theirs and the kill is too.
	shell.shooter = self
	shell.launch(muzzle, tgt.global_position)
	get_parent().add_child(shell)

	FX.flash(get_parent(), muzzle, Palette.AMBER, 0.7, 0.1)
	Sfx.play("fire", -6.0, 0.5)
	_recoil = global_transform.basis.z * 1.9


func _chain_from(origin: Node3D, from_pos: Vector3, damage: float, hops: int) -> void:
	# Arc weapons jump to nearby contacts at falling damage — the reason they
	# shred swarms and tickle single targets.
	var hit_already := [origin]
	var prev_pos := from_pos
	var dmg := damage
	for i in range(hops):
		var best: Node3D = null
		var best_d := CHAIN_RADIUS
		for node in get_tree().get_nodes_in_group("hostiles"):
			var n := node as Node3D
			if not is_instance_valid(n) or hit_already.has(n):
				continue
			var d := prev_pos.distance_to(n.global_position)
			if d < best_d:
				best_d = d
				best = n
		if best == null:
			return
		var target_pos: Vector3 = best.global_position
		if Obstacles.blocked(prev_pos, target_pos) != null:
			return          # the arc cannot bend around a rock either
		dmg *= CHAIN_FALLOFF
		FX.beam(get_parent(), prev_pos, target_pos, Palette.TEAL, 0.04, 0.1)
		_damage_target(best, dmg, false)
		hit_already.append(best)
		prev_pos = target_pos


func _damage_target(target: Node3D, damage: float, is_crit: bool) -> void:
	if not is_instance_valid(target) or not target.has_method("take_damage"):
		return
	# `self` is what makes this a PLAYER kill: attribution decides loot, credit
	# and contract ticks on the far side (v18 / HORIZON-4 A1). Every weapon
	# path the player owns — pulse, lance, arc chain — funnels through here.
	target.take_damage(damage, self)
	if is_crit:
		FX.flash(get_parent(), target.global_position + Vector3(0, 0.4, 0), Palette.GOLD, 1.1, 0.16)


# --- damage & failure -------------------------------------------------------

func take_hit(amount: float, source: Node3D = null) -> void:
	# `source` is optional so every existing caller keeps working untouched; the
	# ones that pass it get return fire aimed at the thing that actually shot,
	# which in a pack is rarely the nearest thing.
	if source != null:
		_threat = source
		_since_threat = 0.0
	if is_protected():
		FX.flash(get_parent(), global_position, Palette.TEAL, 1.2, 0.14)
		return
	shield -= amount
	_time_since_hit = 0.0
	FX.flash(get_parent(), global_position + Vector3(0, 0.2, 0), Palette.THREAT, 0.9, 0.15)
	Sfx.play("hit", -8.0, 0.85)
	Sfx.haptic("light")
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.shake(0.035)
	if shield <= 0.0:
		_emergency_warp()


# --- system-to-system warp (driven by main.gd) ------------------------------

func begin_warp_charge() -> void:
	attack_target = null
	auto_target = null
	_threat = null
	_emp = 0.0
	has_move_target = false
	velocity = Vector3.ZERO
	clear_tether()
	invulnerable = true
	if _engine_mat:
		var tw := create_tween()
		tw.tween_property(_engine_mat, "emission_energy_multiplier", 9.0, 0.7)


func warp_streak_out() -> void:
	Sfx.play("warp", -6.0, 1.05)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.25, 0.25, 4.5), 0.5).set_ease(Tween.EASE_IN)


func warp_streak_in() -> void:
	scale = Vector3(0.25, 0.25, 4.5)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE, 0.55).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	tw.tween_callback(func() -> void:
		invulnerable = false
		_grace = WARP_GRACE
		shield = shield_max
		if _engine_mat:
			_engine_mat.emission_energy_multiplier = 1.2
	)


func _emergency_warp() -> void:
	# Gentle fail state: you lose position and tempo, and — only out past the
	# chart edge — whatever you had not yet learned to read. See Main.spill_unread
	# for why that scope is exactly right. Inside the charted system this is still
	# what the tutorial promised: you never lose salvage.
	if _warping:
		return
	_warping = true
	shield = 0.0
	invulnerable = true
	attack_target = null
	auto_target = null
	_threat = null
	_emp = 0.0        # a stun must never survive the thing that ends the fight
	has_move_target = false
	velocity = Vector3.ZERO
	clear_tether()

	var parent := get_parent()
	# CAPTURED HERE, before the tween. The position reset happens in a callback
	# roughly 0.64s from now, and a spill belongs at the place you died — not at
	# the spawn point the ship is about to appear at.
	var death_pos := global_position
	var main_node := get_tree().get_first_node_in_group("main")
	if main_node and main_node.has_method("spill_unread"):
		main_node.spill_unread(death_pos)
	# A hold does not survive the thing that ended it. hold_tick would otherwise
	# find the ship out of range of the wreck it was cracking and issue a fresh
	# move order, flying the respawned player back toward what killed them.
	var rig_now := get_tree().get_first_node_in_group("camera_rig")
	if rig_now and rig_now.has_method("cancel_hold"):
		rig_now.cancel_hold()
	Sfx.play("alarm", -5.0)
	Sfx.play("warp", -4.0)
	FX.flash(parent, global_position, Palette.THREAT, 2.6, 0.3)
	FX.shockwave(parent, global_position, Palette.THREAT, 5.0, 0.6)

	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.shake(0.2)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.prompt("SHIELDS DOWN — EMERGENCY WARP")
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("on_player_downed"):
		main.on_player_downed()

	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3(0.3, 0.3, 3.5), WARP_TIME * 0.4).set_ease(Tween.EASE_IN)
	tw.tween_callback(func() -> void:
		teleport_to(SPAWN_POINT)
		FX.flash(parent, SPAWN_POINT, Palette.TEAL, 2.0, 0.35)
	)
	tw.tween_interval(OFFLINE_TIME)
	tw.tween_property(self, "scale", Vector3.ONE, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_callback(func() -> void:
		shield = shield_max
		invulnerable = false
		_warping = false
		# Brief grace so you re-materialize with a chance to reposition rather
		# than straight back into whatever just killed you.
		_grace = WARP_GRACE
		var h := get_tree().get_first_node_in_group("hud")
		if h:
			h.clear_prompt()
	)
