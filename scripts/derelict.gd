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

# THE OPENING BEARING. Cracking a system's own derelict reads a bearing on that
# system's engine off the hull's log — the first entry in the dossier, and for
# most players the one that turns "silence THE GNOMON" from an instruction into
# a direction. It is the tutorial's real payload: the guided run ends on this
# breach, so it ends by starting the hunt rather than by announcing it.
#
# 20 DEGREES, AND IT MUST STAY THE WIDEST CONE IN THE GAME. Every other bearing
# channel is earned or bought — a cleared guard post is 15, a read relic 12, a
# mast 8, the Last Watch 5, a rift 4 — and this one is given away. Tighten it
# below any of those and the whole intel economy is undercut by the thing the
# player gets for free in the first twenty minutes. `THE OPENING BEARING IS THE
# WIDEST` asserts it against the real constants rather than trusting this note.
#
# The geometry does the difficulty scaling for free, which is why one number
# serves all three systems. A +-20 cone spans 2*r*tan(20) across, and the lair
# radii are authored per system, so the same reading is worth wildly different
# amounts depending on where it is read:
#
#     PYX-01   lair at radius  300- 380   cone  218- 277u across
#     PYX-02   lair at radius  668- 828   cone  486- 603u
#     PYX-03   lair at radius 1194-1494   cone  869-1088u
#
# A real lead on the first hunt, and nearly worthless on the last. That is the
# correct shape — the deep hunts are supposed to be bought, not given.
const INTEL_ERROR_DEG := 20.0

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

# v25 (§99). THE PROVING DRIFT, as two fields rather than a subclass. This class
# is already a gradient of hull kinds -- the authored survey hull, the tutorial's
# hull, the deep hulks, the grave-field pairs -- and §17's rule is that the
# gradient is parameters. Empty on every hull that is not a workshop, which is
# all of them but one.
#
# `prototype` is the module id the workshop was building; `owns_mark` is the
# sounding mark it belongs to, so cracking it can spend the mark and the drift
# does not come back on the next rebuild.
var prototype := ""
var owns_mark := ""
# §101. THE LAYUP. A hull that takes deposits stays interactive after its
# breach: the crack is the withdrawal, and the open cache then accepts cargo --
# the only purely expressive verb in the game, paying nothing, counting
# nothing. Set by the spawner with owns_mark; every other hull leaves it false.
var takes_deposits := false
# A donation is slower than a breach and faster than a filing: long enough to
# be deliberate, short enough that generosity is not punished with tedium.
const DEPOSIT_TIME := 3.5
var _depositing := false

var breach_point := Vector3.ZERO

var _progress := 0.0
var _holding := false
var _cracked := false

# Which expanse cell this hull belongs to, and whether it has already been
# opened this session. Charted derelicts leave `deep` false and are untouched by
# any of it — their persistence is `GameState.breached`, which is a different
# guarantee entirely. See DeepSpace._cracked for why a deep hulk needs one.
var cell := Vector2i.ZERO
# WHICH hulk in that cell. 0 for the wreck a cell has always held, 1 for the
# second one a band-6 grave-field puts beside it. The breached-set was keyed by
# CELL alone, on a stated invariant ("a cell holds at most one hulk") that
# grave-fields are the first thing to break — so cracking one of a pair would
# have opened the other, and the second wreck's loot would have vanished with a
# hull that read as already-breached.
var hulk_index := 0
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
		# §101. An opened LAYUP stays in the ladder: the cache outlives its own
		# withdrawal, and deposits reach it through the same hold every other
		# verb uses. Every other hull leaves the group when it opens.
		if not takes_deposits:
			remove_from_group("crackable")
		_beacon.visible = false
		_ring.visible = false

	_crack_player = Sfx.attached_loop(self, "crack", -6.0)


