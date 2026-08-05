class_name Hostile
extends Node3D
# Automated sentry: drifts near its post, telegraphs then fires on the player,
# and dies in a staged sequence (hitstop + flash + shockwave -> fireball ->
# secondary burst + loot spill).
#
# --- FEEL CONSTANTS ---
const ENGAGE_RANGE := 9.0
const FIRE_INTERVAL := 1.15
const TELEGRAPH := 0.4
const DAMAGE := 14.0
const LOOT_COUNT := 14
const DEATH_STAGE_2 := 0.10
const DEATH_STAGE_3 := 0.38

# Base hull before any scaling. A const rather than three literals so a harness
# can compute what a guard SHOULD have from the same number the class uses,
# instead of restating it and drifting.
const BASE_HP := 120.0

var difficulty := 1.0  # set by SystemBuilder before the node enters the tree
# Scales HP independently of `difficulty`, which scales BOTH hp and damage. The
# two have to come apart for deep guards: a machine standing 1100u from the
# nearest dock, with no station to run to and no regen window, has to be a WALL
# rather than a harder puncher. On one dial the only way to make it tanky is to
# make its shot lethal — at the swarm curve's 2.6 a Quiet guard would hit for
# 36.4 against PYX-03's authored sentries at 30.8, which is exactly backwards.
# Defaults to 1.0, so every authored sentry is untouched.
var hp_scale := 1.0

var hp := 120.0
var max_hp := 120.0

# See SwarmHostile.despawn_radius. 0 = never give up, which is every authored
# sentry. A sentry does not chase, but one left standing 600u out in the expanse
# after the player has flown home is still litter that nothing would ever clear.
var despawn_radius := 0.0

# Set by the spawner BEFORE add_child (_build_mesh runs in _ready), same contract
# as SwarmHostile.tint. A deep guard is the same machine as a charted sentry
# standing somewhere else, so the tell is paint rather than a new silhouette.
var tint := Color(0.0, 0.0, 0.0, 0.0)
# What the scanner can still tell you about this thing. Empty on every authored
# sentry: on the chart you know perfectly well what a picket is.
var designation := ""
# Parley standoff, mirroring SwarmHostile: positive means hold fire.
var standoff := 0.0

# Which flag this machine flies (v18, Horizon 4 stage 1). Set by the spawner
# BEFORE add_child, same contract as tint/difficulty. The default is FERAL —
# the dead frontier's unflagged automata, HOSTILE to the surveyor and
# indifferent to everything else — which is the shipped world stated as data,
# so every existing spawner is untouched by construction.
var faction := FactionDB.FERAL

# --- the beat (v18, Horizon 4 stage 2a) --------------------------------------
# Absolute world waypoints. Set by the spawner before add_child, like tint and
# faction. EMPTY on every machine that shipped before the Cordon, and empty
# means "hold station and drift" — the behaviour every authored sentry has
# always had — so this whole block is inert for sentries by construction.
#
# The route is a LOOP: after the last waypoint comes the first. A ping-pong
# route needs a direction flag and an end-detection branch to say the same
# thing on screen.
var patrol: Array[Vector3] = []
# How fast a picket walks its beat. Deliberately under the player's 5.75 and
# well under a swarm's 7.5: a patrol is a presence, not a pursuer, and one that
# could run the player down would be a second raider wearing a badge.
const PATROL_SPEED := 3.2
# How near counts as arrived. Larger than it looks because the drift is applied
# on top, so a tighter radius makes a picket jitter at a corner instead of
# turning it.
const PATROL_ARRIVE := 1.6
# How far off its route a picket will step to engage, and how far a target may
# get before it gives up and resumes. The GAP between them is hysteresis — the
# same reason the apex has WAKE 60 against LEASH 120. Without it a contact
# sitting near the boundary flickers a picket between engaging and walking off
# every frame.
const PATROL_ENGAGE := 12.0
const PATROL_RELEASE := 25.0

var _patrol_i := 0

