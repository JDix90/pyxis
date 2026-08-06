class_name SwarmHostile
extends Node3D
# Fast, fragile strafer that hunts in packs. The counterpart to the tanky
# sentry: Arc chains delete these, Lance wastes its cycle on them.
#
# --- FEEL CONSTANTS ---
const MAX_SPEED := 7.5
const ACCEL := 16.0
const ORBIT_RADIUS := 3.2
const SEPARATION := 1.8
const SEPARATION_FORCE := 9.0
const ATTACK_RANGE := 3.6
const FIRE_INTERVAL := 1.5
const DAMAGE := 5.0
# Two, not three: swarms are the most farmable thing in the game because they
# respawn on a timer, so they are the first place an economy rebalance has to
# bite. The pack still reads as a payout; it just is not the best salvage per
# minute in the system any more.
const LOOT_COUNT := 2
const MAX_HP := 34.0

var difficulty := 1.0  # scales damage dealt; set by the spawner before _ready
var hp_scale := 1.0    # scales HP independently, so apex probes can be tough
                       # without also hitting like a sentry
var hp := MAX_HP

# Set by the spawner before _ready to repaint the hull. Interdiction raiders fly
# the same airframe as a survey-field swarm — they are a different faction, not a
# different ship — so the tell has to be colour, and it has to be legible at a
# glance on a phone. Crimson reads as "this one wants your cargo".
var tint := Color(0.0, 0.0, 0.0, 0.0)
# Raiders carry what they have already taken from somebody else.
var drop_good := ""

# How far the player can get before this one gives up and is gone. 0 = never give
# up, which is every hostile the charted systems build, so nothing that shipped
# before this changes by a hair.
#
# It exists for the expanse. A swarm does 7.5 against the player's 5.75, so it
# cannot be outrun — inside a system that is correct, because a system has edges
# and a station to reach. Out in the deep there are no edges: a nest picked up 400
# units out would simply follow you the whole way home and be waiting at the
# Anchor. DeepSpace sets 140 on everything it seeds.
var despawn_radius := 0.0

# Apex probes dock onto the Gnomon's shell and hold a plate shut. A docked probe
# stops hunting but stays a live target, so shooting it off reopens the plate.
var docked := false
var _dock_point := Vector3.ZERO

# Which flag this airframe flies (v18, Horizon 4 stage 1). Same contract and
# same default as Hostile.faction: set before add_child, FERAL unless a
# spawner says otherwise, and FERAL is the shipped world exactly.
var faction := FactionDB.FERAL
var _enemies: Array = []
var _enemies_version := -1
var _aggro: Node3D = null
var _target: Node3D = null
var _retarget_t := 0.0
const RETARGET_INTERVAL := 0.4
# The skirmish clock, same contract and same constants as Hostile's — see
# FactionDB.SKIRMISH_TIME. A dart needs it as much as a sentry does: a picket
# kills one in 2.8s, but a six-dart wave kills a PICKET in about six, so
# without a break-off the Cordon would simply be ground down by the waves it
# was posted to stop.
var _skirmish := 0.0
var _skirmish_rest := 0.0
# The grudge, same contract and same constant as Hostile's — FactionDB.GRUDGE_TIME
# carries the reasoning. A dart needs it for the case a sentry does not: a convoy
# hauler is a SwarmHostile, and a convoy is the commonest thing an OVERCHARGE
# discharge catches by accident.
var _grudge := 0.0

# --- the march (v18, stage 4) ------------------------------------------------
# WHERE THIS SHIP IS GOING, if it is going anywhere. Vector3.ZERO means "not
# marching", which is every dart that has ever existed — so the whole mode is
# inert by construction for waves, raiders, nests and apex probes.
#
# This is the FIRST NON-ORBIT MOVEMENT this class has had. Everything else it
# does is expressed relative to a target it is circling; a column crossing the
# Shoals toward the chart edge is expressed relative to a place, and ignores
# whoever it passes until something shoots at it.
var march_to := Vector3.ZERO
# How near the destination counts as arrived. Generous: the column is dozens of
# ships wide and the point is the crossing, not the parking.
const MARCH_ARRIVE := 6.0
# Marching speed. MAX_SPEED is 7.5, which crosses 75u in ten seconds — the
# whole event would be over before the warning broadcast finished reading. At
# 2.8 the column takes ~27s to reach the line, which is long enough to fly out
# and meet it, or to watch it come.
const MARCH_SPEED := 2.8

