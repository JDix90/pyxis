class_name HyperStructure
extends Node3D
# AN INSTRUMENT THE SIZE OF A MOON (v20, Hunt stage 6). Three to five per
# system, past 1600u, placed by SystemDB.hyper_positions on its own salted
# stream. Clear its wardens and it becomes a Colony: a place you own, and a
# place the chart can jump you to.
#
# FOUND WITH YOUR EYES, AND NOTHING ELSE. No radar group, no intel channel, no
# chart hint — the discovery pillar, and the one rule this file must never
# quietly break by joining a scanned group for convenience.
#
# WHICH IS WHY IT IS ENORMOUS. The spec said "findable visually at ~150u", and
# that number does not survive its own arithmetic: 3-5 objects at 150u cover
# 0.7% of the 1600-4200u annulus, and a systematic sweep is the better part of
# eight hours. It also re-creates the exact problem the intel dossier (§42) was
# built to solve — the apex, WITH six intel channels, sits in a search space
# ~80x smaller. So the concept survives and the number moved: this silhouette
# reads at ~1000u, which makes the same sweep about seventy minutes. An
# expedition, not a lottery. SILHOUETTE_SPAN is what buys that, and it is
# asserted rather than eyeballed.
#
# ALWAYS PRESENT, like the apex. Built by SystemBuilder at load rather than
# streamed by cells, because a thing whose whole job is to be seen from a
# thousand units away must not depend on the finder standing 128u from it.

# The tallest axis of the silhouette. A hyper-structure is 7x the apex's
# apparent size at the same range, which is what "visible at 1000u" costs on a
# 55-degree fov: SILHOUETTE_SPAN / distance must stay above the angular size
# the eye resolves against a starfield.
const SILHOUETTE_SPAN := 140.0
# How near the player must come before the wardens are on station. Generous,
# because the structure is visible from far outside it: you SEE the thing, fly
# to it, and only then discover it is held. LAIR-scale, not ENGAGE-scale.
const WARDEN_WAKE := 260.0
# How near to hold the claim. The structure is enormous, so this is measured
# generously against its own span rather than at a hulk's 5u.
const CLAIM_RANGE := 26.0
const CLAIM_TIME := 6.0
const DECAY_RATE := 0.35
# What stands over an unclaimed instrument. Above band-4 tables: the deepest
# guards in the game are the Quiet's, and these are what the Quiet posts on
# something it does not want opened.
const WARDEN_COUNT := 3
const WARDEN_HP_SCALE := 2.4
const WARDEN_DIFFICULTY := 2.6
const WARDEN_STANDOFF := 11.0

# v22. HOW NEAR BEFORE THE SIGHTING IS RECORDED. Derived from the silhouette
# argument at the top of this file rather than picked: the mesh reads at ~1000u
# on a 55-degree fov, so 900 is inside the range at which a player can honestly
# say they SAW it. Deliberately not WARDEN_WAKE (260) -- the wardens are what
# drives you off, and being driven off is precisely the case where the sighting
# has to survive.
const SIGHT_RANGE := 900.0

# Identity, set by the spawner before add_child — the contract every field in
# this project's spawners uses.
var system_id := ""
var index := -1

var _woken := false
var _holding := false
var _progress := 0.0
var _ring_mat: StandardMaterial3D
var _t := 0.0


func claim_key() -> String:
	return GameState.colony_key(system_id, index)


func designation() -> String:
	return SystemDB.hyper_designation(system_id, index)


func is_claimed() -> bool:
	return GameState.is_colony_claimed(claim_key())


func _ready() -> void:
	# THE ONE GROUP IT JOINS, and it is not a scanned one. `hyper` exists so the
	# harness and the claim ladder can find these; every radar-collected group
	# (apex / dockable / crackable / hostiles / mineable) is deliberately absent,
	# and NOTHING POINTS AT THEM asserts that emptiness rather than trusting it.
	add_to_group("hyper")
	_build_mesh()


