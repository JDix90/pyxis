class_name ApexBoss
extends Node3D
# A derelict survey engine — the apex encounter of a system. Which engine is
# data: the system def names it and arms it (THE GNOMON's shadow lance, THE
# ARMILLARY's flare mortars, THE MERIDIAN's graviton tether), so each system's
# apex asks a different question without any of them being a new class.
#
# The third leg of the encounter triangle. Swarms ask "can you delete many weak
# things?"; sentries ask "can you kill one tanky thing from range?". The engine
# puts both on one clock and makes the answer to the first MULTIPLY the answer
# to the second:
#
#   SURVEY  - the iris opens, the core is vulnerable, you deal
#             damage x (0.15 + 0.85 * open_plates/5)
#   SEAL    - the iris slams shut, the engine vents probes that hunt you
#   next SURVEY - every probe still alive welds a plate shut for that whole
#             window. Kill the pack fast and you get a full window; ignore it
#             and you get a sliver.
#
# So add-clear speed buys structure-damage time, while the sweep arm decides how
# close you can afford to stand. No fit wins both halves.
#
# Boss state is deliberately NOT persisted: warping out or reloading resets the
# fight to full. Failure costs tempo, never salvage.

enum State { DORMANT, WAKING, SURVEY, SEAL, PHASING, DYING }

# --- FEEL CONSTANTS ---
# Kept equal to the highest probe count so a fully-ignored pack can actually
# seal the iris. With more plates than probes the floor is unreachable and the
# threat loses its teeth.
const PLATE_COUNT := 3
const SEALED_MULTIPLIER := 0.15     # never zero: every tap must register
const SEAL_TIME := 5.0
const PHASE_CHANGE_TIME := 1.5
const WAKE_TIME := 4.2              # long and loud: the player cannot opt in
# Probes are survey drones, not warships: they are tanky (so clearing them costs
# real time) but hit softly. Their threat is window denial, not lethality —
# ignoring them should cost you damage output, not the run.
const PROBE_DIFFICULTY := 0.7
# Probe HP must sit ABOVE the biggest single-shot alpha in the catalog
# (Lance Mk II, 105). Below that, a Lance one-shots probes and clears the pack
# as fast as an Arc, which collapses the entire exchange-rate mechanic.
const PROBE_HP_SCALE := 3.1
# Each successive vent WITHIN a phase releases one more probe than the last, so
# an engine that keeps sealing on you is visibly waking up rather than looping.
#
# Two guards, both load-bearing and both from measurement:
#   * capped at 4 — probe counts of 4-5 were MEASURED consuming ~40% of total
#     damage output and stretching fights past two and a half minutes (see the
#     PHASES comment). The escalation may touch that ceiling; it may not pass it.
#   * the counter RESETS each phase — an earlier tuning pass proved that any
#     bill scaling with whole-fight LENGTH makes slow fits pay several times
#     what fast fits do, which widens the exact gap the encounter exists to
#     close. Stalling one phase gets harder; being a slow fit does not compound.
const PROBE_VENT_MAX := 4

var _phase_vents := 0
const CORE_RADIUS := 1.5
const HUB_RADIUS := 2.2
# The survey field. Shots from beyond this break on the field and do nothing, so
# the highest-DPS long-range fit cannot farm the engine from outside the sweep.
# Every damaging position is inside SweepArm.SWEEP_RADIUS by design.
const CORE_RANGE := 7.0

# v15. THE HUNT'S THREE RANGES. They live on the engine rather than on Main
# because they are properties of the thing itself -- how close before it notices
# you, how far before it stops caring, how close before your instruments admit it
# is there. Main reads the first two, the radar reads the third; a constant on
# Main would be invisible to hud.gd, which has no way to name that script.
#
# Ordered WAKE < DETECT < LEASH, and the ordering is the design:
#   60  the engine wakes. Arriving is deliberate.
#   90  the radar finally marks it. You are already committed by then.
#  120  the fight ends. Leaving is deliberate too.
# The gap between wake and leash is what stops the encounter flickering on and
# off while a ship drifts at the edge of it.
const WAKE_RANGE := 60.0
const DETECT_RANGE := 90.0
const LEASH_RANGE := 120.0

