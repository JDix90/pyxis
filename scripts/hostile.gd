class_name Hostile
extends Node3D
# Automated sentry: drifts near its post, telegraphs then fires on the player,
# and dies in a staged sequence (hitstop + flash + shockwave -> fireball ->
# secondary burst + loot spill).
#
# --- FEEL CONSTANTS ---
const ENGAGE_RANGE := 9.0
const FIRE_INTERVAL := 1.15
const TELEGRAPH := 0.4
const DAMAGE := 14.0
const LOOT_COUNT := 14
const DEATH_STAGE_2 := 0.10
const DEATH_STAGE_3 := 0.38

# Base hull before any scaling. A const rather than three literals so a harness
# can compute what a guard SHOULD have from the same number the class uses,
# instead of restating it and drifting.
const BASE_HP := 120.0

var difficulty := 1.0  # set by SystemBuilder before the node enters the tree
# Scales HP independently of `difficulty`, which scales BOTH hp and damage. The
# two have to come apart for deep guards: a machine standing 1100u from the
# nearest dock, with no station to run to and no regen window, has to be a WALL
# rather than a harder puncher. On one dial the only way to make it tanky is to
# make its shot lethal — at the swarm curve's 2.6 a Quiet guard would hit for
# 36.4 against PYX-03's authored sentries at 30.8, which is exactly backwards.
# Defaults to 1.0, so every authored sentry is untouched.
var hp_scale := 1.0

var hp := 120.0
var max_hp := 120.0

# See SwarmHostile.despawn_radius. 0 = never give up, which is every authored
# sentry. A sentry does not chase, but one left standing 600u out in the expanse
# after the player has flown home is still litter that nothing would ever clear.
var despawn_radius := 0.0

# Set by the spawner BEFORE add_child (_build_mesh runs in _ready), same contract
# as SwarmHostile.tint. A deep guard is the same machine as a charted sentry
# standing somewhere else, so the tell is paint rather than a new silhouette.
var tint := Color(0.0, 0.0, 0.0, 0.0)
# What the scanner can still tell you about this thing. Empty on every authored
# sentry: on the chart you know perfectly well what a picket is.
var designation := ""
# Parley standoff, mirroring SwarmHostile: positive means hold fire.
var standoff := 0.0

var _fire_cooldown := 0.0
var _charging := false
var _home := Vector3.ZERO
var _home_set := false
var _drift_phase := 0.0
var _dying := false
var _hp_fill: MeshInstance3D
var _core_mat: StandardMaterial3D
var _body_parts: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("hostiles")
	max_hp = BASE_HP * difficulty * hp_scale
	hp = max_hp
	# _home is captured on the FIRST FRAME, not here. _ready fires from
	# add_child(), and every spawner in the game — SystemBuilder, the apex, the
	# interdiction, the expanse — sets `position` on the line AFTER add_child,
	# because a node has to be in the tree before global_position means anything.
	# Reading it here therefore always returned the container's origin, and since
	# _process hard-writes `global_position = _home + drift`, every sentry in
	# every system was snapping to the middle of the map on frame one. PYX-01's
	# four lane guards were authored 6-20u out and were all sitting on top of the
	# player's spawn point.
	_drift_phase = randf() * TAU
	_fire_cooldown = randf_range(0.5, FIRE_INTERVAL)
	_build_mesh()
	_build_hp_bar()


func _build_mesh() -> void:
	# Spiky rotor of dark vanes around a glitch-magenta core.
	var core := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.28
	cm.height = 0.56
	core.mesh = cm
	# The CORE takes the band colour outright rather than blending — it is the part
	# that swells during the telegraph, so the colour lands on the thing already
	# drawing the eye at the moment it matters.
	_core_mat = Palette.emissive(tint if tint.a > 0.0 else Palette.THREAT, 2.5)
	core.material_override = _core_mat
	add_child(core)
	_body_parts.append(core)

	for i in range(5):
		var vane := MeshInstance3D.new()
		var vm := BoxMesh.new()
		vm.size = Vector3(0.16, 0.1, 1.15)
		vane.mesh = vm
		var ang := TAU * float(i) / 5.0
		vane.position = Vector3(cos(ang), 0, sin(ang)) * 0.55
		vane.rotation.y = -ang + PI / 2.0
		vane.material_override = Palette.matte(_hull_color(Color(0.16, 0.15, 0.2)))
		add_child(vane)
		_body_parts.append(vane)


