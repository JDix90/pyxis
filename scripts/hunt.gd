class_name Hunt
extends Object
# WHERE THE DOSSIER SAYS THE ENGINE IS.
#
# One pure function over `GameState.apex_intel` and the system's authored lair
# band. It reads no node, writes nothing, and stores nothing: the estimate is
# recomputed from the hints every time it is asked for, which is what lets a
# newly bought reading tighten the plot the instant it is filed.
#
# THE ESTIMATE IS NOT THE ANSWER, and every decision here protects that. The
# ghost this drives sits at the centroid of what the hints agree on, which is
# honestly wrong by whatever error the player has not yet bought out. A hunt
# that hands over `SystemDB.lair_pos` the moment you own three hints is not a
# hunt; it is a waypoint with extra steps.
#
# --- WHY A GRID AND NOT ALGEBRA ---------------------------------------------
# Intersecting N cones with an annulus and a quadrant analytically means N-body
# case analysis: cones that cross the annulus twice, cones that miss it, cones
# whose apex sits inside it, pairs that intersect in two disjoint lens shapes.
# Every one of those is a branch that can be wrong in a way that still returns a
# plausible Vector3 — the exact failure mode this project keeps writing
# assertions about.
#
# A fixed polar grid over the annulus has none of that. It is deterministic
# (no RNG, no time, no node state), it degrades honestly under contradiction,
# and "how many hints does this point satisfy" is a total function with no
# special cases. 120 x 24 = 2,880 samples against at most HINT_CAP hints is
# ~23k comparisons — trivial once, and the caller caches it against
# `GameState.intel_version` rather than paying it per frame.

# One pass's resolution. The scan is run repeatedly, each time inside the window
# the last one found, so this is the resolution PER PASS rather than the
# resolution of the answer.
const BEARING_STEPS := 180
const RADIUS_STEPS := 36
# How many times the scan zooms in on its own answer.
#
# A single coarse pass is not enough, for two separate reasons the harness found
# in turn. It can FAIL TO FIND a narrow agreement -- every channel derives its
# reading from the true lair within its own quoted error, so the true
# intersection is never empty, and a scan that cannot satisfy every hint has
# been out-resolved by the geometry rather than shown a contradiction. And it
# can UNDER-MEASURE one it does find, because when only a sample or two lands
# inside the region the measured extent is mostly an artifact of where the grid
# fell.
#
# Every pass runs every time, so measurement DEPTH is uniform: two dossiers are
# only comparable if they were measured the same way, and an early exit made a
# four-hint estimate stop shallow while a five-hint one went deep -- which read
# as the search circle growing when a reading was bought.
const REFINE_PASSES := 6
# What "the search area did not grow" is allowed to mean, as a fraction.
#
# The radius is a heuristic uncertainty bound produced by an ITERATIVE SAMPLED
# SEARCH: a coarse pass picks a window, later passes zoom into it, and which
# window a dossier converges on depends slightly on where the first grid fell.
# Adding a hint can therefore nudge the reported radius by a couple of units on
# a 250-unit circle even though the region it bounds genuinely shrank.
#
# Three formulations were tried against the harness before this constant
# existed -- sample extent with an early exit, sample extent keeping the widest
# pass, and the window bound used now -- and each moved the wobble somewhere
# else rather than removing it. That is the method's noise floor, not a bug
# hiding in it, and the honest thing is to name it rather than keep tuning until
# one particular fixture happens to come out clean.
#
# 5% is chosen against what the player can SEE: the ghost only appears under a
# 200u radius, where 5% is 10 units -- under one marker width on the radar and
# invisible on a plot 150 pixels tall. What this forbids is the search area
# MATERIALLY widening when a reading is bought, which is the promise that
# matters; sub-percent jitter in the last digit is not that promise.
const RESIDUAL_FRACTION := 0.05