# --- the beat a STANDING machine walks (v18, playtest round 4) ----------------
# How far a station-keeping sentry orbits its post. 0 means "hold exactly", which
# is every machine in the game except the authored garrison — see the opt-in
# argument in _process. Set by the spawner before add_child, like `patrol`.
var beat_radius := 0.0
# The radius the sentry spawner uses, as a const so SENTRY POSTS can compute the
# tolerance it checks instead of restating a literal that would drift the moment
# this number moved. 1.2u is visible on a 720-wide phone (~36px of travel at the
# usual framing) and small enough that a post is still unmistakably a post.
const SENTRY_BEAT_RADIUS := 1.2
# Radians per second. 0.26 is a full circle in ~24s: at 1.2u that is 0.31 u/s,
# an order under PATROL_SPEED, because this is breathing rather than patrolling.
const BEAT_RATE := 0.26

# Whether this machine belongs to a muster (v18, stage 4). Set by the event
# spawner; false on everything else, which is every machine that shipped.
var muster := false

# --- the skirmish clock (v18, stage 3, finding A6) ---------------------------
# The numbers and the reasoning live in FactionDB.SKIRMISH_TIME so both hostile
# classes share one clock rather than two that have to be kept equal.
var _skirmish := 0.0
var _skirmish_rest := 0.0

# Enemy list cached against GameState.faction_version — the matrix moves only
# on player actions, so recomputing it per frame would be paying every tick
# for something that changes a few times an hour.
var _enemies: Array = []
var _enemies_version := -1
# Defend-if-attacked: whoever shot this machine last, held until dead or gone.
# Band-independent by design (HORIZON-4 §4) — being fired on is its own
# diplomacy. The Cordon's never-retaliate-at-the-surveyor exception is stage 2
# behaviour and lands with the Cordon, not here.
var _aggro: Node3D = null
var _target: Node3D = null
var _retarget_t := 0.0
# THE GRUDGE (v18, playtest round 4). Seconds of "this machine is angry at the
# player because the player shot one of us". Zero on everything by construction,
# so nothing that has not been provoked carries any of this.
#
# WHY IT NEEDS ITS OWN CLOCK when _aggro already exists: the skirmish clock in
# _combat_target exempts the player deliberately, so an _aggro pointing at the
# player is never cleared by it. Before this, a picket the player clipped once
# stayed angry until it died or the player docked — unbounded in the field, and
# nothing said so. This is the release that was missing.
var _grudge := 0.0
# The system's chart edge, resolved on first use and never again — a picket dies
# with SystemRoot, so it cannot outlive the number it cached. -1 means "not
# asked yet"; 0 means "asked, and there was no main to ask", which disables the
# clamp rather than clamping every target to the origin.
var _edge := -1.0
# How often the sentry re-asks "who is nearest that I hate". Between scans it
# keeps its answer, which bounds the group walk the same way the drift bounds
# its wander.
const RETARGET_INTERVAL := 0.4

var _fire_cooldown := 0.0
var _charging := false
var _home := Vector3.ZERO
var _home_set := false
var _drift_phase := 0.0
var _dying := false
var _hp_fill: MeshInstance3D
var _core_mat: StandardMaterial3D
var _body_parts: Array[MeshInstance3D] = []


func _ready() -> void:
	add_to_group("hostiles")
	# The allegiance-aware pool: everything a faction rule can point a gun at.
	# Deliberately a SECOND group rather than a reuse of "hostiles" — that name
	# is load-bearing in a dozen places that mean "things opposed to the
	# player", and an allied ship in it would be counted, swept and cleaned up
	# as an enemy by every one of them.
	add_to_group("combatants")
	# Faction paint, and it outranks band and raid tint — FactionDB.TINTS'
	# precedence note (faction > raid > band), because allegiance is the thing
	# combat decisions hang on. Applied only when the spawner has NOT already
	# set a tint by hand, so a deep guard's band colour and a corsair's crimson
	# are untouched; and BEFORE _build_mesh, which reads `tint`.
	if tint.a <= 0.0:
		tint = FactionDB.tint_of(faction)
	max_hp = BASE_HP * difficulty * hp_scale
	hp = max_hp
	# _home is captured on the FIRST FRAME, not here. _ready fires from
	# add_child(), and every spawner in the game — SystemBuilder, the apex, the
	# interdiction, the expanse — sets `position` on the line AFTER add_child,
	# because a node has to be in the tree before global_position means anything.
	# Reading it here therefore always returned the container's origin, and since
	# _process hard-writes `global_position = _home + drift`, every sentry in
	# every system was snapping to the middle of the map on frame one. PYX-01's
	# four lane guards were authored 6-20u out and were all sitting on top of the
	# player's spawn point.
	_drift_phase = randf() * TAU
	_fire_cooldown = randf_range(0.5, FIRE_INTERVAL)
	_build_mesh()
	_build_hp_bar()


