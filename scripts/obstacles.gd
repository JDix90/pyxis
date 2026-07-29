class_name Obstacles
extends Object
# Analytic collision for a game that has no physics.
#
# Everything in Pyxis moves by direct position maths — ships, probes, loot — and
# weapons are instant visual+damage events. Retrofitting physics bodies would
# mean rewriting every mover at once and breaking tap-to-move until avoidance
# existed. So solid things register spheres here instead, and three cheap
# queries give us the behaviour that matters:
#
#   resolve()  - push a mover out of anything it has entered (sliding, not stopping)
#   steer()    - a tangential nudge so autopilot rounds obstacles instead of
#                grinding into them
#   blocked()  - segment-vs-sphere, so a rock actually stops a shot
#
# Registration lives with construction (SystemBuilder, Port, ApexBoss) and the
# whole registry is cleared when SystemRoot is torn down on warp.
#
# Streamed deep-space content breaks that "built once, cleared wholesale" pattern:
# a sector cell appears and disappears while the system stands. So a sphere may
# carry an OWNER tag, and `remove_owner` unregisters exactly that cell's spheres.
# The tag defaults to "" and every authored caller leaves it that way, so nothing
# that existed before this can be removed by anything but `clear()`.

const AVOID_LOOKAHEAD := 9.0     # how far ahead autopilot checks for a blocker
const AVOID_STRENGTH := 1.35     # how hard it slides around one
const SKIN := 0.05               # keeps movers a hair off the surface

static var _spheres: Array = []  # [{pos: Vector3, radius: float, owner: String}]


static func clear() -> void:
	_spheres.clear()


static func add(pos: Vector3, radius: float, owner: String = "") -> void:
	if radius <= 0.0:
		return
	var p := pos
	p.y = 0.0     # everything of consequence lives on the play plane
	_spheres.append({"pos": p, "radius": radius, "owner": owner})


static func remove_owner(owner: String) -> int:
	# Returns how many were removed, which is what lets a harness assert the
	# registry came back to its baseline rather than merely stopped growing.
	if owner == "":
		return 0        # "" is the un-owned authored world; never bulk-removable
	var kept: Array = []
	for s in _spheres:
		if String(s.get("owner", "")) != owner:
			kept.append(s)
	var removed := _spheres.size() - kept.size()
	_spheres = kept
	return removed


static func count_owned(owner: String) -> int:
	var n := 0
	for s in _spheres:
		if String(s.get("owner", "")) == owner:
			n += 1
	return n


static func count() -> int:
	return _spheres.size()


static func spheres() -> Array:
	return _spheres


# --- movement ---------------------------------------------------------------

static func resolve(pos: Vector3, body_radius: float) -> Vector3:
	# Push out of every sphere currently overlapped. Sliding rather than
	# stopping means a ship scraping a moon keeps its tangential speed.
	var out := pos
	for s in _spheres:
		var centre: Vector3 = s["pos"]
		var min_dist: float = float(s["radius"]) + body_radius
		var offset := out - centre
		offset.y = 0.0
		var d := offset.length()
		if d >= min_dist or d <= 0.0001:
			if d <= 0.0001:
				# Dead centre: pick an arbitrary bearing rather than divide by zero.
				out = centre + Vector3(min_dist + SKIN, 0, 0)
			continue
		out = centre + offset.normalized() * (min_dist + SKIN)
		out.y = pos.y
	return out


static func steer(pos: Vector3, desired: Vector3, body_radius: float) -> Vector3:
	# Tangential avoidance for autopilot. Only reacts to the nearest blocker in
	# front of us, so it produces a smooth arc rather than fighting itself.
	if desired.length_squared() < 0.0001:
		return desired
	var dir := desired.normalized()
	var reach := minf(AVOID_LOOKAHEAD, desired.length() + AVOID_LOOKAHEAD)

	var best: Dictionary = {}
	var best_t := INF
	for s in _spheres:
		var centre: Vector3 = s["pos"]
		var to_centre := centre - pos
		to_centre.y = 0.0
		var along := to_centre.dot(dir)
		if along <= 0.0 or along > reach:
			continue
		var perp := (to_centre - dir * along).length()
		if perp >= float(s["radius"]) + body_radius:
			continue
		if along < best_t:
			best_t = along
			best = s

	if best.is_empty():
		return desired

	var centre2: Vector3 = best["pos"]
	var away := pos - centre2
	away.y = 0.0
	if away.length() < 0.0001:
		away = Vector3(1, 0, 0)
	# Tangent on the side we are already favouring.
	var tangent := Vector3(-dir.z, 0.0, dir.x)
	if tangent.dot(away) < 0.0:
		tangent = -tangent
	var urgency := clampf(1.0 - (best_t / maxf(reach, 0.001)), 0.0, 1.0)
	return (dir + tangent * AVOID_STRENGTH * urgency).normalized() * desired.length()


# --- line of sight ----------------------------------------------------------

static func blocked(from: Vector3, to: Vector3):
	# Returns the impact point if a sphere interrupts the segment, else null.
	# Callers render the beam to that point so cover reads visually.
	var a := from
	var b := to
	a.y = 0.0
	b.y = 0.0
	var seg := b - a
	var len_sq := seg.length_squared()
	if len_sq < 0.0001:
		return null

	var closest_t := INF
	var hit = null
	for s in _spheres:
		var centre: Vector3 = s["pos"]
		var r: float = float(s["radius"])
		var m := a - centre
		# Ignore any sphere containing either end of the segment. A body is not
		# cover for something embedded inside it: the apex boss registers a hull
		# sphere at its own centre, so without the endpoint check every shot
		# aimed at the Gnomon (and at probes docked on its shell) was absorbed
		# by the Gnomon itself, making it unkillable.
		if m.length() <= r or b.distance_to(centre) <= r:
			continue
		var t := clampf(-m.dot(seg) / len_sq, 0.0, 1.0)
		var closest := a + seg * t
		if closest.distance_to(centre) > r:
			continue
		# Entry point along the segment, for an honest impact position.
		var f := seg / sqrt(len_sq)
		var b_coef := m.dot(f)
		var c_coef := m.length_squared() - r * r
		var disc := b_coef * b_coef - c_coef
		if disc < 0.0:
			continue
		var enter := -b_coef - sqrt(disc)
		if enter < 0.0 or enter * enter > len_sq:
			continue
		if enter < closest_t:
			closest_t = enter
			hit = a + f * enter
	return hit


static func has_line(from: Vector3, to: Vector3) -> bool:
	return blocked(from, to) == null
