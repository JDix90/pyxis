class_name DeepSpace
extends Node3D
# Everything outside the charted system: the endless backdrop, and the distance
# bands that decide how strange, how dangerous and how rewarding a place is.
#
# NOTHING HERE IS SAVED. Every feature of the expanse is a pure function of
# (system id, cell x, cell z), computed on demand, so the same cell always
# produces the same thing and revisiting it costs zero bytes. The alternative —
# a visited-cells array — would grow every minute the player flies.
#
# Bands are measured on DEPTH (distance past the chart edge), never on radius,
# so a bigger system pushes its own expanse out with it: PYX-03's Reaches begin
# where PYX-03 ends, not at some absolute number that happens to suit PYX-01.

const BAND_EDGES := [0.0, 160.0, 440.0, 1100.0]
const BAND_NAMES := ["CHARTED", "THE SHOALS", "THE DRIFT", "THE REACHES", "THE QUIET"]

# Depth at which the deep dressing is fully faded in.
const DEEP_FULL := 260.0
const STAR_COUNT := 520
const MOTE_COUNT := 120

# --- sector streaming --------------------------------------------------------
# The expanse is a grid. A cell is generated when the player comes within WINDOW
# cells of it and torn down once they are KEEP cells away — the gap between the
# two is hysteresis, and without it a player hovering on a boundary would thrash
# a whole column of content in and out every few seconds.
#
# The sizing is load-bearing, not taste. At CELL 64 and WINDOW 2 the live block
# is 5x5, 320u across; crossing into a new cell adds a column whose nearest edge
# is 2*CELL = 128u away, against a visible ground half-extent of ~35u at maximum
# zoom. Content therefore always appears and disappears at least three screens
# off camera, which is the only reason this can be done without a fade.
const CELL := 64.0
const WINDOW := 2
const KEEP := 3
# Nothing generates until well past the chart edge. The charted system is
# authored down to the placement of its rocks, and streamed content dropped on
# top of it would fight that — as well as landing next to whatever a harness has
# hand-placed just outside `bounds`.
const CONTENT_MIN_DEPTH := 24.0

# --- the danger gradient -----------------------------------------------------
# No new enemy classes: the whole gradient is the parameters SwarmHostile and
# Hostile already carry, turned up per band. What changes with distance is how
# hard the thing hits, how long it takes to kill, how many of it there are and
# what colour it is — and colour is the tell that reads at a glance on a phone.
#
# Indexed by band, so the row for CHARTED is the identity row and every existing
# encounter in the game is untouched by construction.
#                        charted shoals drift reaches quiet
const PACK_CHANCE := [0.0, 0.0, 0.30, 0.42, 0.50]
const PACK_HP := [1.0, 1.0, 1.6, 2.4, 3.2]
const PACK_DIFFICULTY := [1.0, 1.0, 1.4, 2.0, 2.6]
const PACK_MIN := [0, 0, 3, 5, 6]
const PACK_MAX := [0, 0, 5, 7, 9]
# What they are carrying. The reward for going out is not a bigger number on the
# same crate, it is a better crate.
const PACK_DROP := ["", "", "isotopes", "cores", "relics"]
# A sentry rides along from the Reaches out: something that does not die to one
# Arc hop, which is the same lever the corsair pulls on a rich interdiction.
const PACK_ESCORT_FROM := 3

# --- deep stations -----------------------------------------------------------
# Sparse and getting less so with distance — the reward for going out is that
# there is somewhere out there. At these odds a 5x5 window holds a station about
# one visit in eight in the Drift, so finding one is an event rather than a
# feature of the landscape.
const STATION_CHANCE := [0.0, 0.035, 0.055, 0.075, 0.095]
# Debris and wrecks stay this far off a station; a nest stays much further, since
# it is the difference between a hard approach and an unreachable dock.
const STATION_CLEARANCE := 14.0
const STATION_SAFE_RADIUS := 34.0

# How far in from its cell's edges each thing is placed. These are not taste —
# they are what makes the clearances above hold ACROSS a cell boundary, which is
# the case the per-cell check cannot see. A cell only knows its own contents, so
# a nest in the cell next door is invisible to the station's keep-out test; the
# guarantee has to come from the geometry instead:
#
#     STATION_INSET + PACK_INSET = 36 >= STATION_SAFE_RADIUS (34)
#     STATION_INSET + ROCK_INSET = 26 >= STATION_CLEARANCE   (14)
#
# So the nearest a neighbouring cell's nest can ever get to a station is 36u,
# whatever either of them rolls.
const STATION_INSET := 22.0
const PACK_INSET := 14.0
const HULK_INSET := 12.0
const ROCK_INSET := 4.0

# --- what the beacons say ----------------------------------------------------
# Crossing a band plays an automated broadcast. This replaces the soft outer
# limit the plan originally called for, and it is a better answer: a wall says
# "the designer stopped building here", whereas a survey authority washing its
# hands of you says "people stopped coming here", which is the same information
# delivered as fiction instead of as UI.
#
# It also does the job the interdiction taper needs doing. Raiders thin out with
# distance (Main.DEEP_RAID_TAPER) and the reason is exactly this: nobody is
# watching. Saying so out loud is what turns a number into a place.
const BROADCASTS := [
	{},
	{
		"from": "GALACTIC SURVEY AUTHORITY — AUTOMATED BEACON",
		"body": "You are leaving charted space. Security patrols do not operate beyond this marker and cannot be dispatched to assist. Salvage, navigation and rescue are unsupported. Proceed at your own risk.",
		# v13. What the same beacon says once the register knows your name. "On
		# file" was stage one of the Commission, and this is the callback.
		"from_commissioned": "GALACTIC SURVEY AUTHORITY — REGISTERED VESSEL",
		"body_commissioned": "Charts on file. This marker stands on your readings. Patrols still do not operate beyond it, and the authority still cannot be dispatched to assist — but the bearing is yours, and it is written down.",
	},
	{
		"from": "GSA RELAY — LAST REPEATER",
		"body": "This is the final beacon on this bearing. No vessel has filed a return from beyond it this cycle. Contacts logged out here are not registered to any fleet.",
		"from_commissioned": "GSA RELAY — LAST REPEATER",
		"body_commissioned": "This is the final beacon on this bearing. One vessel has filed a return from beyond it. The file is open and the readings are yours.",
	},
	{
		"from": "GSA RELAY — SIGNAL DEGRADED",
		"body": "Carrier lost. This transmission is a recording. Whatever is out here was not surveyed, is not catalogued, and is not ours.",
		"from_commissioned": "GSA RELAY — SIGNAL DEGRADED",
		"body_commissioned": "Carrier lost. This transmission is a recording. Whatever is out here was not surveyed by us. It has been surveyed.",
	},
	# Band 4 carries NO commissioned keys, and that is the note the whole arc ends
	# on rather than an oversight. COMMISSIONED requires reaching THE QUIET, and
	# THE QUIET is the one band that will never acknowledge it — GUARD_DESIGNATION
	# for this band is already "UNREADABLE — IT DOES NOT ANSWER", so the data and
	# the fiction agree. Do not "finish" this entry.
	{
		"from": "· · · —— · · ·",
		"body": "The beacon net does not reach this far. Nothing is transmitting. Nothing is listening.",
	},
]


