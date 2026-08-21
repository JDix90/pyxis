class_name PatternForge
extends Node3D
# THE PATTERN FORGE (§104, Horizon 9 commit 5). A machine that copies. Feed it
# a hull and it prints the pattern; it does not ask whose hull. Nobody built
# it that the network knows of, and the mark says so.
#
# THE VERB IS A JOURNEY, NOT A BUTTON. "Bring it a hull" is taken literally:
# the forge takes the pattern of anything that DIES within FEED_RANGE of it,
# so arming the forge means leading something out to it — or finding the
# ground already occupied and fighting there on purpose. The bed is empty
# until you put something on it, and the tap says so (§58).
#
# THE WING IS THE SHIPPED ESCORT MACHINERY, and finding that was the whole
# return on the research pass. REQUEST ESCORT has flown a ship on the player's
# wing since v18: the station off the shoulder, the guard reach measured from
# the PLAYER, firing only at what `hostile_to_player` says fights the player,
# the ambient HP floor, the staged death, the radar paint. Every hazard a
# friendly armed ship raises was found and paid for there. What a printed wing
# needed was a different spawner and two policies lifted — the courtesy clock
# and the chart-edge release — both flag-gated on `Hostile.printed`.
#
# THEY FLY AN UNREGISTERED PATTERN, and that is the fiction and the mechanism
# in one word. `faction = "printed"` is in no roster, so:
#   - `baseline_attitude` answers 0 → NEUTRAL → `fights_the_player` is false,
#     so the player's guns never auto-target their own wing;
#   - `is_faction` is false, so `shift_faction` no-ops — splashing your own
#     escort with an overcharge costs nothing in standing, which matters
#     because three player weapons sweep the `hostiles` group with no IFF
#     filter by documented design;
#   - `enemies_of` never lists it, so nothing in the world opens on a printed
#     hull unprovoked. They are shot at only once they have fired, which is
#     exactly what "they follow, and when something shoots at you they answer"
#     means when you write it down.
# `marker_color` falls through to the spawner's `tint`, the branch its own
# comment reserves for "a ship that flies no flag at all".
#
# THEY CANNOT LAND THE KILL, and that is deliberate rather than a limitation.
# A printed hull joins `combatants` like every other, so `SKIRMISH_HP_FLOOR`
# clamps what it can take a non-muster target down to — the player still
# lands every killing blow. Drop the wing out of `combatants` and `_die`'s
# `player_kill` goes false on anything they finish: no loot, no contract tick,
# and the world depleting itself without paying anyone. The floor is what
# keeps §51 true with the wing in the sky.
#
# JOINS GROUP "legend" (§103's shared rung). Prints nothing on its own, pays
# nothing, and never spends its mark — a forge is a PLACE, like the serpent's
# ground, so it rebuilds whole on every visit. That is not a farm: escorts are
# not currency, they do not survive a warp, and arming it costs a kill.

const FEED_RANGE := 120.0
const PRINT_RANGE := 14.0
const PRINT_TIME := 5.0
const DECAY_RATE := 0.5
# Three is a wing. They cannot finish anything (the floor), do not survive a
# warp, and die permanently — so the number is about how the sky reads, not
# about damage: one is a straggler, three is somebody flying with you.
const PRINT_COUNT := 3
# WHERE THEY ARRIVE, measured against the one hazard a wing multiplies:
# PlayerShip's overcharge discharge sweeps `hostiles` with no IFF filter at
# OVERCHARGE_RADIUS. Escorts station themselves at ESCORT_FOLLOW (8.0) which
# already clears it, but they are PRINTED here and fly there — so they are
# born outside the blast rather than inside it, and the ring is wide enough
# that the flight in never crosses the player's own nose.
const PRINT_RING := 18.0
# The flag nothing has a row for. Deliberately not in FactionDB: see header.
const PRINTED_FLAG := "printed"

const CONTRACT_LINE := "THEY WILL NOT TAKE ORDERS. THEY WILL NOT TAKE A BEARING. THEY FOLLOW, AND WHEN SOMETHING SHOOTS AT YOU THEY ANSWER. THAT IS ALL IT PRINTS."

# Identity, set by the spawner before add_child — every spawner's contract.
var owns_mark := ""

