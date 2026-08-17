class_name SignatureSite
extends Node3D
# THE ONE THING EACH PYX HAS THAT THE OTHERS DO NOT (v21). The playtest note
# this answers was that every system reads the same once you are past its chart:
# the bands are the same bands, the wrecks are the same wrecks, and only the
# small authored volume in the middle ever felt like a place. The four data
# channels — names, wash, weights, broadcasts — change how the deep READS. This
# is the thing a player points at.
#
# ONE CLASS, THREE KINDS, and that is §17's rule rather than laziness: "the
# gradient is parameters, not new classes". Three near-identical Node3Ds
# differing in a mesh and a reward would be three files to keep in step with
# CameraRig's pick ladder, the radar's tier table and the spawner — and the
# thing that actually differs between them is small enough to be a `kind`.
#
#   relay    (PYX-01, bands 1-2)  a dead GSA watch-buoy. Answers ONCE with a
#                                 degraded transmission, then is quiet forever.
#   slag     (PYX-02, bands 2-4)  cooling spoil. Ticks hull heat inside its
#                                 radius and carries a rich seam for anyone
#                                 willing to stand in it.
#   sounding (PYX-03, bands 3-5)  a plumb-line pylon. Quotes a free bearing to
#                                 the nearest deep station, through compass_deg.
#
# NOT CRACKABLE, and none of them is a fight. The deep already has hulks, packs,
# traps and guards; a fourth thing that shoots would be the frontier's existing
# vocabulary with a new hat on. These are places, which is what the note asked
# for.

const HAIL_RANGE := 14.0
# The slag field's reach. Deliberately larger than HAIL_RANGE: you are meant to
# notice you are inside it before you notice what it is.
const SLAG_RANGE := 22.0
const SLAG_DPS := 1.4
# How far a sounding line will look for something to point at. Past this it
# says so rather than inventing a bearing — §42's rule that the dossier holds
# claims, never the answer.
const SOUNDING_REACH := 900.0

var kind := ""
var band := 1
var system_id := ""

var _spoken := false
var _t := 0.0
var _lamp: StandardMaterial3D


func _ready() -> void:
	# NOT in "crackable" and NOT in "mineable": both are hold-to-work groups on
	# CameraRig's four-rung pick ladder, and joining one would put a signature
	# site in contention with the hulk or seam a player is actually reaching
	# for. Its own group, read by nothing but the harness and the radar.
	add_to_group("signature")
	_build()


func _build() -> void:
	var tint := Palette.band_color(band)
	match kind:
		"relay":
			_build_relay(tint)
		"slag":
			_build_slag(tint)
		_:
			_build_sounding(tint)


func _build_relay(tint: Color) -> void:
	# A buoy: short mast, dead lamp housing, one drooping vane. Small, because
	# the Shoals are where a player is still learning that the deep has things
	# in it at all.
	var mast := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.18, 2.6, 0.18)
	mast.mesh = bm
	mast.material_override = Palette.emissive(Palette.HULL, 0.6)
	mast.position = Vector3(0, 1.3, 0)
	add_child(mast)

	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.42
	hm.height = 0.84
	hm.radial_segments = 10
	hm.rings = 6
	head.mesh = hm
	_lamp = Palette.emissive(tint, 0.5)
	head.material_override = _lamp
	head.position = Vector3(0, 2.7, 0)
	add_child(head)

	var vane := MeshInstance3D.new()
	var vm := BoxMesh.new()
	vm.size = Vector3(1.5, 0.06, 0.4)
	vane.mesh = vm
	vane.material_override = Palette.emissive(Palette.HULL, 0.35)
	vane.position = Vector3(0.7, 2.1, 0)
	vane.rotation_degrees = Vector3(0, 0, -18)
	add_child(vane)


func _build_slag(tint: Color) -> void:
	# A cluster rather than an object: five lumps at descending heat, so the
	# thing reads as spoil that was poured rather than built.
	for i in range(5):
		var lump := MeshInstance3D.new()
		var lm := SphereMesh.new()
		lm.radius = 0.9 + 0.35 * float(4 - i)
		lm.height = lm.radius * 1.7
		lm.radial_segments = 9
		lm.rings = 6
		lump.mesh = lm
		# Hot at the core, crusted at the edge. The one place in the game a
		# band colour is deliberately overridden: slag is the same temperature
		# whichever band it cooled in.
		var heat := Color(1.0, 0.42 + 0.09 * float(i), 0.16, 1.0)
		lump.material_override = Palette.emissive(heat, 1.6 - 0.28 * float(i))
		var ang := TAU * float(i) / 5.0
		lump.position = Vector3(cos(ang), 0.0, sin(ang)) * (1.6 + 0.5 * float(i))
		add_child(lump)
		if i == 0:
			_lamp = lump.material_override