static func broadcast_for(band: int, commissioned := false) -> Dictionary:
	# Optional keys with a fallback rather than a parallel three-entry array: a
	# second array would be a second bounds contract that could disagree with the
	# first, and "band 4 is unchanged" would become a size mismatch instead of a
	# stated property of the data.
	if band <= 0 or band >= BROADCASTS.size():
		return {}
	var entry: Dictionary = BROADCASTS[band]
	if not commissioned:
		return entry
	return {
		"from": String(entry.get("from_commissioned", entry.get("from", ""))),
		"body": String(entry.get("body_commissioned", entry.get("body", ""))),
	}


# --- rigged hulks ------------------------------------------------------------
# Some wrecks out there are bait. Breaching one blows an EMP across the bay —
# drives and mounts dead for a few seconds — and whoever left it there comes to
# collect. Deeper means a better chance of it, a longer lockout, a bigger pack,
# and from the Reaches out a proper fighter riding along with the swarm.
#
# Two things make this a decision rather than a tax:
#
#   * it is SEEDED, like everything else here, so a given hulk is always rigged
#     or always is not. A trap that rerolled per visit would be a coin flip
#     wearing a mechanic's clothes.
#   * a rigged hulk carries MORE. You are not being punished for salvaging, you
#     are being offered a worse-odds bet with a bigger pot — and the tell below
#     is what lets you take it knowingly.
const TRAP_CHANCE := [0.0, 0.12, 0.26, 0.38, 0.50]
const TRAP_EMP := [0.0, 1.4, 1.9, 2.4, 2.8]
const TRAP_PACK_MIN := [0, 3, 4, 6, 7]
const TRAP_PACK_MAX := [0, 4, 6, 8, 10]
const TRAP_LOOT_BONUS := 1.6          # what the bet pays if you take it and live
const TRAP_ESCORT_FROM := 3

# How many deep stations keep a bonded store. Deliberately a minority: stations
# out here are already scarce, and one that will hold your cargo has to be a
# relief rather than an amenity. Not finding one is the point.
const DEEP_STORAGE_CHANCE := 0.15           # a Hostile joins the ambush from here out

# Nothing the expanse spawns may chase further than this. See
# SwarmHostile.despawn_radius for why the number has to exist at all.
# --- guarded hulks -----------------------------------------------------------
# Past a certain depth a wreck is not just lying there — something is standing
# over it. This is what makes approaching a hulk a DECISION rather than a flight
# plan: you can read the post from further out than you can read the rigged
# beacon, so the choice to commit is always available.
#
# Not from the chart edge: the Shoals have to keep teaching that going out is
# survivable, so the first wrecks a player ever finds stay unguarded.
const GUARD_MIN_DEPTH := 55.0

# 20% none, 25% two, 30% three, 25% four. There is deliberately NO one-guard
# case: a lone sentry reads as a straggler rather than a post, and it is the one
# size the geometry cannot make contest the breach (one gun in range instead of
# two). GUARD_BEARINGS enforces it structurally — a 1 added here has nowhere to
# stand.
const GUARD_COUNTS := [0, 2, 3, 4]
const GUARD_WEIGHTS := [0.20, 0.25, 0.30, 0.25]

# Guards get their OWN curve, not PACK_*. Hostile.difficulty scales BOTH hp and
# damage, and for a standing post those have to come apart. On the swarm curve a
# Quiet guard's shot is 14.0 x 2.6 = 36.4, against PYX-03's authored sentries at
# 14.0 x 2.2 = 30.8 — a machine 1100u from the nearest dock hitting 18% harder
# than anything on the chart, where you have a station to run to and a regen
# window. That inversion was the defect; HP was never the lethal axis.
#
# So a guard is scary through COUNT, HP and where it is standing, never alpha.
# What falls out is a band-gated decision with its answer already in the fitting
# console: you can tank a guarded crack in the Shoals and the Drift, and from the
# Reaches out you clear the post first or you fit Bulwark.
#                         charted shoals drift reaches quiet
const GUARD_DIFFICULTY := [1.0, 0.90, 1.10, 1.40, 1.65]
const GUARD_HP_SCALE := [1.0, 1.20, 1.45, 1.50, 1.60]

# Posts ring the BREACH POINT, not the hull: what they are guarding is the way in.
#
# Derelict._approach parks the ship at CRACK_RANGE * 0.78 = 5.07u from the breach
# point, on a bearing bounded to 32 degrees off the hull's outward axis by the
# 1.6 weighting in that function. Against ENGAGE_RANGE 9.0 at this stand-off the
# inner pair are always engaged (2.6-3.8u) and the outer pair only on an oblique
# approach (7.4u vs 9.8u straight-in). So a post puts TWO guns on you typically
# and three at worst, never four — the count sets how LONG the fight is, not how
# hard the hold is, and the difficulty curve above is tuned against that.
const GUARD_STANDOFF := 7.6
const GUARD_BEARINGS := [
	[], [],
	[26.0, -26.0],
	[26.0, -26.0, 100.0],
	[26.0, -26.0, 100.0, -100.0],
]
const GUARD_JITTER_DEG := 6.0
const GUARD_JITTER_STANDOFF := 0.4

# What the scanner can still tell you about the thing pointing a gun at you. The
# machine does not change with distance; your ability to NAME it does — the same
# arc BROADCASTS walks (authority, lapsed authority, a recording, no carrier) and
# the same arc the salvage grades walk. Index 0 is never read: nothing charted is
# guarded.
const GUARD_DESIGNATION := [
	"",
	"GSA PICKET — DECOMMISSIONED",
	"PICKET — REGISTRY LAPSED",
	"UNFLAGGED — NO PATTERN ON FILE",
	"UNREADABLE — IT DOES NOT ANSWER",
]
const GUARD_COUNT_WORD := ["NOTHING", "ONE", "TWO", "THREE", "FOUR"]

const HOSTILE_LEASH := 140.0
# How close the player gets before a seeded nest actually becomes ships. Comfortably
# outside the ~34u visible half-extent at maximum zoom, so a pack is never seen
# popping into existence, and comfortably inside HOSTILE_LEASH, so it is never
# born already past the range at which it gives up.
const ENCOUNTER_TRIGGER := 44.0

var generating := true

var _bounds := 40.0
var _id := ""
var _stars: DeepField
var _motes: DeepField
var _cold: MeshInstance3D
var _cold_mat: StandardMaterial3D
var _k_last := -1.0

# Live cells, keyed by Vector2i. The value is the cell's content node, or null
# for a cell that generated nothing — the key still has to be present, or an
# empty cell is re-planned on every frame it stays in the window.
var _cells := {}
var _cell_last := Vector2i(0x7fffffff, 0x7fffffff)
# Cells registered but not yet dressed. See _stream for the split and why.
var _build_queue: Array[Vector2i] = []
# cell -> { seam index: true }. A dict of dicts rather than the flat set
# _cracked and _surveyed use, because a cell holds at most one hulk but can hold
# a seam on every rock in it.
var _mined := {}
# Per-frame budget for building meshes. About a third of a 60Hz frame, which
# leaves room for everything else that happens on a frame where the player
# crossed a boundary -- and cells are drained nearest-first, so the budget
# spends itself on what is in front of the ship.
const BUILD_BUDGET_USEC := 5000

