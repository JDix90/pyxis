class_name Procession
extends Node3D
# THE PROCESSION'S END (§105, Horizon 9 commit 5). A drifting formation of
# dead ships in perfect order, every one facing the charted side. Nothing to
# crack, nothing to mine, nothing to fight. You can read the hulls, and you
# can leave something. That is all there is, and the design is that it pays
# NOTHING — in a set of ten legends where nine of them give, one that only
# asks is what keeps the others from reading as a loot table.
#
# THE NAMES ARE THE ATTACHMENT. Directive 9's page 6 ships as one clause —
# "ATTACHED: vessels known to have filed after the effective date" — and a
# margin note counting nine names the reader has met two of. Those names did
# not exist anywhere in the game until this commit; they are drafted and
# approved in docs/THE-NINE-NAMES-DRAFT.md and carried here verbatim.
#
# SEVEN OF THE NINE ARE HERE. The eighth is THE LAST RETURN's evacuation
# tender, standing past the last band edge where the player has already read
# it. The ninth is the rival — "a hull in a livery nobody registered, last
# seen heading out, still filing" — whose wreck lies in PYX-01's band 5, not
# in this formation. Per N1 the list names VESSELS and never pilots, and the
# rival's hull is absent rather than named: a player who has read the wreck's
# log knows exactly which hull is missing from the line, and nobody ever says
# it. Two horizons of deliberate anonymity are not spent for a caption.
#
# READ THEM SLOWLY, AND THE INTERFACE MEANS IT. Each hull answers a tap with
# its attachment entry on the BROADCAST plate, which holds for six seconds and
# has no queue — so a player tapping three hulls in six seconds would erase
# two of them. Rather than working around that, the hull ASKS FIRST
# (hud.broadcast_busy) and refuses with one short line while a plate is up.
# The mark's own instruction is "IF YOU READ THE HULLS, READ THEM SLOWLY", and
# this is that sentence enforced by the only surface that could enforce it.
#
# THE PROMPT LINE IS FOR REFUSALS ONLY. It is a single un-wrapped Label at
# font 16 on a 720-wide design space, so anything much past eighty characters
# runs off both edges — which is why the attachment entries go to the plate
# and only the short terms go to the prompt.
#
# THE HULLS ARE NODES; THE REST IS SCENERY. Only the hulls a player can read
# join the ladder group, spaced well past CameraRig.PICK_PX so choosing one is
# never a lottery. The hundreds the mark counted and stopped counting are a
# MultiMesh — _build_starfield's precedent — because an instance that cannot
# be tapped has no business being a node.
#
# NEVER SPENDS ITS MARK. A formation is a place, the serpent's and the forge's
# rule, and it pays nothing at all, so there is nothing here to farm.

const HULL_SPACING := 24.0
const LATERAL := 13.0
const READ_RANGE := 16.0
const DEPOSIT_TIME := 3.5
const DECAY_RATE := 1.6
# How many anonymous hulls stand in the line beside the seven. Enough that the
# named ones read as a sample of something much larger, which is what the
# plate's "four hundred and stopped counting" is claiming.
const UNNAMED := 12
const DISTANT := 260
const DISTANT_SPREAD := 900.0

# The attachment, verbatim from the approved draft. Clerical entries, every
# one: the horror is the filing cabinet, not the prose (N2).
const ATTACHMENT := [
	["THE MERIDIAN CLERK",
		"Filed 41 returns after the effective date. Last transmission gave a position, a time, and no complaint."],
	["CONSTANT USAGE",
		"A supply hull. Filed on behalf of four other crews who had no equipment left to file with."],
	["THE PATIENT INSTRUMENT",
		"Filed the same volume nine times. The attachment notes the readings did not agree and does not say what was done about it."],
	["SMALL HOURS",
		"Filed once, at length. The entry is longer than the vessel's entire service record before it."],
	["THE HONEST DEPTH",
		"Refused a recall order in writing. The refusal is attached to the attachment."],
	["WHAT THE LINE FOUND",
		"Filed a sounding with no bottom on it. Marked for review. No reviewer is named."],
	["THE UNCOLLECTED",
		"Filed continuously for eleven years. Every return was received. None was ever read."],
]

