class_name Beacon
extends Node3D
# A WAYPOINT THE PLAYER PAID FOR (v19, Hunt stage 5). The deep has no lattice
# and no chart; the one navigation instrument out there is the bottom-left
# readout, and a place worth returning to — a rich cell, a station, and next
# stage a hyper-structure — could only be remembered by writing its bearing on
# paper. A beacon is that memory, dropped in the world and persisted in the
# save: eight in stock, each one standing somewhere until it is recovered.
#
# THE STOCK IS THE DESIGN. Eight is enough to thread a route across a system's
# deep and few enough that a beacon is a decision — an unlimited supply would
# be spray-paint, and the recover verb would never once be used. Stock is
# DERIVED (BEACON_STOCK minus every dropped entry across every system), never
# stored: §59's derived-not-tracked rule, so the save cannot disagree with
# itself about how many beacons exist.
#
# RECOVERY IS THE MAST'S VERB. hold_begin/hold_tick/hold_release mirror
# SurveyMast — the ship parks in range and holds — because the deep already
# taught that gesture, and a flyover pickup would delete the marker at the
# exact moment the player arrives at the thing it marks.

const HOLD_RANGE := 6.0
const RECOVER_TIME := 1.6
const DECAY_RATE := 0.8

# Which system this beacon's store entry lives in. Set by the spawner before
# add_child, like every identity field in this project. Removal is keyed by
# POSITION, not by index — an index held on a node goes stale the moment a
# sibling in the same system is recovered first, and a position cannot.
var system_id := ""
# v22. NOT YOURS. A rival beacon reuses this whole node -- mesh, breath, pick
# group, radar tier -- because it IS a beacon; what differs is small enough to
# be a flag. Foreign beacons are world dressing, not store entries: they are
# spawned by the cell streamer from the rival function, never live in
# GameState.beacons, never count against stock, and refuse recovery -- the
# anchor code is not yours to release.
var foreign := false

var _holding := false
var _progress := 0.0
var _pulse_mat: StandardMaterial3D
var _t := 0.0


static func _accent() -> Color:
	# The player's livery accent — the colour that already means "yours". Read
	# through Palette.livery_accent, the accessor the refit sheet uses, with the
	# same default-0 the loader clamps to.
	return Palette.livery_accent(int(GameState.livery.get("accent", 0)))


func _ready() -> void:
	# The pick group CameraRig's hold ladder reads, LAST in priority: a beacon
	# stands alone in empty deep by construction (the player chose the spot),
	# so contested taps with hulks and seams are not its problem — but the
	# ladder order still has to be stated somewhere, and it is stated there.
	add_to_group("beacon")
	_build_mesh()


func _build_mesh() -> void:
	# A slim pylon with a breathing light in the player's accent — the one
	# colour vocabulary that already means "yours" (the livery system's).
	# Deliberately NOT band paint: band colour means "where", and a beacon's
	# whole point is "whose".
	var mast := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.16, 2.2, 0.16)
	mast.mesh = bm
	mast.position.y = 1.1
	mast.material_override = Palette.emissive(Palette.HULL, 1.2)
	add_child(mast)

	var lamp := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.3
	sm.height = 0.6
	lamp.mesh = sm
	lamp.position.y = 2.4
	_pulse_mat = Palette.emissive(Palette.RIVAL if foreign else _accent(), 2.5)
	lamp.material_override = _pulse_mat
	add_child(lamp)


func _process(delta: float) -> void:
	_t += delta
	# A slow breath, not a strobe: this is furniture you left, not an alarm.
	if _pulse_mat:
		_pulse_mat.emission_energy_multiplier = 1.6 + sin(_t * 2.2) * 1.1
	if not _holding and _progress > 0.0:
		_progress = maxf(_progress - DECAY_RATE * delta, 0.0)
		_sync_gauge()


func pick_anchor() -> Vector3:
	return global_position + Vector3(0, 1.2, 0)


func _player_in_range() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	return p != null and global_position.distance_to(p.global_position) <= HOLD_RANGE


func hold_begin() -> void:
	if foreign:
		# WHICH refusal, per 58 -- and a refusal, not a silence: the hold
		# gesture on a beacon has meant "recover" since v19, so a foreign one
		# that simply did nothing would read as a bug.
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_toast"):
			hud.show_toast("NOT YOUR ANCHOR CODE — THIS BEACON ANSWERS TO SOMEBODY ELSE",
				Palette.RIVAL)
		Sfx.play("hit", -12.0, 0.7)
		return
	if not _player_in_range():
		_approach()
		return
	_holding = true


func hold_release() -> void:
	_holding = false
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and _progress < 1.0:
		hud.crack_progress(-1.0)


func hold_tick(delta: float) -> void:
	if not _holding:
		return
	if not _player_in_range():
		hold_release()
		return
	_progress += delta / RECOVER_TIME
	_sync_gauge()
	if _progress >= 1.0:
		_recover()


func marker_color() -> Color:
	# The radar override hud.gd already honours. Own beacons wear the livery
	# accent there too -- the same colour the world mesh already breathes, which
	# closes a small radar/world disagreement -- and foreign ones wear RIVAL.
	return Palette.RIVAL if foreign else _accent()


func on_tapped() -> void:
	FX.ring_pulse(get_parent(), pick_anchor(),
		Palette.RIVAL if foreign else _accent(), 1.2)
	if not _player_in_range():
		_approach()


func _approach() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("command_move"):
		p.command_move(global_position + Vector3(2.5, 0, 0))


func _sync_gauge() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(_progress if _progress > 0.001 else -1.0, "RECOVERING BEACON")


func _recover() -> void:
	# THE STORE FIRST, then the theater. GameState is authoritative — the node
	# is a projection of it, rebuilt on every _load_system — so a recover that
	# freed the node before the store entry would leave a ghost that respawns
	# on the next warp.
	_holding = false
	GameState.recover_beacon(system_id, global_position.x, global_position.z)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(-1.0)
		hud.show_toast("BEACON RECOVERED — %d IN STOCK" % GameState.beacon_stock_left(),
			_accent())
	Sfx.play("equip", -10.0, 1.1)
	FX.ring_pulse(get_parent(), global_position, _accent(), 3.0, 0.5)
	queue_free()