# Whether this ship belongs to a muster column. Kept separate from `march_to`
# because a column ship that has ARRIVED (march_to cleared) is still a muster
# ship for as long as it lives — it is what the census counts and what the
# payout ban keys on.
var muster := false

var _velocity := Vector3.ZERO
var _fire_cooldown := 0.0
# Seconds of parley standoff remaining. While positive the pack keeps its orbit
# distance and HOLDS FIRE — raiders spawned 17u out at 7.5u/s would otherwise be
# shooting ~2.3s after the klaxon, before the demand can even be read, and 14
# says being jumped must be something you could have reacted to.
var standoff := 0.0
var _departing := false
var _orbit_dir := 1.0
var _phase := 0.0
var _dying := false
var _core_mat: StandardMaterial3D


func _ready() -> void:
	# Integrates on the fixed tick like the player, so it opts into interpolation
	# for the same reason. Its sentry cousins in hostile.gd move in _process and
	# deliberately do not. See project.godot's [physics] comment.
	physics_interpolation_mode = Node.PHYSICS_INTERPOLATION_MODE_ON
	add_to_group("hostiles")
	# See Hostile._ready: the allegiance-aware pool, kept apart from "hostiles"
	# because that name means "opposed to the player" everywhere it is read.
	add_to_group("combatants")
	add_to_group("swarm")
	hp = MAX_HP * difficulty * hp_scale
	_orbit_dir = 1.0 if randf() < 0.5 else -1.0
	_phase = randf() * TAU
	_fire_cooldown = randf_range(0.3, FIRE_INTERVAL)
	_build_mesh()


func _build_mesh() -> void:
	# Small dart: a swept body with a bright cyan-magenta eye.
	var body := MeshInstance3D.new()
	var bm := PrismMesh.new()
	bm.size = Vector3(0.34, 0.14, 0.62)
	body.mesh = bm
	body.rotation_degrees = Vector3(-90, 0, 0)
	body.material_override = Palette.matte(_hull_color(Color(0.2, 0.17, 0.24)))
	add_child(body)

	for side in [-1.0, 1.0]:
		var wing := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.34, 0.05, 0.12)
		wing.mesh = wm
		wing.position = Vector3(side * 0.24, 0, 0.16)
		wing.rotation.y = side * 0.35
		wing.material_override = Palette.matte(_hull_color(Color(0.14, 0.13, 0.18)))
		add_child(wing)

	var eye := MeshInstance3D.new()
	var em := SphereMesh.new()
	em.radius = 0.1
	em.height = 0.2
	em.radial_segments = 8
	em.rings = 4
	eye.mesh = em
	eye.position = Vector3(0, 0.02, -0.24)
	_core_mat = Palette.emissive(tint if tint.a > 0.0 else Palette.THREAT, 3.0)
	eye.material_override = _core_mat
	add_child(eye)


func _hull_color(base: Color) -> Color:
	# Blend rather than replace, so a raider still reads as the same airframe
	# with different paint instead of as a new enemy type.
	if tint.a <= 0.0:
		return base
	return base.lerp(tint, 0.62)


func dock_at(point: Vector3) -> void:
	docked = true
	_dock_point = point
	_velocity = Vector3.ZERO


func undock() -> void:
	docked = false