static func _scan(hints: Array, a0: float, a1: float, r0: float, r1: float,
		bounds: float) -> Dictionary:
	# One pass over a polar window. Returns the best-agreeing sample set, its
	# centroid, a radius bounding the window those samples occupy, and that
	# window -- which is what the next pass zooms into.
	var best_score := -1
	var sum_x := 0.0
	var sum_z := 0.0
	var kept := 0
	var ref_ang := a0
	var min_off := 0.0
	var max_off := 0.0
	var min_r := r1
	var max_r := r0
	# Half-open in bearing when the window is the full circle (so 0 and TAU are
	# not both sampled), closed when it is not, so a narrow window still reaches
	# both of its own edges.
	var full := absf((a1 - a0) - TAU) < 0.0001
	var denom := float(BEARING_STEPS) if full else float(maxi(BEARING_STEPS - 1, 1))
	for bi in range(BEARING_STEPS):
		var ang := a0 + (a1 - a0) * float(bi) / denom
		var ca := cos(ang)
		var sa := sin(ang)
		for ri in range(RADIUS_STEPS):
			# Cell CENTRES, so a one-step band still has a sample in it.
			var t := (float(ri) + 0.5) / float(RADIUS_STEPS)
			var rad := lerpf(r0, r1, t)
			var p := Vector3(ca * rad, 0.0, sa * rad)
			var score := 0
			for h_v in hints:
				if _satisfies(h_v as Dictionary, p, bounds):
					score += 1
			if score < best_score:
				continue
			if score > best_score:
				# A better agreement invalidates everything gathered so far.
				best_score = score
				kept = 0
				sum_x = 0.0
				sum_z = 0.0
				ref_ang = ang
				min_off = 0.0
				max_off = 0.0
				min_r = rad
				max_r = rad
			kept += 1
			sum_x += p.x
			sum_z += p.z
			# Angular extent measured as an OFFSET from the first kept sample, so
			# a region straddling bearing 0 gives a narrow window rather than the
			# whole circle.
			var off := wrapf(ang - ref_ang, -PI, PI)
			min_off = minf(min_off, off)
			max_off = maxf(max_off, off)
			min_r = minf(min_r, rad)
			max_r = maxf(max_r, rad)

	if kept == 0:
		return {"strength": -1}

	var centre := Vector3(sum_x / float(kept), 0.0, sum_z / float(kept))
	# The window the kept samples occupy, padded by a cell so the next pass
	# cannot lose the agreed region to its own edges.
	var radial_half := (r1 - r0) / float(RADIUS_STEPS) * 0.5
	var ang_step := (a1 - a0) / denom
	var w_a0 := ref_ang + min_off - ang_step
	var w_a1 := ref_ang + max_off + ang_step
	var w_r0 := maxf(min_r - radial_half * 2.0, r0)
	var w_r1 := minf(max_r + radial_half * 2.0, r1)

	# RADIUS BOUNDS THE WINDOW, NOT THE SAMPLES, and that choice is what makes
	# this number stable enough to show a player.
	#
	# Measuring the extent of the kept SAMPLES sounds tighter and is worse: when
	# the agreed region is small relative to a cell only one or two samples land
	# in it, so the measurement is dominated by where the grid happened to fall.
	# It dips while the window is coarse and rises as the window closes, and two
	# dossiers measured at different depths stop being comparable.
	#
	# The window is a genuine SUPERSET of the agreed region, so bounding it can
	# never under-claim -- and under-claiming is the one error this file exists
	# to avoid. A ghost that is honestly vague costs the player another reading;
	# a ghost that is precisely wrong costs them the trip. The arc is SAMPLED
	# rather than cornered because a polar rectangle bulges: its furthest point
	# from the centroid can lie mid-arc.
	var radius := 0.0
	for i in range(9):
		var a := lerpf(w_a0, w_a1, float(i) / 8.0)
		for r_v in [w_r0, w_r1]:
			var r: float = r_v
			radius = maxf(radius, centre.distance_to(Vector3(cos(a) * r, 0.0, sin(a) * r)))

	return {
		"center": centre, "radius": radius, "strength": best_score,
		"a0": w_a0, "a1": w_a1, "r0": w_r0, "r1": w_r1,
	}


