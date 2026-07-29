class_name Derelict
extends Node3D
# The set-piece: a dead hulk still transmitting. Fly into range, hold on it to
# breach the hull, then ride the salvage vortex. This is the session climax —
# the one moment tuned to be spectacular rather than merely responsive.
#
# --- FEEL CONSTANTS ---
const CRACK_RANGE := 6.5
# Where the door is, in hull-local space. A const because DeepSpace has to derive
# the breach point ANALYTICALLY when planning guard posts: `breach_point` is set
# in _ready, which fires from add_child — before the spawner assigns
# global_position — so reading it at plan time gives the container's origin. Same
# trap as Hostile._home. One place owns this offset.
const BEACON_LOCAL := Vector3(0, 1.3, -6.6)
const DECAY_RATE := 1.6
const VORTEX_TIME := 2.6
const LOOT_WAVE_INTERVAL := 0.09
# The colour of a wreck that still has power in it.
const TRAP_TELL := Color(0.55, 0.85, 1.0)

# Set by SystemBuilder from the system definition.
var crack_time := 1.8
var loot_total := 70

# Whether cracking this hull counts as SURVEYING THE SYSTEM — charting the next
# one and waking the apex engine. True for the one authored hulk a system is
# built around; DeepSpace sets it false on the drifting wrecks out in the expanse,
# which are salvage and nothing else. Defaults to the behaviour that shipped, so
# every existing derelict is unchanged.
var counts_as_survey := true

# Whether breaching this hull ALSO advances a salvage contract. Split from
# `counts_as_survey` deliberately: charting the next system and waking the apex
# are the things a deep hulk must not do — but you did breach a hull, and the
# contract that asks you to breach one should say so.
var counts_for_contract := true

# Set by DeepSpace on a rigged wreck; empty on every authored one. See
# DeepSpace.TRAP_* for what is in it and why it is seeded rather than rolled.
var trap := {}

var breach_point := Vector3.ZERO

var _progress := 0.0
var _holding := false
var _cracked := false

# Which expanse cell this hull belongs to, and whether it has already been
# opened this session. Charted derelicts leave `deep` false and are untouched by
# any of it — their persistence is `GameState.breached`, which is a different
# guarantee entirely. See DeepSpace._cracked for why a deep hulk needs one.
var cell := Vector2i.ZERO
var deep := false
var cracked := false
var _hull_parts: Array[MeshInstance3D] = []
var _beacon: MeshInstance3D
var _beacon_mat: StandardMaterial3D
var _ring: MeshInstance3D
var _ring_mat: StandardMaterial3D
var _crack_player: AudioStreamPlayer
var _in_range_last := false


func _ready() -> void:
	add_to_group("crackable")
	_build_mesh()
	_build_beacon()
	# A hull opened earlier this session comes back open. The mast beside it has
	# always done this (SurveyMast.surveyed) and so has the post standing over it
	# (_build_post's _cleared check) — the hull was the one of the three that
	# forgot, which made it an unbounded farm reachable by flying 192u out and
	# back. It is spawned already breached rather than re-breached: _breach is an
	# event with a vortex, a shockwave and a payout in it.
	if cracked:
		_cracked = true
		remove_from_group("crackable")
		_beacon.visible = false
		_ring.visible = false

	_crack_player = Sfx.attached_loop(self, "crack", -6.0)


func pick_anchor() -> Vector3:
	return breach_point


func is_cracked() -> bool:
	return _cracked