# Per phase: [core_hp, sweep_deg, blades, probe_count, survey_window]
# Phase HP is sized so that even the highest-DPS fit in the catalog (dual Lance
# Mk II, ~214 dps) cannot burst a phase inside a single SURVEY window. If it
# could, that fit would never meet a seal, a probe, or the sweep — it would skip
# the encounter's entire mechanic, which is exactly what the first balance run
# measured at 1200 hp/phase.
#
# 1500 -> 1700 (phase 3). 1500 was chosen to sit JUST above the catalog's best
# sustained output, and a margin that thin is a margin that the next feature
# spends. Return fire spent it: filling the idle gaps between probe kills pushed
# peak single-window damage to 1500 exactly, against a ceiling of 1500. Return
# fire no longer touches the hub (PlayerShip._auto_targetable), but it still
# clears probes faster, which opens more plates, which raises the multiplier on
# the next window — so the ceiling gets real headroom this time rather than
# another coat of paint.
const PHASES := [
	# Probe COUNT is the fight's real time sink — each one is deliberately tanky,
	# so three is already ~400 hp of clearing per seal. Measured at 4-5 the probe
	# job consumed ~40% of total damage output and stretched the fight past two
	# and a half minutes.
	{"hp": 1700.0, "sweep": 22.0, "blades": 1, "probes": 2, "window": 7.0, "name": "SURVEY"},
	{"hp": 1700.0, "sweep": 34.0, "blades": 1, "probes": 3, "window": 6.5, "name": "RESURVEY"},
	{"hp": 1700.0, "sweep": 40.0, "blades": 2, "probes": 3, "window": 6.0, "name": "COLLAPSE"},
]

# --- the hub's own armament (phase 2.5) --------------------------------------
# The engine itself now fights. Before this, every apex was the same machine and
# all its pressure was delegated — probes deny the window, the sweep denies the
# ground — so the hub was a target, not an opponent, and "fight the boss" meant
# "shoot swarm fighters and time your shots". Each armament is telegraphed and
# dodgeable, because the series' rule is that standing still is what kills you;
# an attack you cannot answer with movement would just be a damage tax.
#
#   shadow_lance - locks a firing LINE on your position, fires down it a beat
#                  later. Sidestep. (The Gnomon — the tutorial-system boss
#                  teaches the rule in its cleanest form.)
#   flare_mortar - lobs shells onto your position under ground-ring telegraphs.
#                  Area denial: the dodge is a direction, not a sidestep.
#                  (The Armillary.)
#   grav_tether  - deals NO damage. Latches on and drags you toward the hub,
#                  the sweep arm, and the survey field's inner edge — it
#                  weaponizes positioning itself. Break it by burning outward;
#                  thrust away is stronger than the pull, standing still is not.
#                  (The Meridian.)
#
# Attacks run during SURVEY ONLY. That is where the player parks on the core,
# which is the behaviour these are built to punish; SEAL is already the probe
# job, and firing through it stacked two pressures on the one phase where slow
# fits spend most of their time. Measured with SEAL included, Arc went from a
# 53s kill to a 180s timeout with two emergency warps — and every warp resets
# the engine to full, so the tax compounded into a wall. SURVEY-only keeps the
# anti-camping teeth and drops the compounding.
# Damage is deliberately LOW. The armament is a pressure mechanic, not a second
# health bar: a player who dodges takes ~nothing (asserted), and a player who
# never moves should be pushed off their spot, not deleted. The first tuning
# pass ran 22/13 and measured as a flat per-second tax — every fit took ~9 per
# attack cycle, so the bill scaled with fight LENGTH and slow fits paid six
# times what the fastest fit did. That is the wrong axis entirely: it widens the
# fit gap the encounter is supposed to close.
const ATTACKS := {
	"shadow_lance": {"interval": 3.6, "telegraph": 0.85, "damage": 13.0,
		"width": 1.5, "reach": 11.0, "range": 15.0},
	"flare_mortar": {"interval": 4.6, "telegraph": 1.05, "damage": 8.0,
		"radius": 2.3, "shells": 3, "scatter": 1.6, "range": 15.0},
	# drag_cap is the terminal drag speed in u/s, and it must stay below the
	# 1.6 u/s that ModuleDB floors max_speed at or the worst legal fit is pinned.
	"grav_tether": {"interval": 7.5, "duration": 2.8, "pull": 6.5,
		"drag_cap": 1.15, "range": 13.0},
}
# First shot lands well after the wake so the opening read stays calm.
const ATTACK_FIRST_DELAY := 2.5
# Armament damage scales more softly than the rest of the encounter. A later
# system's engine already brings more HP, a faster sweep and more probes; at the
# full 2.0 multiplier a Meridian lance hit was 44 against a 100-point shield,
# which made the armament the fight rather than the pressure on it.
const ATTACK_DIFFICULTY_SOFTENING := 0.45

var difficulty := 1.0
var loot_total := 90
var first_kill_bonus := 15000
var boss_name := "THE GNOMON"
var attack_kind := "shadow_lance"

var state: int = State.DORMANT
var phase := 0
var hp := 0.0
var phase_hp_max := 0.0