# Nests that are seeded but have not been walked into yet, keyed by cell.
# Guard posts. The tree and the ownership record are different things — the same
# split Obstacles already makes with owner tags. Nodes live in system_root so
# Hostile._die()'s deferred loot spawn keeps the guarantee every other deep
# hostile has; the CELL owns them, and _despawn_cell frees them explicitly.
var _guards := {}       # Vector2i -> Array[Hostile]
var _guard_origin := {} # Vector2i -> Vector3, the hulk the post stands over
var _cleared := {}      # Vector2i -> true, posts whose last guard died this session
# Hulls already opened this session. The post standing over the wreck has had
# this guarantee since it shipped and the mast on its stern has had it since the
# survey landed; the HULL was the one that forgot, and _build_post's own comment
# describes the exact farm that left open — 200u out and back, full loot every
# lap, somewhere ports cannot reach. Session-scoped like its two neighbours, so
# a warp resets it and the geometry argument in 22 keeps covering all three.
var _cracked := {}      # Vector2i -> true, hulls breached this session
var _hailed := {}       # Vector2i -> true, posts already announced this session
var _counted := {}      # Vector2i -> true, posts already credited to the logbook
# Cells whose landmark has already been read this session. Session-only like
# _sprung, and for the same reason 17 gives: persisting it would be a
# visited-cells array by another name, growing every minute the player flies.
# The consequence — a warp resets surveys — is asserted on purpose in CARTTEST,
# so a future "fix" that saves this trips a FAIL and forces the conversation.
var _surveyed := {}

var _armed := {}
# Cells whose nest has already been sprung this visit. Session-only and rebuilt
# with the system, like everything else out here — flying a circle back through
# a sector you just fought in must not hand you the same pack a second time.
var _sprung := {}


# --- bands (pure) -----------------------------------------------------------

static func band_of(depth: float) -> int:
	if depth <= 0.0:
		return 0
	for i in range(BAND_EDGES.size() - 1, 0, -1):
		if depth >= BAND_EDGES[i]:
			return i + 1
	return 1


static func band_name(depth: float) -> String:
	return BAND_NAMES[band_of(depth)]


static func band_color(depth: float) -> Color:
	return Palette.band_color(band_of(depth))


# --- construction -----------------------------------------------------------

func configure(def: Dictionary, system_id: String) -> void:
	_bounds = float(def.get("bounds", 40.0))
	_id = system_id
	var sf: Dictionary = def.get("starfield", {})
	var seed_value := hash(system_id)

	# Far layer: the sky that never runs out. Low parallax, so it slides slowly
	# and reads as genuinely distant against the world-locked per-system field,
	# which is left exactly as it was and becomes the NEAR sky over the system.
	_stars = DeepField.new()
	_stars.parallax = 0.30
	_stars.half = 120.0
	add_child(_stars)
	_stars.build(STAR_COUNT, sf.get("tint", Color(0.85, 0.9, 1.0)), 0.05, seed_value)

	# Near layer: specks that slide past the hull at nearly full speed. Once the
	# lattice is behind you this is the only thing left that sells motion, so it
	# fades IN with depth rather than being on everywhere.
	_motes = DeepField.new()
	_motes.parallax = 0.92
	_motes.half = 30.0
	_motes.rebake_step = 4.0
	add_child(_motes)
	_motes.build(MOTE_COUNT, Color(0.72, 0.78, 0.9), 0.022, seed_value ^ 0x5bf03)
	_motes.set_presence(0.0)

	# The colour of nothing: one huge inside-out sphere under the play plane that
	# follows the camera, replacing the system's haze once the haze is behind
	# you. Same primitive as _build_haze, one instance, effectively free.
	_cold = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.0
	sm.height = 2.0
	sm.radial_segments = 12
	sm.rings = 8
	_cold.mesh = sm
	_cold.scale = Vector3.ONE * 190.0
	_cold_mat = Palette.emissive(Color(Palette.DEEP_COLD.r, Palette.DEEP_COLD.g,
		Palette.DEEP_COLD.b, 0.0), 1.0)
	_cold_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_cold_mat.cull_mode = BaseMaterial3D.CULL_FRONT
	_cold.material_override = _cold_mat
	add_child(_cold)


func set_generation(on: bool) -> void:
	# Harnesses that assert against a hand-placed world turn generation off, the
	# same way they already pin `_wave_timer`. PYXIS_COLLISIONTEST in particular
	# puts its synthetic body at (34, 0, 34) — magnitude 48.1, which is OUTSIDE
	# PYX-01's bounds of 40, so a generated rock could land next to it and
	# corrupt the slide assertion.
	generating = on
	if not on:
		_despawn_all()


# --- sector streaming -------------------------------------------------------

static func guard_count(roll: float) -> int:
	# Pure, so the distribution's edges are assertable with no RNG, no spawning
	# and no flying.
	var acc := 0.0
	for i in range(GUARD_WEIGHTS.size()):
		acc += GUARD_WEIGHTS[i]
		if roll < acc:
			return GUARD_COUNTS[i]
	return GUARD_COUNTS[GUARD_COUNTS.size() - 1]


static func guard_posts(hulk_pos: Vector3, rot_y: float, count: int,
		rng: RandomNumberGenerator) -> Array:
	# Derived ANALYTICALLY from the hull transform, never by reading
	# Derelict.breach_point — that is set in _ready, which fires from add_child,
	# before the spawner assigns global_position. Reading it at plan time returns
	# the container origin. Same trap as Hostile._home.
	var out: Array = []
	if count <= 0 or count >= GUARD_BEARINGS.size():
		return out
	var basis := Basis(Vector3.UP, deg_to_rad(rot_y))
	var breach: Vector3 = hulk_pos + basis * Derelict.BEACON_LOCAL
	breach.y = 0.0
	# The outward prow axis: the direction the beacon sits from the hull centre.
	var outward := breach - hulk_pos
	outward.y = 0.0
	if outward.length() < 0.01:
		outward = Vector3.FORWARD
	outward = outward.normalized()
	for b_v in GUARD_BEARINGS[count]:
		var ang := deg_to_rad(float(b_v) + rng.randf_range(-GUARD_JITTER_DEG, GUARD_JITTER_DEG))
		var reach := GUARD_STANDOFF + rng.randf_range(-GUARD_JITTER_STANDOFF, GUARD_JITTER_STANDOFF)
		var dir := Basis(Vector3.UP, ang) * outward
		out.append(breach + dir * reach)
	return out


static func cell_key(system_id: String, cx: int, cz: int) -> String:
	# The stable identity of a deep station: not its archetype (shared by every
	# station of that kind, everywhere) but the cell it stands in.
	return "%s:%d:%d" % [system_id, cx, cz]


func cell_has_bay(system_id: String, cx: int, cz: int) -> bool:
	# Re-derives a cell from the generator and reports whether it holds a station
	# with a bay. GameState validates every saved deep bay key through this, so a
	# stale or edited save self-corrects instead of carrying phantom stores.
	if system_id != _id:
		return false
	var st: Dictionary = plan_cell(cx, cz).get("station", {})
	return not st.is_empty() and bool(st.get("storage", false))


static func cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CELL), floori(pos.z / CELL))