const UNNAMED_LINE := "No registry, no attachment, no name on this one. It is pointed home with the rest of them."
const SLOWLY := "READ THEM SLOWLY — ONE HULL AT A TIME."
const NOT_SALVAGE := "NOTHING HERE IS SALVAGE — THE HULLS ARE FULL AND NOBODY HAS TOUCHED THEM."

# Identity, set by the spawner before add_child — every spawner's contract.
var owns_mark := ""

var _hulls: Array = []


class Hull:
	extends Node3D
	# One ship in the line. Untyped back-reference, the serpent's rule: an
	# inner class naming its owner's class_name would be a cycle in a coat.
	var owner_node = null
	var hull_name := ""
	var hull_line := ""

	var _holding := false
	var _progress := 0.0

	func _ready() -> void:
		add_to_group("legend")

	func pick_anchor() -> Vector3:
		return global_position

	func _hud():
		return get_tree().get_first_node_in_group("hud")

	func _in_range() -> bool:
		var p := get_tree().get_first_node_in_group("player")
		return p != null and global_position.distance_to(p.global_position) \
			<= Procession.READ_RANGE

	func _approach() -> void:
		var p := get_tree().get_first_node_in_group("player")
		if p and p.has_method("command_move"):
			p.command_move(global_position + Vector3(Procession.READ_RANGE * 0.6, 0.0, 0.0))

	func on_tapped() -> void:
		# THE ENTRY GOES TO THE PLATE, and the plate is asked first. A hull that
		# spoke over the one before it would make "read them slowly" a sentence
		# the game contradicts every time a player follows it.
		var hud = _hud()
		FX.ring_pulse(get_parent(), global_position, Palette.RIVAL, 2.2, 0.7)
		if hud:
			if hud.has_method("broadcast_busy") and hud.broadcast_busy():
				hud.prompt(Procession.SLOWLY)
			elif hull_name == "":
				hud.show_broadcast("A HULL, POINTED HOME",
					Procession.UNNAMED_LINE, Palette.RIVAL)
			else:
				hud.show_broadcast(hull_name, hull_line, Palette.RIVAL)
		if not _in_range():
			_approach()

	func hold_begin() -> void:
		# The only verb in the formation, and the refusal is the teaching: a
		# player holding on a dead ship means "take something", and this is
		# where the line that answers that belongs.
		if GameState.cargo_used() <= 0:
			var hud_e = _hud()
			if hud_e:
				hud_e.prompt(Procession.NOT_SALVAGE)
			return
		if not _in_range():
			_approach()
			return
		_holding = true

	func hold_release() -> void:
		if not _holding:
			return
		_holding = false
		# An abandoned donation resets whole, the layup's rule: the act is
		# deliberate or it is nothing.
		_progress = 0.0
		var hud = _hud()
		if hud:
			hud.crack_progress(-1.0)

	func hold_tick(delta: float) -> void:
		if not _holding:
			return
		if not _in_range():
			hold_release()
			return
		_progress += delta / Procession.DEPOSIT_TIME
		var hud = _hud()
		if hud:
			hud.crack_progress(_progress if _progress > 0.001 else -1.0,
				"LEAVING THE HOLD — EVERYTHING, FOR NOTHING")
		if _progress >= 1.0:
			_leave_it()

	func _leave_it() -> void:
		_holding = false
		_progress = 0.0
		for good_v in GameState.cargo.keys():
			var n := int(GameState.cargo.get(good_v, 0))
			if n > 0:
				GameState.unload_cargo(String(good_v), n)
		var first := false
		if owner_node != null:
			first = GameState.note_mark_given(String(owner_node.owns_mark))
		var hud = _hud()
		if hud:
			hud.crack_progress(-1.0)
			hud.refresh_cargo()
			# S7 taken: the nomad fleet is named FOR this place. The connection
			# is stated exactly once, here, and never explained.
			hud.show_broadcast("LEFT WITH THE PROCESSION",
				"THEY CARRY THINGS PAST THE END OF WHERE THEY WERE GOING. THAT IS WHAT THE NAME MEANT FIRST.",
				Palette.RIVAL)
		if first:
			GameState.note_log("LEFT SOMETHING WITH THE PROCESSION")
		Sfx.play("equip", -8.0, 0.6)
		FX.ring_pulse(get_parent(), global_position, Palette.RIVAL, 3.0, 0.8)


