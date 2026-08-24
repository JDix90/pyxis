class_name Storm
extends Node3D
# WEATHER IN THE UNSOUNDED (v20). Four hundred units across, wandering, and the
# only thing in this game that will kill you without shooting at you.
#
# --- THE THREE THINGS A READER GETS WRONG ------------------------------------
#
# 1. THE PULL CANNOT TRAP YOU, AND WAS NEVER MEANT TO. DRAG_MAX 1.40 sits under
#    PlayerShip.TETHER_DRAG_CEILING 1.5 sits under the 1.6 that
#    ModuleDB.enforce_floors clamps max_speed to. Outside the eye the speed you
#    need to break even is EXACTLY the drag, so every legal fit makes outward
#    headway at every radius, always — 1.202 u/s at the eyewall against a 1.6
#    floor. That is 40's promise ("out-runnable by any legal fit is the one
#    promise this mechanic has to keep") unmodified, and it holds because the
#    pull goes through apply_tether, which re-clamps whatever this file passes
#    it. No tuning of the constants below can build a cage.
#
#    The radii at which a real drive is actually pinned are single digits:
#    Vector 5.1u, Cruise 0.8u, Cruise Mk II never. The pull is not the trap.
#
# 2. THE TEETH ARE THE CANCELLED MOVE ORDER AND THE DAMAGE CLOCK. emp_stun
#    clears has_move_target — inside the eye that is every 4 to 5.4 seconds. A
#    player who taps a bearing and looks away is drifting again within one pulse,
#    while the hull takes up to 14/s. Worked out, the centre kills EVERY fit in
#    the game without a Thermal Sink, including a Cruise Mk II behind Bulwark's
#    250. With one carried it is a seven-second walk out costing 57 shield.
#    That is the whole design: the storm is survivable, and surviving it is a
#    thing you prepared for rather than a thing you out-ran.
#
# 3. THE EMP RING AND THE DAMAGE RING ARE THE SAME RING, ON PURPOSE. A ship
#    pinned somewhere with no clock running is a soft-lock the player cannot even
#    die out of — worse than the death this design chose. Between PULL_RADIUS and
#    EYE_RADIUS there is drag and nothing else, which is also what makes the
#    escape guarantee provable: out there the threshold IS the drag.
#
# --- WHAT IT IS NOT ----------------------------------------------------------
#
# It pays nothing. No crate, no mast, no intel packet — 67's rule about
# landmarks, that an object which pays out stops being scenery and becomes
# another errand, and a hazard that paid would be a thing you farm rather than
# avoid.
#
# It pulls only the player. Hostiles keep their own movers, exactly as SweepArm
# damages only the player: a storm that killed packs would be a loot farm you
# could kite things into. Swarm fighters flying serenely through a hurricane is a
# deliberate scope decision, not an oversight.
#
# It is SESSION WEATHER, never generated world. A system_root child that dies
# with the system, placed on the unsalted global randf() — spawn_rift's own
# reasoning. It never touches plan_cell, takes no salted stream, and appears in
# no fingerprint. "Nothing out there is saved" governs CELLS, which must be pure
# functions; a rift is already the precedent for weather that is not.
#
# And it calls note_log and note_ledger exactly ZERO times. 53's rule is that
# anything ambient which logs, SAVES — note_log queues a write — and the
# captain's log is ten slots for things that happened to you, not three slots an
# hour of ambient weather.

# --- geometry ----------------------------------------------------------------
# 400u across: 2.9x HyperStructure's 140u silhouette and 1.25x the 320u live
# streaming window, which makes it by a wide margin the largest object in the
# game and readable from roughly three times further out than anything reacts to
# it. The telegraph is the geometry before it is ever a line of text.
const WARN_RADIUS := 520.0
const PULL_RADIUS := 200.0
const EYE_RADIUS := 36.0

# --- the pull ----------------------------------------------------------------
# THE CENTRE THRESHOLD IS THE DESIGN AND THE DRAG IS DERIVED FROM IT.
#
# Thrust and drag ADD in PlayerShip's position step, and an EMP kills thrust
# while drag keeps applying at full strength. So net progress is
# max_speed*(1 - duty) - drag, and the speed at which a ship breaks even is
# drag / (1 - duty). Solved backwards from the number that matters:
#
#   10.00 sits between the best tier-1 drive total (BASE 5.75 + drive_cruise 3.5
#   = 9.25) and the best tier-2 (BASE + drive_cruise_2 5.0 = 10.75).
#
# The threshold is authored; STORMTEST asserts the RULE against ModuleDB's live
# catalog, so a Mk III drive turns it red and makes somebody re-decide the
# boundary rather than silently moving it.
const CENTRE_THRESHOLD := 10.0
const EYE_DUTY_MAX := 0.86
const DRAG_MAX := CENTRE_THRESHOLD * (1.0 - EYE_DUTY_MAX)     # 1.40
const DRAG_EDGE := 0.30
# How fast the drag reservoir fills. The CAP is the promise; this is only how
# quickly it is reached, and apply_tether limit_lengths it regardless.
const PULL_ACCEL := 2.4