# The pattern on the bed. SESSION ONLY, and that is the correct lifetime
# rather than a saving: the wing it prints cannot survive a warp either, so a
# pattern that outlived the visit would be a promise the next visit breaks.
var _pattern := {}
# THE HULL CURRENTLY ON WATCH, and the snapshot taken of it WHILE IT WAS
# ALIVE. Both exist because of a defect the first version of this file
# shipped and the sweep caught -- see _watch_the_bed.
var _watch_ref: Node3D = null
var _pending := {}
var _holding := false
var _progress := 0.0
var _t := 0.0
var _wing: Array = []
var _bed_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("legend")
	_build_mesh()


func _build_mesh() -> void:
	# A frame and a bed: two uprights with a flat plate between them, and the
	# plate lights when there is a pattern on it. The one legend whose state
	# the player can read from outside tap range.
	for side in [-1.0, 1.0]:
		var post := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.2, 14.0, 1.2)
		post.mesh = bm
		post.position = Vector3(side * 7.0, 7.0, 0.0)
		post.material_override = Palette.emissive(Color(0.10, 0.09, 0.12), 0.4)
		add_child(post)
	var bed := MeshInstance3D.new()
	var pm := BoxMesh.new()
	pm.size = Vector3(13.0, 0.4, 7.0)
	bed.mesh = pm
	bed.position.y = 3.0
	_bed_mat = Palette.emissive(Palette.RIVAL, 0.3)
	bed.material_override = _bed_mat
	add_child(bed)


func has_pattern() -> bool:
	return not _pattern.is_empty()


func wing_flying() -> int:
	var n := 0
	for w_v in _wing:
		var w := w_v as Node3D
		if is_instance_valid(w) and not (w.has_method("is_dying") and w.is_dying()):
			n += 1
	return n


func _process(delta: float) -> void:
	_t += delta
	if _bed_mat:
		# Dark and cold with nothing on it; breathing once it has a pattern.
		_bed_mat.emission_energy_multiplier = 0.3 if not has_pattern() \
			else 1.2 + sin(_t * 1.1) * 0.5
	if not _holding and _progress > 0.0:
		_progress = maxf(_progress - DECAY_RATE * delta, 0.0)
		_sync_gauge()
	_watch_the_bed()


func _watch_the_bed() -> void:
	# IT DOES NOT ASK WHOSE HULL. Anything that dies in range is a pattern,
	# including a printed hull -- a wing that dies here can be reprinted from
	# its own corpse, which is the machine's whole character and costs nothing
	# to allow.
	#
	# THE SNAPSHOT IS TAKEN WHILE THE HULL IS ALIVE, and that is the shape of
	# this whole function rather than an optimisation. The first version walked
	# the `hostiles` group looking for `is_dying()` -- which can NEVER be true
	# of anything in that group, because Hostile._die removes the node from
	# `hostiles` and `combatants` on its opening two lines, before any frame
	# can observe it. The forge could not have armed once in play, and nothing
	# but a run would have said so: the parser, the static checker and every
	# reading of this file took it for correct.
	#
	# So the forge WATCHES the nearest live hull in range, keeps a copy of what
	# it is, and promotes that copy the moment the hull stops being valid or
	# starts dying. Death is still the trigger; the group is simply not where
	# the answer lives.
	if has_pattern():
		return
	if _watch_ref != null:
		var gone := not is_instance_valid(_watch_ref)
		var dying: bool = not gone and _watch_ref.has_method("is_dying") \
			and _watch_ref.is_dying()
		if gone or dying:
			_watch_ref = null
			if not _pending.is_empty():
				_pattern = _pending
				_pending = {}
				_announce_pattern()
			return
		if global_position.distance_to(_watch_ref.global_position) <= FEED_RANGE:
			return
		# It left without dying. Nothing is owed for that.
		_watch_ref = null
		_pending = {}
	var best: Hostile = null
	var best_d := FEED_RANGE
	for h_v in get_tree().get_nodes_in_group("hostiles"):
		var h := h_v as Hostile
		if h == null or not is_instance_valid(h):
			continue
		if h.has_method("is_dying") and h.is_dying():
			continue
		var d := global_position.distance_to(h.global_position)
		if d <= best_d:
			best_d = d
			best = h
	if best != null:
		_watch_ref = best
		_pending = {
			"difficulty": best.difficulty,
			"hp_scale": best.hp_scale,
			"tint": best.marker_color(),
			"designation": String(best.designation),
		}


func _announce_pattern() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_broadcast("THE FORGE — PATTERN TAKEN",
			"IT DID NOT ASK WHOSE HULL. " + CONTRACT_LINE, Palette.RIVAL)
	Sfx.play("equip", -8.0, 0.6)
	FX.ring_pulse(get_parent(), global_position + Vector3(0.0, 3.0, 0.0),
		Palette.RIVAL, 4.0, 0.9)