func _ready() -> void:
	_build_line()
	_build_distant()


func _home_facing() -> float:
	# EVERY ONE OF THEM IS POINTED HOME, which out here means pointed at the
	# system origin — the charted side, the thing they were all trying to reach
	# when they stopped. One angle for the whole formation: they are in perfect
	# order, and perfect order is the detail that makes it frightening.
	var flat := Vector2(global_position.x, global_position.z)
	if flat.length() < 0.001:
		return 0.0
	return atan2(-flat.y, -flat.x)


func _build_line() -> void:
	var face := _home_facing()
	var fwd := Vector3(cos(face), 0.0, sin(face))
	var side := Vector3(-fwd.z, 0.0, fwd.x)
	var total := ATTACHMENT.size() + UNNAMED
	for i in range(total):
		var h := Hull.new()
		h.owner_node = self
		if i < ATTACHMENT.size():
			var entry: Array = ATTACHMENT[i]
			h.hull_name = String(entry[0])
			h.hull_line = String(entry[1])
		_hull_mesh(h, h.hull_name != "")
		add_child(h)
		# A COLUMN, not a cloud. Spaced well past PICK_PX in screen terms so
		# choosing which hull to read is a decision rather than a coin flip,
		# and staggered laterally so the line reads as a formation rather than
		# as a queue. Deterministic from the index: no draw, no stream.
		var lane := float((i % 3) - 1) * LATERAL
		h.position = fwd * (-HULL_SPACING * float(i)) + side * lane \
			+ Vector3(0.0, sin(float(i) * 1.7) * 2.0, 0.0)
		h.rotation.y = -face
		_hulls.append(h)


func _hull_mesh(h: Node3D, named: bool) -> void:
	# Two meshes each: a prow and a spine. Dead ships, unlit — the only thing
	# that separates a named hull from an anonymous one is a dim plate on the
	# flank, which is what the player is reading when they read a hull.
	var body := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(2.4, 0.9, 7.0)
	body.mesh = pm
	body.material_override = Palette.matte(Color(0.09, 0.09, 0.11))
	h.add_child(body)
	if not named:
		return
	var plate := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.3, 0.5, 2.2)
	plate.mesh = bm
	plate.position = Vector3(1.2, 0.3, 0.0)
	plate.material_override = Palette.emissive(Palette.RIVAL, 0.55)
	h.add_child(plate)


func _build_distant() -> void:
	# THE ONES NOBODY FINISHED COUNTING. A MultiMesh, _build_starfield's
	# precedent: these can never be tapped, so they must never be nodes. They
	# are what makes the nineteen readable hulls read as a sample.
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var pm := PrismMesh.new()
	pm.size = Vector3(2.0, 0.8, 6.0)
	pm.material = Palette.matte(Color(0.06, 0.06, 0.08))
	mm.mesh = pm
	mm.instance_count = DISTANT
	var face := _home_facing()
	var basis := Basis(Vector3.UP, -face)
	# A DETERMINISTIC LATTICE, not a roll. Its own arithmetic rather than a
	# seeded stream, because the formation must look identical on every rebuild
	# and nothing here may touch a shared draw.
	for i in range(DISTANT):
		var fi := float(i)
		var pos := Vector3(
			sin(fi * 2.399) * DISTANT_SPREAD,
			sin(fi * 1.117) * 40.0 - 30.0,
			cos(fi * 1.867) * DISTANT_SPREAD - fi * 1.6)
		mm.set_instance_transform(i, Transform3D(basis, pos))
	var mmi := MultiMeshInstance3D.new()
	mmi.multimesh = mm
	add_child(mmi)


func hulls() -> Array:
	return _hulls


func named_hulls() -> Array:
	var out: Array = []
	for h_v in _hulls:
		if String((h_v as Node).get("hull_name")) != "":
			out.append(h_v)
	return out