static func cell_centre(cx: int, cz: int) -> Vector3:
	return Vector3((float(cx) + 0.5) * CELL, 0.0, (float(cz) + 0.5) * CELL)


func _owner_tag(cx: int, cz: int) -> String:
	return "deep:%d:%d" % [cx, cz]


func plan_cell(cx: int, cz: int) -> Dictionary:
	# PURE. Given a cell it returns exactly what that cell contains, with no nodes
	# built and no state touched, and `_spawn_cell` builds from what this returns.
	# One source of truth is what makes "the same cell always holds the same
	# thing" a property of the code rather than a claim about it — and it lets a
	# harness compare two visits without having to fly there twice.
	var depth := depth_at(cell_centre(cx, cz))
	var band := band_of(depth)
	var out := {"band": band, "depth": depth, "rocks": [], "hulk": {}, "pack": {},
		"station": {}}
	if band == 0:
		return out

	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d" % [_id, cx, cz])
	var base := Vector3(float(cx) * CELL, 0.0, float(cz) * CELL)

	# A station rolls FIRST, and everything after it gives it room. It is the
	# rarest and most valuable thing a cell can hold — somewhere to dock is the
	# only safe state this game has — and losing one to a boulder that happened to
	# roll on top of it would be the worst possible way to lose one.
	if rng.randf() < STATION_CHANCE[band]:
		var kinds := DeepPortDB.for_band(band)
		if not kinds.is_empty():
			var arch: Dictionary = kinds[rng.randi() % kinds.size()]
			var sp := base + Vector3(rng.randf_range(STATION_INSET, CELL - STATION_INSET), 0.0,
				rng.randf_range(STATION_INSET, CELL - STATION_INSET))
			if depth_at(sp) >= CONTENT_MIN_DEPTH:
				# A bonded store, on a minority of stations. Rolled here from the
				# same seeded stream as everything else, so a given station always
				# has one or always does not — the scarcity has to be a property
				# of the place, or "is there a bay at that relay" stops being
				# something a player can learn and remember.
				out["station"] = {"pos": sp, "archetype": String(arch["id"]),
					"storage": rng.randf() < DEEP_STORAGE_CHANCE}
	var keep_out: Vector3 = out["station"].get("pos", Vector3(1e9, 0.0, 1e9))

	# Debris. Thin in the Shoals and thickening outward, so the expanse reads as
	# emptier near home and more cluttered where nobody has ever swept it.
	if rng.randf() < [0.0, 0.34, 0.46, 0.58, 0.66][band]:
		for i in range(rng.randi_range(2, 2 + band)):
			var pos := base + Vector3(rng.randf_range(ROCK_INSET, CELL - ROCK_INSET), -3.0,
				rng.randf_range(ROCK_INSET, CELL - ROCK_INSET))
			if depth_at(pos) < CONTENT_MIN_DEPTH or pos.distance_to(keep_out) < STATION_CLEARANCE:
				continue
			var sx := rng.randf_range(2.2, 4.0 + float(band))
			out["rocks"].append({
				"pos": pos,
				"scale": Vector3(sx, rng.randf_range(2.0, 4.0), sx * rng.randf_range(0.7, 1.3)),
			})

	# A drifting wreck: the reason to go out at all. Loot climbs with the band,
	# so the trip pays for itself further out — and NOT a survey, so cracking one
	# charts nothing and wakes nothing (see Derelict.counts_as_survey).
	if rng.randf() < [0.0, 0.10, 0.15, 0.19, 0.24][band]:
		var hp := base + Vector3(rng.randf_range(HULK_INSET, CELL - HULK_INSET), 0.0,
			rng.randf_range(HULK_INSET, CELL - HULK_INSET))
		if depth_at(hp) >= CONTENT_MIN_DEPTH and hp.distance_to(keep_out) >= STATION_CLEARANCE:
			var rigged: bool = rng.randf() < float(TRAP_CHANCE[band])
			# Hoisted out of the dict literal: guard_posts needs the same hull
			# rotation to derive the breach point, and re-rolling it there would
			# put the posts around a hull facing somewhere else.
			var rng_rot := rng.randf_range(0.0, 360.0)
			out["hulk"] = {
				"pos": hp,
				"rot_y": rng_rot,
				"loot": int(round(70.0 * [1.0, 1.15, 1.6, 2.2, 2.9][band]
					* (TRAP_LOOT_BONUS if rigged else 1.0))),
				"crack_time": 1.8 + 0.2 * float(band),
				"trap": {
					"emp": TRAP_EMP[band],
					"count": rng.randi_range(TRAP_PACK_MIN[band], TRAP_PACK_MAX[band]),
					"hp_scale": PACK_HP[band],
					"difficulty": PACK_DIFFICULTY[band],
					"tint": Palette.band_color(band),
					"drop": PACK_DROP[band],
					"escort": band >= TRAP_ESCORT_FROM,
					"band": band,
				} if rigged else {},
			}
			# A STANDING POST, on its own salted stream.
			#
			# plan_cell's RNG is one linear sequence, so a roll inserted anywhere
			# but the last line reshuffles every cell in the game. Salting mirrors
			# _spring's "|pack" and buys two things: existing determinism is
			# untouched by construction, and "guards roll independently of whether
			# the hulk is rigged" becomes true STRUCTURALLY rather than
			# statistically — on a shared stream the guard roll would sit
			# downstream of the trap roll's consumption.
			#
			# STATION_SAFE_RADIUS, not STATION_CLEARANCE: a hulk keeps only 14u
			# from a station in its own cell, and a post reaches 14.2u past the
			# hulk centre, so on the tighter constant a guard could stand on a
			# docking ring. At 34u the arithmetic is 34 - 14.2 = 19.8 against
			# DOCK_RANGE 5 + ENGAGE_RANGE 9 = 14, so no guard from this cell or
			# the one next door can ever put a docking ship inside its range.
			if depth_at(hp) >= GUARD_MIN_DEPTH \
					and hp.distance_to(keep_out) >= STATION_SAFE_RADIUS:
				var grng := RandomNumberGenerator.new()
				grng.seed = hash("%s|%d|%d|guard" % [_id, cx, cz])
				var gn := guard_count(grng.randf())
				if gn > 0:
					out["hulk"]["guards"] = {
						"count": gn,
						"band": band,
						"difficulty": GUARD_DIFFICULTY[band],
						"hp_scale": GUARD_HP_SCALE[band],
						"tint": Palette.band_color(band),
						"designation": GUARD_DESIGNATION[band],
						"origin": hp,
						"posts": guard_posts(hp, rng_rot, gn, grng),
					}

	# A nest. Nothing hunts you in the Shoals — the first band out is the one that
	# has to teach that the expanse is survivable, or nobody goes to the second.
	if rng.randf() < PACK_CHANCE[band]:
		var pp := base + Vector3(rng.randf_range(PACK_INSET, CELL - PACK_INSET), 0.0,
			rng.randf_range(PACK_INSET, CELL - PACK_INSET))
		# And nothing camps the dock ring. Docking is the game's one safe state;
		# a nest sitting on the only station for four hundred units would turn the
		# reward for the whole trip into a thing you cannot reach.
		if depth_at(pp) >= CONTENT_MIN_DEPTH and pp.distance_to(keep_out) >= STATION_SAFE_RADIUS:
			out["pack"] = {
				"pos": pp,
				"count": rng.randi_range(PACK_MIN[band], PACK_MAX[band]),
				"hp_scale": PACK_HP[band],
				"difficulty": PACK_DIFFICULTY[band],
				"tint": Palette.band_color(band),
				"drop": PACK_DROP[band],
				"escort": band >= PACK_ESCORT_FROM,
			}

	# APPENDED, after every existing roll and on its own salted stream, exactly
	# like the guards. The roll ORDER above is load-bearing -- a roll inserted
	# anywhere in it reshuffles every cell in the game -- so a new feature may
	# only ever be added at the end, and one that needs randomness of its own
	# takes a separate seed rather than a slice of this one.
	out["landmark"] = landmark_at(cx, cz, band)
	# APPENDED AFTER THE LANDMARK, on its own salted stream, for the reason
	# written directly above. This one looks riskier than it is: it READS
	# out["rocks"], which the shared sequence produced, but it must never DRAW
	# from `rng` -- a seam roll on the shared stream would move every rock, hulk,
	# nest and station in the game by one draw. PYXIS_MINETEST's WORLD
	# FINGERPRINT is the check, against a hash recorded before seams existed.
	out["seams"] = seams_for(cx, cz, band, out["rocks"])
	return out