# --- the eye -----------------------------------------------------------------
# EMP_LEN_MAX stays under the Unsounded's own TRAP_EMP[6] of 3.5: nothing in a
# storm out-hits the chart, on any axis, and a rigged hulk is the harder pulse.
const EMP_LEN_MIN := 1.6
const EMP_LEN_MAX := 3.4
# Below this there is no pulse at all, which is what keeps the eyewall itself a
# clean drag-only boundary.
const MIN_DUTY := 0.05
# 0.9s of warning before every pulse. 18's rule: everything in this game that
# can hurt you telegraphs first, and this is the beat in which a re-tap or a
# core_surge actually lands.
const PULSE_LEAD := 0.9
const EYE_DPS_MAX := 14.0
# SweepArm's fixed accumulator, not per-frame damage. Same reason: a hazard
# measured in frames is a hazard whose difficulty is the player's hardware.
const TICK := 0.25

# --- the wander --------------------------------------------------------------
# Under the 1.6 max_speed floor by 0.75, so a storm can never run anything down.
const DRIFT_SPEED := 0.85
const HEADING_INTERVAL := 45.0
const HEADING_TURN_DEG := 70.0
const LIFETIME := 900.0
# How far past the band's own floor a storm may roam. The inner bound keeps the
# PULL ring itself clear of the band edge, so THE UNSOUNDED's inner boundary is
# never weather.
const DRIFT_DEPTH_SPAN := 2000.0

const ARM_SPIN := 0.06

# THE COPY, on the object, so the assertion reads the shipped strings rather
# than a re-typed copy of them. 58: every line uses a word the game has taught
# or says what to do about it. BURN OUTWARD is not new vocabulary — it is the
# Meridian's own tether prompt, which is the point.
const COPY := {
	"pull": "THE STORM HAS YOU — BURN OUTWARD",
	"eye": "THE STORM IS TAKING YOUR HULL — BURN OUTWARD NOW",
	"tag": " · CAUGHT — BURN OUTWARD",
	"blow_out": "THE STORM BLEW ITSELF OUT",
	# 58 audited: "storm" is taught by the line that introduces it, "bearing" is
	# already vocabulary, GO AROUND and CARRY are the verbs, and the answer is
	# named by CommodityDB's own display name rather than by a description of it.
	#
	# The sender is the ship's OWN INSTRUMENTS and not the GSA. Band 4's
	# broadcast already established that the beacon net does not reach, and band
	# 6's is "· · ·" / "Nothing is transmitting. Something is listening." An
	# automated advisory out here would contradict shipped fiction.
	"from": "YOUR OWN INSTRUMENTS",
	"body": "A STORM AHEAD — BEARING %03d, %du OFF. IT PULLS EVERYTHING INWARD. GO AROUND IT, OR CARRY A THERMAL SINK THROUGH IT.",
}

var _heading := Vector2.RIGHT
var _heading_timer := HEADING_INTERVAL
var _life := LIFETIME
var _pulse_timer := 0.0
var _lead_timer := -1.0
var _damage_acc := 0.0
var _reduced := false
var _arms: Node3D
var _eye_mat: StandardMaterial3D
var _ring_mat: StandardMaterial3D
var _motes: CPUParticles3D
var _announced := false
var _prompt_now := ""


static func band_index() -> int:
	# The deepest band the game has, derived. Read as an IDENTITY rather than as
	# the number 6, so adding a band moves the weather with it — which is the
	# opposite of the choice Rift.GRADE_CEILING makes, and deliberately so: a
	# shear's GRADE must not follow the ladder outward (that was 68's stealth pay
	# rise), while a storm's PLACE must, because "past everything" is what it is.
	return DeepSpace.BAND_NAMES.size() - 1


static func band_floor() -> float:
	return float(DeepSpace.BAND_EDGES[DeepSpace.BAND_EDGES.size() - 1])


static func drag_at(dist: float) -> float:
	# Pure, static, and the harness's single source for the escape arithmetic —
	# so an assertion cannot restate the curve and then agree with itself.
	var s := clampf(1.0 - dist / PULL_RADIUS, 0.0, 1.0)
	return lerpf(DRAG_EDGE, DRAG_MAX, s)


