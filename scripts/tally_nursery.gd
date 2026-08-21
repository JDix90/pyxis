class_name TallyNursery
extends Node3D
# THE TALLY'S NURSERY (§106, Horizon 9 commit 5, v26). Their ground: hulls
# nobody has names for, in numbers. It can be taken, and the mark says plainly
# that it never has been. Held, it is the only thing in Pyxis you can own and
# then have to keep.
#
# THE ONLY LEGEND THAT COSTS A SAVE BYTE, and it is one store: `nursery`, its
# own, because `colony_key` and `mark_key` are the same string format and a
# nursery filed under `colonies` would collide with a hyper structure's claim.
# The research pass found no key shape that both survives `_load_colonies` and
# avoids that collision — see game_state.gd's store comment.
#
# THE RECAPTURE CLOCK IS DERIVED, NOT TRACKED. `taken_at` is a persisted
# played_seconds stamp; which assault is due falls out of it the way a contract
# board falls out of the clock, quantised to a stride so two rebuilds seconds
# apart cannot disagree. The only thing stored beyond the anchor is how many
# waves the pilot has actually turned back, because that is a fact about them
# rather than about the clock.
#
# THEY WAIT FOR YOU (S5). An assault only forms while the player is in this
# system: arriving to find one mid-form is the encounter, and a nursery
# besieged by nobody in an empty system would be a clock running down on a
# player who could not have known. Fleeing or dying loses the ground; the
# Tally take it back, the clock restarts, and the record of what you held does
# not reset.
#
# WHAT IT PAYS IS THE GROUND ITSELF. No credits, no goods, no income term —
# what the nursery buys is a jump anchor at a depth nothing else reaches, and
# the anchor exists only while it is held (§64/S4: held, not owned). The day
# the Tally take it back, the door into the deep closes with it.
#
# JOINS GROUP "legend" (§103's shared rung), and the wardens it stands over
# join "hostiles" like every other fighter.

const TAKE_RANGE := 22.0
const TAKE_TIME := 9.0
const DECAY_RATE := 0.35
# How near the player must be for an assault to form. Generous: the point is
# that you are HERE when they come, not that you are parked on the hull.
const HOLD_RANGE := 320.0
# What stands over an unclaimed nursery. Above the hyper wardens (2.6 / 2.4) —
# the Tally posts more on ground it counts than the Quiet posts on an
# instrument — and the count is what the plate means by "in numbers".
const KEEPER_COUNT := 5
const KEEPER_DIFFICULTY := 2.8
const KEEPER_HP_SCALE := 2.6
const KEEPER_STANDOFF := 16.0
const ASSAULT_STANDOFF := 90.0

const TAKEN_LINE := "IT IS YOURS. NOBODY HAS HELD THIS. THEY WILL COME BACK FOR IT, AND THEY WILL KEEP COMING."
const LOST_LINE := "THEY HAVE IT AGAIN. THEY COUNTED WHAT IT COST THEM, THE WAY THEY COUNT EVERYTHING."

# Identity, set by the spawner before add_child — every spawner's contract.
var owns_mark := ""

var _holding := false
var _progress := 0.0
var _t := 0.0
var _keepers_woken := false
var _assault_index := -1
var _assault: Array = []
var _core_mat: StandardMaterial3D


func _ready() -> void:
	add_to_group("legend")
	_build_mesh()


func is_held() -> bool:
	return GameState.holds_nursery() and GameState.nursery_key() == owns_mark


func _build_mesh() -> void:
	# A cluster, not a structure: a dozen hulls in a shape nobody designed,
	# around something in the middle that the mark does not explain and neither
	# does this file.
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 3.2
	sm.height = 6.4
	core.mesh = sm
	_core_mat = Palette.emissive(FactionDB.tint_of("unknown_a"), 1.1)
	core.material_override = _core_mat
	add_child(core)
	for i in range(12):
		var hull := MeshInstance3D.new()
		var pm := PrismMesh.new()
		pm.size = Vector3(1.8, 0.7, 4.2)
		hull.mesh = pm
		var a := TAU * float(i) / 12.0
		var r := 9.0 + float(i % 3) * 3.5
		hull.position = Vector3(cos(a) * r, sin(float(i) * 1.3) * 3.0, sin(a) * r)
		hull.rotation.y = -a
		hull.material_override = Palette.matte(Color(0.14, 0.14, 0.13))
		add_child(hull)