var _timer := 0.0
var _attack_timer := ATTACK_FIRST_DELAY
var _tether_time := 0.0
var _tether_fx_cooldown := 0.0
var _plates: Array[MeshInstance3D] = []
var _plate_welded: Array[bool] = []
var _plate_probe: Array[Node3D] = []
var _pending_probes: Array[Node3D] = []
var _arm: SweepArm
var _core: MeshInstance3D
var _core_mat: StandardMaterial3D
var _hub_parts: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("apex")
	_build_mesh()
	# Seed phase 1 immediately so a dormant engine reports full strength rather
	# than reading as already dead to anything that inspects it before the wake.
	_begin_phase(0)
	_set_state(State.DORMANT)


# --- construction -----------------------------------------------------------

func _build_mesh() -> void:
	# Hub: a squat drum of dark plating with amber survey slits.
	for i in range(6):
		var ang := TAU * float(i) / 6.0
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.5, 0.9, 0.55)
		seg.mesh = bm
		seg.position = Vector3(cos(ang), 0, sin(ang)) * HUB_RADIUS
		seg.rotation.y = -ang
		seg.material_override = Palette.matte(Color(0.12, 0.11, 0.14))
		add_child(seg)
		_hub_parts.append(seg)

		var slit := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(1.1, 0.1, 0.08)
		slit.mesh = sm
		slit.position = Vector3(cos(ang), 0.3, sin(ang)) * HUB_RADIUS
		slit.rotation.y = -ang
		slit.material_override = Palette.emissive(Palette.AMBER, 1.6)
		add_child(slit)
		_hub_parts.append(slit)

	# Core: the thing you are actually shooting.
	_core = MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = CORE_RADIUS
	cm.height = CORE_RADIUS * 2.0
	cm.radial_segments = 16
	cm.rings = 10
	_core.mesh = cm
	_core_mat = Palette.emissive(Palette.THREAT, 2.0)
	_core.material_override = _core_mat
	_core.position.y = 0.5
	add_child(_core)

	# Iris plates: five wedges that read as open/shut from any zoom.
	for i in range(PLATE_COUNT):
		var ang := TAU * float(i) / float(PLATE_COUNT)
		var plate := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(1.5, 0.28, 1.9)
		plate.mesh = pm
		plate.position = Vector3(cos(ang), 0.5, sin(ang)) * 0.95
		plate.rotation.y = -ang
		plate.material_override = Palette.matte(Color(0.22, 0.2, 0.26))
		add_child(plate)
		_plates.append(plate)
		_plate_welded.append(false)
		_plate_probe.append(null)

	_arm = SweepArm.new()
	add_child(_arm)
	_arm.active = false
	# The hub obstacle is registered by SystemBuilder once this node has been
	# positioned — _ready runs before `position` is assigned.


# --- lifecycle --------------------------------------------------------------

func wake() -> void:
	if state != State.DORMANT:
		return
	phase = 0
	_begin_phase(0)
	_set_state(State.WAKING)
	_timer = WAKE_TIME

	var main := get_tree().get_first_node_in_group("main")
	var hud := get_tree().get_first_node_in_group("hud")
	var rig := get_tree().get_first_node_in_group("camera_rig")

	Sfx.play("boss_wake", 0.0)
	Sfx.play("alarm", -4.0)
	if hud and hud.has_method("show_toast"):
		hud.show_toast("SURVEY ENGINE WAKING", Palette.THREAT)
	if hud and hud.has_method("prompt"):
		hud.prompt("APEX CONTACT — %s" % boss_name)
	_attack_timer = WAKE_TIME + ATTACK_FIRST_DELAY
	if rig:
		rig.shake(0.05)

	# The wake-up is long, loud, and staged so it reads as an event rather than
	# an ambush: the player has WAKE_TIME to reposition or run.
	var tree := get_tree()
	for i in range(5):
		tree.create_timer(WAKE_TIME * (float(i) / 5.0)).timeout.connect(func() -> void:
			if not is_instance_valid(self):
				return
			FX.ring_pulse(get_parent(), global_position, Palette.THREAT, 3.0 + i * 1.6, 0.7)
			var r := get_tree().get_first_node_in_group("camera_rig")
			if r:
				r.shake(0.03 + i * 0.02)
			Sfx.play("plate", -8.0, 0.8 + i * 0.08)
		)


func reset_fight() -> void:
	# The player broke off (emergency warp). The engine powers down and returns
	# to full strength: failure costs tempo and progress, never salvage.
	if state in [State.DORMANT, State.DYING]:
		return
	for probe in _pending_probes:
		if is_instance_valid(probe):
			(probe as Node3D).queue_free()
	_pending_probes.clear()
	for i in range(PLATE_COUNT):
		_plate_welded[i] = false
		_plate_probe[i] = null
		_shut_plate(i)
	for p in get_tree().get_nodes_in_group("apex_probe"):
		if is_instance_valid(p):
			(p as Node3D).queue_free()

	_begin_phase(0)
	_set_state(State.DORMANT)
	_arm.active = false
	_tether_time = 0.0
	_attack_timer = ATTACK_FIRST_DELAY
	Sfx.play("plate", -5.0, 0.6)
	FX.ring_pulse(get_parent(), global_position, Palette.TEAL, 4.0, 0.9)