static func duty_at(dist: float) -> float:
	# Concave on purpose. threshold = drag/(1 - duty) is hyperbolic in duty, so a
	# LINEAR duty puts every drive-tier boundary inside the last four units of
	# radius and the whole gradient reads as a cliff.
	var e := clampf(1.0 - dist / EYE_RADIUS, 0.0, 1.0)
	return EYE_DUTY_MAX * sqrt(e)


static func threshold_at(dist: float) -> float:
	# The speed at which a ship breaks even against this storm at this distance.
	var u := duty_at(dist)
	return drag_at(dist) / maxf(1.0 - u, 0.0001)


static func dps_at(dist: float) -> float:
	return EYE_DPS_MAX * clampf(1.0 - dist / EYE_RADIUS, 0.0, 1.0)


func _ready() -> void:
	add_to_group("storm")
	set_physics_process(true)
	_heading = Vector2(cos(randf() * TAU), sin(randf() * TAU))
	_build()


func _build() -> void:
	# REDUCED MOTION IS READ ONCE, HERE. 30's rule is that the accommodation is
	# gated at one entry point and shows the END STATE immediately — never a
	# slower animation. With it on, no particle node is constructed at all, the
	# arms never turn, and both rings are built at their final emission energy,
	# so the storm is fully itself on frame one.
	_reduced = GameState.reduce_motion()
	var tint := Palette.band_color(band_index())

	# The boundary ring IS the pull radius. A player who learns the ring learns
	# the mechanic, and nothing has to say so.
	var ring := MeshInstance3D.new()
	var rm := TorusMesh.new()
	rm.inner_radius = PULL_RADIUS - 3.0
	rm.outer_radius = PULL_RADIUS
	rm.ring_segments = 96
	ring.mesh = rm
	_ring_mat = Palette.emissive(tint, 1.6)
	ring.material_override = _ring_mat
	ring.scale.y = 0.2
	add_child(ring)

	_arms = Node3D.new()
	add_child(_arms)
	for i in range(6):
		var arm := MeshInstance3D.new()
		var am := BoxMesh.new()
		am.size = Vector3(PULL_RADIUS * 0.82, 0.6, 5.0)
		arm.mesh = am
		var a := TAU * float(i) / 6.0
		arm.rotation.y = a
		arm.position = Vector3(cos(a), 0.0, sin(a)) * PULL_RADIUS * 0.42
		arm.material_override = Palette.emissive(
			Color(tint.r, tint.g, tint.b, 0.35), 0.9)
		_arms.add_child(arm)

	# THREAT, the game's universal "this will hurt", the same colour the sweep
	# arm's leading edge wears.
	var eye := MeshInstance3D.new()
	var em := TorusMesh.new()
	em.inner_radius = EYE_RADIUS - 2.5
	em.outer_radius = EYE_RADIUS
	em.ring_segments = 64
	eye.mesh = em
	_eye_mat = Palette.emissive(Palette.THREAT, 2.8)
	eye.material_override = _eye_mat
	eye.scale.y = 0.3
	add_child(eye)

	if not _reduced:
		# Owned rather than FX.vortex, which is a one-shot that frees itself.
		_motes = CPUParticles3D.new()
		_motes.amount = 130
		_motes.lifetime = 3.2
		_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		_motes.emission_sphere_radius = EYE_RADIUS * 1.4
		_motes.radial_accel_min = -30.0
		_motes.radial_accel_max = -18.0
		_motes.tangential_accel_min = 11.0
		_motes.tangential_accel_max = 18.0
		_motes.scale_amount_min = 0.6
		_motes.scale_amount_max = 1.6
		_motes.color = tint
		# §143. THE LINE THAT WAS MISSING HERE TOO, since v20. CPUParticles3D
		# draws nothing without a mesh, and `color` only tints a material that
		# is not there -- so the eye's motes have never rendered. It went
		# unnoticed for four horizons because a storm also has an eye, arms, a
		# ring and a shockwave to be seen by; the tide, which had only motes,
		# is what finally reported it. FX.burst's exact construction.
		var storm_mote := BoxMesh.new()
		storm_mote.size = Vector3.ONE * 0.16
		storm_mote.material = Palette.emissive(tint, 2.6)
		_motes.mesh = storm_mote
		add_child(_motes)

	_audio = Sfx.attached_loop(self, "sweep", AUDIO_DB_FAR)


const AUDIO_DB_NEAR := -6.0
const AUDIO_DB_FAR := -34.0
const AUDIO_FADE := 3.0
var _audio: AudioStreamPlayer
var _hud_poll := 0.0