func _build_mesh() -> void:
	# Spiky rotor of dark vanes around a glitch-magenta core.
	var core := MeshInstance3D.new()
	var cm := SphereMesh.new()
	cm.radius = 0.28
	cm.height = 0.56
	core.mesh = cm
	# The CORE takes the band colour outright rather than blending — it is the part
	# that swells during the telegraph, so the colour lands on the thing already
	# drawing the eye at the moment it matters.
	_core_mat = Palette.emissive(tint if tint.a > 0.0 else Palette.THREAT, 2.5)
	core.material_override = _core_mat
	add_child(core)
	_body_parts.append(core)

	for i in range(5):
		var vane := MeshInstance3D.new()
		var vm := BoxMesh.new()
		vm.size = Vector3(0.16, 0.1, 1.15)
		vane.mesh = vm
		var ang := TAU * float(i) / 5.0
		vane.position = Vector3(cos(ang), 0, sin(ang)) * 0.55
		vane.rotation.y = -ang + PI / 2.0
		vane.material_override = Palette.matte(_hull_color(Color(0.16, 0.15, 0.2)))
		add_child(vane)
		_body_parts.append(vane)


func _hull_color(base: Color) -> Color:
	# Blends at 0.45, NOT SwarmHostile's 0.62. A sentry's silhouette is roughly
	# four times a dart's, so the same blend covers four times the screen: at
	# 0.62 a Quiet guard's vanes land on Color(0.63, 0.66, 0.70), which is
	# Palette.HULL — the player's own ship. The band has to read as paint on a
	# familiar machine, not as a repaint of the player.
	if tint.a <= 0.0:
		return base
	return base.lerp(tint, 0.45)


func is_dying() -> bool:
	# _die() does not queue_free until DEATH_STAGE_3, so a node mid-explosion is
	# still valid and must not be counted as standing.
	return _dying


func _build_hp_bar() -> void:
	var bar := Node3D.new()
	bar.name = "HPBar"
	add_child(bar)
	bar.position = Vector3(0, 1.1, 0)

	var bg := MeshInstance3D.new()
	var bgm := BoxMesh.new()
	bgm.size = Vector3(1.3, 0.09, 0.02)
	bg.mesh = bgm
	bg.material_override = Palette.emissive(Color(0.25, 0.03, 0.1, 0.85), 1.0)
	bar.add_child(bg)

	_hp_fill = MeshInstance3D.new()
	var fm := BoxMesh.new()
	fm.size = Vector3(1.3, 0.09, 0.02)
	_hp_fill.mesh = fm
	_hp_fill.position.z = -0.01
	_hp_fill.material_override = Palette.emissive(Palette.THREAT, 2.0)
	bar.add_child(_hp_fill)


