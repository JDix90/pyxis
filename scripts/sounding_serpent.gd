class_name SoundingSerpent
extends Node3D
# THE SOUNDING SERPENT (§102, Horizon 9 commit 4). The thing that is alive.
# Everything else in this game is machinery and residue; a living thing is the
# one genuine escalation left, and it must be unmistakably alive: it does not
# strafe, it SWIMS — a segmented body moving through the play plane, taking
# damage per segment, so the fight is about where you are rather than how much
# you shoot.
#
# NEW MOVEMENT, NO NEW AI FRAMEWORK — the spec's own bounds, kept literally.
# The head steers; the body follows the body ahead of it (the whole of the
# "framework"); segments take the player's fire through the same duck-typed
# take_damage every combatant answers, and deal contact damage through the
# same take_hit every hazard uses. Segments join "hostiles" so the radar tiers
# a fight as a fight and every targeting surface works unmodified. The
# controller itself joins NOTHING.
#
# IT LEAVES RATHER THAN DIES (S2, adopted). Silence enough of the body and it
# breaks off — the segments stop answering, the body turns, and it goes back
# down where the line found no bottom. No faction, no flag, no wreck, no
# salvage: nothing in this file pays anything, calls report_kill, or touches a
# ledger, and the harness asserts that emptiness. What it drops is that you
# saw it.
#
# AND THE MARK STAYS LIVE — the one legend that NEVER spends its mark. The
# place stays dangerous instead of becoming a cleared room, and returning is a
# choice you make again every time. build_legend rebuilds it whole on every
# visit, which is not a respawn exploit because it has never once paid.

const SEGMENTS := 7
const SEGMENT_HP := 260.0
# Silencing this many drives it off. A majority of the body, not all of it:
# a fight to the last segment would read as a kill, and it does not die.
const BREAK_AT := 4
const SPACING := 3.4
const SPEED := 6.5
const TURN_RATE := 1.4
# Past this it swims its own water around the mark and takes no interest.
const AGGRO_RANGE := 120.0
const HIT_RADIUS := 2.4
const HIT_DAMAGE := 26.0
const HIT_COOLDOWN := 1.2
# The weave that makes it read as swimming rather than homing.
const WEAVE_HZ := 0.5
const WEAVE_AMP := 14.0
const SEEN_RANGE := 60.0
const LEAVE_TIME := 4.0

# Identity, set by the spawner before add_child — every spawner's contract.
var owns_mark := ""

var _bodies: Array = []
var _hp: Array = []
var _silenced: Array = []
var _heading := 0.0
var _t := 0.0
var _hit_cd := 0.0
var _leaving := false
var _leave_t := 0.0
var _seen := false


class SerpentSegment:
	extends Node3D
	# One vertebra. Untyped back-reference, the class-list rule: an inner class
	# naming its owner's class_name would be a cycle in a trench coat.
	var serpent = null
	var index := 0

	func take_damage(amount: float, attacker: Node3D = null) -> void:
		if serpent != null:
			serpent.segment_hit(index, amount, attacker)

	func fights_the_player() -> bool:
		return serpent != null and serpent.segment_answers(index)

	func is_dying() -> bool:
		# A silenced segment reads as dying to every targeting surface, so
		# auto-fire moves on to the parts that still answer.
		return serpent == null or not serpent.segment_answers(index)

	func marker_color() -> Color:
		return Color(0.36, 0.30, 0.52)

	func pick_anchor() -> Vector3:
		return global_position


func _ready() -> void:
	for i in range(SEGMENTS):
		var seg := SerpentSegment.new()
		seg.serpent = self
		seg.index = i
		var body := MeshInstance3D.new()
		var sm := SphereMesh.new()
		# Tapered: a head you can pick out, a tail that trails.
		var r := 2.0 - 0.14 * float(i)
		sm.radius = r
		sm.height = r * 2.6
		body.mesh = sm
		body.rotation_degrees.x = 90.0
		body.material_override = Palette.emissive(Color(0.13, 0.11, 0.19), 0.6)
		seg.add_child(body)
		seg.add_to_group("hostiles")
		add_child(seg)
		seg.position = Vector3(-SPACING * float(i), 0.0, 0.0)
		_bodies.append(seg)
		_hp.append(SEGMENT_HP)
		_silenced.append(false)


func segments() -> Array:
	return _bodies


func segment_answers(i: int) -> bool:
	return not _leaving and i >= 0 and i < _silenced.size() and not _silenced[i]


func is_leaving() -> bool:
	return _leaving


func answering_count() -> int:
	var n := 0
	for i in range(_silenced.size()):
		if not _silenced[i]:
			n += 1
	return n


func segment_hit(i: int, amount: float, _attacker: Node3D = null) -> void:
	# PAYS NOTHING BY CONSTRUCTION. The attacker is taken for signature
	# compatibility with every weapon path and read for nothing: there is no
	# attribution here because there is no payout, no contract kind, and no
	# standing — it has no faction to shift.
	if _leaving or i < 0 or i >= _hp.size() or _silenced[i]:
		return
	_hp[i] -= amount
	var seg := _bodies[i] as Node3D
	FX.flash(get_parent(), seg.global_position, Color(0.60, 0.50, 0.80), 0.7, 0.1)
	Sfx.play("hit", -11.0, 0.55)
	if _hp[i] <= 0.0:
		_silence(i)