# --- seams -------------------------------------------------------------------
# Ore lives on the surface of rocks that were already there. Thin and poor near
# home, thick and rich outward -- and that gradient is not flavour, it is the
# anti-farm mechanism. `_mined` is SESSION state (see note_mined), so a warp
# re-rolls the expanse; what makes that safe is that the band you can reach in
# one warp is the band that pays worst. Band 1 works out at roughly 330 credits
# a minute against a combat baseline of about 2,000 -- PYXIS_MINETEST's WARP FARM
# prints the measured figure. (This said 195 until stage 3: 195 is the band-1
# mean SEAM VALUE from CommodityDB.SEAM_YIELDS, not a rate, and the two were
# transcribed into one sentence.)
const SEAM_CHANCE := [0.0, 0.22, 0.30, 0.38, 0.45]
const SEAM_UNITS := [0, 3, 4, 4, 5]
# How far outside the rock's own collision sphere the seam node sits. A seam
# measured from the ROCK's centre would be unreachable on a big one: a QUIET
# boulder's obstacle radius reaches 6.56 and MineableSeam.MINE_RANGE is 6.0, so
# the ship would be pushed out past its own hold range and the seam could never
# be worked. system_builder.gd:288 records this exact bug being shipped once.
const SEAM_STANDOFF := 0.6


func seams_for(cx: int, cz: int, band: int, rocks: Array) -> Array:
	var out: Array = []
	if band <= 0 or rocks.is_empty():
		return out
	var table: Array = CommodityDB.seam_yields(band)
	if table.is_empty():
		return out
	var srng := RandomNumberGenerator.new()
	srng.seed = hash("%s|%d|%d|seam" % [_id, cx, cz])
	for i in range(rocks.size()):
		if srng.randf() >= SEAM_CHANCE[band]:
			continue
		var r: Dictionary = rocks[i]
		var sc: Vector3 = r["scale"]
		var radius := minf(sc.x, sc.z) * 0.82
		# On the rock's flank, on the play plane. The rock itself sits at y -3,
		# below the plane the ship flies on, so the seam is what the player
		# actually approaches.
		var ang := srng.randf_range(0.0, TAU)
		out.append({
			"rock": i,
			"pos": Vector3(r["pos"].x, 0.0, r["pos"].z)
				+ Vector3(cos(ang), 0.0, sin(ang)) * (radius + SEAM_STANDOFF),
			"good": String(table[srng.randi() % table.size()]),
			"units": SEAM_UNITS[band],
			"band": band,
		})
	return out


func note_mined(cell: Vector2i, index: int) -> void:
	# SESSION state, like _cracked and _surveyed. 17 refuses a persistent
	# visited-cells array because it grows every minute the player flies, and
	# rocks are the most numerous thing out there -- a saved one would grow
	# faster than surveys would. What stops this being a farm is the band
	# gradient, not a save. See PYXIS_MINETEST's WARP FARM.
	if not _mined.has(cell):
		_mined[cell] = {}
	(_mined[cell] as Dictionary)[index] = true


func is_mined(cell: Vector2i, index: int) -> bool:
	return _mined.has(cell) and (_mined[cell] as Dictionary).has(index)


# --- landmarks ---------------------------------------------------------------
# The expanse was uniform noise: every cell rolled the same four things with the
# same tables, so flying out felt like more of the same rather than like going
# somewhere. Landmarks are the second layer -- one per SUPERCELL of 4x4 cells,
# themed by band, so there is roughly one deliberate object every 256 units and
# what it is tells you where you are without reading the label.
#
# This is what "designed rather than random" means here: not less randomness,
# but randomness at two scales, with the coarse one carrying meaning. A single
# scale is noise however you tune it.
const SUPERCELL := 4
# What stands in each band. Band 0 is charted space and gets nothing -- a
# landmark inside the survey volume would be a landmark on a map that already
# has one.
const LANDMARKS := ["", "pylon", "frame", "monolith", "marker"]


static func supercell_of(cx: int, cz: int) -> Vector2i:
	# Floor division, not truncation: -1 / 4 truncates toward zero and puts the
	# cells either side of the origin in the same supercell, which would double
	# the landmark density in exactly the region the player crosses first.
	return Vector2i(floori(float(cx) / float(SUPERCELL)), floori(float(cz) / float(SUPERCELL)))


static func landmark_cell(id: String, sx: int, sz: int) -> Vector2i:
	# Which cell of the supercell carries it. Pure, salted, and independent of
	# every other roll, so adding or removing landmarks cannot move a rock.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d|landmark" % [id, sx, sz])
	return Vector2i(sx * SUPERCELL + rng.randi_range(0, SUPERCELL - 1),
		sz * SUPERCELL + rng.randi_range(0, SUPERCELL - 1))


func landmark_at(cx: int, cz: int, band: int) -> Dictionary:
	if band <= 0 or band >= LANDMARKS.size():
		return {}
	var sc := supercell_of(cx, cz)
	if landmark_cell(_id, sc.x, sc.y) != Vector2i(cx, cz):
		return {}
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d|landmark_at" % [_id, cx, cz])
	var base := Vector3(float(cx) * CELL, 0.0, float(cz) * CELL)
	var at := base + Vector3(CELL * 0.5, 0.0, CELL * 0.5)
	if depth_at(at) < CONTENT_MIN_DEPTH:
		return {}
	return {
		"kind": String(LANDMARKS[band]),
		"pos": at,
		"rot_y": rng.randf_range(0.0, 360.0),
		"band": band,
	}