static func probes_for(phase_index: int, vent_index: int) -> int:
	# Pure, so the escalation table is assertable without waking a boss.
	var base := int((PHASES[clampi(phase_index, 0, PHASES.size() - 1)] as Dictionary)["probes"])
	return mini(base + maxi(vent_index, 0), PROBE_VENT_MAX)


func _begin_phase(index: int) -> void:
	phase = clampi(index, 0, PHASES.size() - 1)
	_phase_vents = 0
	var def: Dictionary = PHASES[phase]
	phase_hp_max = float(def["hp"]) * difficulty
	hp = phase_hp_max
	_arm.speed_deg = float(def["sweep"])
	_arm.blades = int(def["blades"])
	_arm.rebuild()


func _set_state(next: int) -> void:
	state = next
	_arm.active = state in [State.SURVEY, State.SEAL, State.PHASING]
	match state:
		State.SURVEY:
			add_to_group("hostiles")  # targetable only when it can be hurt
		State.DORMANT, State.DYING:
			if is_in_group("hostiles"):
				remove_from_group("hostiles")
		_:
			if not is_in_group("hostiles"):
				add_to_group("hostiles")


func _process(delta: float) -> void:
	if state in [State.DORMANT, State.DYING]:
		return

	_timer -= delta
	_core_mat.emission_energy_multiplier = 1.4 + damage_multiplier() * 2.6

	match state:
		State.WAKING:
			if _timer <= 0.0:
				_begin_survey()
		State.SURVEY:
			if _timer <= 0.0:
				_begin_seal()
		State.SEAL:
			if _timer <= 0.0:
				_begin_survey()
		State.PHASING:
			if _timer <= 0.0:
				_begin_survey()

	if state == State.SURVEY:
		_tick_attack(delta)
	elif _tether_time > 0.0:
		# A tether already latched keeps dragging through the seal — letting it
		# drop the instant the iris shuts would make it the weakest of the three.
		var player: Node3D = get_tree().get_first_node_in_group("player")
		if player != null:
			_tether_pull(player, ATTACKS.get(attack_kind, {}), delta)

	_sync_hud()


# --- SURVEY / SEAL cycle ----------------------------------------------------

func _begin_survey() -> void:
	_set_state(State.SURVEY)
	_timer = float(PHASES[phase]["window"])

	# Every probe that survived the seal now welds a plate shut for this window.
	var survivors := 0
	for probe in _pending_probes:
		if not is_instance_valid(probe):
			continue
		var slot := _free_plate()
		if slot < 0:
			break
		_weld_plate(slot, probe)
		survivors += 1
	_pending_probes.clear()

	for i in range(PLATE_COUNT):
		if not _plate_welded[i]:
			_open_plate(i)

	Sfx.play("plate", -3.0, 1.0)
	FX.ring_pulse(get_parent(), global_position, Palette.AMBER, 3.4, 0.6)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("prompt"):
		if survivors >= PLATE_COUNT:
			hud.prompt("IRIS SEALED — CLEAR THE PROBES")
		elif survivors > 0:
			hud.prompt("IRIS PARTIAL — %d PLATE(S) WELDED" % survivors)
		else:
			hud.prompt("IRIS OPEN — FULL EXPOSURE")


func _begin_seal() -> void:
	_set_state(State.SEAL)
	_timer = SEAL_TIME

	# Welds last one window only. Surviving welders let go, resume hunting, and
	# must be cleared again this seal or they re-weld. Without this the welds
	# accumulate permanently and a single bad window locks the rest of the fight
	# at the floor multiplier — a death spiral rather than a decision.
	for i in range(PLATE_COUNT):
		if _plate_welded[i]:
			var probe: Node3D = _plate_probe[i]
			_plate_welded[i] = false
			_plate_probe[i] = null
			if is_instance_valid(probe):
				if probe.has_method("undock"):
					probe.undock()
				_pending_probes.append(probe)
		_shut_plate(i)

	Sfx.play("plate", -3.0, 0.72)
	_vent_probes(probes_for(phase, _phase_vents))
	_phase_vents += 1

	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("prompt"):
		hud.prompt("VENTING PROBES")


func _vent_probes(count: int) -> void:
	var parent := get_parent()
	for i in range(count):
		var probe := SwarmHostile.new()
		probe.difficulty = PROBE_DIFFICULTY * difficulty
		probe.hp_scale = PROBE_HP_SCALE
		parent.add_child(probe)
		var ang := TAU * float(i) / float(maxi(count, 1)) + randf() * 0.3
		probe.global_position = global_position + Vector3(cos(ang), 0, sin(ang)) * (HUB_RADIUS + 0.8)
		probe.add_to_group("apex_probe")
		_pending_probes.append(probe)
		FX.flash(parent, probe.global_position, Palette.THREAT, 0.8, 0.2)