func _hull_color(base: Color) -> Color:
	# Blends at 0.45, NOT SwarmHostile's 0.62. A sentry's silhouette is roughly
	# four times a dart's, so the same blend covers four times the screen: at
	# 0.62 a Quiet guard's vanes land on Color(0.63, 0.66, 0.70), which is
	# Palette.HULL — the player's own ship. The band has to read as paint on a
	# familiar machine, not as a repaint of the player.
	if tint.a <= 0.0:
		return base
	return base.lerp(tint, 0.45)


func is_dying() -> bool:
	# _die() does not queue_free until DEATH_STAGE_3, so a node mid-explosion is
	# still valid and must not be counted as standing.
	return _dying


func _build_hp_bar() -> void:
	var bar := Node3D.new()
	bar.name = "HPBar"
	add_child(bar)
	bar.position = Vector3(0, 1.1, 0)

	var bg := MeshInstance3D.new()
	var bgm := BoxMesh.new()
	bgm.size = Vector3(1.3, 0.09, 0.02)
	bg.mesh = bgm
	bg.material_override = Palette.emissive(Color(0.25, 0.03, 0.1, 0.85), 1.0)
	bar.add_child(bg)

	_hp_fill = MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.3, 0.09, 0.02)
	_hp_fill.mesh = fm
	_hp_fill.position.z = -0.01
	_hp_fill.material_override = Palette.emissive(Palette.THREAT, 2.0)
	bar.add_child(_hp_fill)


func _process(delta: float) -> void:
	if _dying:
		return
	if not _home_set:
		# Wherever the spawner put us, now that it has finished putting us there.
		_home = global_position
		_home_set = true
	if despawn_radius > 0.0:
		var who: Node3D = get_tree().get_first_node_in_group("player")
		if who != null and global_position.distance_to(who.global_position) > despawn_radius:
			_give_up()
			return
	rotation.y += delta * 0.8
	var t := Time.get_ticks_msec() / 1000.0
	global_position = _home + Vector3(sin(t * 0.5 + _drift_phase), 0, cos(t * 0.4 + _drift_phase)) * 0.4

	var cam := get_viewport().get_camera_3d()
	var bar := get_node_or_null("HPBar")
	if cam and bar:
		bar.global_transform.basis = cam.global_transform.basis

	_weapon(delta)


func _weapon(delta: float) -> void:
	if standoff > 0.0:
		standoff -= delta
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	# A docked ship is not a target: safety at port has to be total, or it is
	# not safety.
	if not player or player.docked \
			or global_position.distance_to(player.global_position) > ENGAGE_RANGE:
		_charging = false
		_core_mat.emission_energy_multiplier = 2.5
		return

	_fire_cooldown -= delta
	# Telegraph: the core swells before the shot so the hit is never a surprise.
	if _fire_cooldown <= TELEGRAPH and _fire_cooldown > 0.0:
		var k := 1.0 - _fire_cooldown / TELEGRAPH
		_core_mat.emission_energy_multiplier = 2.5 + k * 7.0
	elif _fire_cooldown <= 0.0:
		_fire_cooldown = FIRE_INTERVAL
		_core_mat.emission_energy_multiplier = 2.5
		var muzzle := global_position + Vector3(0, 0.1, 0)
		var cover = Obstacles.blocked(muzzle, player.global_position)
		if cover != null:
			# Cover protects the player from sentries too, not just the reverse.
			FX.beam(get_parent(), muzzle, cover, Palette.THREAT, 0.05, 0.12)
			return
		FX.beam(get_parent(), muzzle, player.global_position, Palette.THREAT, 0.05, 0.14)
		Sfx.play("fire", -14.0, 0.72)
		if player.has_method("take_hit"):
			player.take_hit(DAMAGE * difficulty, self)