func _stream(around: Vector3) -> void:
	var here := cell_of(around)
	if here == _cell_last:
		return
	_cell_last = here

	# Two passes, and the split between them is the whole point.
	#
	# Everything the GAME needs from a cell -- that it exists, where its collision
	# spheres are, whether a nest is armed -- is derived from plan_cell, which is
	# pure arithmetic and costs nothing. That happens now, for the whole window,
	# exactly as it always did.
	#
	# Everything the EYE needs -- meshes, a Derelict, a Port -- is queued. That is
	# where the time actually goes: measured by PYXIS_STREAMTEST, a single
	# crossing spiked to 44ms building one row of five when one of them held a
	# station, which is roughly three dropped frames in the middle of flying.
	#
	# Determinism is untouched. plan_cell is still the only source of truth and is
	# still called in exactly the same order; only the moment a mesh appears
	# moves, and nothing reads a mesh to decide anything.
	for cz in range(here.y - WINDOW, here.y + WINDOW + 1):
		for cx in range(here.x - WINDOW, here.x + WINDOW + 1):
			var key := Vector2i(cx, cz)
			if not _cells.has(key):
				_cells[key] = _register_cell(cx, cz)
				var pack: Dictionary = plan_cell(cx, cz)["pack"]
				if not pack.is_empty() and not _sprung.has(key):
					_armed[key] = pack
				if _cells[key] != null:
					_build_queue.append(key)

	for key_v in _cells.keys():
		var key: Vector2i = key_v
		if absi(key.x - here.x) > KEEP or absi(key.y - here.y) > KEEP:
			_despawn_cell(key)

	# Nearest first, so what the player is flying toward is dressed before what
	# they are flying away from.
	var origin := here
	_build_queue.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - origin).length_squared() < (b - origin).length_squared())


# Cells dressed on the most recent frame that dressed any. This, not a
# stopwatch, is what the budget actually guarantees -- and unlike wall-clock
# milliseconds it means the same thing on a loaded build machine as on a phone.
var built_last_frame := 0


func build_backlog() -> int:
	# Read-back for PYXIS_STREAMTEST. Whether the queue actually empties is the
	# question that decides if amortising was correct or merely quieter.
	return _build_queue.size()


func _drain_queue() -> void:
	# At least one cell per frame, so the queue provably empties even if a single
	# cell exceeds the whole budget -- which is exactly the case that made this
	# necessary, and a budget that could refuse everything would stall forever.
	if _build_queue.is_empty():
		return
	var started := Time.get_ticks_usec()
	var built := 0
	while not _build_queue.is_empty():
		var key: Vector2i = _build_queue.pop_front()
		var node = _cells.get(key)
		if node == null or not is_instance_valid(node):
			continue
		_populate_cell(key.x, key.y, node)
		built += 1
		if Time.get_ticks_usec() - started >= BUILD_BUDGET_USEC:
			break
	built_last_frame = built


func stream_now(around: Vector3) -> void:
	# The escape hatch. Arriving somewhere must never show a frame of empty space
	# where a station is, and first entry was measured at 6.4ms for the whole
	# window -- comfortably inside the warp flash that already covers it. Used by
	# warps and by the capture harnesses, which frame compositions by hand and
	# cannot wait for a queue.
	_stream(around)
	while not _build_queue.is_empty():
		var key: Vector2i = _build_queue.pop_front()
		var node = _cells.get(key)
		if node != null and is_instance_valid(node):
			_populate_cell(key.x, key.y, node)


func _register_cell(cx: int, cz: int):
	# The cheap half: the container plus every collision sphere, all derived from
	# plan_cell. Runs synchronously for the whole window on the frame the player
	# crosses a boundary, so the world is solid before it is visible -- flying
	# through a rock that has not been dressed yet would be a far worse bug than
	# seeing it appear a frame late.
	var plan := plan_cell(cx, cz)
	var rocks: Array = plan["rocks"]
	var hulk: Dictionary = plan["hulk"]
	var station: Dictionary = plan["station"]
	# A landmark counts as content. Without it here, a supercell whose elected
	# cell happens to roll no rocks, no hulk and no station is discarded as empty
	# and the landmark never spawns -- which would silently thin them out in
	# exactly the sparse cells where one is most worth having.
	var mark: Dictionary = plan.get("landmark", {})
	# Seams only exist where rocks do, so they cannot make an otherwise-empty
	# cell contentful -- but naming them here keeps the check honest if that ever
	# stops being true.
	if rocks.is_empty() and hulk.is_empty() and station.is_empty() and mark.is_empty():
		return null

	var tag := _owner_tag(cx, cz)
	var node := Node3D.new()
	node.name = "Cell_%d_%d" % [cx, cz]
	add_child(node)

	for r_v in rocks:
		var r: Dictionary = r_v
		var s: Vector3 = r["scale"]
		Obstacles.add(r["pos"], minf(s.x, s.z) * 0.82, tag)

	if not hulk.is_empty():
		# Derived from rot_y rather than read off the node's basis, because the
		# node does not exist yet. Same vector either way: the Derelict's only
		# rotation is this yaw, applied right after add_child in _populate_cell.
		var fwd := Vector3(0.0, 0.0, 1.0).rotated(Vector3.UP, deg_to_rad(float(hulk["rot_y"])))
		var at: Vector3 = hulk["pos"]
		Obstacles.add(at - fwd * 2.6, 1.9, tag)
		Obstacles.add(at + fwd * 2.6, 1.9, tag)

	if not station.is_empty():
		var arch0 := DeepPortDB.by_id(String(station["archetype"]))
		if not arch0.is_empty():
			Obstacles.add(station["pos"], Port.HULL_OBSTACLE_RADIUS, tag)
	return node