# --- the hub's own armament ---------------------------------------------------

func _armament_scale() -> float:
	return 1.0 + (difficulty - 1.0) * ATTACK_DIFFICULTY_SOFTENING


func _tick_attack(delta: float) -> void:
	var spec: Dictionary = ATTACKS.get(attack_kind, {})
	if spec.is_empty():
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null or bool(player.get("docked")):
		return

	# The tether is the one armament with a sustained effect.
	if _tether_time > 0.0:
		_tether_pull(player, spec, delta)

	_attack_timer -= delta
	if _attack_timer > 0.0:
		return
	# Out of range means out of the fight: a player who has disengaged to the
	# far side of the system is not sniped from across it.
	var flat: Vector3 = player.global_position - global_position
	flat.y = 0.0
	if flat.length() > float(spec.get("range", 15.0)):
		_attack_timer = 1.0     # re-check soon rather than a whole interval away
		return
	_attack_timer = float(spec.get("interval", 4.0))

	match attack_kind:
		"shadow_lance":
			_fire_shadow_lance(player, spec)
		"flare_mortar":
			_fire_flare_mortar(player, spec)
		"grav_tether":
			_fire_grav_tether(player, spec)


func _fire_shadow_lance(player: Node3D, spec: Dictionary) -> void:
	# The line is LOCKED at telegraph time — that is the whole attack. It fires
	# where you were, so any movement at all defeats it, and none at all does not.
	var origin := global_position
	var dir: Vector3 = player.global_position - origin
	dir.y = 0.0
	if dir.length() < 0.01:
		dir = Vector3.FORWARD
	dir = dir.normalized()
	var reach := float(spec.get("reach", 11.0))
	var tip := origin + dir * reach

	# Telegraph: a thin warning line, drawn twice so it reads as a countdown.
	var telegraph := float(spec.get("telegraph", 0.85))
	FX.beam(get_parent(), origin, tip, Color(Palette.THREAT.r, Palette.THREAT.g,
		Palette.THREAT.b, 0.35), 0.05, telegraph * 0.55)
	Sfx.play("tap", -8.0, 0.55)
	get_tree().create_timer(telegraph * 0.55).timeout.connect(func() -> void:
		if not is_instance_valid(self) or state in [State.DORMANT, State.DYING]:
			return
		FX.beam(get_parent(), origin, tip, Color(Palette.THREAT.r, Palette.THREAT.g,
			Palette.THREAT.b, 0.6), 0.08, telegraph * 0.45)
	)

	get_tree().create_timer(telegraph).timeout.connect(func() -> void:
		if not is_instance_valid(self) or state in [State.DORMANT, State.DYING]:
			return
		FX.beam(get_parent(), origin, tip, Palette.THREAT, 0.22, 0.18)
		FX.flash(get_parent(), tip, Palette.THREAT, 1.2, 0.16)
		Sfx.play("fire", -4.0, 0.5)
		var p: Node3D = get_tree().get_first_node_in_group("player")
		if p == null or not p.has_method("take_hit"):
			return
		# Distance from the player to the locked segment, on the play plane.
		var to_p: Vector3 = p.global_position - origin
		to_p.y = 0.0
		var along := clampf(to_p.dot(dir), 0.0, reach)
		var closest := origin + dir * along
		var off: Vector3 = p.global_position - closest
		off.y = 0.0
		if off.length() <= float(spec.get("width", 1.5)):
			p.take_hit(float(spec.get("damage", 13.0)) * _armament_scale(), self)
	)


func _fire_flare_mortar(player: Node3D, spec: Dictionary) -> void:
	# Shells lob onto where you ARE, staggered, each under a ground-ring
	# telegraph. One ring is a sidestep; three overlapping rings are a direction.
	var shells := int(spec.get("shells", 3))
	var scatter := float(spec.get("scatter", 1.6))
	var telegraph := float(spec.get("telegraph", 1.05))
	var radius := float(spec.get("radius", 2.3))
	for i in range(shells):
		get_tree().create_timer(i * 0.28).timeout.connect(func() -> void:
			if not is_instance_valid(self) or state in [State.DORMANT, State.DYING]:
				return
			var p: Node3D = get_tree().get_first_node_in_group("player")
			if p == null:
				return
			var target: Vector3 = p.global_position + Vector3(
				randf_range(-scatter, scatter), 0, randf_range(-scatter, scatter))
			target.y = 0.0
			# The telegraph ring shrinks onto the impact point — the countdown is
			# the picture, not a bar somewhere on the HUD.
			FX.ring_pulse(get_parent(), target, Palette.THREAT, radius, telegraph)
			Sfx.play("tap", -10.0, 0.5)
			get_tree().create_timer(telegraph).timeout.connect(func() -> void:
				if not is_instance_valid(self) or state in [State.DORMANT, State.DYING]:
					return
				FX.flash(get_parent(), target, Palette.WHITE_HOT, 1.6, 0.14)
				FX.burst(get_parent(), target, Color(1.0, 0.5, 0.2), 22, radius * 2.0, 0.18, 0.5)
				Sfx.play("explode", -12.0, 1.3)
				var p2: Node3D = get_tree().get_first_node_in_group("player")
				if p2 == null or not p2.has_method("take_hit"):
					return
				var off: Vector3 = p2.global_position - target
				off.y = 0.0
				if off.length() <= radius:
					p2.take_hit(float(spec.get("damage", 8.0)) * _armament_scale(), self)
			)
		)