func _build_mesh() -> void:
	for part in [
		{"size": Vector3(2.2, 2.0, 14.0), "pos": Vector3.ZERO},
		{"size": Vector3(7.0, 1.2, 2.5), "pos": Vector3(0, 0.4, -3.5)},
		{"size": Vector3(1.4, 3.5, 3.0), "pos": Vector3(0, 1.0, 4.0)},
		{"size": Vector3(1.0, 1.0, 5.0), "pos": Vector3(2.4, 0.2, -3.5)},
		{"size": Vector3(1.0, 1.0, 5.0), "pos": Vector3(-2.4, 0.2, -3.5)},
	]:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part["size"]
		mi.mesh = bm
		mi.position = part["pos"]
		mi.material_override = Palette.matte(Color(0.1, 0.1, 0.12))
		add_child(mi)
		_hull_parts.append(mi)

	for i in range(11):
		var w := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.12, 0.12, 0.3)
		w.mesh = wm
		w.position = Vector3(1.15, randf_range(-0.4, 0.6), randf_range(-6.0, 6.0))
		w.material_override = Palette.emissive(Palette.AMBER, 2.0)
		add_child(w)


func _build_beacon() -> void:
	# Pulsing magenta breach marker — the "tap me" affordance.
	_beacon = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.42
	sm.height = 0.84
	_beacon.mesh = sm
	_beacon_mat = Palette.emissive(Palette.THREAT, 3.0)
	_beacon.material_override = _beacon_mat
	# Out at the prow, clear of the cross arms, so the approach lane stays open.
	_beacon.position = BEACON_LOCAL
	add_child(_beacon)
	breach_point = _beacon.global_position

	_ring = MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.95
	torus.outer_radius = 1.05
	torus.ring_segments = 48
	_ring.mesh = torus
	_ring_mat = Palette.emissive(Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.0), 3.0)
	_ring.material_override = _ring_mat
	_ring.position = _beacon.position
	add_child(_ring)


func arm_trap(cfg: Dictionary) -> void:
	# Called after the node is in the tree, because the beacon it restyles is
	# built in _ready.
	trap = cfg
	if trap.is_empty() or _beacon_mat == null:
		return
	# THE TELL. A rigged hull is not a gotcha — this game telegraphs everything
	# that can hurt you (see Hostile's charge-up, the apex ground rings). The
	# beacon goes cold electric blue and stutters instead of breathing: something
	# in there is still drawing power, on a wreck that should be dead.
	#
	# It is deliberately only legible CLOSE UP. At range a small sphere has no
	# readable hue, so you learn what it means at the moment you are already
	# deciding to commit — which is where the decision belongs.
	_beacon_mat.albedo_color = TRAP_TELL
	_beacon_mat.emission = Color(TRAP_TELL.r, TRAP_TELL.g, TRAP_TELL.b)


func _process(delta: float) -> void:
	if _cracked:
		return

	breach_point = _beacon.global_position
	var t := Time.get_ticks_msec() / 1000.0
	if trap.is_empty():
		_beacon_mat.emission_energy_multiplier = 2.4 + sin(t * 3.0) * 0.9 + _progress * 6.0
		_beacon.scale = Vector3.ONE * (1.0 + sin(t * 3.0) * 0.06 + _progress * 0.35)
	else:
		# Arrhythmic: two beats that never line up, so it reads as a fault rather
		# than as a heartbeat.
		var stutter := sin(t * 11.0) * sin(t * 2.3)
		_beacon_mat.emission_energy_multiplier = 2.0 + absf(stutter) * 4.5 + _progress * 6.0
		_beacon.scale = Vector3.ONE * (1.0 + stutter * 0.09 + _progress * 0.35)

	# Progress decays when not held, so a released hold visibly slips back.
	if not _holding and _progress > 0.0:
		_progress = maxf(_progress - DECAY_RATE * delta, 0.0)
		_sync_gauge()

	_update_prompt()


func _update_prompt() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if not hud:
		return
	var in_range := _player_in_range()
	if in_range != _in_range_last:
		_in_range_last = in_range
		if in_range:
			Barks.fire("first_breach_range")
			hud.prompt(breach_prompt())
		else:
			hud.clear_prompt()


