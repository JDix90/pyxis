class_name ApexWreck
extends Node3D
# What the Gnomon leaves behind. Implements the same duck-typed contract the
# CameraRig already speaks to Derelict (`pick_anchor`, `on_tapped`, `hold_begin`,
# `hold_tick`, `hold_release`), so the apex finale is the game's signature
# hold-to-breach with no new input verb — every derelict was a rehearsal.

const CRACK_RANGE := 7.0
const CRACK_TIME := 2.2
const DECAY_RATE := 1.4
const VORTEX_TIME := 3.4
const LOOT_WAVE_INTERVAL := 0.07

# Killing the same engine again still pays, just not like the first time. The
# one-time bonus already carries the "you did the thing" moment; farming a
# solved fight should not out-earn flying somewhere new.
const REPEAT_LOOT_MULT := 0.7

var loot_total := 90
var first_kill_bonus := 15000
var system_id := ""

var breach_point := Vector3.ZERO

var _progress := 0.0
var _holding := false
var _cracked := false
var _beacon: MeshInstance3D
var _beacon_mat: StandardMaterial3D
var _crack_player: AudioStreamPlayer
var _in_range_last := false


func _ready() -> void:
	add_to_group("crackable")
	_build_mesh()

	_crack_player = AudioStreamPlayer.new()
	if ResourceLoader.exists("res://audio/crack.wav"):
		_crack_player.stream = load("res://audio/crack.wav")
	_crack_player.volume_db = -5.0
	add_child(_crack_player)


func pick_anchor() -> Vector3:
	return breach_point


func is_cracked() -> bool:
	return _cracked


func _build_mesh() -> void:
	# A cooling ruin: broken hub segments slumped around an exposed core.
	for i in range(7):
		var ang := TAU * float(i) / 7.0 + 0.3
		var chunk := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(randf_range(0.9, 1.7), randf_range(0.4, 0.8), randf_range(0.9, 1.6))
		chunk.mesh = bm
		chunk.position = Vector3(cos(ang), -0.15, sin(ang)) * randf_range(2.0, 3.4)
		chunk.rotation = Vector3(randf_range(-0.4, 0.4), randf_range(0, TAU), randf_range(-0.4, 0.4))
		chunk.material_override = Palette.matte(Color(0.12, 0.11, 0.13))
		add_child(chunk)

	var core := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 1.25
	cm.height = 2.5
	cm.radial_segments = 14
	cm.rings = 8
	core.mesh = cm
	core.material_override = Palette.matte(Color(0.16, 0.14, 0.18))
	add_child(core)

	_beacon = MeshInstance3D.new()
	var bm2 := SphereMesh.new()
	bm2.radius = 0.5
	bm2.height = 1.0
	_beacon.mesh = bm2
	_beacon_mat = Palette.emissive(Palette.GOLD, 3.0)
	_beacon.material_override = _beacon_mat
	_beacon.position = Vector3(0, 1.5, 0)
	add_child(_beacon)
	breach_point = _beacon.global_position


func _process(delta: float) -> void:
	if _cracked:
		return
	breach_point = _beacon.global_position
	var t := Time.get_ticks_msec() / 1000.0
	_beacon_mat.emission_energy_multiplier = 2.6 + sin(t * 3.4) * 1.0 + _progress * 7.0
	_beacon.scale = Vector3.ONE * (1.0 + sin(t * 3.4) * 0.08 + _progress * 0.4)

	if not _holding and _progress > 0.0:
		_progress = maxf(_progress - DECAY_RATE * delta, 0.0)
		_sync_gauge()

	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		var in_range := _player_in_range()
		if in_range != _in_range_last:
			_in_range_last = in_range
			if in_range:
				hud.prompt("HOLD TO BREACH THE CORE")
			else:
				hud.clear_prompt()


func _player_in_range() -> bool:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	return player.global_position.distance_to(breach_point) <= CRACK_RANGE


func on_tapped() -> void:
	if _cracked:
		return
	FX.ring_pulse(get_parent(), breach_point, Palette.GOLD, 1.6)
	if _player_in_range():
		return
	_approach()