func _silence(i: int) -> void:
	# The segment stops answering: out of the group, dark, inert — not a corpse
	# and not loot, because it is still part of something alive that is about
	# to make a decision.
	_silenced[i] = true
	var seg := _bodies[i] as Node3D
	if seg.is_in_group("hostiles"):
		seg.remove_from_group("hostiles")
	var mesh := seg.get_child(0) as MeshInstance3D
	if mesh:
		mesh.material_override = Palette.matte(Color(0.06, 0.05, 0.09))
	FX.burst(get_parent(), seg.global_position, Color(0.36, 0.30, 0.52),
		18, 3.0, 0.16, 0.5)
	Sfx.play("crack", -9.0, 0.5)
	if SEGMENTS - answering_count() >= BREAK_AT:
		_break_off()


func _break_off() -> void:
	# IT BROKE OFF. Driven off rather than killed: every segment stops
	# answering, the body turns for the deep, and the mark keeps its warning
	# forever. S2's whole argument in one function.
	_leaving = true
	_leave_t = LEAVE_TIME
	for seg_v in _bodies:
		var seg := seg_v as Node3D
		if seg.is_in_group("hostiles"):
			seg.remove_from_group("hostiles")
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_broadcast("IT BROKE OFF",
			"IT IS STILL DOWN THERE. THE MARK STANDS. NOTHING ON THE BOARD, NOTHING TO FILE — WE SAW IT.",
			Palette.RIVAL)
	GameState.note_log("THE SERPENT BROKE OFF — IT IS STILL DOWN THERE")


func _process(delta: float) -> void:
	_t += delta
	_hit_cd = maxf(_hit_cd - delta, 0.0)
	var head := _bodies[0] as Node3D
	var p := get_tree().get_first_node_in_group("player") as Node3D

	# WHERE THE HEAD WANTS TO GO. Its own water by default; the player's
	# position, led by a weave, when they are close enough to be interesting;
	# straight down and away when it has had enough.
	var aim: Vector3
	if _leaving:
		_leave_t -= delta
		aim = head.global_position \
			+ (head.global_position - global_position).normalized() * 50.0 \
			+ Vector3(0.0, -12.0, 0.0)
		if _leave_t <= 0.0:
			queue_free()
			return
	elif p != null and global_position.distance_to(p.global_position) <= AGGRO_RANGE:
		var weave := Vector3(sin(_t * TAU * WEAVE_HZ), 0.0,
			cos(_t * TAU * WEAVE_HZ * 0.73)) * WEAVE_AMP
		aim = p.global_position + weave
		if not _seen and head.global_position.distance_to(p.global_position) <= SEEN_RANGE:
			_seen = true
			Barks.fire("serpent_seen")
	else:
		# Its own water: a slow circuit of the ground it was sounded in.
		aim = global_position + Vector3(sin(_t * 0.22), 0.0, cos(_t * 0.22)) * 40.0

	# THE SWIM. The head turns toward the aim at a bounded rate and always
	# moves at full speed — a serpent never hovers — and every segment closes
	# up on the one ahead along the line between them. That follow rule is the
	# whole of the body's intelligence, and it is what makes the shape read as
	# one animal instead of seven ships in a queue.
	var to_aim := aim - head.global_position
	to_aim.y = 0.0
	if to_aim.length() > 0.5:
		var want := atan2(to_aim.z, to_aim.x)
		var diff := wrapf(want - _heading, -PI, PI)
		_heading += clampf(diff, -TURN_RATE * delta, TURN_RATE * delta)
	head.global_position += Vector3(cos(_heading), 0.0, sin(_heading)) \
		* SPEED * delta
	head.global_position.y = sin(_t * 1.7) * 0.5 + (-3.0 * (LEAVE_TIME - _leave_t) / LEAVE_TIME if _leaving else 0.0)
	head.rotation.y = -_heading

	for i in range(1, _bodies.size()):
		var seg := _bodies[i] as Node3D
		var ahead := _bodies[i - 1] as Node3D
		var back := seg.global_position - ahead.global_position
		back.y = 0.0
		if back.length() < 0.01:
			back = Vector3.LEFT
		seg.global_position = ahead.global_position \
			+ back.normalized() * SPACING
		seg.global_position.y = sin(_t * 1.7 - float(i) * 0.55) * 0.5 \
			+ (head.global_position.y - sin(_t * 1.7) * 0.5)
		seg.rotation.y = atan2(-back.z, -back.x) * -1.0

	# CONTACT. Where you are, not how much you shoot: an answering segment
	# passing through the hull costs shield, on a cooldown so a body-length
	# pass reads as one hit rather than seven.
	if _leaving or p == null or _hit_cd > 0.0:
		return
	for i in range(_bodies.size()):
		if _silenced[i]:
			continue
		var seg2 := _bodies[i] as Node3D
		if seg2.global_position.distance_to(p.global_position) <= HIT_RADIUS:
			if p.has_method("take_hit"):
				p.take_hit(HIT_DAMAGE, seg2)
			_hit_cd = HIT_COOLDOWN
			Sfx.play("hit", -6.0, 0.4)
			break