func _build_sounding(tint: Color) -> void:
	# A plumb line: a tall thin pylon with a weight hanging under the play
	# plane, which is the only thing in the deep that points DOWN. The deep has
	# no down, and that is the joke Meridian is making.
	var pylon := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(0.14, 5.4, 0.14)
	pylon.mesh = pm
	pylon.material_override = Palette.emissive(Palette.HULL, 0.55)
	pylon.position = Vector3(0, 1.4, 0)
	add_child(pylon)

	var bob := MeshInstance3D.new()
	var bmm := SphereMesh.new()
	bmm.radius = 0.5
	bmm.height = 1.4
	bmm.radial_segments = 10
	bmm.rings = 6
	bob.mesh = bmm
	_lamp = Palette.emissive(tint, 0.8)
	bob.material_override = _lamp
	bob.position = Vector3(0, -1.6, 0)
	add_child(bob)

	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 1.5
	tm.outer_radius = 1.7
	ring.mesh = tm
	ring.material_override = Palette.emissive(tint, 0.35)
	ring.position = Vector3(0, 3.6, 0)
	add_child(ring)


func marker_color() -> Color:
	# The optional per-node override HUD's radar loop honours. A signature wears
	# its band's colour: it is a place, and band colour is what "where" means.
	return Palette.band_color(band)


func _process(delta: float) -> void:
	_t += delta
	if _lamp != null:
		# Each kind breathes differently, which is most of what tells them apart
		# at radar range: the relay gutters, the slag pulses slowly like
		# something cooling, the sounding line is steady.
		match kind:
			"relay":
				_lamp.emission_energy_multiplier = 0.20 + maxf(0.0, sin(_t * 5.3)) * 0.5
			"slag":
				_lamp.emission_energy_multiplier = 1.3 + sin(_t * 0.9) * 0.35
			_:
				_lamp.emission_energy_multiplier = 0.7 + sin(_t * 1.6) * 0.15

	var player := get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var d := global_position.distance_to((player as Node3D).global_position)
	if kind == "slag":
		_tick_slag(player, d, delta)
	elif d <= HAIL_RANGE:
		_speak(player)


func _tick_slag(player: Node, d: float, delta: float) -> void:
	# Damage, not a trap: it is visible from further away than it reaches, it
	# does not follow, and leaving ends it. §18's rule that the deep's nastiest
	# thing "can cost you the run; it cannot trap you in one" — this cannot even
	# do the first, at 1.4/s against any hull that got this far.
	if d > SLAG_RANGE:
		return
	if player.has_method("take_hit"):
		# The same door storms use (storm.gd ticks player.take_hit), so hull
		# mitigation, the damage screen and the death path all behave identically.
		player.take_hit(SLAG_DPS * delta)
	if not _spoken:
		_spoken = true
		_toast("SPOIL FIELD — STILL HOT", Palette.THREAT)


func _speak(player: Node) -> void:
	if _spoken:
		return
	_spoken = true
	if kind == "relay":
		# One degraded transmission, once, ever. The session dict DeepSpace uses
		# for post hails is not needed here: a site is despawned with its cell
		# and rebuilt from the same seed, so `_spoken` on the node is exactly
		# "since you last flew past", which is the beat this wants.
		_toast("…CARRIER ONLY. THIS BUOY STOPPED FILING.", Palette.band_color(band))
		return
	# A sounding line pays in the one currency the deep is short of: a bearing
	# you did not have to buy. Free, because it is the reward for having flown
	# to a thing that does not shoot at you.
	var best := _nearest_station()
	if best == Vector3.ZERO:
		_toast("SOUNDING: NO MARK WITHIN REACH", Palette.band_color(band))
		return
	var dir := best - global_position
	# THROUGH THE GLASS. §60: compass_deg is the only converter between the
	# world's angles and the ones a player reads, and a bearing quoted any other
	# way would disagree with the heading readout by 90 degrees.
	_toast("SOUNDING: MARK BEARING %03d, %du OUT" % [
		DeepSpace.compass_deg(dir), int(dir.length())],
		Palette.band_color(band))


func _nearest_station() -> Vector3:
	# Asked of the WORLD, not of the generator: a station that built_plan
	# suppressed for a keep-out is not there, and pointing at it would be the
	# phantom-bay bug with a bearing attached.
	var best := Vector3.ZERO
	var closest := SOUNDING_REACH
	for n in get_tree().get_nodes_in_group("dockable"):
		var p := n as Node3D
		if p == null:
			continue
		var d := global_position.distance_to(p.global_position)
		if d < closest:
			closest = d
			best = p.global_position
	return best


func _toast(text: String, tint: Color) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("show_toast"):
		hud.show_toast(text, tint)