func _fire_grav_tether(player: Node3D, spec: Dictionary) -> void:
	_tether_time = float(spec.get("duration", 2.8))
	Sfx.play("weld", -4.0, 0.7)
	FX.ring_pulse(get_parent(), player.global_position, Palette.TEAL, 1.8, 0.4)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("prompt"):
		hud.prompt("GRAVITON TETHER — BURN OUTWARD")


func _tether_pull(player: Node3D, spec: Dictionary, delta: float) -> void:
	_tether_time -= delta
	var inward: Vector3 = global_position - player.global_position
	inward.y = 0.0
	if inward.length() < HUB_RADIUS + 1.0:
		return          # already against the hull; the sweep arm takes it from here
	inward = inward.normalized()
	# Routed through PlayerShip's own drag channel, NOT through `velocity`.
	#
	# This was `player.velocity += inward * pull * delta`, and it dragged an idle
	# ship 0.0u for as long as it existed. PlayerShip integrates with
	# `velocity = velocity.move_toward(desired, accel * delta)`, and `desired` is
	# ZERO for a ship with no move target — so the autopilot brakes at `accel`
	# (9.0 bare, floored at 3.0 by ModuleDB), beats the 6.5 pull, and clamps the
	# velocity back to nothing before the position step runs. The comment that
	# used to sit here reasoned the tether "only wins against a player who is not
	# flying", which had the case exactly backwards: the ship that is not flying
	# is the one braking hardest, and it was the only ship the armament could not
	# move.
	#
	# `drag_cap` is a terminal speed rather than an acceleration, and it is the
	# escape guarantee: at 1.15 u/s it sits under the 1.6 u/s floor ModuleDB
	# clamps max_speed to, so the weakest legal fit still burns outward at a net
	# 0.45 u/s. The two velocities add, so thrust is still what beats this —
	# standing still is simply no longer thrust.
	if player.has_method("apply_tether"):
		player.apply_tether(inward, float(spec.get("pull", 6.5)),
			float(spec.get("drag_cap", 1.15)), delta)
	_tether_fx_cooldown -= delta
	if _tether_fx_cooldown <= 0.0:
		_tether_fx_cooldown = 0.12
		FX.beam(get_parent(), _core.global_position, player.global_position,
			Color(Palette.TEAL.r, Palette.TEAL.g, Palette.TEAL.b, 0.5), 0.05, 0.13)


# --- plates -----------------------------------------------------------------

func _free_plate() -> int:
	for i in range(PLATE_COUNT):
		if not _plate_welded[i]:
			return i
	return -1


func _open_plate(index: int) -> void:
	var ang := TAU * float(index) / float(PLATE_COUNT)
	var plate := _plates[index]
	var tw := plate.create_tween()
	tw.tween_property(plate, "position", Vector3(cos(ang), 0.5, sin(ang)) * 2.4, 0.45) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	plate.material_override = Palette.matte(Color(0.22, 0.2, 0.26))


func _shut_plate(index: int) -> void:
	var ang := TAU * float(index) / float(PLATE_COUNT)
	var plate := _plates[index]
	var tw := plate.create_tween()
	tw.tween_property(plate, "position", Vector3(cos(ang), 0.5, sin(ang)) * 0.95, 0.22) \
		.set_ease(Tween.EASE_IN)


func _weld_plate(index: int, probe: Node3D) -> void:
	# A welded plate is held shut by a probe that is still a live target: shoot
	# it off and the plate springs back open mid-window.
	_plate_welded[index] = true
	_plate_probe[index] = probe
	_shut_plate(index)
	_plates[index].material_override = Palette.emissive(
		Color(Palette.THREAT.r, Palette.THREAT.g, Palette.THREAT.b, 0.9), 1.8)

	var ang := TAU * float(index) / float(PLATE_COUNT)
	if is_instance_valid(probe):
		if probe.has_method("dock_at"):
			probe.dock_at(global_position + Vector3(cos(ang), 0.7, sin(ang)) * 1.5)
	Sfx.play("weld", -6.0, 1.0)
	FX.flash(get_parent(), global_position + Vector3(cos(ang), 0.7, sin(ang)) * 1.5,
		Palette.THREAT, 0.9, 0.25)