func _process(delta: float) -> void:
	if _dying:
		return
	if not _home_set:
		# Wherever the spawner put us, now that it has finished putting us there.
		_home = global_position
		_home_set = true
	if despawn_radius > 0.0:
		var who: Node3D = get_tree().get_first_node_in_group("player")
		if who != null and global_position.distance_to(who.global_position) > despawn_radius:
			_give_up()
			return
	# THE GRUDGE RUNS DOWN BEFORE THE GUN IS ASKED, so the frame a grudge expires
	# is a frame this machine does not fire on the player.
	if _grudge > 0.0:
		_grudge = maxf(_grudge - delta, 0.0)
		if _grudge <= 0.0:
			_release_grudge()
	rotation.y += delta * 0.8
	var t := Time.get_ticks_msec() / 1000.0
	var wander := Vector3(sin(t * 0.5 + _drift_phase), 0, cos(t * 0.4 + _drift_phase)) * 0.4
	if patrol.is_empty():
		# Station-keeping. A POST IS A PLACE YOU STAND, NOT A PLACE YOU FREEZE
		# (v18, playtest round 4): an authored sentry walks a slow ring around
		# its post so a held lane reads as crewed rather than as scenery.
		#
		# OPT-IN PER NODE, never a change to this branch's shape, and that is
		# load-bearing rather than fussy. Deep guards are this same class
		# station-keeping at _home, and GUARD POSTS requires each within 0.6u of
		# its PLANNED post and outside Derelict.CRACK_RANGE of the breach point
		# — a guard that had picked up a wander would drift inside crack range
		# and make a guarded hulk unbreachable. `beat_radius` is 0 on every
		# machine the sentry spawner does not set it on.
		var beat := Vector3.ZERO
		if beat_radius > 0.0:
			var a := t * BEAT_RATE + _drift_phase
			beat = Vector3(cos(a), 0.0, sin(a)) * beat_radius
		global_position = _home + beat + wander
	else:
		# THE TWO BRANCHES CANNOT BE UNIFIED, and the difference is the bug that
		# would otherwise ship. Station-keeping ASSIGNS `_home + wander`; a
		# patrol ADDS the wander as a nudge. A moving picket whose position were
		# assigned from a wander term would have its travel overwritten every
		# frame and never leave the spot — which is this file's own
		# _home-on-frame-one defect, reintroduced from the other direction.
		_walk_beat(delta)
		global_position += wander * delta

	var cam := get_viewport().get_camera_3d()
	var bar := get_node_or_null("HPBar")
	if cam and bar:
		bar.global_transform.basis = cam.global_transform.basis

	_weapon(delta)



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

func enter_beat(i: int) -> void:
	# Join the route at waypoint `i` and walk ON from there rather than turning
	# round to reach waypoint 0. The re-form enters at the waypoint furthest from
	# the player so relief never materialises in front of them, and a picket that
	# then immediately walked back past them would undo exactly that.
	if patrol.is_empty():
		return
	_patrol_i = (i + 1) % patrol.size()


func provoke(who: Node3D) -> void:
	# THE REACTION HALF of "shooting something that was not shooting at you is
	# noticed". The bookkeeping half has been in _die since stage 1; this is what
	# the ships beside the one you hit actually do about it. Called on the victim
	# AND on its neighbours, from Main.witness_attack.
	#
	# AGGRO, NOT STANDING, and the separation is the whole design. The matrix is
	# persisted, clamped and symmetric, and it moves on KILLS (_die's -1). A
	# grudge is a session-only pointer with an expiry that is never written to a
	# save. One stray splash must not be able to author a permanent faction state
	# in the player's file, and the GSA floor (HORIZON-4 §2) has to keep meaning
	# exactly what it says — which it does, because nothing here touches a band.
	if _dying or who == null or not is_instance_valid(who):
		return
	_aggro = who
	_grudge = FactionDB.GRUDGE_TIME


func _release_grudge() -> void:
	# A GRUDGE THAT LAPSES HAS TO LET THE SHIP GO, and this is the half that is
	# easy to leave out. _tick_interdiction paid for learning it: a pack whose
	# flag had stopped wanting the player kept its target, drifted forever, and
	# latched _raid_active for the session — taking every later raid and muster
	# with it. Zeroing the timer without clearing the pointers reproduces that
	# one layer down, because fights_the_player() reads _aggro and _target, not
	# the clock. The machine would stay a live enemy with nothing left saying why.
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