func _build_mesh() -> void:
	# Concentric rings on a spine — an armillary read at moon scale. Deliberately
	# NOT band paint: the deep's band colours mean "how far out", and this thing
	# is a landmark rather than a depth reading. It takes the family's own light.
	var tint := Palette.AMBER if is_claimed() else Palette.HULL

	var spine := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 1.8
	sm.bottom_radius = 1.8
	sm.height = SILHOUETTE_SPAN
	spine.mesh = sm
	spine.material_override = Palette.emissive(tint, 0.9)
	add_child(spine)

	for i in range(3):
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new()
		var r := SILHOUETTE_SPAN * (0.22 + 0.13 * float(i))
		tm.inner_radius = r - 1.6
		tm.outer_radius = r + 1.6
		tm.ring_segments = 64
		ring.mesh = tm
		ring.rotation_degrees = Vector3(90.0 * float(i % 2), 40.0 * float(i), 0.0)
		ring.material_override = Palette.emissive(tint, 1.3)
		add_child(ring)
		if i == 0:
			_ring_mat = ring.material_override as StandardMaterial3D


func _process(delta: float) -> void:
	_t += delta
	if _ring_mat:
		# A slow turn of the light. Claimed instruments burn steady; unclaimed
		# ones pulse, which is the only tell the silhouette carries at range.
		_ring_mat.emission_energy_multiplier = 1.3 if is_claimed() \
			else 1.0 + sin(_t * 0.8) * 0.6
	if not _holding and _progress > 0.0:
		_progress = maxf(_progress - DECAY_RATE * delta, 0.0)
		_sync_gauge()
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	var d := global_position.distance_to(p.global_position)

	# v22. THE SIGHTING, recorded once ever. Checked BEFORE the claimed/woken
	# early return below, because a structure you found and could not take is
	# the exact case this exists for -- the wardens drive you off, and without
	# this the only thing you learned in fifty minutes of sweeping evaporates.
	# GameState refuses the repeat, so this is one dictionary lookup per frame
	# per instance and no toast after the first.
	if d <= SIGHT_RANGE and system_id != "" and index >= 0:
		if GameState.note_structure_seen(claim_key()):
			var hud := get_tree().get_first_node_in_group("hud")
			if hud != null and hud.has_method("show_toast"):
				hud.show_toast("STRUCTURE SIGHTED — %s · FILED ON THE CHART"
					% designation(), Palette.GOLD)
			Sfx.play("equip", -12.0, 0.85)

	if _woken or is_claimed():
		return
	if d <= WARDEN_WAKE:
		_wake_wardens()


func _wake_wardens() -> void:
	# ON APPROACH, not at load. Three ships per instance times five instances
	# times three systems is forty-five machines nobody is looking at; the apex
	# solved this with a proximity poll and so does this.
	#
	# GATED ON THE PERSISTED CLAIM, never on a session flag. deep_space clears
	# its session sets on every rebuild — and rebuild_visuals() calls
	# _load_system when the player changes a COLOUR setting — so wardens keyed
	# off session state would come back after an accessibility toggle, on a
	# colony founded an hour ago. A CLAIM OUTLIVES A WARP asserts both wipes.
	_woken = true
	var parent := get_parent()
	if parent == null:
		return
	for i in range(WARDEN_COUNT):
		var w := Hostile.new()
		w.faction = "unknown_b"          # the Quiet holds what it does not explain
		w.difficulty = WARDEN_DIFFICULTY
		w.hp_scale = WARDEN_HP_SCALE
		w.tint = Palette.band_color(4)
		w.designation = "WARDEN — IT DOES NOT ANSWER"
		# NO LEASH, the deep-post rule: a warden that gave up at 140u would let
		# the player kite it off the instrument and walk in behind it.
		w.despawn_radius = 0.0
		w.set_meta("warden_key", claim_key())
		parent.add_child(w)
		var a := TAU * float(i) / float(WARDEN_COUNT)
		w.global_position = global_position \
			+ Vector3(cos(a) * WARDEN_STANDOFF, 0.0, sin(a) * WARDEN_STANDOFF)