func _process(delta: float) -> void:
	if _reduced:
		return
	_arms.rotation.y += ARM_SPIN * delta


func _physics_process(delta: float) -> void:
	_life -= delta
	if _life <= 0.0:
		blow_out()
		return

	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var to_player := player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()

	_drift(delta, dist, to_player)

	# DOCKED IS SAFE, and it is checked here rather than trusted to PlayerShip's
	# early return. 14 makes docking the game's one safe state; a guarantee that
	# rests on a return statement in another file is a guarantee one refactor
	# away from being untrue.
	#
	# DOCKED ONLY, deliberately — NOT is_protected(). Aegis and the post-warp
	# grace window are DAMAGE protection, and take_hit already refuses on both by
	# itself; a storm that also stopped PULLING would make a defensive core into
	# a tractor immunity nobody designed. The first draft checked is_protected
	# and the harness caught it instantly, because a harness sets invulnerable to
	# survive its own measurements and the whole pull silently switched off.
	if player.docked:
		_release(player)
		return

	if dist <= PULL_RADIUS:
		_pull(player, to_player, dist, delta)
		_tick_eye(player, dist, delta)
	else:
		_release(player)

	_hud_poll -= delta
	if _hud_poll <= 0.0:
		_hud_poll = 0.25
		_tick_hud(player, dist)


func _pull(player: PlayerShip, to_player: Vector3, dist: float, delta: float) -> void:
	# EVERY PHYSICS FRAME, never the 0.25s poll: TETHER_RELEASE_DECAY bleeds the
	# channel to zero in about a third of a second, so a throttled feed would
	# produce a sawtooth the player feels as stutter.
	#
	# Through apply_tether and nowhere else. That call re-clamps at
	# TETHER_DRAG_CEILING, which is what makes the escape promise structural
	# rather than a thing this file remembers to honour.
	if dist < 0.001:
		return
	player.apply_tether(-to_player.normalized(), PULL_ACCEL, drag_at(dist), delta)


func _tick_eye(player: PlayerShip, dist: float, delta: float) -> void:
	if dist > EYE_RADIUS:
		_pulse_timer = 0.0
		_lead_timer = -1.0
		_damage_acc = 0.0
		return

	# Damage on a fixed accumulator, and with NO source — SweepArm's contract, so
	# the storm never sets the ship's threat and never becomes something the
	# auto-targeter tries to shoot back at.
	_damage_acc += delta
	while _damage_acc >= TICK:
		_damage_acc -= TICK
		var dps := dps_at(dist)
		if dps > 0.0:
			player.take_hit(dps * TICK)

	var duty := duty_at(dist)
	if duty <= MIN_DUTY:
		return
	var emp_len := lerpf(EMP_LEN_MIN, EMP_LEN_MAX, clampf(1.0 - dist / EYE_RADIUS, 0.0, 1.0))
	var period := emp_len / duty

	if _lead_timer > 0.0:
		_lead_timer -= delta
		if _lead_timer <= 0.0:
			_lead_timer = -1.0
			player.emp_stun(emp_len)
			Sfx.play("breach", -9.0, 0.6)
			if not _reduced:
				FX.shockwave(get_parent(), global_position, Palette.THREAT, EYE_RADIUS, 0.5)
		return

	_pulse_timer -= delta
	if _pulse_timer <= 0.0:
		_pulse_timer = period
		_lead_timer = PULSE_LEAD
		Sfx.play("klaxon", -14.0, 0.7)
		if _eye_mat:
			_eye_mat.emission_energy_multiplier = 5.2


