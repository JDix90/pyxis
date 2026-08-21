class_name StillnessGround
extends Node3D
# THE STILLNESS' GROUND (§102, Horizon 9 commit 4). The dread legend, and the
# one with no combat in it at all: a volume something else uses, on its own
# schedule, for its own reasons. Enter it and the drives go quiet — a
# becalming, not damage, not EMP — something crosses the far edge of the
# picture, and then the drives return, exactly as the mark promised.
#
# THE STRANGEST FACT IS THE ROSTER FACT: nothing here is attacking you. The
# Stillness is neutral to the surveyor. It is simply passing, and you are
# simply in the way of it — which is why this node spawns nothing into any
# combat group and the harness asserts that emptiness rather than trusting it.
#
# THE GROUND OUTLIVES ITS READING, the layup's posture rather than the
# drift's: the mark spends when the reading is finally carried home, but the
# PLACE stays what it is — every entry becalms, forever. A field that switched
# off after paying would be a cleared room, and the entire design of the
# dangerous three is that the deep does not clear.
#
# JOINS NO GROUP. Not tappable, not scanned, not radar-tiered: the verb here
# is WAIT, and the affordance is the mark's own plate standing beside it —
# "IF YOUR DRIVES GO QUIET, THEY WILL COME BACK. DO NOT BURN. DO NOT
# TRANSMIT. WAIT." The warning is the interface.

# The field. Big enough that the buoy that names it stands INSIDE it — read
# the plate, and the first becalming can begin where you float. That is the
# plate keeping its promise immediately, not an ambush: the promise is that
# they come back.
const RADIUS := 90.0
# The player must actually leave before it can happen again — re-arming at the
# same edge it triggers at would becalm a hull sitting on the boundary twice.
const REARM_RADIUS := 140.0
# How long the drives are down. Long enough to be a passage, short enough that
# WAIT is a bearable instruction the second time.
const PASSAGE_TIME := 9.0
# What the far side pays, once ever: a reading taken while still, in the good
# the archives pay — the band-6 chart data nothing on the charted side sells.
const READING_GOOD := "chart_unsounded"
const READING_UNITS := 4

# Identity, set by the spawner before add_child — every spawner's contract.
var owns_mark := ""

# 0 idle, 1 passage running, 2 passed — waiting for the player to leave.
var _phase := 0
var _t := 0.0
var _shape: Node3D = null
var _dust_mat: StandardMaterial3D


func _ready() -> void:
	_build_mesh()


func _build_mesh() -> void:
	# Almost nothing: a wide, very dim ring of settled dust below the plane.
	# The ground must read as a PLACE without reading as a THING — anything
	# bright enough to aim at would promise a verb this legend does not have.
	var disc := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = RADIUS * 0.82
	tm.outer_radius = RADIUS
	tm.ring_segments = 96
	disc.mesh = tm
	disc.position.y = -3.0
	disc.scale.y = 0.05
	_dust_mat = Palette.emissive(Color(0.30, 0.28, 0.40, 0.10), 0.5)
	_dust_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	disc.material_override = _dust_mat
	add_child(disc)


func _process(delta: float) -> void:
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var flat := p.global_position - global_position
	flat.y = 0.0
	var d := flat.length()
	match _phase:
		0:
			if d <= RADIUS:
				_begin_passage()
		1:
			_t -= delta
			if _t <= 0.0:
				_finish_passage()
		2:
			if d > REARM_RADIUS:
				_phase = 0


func _begin_passage() -> void:
	# THE BECALMING. becalm(), not emp_stun(): no thermal sink shortens this,
	# no tumble, no recovery pulse — see player_ship.gd's field comment for the
	# full argument. The bark is the ship's voice, once ever, from inside.
	_phase = 1
	_t = PASSAGE_TIME
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("becalm"):
		p.becalm(PASSAGE_TIME + 0.5)
	Barks.fire("stillness_passage")
	Sfx.play("hit", -20.0, 0.3)
	_spawn_shape()


func _spawn_shape() -> void:
	# SOMETHING CROSSES THE FAR EDGE OF THE PICTURE. A long dark body, well
	# outside weapon range, crossing the sensor horizon over most of the
	# passage and gone before the drives return. It joins NO group — the radar
	# refuses to tier it because there is nothing to tier: it is a mesh, moving,
	# and that is every fact the ship can collect about it.
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	_shape = Node3D.new()
	var body := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = 4.0
	cm.height = 64.0
	body.mesh = cm
	body.rotation_degrees.z = 90.0
	body.material_override = Palette.matte(Color(0.03, 0.03, 0.05))
	_shape.add_child(body)
	get_parent().add_child(_shape)
	# Perpendicular crossing at ~70u off the hull: from one side of the picture
	# to the other, unhurried. The tween frees the shape itself.
	var side := Vector3(p.global_position.z - global_position.z, 0.0,
		global_position.x - p.global_position.x).normalized()
	if side.length() < 0.5:
		side = Vector3.RIGHT
	_shape.global_position = p.global_position + side * 70.0 \
		+ Vector3(0.0, -1.5, 0.0) - Vector3(side.z, 0.0, -side.x) * 90.0
	var tw := _shape.create_tween()
	tw.tween_property(_shape, "global_position",
		_shape.global_position + Vector3(side.z, 0.0, -side.x) * 180.0,
		PASSAGE_TIME * 0.8)
	tw.tween_callback(_shape.queue_free)


func _finish_passage() -> void:
	# THE DRIVES RETURN, EXACTLY AS THE MARK PROMISED. Quietly: the recovery has
	# no pulse and no toast, because the mark already told the player this would
	# happen and the game believing its own fiction IS the payoff register.
	_phase = 2
	var p := get_tree().get_first_node_in_group("player")
	if p != null and p.has_method("clear_becalm"):
		p.clear_becalm()
	if _shape != null and is_instance_valid(_shape):
		_shape.queue_free()
	_shape = null
	# ON THE FAR SIDE, A READING — once ever, and DEFERRED on a full hold
	# rather than lost: the mark stays unspent and the next passage pays,
	# because the passage is repeatable and the archives' rule (a reading that
	# paid nothing must not burn its stage) holds harder for a reading you
	# cannot choose the moment of.
	if GameState.is_mark_spent(owns_mark):
		return
	var hud := get_tree().get_first_node_in_group("hud")
	if not GameState.can_load(READING_GOOD, READING_UNITS):
		if hud:
			hud.show_toast("NO ROOM FOR THE READING", Palette.THREAT)
		return
	GameState.load_cargo(READING_GOOD, READING_UNITS)
	GameState.note_mark_spent(owns_mark)
	if hud:
		hud.refresh_cargo()
		hud.show_broadcast("ON THE FAR SIDE",
			"The instruments kept working the whole time. The reading is whole, and it is the only proof anything was here.",
			Palette.RIVAL)
	GameState.note_log("A READING, TAKEN WHILE STILL")
	Sfx.play("equip", -9.0, 0.7)