func _walk_beat(delta: float) -> void:
	# A picket is only ever in one of two positions: standing off something it
	# is fighting, or walking to its next waypoint. There is deliberately NO
	# "returning" state — a picket with nothing to shoot walking to its next
	# waypoint IS returning, and a third state would be a second thing to keep
	# true for no visible difference.
	var goal: Vector3
	var target := _combat_target(delta)
	if target != null and _worth_leaving_the_beat(target):
		# Stand off rather than close. A picket is a gun emplacement that
		# happens to move; one that charged would be indistinguishable on
		# screen from the raiders it exists to stop.
		var away := global_position - target.global_position
		away.y = 0.0
		if away.length() < 0.01:
			away = Vector3(1, 0, 0)
		goal = target.global_position + away.normalized() * (ENGAGE_RANGE * 0.8)
	else:
		goal = patrol[_patrol_i]
		if global_position.distance_to(goal) <= PATROL_ARRIVE:
			_patrol_i = (_patrol_i + 1) % patrol.size()
			goal = patrol[_patrol_i]

	var step := goal - global_position
	step.y = 0.0
	if step.length() > 0.01:
		# Expressed as a target position rather than an impulse, per §13's
		# lesson: an impulse makes speed a function of how often the caller
		# ticks. Clamped to the remaining distance so a long frame cannot
		# overshoot a waypoint and start the picket oscillating around it.
		var move := step.normalized() * PATROL_SPEED * delta
		global_position += move if move.length() < step.length() else step
	global_position.y = 0.0
	global_position = Obstacles.resolve(global_position, 0.5)


func _worth_leaving_the_beat(target: Node3D) -> bool:
	# THE PARLEY IS THE PLAYER'S CONVERSATION (finding A3). break_parley fires
	# when a raider takes damage from ANYONE, so a picket that peeled onto a pack
	# mid-standoff would answer the demand on the player's behalf and delete the
	# choice the whole interdiction is built around — permanently, everywhere in
	# charted space.
	if target.is_in_group("raider") and "standoff" in target \
			and float(target.standoff) > 0.0:
		return false
	# MEASURED FROM THE ROUTE, NOT FROM THE PICKET, and that is the whole
	# function. A picket measuring from itself would drift outward along its own
	# engagements — every individual step looking correct while charted space
	# quietly went unguarded. The waypoint it is walking to is the anchor, so a
	# contact the ROUTE never comes near is a contact the Cordon never chases,
	# however close the picket happens to drift mid-leg.
	# AND THE CHASE STOPS AT THE MARKER. The band-1 beacon has promised since v13
	# that security patrols do not operate past it, THE CORDON STOPS AT THE
	# MARKER makes that true of the authored ROUTES, and THE LINE IS THE EDGE
	# makes it true of a muster line — but nothing has ever made it true of a
	# picket in PURSUIT, and a waypoint 30u out plus PATROL_RELEASE 25 already
	# reaches past a 40u edge. The grudge below makes that trivially reachable on
	# purpose, so it is closed here rather than left as a gap the new feature
	# happens to widen. It also hands the player the out the fiction already
	# advertises: cross the line and the Cordon does not follow you over it.
	if _edge < 0.0:
		var m := get_tree().get_first_node_in_group("main")
		# Resolved once. A picket is a child of SystemRoot and dies with it on
		# every _load_system, so it can never outlive the edge it cached.
		_edge = float(m.chart_edge()) if m != null and m.has_method("chart_edge") else 0.0
	if _edge > 0.0 and Vector2(target.global_position.x,
			target.global_position.z).length() > _edge:
		return false
	var post: Vector3 = patrol[_patrol_i]
	# A GRUDGE WIDENS THE REACH AND NEVER MOVES THE ANCHOR. Measuring from the
	# picket instead of from the route is the defect this whole function exists
	# to prevent, so a provoked picket asks the same question about the same
	# waypoint — it is only willing to answer yes from further out.
	#
	# PATROL_ENGAGE (12) is the price of picking up a fight it was not in. A
	# machine that has just watched the player shoot one of its own is already in
	# the fight, so it gets WITNESS_RANGE — the same 25 that provoked it, and the
	# same 25 PATROL_RELEASE already lets it chase to. No picket ends up further
	# from its route than it could before this existed.
	#
	# NOT a bypass in _walk_beat, deliberately: THE BEAT IS THE ANCHOR calls this
	# function directly, so a grudge implemented one level up would leave that
	# assertion green while the property it names quietly stopped holding.
	var reach := PATROL_RELEASE if _target == target else PATROL_ENGAGE
	if _grudge > 0.0 and target.is_in_group("player"):
		reach = maxf(reach, FactionDB.WITNESS_RANGE)
	return post.distance_to(target.global_position) <= reach


