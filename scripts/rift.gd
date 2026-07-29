class_name Rift
extends Node3D
# An unstable shear in the deep: a windfall with a fuse you can read.
#
# THE EXPIRY IS ESCALATION, NOT A CLOCK. A hidden countdown fails the Cantina
# standard (a bad bet you cannot see is a con), and content vanishing under a
# mid-collection player fails 14. So the rift dies in three telegraphed
# COLLAPSE PULSES — klaxon, ring, a pack arriving, a third of the remaining pot
# evaporating — and after the third it is gone. Staying longer is more of the
# pot and more company. The timer is legible as danger.
#
# Nothing here is saved, anywhere. A rift is weather you were present for: it is
# a system_root child, it dies with the system, and a reload never owed it to
# you — unlike a market event, it was never promised to persist.

const CRATE_MIN := 30
const CRATE_MAX := 36
const PULSES := 3
const EVAPORATE_SHARE := 0.30
const SCATTER := 7.0

var band := 2                 # the band of the DEPTH it sits at
var pulse_interval := 75.0    # a var so the harness can drive it without waiting

var pulses_done := 0
var _pulse_timer := 0.0
var _crates: Array = []
var _tear: MeshInstance3D
var _tear_mat: StandardMaterial3D
var _spin := 0.0


func _ready() -> void:
	_pulse_timer = pulse_interval
	_build()
	_spill_pot()


func _build() -> void:
	# The tear: a stretched, slowly turning ring of the band-above's colour —
	# the one thing out here that is visibly a hole rather than a thing.
	_tear = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.0
	tm.outer_radius = 2.35
	tm.ring_segments = 48
	_tear.mesh = tm
	_tear.scale = Vector3(1.0, 2.6, 0.35)
	_tear_mat = Palette.emissive(Palette.DEEP_BANDS[_rich_band()], 3.2)
	_tear.material_override = _tear_mat
	add_child(_tear)

	var mast := SurveyMast.new()
	mast.band = band
	mast.survey_time = 3.0 + 0.5 * float(band - 1)
	# A rift has no cell of its own; the sentinel cell keeps note_surveyed
	# harmless while the mast still pays its chart packet.
	mast.cell = Vector2i(0x7ffffff, 0x7ffffff)
	add_child(mast)
	mast.position = Vector3(0, 0, 4.0)


func _rich_band() -> int:
	# Rich means ONE BAND BETTER than the depth deserves, using goods that
	# already exist — no new grade, no new table.
	return clampi(band + 1, 1, DeepSpace.BAND_NAMES.size() - 1)


func _spill_pot() -> void:
	var good := CommodityDB.salvage_for_band(_rich_band())
	if good == "":
		return
	var script := load("res://scripts/loot_cube.gd") as GDScript
	var count := randi_range(CRATE_MIN, CRATE_MAX)
	for i in range(count):
		var cube: Node3D = script.new()
		cube.commodity = good
		# Spill-flagged for the same three reasons the death spill is: stock
		# cubes would reap themselves at 25s and vacuum themselves to the player
		# from any distance at 1.3s — a pot that collects itself is not a pot.
		cube.spill = true
		add_child(cube)
		var ang := randf() * TAU
		cube.position = Vector3(cos(ang), 0.0, sin(ang)) * randf_range(1.5, SCATTER)
		_crates.append(cube)


func _process(delta: float) -> void:
	_spin += delta
	if _tear:
		_tear.rotation.y = _spin * 0.4
		_tear_mat.emission_energy_multiplier = 2.4 + sin(_spin * 3.1) * 1.0 \
			+ float(pulses_done) * 0.9

	_pulse_timer -= delta
	if _pulse_timer <= 0.0:
		pulse()


func pulse() -> void:
	# One step of the collapse. Public so the harness drives it directly instead
	# of waiting out 75-second intervals nobody will sit through.
	if pulses_done >= PULSES:
		return
	pulses_done += 1
	_pulse_timer = pulse_interval

	var tree := get_tree()
	Sfx.play("klaxon", -9.0, 1.3)
	FX.shockwave(get_parent(), global_position, Palette.DEEP_BANDS[_rich_band()], 9.0, 0.8)
	var rig := tree.get_first_node_in_group("camera_rig")
	if rig:
		rig.shake(0.1)

	# A third of what is left goes back through the tear.
	var standing: Array = []
	for c in _crates:
		if is_instance_valid(c):
			standing.append(c)
	var lose := int(ceil(float(standing.size()) * EVAPORATE_SHARE))
	for i in range(mini(lose, standing.size())):
		var victim: Node3D = standing[i]
		FX.flash(get_parent(), victim.global_position, Palette.DEEP_BANDS[_rich_band()], 0.5, 0.2)
		victim.queue_free()

	# And something comes through it. Band-curve pack, leashed like every other
	# deep spawn — parented to the SYSTEM, never to the rift, or the third pulse
	# would delete the fight it just started.
	var root := get_parent()
	var hud := tree.get_first_node_in_group("hud")
	if root:
		var count := randi_range(DeepSpace.PACK_MIN[band], maxi(DeepSpace.PACK_MIN[band], DeepSpace.PACK_MAX[band] - 2))
		for i in range(maxi(count, 2)):
			var s := SwarmHostile.new()
			s.difficulty = DeepSpace.PACK_DIFFICULTY[band]
			s.hp_scale = DeepSpace.PACK_HP[band]
			s.tint = Palette.DEEP_BANDS[band]
			s.despawn_radius = DeepSpace.HOSTILE_LEASH
			root.add_child(s)
			s.global_position = global_position + Vector3(
				randf_range(-2.0, 2.0), 0.0, randf_range(-2.0, 2.0))

	if pulses_done >= PULSES:
		# The shear closes over whatever was not carried away.
		for c in _crates:
			if is_instance_valid(c):
				c.queue_free()
		FX.shockwave(get_parent(), global_position, Palette.WHITE_HOT, 14.0, 1.1)
		Sfx.play("breach", -8.0, 0.7)
		if hud:
			hud.show_toast("THE SHEAR HAS CLOSED", Palette.AMBER_DIM)
		# `band` is where the shear SAT, not what it paid — the pot is
		# _rich_band(). The log records the place, in the toast's own words.
		GameState.note_log("THE SHEAR CLOSED — %s" % DeepSpace.BAND_NAMES[band])
		var m := tree.get_first_node_in_group("main")
		if m and m.get("live_rift") == self:
			m.set("live_rift", null)
		queue_free()
	elif hud:
		hud.show_toast("THE SHEAR IS FAILING — %d OF %d" % [pulses_done, PULSES],
			Palette.THREAT)


func crates_standing() -> int:
	var n := 0
	for c in _crates:
		if is_instance_valid(c) and not c.is_queued_for_deletion():
			n += 1
	return n