func _physics_process(delta: float) -> void:
	if _dying:
		return

	if docked:
		# Clamped to the shell, still shootable, still visibly menacing.
		global_position = global_position.lerp(_dock_point, clampf(9.0 * delta, 0.0, 1.0))
		_phase += delta * 5.0
		rotation.y += delta * 2.0
		_core_mat.emission_energy_multiplier = 3.0 + sin(_phase * 3.0) * 1.2
		return

	# BEFORE the target lookup, not after. A departing raider has already shed
	# every group and is pure theater — deciding its exit on whether it can
	# still find something to hate would make the burn-out stutter into a drift
	# the moment the player docked, which is precisely when a paid-off raid
	# ends.
	if _departing:
		# Burning out. Groups are already shed, so the raid is already over; this
		# is theater, and brief.
		global_position += _velocity * delta
		return

	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return
	# THE GRUDGE RUNS DOWN BEFORE THE TARGET IS PICKED, so the frame it expires
	# is a frame this ship is already not hunting the player. See Hostile.
	if _grudge > 0.0:
		_grudge = maxf(_grudge - delta, 0.0)
		if _grudge <= 0.0:
			_release_grudge()
	var target := _combat_target(delta)

	# THE MARCH. Held until something is actually in reach: a column crossing
	# empty space walks, and only stops walking when a fight arrives. Checked
	# against ATTACK_RANGE rather than "has a target", because _combat_target
	# returns the nearest hated thing at ANY distance — a column that halted the
	# moment it could see the far side of the line would never cross at all.
	if march_to != Vector3.ZERO:
		# THE LEASH APPLIES TO A MARCHER TOO — checked HERE because the march
		# step returns before the leash check below, so a leashed dart that was
		# walking a beat never reached it and marched forever after the player
		# left. Invisible for three stages because the only marchers were
		# muster ships, which carry NO leash by design (the event ends the
		# event); convoy darts are the first leashed marchers, and AND THE
		# LEASH CLEANS IT UP counted 4 of them still walking an empty sky.
		# Inside the march branch rather than hoisted above it, so the shipped
		# drift path (docked player, no target, no despawn) stays word for
		# word what it was.
		if despawn_radius > 0.0 and Vector3(
				player.global_position.x - global_position.x, 0.0,
				player.global_position.z - global_position.z).length() > despawn_radius:
			_give_up()
			return
		var engaged: bool = target != null \
			and global_position.distance_to(target.global_position) <= ATTACK_RANGE * 2.0
		if not engaged:
			_march_step(delta)
			return
	if target == null:
		# Nothing this flag hates is in reach — which for a FERAL dart means the
		# player is docked, and this is the shipped "a docked ship is not prey"
		# drift, word for word.
		_velocity = _velocity.move_toward(Vector3.ZERO, ACCEL * 0.5 * delta)
		global_position += _velocity * delta
		return

	# THE LEASH STAYS ON THE PLAYER whatever the target is. despawn_radius
	# exists so a pack picked up 400u out is not waiting at the Anchor when the
	# player flies home (see the field comment) — it is about litter following
	# the AUDIENCE, not about whoever the pack is currently shooting.
	var player_dist := Vector3(player.global_position.x - global_position.x, 0.0,
		player.global_position.z - global_position.z).length()
	if despawn_radius > 0.0 and player_dist > despawn_radius:
		_give_up()
		return

	var to_target := target.global_position - global_position
	to_target.y = 0.0
	var dist := to_target.length()

	# Seek to orbit distance, strafe around it, and shove off siblings so the
	# pack spreads instead of stacking into one dot.
	var standoff_hold := standoff > 0.0
	if standoff_hold:
		standoff -= delta

	var desired := Vector3.ZERO
	if dist > 0.01:
		var radial := to_target.normalized() * (dist - ORBIT_RADIUS)
		var tangent := Vector3(-to_target.z, 0, to_target.x).normalized() * _orbit_dir
		desired = (radial + tangent * 2.2).normalized() * MAX_SPEED

	var push := Vector3.ZERO
	for other in get_tree().get_nodes_in_group("swarm"):
		if other == self or not is_instance_valid(other):
			continue
		var away: Vector3 = global_position - (other as Node3D).global_position
		away.y = 0.0
		var d := away.length()
		if d < SEPARATION and d > 0.01:
			push += away.normalized() * (SEPARATION - d) / SEPARATION
	desired += push * SEPARATION_FORCE

	# Weave so the pack never flies in a clean circle.
	_phase += delta * 3.0
	desired += Vector3(cos(_phase), 0, sin(_phase)) * 1.2

	_velocity = _velocity.move_toward(
		Obstacles.steer(global_position, desired.limit_length(MAX_SPEED), 0.4),
		ACCEL * delta)
	global_position += _velocity * delta
	global_position.y = 0.0
	global_position = Obstacles.resolve(global_position, 0.4)

	if _velocity.length() > 0.2:
		rotation.y = lerp_angle(rotation.y, atan2(-_velocity.x, -_velocity.z), 10.0 * delta)

	_core_mat.emission_energy_multiplier = 2.4 + sin(_phase * 2.0) * 0.6

	_fire_cooldown -= delta
	if standoff_hold:
		return
	if dist <= ATTACK_RANGE and _fire_cooldown <= 0.0 \
			and Obstacles.blocked(global_position, target.global_position) == null:
		_fire_cooldown = FIRE_INTERVAL
		FX.beam(get_parent(), global_position, target.global_position, Palette.THREAT, 0.035, 0.1)
		Sfx.play("fire", -18.0, 1.5)
		if target.has_method("take_hit"):
			# THE HOLLOWING'S TELL. Its fire cannot take the last point of
			# shield, so it strips a ship to a sliver and CANNOT finish it.
			# You do not die to the Hollowing; you arrive somewhere with
			# nothing left between you and whatever is there. It breaks the
			# game's most basic convention — a weapon that can kill you —
			# while staying perfectly telegraphed, which is §13's rule applied
			# to something that is meant to feel wrong.
			#
			# MINUS ONE, and the one is load-bearing. This ship has no hull:
			# `shield` IS its health and PlayerShip.take_hit downs you at
			# `shield <= 0.0`. Clamping to the shield REMAINING would land
			# exactly on zero and kill — which is what the first version of
			# this did, written against a two-layer health model this game has
			# never had. The assertion below caught it by crashing on a `hull`
			# property that does not exist.
			var out := DAMAGE * difficulty
			if faction == "unknown_b" and "shield" in target:
				out = minf(out, maxf(float(target.shield) - 1.0, 0.0))
			if out > 0.0:
				target.take_hit(out, self)
		elif target.has_method("take_damage"):
			target.take_damage(DAMAGE * difficulty, self)