func breach_prompt() -> String:
	# A Reliquary Heart in the hold names what the beacon only hints at. The tell
	# in arm_trap is deliberately hue-only and legible close up; the Heart turns
	# it into WORDS at the moment you are deciding to commit, which is the whole
	# of what the item is for. Without one nothing changes — an item that alters
	# nothing when absent has no value.
	#
	# Split out of _update_prompt so the rule can be asserted without standing a
	# ship in front of a wreck and reading the HUD.
	if not trap.is_empty() and (GameState.hold_has("heart_reliquary") or GameState.fit_has("mod_resonance")):
		return "RIGGED — THE HEART IS HUMMING. HOLD TO BREACH ANYWAY"
	return "HOLD ON THE BREACH POINT"


func _player_in_range() -> bool:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return false
	return player.global_position.distance_to(breach_point) <= CRACK_RANGE


func on_tapped() -> void:
	if _cracked:
		return
	FX.ring_pulse(get_parent(), breach_point, Palette.AMBER, 1.4)
	if _player_in_range():
		return
	_approach()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.prompt("APPROACHING DERELICT")


func _approach() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var toward: Vector3 = player.global_position - breach_point
	toward.y = 0.0
	if toward.length() < 0.1:
		toward = Vector3.BACK

	# Approach the prow beacon from off the prow. Biasing toward the camera
	# instead put the stand-off inside the hull's own collision sphere, so the
	# ship was pushed out to 6.8 against a 6.5 breach range and could never
	# start the hold. The outward axis is clear of the hull by construction.
	var axis: Vector3 = breach_point - global_position
	axis.y = 0.0
	if axis.length() < 0.1:
		axis = Vector3.BACK
	var dir: Vector3 = (axis.normalized() * 1.6 + toward.normalized()).normalized()
	var stand: Vector3 = breach_point + dir * (CRACK_RANGE * 0.78)
	stand.y = 0.0
	player.command_move(stand)


func hold_begin() -> void:
	if _cracked or _holding:
		return
	if not _player_in_range():
		on_tapped()
		return
	_holding = true
	if _crack_player.stream:
		_crack_player.play()


func hold_release() -> void:
	if not _holding:
		return
	_holding = false
	_crack_player.stop()
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and not _cracked:
		hud.crack_progress(-1.0)


func hold_tick(delta: float) -> void:
	if _cracked or not _holding:
		return
	if not _player_in_range():
		hold_release()
		_approach()
		return

	_progress += delta / crack_time
	_sync_gauge()

	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.shake(0.006 + _progress * 0.03)

	if _progress >= 1.0:
		_breach()


func _sync_gauge() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(_progress if _progress > 0.001 else -1.0)
	_ring_mat.albedo_color.a = _progress * 0.9
	_ring.scale = Vector3.ONE * (1.6 - _progress * 0.7)