func _release_plate(index: int) -> void:
	if not _plate_welded[index]:
		return
	_plate_welded[index] = false
	_plate_probe[index] = null
	if state == State.SURVEY:
		_open_plate(index)
	var ang := TAU * float(index) / float(PLATE_COUNT)
	FX.ring_pulse(get_parent(), global_position + Vector3(cos(ang), 0.7, sin(ang)) * 1.5,
		Palette.GOLD, 1.3, 0.5)
	Sfx.play("plate", -6.0, 1.3)


func _check_welds() -> void:
	for i in range(PLATE_COUNT):
		if _plate_welded[i] and not is_instance_valid(_plate_probe[i]):
			_release_plate(i)


func open_plates() -> int:
	if state != State.SURVEY:
		return 0
	var open := 0
	for i in range(PLATE_COUNT):
		if not _plate_welded[i]:
			open += 1
	return open


func damage_multiplier() -> float:
	if state != State.SURVEY:
		return SEALED_MULTIPLIER
	# Linear: one weld costs one fifth of the window's value. A steeper curve was
	# tried and only punished the fits that were already behind — the real lever
	# was CORE_RANGE, not the shape of this function.
	return SEALED_MULTIPLIER + (1.0 - SEALED_MULTIPLIER) * (float(open_plates()) / float(PLATE_COUNT))


# --- damage -----------------------------------------------------------------

func take_damage(amount: float, _attacker: Node3D = null) -> void:
	# The engine takes the attacker for SIGNATURE COMPATIBILITY only, and the
	# underscore says so: it is the one combatant whose death is already
	# attributed by a different mechanism entirely (on_apex_defeated ->
	# mark_apex_down, and the first-kill bonus rides on cracking the wreck, a
	# second trip). The default is safe HERE and nowhere else — nothing but the
	# player has ever been able to damage an apex, and CORE_RANGE below is what
	# keeps it that way.
	if state in [State.DORMANT, State.WAKING, State.DYING]:
		FX.flash(get_parent(), global_position, Palette.TEAL, 1.0, 0.12)
		Sfx.play("hit", -18.0, 1.9)
		return

	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player != null:
		var flat: Vector3 = player.global_position - global_position
		flat.y = 0.0
		if flat.length() > CORE_RANGE:
			# Shots break on the survey field. Announced once, then it is simply
			# a rule the player can see: close in or do nothing.
			FX.flash(get_parent(), global_position + flat.normalized() * CORE_RANGE,
				Palette.TEAL, 0.8, 0.14)
			Sfx.play("hit", -19.0, 1.95)
			Barks.fire("apex_out_of_range")
			return

	_check_welds()
	var dealt := amount * damage_multiplier()
	hp -= dealt
	FX.flash(get_parent(), _core.global_position, Palette.WHITE_HOT, 0.7, 0.1)
	Sfx.play("hit", -9.0, 0.8 if state == State.SURVEY else 1.6)

	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.shake(0.01)

	if hp <= 0.0:
		if phase + 1 < PHASES.size():
			_advance_phase()
		else:
			_die()


func _advance_phase() -> void:
	_set_state(State.PHASING)
	_timer = PHASE_CHANGE_TIME
	_begin_phase(phase + 1)

	for probe in _pending_probes:
		if is_instance_valid(probe) and probe.has_method("take_damage"):
			# `self`, not the player: the engine is scrapping its own pending
			# probes on a phase change. Attributing them to the player would
			# pay loot and tick a kill_swarm contract for ships nobody shot.
			probe.take_damage(99999.0, self)
	_pending_probes.clear()
	for i in range(PLATE_COUNT):
		_plate_welded[i] = false
		_plate_probe[i] = null
		_shut_plate(i)

	var rig := get_tree().get_first_node_in_group("camera_rig")
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("hit_stop"):
		main.hit_stop(0.09, 0.25)
	if rig:
		rig.shake(0.18)
		rig.punch_zoom(-1.0)
	Sfx.play("phase", -2.0)
	FX.shockwave(get_parent(), global_position, Palette.THREAT, 9.0, 0.8)
	FX.burst(get_parent(), global_position, Color(1.0, 0.5, 0.2), 60, 9.0, 0.3, 0.8)

	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_toast"):
		hud.show_toast(String(PHASES[phase]["name"]), Palette.THREAT)


# --- death ------------------------------------------------------------------