func _targetable(n) -> bool:
	# UNTYPED PARAMETER, DELIBERATELY. `n: Node3D` looks tidier and is a crash:
	# `_aggro` and `_target` can hold a node that was freed since it was cached,
	# and GDScript validates an Object argument against the declared class AT
	# THE CALL BOUNDARY — so a freed node fails there, before is_instance_valid
	# below ever runs, with "the Object-derived class of argument 1 (previously
	# freed) is not a subclass". The validity check has to be reachable, and it
	# is only reachable if the parameter does not demand a live typed object.
	#
	# is_instance_valid(null) is false, so it covers the null case too.
	if not is_instance_valid(n) or not (n as Node3D).is_inside_tree():
		return false
	if (n as Node3D).is_in_group("player"):
		return not n.docked
	return (n as Node3D).is_in_group("combatants")


func _combat_target(delta: float) -> Node3D:
	# THE SKIRMISH CLOCK LIVES HERE AND NOWHERE ELSE, wrapping the picker below
	# so every path that can return an NPC — aggro, cache, fresh scan — is
	# governed by one timer rather than three copies of one.
	#
	# The player is exempt: fighting the player has no break-off, which is what
	# keeps every balance number ever measured against this class still valid.
	if _skirmish_rest > 0.0:
		_skirmish_rest -= delta
	var picked := _pick_target(delta)
	if picked == null or picked.is_in_group("player"):
		# Not skirmishing. The clock unwinds rather than resetting, so a machine
		# that traded fire, lost sight for a moment and re-acquired does not get
		# a fresh six seconds every time.
		_skirmish = maxf(_skirmish - delta, 0.0)
		return picked
	# THE CLOCK COUNTS FIRE, NOT ACQUISITION — and getting this wrong made every
	# faction fight in the game invisible.
	#
	# _pick_target returns the nearest hated thing AT ANY DISTANCE; there is no
	# range limit in it, deliberately, because that is what lets a picket decide
	# whether something is worth leaving the beat for. But the clock used to
	# start ticking the moment that pointer was non-null, so a machine spent its
	# six seconds on a contact eighty units away that it could not shoot, broke
	# off, and was resting by the time the contact arrived. Measured on a muster:
	# line 960hp -> 960hp, column 816hp -> 816hp across the whole event, twice,
	# with the two sides passing straight through each other.
	#
	# SKIRMISH_TIME's own comment says "six seconds of FIRE cannot finish that".
	# It was written as a weapons timer and implemented as an acquisition timer.
	# In range, it counts; out of range the machine is closing or watching, and
	# the clock unwinds exactly as it does with no target at all.
	if global_position.distance_to(picked.global_position) > ENGAGE_RANGE:
		_skirmish = maxf(_skirmish - delta, 0.0)
		return picked
	_skirmish += delta
	if _skirmish >= FactionDB.SKIRMISH_TIME:
		# Break off. Groups, position and post are untouched — the machine simply
		# stops having a target, which _walk_beat reads as "resume the beat" and
		# a stationary sentry reads as "hold station".
		_skirmish = 0.0
		_skirmish_rest = FactionDB.SKIRMISH_REST
		_aggro = null
		_target = null
		return null
	return picked


func _pick_target(delta: float) -> Node3D:
	# Who this machine would fight, ignoring the clock. Aggro first (whoever
	# shot it), then the nearest thing its flag is HOSTILE toward.
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
	# The NPC scan is skipped outright while standing down. Note it runs even
	# when a player target was found: a machine mid-rest still shoots the
	# player, it just will not pick another machine.
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


func _weapon(delta: float) -> void:
	if standoff > 0.0:
		standoff -= delta
		return
	var target := _combat_target(delta)
	if target == null \
			or global_position.distance_to(target.global_position) > ENGAGE_RANGE:
		_charging = false
		_core_mat.emission_energy_multiplier = 2.5
		return

	_fire_cooldown -= delta
	# Telegraph: the core swells before the shot so the hit is never a surprise.
	if _fire_cooldown <= TELEGRAPH and _fire_cooldown > 0.0:
		var k := 1.0 - _fire_cooldown / TELEGRAPH
		_core_mat.emission_energy_multiplier = 2.5 + k * 7.0
	elif _fire_cooldown <= 0.0:
		_fire_cooldown = FIRE_INTERVAL
		_core_mat.emission_energy_multiplier = 2.5
		var muzzle := global_position + Vector3(0, 0.1, 0)
		var cover = Obstacles.blocked(muzzle, target.global_position)
		if cover != null:
			# Cover protects the target from sentries too, not just the reverse.
			FX.beam(get_parent(), muzzle, cover, Palette.THREAT, 0.05, 0.12)
			return
		FX.beam(get_parent(), muzzle, target.global_position, Palette.THREAT, 0.05, 0.14)
		Sfx.play("fire", -14.0, 0.72)
		# The player has a shield model and take_hit; a machine has take_damage.
		# Same shot, two bookkeepings.
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