func hull_aabbs() -> Array:
	# Every solid box of the hull, in WORLD space. Companion to
	# SurveyMast.dish_aabb(); see MAST IS CLEAR.
	var out: Array = []
	for mi in _hull_parts:
		if is_instance_valid(mi):
			out.append(mi.global_transform * mi.get_aabb())
	return out


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
	if _cracked and takes_deposits:
		# §101. The open cache answers every tap with its terms (§58): what the
		# hold gesture will do, or exactly why it will not.
		FX.ring_pulse(get_parent(), breach_point, Palette.RIVAL, 1.4)
		var hud_c := get_tree().get_first_node_in_group("hud")
		if hud_c:
			if GameState.cargo_used() <= 0:
				hud_c.prompt("THE CACHE — YOUR HOLD IS EMPTY. THERE IS NOTHING TO LEAVE.")
			else:
				hud_c.prompt("THE CACHE — HOLD TO LEAVE YOUR CARGO. ALL OF IT, FOR NOTHING.")
		if not _player_in_range():
			_approach()
		return
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
	if _holding:
		return
	if _cracked:
		# §101. THE DEPOSIT, behind the same gesture as everything else. The
		# empty-hold refusal is spoken rather than silent, because a hold that
		# does nothing with no word is a bug report (§58).
		if not takes_deposits:
			return
		if GameState.cargo_used() <= 0:
			var hud_e := get_tree().get_first_node_in_group("hud")
			if hud_e:
				hud_e.prompt("THE CACHE — YOUR HOLD IS EMPTY. THERE IS NOTHING TO LEAVE.")
			return
		if not _player_in_range():
			on_tapped()
			return
		_depositing = true
		_holding = true
		if _crack_player.stream:
			_crack_player.play()
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
	var was_depositing := _depositing
	if _depositing:
		# §101. An abandoned donation resets whole. A breach decays through
		# _process; a deposit cannot (the cracked early-return owns that path),
		# and a residual would let a donation be assembled in free nibbles --
		# the act is deliberate or it is nothing.
		_depositing = false
		_progress = 0.0
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and (was_depositing or not _cracked):
		hud.crack_progress(-1.0)