func take_damage(amount: float) -> void:
	if _dying:
		return
	if standoff > 0.0 and is_in_group("raider"):
		var m2 := get_tree().get_first_node_in_group("main")
		if m2 and m2.has_method("break_parley"):
			m2.break_parley()
	hp -= amount
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	_hp_fill.scale.x = maxf(frac, 0.001)
	_hp_fill.position.x = -1.3 * (1.0 - frac) * 0.5
	FX.flash(get_parent(), global_position + Vector3(0, 0.3, 0), Palette.WHITE_HOT, 0.6, 0.1)
	Sfx.play("hit", -11.0)
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.shake(0.012)
	if hp <= 0.0:
		_die()


func _give_up() -> void:
	# Not a kill: no loot, no credit, no staged death. It is simply not there.
	_dying = true
	remove_from_group("hostiles")
	remove_from_group("raider")
	queue_free()


func depart() -> void:
	# Same contract as SwarmHostile.depart: groups shed immediately, nothing paid
	# back, brief exit theater.
	if _dying:
		return
	_dying = true
	remove_from_group("hostiles")
	remove_from_group("raider")
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.1, 1.8).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _die() -> void:
	_dying = true
	var parent := get_parent()
	var pos := global_position
	var tree := get_tree()
	remove_from_group("hostiles")

	var rig := tree.get_first_node_in_group("camera_rig")
	var main := tree.get_first_node_in_group("main")
	if main and main.has_method("report_kill"):
		main.report_kill("sentry")

	# If this was a deep guard, its post may have just fallen. `_dying` is already
	# true above, so post_standing correctly does not count this node. Credited
	# HERE rather than at cell despawn: a player who clears a post and keeps
	# working the wreck beside it never triggers a despawn.
	if has_meta("post_key") and main and main.deep_space:
		main.deep_space.note_guard_died(get_meta("post_key"))

	# Stage 1: hitstop + white flash + shockwave, body blows apart.
	if main and main.has_method("hit_stop"):
		main.hit_stop(0.07, 0.25)
	if rig:
		rig.shake(0.12)
		rig.punch_zoom(-0.7)
	FX.flash(parent, pos, Palette.WHITE_HOT, 2.4, 0.18)
	FX.shockwave(parent, pos, Palette.WHITE_HOT, 4.5, 0.5)
	Sfx.play("explode", -3.0, 1.0)
	for part in _body_parts:
		var dir := Vector3(randf_range(-1, 1), randf_range(0, 0.5), randf_range(-1, 1)).normalized()
		var tw := part.create_tween()
		tw.set_parallel(true)
		tw.tween_property(part, "position", part.position + dir * 1.8, 0.45)
		tw.tween_property(part, "scale", Vector3.ONE * 0.05, 0.45)

	# Stage 2: main fireball.
	tree.create_timer(DEATH_STAGE_2).timeout.connect(func() -> void:
		FX.burst(parent, pos, Color(1.0, 0.55, 0.15), 60, 10.0, 0.3, 0.75)
		FX.burst(parent, pos, Palette.THREAT, 25, 6.5, 0.2, 0.55)
	)

	# Stage 3: secondary burst + loot spill, then free.
	tree.create_timer(DEATH_STAGE_3).timeout.connect(func() -> void:
		FX.burst(parent, pos, Color(1.0, 0.8, 0.4), 35, 5.0, 0.2, 0.7)
		var m := tree.get_first_node_in_group("main")
		var crate := CommodityDB.roll_drop("sentry")
		for i in range(LOOT_COUNT):
			var spot := pos + Vector3(randf_range(-0.4, 0.4), 0.1, randf_range(-0.4, 0.4))
			if m:
				m.spawn_loot(parent, spot, crate if i == 0 else "")
		queue_free()
	)