func take_damage(amount: float, attacker: Node3D) -> void:
	# `attacker` is REQUIRED, with no default, and that is finding A1 of
	# HORIZON-4: either default silently mis-books a kill — null-means-nobody
	# strips loot from every legacy caller, null-means-player mints credit for
	# NPC fire. Every caller says who is shooting; PYXIS_FACTIONTEST reads the
	# sources and fails any call that does not.
	if _dying:
		return
	if standoff > 0.0 and is_in_group("raider"):
		var m2 := get_tree().get_first_node_in_group("main")
		if m2 and m2.has_method("break_parley"):
			m2.break_parley()
	# Being shot is its own diplomacy: return fire at the shooter, whatever the
	# matrix says about their flag. Same-faction fire is not aggro (the apex
	# venting probes must not turn a probe against its own engine), and a
	# docked player is refused by _targetable, not remembered here.
	if attacker != null and attacker != self \
			and (not ("faction" in attacker) or String(attacker.faction) != faction):
		_aggro = attacker
	# AND ITS FRIENDS SAW IT (v18, playtest round 4). Asked on the BAND rather
	# than through hostile_to_player(), and the difference is not cosmetic: the
	# line above has already pointed this machine at the player, so
	# fights_the_player() answers true and the question would be self-fulfilling.
	# The band is the same test _die uses to decide whether a kill pays, so
	# "was this a neutral" has one definition in this file rather than two.
	#
	# EVERY player damage path arrives here, which is why this is the only hook
	# needed: _damage_target passes the ship itself and the arc chain routes
	# through it, a torpedo carries `shooter`, and the OVERCHARGE discharge
	# passes `self`. Splash and chain are covered by construction, and splash is
	# the case this was asked for.
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
		hp = maxf(hp, max_hp * FactionDB.SKIRMISH_HP_FLOOR)
	var frac := clampf(hp / max_hp, 0.0, 1.0)
	_hp_fill.scale.x = maxf(frac, 0.001)
	_hp_fill.position.x = -1.3 * (1.0 - frac) * 0.5
	FX.flash(get_parent(), global_position + Vector3(0, 0.3, 0), Palette.WHITE_HOT, 0.6, 0.1)
	Sfx.play("hit", -11.0)
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.shake(0.012)
	if hp <= 0.0:
		_die(attacker)


func _give_up() -> void:
	# Not a kill: no loot, no credit, no staged death. It is simply not there.
	_dying = true
	remove_from_group("hostiles")
	remove_from_group("combatants")
	remove_from_group("raider")
	queue_free()


func depart() -> void:
	# Same contract as SwarmHostile.depart: groups shed immediately, nothing paid
	# back, brief exit theater.
	if _dying:
		return
	_dying = true
	remove_from_group("hostiles")
	remove_from_group("combatants")
	remove_from_group("raider")
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector3.ONE * 0.1, 1.8).set_ease(Tween.EASE_IN)
	tw.tween_callback(queue_free)