func _march_step(delta: float) -> void:
	# Goal-directed, expressed as a target position and clamped to the remaining
	# distance — §13's rule, and the same shape Hostile._walk_beat uses, so the
	# two movement modes in this codebase read alike.
	var step := march_to - global_position
	step.y = 0.0
	if step.length() <= MARCH_ARRIVE:
		# Arrived. It stops marching and becomes an ordinary hostile holding the
		# ground it took, which is what makes "the line broke" a state rather
		# than a scripted outcome.
		march_to = Vector3.ZERO
		return
	var want := step.normalized() * MARCH_SPEED
	_velocity = _velocity.move_toward(Obstacles.steer(global_position, want, 0.4),
		ACCEL * delta)
	global_position += _velocity * delta
	global_position.y = 0.0
	global_position = Obstacles.resolve(global_position, 0.4)
	if _velocity.length() > 0.2:
		rotation.y = lerp_angle(rotation.y, atan2(-_velocity.x, -_velocity.z), 10.0 * delta)
	_phase += delta * 3.0
	_core_mat.emission_energy_multiplier = 2.4 + sin(_phase * 2.0) * 0.6



func fights_the_player() -> bool:
	# WHAT THE "hostiles" GROUP MEANT ALL ALONG. Both hostile classes join that
	# group unconditionally in _ready and cannot stop -- it is load-bearing in a
	# dozen places that read it as "things opposed to the player". What CAN move
	# is the handful of consumers that use it to decide what the player may
	# shoot, lock, or hear threat music for.
	#
	# THE SECOND CLAUSE IS WHY THE STANDING RAMP STILL WORKS. A machine the
	# player has chosen to attack ANSWERS, and the moment it does it is an
	# ordinary target again: tappable, auto-targetable, worth the music. Without
	# it a deliberate attack on a neutral would produce return fire the player
	# could not lock on to, which is a worse world than the one this fixes.
	if GameState.faction_band(faction, FactionDB.SURVEYOR) == FactionDB.Band.HOSTILE:
		return true
	var p := get_tree().get_first_node_in_group("player")
	return p != null and (_target == p or _aggro == p)


