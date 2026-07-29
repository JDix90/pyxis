class_name SweepArm
extends Node3D
# The Gnomon's shadow: rigid blades sweeping the chart around the hub.
#
# This is the encounter's positional pressure and the reason weapon RANGE finally
# buys something. The blade is solid from the hub outward — there is deliberately
# NO inner safe pocket, so parking on top of the boss is the most dangerous place
# on the field, not a hiding spot.
#
# Park radii (player_ship.reach() * 0.7) vs SWEEP_RADIUS 6.0:
#   Arc 3.85 / Pulse 4.90-5.25  -> under the blade, paying shield for damage
#   Lance 7.70-8.40             -> outside it, safe but slow at clearing probes
#
# --- FEEL CONSTANTS ---
# Deliberately LARGER than ApexBoss.CORE_RANGE (7.0): every position from which
# the core can be hurt lies inside the blades' reach, so nobody snipes this
# encounter from a chair. The blades are dodgeable — they rotate, and the far
# side of the hub is always momentarily clear — but they cannot be opted out of.
const SWEEP_RADIUS := 8.0
const HUB_CRUSH_RADIUS := 1.3       # inside this the blades' root is always on you
const BLADE_HALF_WIDTH := 0.20      # radians; ~23 degrees of arc
const TELEGRAPH_LEAD := 0.5         # seconds of rotation shown ahead of the blade
# Tuned down from 14 -> 11 -> 8 against the balance harness. The blades are a
# positioning tax, not a damage race: at 14 the fight was unwinnable through
# chip damage alone even with correct dodging.
const DAMAGE_PER_SECOND := 8.0
const TICK := 0.25

var speed_deg := 22.0               # set per phase by the boss
var blades := 1                     # phase 3 runs two opposed blades
var active := false:
	set(v):
		active = v
		visible = v

var _angle := 0.0
var _tick_timer := 0.0
var _blade_nodes: Array[Node3D] = []


func _ready() -> void:
	rebuild()


func rebuild() -> void:
	for n in _blade_nodes:
		n.queue_free()
	_blade_nodes.clear()

	for i in range(blades):
		var blade := Node3D.new()
		add_child(blade)
		_blade_nodes.append(blade)

		# Body: solid spar from the hub out to SWEEP_RADIUS.
		var spar := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.42, 0.16, SWEEP_RADIUS)
		spar.mesh = bm
		spar.position = Vector3(0, 0, -SWEEP_RADIUS * 0.5)
		spar.material_override = Palette.matte(Color(0.17, 0.15, 0.2))
		blade.add_child(spar)

		# Threat edge: the part that actually reads as "this will hurt".
		var edge := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3(0.1, 0.2, SWEEP_RADIUS)
		edge.mesh = em
		edge.position = Vector3(-0.22, 0, -SWEEP_RADIUS * 0.5)
		edge.material_override = Palette.emissive(Palette.THREAT, 2.6)
		blade.add_child(edge)

		# Telegraph: a dim wedge covering the next TELEGRAPH_LEAD of travel, so
		# the hazard is always announced before it arrives (sentry vocabulary).
		var warn := MeshInstance3D.new()
		var wm := BoxMesh.new()
		wm.size = Vector3(0.06, 0.02, SWEEP_RADIUS)
		warn.mesh = wm
		warn.position = Vector3(0, -0.05, -SWEEP_RADIUS * 0.5)
		warn.material_override = Palette.emissive(
			Color(Palette.THREAT.r, Palette.THREAT.g, Palette.THREAT.b, 0.35), 1.8)
		warn.name = "Telegraph"
		blade.add_child(warn)


func _physics_process(delta: float) -> void:
	if not active:
		return

	_angle = wrapf(_angle + deg_to_rad(speed_deg) * delta, 0.0, TAU)
	var lead := deg_to_rad(speed_deg) * TELEGRAPH_LEAD

	for i in range(_blade_nodes.size()):
		var offset := TAU * float(i) / float(maxi(_blade_nodes.size(), 1))
		var blade := _blade_nodes[i]
		blade.rotation.y = _angle + offset
		var warn := blade.get_node_or_null("Telegraph")
		if warn:
			(warn as Node3D).rotation.y = lead  # sits ahead of its own blade

	_tick_timer -= delta
	if _tick_timer <= 0.0:
		_tick_timer = TICK
		_damage_check()


func _damage_check() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	var dist := to_player.length()
	if dist > SWEEP_RADIUS:
		return

	# Dead centre is the WORST place to stand, not a safe pocket. The bearing
	# maths degenerates at the hub (atan2 of ~0,~0), so without this the blades
	# would sail harmlessly over anyone parked on top of the boss — one ground
	# tap would opt out of the entire encounter's positional pressure.
	if dist < HUB_CRUSH_RADIUS:
		if player.has_method("take_hit"):
			player.take_hit(DAMAGE_PER_SECOND * TICK)
		FX.flash(get_parent(), player.global_position, Palette.THREAT, 0.9, 0.14)
		return

	var bearing := atan2(-to_player.x, -to_player.z)
	for i in range(_blade_nodes.size()):
		var blade_angle := _angle + TAU * float(i) / float(maxi(_blade_nodes.size(), 1))
		if absf(wrapf(bearing - blade_angle, -PI, PI)) > BLADE_HALF_WIDTH:
			continue
		if player.has_method("take_hit"):
			player.take_hit(DAMAGE_PER_SECOND * TICK)
		FX.flash(get_parent(), player.global_position, Palette.THREAT, 0.7, 0.12)
		return


func safest_point(radius: float) -> Vector3:
	# The spot furthest from every blade's current bearing — where a player who
	# reads the telegraph naturally moves.
	var best := global_position
	var best_gap := -1.0
	for i in range(24):
		var ang := TAU * float(i) / 24.0
		var gap := PI
		for b in range(_blade_nodes.size()):
			var blade_angle := _angle + TAU * float(b) / float(maxi(_blade_nodes.size(), 1))
			gap = minf(gap, absf(wrapf(ang - blade_angle, -PI, PI)))
		if gap > best_gap:
			best_gap = gap
			best = global_position + Vector3(-sin(ang), 0, -cos(ang)) * radius
	best.y = 0.0
	return best


func is_player_exposed() -> bool:
	# Used by the boss for barks/telemetry, not for damage.
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	var to_player: Vector3 = player.global_position - global_position
	to_player.y = 0.0
	return to_player.length() <= SWEEP_RADIUS
