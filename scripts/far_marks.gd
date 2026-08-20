class_name FarMarks
extends RefCounted
# THE NETWORK'S SOUNDING MARKS (Horizon 9 — §96). Buoys standing past every
# archive, at depths nothing else in this game reaches. Where they are, and
# which of them carries what, is a PURE FUNCTION of (system, run_seed).
#
# A GENERATOR BEFORE A NODE, and that ordering is deliberate. §84 shipped
# `Rival` as arithmetic the world read before anything drew it, and this is the
# same object one horizon later: commit 0 needs a real bearing to name in the
# channel's reply, and commit 2 builds buoys from exactly these positions. A
# generator can be swept exhaustively by a harness without building a world,
# which is the only way to prove a placement rule at nine thousand units.
#
# A LEAF, like Rival and Profiles: this file references SystemDB for a bounds
# lookup and nothing else in the project, so it closes no class-list cycle and
# can be called from the world, from main, or from a pure assertion.

# Where they stand. Past the archives (5,650–6,040u, unsounded_site.gd) with a
# clear gap, so a pilot who has walked the archives has not seen these and a
# pilot who finds one has gone further than the record does.
const DEPTH_MIN := 6500.0
const DEPTH_MAX := 9000.0
# Five per system, fifteen in a run. Bounded by construction like
# hyper_positions, and small: this is the rarest furniture in the game.
const PER_SYSTEM := 5
# A FIXED oversample regardless of the count, hyper_positions' own rule — the
# number of draws must not depend on how many candidates the separation test
# rejects, or the stream would move with the geometry.
const CANDIDATES := 14
# Far apart, because the point of a mark is a journey between marks. Scaled up
# from MIN_HYPER_SEPARATION (700) in proportion to the depth band.
const MIN_SEPARATION := 1400.0

# THE TEN LEGENDS, in two classes.
#
# COMMON kinds may repeat across a run. SINGULAR kinds appear AT MOST ONCE in
# an entire game, and a given run does not carry all of them — a run with no
# serpent in it is a normal run. That is the design rather than a shortfall: it
# is what makes a legend something a player describes to somebody else instead
# of a checklist row, and it is why nothing anywhere counts them.
const COMMON := ["vein", "layup", "drift"]
const SINGULAR := ["stillness", "order", "serpent", "orrery", "nursery",
	"forge", "procession"]
# HOW MANY OF THE SEVEN A RUN ACTUALLY CARRIES, and this constant is the whole
# pacing rule rather than a tuning knob. Without it the rule does not exist:
# three systems x five marks is fifteen slots against seven singulars, so a
# deal that stops at pool.size() hands EVERY run all seven, every time --
# "a run with no serpent in it is a normal run" would have been a sentence in a
# document that the code contradicted on every seed.
#
# Four of seven means a run carries a majority of its legends and misses three,
# and which three is the run's character. It also means the player who has met
# the serpent and the player who has met the forge have played different games
# and can say so to each other, which is the entire argument for singulars.
const SINGULAR_PER_RUN := 4


static func kinds() -> Array:
	return COMMON + SINGULAR


static func positions(system_id: String, run_seed: int) -> Array:
	# hyper_positions' pattern, verbatim in shape: count is fixed rather than
	# rolled (five is five), a fixed candidate oversample, INDEPENDENT depth per
	# candidate, and a separation reject that consumes no extra draws.
	#
	# Independent depths matter more here than anywhere else in the game: one
	# shared depth would put every mark in a system on one ring, so finding a
	# single buoy would hand the player the radius of the other four and turn
	# fifteen expeditions into one arc and four bearings.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|farmark|%d" % [system_id, run_seed])
	var bounds := SystemDB.bounds_of(system_id)
	var cand_b: Array = []
	var cand_d: Array = []
	for i in range(CANDIDATES):
		cand_b.append(rng.randf_range(0.0, TAU))
		cand_d.append(rng.randf_range(DEPTH_MIN, DEPTH_MAX))
	var out: Array = []
	for i in range(CANDIDATES):
		if out.size() >= PER_SYSTEM:
			break
		var radius: float = bounds + float(cand_d[i])
		var p := Vector3(cos(float(cand_b[i])) * radius, 0.0,
			sin(float(cand_b[i])) * radius)
		var clear := true
		for q_v in out:
			if p.distance_to(q_v as Vector3) < MIN_SEPARATION:
				clear = false
				break
		if clear:
			out.append(p)
	return out


static func kind_at(system_id: String, index: int, run_seed: int,
		all_systems: Array) -> String:
	# WHICH LEGEND STANDS AT ONE MARK. Singular kinds are dealt across the whole
	# RUN before commons fill the remainder, which is why this needs the system
	# list rather than one system: "at most once in an entire game" is a
	# statement about every mark that exists, and it cannot be decided one
	# system at a time.
	#
	# Pure and total: same seed, same answer, forever, and no caller anywhere
	# stores the result.
	var plan := run_plan(run_seed, all_systems)
	return String(plan.get("%s:%d" % [system_id, index], ""))


static func run_plan(run_seed: int, all_systems: Array) -> Dictionary:
	# The whole run's assignment in one deterministic pass: "system:index" ->
	# kind. Built here rather than per-mark so the singular rule is enforced by
	# CONSTRUCTION -- a kind is dealt off a list that shrinks -- instead of by a
	# rejection test that could loop or, worse, silently fail open and place a
	# second serpent.
	var slots: Array = []
	for sid_v in all_systems:
		var sid := String(sid_v)
		var count := positions(sid, run_seed).size()
		for i in range(count):
			slots.append("%s:%d" % [sid, i])
	var out := {}
	if slots.is_empty():
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("farmark_plan|%d" % run_seed)
	# Fisher-Yates over a STABLE base order, board_for's own construction: the
	# slot list is built in system order and shuffled once, so the seed is the
	# only thing that varies.
	for i in range(slots.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = slots[i]
		slots[i] = slots[j]
		slots[j] = tmp
	# Deal the singulars first, one each, in a shuffled order of their own — so
	# WHICH singulars a run carries is itself a draw, and the ones it does not
	# carry simply are not in the world this time.
	#
	# The slice is what makes that true. Dealing the whole pool would fill every
	# run with all seven (there are always more slots than singulars), which is
	# the opposite of the rule it was meant to implement.
	var pool := SINGULAR.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = pool[i]
		pool[i] = pool[j]
		pool[j] = tmp
	pool = pool.slice(0, mini(SINGULAR_PER_RUN, pool.size()))
	for i in range(slots.size()):
		if i < pool.size():
			out[String(slots[i])] = String(pool[i])
		else:
			out[String(slots[i])] = String(COMMON[rng.randi() % COMMON.size()])
	return out


static func nearest_unseen(system_id: String, run_seed: int, from: Vector3,
		seen: Dictionary) -> Dictionary:
	# The mark the channel names in its reply: nearest to the pilot, skipping
	# any this pilot has already resolved. Returns {} when there is nothing left
	# to name, and the caller must have a sentence for that case rather than
	# quoting a bearing of zero.
	var best := {}
	var best_d := 1.0e30
	var spots := positions(system_id, run_seed)
	for i in range(spots.size()):
		if bool(seen.get("%s:%d" % [system_id, i], false)):
			continue
		var p: Vector3 = spots[i]
		var d := from.distance_to(p)
		if d < best_d:
			best_d = d
			best = {"index": i, "pos": p, "range": d}
	return best