func _drift(delta: float, dist: float, to_player: Vector3) -> void:
	# CLAMP 1: LATCHED MEANS FROZEN. The escape arithmetic assumes a fixed
	# centre; a storm closing at 0.85 on a floor-fit ship making 0.40 outward
	# would beat the very guarantee the ceiling exists to keep.
	if dist <= PULL_RADIUS:
		return

	_heading_timer -= delta
	if _heading_timer <= 0.0:
		_heading_timer = HEADING_INTERVAL
		# Unsalted global randf(), spawn_rift's precedent: this is session
		# weather, not world generation, and it is deliberately not deterministic.
		_heading = _heading.rotated(deg_to_rad(randf_range(-HEADING_TURN_DEG, HEADING_TURN_DEG)))

	var step := Vector3(_heading.x, 0.0, _heading.y)

	# CLAMP 2: IT NEVER CLOSES THE LAST 520u. 14 says being jumped must always be
	# something you could have reacted to, and a wandering hazard is the one
	# thing that could walk onto a player with a console open. Inside the warning
	# ring the drift is projected onto the tangent: the storm may circle or
	# recede, never approach. A storm never closes the last five hundred units —
	# the player does.
	if dist <= WARN_RADIUS and dist > 0.001:
		# `to_player` points FROM the storm TO the ship, so a POSITIVE component
		# along it is the storm closing. Subtract exactly that component and what
		# is left is the tangent: the storm may circle or fall away, never
		# approach.
		#
		# The first draft added it instead of subtracting, and this clause caught
		# it on the first run — a storm that "never closes" walked 8.5u straight
		# down the player's throat in ten seconds. A one-sided version of this
		# assertion would have passed it, which is why the far half exists.
		var toward := to_player.normalized()
		var closing := step.dot(toward)
		if closing > 0.0:
			step -= toward * closing
		if step.length() > 0.001:
			step = step.normalized()
		else:
			# Dead astern of the ship with nowhere tangential to go: fall away
			# rather than stall, so the clamp can never read as "it never moves".
			step = -toward

	var next := global_position + step * DRIFT_SPEED * delta

	# CLAMP 3: IT STAYS IN ITS BAND. Keyed to the band table's own length, never
	# to a literal 5200 — 17 rejects "an absolute number that happens to suit
	# PYX-01", and a system with bigger bounds pushes its own weather out with it.
	var main := get_tree().get_first_node_in_group("main")
	var ds: DeepSpace = main.deep_space if main != null else null
	if ds != null:
		var d := ds.depth_at(next)
		var lo := band_floor() + PULL_RADIUS
		var hi := band_floor() + DRIFT_DEPTH_SPAN
		if d < lo or d > hi:
			var radial := Vector3(global_position.x, 0.0, global_position.z)
			if radial.length() > 0.001:
				radial = radial.normalized()
				step = radial if d < lo else -radial
				_heading = Vector2(step.x, step.z)
				next = global_position + step * DRIFT_SPEED * delta
	global_position = next


func _tick_hud(player: PlayerShip, dist: float) -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null:
		return
	var want := ""
	if dist <= EYE_RADIUS:
		want = String(COPY["eye"])
	elif dist <= PULL_RADIUS:
		want = String(COPY["pull"])
	if want != _prompt_now:
		if _prompt_now != "":
			hud.clear_prompt_if(_prompt_now)
		_prompt_now = want
	if want != "":
		# hud.prompt early-returns on an identical live string, so re-asserting
		# every quarter second is free and survives being clobbered by a bark.
		hud.prompt(want)

	# ANNOUNCED ONCE, on the first crossing of the warning ring, latched like
	# Rift._intel_read. The bearing is through the glass — compass_deg of the
	# DIFFERENCE, not of the storm's position — because 60's rule is that a
	# readout points where the player must turn, and a bearing measured from the
	# origin to something 5,600u out is arithmetic nobody can fly.
	if not _announced and dist <= WARN_RADIUS:
		_announced = true
		var away := global_position - player.global_position
		away.y = 0.0
		hud.show_broadcast(String(COPY["from"]),
			String(COPY["body"]) % [DeepSpace.compass_deg(away), int(dist)],
			Palette.band_color(band_index()))

	if _audio:
		# Loudness alone carries proximity: the rig is fixed top-down, so there
		# is no stereo image to place it in. SweepArm's argument, and a storm is
		# the second thing in the game that reaches you from off screen.
		var t := clampf(1.0 - dist / WARN_RADIUS, 0.0, 1.0)
		_audio.volume_db = lerpf(AUDIO_DB_FAR, AUDIO_DB_NEAR, t)


func has_player(player: Node3D) -> bool:
	if player == null:
		return false
	var d := player.global_position - global_position
	d.y = 0.0
	return d.length() <= PULL_RADIUS


func _release(player: PlayerShip) -> void:
	if _prompt_now == "":
		return
	var hud := get_tree().get_first_node_in_group("hud")
	# clear_prompt_if, never clear_prompt: the line has a dozen writers and
	# clearing unconditionally is how one of them wipes another's live text.
	if hud:
		hud.clear_prompt_if(_prompt_now)
	_prompt_now = ""
	_pulse_timer = 0.0
	_lead_timer = -1.0
	_damage_acc = 0.0


func blow_out() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	if player != null:
		_release(player)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.show_toast(String(COPY["blow_out"]), Palette.band_color(band_index()))
	if not _reduced:
		FX.shockwave(get_parent(), global_position,
			Palette.band_color(band_index()), 40.0, 1.4)
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("forget_storm"):
		main.forget_storm(self)
	queue_free()