func pick_anchor() -> Vector3:
	return global_position + Vector3(0.0, 3.0, 0.0)


func _player_in_range() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	return p != null and global_position.distance_to(p.global_position) <= PRINT_RANGE


func _approach() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("command_move"):
		p.command_move(global_position + Vector3(PRINT_RANGE * 0.6, 0.0, 0.0))


func on_tapped() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	FX.ring_pulse(get_parent(), pick_anchor(), Palette.RIVAL, 3.0, 0.8)
	if hud:
		if not has_pattern():
			hud.prompt("THE FORGE — THE BED IS EMPTY. IT COPIES WHAT DIES HERE: BRING IT A HULL.")
		elif wing_flying() > 0:
			hud.prompt("THE FORGE — IT WILL NOT PRINT OVER A WING THAT IS STILL FLYING (%d UP)." % wing_flying())
		else:
			hud.prompt("THE FORGE — A PATTERN IS ON THE BED. HOLD TO PRINT %d. THEY TAKE NO ORDERS." % PRINT_COUNT)
	if not _player_in_range():
		_approach()


func hold_begin() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if not has_pattern():
		if hud:
			hud.prompt("THE FORGE — THE BED IS EMPTY. IT COPIES WHAT DIES HERE: BRING IT A HULL.")
		return
	if wing_flying() > 0:
		if hud:
			hud.prompt("THE FORGE — IT WILL NOT PRINT OVER A WING THAT IS STILL FLYING (%d UP)." % wing_flying())
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
	_progress += delta / PRINT_TIME
	_sync_gauge()
	if _progress >= 1.0:
		_print_wing()


func _sync_gauge() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(_progress if _progress > 0.001 else -1.0, "PRINTING THE PATTERN")


func _print_wing() -> void:
	_holding = false
	_progress = 0.0
	var parent := get_parent()
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if parent == null or p == null:
		return
	_wing.clear()
	for i in range(PRINT_COUNT):
		var e := Hostile.new()
		# THE PATTERN, copied. difficulty and hp_scale come off the hull that
		# died here, so feeding the forge a warden prints wardens and feeding
		# it a picket prints pickets -- the machine's promise, kept literally.
		e.difficulty = float(_pattern.get("difficulty", 1.0))
		e.hp_scale = float(_pattern.get("hp_scale", 1.0))
		e.faction = PRINTED_FLAG
		e.tint = _pattern.get("tint", Palette.RIVAL)
		e.designation = "PRINTED — %s" % String(_pattern.get("designation", "NO PATTERN ON FILE"))
		# Flag BEFORE add_child, every spawner's contract -- and load-bearing
		# here beyond convention: _ready and the first _process both read it,
		# and a hull that ran one frame unprinted would station-keep at a home
		# it never had.
		e.printed = true
		# NO LEASH. A printed hull has no post to give up on and no route to
		# go back to; despawn_radius is measured from a home this class does
		# not have out here.
		e.despawn_radius = 0.0
		# PARENTED TO THE CONTAINER, never to the player or to this node. S3
		# ("they will not follow you through a jump") is structural exactly
		# once: _load_system frees every child of system_root, and the forge is
		# a child of it, so `get_parent()` is the one correct answer.
		parent.add_child(e)
		var a := TAU * float(i) / float(PRINT_COUNT)
		e.global_position = p.global_position \
			+ Vector3(cos(a) * PRINT_RING, 0.0, sin(a) * PRINT_RING)
		e.begin_escort(p)
		_wing.append(e)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(-1.0)
		hud.show_broadcast("THE FORGE — %d PRINTED" % PRINT_COUNT,
			"THEY ARE PRINTED FOR THIS GROUND. THEY WILL NOT FOLLOW YOU THROUGH A JUMP, AND NOTHING WE HAVE TRIED HAS EVER PERSUADED ONE TO.",
			Palette.RIVAL)
	# THE PATTERN IS SPENT WITH THE PRINTING. The bed goes cold, so a second
	# wing costs a second hull -- the forge is a place you come back to, never
	# a button you hold twice.
	_pattern = {}
	GameState.note_log("THE FORGE PRINTED A WING")
	Sfx.play("breach", -8.0, 1.2)
	FX.shockwave(parent, global_position, Palette.RIVAL, 16.0, 1.0)