func _approach() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var toward: Vector3 = player.global_position - breach_point
	toward.y = 0.0
	if toward.length() < 0.1:
		toward = Vector3.BACK
	var dir: Vector3 = (toward.normalized() + Vector3.BACK * 1.2).normalized()
	var stand: Vector3 = breach_point + dir * (CRACK_RANGE * 0.8)
	stand.y = 0.0
	player.command_move(stand)


func hold_begin() -> void:
	if _cracked or _holding:
		return
	if not _player_in_range():
		on_tapped()
		return
	_holding = true
	if _crack_player.stream:
		_crack_player.play()


func hold_release() -> void:
	if not _holding:
		return
	_holding = false
	_crack_player.stop()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and not _cracked:
		hud.crack_progress(-1.0)


func hold_tick(delta: float) -> void:
	if _cracked or not _holding:
		return
	if not _player_in_range():
		hold_release()
		_approach()
		return
	_progress += delta / CRACK_TIME
	_sync_gauge()
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.shake(0.008 + _progress * 0.035)
	if _progress >= 1.0:
		_breach()


func _sync_gauge() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(_progress if _progress > 0.001 else -1.0)


func _breach() -> void:
	_cracked = true
	_holding = false
	_crack_player.stop()
	remove_from_group("crackable")

	var parent := get_parent()
	var pos := breach_point
	var tree := get_tree()
	var hud := tree.get_first_node_in_group("hud")
	var rig := tree.get_first_node_in_group("camera_rig")
	var main := tree.get_first_node_in_group("main")

	if hud:
		hud.crack_progress(-1.0)
		hud.prompt("CORE RECOVERED")
	if main and main.has_method("hit_stop"):
		main.hit_stop(0.13, 0.18)
	if rig:
		rig.shake(0.34)
		rig.punch_zoom(-1.8)

	Sfx.play("breach", 0.0)
	Sfx.play("vortex", -6.0)
	FX.flash(parent, pos, Palette.WHITE_HOT, 5.0, 0.35)
	FX.shockwave(parent, pos, Palette.GOLD, 13.0, 1.0)
	FX.burst(parent, pos, Color(1.0, 0.7, 0.25), 110, 13.0, 0.4, 1.2)
	FX.vortex(parent, pos, Palette.GOLD, VORTEX_TIME)

	_beacon.visible = false

	# Read BEFORE the bonus is awarded: award_apex_bonus is what marks the system
	# as killed, so asking afterwards would call every kill a repeat.
	var repeat := GameState.has_killed_apex(system_id)

	# First kill in this system pays a one-time bonus on top of the cubes.
	if main and main.has_method("award_apex_bonus"):
		main.award_apex_bonus(system_id, first_kill_bonus)

	_spill_waves(parent, pos, REPEAT_LOOT_MULT if repeat else 1.0)


func _spill_waves(parent: Node3D, pos: Vector3, value_mult := 1.0) -> void:
	var waves := int(VORTEX_TIME / LOOT_WAVE_INTERVAL)
	var per_wave := maxi(1, int(ceil(float(loot_total) / float(waves))))
	# A survey engine's core is the only reliable source of reactor isotopes.
	var crates := PackedStringArray()
	for i in range(4):
		crates.append("isotopes")
	for i in range(3):
		crates.append("relics")
	var crate_index := 0

	for w in range(waves):
		get_tree().create_timer(w * LOOT_WAVE_INTERVAL).timeout.connect(func() -> void:
			if not is_instance_valid(parent):
				return
			var m := get_tree().get_first_node_in_group("main")
			for i in range(per_wave):
				var spot := pos + Vector3(
					randf_range(-1.5, 1.5), randf_range(-0.6, 1.0), randf_range(-1.5, 1.5))
				var good := ""
				if crate_index < crates.size() and (w % 4) == 0 and i == 0:
					good = crates[crate_index]
					crate_index += 1
				if m:
					m.spawn_loot(parent, spot, good, value_mult)
		)
	get_tree().create_timer(VORTEX_TIME + 1.4).timeout.connect(func() -> void:
		var h := get_tree().get_first_node_in_group("hud")
		if h and h.has_method("clear_prompt"):
			h.clear_prompt()
	)