func marker_color() -> Color:
	# Mirrors Hostile.marker_color, which carries the reasoning. Kept as a copy
	# rather than hoisted for the same reason fights_the_player and provoke are
	# copies: these two classes share a contract, not a base class, and a shared
	# helper would put a third file between the radar and the answer.
	#
	# A DART NEEDS THIS MORE THAN A SENTRY DOES. A convoy escort spawned without
	# an explicit tint renders THREAT red at the mesh (this class has no
	# tint_of fallback in _ready, unlike Hostile) — so on the board it was red
	# twice over.
	if GameState.hostile_to_player(self):
		return Palette.THREAT
	var c := FactionDB.tint_of(faction)
	if c.a > 0.0:
		return c
	return tint if tint.a > 0.0 else Palette.HULL


func current_goal() -> Vector3:
	# See Hostile.current_goal. A dart's goal is its march order; a dart with no
	# march is orbiting something and is not "bound" anywhere worth reporting.
	if march_to == Vector3.ZERO:
		return Vector3.INF
	return march_to


func provoke(who: Node3D) -> void:
	# Same contract as Hostile.provoke, which carries the reasoning: aggro with
	# an expiry, never a band. A provoked dart needs no beat exception — its
	# whole movement model is "orbit whatever _target holds", so pointing it at
	# the player IS the convergence.
	if _dying or who == null or not is_instance_valid(who):
		return
	_aggro = who
	_grudge = FactionDB.GRUDGE_TIME


func _release_grudge() -> void:
	# The pointers, not just the clock — see Hostile._release_grudge for what
	# clearing one without the other reproduces.
	var p := get_tree().get_first_node_in_group("player")
	if p == null:
		return
	if _aggro == p:
		_aggro = null
	if _target == p:
		_target = null


func _refresh_enemies() -> void:
	if _enemies_version == GameState.faction_version:
		return
	_enemies_version = GameState.faction_version
	_enemies = GameState.enemies_of(faction)


func _targetable(n) -> bool:
	# Untyped for the same reason as Hostile._targetable — see the note there.
	# A typed Node3D parameter crashes on a cached target that has since been
	# freed, at the call boundary, before the validity check can run.
	if not is_instance_valid(n) or not (n as Node3D).is_inside_tree():
		return false
	if n.is_in_group("player"):
		return not n.docked
	# A docked apex probe is still a live target — shooting it off reopens the
	# plate — so `docked` is checked only on the player, whose docking is the
	# game's one safe state.
	return n.is_in_group("combatants")


func _combat_target(delta: float) -> Node3D:
	# The skirmish clock, wrapping the picker — Hostile._combat_target carries
	# the full reasoning. One timer over every path that can return an NPC.
	if _skirmish_rest > 0.0:
		_skirmish_rest -= delta
	var picked := _pick_target(delta)
	if picked == null or picked.is_in_group("player"):
		_skirmish = maxf(_skirmish - delta, 0.0)
		return picked
	# THE CLOCK COUNTS FIRE, NOT ACQUISITION — Hostile._combat_target carries the
	# reasoning and the measurement. ATTACK_RANGE here rather than ENGAGE_RANGE
	# because that is this class's weapon: a dart closing from eighty units out
	# is travelling, not fighting, and must not spend its six seconds doing it.
	if global_position.distance_to(picked.global_position) > ATTACK_RANGE:
		_skirmish = maxf(_skirmish - delta, 0.0)
		return picked
	_skirmish += delta
	if _skirmish >= FactionDB.SKIRMISH_TIME:
		_skirmish = 0.0
		_skirmish_rest = FactionDB.SKIRMISH_REST
		_aggro = null
		_target = null
		return null
	return picked


func _pick_target(delta: float) -> Node3D:
	# See Hostile._pick_target: aggro, then nearest hated flag, cached between
	# scans. For a FERAL dart the enemy list is [surveyor] and this returns the
	# player and walks nothing — the shipped behaviour, restated.
	_refresh_enemies()
	if _targetable(_aggro):
		return _aggro
	_aggro = null

	_retarget_t -= delta
	if _targetable(_target) and _retarget_t > 0.0:
		return _target
	_retarget_t = RETARGET_INTERVAL

	var best: Node3D = null
	var best_d := INF
	var hates_player := _enemies.has(FactionDB.SURVEYOR)
	if hates_player:
		var p: Node3D = get_tree().get_first_node_in_group("player")
		if _targetable(p):
			best = p
			best_d = global_position.distance_to(p.global_position)
	if _skirmish_rest > 0.0:
		_target = best
		return best
	if _enemies.size() > (1 if hates_player else 0):
		for n_v in get_tree().get_nodes_in_group("combatants"):
			var n := n_v as Node3D
			if n == self or not _targetable(n):
				continue
			if not _enemies.has(n.faction):
				continue
			var d := global_position.distance_to(n.global_position)
			if d < best_d:
				best_d = d
				best = n
	_target = best
	return best