func _breach() -> void:
	_cracked = true
	_holding = false
	_crack_player.stop()
	remove_from_group("crackable")

	var parent := get_parent()
	var tree := get_tree()
	var pos := breach_point
	var hud := tree.get_first_node_in_group("hud")
	var rig := tree.get_first_node_in_group("camera_rig")
	var main := tree.get_first_node_in_group("main")

	if hud:
		hud.crack_progress(-1.0)
		hud.prompt("HULL BREACHED")
	if main and main.has_method("hit_stop"):
		main.hit_stop(0.11, 0.2)
	if rig:
		rig.shake(0.3)
		rig.punch_zoom(-1.6)

	# Breaching is the progression gate: it charts the next system. A deep-space
	# hulk is deliberately outside that gate — it is a payday found by going
	# looking, not a survey, and charting PYX-02 by cracking something 400u off
	# the map would let the expanse skip the game's spine.
	if main and counts_as_survey:
		GameState.mark_breached(main.system_id)
		# The breach is the aftershock that wakes this system's survey engine.
		if main.has_method("arm_apex_wake"):
			main.arm_apex_wake()
	# Cracking a hull teaches you about hulls, and that is true of a deep hulk as
	# much as a charted derelict — so this sits OUTSIDE the survey guard above.
	# Charting the next system and waking the apex are the things the expanse must
	# not do; learning from what you just opened is not one of them.
	GameState.note_ledger("hulks_cracked", 1)
	# And the expanse remembers, so the cell cycling out and back does not hand
	# the same hull over twice. Charted derelicts skip this: `deep` is false and
	# their persistence is GameState.breached.
	if deep and main and main.deep_space:
		main.deep_space.note_hulk_cracked(cell)
	if GameState.mark_archeology(GameState.ARCHEOLOGY_PER_BREACH) and hud:
		hud.show_toast("ARCHEOLOGY %d — %s NOW READS IN THE FIELD" % [
			GameState.archeology, DeepSpace.BAND_NAMES[GameState.archeology]],
			Palette.GOLD)

	# A contract that says BREACH THE DERELICT is satisfied by breaching one,
	# wherever it was found. Only the charting and the apex wake above are things
	# a deep hulk must be kept away from.
	if main and counts_for_contract and main.contracts:
		main.contracts.on_breach()

	# And if it was bait, this is the moment it says so.
	if not trap.is_empty() and main and main.has_method("spring_trap"):
		main.spring_trap(pos, trap)

	Sfx.play("breach", 0.0)
	Sfx.haptic("heavy")
	Sfx.play("vortex", -8.0)
	FX.flash(parent, pos, Palette.WHITE_HOT, 4.0, 0.3)
	FX.shockwave(parent, pos, Palette.AMBER, 11.0, 0.9)
	FX.burst(parent, pos, Color(1.0, 0.6, 0.2), 90, 12.0, 0.35, 1.1)
	FX.vortex(parent, pos, Palette.GOLD, VORTEX_TIME)

	_beacon.visible = false
	_ring.visible = false

	# Hull splits open along the breach.
	for i in range(_hull_parts.size()):
		var part := _hull_parts[i]
		var dir := Vector3(randf_range(-1, 1), randf_range(-0.2, 0.6), randf_range(-1, 1)).normalized()
		var tw := part.create_tween()
		tw.set_parallel(true)
		tw.tween_property(part, "position", part.position + dir * randf_range(0.5, 1.4), 0.7).set_trans(Tween.TRANS_BACK)
		tw.tween_property(part, "rotation", part.rotation + dir * 0.25, 0.7)

	_spill_waves(parent, pos)


func force_breach() -> void:
	# Harness support: breach without flying a ship to the point and holding. The
	# existing harnesses drive the real hold loop (see PYXIS_PACINGTEST), which is
	# right when what is being measured is the loop — this is for asserting what
	# a breach PAYS, where the flying is not the subject.
	if _cracked:
		return
	_breach()


func _spill_waves(parent: Node3D, pos: Vector3) -> void:
	# Loot arrives in waves, not one dump — the counter should climb for
	# several seconds while the vortex shimmers.
	var waves := int(VORTEX_TIME / LOOT_WAVE_INTERVAL)
	var per_wave := maxi(1, int(ceil(float(loot_total) / float(waves))))
	# A cracked hull yields what a hull yields: relics and sealed archive cores.
	var crates := PackedStringArray()
	for i in range(randi_range(2, 3)):
		crates.append("relics")
	for i in range(randi_range(2, 3)):
		crates.append("cores")
	var crate_index := 0

	for w in range(waves):
		get_tree().create_timer(w * LOOT_WAVE_INTERVAL).timeout.connect(func() -> void:
			if not is_instance_valid(parent):
				return
			var m := get_tree().get_first_node_in_group("main")
			for i in range(per_wave):
				var spot := pos + Vector3(
					randf_range(-1.2, 1.2), randf_range(-0.5, 0.9), randf_range(-1.2, 1.2))
				var good := ""
				if crate_index < crates.size() and (w % 4) == 0 and i == 0:
					good = crates[crate_index]
					crate_index += 1
				if m:
					m.spawn_loot(parent, spot, good)
		)
	get_tree().create_timer(VORTEX_TIME + 1.2).timeout.connect(func() -> void:
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			hud.clear_prompt()
	)