func _process(delta: float) -> void:
	_t += delta
	if _core_mat:
		# Bone-white and counting. Steady once it is yours; otherwise it ticks.
		_core_mat.emission_energy_multiplier = 1.3 if is_held() \
			else 0.9 + absf(sin(_t * 0.9)) * 0.8
	if not _holding and _progress > 0.0:
		_progress = maxf(_progress - DECAY_RATE * delta, 0.0)
		_sync_gauge()
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return
	var d := global_position.distance_to(p.global_position)
	if not is_held():
		# UNTAKEN GROUND IS HELD GROUND. The keepers wake on approach, the
		# warden pattern — and gated on the PERSISTED hold rather than a session
		# flag, so a colour-vision rebuild cannot hand the player a free run at
		# an empty nursery.
		if not _keepers_woken and d <= HOLD_RANGE:
			_wake_keepers()
		return
	_tick_assault(delta, d)


func keepers_standing() -> int:
	var n := 0
	for k_v in get_tree().get_nodes_in_group("hostiles"):
		var k := k_v as Node3D
		if not is_instance_valid(k) or not k.has_meta("nursery_keeper"):
			continue
		if String(k.get_meta("nursery_keeper")) != owns_mark:
			continue
		if k.has_method("is_dying") and k.is_dying():
			continue
		n += 1
	return n


func is_locked() -> bool:
	return keepers_standing() > 0


func _wake_keepers() -> void:
	_keepers_woken = true
	var parent := get_parent()
	if parent == null:
		return
	for i in range(KEEPER_COUNT):
		var k := _spawn_tally(parent, TAU * float(i) / float(KEEPER_COUNT),
			KEEPER_STANDOFF)
		k.designation = "TALLY KEEPER — IT IS COUNTING"


func _spawn_tally(parent: Node3D, angle: float, radius: float) -> Hostile:
	var h := Hostile.new()
	# The Tally's own flag, with the Tally's own tell: no leash. It does not
	# lose you, it does not give up, and the only way it stops is if you stop
	# it — deep_space.gd's rule, and the reason this ground is worth a plate.
	h.faction = "unknown_a"
	h.difficulty = KEEPER_DIFFICULTY
	h.hp_scale = KEEPER_HP_SCALE
	h.despawn_radius = 0.0
	h.set_meta("nursery_keeper", owns_mark)
	parent.add_child(h)
	h.global_position = global_position \
		+ Vector3(cos(angle) * radius, 0.0, sin(angle) * radius)
	return h


func _tick_assault(_delta: float, player_distance: float) -> void:
	# THEY WAIT FOR YOU. The wave index runs off the clock whatever the player
	# is doing, but it only FORMS while they are here — a siege nobody could
	# have attended is a loss nobody could have prevented.
	if player_distance > HOLD_RANGE:
		return
	var due := GameState.nursery_wave_index()
	if due > _assault_index:
		_form_assault(due)
		return
	if _assault.is_empty():
		return
	var standing := 0
	for a_v in _assault:
		var a := a_v as Node3D
		if is_instance_valid(a) and not (a.has_method("is_dying") and a.is_dying()):
			standing += 1
	if standing > 0:
		return
	# THE WAVE IS TURNED BACK, and the clock restarts from the victory rather
	# than from the founding — otherwise the index runs away while the player is
	# busy winning and the next assault arrives already overdue, several at once.
	_assault.clear()
	GameState.note_nursery_wave_turned()
	# AND THE INDEX FOLLOWS THE CLOCK BACK DOWN. note_nursery_wave_turned
	# restamps taken_at, so the derived index returns to 0 -- leaving
	# _assault_index at the wave just fought would make the comparison below
	# false forever and the siege would simply stop, which is the one thing
	# this legend must never do.
	_assault_index = GameState.nursery_wave_index()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_toast("THE GROUND IS STILL YOURS — %d TURNED BACK"
			% GameState.nursery_waves_turned(), Palette.GOLD)


func _form_assault(index: int) -> void:
	_assault_index = index
	_assault.clear()
	var parent := get_parent()
	if parent == null:
		return
	# SIZE COMES FROM THE RECORD, NOT THE CLOCK. Turning a wave back restarts
	# the clock (or the next one arrives already overdue), which sends the
	# derived index back to zero -- so sizing off the index would mean every
	# wave forever was the first one. "In increasing numbers" is a fact about
	# what the pilot has survived, and that is the number the store keeps.
	var n := GameState.nursery_wave_size(GameState.nursery_waves_turned())
	for i in range(n):
		var a := _spawn_tally(parent, TAU * float(i) / float(n), ASSAULT_STANDOFF)
		a.designation = "TALLY — COMING BACK FOR IT"
		_assault.append(a)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_broadcast("THEY ARE COMING BACK FOR IT",
			"%d HULLS, INBOUND. THEY DO NOT NEGOTIATE AND THEY DO NOT STOP COUNTING." % n,
			FactionDB.tint_of("unknown_a"))
	Sfx.play("breach", -10.0, 0.7)