func _populate_cell(cx: int, cz: int, node: Node3D) -> void:
	# The expensive half: meshes, a Derelict with its own kitbash, a Port with
	# six silhouettes' worth of construction. Drained under a frame budget.
	var plan := plan_cell(cx, cz)
	var rocks: Array = plan["rocks"]
	var hulk: Dictionary = plan["hulk"]
	var station: Dictionary = plan["station"]

	for seam_v in (plan.get("seams", []) as Array):
		var sd: Dictionary = seam_v
		var seam := MineableSeam.new()
		seam.good = String(sd["good"])
		seam.units = int(sd["units"])
		seam.band = int(sd["band"])
		seam.mine_time = 4.0 + 0.6 * float(int(sd["band"]) - 1)
		seam.cell = Vector2i(cx, cz)
		seam.seam_index = int(sd["rock"])
		# Set BEFORE add_child, the ordering the mast and the derelict already
		# rely on: _ready is what applies the already-worked state.
		seam.mined = is_mined(Vector2i(cx, cz), int(sd["rock"]))
		node.add_child(seam)
		seam.global_position = sd["pos"]

	# Scenery, so it dresses with the meshes and registers no collision -- a
	# landmark you can bump into is an obstacle, and these exist to be looked at
	# from a distance rather than flown to.
	var mark: Dictionary = plan.get("landmark", {})
	if not mark.is_empty():
		var node_mark := Landmarks.build(String(mark["kind"]), int(mark["band"]))
		if node_mark != null:
			node.add_child(node_mark)
			node_mark.global_position = mark["pos"]
			node_mark.rotation_degrees.y = float(mark["rot_y"])

	for r_v in rocks:
		var r: Dictionary = r_v
		var rock := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 1.0
		sm.height = 2.0
		sm.radial_segments = 10
		sm.rings = 6
		rock.mesh = sm
		rock.material_override = Palette.matte(Color(0.13, 0.12, 0.13))
		node.add_child(rock)
		rock.global_position = r["pos"]
		rock.scale = r["scale"]

	if not hulk.is_empty():
		var d := Derelict.new()
		d.loot_total = int(hulk["loot"])
		d.crack_time = float(hulk["crack_time"])
		# The one thing a deep hulk must NOT do is chart the next system.
		d.counts_as_survey = false
		# Set BEFORE add_child, the same ordering the mast below relies on: _ready
		# is what applies the already-opened state.
		d.cell = Vector2i(cx, cz)
		d.deep = true
		d.cracked = _cracked.has(Vector2i(cx, cz))
		node.add_child(d)
		d.global_position = hulk["pos"]
		d.rotation_degrees.y = float(hulk["rot_y"])
		# After add_child: arm_trap restyles the beacon, which _ready builds.
		d.arm_trap(hulk.get("trap", {}))
		_build_post(Vector2i(cx, cz), hulk.get("guards", {}))

		# The survey mast rides the STERN, opposite the prow breach beacon, at the
		# beacon's own offset mirrored: -6.6 forward, +6.6 aft.
		#
		# It used to sit at 4.5, which put the dish INSIDE the hull. Not partly --
		# the dish's worst-case box is x +/-0.52, y 1.445..2.455, z 3.98..5.02,
		# and _build_mesh's stern block spans x +/-0.7, y -0.75..2.75, z 2.5..5.5.
		# Inside on all three axes. What reached the screen was the fraction of
		# the ring that happened to clear a silhouette edge at one spin phase, on
		# an affordance the player is supposed to fly to and hold on.
		#
		# 6.6 clears it twice over: aft of the stern block (which ends at 5.5) and
		# above the spine roof (y 1.0, and the dish sits at 1.45 and up). The
		# stalk still passes THROUGH the spine, which is what a mast bolted to a
		# hull should look like.
		#
		# The old 4.5 was chosen for a separation figure, and the figure survives:
		# 13.2 units between the two anchors, against a CameraRig._pick radius of
		# 60 SCREEN pixels -- which the pair clears by roughly 5x at every legal
		# zoom. Moving aft also moves AWAY from the guard ring, so the "quiet
		# option" stand-off argument only gets stronger.
		#
		# It fixes a second bug for free. CRACK_RANGE and SURVEY_RANGE are 6.5
		# each, so at 11.1 apart the two in-range spheres OVERLAPPED: both wrote
		# hud.prompt's single slot, and leaving one cleared the other's still-
		# valid prompt. 13.2 > 13.0, so the lens is gone.
		var mast := SurveyMast.new()
		mast.band = int(plan["band"])
		mast.survey_time = 3.0 + 0.5 * float(int(plan["band"]) - 1)
		mast.cell = Vector2i(cx, cz)
		mast.surveyed = _surveyed.has(Vector2i(cx, cz))
		node.add_child(mast)
		mast.global_position = d.global_position + d.global_transform.basis.z * SurveyMast.HULL_OFFSET

	if not station.is_empty():
		var arch := DeepPortDB.by_id(String(station["archetype"]))
		if not arch.is_empty():
			var p := Port.new()
			p.port_id = String(arch["id"])
			p.port_name = String(arch["name"])
			p.kind = String(arch["kind"])
			# The def travels on the node. Nothing is added to SystemDB, so the
			# market-event roll, the rumour loop and STATIONTEST's registry sweeps
			# never see this station exist.
			# DUPLICATED, and this is not optional. DeepPortDB.by_id returns the
			# ARCHETYPES entry itself, and dictionaries are references — so
			# appending "storage" to p.def["services"] below would append it to
			# the archetype, and every Shoal Relay generated afterwards, in every
			# system, for the rest of the session, would have a bay.
			p.def = arch.duplicate(true)
			if bool(station.get("storage", false)):
				(p.def["services"] as Array).append("storage")
			# The bay is keyed on the CELL, never on port_id: port_id is the
			# archetype, shared by every station of this kind everywhere.
			p.bay_key = cell_key(_id, cx, cz)
			node.add_child(p)
			p.global_position = station["pos"]


func _check_encounters(at: Vector3) -> void:
	# At most 25 armed nests, and almost always none — this is a distance check
	# over a near-empty dictionary, not a search.
	if not _armed.is_empty():
		for key_v in _armed.keys():
			var key: Vector2i = key_v
			var pack: Dictionary = _armed[key]
			var p: Vector3 = pack["pos"]
			if Vector2(p.x - at.x, p.z - at.z).length() <= ENCOUNTER_TRIGGER:
				_spring(key, pack)
	if not _guards.is_empty():
		_check_hails(at)


func _check_hails(at: Vector3) -> void:
	# Reuses ENCOUNTER_TRIGGER rather than inventing a hail range: one number for
	# "the expanse has noticed you" beats two, or the player learns two distances
	# for the same sensation.
	#
	# _hailed is session-only and deliberately NOT cleared on despawn, same as
	# _sprung: flying a circle back through a sector you already read must not
	# hand you the same announcement twice. A cleared post has no standing guards
	# and is skipped for free.
	for key_v in _guards.keys():
		var key: Vector2i = key_v
		if _hailed.has(key) or post_standing(key) == 0:
			continue
		var origin: Vector3 = _guard_origin.get(key, Vector3.ZERO)
		if Vector2(origin.x - at.x, origin.z - at.z).length() > ENCOUNTER_TRIGGER:
			continue
		_hailed[key] = true
		var band := band_of(depth_at(origin))
		var n := post_standing(key)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			hud.show_toast("%s STANDING — %s" % [
				GUARD_COUNT_WORD[mini(n, GUARD_COUNT_WORD.size() - 1)],
				GUARD_DESIGNATION[band]], Palette.band_color(band))


func _spring(key: Vector2i, pack: Dictionary) -> void:
	# Hostiles go into SYSTEM_ROOT, never into the cell node. A pack that belonged
	# to its cell would vanish mid-fight the moment the chase carried the player
	# past the streaming window — which, since a swarm is faster than the player,
	# is exactly what a real chase does.
	_armed.erase(key)
	_sprung[key] = true
	var root := get_parent()
	if root == null:
		return

	var origin: Vector3 = pack["pos"]
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d|pack" % [_id, key.x, key.y])
	var count := int(pack["count"])
	var drop := String(pack["drop"])

	for i in range(count):
		var s := SwarmHostile.new()
		s.difficulty = float(pack["difficulty"])
		s.hp_scale = float(pack["hp_scale"])
		s.tint = pack["tint"]
		# One crate of the good thing, the same way a raider carries what it took.
		s.drop_good = drop if i == 0 else ""
		s.despawn_radius = HOSTILE_LEASH
		root.add_child(s)
		s.global_position = origin + Vector3(rng.randf_range(-2.5, 2.5), 0.0,
			rng.randf_range(-2.5, 2.5))

	if bool(pack["escort"]):
		var h := Hostile.new()
		h.difficulty = float(pack["difficulty"])
		h.despawn_radius = HOSTILE_LEASH
		root.add_child(h)
		h.global_position = origin

	FX.ring_pulse(root, origin, pack["tint"], 3.0, 0.9)
	Sfx.play("klaxon", -12.0, 1.15)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_toast"):
		hud.show_toast("CONTACT — %s" % band_name(depth_at(origin)), pack["tint"])


