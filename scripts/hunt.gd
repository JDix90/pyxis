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

# 3 degrees of bearing and ~1/24th of the band's width. Finer than this stops
# moving the centroid by more than the ghost marker is wide, which is the only
# resolution that can matter to anything downstream.
const BEARING_STEPS := 120
const RADIUS_STEPS := 24


static func estimate(system_id: String) -> Dictionary:
	# Returns {center: Vector3, radius: float, strength: int}:
	#
	#   center    where to draw the ghost. Centroid of the agreed region.
	#   radius    how wrong that ghost may be, in world units — the furthest
	#             agreed point from the centroid. Shrinks as hints accumulate,
	#             which is the number the survey plot is really drawing.
	#   strength  how many hints the agreed region satisfies. NOT the hint
	#             count: three cones that contradict each other yield a
	#             strength of 2, because no point in the world satisfies all
	#             three, and the radar's threshold should not fire on a dossier
	#             that disagrees with itself.
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
		# Nothing bought yet. The honest answer is the whole band — the same
		# thing the free lane-obstructed broadcast already says out loud.
		var mid := (r_min + r_max) * 0.5
		return {"center": Vector3.ZERO, "radius": mid, "strength": 0}

	var best_score := -1
	var sum_x := 0.0
	var sum_z := 0.0
	var kept: Array = []
	for bi in range(BEARING_STEPS):
		var ang := TAU * float(bi) / float(BEARING_STEPS)
		var ca := cos(ang)
		var sa := sin(ang)
		for ri in range(RADIUS_STEPS):
			# Cell CENTRES (the +0.5), so a one-step band still has a sample in
			# it and the set is symmetric about the annulus's mid-radius.
			var t := (float(ri) + 0.5) / float(RADIUS_STEPS)
			var rad := lerpf(r_min, r_max, t)
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
				kept.clear()
				sum_x = 0.0
				sum_z = 0.0
			kept.append(p)
			sum_x += p.x
			sum_z += p.z

	if kept.is_empty():
		var mid2 := (r_min + r_max) * 0.5
		return {"center": Vector3.ZERO, "radius": mid2, "strength": 0}

	var centre := Vector3(sum_x / float(kept.size()), 0.0, sum_z / float(kept.size()))
	# THE CENTROID CAN FALL OUTSIDE THE BAND, and that is correct rather than a
	# bug to clamp away: two cones meeting on opposite sides of the system
	# average to a point near the origin, and a radius measured from there
	# honestly reports "these hints do not agree on a side". Pulling the centre
	# back onto the annulus would shrink the radius and dress a contradiction up
	# as precision.
	# INFLATED BY THE CELL, and this is not a fudge factor — it is the difference
	# between the region and the samples of it.
	#
	# What the grid holds is a set of POINTS; what the hints actually admit is
	# the set of CELLS those points stand for. Measuring the radius to the
	# points alone under-claims the region by up to half a cell diagonal, and at
	# this scale that is not small: 120 bearing steps at radius 1300 is a 68-unit
	# arc between neighbours. The harness caught it exactly there — a two-hint
	# dossier claiming 209u when the lair was 213u away, so the plot drew a
	# circle that confidently excluded the answer.
	#
	# Under-claiming uncertainty is the one error this whole file exists to
	# avoid. A ghost that is honestly vague costs the player another reading; a
	# ghost that is precisely wrong costs them the trip.
	var radial_half := (r_max - r_min) / float(RADIUS_STEPS) * 0.5
	var radius := 0.0
	for p_v in kept:
		var p: Vector3 = p_v
		# The angular half-width is a function of the point's own radius, so an
		# annulus sampled at one bearing resolution is wider in world units the
		# further out it sits.
		var ang_half := p.length() * TAU / float(BEARING_STEPS) * 0.5
		radius = maxf(radius, centre.distance_to(p)
			+ sqrt(radial_half * radial_half + ang_half * ang_half))
	return {"center": centre, "radius": radius, "strength": best_score}


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