static func estimate(system_id: String) -> Dictionary:
	# Returns {center: Vector3, radius: float, strength: int}:
	#
	#   center    where to draw the ghost. Centroid of the agreed region.
	#   radius    how wrong that ghost may be, in world units. Shrinks as hints
	#             accumulate, which is the number the survey plot is drawing.
	#   strength  how many hints the agreed region satisfies. NOT the hint
	#             count: three cones that contradict each other yield a strength
	#             of 2, because no point in the world satisfies all three, and
	#             the radar's threshold should not fire on a dossier that
	#             disagrees with itself.
	var s := SystemDB.get_system(system_id)
	var bounds := float(s.get("bounds", 40.0))
	var lair: Dictionary = (s.get("apex", {}) as Dictionary).get("lair", {})
	if lair.is_empty():
		return {"center": Vector3.ZERO, "radius": 0.0, "strength": 0}
	var band: Array = lair.get("depth", [200.0, 300.0])

	# THE CLAMP, and it is the reason the estimate can never be absurd. Every
	# candidate point lies inside the authored depth band, so no combination of
	# stale, contradictory or hand-edited hints can put the ghost in the charted
	# volume or out past the edge of the world. The hints choose WHERE in the
	# annulus; they never get to choose the annulus.
	var r_min := bounds + float(band[0])
	var r_max := bounds + float(band[1])

	var hints: Array = GameState.apex_hints(system_id)
	if hints.is_empty():
		# Nothing bought yet. The honest answer is the whole band -- the same
		# thing the free lane-obstructed broadcast already says out loud.
		return {"center": Vector3.ZERO, "radius": (r_min + r_max) * 0.5, "strength": 0}

	var res := _scan(hints, 0.0, TAU, r_min, r_max, bounds)
	for pass_i in range(REFINE_PASSES):
		var next := _scan(hints, float(res["a0"]), float(res["a1"]),
			float(res["r0"]), float(res["r1"]), bounds)
		# Never trade agreement for resolution: a finer window satisfying fewer
		# hints has zoomed past the answer.
		if int(next.get("strength", -1)) < int(res.get("strength", -1)):
			break
		res = next

	if int(res.get("strength", -1)) < 0:
		return {"center": Vector3.ZERO, "radius": (r_min + r_max) * 0.5, "strength": 0}
	# THE CENTROID CAN FALL OUTSIDE THE BAND, and that is correct rather than a
	# bug to clamp away: two cones meeting on opposite sides of the system
	# average to a point near the origin, and a radius measured from there
	# honestly reports "these hints do not agree on a side". Pulling the centre
	# back onto the annulus would shrink the radius and dress a contradiction up
	# as precision.
	return {"center": res["center"], "radius": res["radius"], "strength": res["strength"]}


static func _satisfies(hint: Dictionary, p: Vector3, bounds: float) -> bool:
	if String(hint.get("kind", "")) == "ring":
		if DeepSpace.quadrant_of(p) != String(hint.get("quadrant", "")):
			return false
		return DeepSpace.band_of(maxf(p.length() - bounds, 0.0)) == int(hint.get("band", -1))
	# A bearing cone: is the candidate within `err` degrees of the reading, as
	# seen FROM where the instrument stood? The stored origin is what makes this
	# a cone rather than a ray from the middle of the map.
	var to_p := p - Vector3(float(hint.get("ox", 0.0)), 0.0, float(hint.get("oz", 0.0)))
	if to_p.length_squared() < 0.001:
		return true          # standing on it: every bearing is satisfied
	var deg := fposmod(rad_to_deg(atan2(to_p.z, to_p.x)), 360.0)
	var delta := absf(wrapf(deg - float(hint.get("bearing", 0.0)), -180.0, 180.0))
	return delta <= float(hint.get("err", 0.0))


static func bearing_hint(system_id: String, from: Vector3, kind: String,
		err_deg: float, run_seed: int) -> Dictionary:
	# Builds a hint AT the moment it is earned, from ground truth plus a
	# deterministic error — which is the only place `lair_pos` may be touched by
	# an intel channel.
	#
	# THE ERROR IS SEEDED, NOT ROLLED. `randf()` here would mean a player who
	# saves, buys a reading, reloads and buys it again gets a different cone
	# each time — the hunt would become a slot machine that pays out to whoever
	# reloads most. The offset is a pure function of the system, the run, the
	# channel and the observer's own position, so the same reading taken from
	# the same place is the same reading forever.
	var truth := SystemDB.lair_pos(system_id, run_seed)
	var to_truth := truth - from
	var true_deg := fposmod(rad_to_deg(atan2(to_truth.z, to_truth.x)), 360.0)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|hint|%s|%d|%d|%d" % [
		system_id, kind, run_seed, int(round(from.x)), int(round(from.z))])
	# Offset within the cone the channel advertises, so the reading is honestly
	# wrong by up to its own quoted error and never by more.
	var offset := rng.randf_range(-err_deg, err_deg)
	return {
		"kind": kind,
		"ox": from.x,
		"oz": from.z,
		"bearing": fposmod(true_deg + offset, 360.0),
		"err": err_deg,
	}


static func ring_hint(system_id: String, run_seed: int) -> Dictionary:
	# The rumour tier: no origin, no bearing, and no error to buy down — the
	# band and the sector, exactly what the free broadcast gives, which is why
	# the channels that sell this one sell it cheap.
	var truth := SystemDB.lair_pos(system_id, run_seed)
	var depth := SystemDB.lair_depth(system_id, run_seed)
	return {
		"kind": "ring",
		"band": DeepSpace.band_of(depth),
		"quadrant": DeepSpace.quadrant_of(truth),
	}