func wardens_standing() -> int:
	var n := 0
	for w_v in get_tree().get_nodes_in_group("hostiles"):
		var w := w_v as Node3D
		if not is_instance_valid(w) or not w.has_meta("warden_key"):
			continue
		if String(w.get_meta("warden_key")) != claim_key():
			continue
		if w.has_method("is_dying") and w.is_dying():
			continue
		n += 1
	return n


func is_locked() -> bool:
	return wardens_standing() > 0


func pick_anchor() -> Vector3:
	return global_position


func _player_in_range() -> bool:
	var p := get_tree().get_first_node_in_group("player")
	return p != null and global_position.distance_to(p.global_position) <= CLAIM_RANGE


func hold_begin() -> void:
	if is_claimed():
		return
	if is_locked():
		# THE REFUSAL SAYS WHAT TO DO ABOUT IT, and names the count — §58's copy
		# rule, and the reason a locked seam prompt exists rather than a silent
		# no-op. A refusal the player cannot read is a bug report.
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			hud.prompt("%d WARDEN(S) STILL STANDING — CLEAR THEM TO FOUND THIS COLONY"
				% wardens_standing())
		return
	if not _player_in_range():
		_approach()
		return
	_holding = true


func on_tapped() -> void:
	# v22 (88). THE INVITATION. The claim hold was wired from the day these
	# shipped and the playtest still reported "no way to interact" -- because a
	# player who finds a 140-unit monument CLICKS it, and nothing answered.
	# The tap states the terms (58: which refusal, what to do about it) and
	# starts the approach; the hold at the base stays the claiming verb.
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		if is_claimed():
			hud.prompt("%s — CLAIMED. THE CHART CARRIES ITS JUMP." % designation())
		elif is_locked():
			hud.prompt("%s — %d WARDEN(S) STANDING. CLEAR THEM, THEN HOLD AT THE BASE TO CLAIM."
				% [designation(), wardens_standing()])
		else:
			hud.prompt("%s — HOLD AT THE BASE TO CLAIM." % designation())
	FX.ring_pulse(get_parent(), pick_anchor(), Palette.GOLD, 3.0, 0.8)
	if not _player_in_range():
		_approach()


func hold_release() -> void:
	_holding = false
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and _progress < 1.0:
		hud.crack_progress(-1.0)


func hold_tick(delta: float) -> void:
	if not _holding or is_claimed():
		return
	if is_locked() or not _player_in_range():
		hold_release()
		return
	_progress += delta / CLAIM_TIME
	_sync_gauge()
	if _progress >= 1.0:
		_found()


func on_tapped() -> void:
	if is_claimed():
		return
	if is_locked():
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			hud.prompt("%d WARDEN(S) STILL STANDING — CLEAR THEM TO FOUND THIS COLONY"
				% wardens_standing())
		return
	if not _player_in_range():
		_approach()


func _approach() -> void:
	var p := get_tree().get_first_node_in_group("player")
	if p and p.has_method("command_move"):
		p.command_move(global_position + Vector3(CLAIM_RANGE * 0.6, 0.0, 0.0))


func _sync_gauge() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(_progress if _progress > 0.001 else -1.0, "FOUNDING")


func _found() -> void:
	# THE POSITION IS PERSISTED AT CLAIM, per instance. A later change to the
	# seed policy, the depth band or the candidate count could otherwise move an
	# instrument out from under a colony that was already founded — and a jump
	# row pointing at empty space is worse than no jump row. What the save holds
	# is where the player actually stood, not a recipe for recomputing it.
	_holding = false
	GameState.claim_colony(claim_key(), global_position.x, global_position.z)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(-1.0)
		hud.show_broadcast("COLONY FOUNDED", "%s is yours. The chart will take you back to it."
			% designation(), Palette.GOLD)
	Sfx.play("breach", -6.0, 0.8)
	FX.shockwave(get_parent(), global_position, Palette.GOLD, 24.0, 1.2)
	if _ring_mat:
		_ring_mat.albedo_color = Palette.AMBER