func hold_tick(delta: float) -> void:
	if not _holding:
		return
	if _depositing:
		if not _player_in_range():
			hold_release()
			return
		_progress += delta / DEPOSIT_TIME
		# The gauge carries the TERMS while the bar moves (§58): this is
		# irreversible and pays nothing, and the label says so before the last
		# tick rather than after it.
		var hud_d := get_tree().get_first_node_in_group("hud")
		if hud_d:
			hud_d.crack_progress(_progress if _progress > 0.001 else -1.0,
				"LEAVING THE HOLD — EVERYTHING, FOR NOTHING")
		if _progress >= 1.0:
			_deposit()
		return
	if _cracked:
		return
	if not _player_in_range():
		hold_release()
		_approach()
		return

	# THE BREACHING TORCH'S ONE JOB. A rate multiplier rather than a shorter
	# crack_time, because crack_time is the WRECK's property — set by the band it
	# was found in — and a tool that edited it would be writing the world's number
	# from the ship. The hold gets faster; the hull stays what it is.
	_progress += delta * (1.0 + maxf(float(GameState.stats.get("breach_speed", 0.0)), 0.0)) / crack_time
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
	if not takes_deposits:
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
		# ...and the hull's log gives up a bearing on it. INSIDE the survey
		# guard, for exactly the reason charting is: a deep hulk is a payday
		# found by going looking, and letting one 400u off the map hand over the
		# opening lead would let the expanse skip the hunt as well as the spine.
		#
		# AFTER mark_breached, and the order is the beat. Charting fires
		# `system_unlocked`, whose handler broadcasts the free band-and-quadrant
		# ("%s is transmitting across the lane... silence it") — so the player is
		# told there is a hunt, and then told which way to point. Filing first
		# would answer a question nobody had asked yet.
		if main.has_method("file_apex_intel"):
			main.file_apex_intel("hull", global_position, INTEL_ERROR_DEG)
	# Cracking a hull teaches you about hulls, and that is true of a deep hulk as
	# much as a charted derelict — so this sits OUTSIDE the survey guard above.
	# Charting the next system and waking the apex are the things the expanse must
	# not do; learning from what you just opened is not one of them.
	GameState.note_ledger("hulks_cracked", 1)
	# §99. AND IF IT WAS A WORKSHOP, THIS IS WHAT WAS ON THE BENCH. Placed here,
	# with the other conditional payloads, because that is what it is: one more
	# flag-gated block in a function that already has four.
	if owns_mark != "":
		if takes_deposits:
			# §101. THE WITHDRAWAL IS TAKEN, and the hull stands. Spending the
			# mark is what makes the haul once-only across every rebuild; the
			# broadcast is the deposit verb's teaching, spoken at the exact
			# moment the cache becomes able to receive (§88's rule: the
			# affordance is announced where it begins to exist).
			GameState.note_mark_spent(owns_mark)
			if hud:
				hud.show_broadcast("THE LAYUP — OPEN",
					"TAKE WHAT YOU NEED. LEAVE WHAT YOU CAN. IT HAS ALWAYS WORKED THAT WAY — HOLD ON THE CACHE TO LEAVE YOUR CARGO.",
					Palette.RIVAL)
		else:
			_hand_over_prototype(hud)
	# And the expanse remembers, so the cell cycling out and back does not hand
	# the same hull over twice. Charted derelicts skip this: `deep` is false and
	# their persistence is GameState.breached.
	if deep and main and main.deep_space:
		main.deep_space.note_hulk_cracked(cell, hulk_index)
	if GameState.mark_archeology(GameState.ARCHEOLOGY_PER_BREACH) and hud:
		hud.show_toast("ARCHEOLOGY %d — IDENTIFY %s SALVAGE WITHOUT DOCKING" % [
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


func _hand_over_prototype(hud) -> void:
	# THE MARK IS SPENT WHATEVER HAPPENS, and that ordering is deliberate: the
	# hull is open either way, and a mark that stayed unspent because the pilot
	# happened to own the module already would rebuild the workshop on the next
	# warp and hand out its salvage again, forever.
	GameState.note_mark_spent(owns_mark)
	var took := prototype != "" and GameState.grant_module(prototype)
	if took:
		if hud:
			hud.show_broadcast("THE BENCH — %s" % String(ModuleDB.get_module(prototype)["name"]),
				"It was still clamped down when the air went. Nobody out here is selling them anything, so they built it themselves. It is yours, and it is the only one.",
				Palette.RIVAL)
		# 48 characters is the whole line, so the module's name goes last and
		# the longest one in the table leaves room.
		GameState.note_log("TOOK A PROTOTYPE — %s" % String(
			ModuleDB.get_module(prototype)["name"]).to_upper())
		Sfx.play("equip", -5.0, 0.8)
		return
	# THE SECOND WORKSHOP SAYS SO. The proving drift is a COMMON kind and may
	# repeat in a run, so two of them dealing the same bench is routine rather
	# than exotic -- and a hull that quietly handed over nothing would read as a
	# bug in the one place the fiction is most specific. §58: the refusal states
	# its own terms, and it pays the salvage either way because the hull was
	# still full.
	if hud:
		hud.show_broadcast("THE BENCH — STRIPPED",
			"The same pattern you are already flying. They built more than one, and somebody else got here first — or you did, at another drift. The hull is still worth opening.",
			Palette.RIVAL)


func _deposit() -> void:
	# §101. EVERYTHING, FOR NOTHING. The whole hold in one gesture -- the mast's
	# one-gesture generosity, never a picker -- and the response is one line
	# with no number in it, because the arrangement does not keep books. The
	# only record anywhere is the single fact on the mark (note_mark_given),
	# which is what re-reads the plate; amounts, goods and counts are recorded
	# nowhere, asserted by THE CACHE IS TWO-WAY.
	_holding = false
	_depositing = false
	_progress = 0.0
	for good_v in GameState.cargo.keys():
		var n := int(GameState.cargo.get(good_v, 0))
		if n > 0:
			GameState.unload_cargo(String(good_v), n)
	var first := GameState.note_mark_given(owns_mark)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(-1.0)
		hud.refresh_cargo()
		hud.show_broadcast("THE CACHE",
			"IT IS IN THE CACHE. SOMEBODY WILL NEED IT. THAT IS THE WHOLE ARRANGEMENT.",
			Palette.RIVAL)
	if first:
		GameState.note_log("LEFT THE HOLD AT THE LAYUP")
	Sfx.play("equip", -8.0, 0.65)
	FX.ring_pulse(get_parent(), breach_point, Palette.RIVAL, 3.0, 0.8)


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
