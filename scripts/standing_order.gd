class_name StandingOrder
extends Node3D
# THE STANDING ORDER (§102, Horizon 9 commit 4). The fight, and it is polite:
# an Authority asset holding ground in a place the Authority says does not
# exist. It hails first, in the warm shipped register. It repeats the
# instruction, exactly as it promises to. Then it fires. Page 4 of Directive 9
# met in person.
#
# THE FLAG AND THE PAINT ARE DIFFERENT THINGS, and that is the raider
# precedent carrying the arc's whole thesis. The asset WEARS Authority teal
# (tint, designation, the hail's letterhead) and FLIES FactionDB.FERAL --
# unflagged automata, hostile to the surveyor -- because mechanically that is
# what it IS: a machine nobody ever told anything, that was never in the
# Authority's books. Killing it therefore pays like the windfall it is and
# moves GSA standing by NOTHING -- Hostile._die docks standing only for
# killing a non-hostile flag, and shooting a GSA-flagged hull here would have
# made the Authority notice, which is the one thing this horizon must never
# do. THE MACHINES DO NOT KNOW, enforced by a faction id.
#
# NOT ApexBoss, deliberately, against the spec table's own suggestion. The
# apex fight IS the survey-engine puzzle -- plates, seals, probes -- and its
# death path charts the next system, wakes main.on_apex_defeated and spawns an
# ApexWreck: three things a station asset must never do, which would have made
# the ride a subclass wearing a const's clothes. The wardens are the honest
# precedent: the deepest guards in the game are already parameter-tuned
# Hostiles, and this is one more, tuned past all of them.
#
# THE STATION JOINS NO GROUP. Its verb until it arms is being spoken to, and
# the asset it launches joins "hostiles" the way every fighter does.

const HAIL_RANGE := 150.0
# The instruction, then the gap in which a pilot can take it, then the repeat,
# then a short arming beat. Generous on purpose: the fight is opt-in by
# STAYING, which is the politeness that makes the kill line land.
const HAIL_GAP := 7.0
const ARM_DELAY := 2.5
# Past the wardens (2.6 / 2.4), the deepest guards in the game -- this is what
# the Authority posts where it pretends there is nothing to guard.
const ASSET_DIFFICULTY := 3.0
const ASSET_HP_SCALE := 6.0

const HAIL_SENDER := "GALACTIC SURVEY AUTHORITY — STATION ASSET"
const HAIL_FIRST := "Registered vessel. This volume is closed to survey by standing directive. Return to the charted side. This instruction will be repeated."
const HAIL_SECOND := "Registered vessel. This volume is closed to survey by standing directive. Return to the charted side."

# Identity, set by the spawner before add_child — every spawner's contract.
var owns_mark := ""

# 0 dormant, 1 hailed once, 2 hailed twice (arming), 3 armed and watching,
# 4 finished — silenced, or torn down.
var _phase := 0
var _t := 0.0
var _asset: Node3D = null
var _lamp_mat: StandardMaterial3D
var _tt := 0.0


func _ready() -> void:
	_build_mesh()


func _build_mesh() -> void:
	# An Authority pylon in Authority teal, in perfect repair. Out here, the
	# maintenance is the horror: somebody's budget line still covers this.
	var teal := FactionDB.tint_of("gsa")
	var spine := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 1.4
	cm.height = 22.0
	spine.mesh = cm
	spine.position.y = 11.0
	spine.material_override = Palette.emissive(Color(0.10, 0.12, 0.13), 0.5)
	add_child(spine)
	var lamp := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.3
	sm.height = 2.6
	lamp.mesh = sm
	lamp.position.y = 23.0
	_lamp_mat = Palette.emissive(teal, 1.8)
	lamp.material_override = _lamp_mat
	add_child(lamp)


func _process(delta: float) -> void:
	_tt += delta
	if _lamp_mat and _phase < 4:
		# A service cadence, not a warning: the steady double-blink of an
		# instrument that has never once malfunctioned.
		_lamp_mat.emission_energy_multiplier = \
			2.2 if fmod(_tt, 2.0) < 0.25 or fmod(_tt, 2.0) < 0.65 and fmod(_tt, 2.0) > 0.4 \
			else 1.2
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var d := global_position.distance_to(p.global_position)
	match _phase:
		0:
			if d <= HAIL_RANGE:
				_hail(HAIL_FIRST)
				_phase = 1
				_t = HAIL_GAP
		1:
			_t -= delta
			if d > HAIL_RANGE * 1.6:
				# The pilot took the instruction. The asset holds its ground and
				# holds no grudge -- it starts over from the top next time,
				# because nobody ever told it anything, including that this
				# happened.
				_phase = 0
			elif _t <= 0.0:
				_hail(HAIL_SECOND)
				_phase = 2
				_t = ARM_DELAY
		2:
			_t -= delta
			if _t <= 0.0:
				_arm()
		3:
			_check_silenced()


func _hail(body: String) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_broadcast(HAIL_SENDER, body, FactionDB.tint_of("gsa"))
	Sfx.play("equip", -12.0, 1.1)


func _arm() -> void:
	# THE INSTRUCTION HAS BEEN GIVEN TWICE. Now it fires — the asset launches,
	# and from here it is an ordinary boss-scale fight the combat stack already
	# knows how to have.
	_phase = 3
	var parent := get_parent()
	if parent == null:
		return
	var a := Hostile.new()
	a.faction = FactionDB.FERAL
	a.difficulty = ASSET_DIFFICULTY
	a.hp_scale = ASSET_HP_SCALE
	a.tint = FactionDB.tint_of("gsa")
	a.designation = "GSA STATION ASSET — IT WAS NOT RECALLED"
	# NO LEASH, the warden rule: an asset that gave up at range would let the
	# player kite it off its post and walk in behind it.
	a.despawn_radius = 0.0
	a.set_meta("standing_order", owns_mark)
	parent.add_child(a)
	a.global_position = global_position + Vector3(6.0, 0.0, 6.0)
	_asset = a
	if _lamp_mat:
		_lamp_mat.emission_energy_multiplier = 0.4
	Sfx.play("breach", -10.0, 1.3)


func _check_silenced() -> void:
	# Watches through is_dying rather than through freed-ness: the dying node
	# persists through its staged death FX, while a teardown (warp) frees the
	# asset and this station in the same sweep -- so an invalid reference here
	# means the WORLD ended, not the fight, and must spend nothing.
	if _asset == null or not is_instance_valid(_asset):
		_phase = 4
		return
	if not (_asset.has_method("is_dying") and _asset.is_dying()):
		return
	_phase = 4
	# THE KILL LINE IS THE ARC'S THESIS, plainly. The mark spends -- an asset
	# silenced does not re-post -- and GSA standing has not moved one point,
	# which the harness asserts rather than trusts: nobody reports this fight,
	# because nobody knows the asset existed to lose it.
	GameState.note_mark_spent(owns_mark)
	GameState.note_log("SILENCED THE STANDING ORDER")
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_broadcast("THE STANDING ORDER — SILENCED",
			"IT WAS DOING ITS JOB. IT WAS ALWAYS JUST DOING ITS JOB.",
			FactionDB.tint_of("gsa"))
	if _lamp_mat:
		_lamp_mat.emission_energy_multiplier = 0.0