func take_damage(amount: float, attacker: Node3D) -> void:
	# `attacker` required, no default — HORIZON-4 finding A1. See
	# Hostile.take_damage for why neither default is safe.
	if _dying:
		return
	# Shooting a raider IS the answer to the demand. The whole pack drops the
	# standoff together, or the player fights one raider while three watch.
	if standoff > 0.0 and is_in_group("raider"):
		var m := get_tree().get_first_node_in_group("main")
		if m and m.has_method("break_parley"):
			m.break_parley()
	if attacker != null and attacker != self \
			and (not ("faction" in attacker) or String(attacker.faction) != faction):
		_aggro = attacker
	# AND ITS FRIENDS SAW IT — see Hostile.take_damage for the whole argument,
	# including why this asks the BAND rather than hostile_to_player().
	if attacker != null and is_instance_valid(attacker) \
			and attacker.is_in_group("player") \
			and GameState.faction_band(faction, FactionDB.SURVEYOR) \
				!= FactionDB.Band.HOSTILE:
		var witness := get_tree().get_first_node_in_group("main")
		if witness != null and witness.has_method("witness_attack"):
			witness.witness_attack(self, faction, attacker)
	hp -= amount
	# THE AMBIENT FLOOR. Fire from another machine wears this one down but can
	# never finish it — see FactionDB.SKIRMISH_HP_FLOOR. Applied to the RESULT
	# rather than to the damage, so a machine already below the floor when the
	# player leaves it there is not quietly healed by being shot at.
	# Gated on COMBATANTS, not on "is not the player". The distinction matters:
	# ApexBoss scraps its own pending probes with take_damage(99999, self) on a
	# phase change, and the boss is in "hostiles" but not "combatants" — so a
	# "not the player" test would floor those probes at half hull and leave them
	# alive through the phase they were supposed to be cleared by.
	# THE SET-PIECE EXEMPTION. The ambient floor exists so the world does not
	# empty itself unwatched — but a muster is announced, bounded, cleaned up
	# after, and SUPPOSED to resolve. A line that could not be broken and a
	# column that could not be stopped would be two crowds of machines shooting
	# each other forever, which is the opposite of a set-piece.
	if attacker != null and is_instance_valid(attacker) \
			and attacker.is_in_group("combatants") and not muster:
		hp = maxf(hp, MAX_HP * difficulty * hp_scale * FactionDB.SKIRMISH_HP_FLOOR)
	FX.flash(get_parent(), global_position, Palette.WHITE_HOT, 0.4, 0.08)
	Sfx.play("hit", -15.0, 1.4)
	if hp <= 0.0:
		_die(attacker)


func depart() -> void:
	# The paid exit. Removes from every group IMMEDIATELY — _count_raiders() is
	# what ends a raid, and a pack that merely flew away would leave _raid_active
	# true forever, silently bricking the interdiction system for the session.
	# Group removal now is also what makes pay-then-kill impossible: a departing
	# raider is not a hostile, drops nothing, and pays nothing back.
	if _dying or _departing:
		return
	_departing = true
	drop_good = ""
	remove_from_group("hostiles")
	remove_from_group("combatants")
	remove_from_group("swarm")
	remove_from_group("raider")
	var away := global_position - _last_player_pos()
	away.y = 0.0
	if away.length() < 0.1:
		away = Vector3(1, 0, 0)
	_velocity = away.normalized() * MAX_SPEED * 1.6
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.1, 1.8).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _last_player_pos() -> Vector3:
	var p: Node3D = get_tree().get_first_node_in_group("player")
	return p.global_position if p else Vector3.ZERO