func besieged() -> bool:
	# Whether an assault is FORMED AND STANDING right now. This is the whole of
	# what "fleeing loses it" measures: leaving with the ground quiet is a
	# supply run, and a nursery that reverted every time the pilot went home to
	# sell would be a thing nobody could keep rather than a thing that costs
	# something to keep.
	if not is_held():
		return false
	for a_v in _assault:
		var a := a_v as Node3D
		if is_instance_valid(a) and not (a.has_method("is_dying") and a.is_dying()):
			return true
	return false


func abandon_if_besieged() -> bool:
	# S5, and the one line Main has to call. Leaving the system while they are
	# on the ground is losing it -- the assault does not follow, and a siege the
	# defender walked out of is a siege the defender lost.
	if not besieged():
		return false
	lose_the_ground()
	return true


func lose_the_ground() -> void:
	# The ground reverts, the jump anchor closes with it, and the keepers come
	# back the next time somebody comes near.
	if not is_held():
		return
	GameState.release_nursery()
	_keepers_woken = false
	_assault_index = -1
	_assault.clear()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_broadcast("THE TALLY'S NURSERY — LOST", LOST_LINE,
			FactionDB.tint_of("unknown_a"))


func pick_anchor() -> Vector3:
	return global_position


func _player_in_range() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	return p != null and global_position.distance_to(p.global_position) <= TAKE_RANGE


func _approach() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("command_move"):
		p.command_move(global_position + Vector3(TAKE_RANGE * 0.6, 0.0, 0.0))


func on_tapped() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	FX.ring_pulse(get_parent(), pick_anchor(), FactionDB.tint_of("unknown_a"),
		4.0, 0.8)
	if hud:
		if is_held():
			hud.prompt("THE NURSERY — YOURS. %d WAVES TURNED BACK. THEY ARE NOT FINISHED."
				% GameState.nursery_waves_turned())
		elif is_locked():
			hud.prompt("THE NURSERY — %d KEEPERS STILL COUNTING. CLEAR THEM TO TAKE THE GROUND."
				% keepers_standing())
		else:
			hud.prompt("THE NURSERY — NOBODY HAS TAKEN THIS. HOLD TO TAKE IT.")
	if not _player_in_range():
		_approach()


func hold_begin() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if is_held():
		if hud:
			hud.prompt("THE NURSERY — YOURS ALREADY. KEEPING IT IS THE PART THAT COSTS.")
		return
	if is_locked():
		if hud:
			hud.prompt("THE NURSERY — %d KEEPERS STILL COUNTING. CLEAR THEM TO TAKE THE GROUND."
				% keepers_standing())
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
	if is_locked() or not _player_in_range():
		hold_release()
		return
	_progress += delta / TAKE_TIME
	_sync_gauge()
	if _progress >= 1.0:
		_take()


func _sync_gauge() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(_progress if _progress > 0.001 else -1.0,
			"TAKING THE GROUND")


func _take() -> void:
	_holding = false
	_progress = 0.0
	# THE POSITION IS PERSISTED AT THE TAKING, the colony's rule: what the save
	# holds is where the pilot actually stood, not a recipe for recomputing it.
	GameState.take_nursery(owns_mark, global_position.x, global_position.z)
	# THE TAKING IS NOT THE FIRST ASSAULT. _assault_index starts at -1 so a
	# nursery rebuilt while a wave is overdue forms it on the first tick -- you
	# come back and they are there. But at the MOMENT of taking the due index is
	# 0, and -1 would make that "overdue" and summon a wave on the same frame
	# the ground changed hands. Pinned to the current index instead: the first
	# assault is the next one.
	_assault_index = GameState.nursery_wave_index()
	# The mark is NOT spent. Holding is not consuming, and the day the Tally
	# take it back the plate has to still read.
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(-1.0)
		hud.show_broadcast("THE TALLY'S NURSERY — TAKEN", TAKEN_LINE,
			FactionDB.tint_of("unknown_a"))
	Sfx.play("breach", -5.0, 0.8)
	FX.shockwave(get_parent(), global_position, Palette.GOLD, 26.0, 1.2)
	if _core_mat:
		_core_mat.albedo_color = Palette.AMBER