func _die() -> void:
	_set_state(State.DYING)
	_arm.active = false
	hp = 0.0

	var parent := get_parent()
	var pos := global_position
	var tree := get_tree()

	for probe in _pending_probes:
		if is_instance_valid(probe) and probe.has_method("take_damage"):
			# `self`, not the player: the engine is scrapping its own pending
			# probes on a phase change. Attributing them to the player would
			# pay loot and tick a kill_swarm contract for ships nobody shot.
			probe.take_damage(99999.0, self)
	_pending_probes.clear()

	var main := tree.get_first_node_in_group("main")
	var rig := tree.get_first_node_in_group("camera_rig")
	if main and main.has_method("hit_stop"):
		main.hit_stop(0.16, 0.18)
	if rig:
		rig.shake(0.4)
		rig.punch_zoom(-2.0)
	Sfx.play("explode", 0.0, 0.65)
	FX.flash(parent, pos, Palette.WHITE_HOT, 5.0, 0.35)
	FX.shockwave(parent, pos, Palette.THREAT, 14.0, 1.0)

	# Stage 1: the arm shears off and tumbles away.
	var arm_tw := _arm.create_tween()
	arm_tw.set_parallel(true)
	arm_tw.tween_property(_arm, "position", _arm.position + Vector3(randf_range(-6, 6), -2.0, randf_range(-6, 6)), 1.4)
	arm_tw.tween_property(_arm, "rotation", _arm.rotation + Vector3(1.2, 3.0, 0.8), 1.4)
	arm_tw.tween_property(_arm, "scale", Vector3.ONE * 0.4, 1.4)

	# Stage 2: plates blow outward.
	tree.create_timer(0.25).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		for plate in _plates:
			var dir := Vector3(randf_range(-1, 1), randf_range(0.1, 0.7), randf_range(-1, 1)).normalized()
			var tw := plate.create_tween()
			tw.set_parallel(true)
			tw.tween_property(plate, "position", plate.position + dir * 5.0, 0.9)
			tw.tween_property(plate, "scale", Vector3.ONE * 0.1, 0.9)
		FX.burst(parent, pos, Color(1.0, 0.55, 0.15), 90, 13.0, 0.4, 1.0)
		Sfx.play("explode", -4.0, 0.9)
	)

	# Stage 3: the hub collapses.
	tree.create_timer(0.7).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		for part in _hub_parts:
			var dir := Vector3(randf_range(-1, 1), randf_range(-0.3, 0.4), randf_range(-1, 1)).normalized()
			var tw := part.create_tween()
			tw.set_parallel(true)
			tw.tween_property(part, "position", part.position + dir * 3.5, 1.0)
			tw.tween_property(part, "scale", Vector3.ONE * 0.05, 1.0)
		FX.burst(parent, pos, Palette.THREAT, 50, 8.0, 0.25, 0.9)
		FX.shockwave(parent, pos, Palette.AMBER, 10.0, 0.9)
		Sfx.play("explode", -6.0, 1.15)
	)

	# Stage 4: the core falls dark and becomes salvageable — the finale is the
	# game's signature hold-to-breach, so every derelict was a rehearsal.
	tree.create_timer(1.5).timeout.connect(func() -> void:
		if not is_instance_valid(self):
			return
		_become_wreck()
	)


func _become_wreck() -> void:
	if is_in_group("hostiles"):
		remove_from_group("hostiles")
	remove_from_group("apex")

	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("on_apex_defeated"):
		main.on_apex_defeated(self)

	_core_mat.emission_energy_multiplier = 0.6
	var tw := _core.create_tween()
	tw.tween_property(_core, "position:y", -0.2, 1.0).set_ease(Tween.EASE_OUT)

	var wreck := ApexWreck.new()
	wreck.loot_total = loot_total
	wreck.first_kill_bonus = first_kill_bonus
	wreck.system_id = String(main.system_id) if main else ""
	get_parent().add_child(wreck)
	wreck.global_position = global_position

	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("prompt"):
		hud.prompt("ENGINE DEAD — BREACH THE CORE")

	queue_free()


func safest_point(radius: float) -> Vector3:
	return _arm.safest_point(radius)


func hp_fraction() -> float:
	return clampf(hp / maxf(phase_hp_max, 1.0), 0.0, 1.0)


func _sync_hud() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.has_method("set_boss_status"):
		return
	_check_welds()
	hud.set_boss_status({
		"active": true,
		"name": boss_name,
		"phase": phase + 1,
		"phase_total": PHASES.size(),
		"hp": hp_fraction(),
		"open": open_plates(),
		"plates": PLATE_COUNT,
		"state": _state_label(),
	})


func _state_label() -> String:
	match state:
		State.WAKING: return "WAKING"
		State.SURVEY: return "IRIS OPEN"
		State.SEAL: return "SEALED"
		State.PHASING: return "RECONFIGURING"
	return ""