func _give_up() -> void:
	# NOT a kill. No loot, no credit, no bang — breaking off contact has to be
	# worth nothing, or the leash becomes a way to farm packs by running away.
	_dying = true
	remove_from_group("hostiles")
	remove_from_group("combatants")
	remove_from_group("swarm")
	remove_from_group("raider")
	queue_free()


func _die(attacker: Node3D) -> void:
	_dying = true
	var parent := get_parent()
	var pos := global_position
	remove_from_group("hostiles")
	remove_from_group("combatants")
	remove_from_group("swarm")

	FX.flash(parent, pos, Palette.WHITE_HOT, 1.1, 0.14)
	FX.burst(parent, pos, Color(1.0, 0.5, 0.2), 22, 6.0, 0.16, 0.45)
	Sfx.play("explode", -14.0, 1.55)
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.shake(0.03)

	# ATTRIBUTION GATES THE PAYOUT, never the theater — see Hostile._die.
	var player_kill := attacker != null and is_instance_valid(attacker) \
		and attacker.is_in_group("player")
	# WHAT A KILL IS WORTH, and it is three questions rather than one.
	#
	# 1. Did the PLAYER do it — stage 1's attribution rule.
	# 2. Was this thing HOSTILE TO THE PLAYER? Stage 2a put Cordon pickets in
	#    charted space, and stage 1's gate alone would have paid 2 crates and
	#    a kill_swarm contract tick for shooting one. Pickets never return fire
	#    (the WARY floor) and REBUILD ON EVERY _load_system — so warping out and
	#    back would have minted a fresh row of non-retaliating piñatas on demand.
	#    That is §27's deep-hulk printer with a badge on, and it shipped in 2a.
	# 3. Is this a MUSTER ship? The muster carries nothing by design
	#    (HORIZON-4 §8): PACING_LOOP sits at 97% of its ceiling and a recurring
	#    event that paid would be recurring income whatever it was called.
	var was_hostile := GameState.faction_band(faction, FactionDB.SURVEYOR) \
		== FactionDB.Band.HOSTILE
	var pays := player_kill and was_hostile and not muster
	# Shooting something that was not shooting at you is noticed, even when it
	# pays nothing. The GSA floor bounds how far this can go, so the Cordon can
	# resent the player without ever opening fire on them.
	if player_kill and not was_hostile and not muster:
		GameState.shift_faction(FactionDB.SURVEYOR, faction, -1)

	var main := get_tree().get_first_node_in_group("main")
	if player_kill and main and main.has_method("report_kill"):
		# A kill that does not pay reports its own kind — see Hostile._die for
		# the whole argument. "kill_muster" and "kill_neutral" are keys nothing
		# in contract_db asks for, so a convoy hauler or a muster column ship
		# cannot fill `sweep_swarm` (840 for six) the way a hostile swarm does.
		var kind := "swarm"
		if muster:
			kind = "muster"
		elif not pays:
			kind = "neutral"
		main.report_kill(kind)
	# AND WHOEVER THIS WAS SHOOTING AT MAY OWE THE PLAYER FOR IT. Read here
	# because _aggro and _target are still valid -- the group removals above
	# touch neither -- and gone a frame later.
	if player_kill and main and main.has_method("credit_defence"):
		# BOTH FIELDS, IN THIS ORDER, and the order is the whole point. Shooting
		# this ship set _aggro to the PLAYER -- that is what take_damage does --
		# so reading _aggro first would credit the player's own convoy_id, which
		# does not exist, and no favour would ever be recorded. _target is the
		# field that still holds whatever it was hunting, because _pick_target
		# returns an aggro node early without overwriting it.
		#
		# Called twice rather than chosen between: note_convoy_defended is
		# bounded per convoy per session, so a double call cannot double-pay,
		# and the alternative is a conditional that has to stay true about
		# which field means what.
		main.credit_defence(_target)
		main.credit_defence(_aggro)
	if not pays:
		queue_free()
		return

	# A raider drops what it stole; a survey-field swarm rolls the usual table.
	var crate := drop_good if drop_good != "" else CommodityDB.roll_drop("swarm")
	for i in range(LOOT_COUNT):
		var spot := pos + Vector3(randf_range(-0.3, 0.3), 0.1, randf_range(-0.3, 0.3))
		if main:
			main.spawn_loot(parent, spot, crate if i == 0 else "")
	queue_free()