func _build_post(key: Vector2i, cfg: Dictionary) -> void:
	# A post you have already cleared stays cleared. Hostile.LOOT_COUNT is 14
	# against a swarm's 2, so a four-guard post pays around 2,600 — and PACING_LOOP
	# budgets FIVE sentries for a whole eight-minute loop. A post that re-armed
	# every time its cell cycled would be an unbounded farm reachable by flying
	# 200u out and back: 11's money-printer rule, somewhere ports cannot reach.
	if cfg.is_empty() or _cleared.has(key):
		return
	var root := get_parent()
	if root == null:
		return
	var live: Array = []
	for post_v in cfg.get("posts", []):
		var h := Hostile.new()
		h.difficulty = float(cfg["difficulty"])
		h.hp_scale = float(cfg["hp_scale"])
		h.tint = cfg["tint"]
		h.designation = String(cfg["designation"])
		# NO LEASH, and that is deliberate rather than forgotten. despawn_radius
		# exists because a swarm does 7.5 against the ship's 5.75 and cannot be
		# outrun, so a chase needs an end. A guard does not chase — _process hard
		# writes it back to its post. A leash here would create a 141u disarm: back
		# off past it, return before the cell cycles at 192u, and the hulk is
		# unguarded. The CELL is what ends a guard's life.
		h.despawn_radius = 0.0
		h.add_to_group("deep_guard")
		# Which post this guard belongs to, so its death can ask whether the post
		# it was standing in is now empty.
		h.set_meta("post_key", key)
		root.add_child(h)
		h.global_position = post_v
		live.append(h)
	if not live.is_empty():
		_guards[key] = live
		_guard_origin[key] = cfg["origin"]


func note_hulk_cracked(key: Vector2i) -> void:
	# Called from Derelict._breach, the same shape note_guard_died is called in.
	_cracked[key] = true


func is_hulk_cracked(key: Vector2i) -> bool:
	return _cracked.has(key)


func note_surveyed(key: Vector2i) -> void:
	_surveyed[key] = true


func is_surveyed(key: Vector2i) -> bool:
	return _surveyed.has(key)


func note_guard_died(key: Vector2i) -> void:
	# Called from Hostile._die, NOT from _despawn_cell. A player who clears a post
	# and then keeps working the wreck beside it never triggers a despawn, so
	# crediting the clear at despawn time would miss exactly the case where the
	# player most obviously earned it — and would credit it minutes later, out of
	# sight of the thing that caused it.
	if _counted.has(key) or post_standing(key) > 0:
		return
	_counted[key] = true
	GameState.note_ledger("posts_cleared", 1)
	# Band from the HULK's own position, never from the cell centre: a cell is 64u
	# across and a band edge can run straight through one, so the two can name
	# different bands for the same post.
	var origin: Vector3 = _guard_origin.get(key, Vector3.ZERO)
	GameState.note_log("POST CLEARED — %s" % band_name(depth_at(origin)))


func guards_at(key: Vector2i) -> Array:
	# Harness support: the streaming window holds several guarded hulks at once,
	# so anything asserting about ONE post has to ask by cell rather than sweep
	# the deep_guard group.
	return _guards.get(key, [])


func post_standing(key: Vector2i) -> int:
	var n := 0
	for g_v in _guards.get(key, []):
		var g = g_v
		if is_instance_valid(g) and not g.is_dying():
			n += 1
	return n


func _despawn_cell(key: Vector2i) -> void:
	var node = _cells.get(key)
	_cells.erase(key)
	# A cell that leaves the window before it was ever dressed drops out of the
	# queue with it. Without this the drain would later reach a key whose node is
	# gone -- harmless, because it checks, but it would also mean flying fast
	# enough could keep a stale backlog growing behind the player forever.
	_build_queue.erase(key)
	# The nest goes back to being a seed. It is not lost — plan_cell will produce
	# the identical pack if the player ever comes back — it is simply no longer
	# armed, because there is no cell here any more to walk into.
	_armed.erase(key)
	# Guards are freed by their OWNER, not by the tree they live in. Polled before
	# freeing: a post whose last guard died stays cleared, so leaving and coming
	# back cannot rebuild a fight you already won.
	if _guards.has(key):
		if post_standing(key) == 0:
			_cleared[key] = true
		for g_v in _guards[key]:
			var g = g_v
			if is_instance_valid(g):
				g.queue_free()
		_guards.erase(key)
		_guard_origin.erase(key)
	# Obstacles come out FIRST and synchronously. queue_free is deferred, so
	# clearing them afterwards would leave a frame in which the mesh is gone and
	# its collision sphere is not — an invisible wall, out where there is nothing
	# to explain it.
	Obstacles.remove_owner(_owner_tag(key.x, key.y))
	if node != null and is_instance_valid(node):
		node.queue_free()


func rebuild() -> void:
	# Drop every live cell and let the stream rebuild them. Used by the colour
	# vision setting, which changes what band_color returns -- and every deep
	# material was baked from that at construction, so nothing short of building
	# them again picks it up. Costs nothing that warping does not already cost,
	# and the world is a pure function of (system, cell), so what comes back is
	# identical apart from the tint.
	_despawn_all()
	_build_queue.clear()
	_cell_last = Vector2i(9999, 9999)      # force the next _stream to run


func _despawn_all() -> void:
	_build_queue.clear()
	_mined.clear()
	for key_v in _cells.keys():
		_despawn_cell(key_v)
	_armed.clear()
	_sprung.clear()
	_guards.clear()
	_guard_origin.clear()
	_cleared.clear()
	_hailed.clear()
	_counted.clear()
	_cracked.clear()
	_surveyed.clear()
	_cell_last = Vector2i(0x7fffffff, 0x7fffffff)


# --- harness support --------------------------------------------------------

func live_cells() -> Array:
	return _cells.keys()


func live_cell_count() -> int:
	return _cells.size()


func content_cell_count() -> int:
	var n := 0
	for key in _cells:
		if _cells[key] != null:
			n += 1
	return n
func _process(_delta: float) -> void:
	# Ahead of the early return: cells already registered still owe their meshes
	# whether or not there is a rig to follow this frame.
	_drain_queue()
	var rig: Node3D = get_tree().get_first_node_in_group("camera_rig")
	if rig == null or _stars == null:
		return
	var c := rig.global_position
	_stars.follow(c)
	_motes.follow(c)
	_cold.global_position = Vector3(c.x, -70.0, c.z)

	# Sectors stream around the SHIP, not the lens. The camera can be panned a
	# leash-length away from the player, and content that appeared because you
	# looked somewhere would be content that vanished when you looked back.
	if generating:
		var player: Node3D = get_tree().get_first_node_in_group("player")
		if player != null:
			_stream(player.global_position)
			_check_encounters(player.global_position)

	var depth := maxf(Vector2(c.x, c.z).length() - _bounds, 0.0)
	var k := clampf(depth / DEEP_FULL, 0.0, 1.0)
	if is_equal_approx(k, _k_last):
		return
	_k_last = k
	_motes.set_presence(k)
	_cold_mat.albedo_color.a = lerpf(0.0, 0.030, k)


func depth_at(pos: Vector3) -> float:
	return maxf(Vector2(pos.x, pos.z).length() - _bounds, 0.0)


func star_field() -> DeepField:
	return _stars