func _die(attacker: Node3D) -> void:
	_dying = true
	var parent := get_parent()
	var pos := global_position
	var tree := get_tree()
	remove_from_group("hostiles")
	remove_from_group("combatants")

	# ATTRIBUTION GATES THE PAYOUT, never the theater (v18). Kill credit,
	# contract ticks and the loot spill flow only from a player-attributed
	# death; a machine shot down by another machine explodes exactly as loudly
	# and pays exactly nothing — _give_up's "breaking off contact has to be
	# worth nothing" argument, applied to a fight the player did not win.
	# The death FX, the post bookkeeping and queue_free are unconditional:
	# world state is not a payment.
	var player_kill := attacker != null and is_instance_valid(attacker) \
		and attacker.is_in_group("player")

	# WHAT A KILL IS WORTH, and it is three questions rather than one.
	#
	# 1. Did the PLAYER do it — stage 1's attribution rule.
	# 2. Was this thing HOSTILE TO THE PLAYER? Stage 2a put Cordon pickets in
	#    charted space, and stage 1's gate alone would have paid 14 crates and
	#    a kill_sentry contract tick for shooting one. Pickets never return fire
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

	var rig := tree.get_first_node_in_group("camera_rig")
	var main := tree.get_first_node_in_group("main")
	if player_kill and main and main.has_method("report_kill"):
		# A kill THAT DOES NOT PAY REPORTS ITS OWN KIND, so no contract can match
		# it — "kill_muster" and "kill_neutral" are keys nothing in contract_db
		# asks for. The column is the fastest kill_swarm filler in the game and
		# must not count.
		#
		# THE NEUTRAL CASE IS THE HALF §52 LEFT OPEN, and it was live until now.
		# That section closed the picket printer by gating LOOT on `pays` — but
		# report_kill was gated on `player_kill` alone, and contracts.on_kill
		# does not ask a second question. So a Cordon picket dropped no crates
		# and still ticked `cull_sentries` (1,550 for three) and
		# `cull_sentries_big` (3,500 for six), bounded only by the route count
		# and re-armed by every _load_system. Warp out and back and the contract
		# half of the piñata row was still there.
		#
		# Derived from `pays` rather than from a fourth hand-written condition, so
		# the question "is this kill worth anything" has exactly one answer in
		# this function and a later payout cannot disagree with the contract tick.
		var kind := "sentry"
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

	# If this was a deep guard, its post may have just fallen. `_dying` is already
	# true above, so post_standing correctly does not count this node. Credited
	# HERE rather than at cell despawn: a player who clears a post and keeps
	# working the wreck beside it never triggers a despawn.
	if has_meta("post_key") and main and main.deep_space:
		main.deep_space.note_guard_died(get_meta("post_key"))

	# Stage 1: hitstop + white flash + shockwave, body blows apart.
	if main and main.has_method("hit_stop"):
		main.hit_stop(0.07, 0.25)
	if rig:
		rig.shake(0.12)
		rig.punch_zoom(-0.7)
	FX.flash(parent, pos, Palette.WHITE_HOT, 2.4, 0.18)
	FX.shockwave(parent, pos, Palette.WHITE_HOT, 4.5, 0.5)
	Sfx.play("explode", -3.0, 1.0)
	for part in _body_parts:
		var dir := Vector3(randf_range(-1, 1), randf_range(0, 0.5), randf_range(-1, 1)).normalized()
		var tw := part.create_tween()
		tw.set_parallel(true)
		tw.tween_property(part, "position", part.position + dir * 1.8, 0.45)
		tw.tween_property(part, "scale", Vector3.ONE * 0.05, 0.45)

	# Stage 2: main fireball.
	tree.create_timer(DEATH_STAGE_2).timeout.connect(func() -> void:
		FX.burst(parent, pos, Color(1.0, 0.55, 0.15), 60, 10.0, 0.3, 0.75)
		FX.burst(parent, pos, Palette.THREAT, 25, 6.5, 0.2, 0.55)
	)

	# Stage 3: secondary burst + loot spill, then free. The spill is the gated
	# half — an NPC kill gets the burst and nothing adrift.
	tree.create_timer(DEATH_STAGE_3).timeout.connect(func() -> void:
		FX.burst(parent, pos, Color(1.0, 0.8, 0.4), 35, 5.0, 0.2, 0.7)
		if pays:
			var m := tree.get_first_node_in_group("main")
			var crate := CommodityDB.roll_drop("sentry")
			for i in range(LOOT_COUNT):
				var spot := pos + Vector3(randf_range(-0.4, 0.4), 0.1, randf_range(-0.4, 0.4))
				if m:
					m.spawn_loot(parent, spot, crate if i == 0 else "")
		queue_free()
	)
