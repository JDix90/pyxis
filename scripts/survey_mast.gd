class_name SurveyMast
extends Node3D
# A thing out here worth reading. Hold on it and you come away with CHART DATA:
# bearings, masses, whatever the lens can resolve — sellable at any counter that
# buys, because the people who buy charts are the people who will not fly out to
# make them.
#
# The fourth implementation of the same duck-typed hold contract Derelict and
# ApexWreck already carry (`hold_begin` / `hold_tick` / `hold_release` /
# `on_tapped` / `pick_anchor`). CameraRig picks by GROUP and calls by method, so
# joining "crackable" costs zero lines anywhere else — and buys the radar marker
# for free, since RadarLayer scans the same group.
#
# On a hulk this sits at the STERN while the breach beacon sits at the prow, 13.2
# units apart. That separation is doing three jobs: it gives `_pick` room to tell
# two verbs on one wreck apart, it puts the survey stand-off outside the ring of
# guard posts that ring the breach point, and -- since it exceeds CRACK_RANGE +
# SURVEY_RANGE -- it keeps the two in-range prompts from overlapping and fighting
# over hud.prompt's single slot. Surveying a guarded hulk is the sneak play;
# cracking it is what contests the post.

# Where the mast rides on a hulk, along the hull's forward axis. The breach
# beacon sits at Derelict.BEACON_LOCAL.z (-6.6); this is that mirrored, which is
# both why the wreck reads as symmetrical and why the dish clears the stern
# block. See the comment at the placement site in deep_space.gd for the geometry
# it used to be buried in.
const HULL_OFFSET := 6.6

const SURVEY_RANGE := 6.5
const DECAY_RATE := 1.6
const YIELD_UNITS := 2

# Set by whoever builds it, before add_child.
var band := 1
var survey_time := 3.0
# Where this reading is recorded once taken, so it is not taken twice. Session
# state owned by DeepSpace; the mast only reports.
var cell := Vector2i.ZERO

var surveyed := false

var _holding := false
var _progress := 0.0
var _dish: MeshInstance3D
var _dish_mat: StandardMaterial3D
var _spin := 0.0
var _in_range_last := false


func _ready() -> void:
	add_to_group("crackable")
	add_to_group("survey_mast")
	_build()


func _build() -> void:
	var mast := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.06
	mm.bottom_radius = 0.12
	mm.height = 1.9
	mast.mesh = mm
	mast.position.y = 0.95
	mast.material_override = Palette.matte(Color(0.22, 0.22, 0.26))
	add_child(mast)

	_dish = MeshInstance3D.new()
	var dm := TorusMesh.new()
	dm.inner_radius = 0.36
	dm.outer_radius = 0.52
	dm.ring_segments = 18
	_dish.mesh = dm
	_dish.position.y = 1.95
	_dish.rotation.x = PI / 2.4
	_dish_mat = Palette.emissive(Palette.band_color(band), 2.0)
	_dish.material_override = _dish_mat
	add_child(_dish)


func dish_aabb() -> AABB:
	# The dish's box in WORLD space, at its current spin. Read-back for
	# PYXIS_CARTTEST's MAST IS CLEAR: the thing that went wrong here was purely
	# geometric, so the assertion measures the geometry rather than the number
	# that produced it -- change the hull, the offset or the dish and it follows.
	if _dish == null:
		return AABB()
	var local := _dish.get_aabb()
	return _dish.global_transform * local


func pick_anchor() -> Vector3:
	return global_position + Vector3(0, 1.95, 0)


func _process(delta: float) -> void:
	_spin += delta
	if _dish:
		_dish.rotation.y = _spin * 0.7
		_dish_mat.emission_energy_multiplier = (0.6 if surveyed else 1.6) \
			+ (0.0 if surveyed else sin(_spin * 2.2) * 0.5)

	if not _holding and _progress > 0.0:
		_progress = maxf(_progress - DECAY_RATE * delta, 0.0)
		_sync_gauge()

	var near := _player_in_range()
	if near != _in_range_last:
		_in_range_last = near
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			if near and not surveyed:
				hud.prompt("HOLD TO SURVEY — %s" % DeepSpace.BAND_NAMES[
					clampi(band, 0, DeepSpace.BAND_NAMES.size() - 1)])
			else:
				hud.clear_prompt()


func _player_in_range() -> bool:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	return player.global_position.distance_to(global_position) <= SURVEY_RANGE


func survey_seconds() -> float:
	# Scanners finally do something sensor-shaped. Until now "Targeting Scanner"
	# was a range-and-crit module wearing an instrument's name.
	var speed := 1.0 + float(GameState.stats.get("survey_speed", 0.0))
	return survey_time / maxf(speed, 0.2)


# --- the hold contract ------------------------------------------------------

func hold_begin() -> void:
	if surveyed or _holding:
		return
	if not _player_in_range():
		on_tapped()
		return
	_holding = true


func hold_release() -> void:
	if not _holding:
		return
	_holding = false
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and not surveyed:
		hud.crack_progress(-1.0)


func hold_tick(delta: float) -> void:
	if surveyed or not _holding:
		return
	if not _player_in_range():
		hold_release()
		_approach()
		return
	_progress += delta / maxf(survey_seconds(), 0.05)
	_sync_gauge()
	if _progress >= 1.0:
		_complete()


func on_tapped() -> void:
	if surveyed:
		return
	FX.ring_pulse(get_parent(), pick_anchor(), Palette.TEAL, 1.2)
	if _player_in_range():
		return
	_approach()


func _approach() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var toward: Vector3 = player.global_position - global_position
	toward.y = 0.0
	if toward.length() < 0.1:
		toward = Vector3.BACK
	var stand: Vector3 = global_position + toward.normalized() * (SURVEY_RANGE * 0.78)
	stand.y = 0.0
	player.command_move(stand)


func _sync_gauge() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(_progress if _progress > 0.001 else -1.0, "SURVEYING")


func _complete() -> void:
	# Guards ITSELF rather than trusting hold_tick to have checked. Both callers
	# do check, which is exactly why this is worth writing down: a function that
	# is safe only because of who calls it stops being safe the moment something
	# else calls it, and nothing about the name says so.
	if surveyed:
		return
	surveyed = true
	_holding = false
	_progress = 0.0
	remove_from_group("crackable")

	var good := CommodityDB.chart_for_band(band)
	var taken := GameState.load_cargo(good, YIELD_UNITS) if good != "" else 0

	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(-1.0)
		if taken > 0:
			hud.show_toast("SURVEY LOGGED — %s x%d" % [
				CommodityDB.short_name(good), taken], CommodityDB.color_of(good))
			hud.refresh_cargo()
		else:
			# The hold is full and a reading has nowhere to go. Said out loud
			# rather than silently dropped — and the mast stays unsurveyed, so
			# the trip is not wasted, only deferred.
			hud.show_toast("NO ROOM FOR THE READING", Palette.THREAT)
	if taken <= 0:
		surveyed = false
		add_to_group("crackable")
		return

	Sfx.play("equip", -7.0, 1.35)
	FX.ring_pulse(get_parent(), pick_anchor(), CommodityDB.color_of(good), 2.6, 0.7)

	var main := get_tree().get_first_node_in_group("main")
	if main and main.deep_space:
		main.deep_space.note_surveyed(cell)
