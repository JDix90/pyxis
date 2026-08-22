class_name Tide
extends Node3D
# THE TIDE (§139, Horizon 14 commit 2). Weather in the middle bands, and the
# first thing in this game that only ever GIVES.
#
# A standing set of water, one per SUPERCELL across THE QUIET and THE FATHOMS,
# derived rather than stored: a pure function of (system, supercell) drawing its
# own salted stream, so it costs no save key, no world-gen change and no
# fingerprint. Roughly one block in three carries one.
#
# --- THE FOUR THINGS A READER GETS WRONG -------------------------------------
#
# 1. IT CANNOT SLOW YOU, PUSH YOU OFF COURSE OR CAGE YOU, and that is
#    structural rather than tuned. The push is scaled by how well the hull's own
#    heading ALREADY agrees with the set -- a dot product clamped at zero -- so
#    crossing a tide gets nothing and fighting one gets nothing. There is no
#    escape guarantee anywhere in this file because there is nothing to escape.
#
#    That is the whole difference from the storm, stated as a sentence: a storm
#    is a thing you PREPARED for, a tide is a thing you FOUND.
#
# 2. IT RUNS ACROSS THE DEPTH GRADIENT, NEVER ALONG IT, and that is the feature
#    rather than the flavour. The set is tangential to the system centre,
#    twisted up to TWIST_DEG. A radial tide would be a slide outward -- which is
#    MORE of the exact complaint this horizon opened on, "my only motivation is
#    to go further". A tangential one is a reason to move ACROSS a band: to the
#    next colony, to the sheet next door, to the block you have three readings
#    into.
#
# 3. THE DRIFT IS FLAT, WHICH IS §137's TRICK A SECOND TIME. 0.9 u/s
#    everywhere, against a drive ladder that only rises: +56% on the 1.6
#    max_speed floor and around +15% on the fastest legal fit, so the water is
#    worth most to the pilot who has least. Against a table that rises
#    everywhere, a constant is a slope.
#
# 4. IT STANDS DOWN INSIDE A STORM, AND THE REASON IS A DEFECT CLASS RATHER THAN
#    ETIQUETTE. apply_tether re-clamps _tether_vel to the LAST caller's cap, so
#    a tide feeding the channel in the same frame as a storm's pull would
#    overwrite the storm's cap with its own and the answer would be decided by
#    node order -- DEFECTS class 2b, two systems writing one property. The guard
#    reads the `storm` group directly rather than asking main, because a
#    guarantee that rests on another file's bookkeeping is a guarantee one
#    refactor away from being untrue.
#
# --- WHAT IT IS NOT ----------------------------------------------------------
#
# It pays no credits, ever. §67's rule about landmarks one system along: a thing
# out here that pays out stops being weather and becomes another errand. What a
# tide pays is TIME, which §26 cannot inflate into a printer at any rate that
# matters -- and the sheet, not the tide, is where the middle's money is.
#
# It calls note_log and note_ledger exactly ZERO times, for §53's reason: the
# captain's log is ten slots for things that happened to you, and ambient water
# is not one of them.
#
# IT DOES NOT TURN. A tide on a clock would make route knowledge into
# route-AND-timetable knowledge, which is a second dimension the chart has no
# way to draw and the player has no way to check. Standing, it is a fact about a
# PLACE -- which is the only kind of fact a filed sheet can remember, and the
# braid below depends on that. §64 carries the question of whether it ever
# should turn.
#
# --- THE BRAID ---------------------------------------------------------------
#
# WHAT A FILED SHEET UNLOCKS IS THE CHART, NOT THE TIDE. The water moves whether
# or not you have filed anything: the motes show it and the readout names it, so
# a tide is always discoverable by flying into one. What the sheet buys is the
# tide DRAWN, permanently, so the next crossing can be planned instead of
# stumbled into. The research asked whether a current should be learned or
# shown; this answers both, in that order, and it makes §137's sheet pay twice
# -- a premium once, and a fact about the region forever.

# --- where it lives ----------------------------------------------------------
# THE QUIET (1,100u) and THE FATHOMS (2,600u), stopping at the Unsounded floor.
# Band 6 already has weather and the complaint was 1,000 to 5,000; a tide that
# ran everywhere would be a global speed buff wearing a bearing.
const BAND_LO := 4
const BAND_HI := 5
# One block in three. A supercell is 256u square, so a crossing of the middle
# meets a tide roughly every 750u -- often enough to be a thing about the place,
# rare enough that finding one is a finding.
const DENSITY := 0.34
# How far the set may lean off tangential. Small enough that neighbouring blocks
# broadly agree (so the water reads as water rather than as noise), large enough
# that each block is its own reading and knowing the band is not knowing the
# block.
const TWIST_DEG := 35.0

# --- what it gives -----------------------------------------------------------
# Terminal drift, u/s, flat. Sits at 0.6 of PlayerShip.TETHER_DRAG_CEILING, so
# apply_tether's own clamp is never the thing deciding this number -- the cap
# there is a ceiling this design stays well under rather than one it leans on.
const DRIFT := 0.9
# Acceleration into it. About a second and a half from nothing to terminal,
# which is slow enough to feel like water taking hold and fast enough that a
# short block still pays.
const PUSH := 0.62
# Below this the ship is not going anywhere and the tide has nothing to agree
# with. A hull parked at a seam is not riding anything.
const UNDER_WAY := 0.6

# --- what it looks like ------------------------------------------------------
const MOTE_BOX := 120.0
const MOTE_COUNT := 70
const MOTE_SPEED := 9.0

const COPY := {
	"tag": " · TIDE SET %03d",
}


# Identity, set by the spawner before add_child -- every spawner's contract.
var system_id := ""
var deep: DeepSpace = null

var _motes: CPUParticles3D = null
var _reduced := false
# Cached per supercell rather than recomputed per frame: set_at allocates an
# RNG and hashes a string, and the answer cannot change until the ship crosses
# 256 units. _block starts at a coordinate no supercell has so the first frame
# always resolves.
var _block := Vector2i(1 << 30, 1 << 30)
var _set := Vector2.ZERO
var _riding := false


static func band_hand(id: String, band: int) -> float:
	# Which way round the water goes in this band -- ONE fact per band, not one
	# per block. It is what a pilot can learn without filing anything, and it is
	# why the twist above has to be bounded: knowing the hand should get you
	# most of the way, and knowing the sheet should get you the rest.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|tide_hand" % [id, band])
	return 1.0 if rng.randf() < 0.5 else -1.0


static func set_at(id: String, sx: int, sz: int) -> Vector2:
	# THE WHOLE WORLD-SIDE FEATURE, in one pure function. Unit vector in world
	# XZ, or ZERO for no tide.
	#
	# Salted with its own key, like landmark_cell: the fingerprint hashes
	# plan_cell's rocks, hulk, pack, station, seams and convoy, and this draws
	# from a stream none of them share -- so adding the tide cannot move a rock,
	# and WORLD_FINGERPRINT_BEFORE_SEAMS is untouched by construction rather
	# than by measurement.
	var centre := DeepSpace.supercell_centre(sx, sz)
	if centre.length() < 0.001:
		return Vector2.ZERO
	# THE BAND GATE LIVES HERE AND NOWHERE ELSE, which is why _physics_process
	# has none: a gate on the HULL's depth would have a slightly different edge
	# from this one on the BLOCK's radius, and the chart would then draw arrows
	# for water the hull is not pushed in. DEFECTS class 2b in its quietest
	# form -- two readers of one fact, each with its own copy of the rule.
	#
	# Depth is measured from the SYSTEM's bounds, which this static does not
	# have. Using the raw radius instead is deliberate and is a band-edge
	# question rather than a correctness one: bounds are tens of units against
	# band edges of 1,100 and 5,200, so the tide's outer and inner limits sit
	# within one cell of where a bounds-aware version would put them, and every
	# reader of this function agrees with every other by construction.
	var band := DeepSpace.band_of(centre.length())
	if not band_carries(band):
		return Vector2.ZERO
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("%s|%d|%d|tide" % [id, sx, sz])
	if rng.randf() >= DENSITY:
		return Vector2.ZERO
	# Depth is radius here, so the outward normal IS the depth gradient and its
	# perpendicular is the direction that costs nothing in depth. Point 2 of the
	# header, as two lines of arithmetic.
	var out := centre.normalized()
	var tang := Vector2(-out.y, out.x) * band_hand(id, band)
	return tang.rotated(deg_to_rad(rng.randf_range(-TWIST_DEG, TWIST_DEG)))


static func set_deg(v: Vector2) -> int:
	# Degrees clockwise from world -Z, which is the chart's up. The number and
	# the arrow the chart draws come off the SAME vector, so a readout and a
	# plot cannot disagree about which way the water runs -- §120's rule about
	# one act speaking once, applied to two instruments instead of two messages.
	if v.length() < 0.001:
		return -1
	return int(round(fposmod(rad_to_deg(atan2(v.x, -v.y)), 360.0))) % 360


static func band_carries(band: int) -> bool:
	return band >= BAND_LO and band <= BAND_HI


func _ready() -> void:
	_reduced = GameState.reduce_motion()
	_build_motes()


func _build_motes() -> void:
	if _reduced:
		return
	# A box of dust around the ship, drifting with the set. THE TELL IS THE
	# WATER ITSELF, not a marker on it: a tide has no object to look at, so what
	# has to read is that the stuff already out here has started moving one way.
	#
	# local_coords off, deliberately: the emitter follows the hull, and
	# particles that moved with it would be glued to the canopy instead of
	# streaming past it.
	_motes = CPUParticles3D.new()
	_motes.amount = MOTE_COUNT
	_motes.local_coords = false
	_motes.emitting = false
	_motes.lifetime = (MOTE_BOX * 2.0) / MOTE_SPEED
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_motes.emission_box_extents = Vector3(MOTE_BOX, 6.0, MOTE_BOX)
	_motes.gravity = Vector3.ZERO
	_motes.spread = 4.0
	_motes.initial_velocity_min = MOTE_SPEED * 0.7
	_motes.initial_velocity_max = MOTE_SPEED * 1.3
	_motes.scale_amount_min = 0.35
	_motes.scale_amount_max = 0.9
	add_child(_motes)


func riding_deg() -> int:
	# -1 when the tide is not paying. Read by the HUD tag, which is why it
	# reports RIDING rather than PRESENT: the readout is the confirmation that
	# the water is doing something for you, and a line that stayed lit while a
	# ship crossed a tide sideways would be saying the opposite of the truth.
	return set_deg(_set) if _riding else -1


func _physics_process(delta: float) -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	if player == null or deep == null:
		_stand_down()
		return

	# DOCKED IS SAFE and docked is also STILL: §14's one safe state, checked here
	# rather than trusted to PlayerShip's early return, for the storm's reason.
	if player.docked:
		_stand_down()
		return

	# Point 4 of the header. Checked before anything else touches the channel.
	for s_v in get_tree().get_nodes_in_group("storm"):
		var s := s_v as Storm
		if s != null and s.has_player(player):
			_stand_down()
			return

	# NO SECOND BAND GATE HERE, and that omission is deliberate enough to state.
	# The obvious optimisation is to bail early on the hull's own depth -- but
	# set_at gates on the BLOCK's radius, so a depth test on the SHIP would be a
	# second rule with a slightly different edge, and the chart would then draw
	# arrows for the outer sliver of a block the hull is not pushed in. That is
	# DEFECTS class 2b in its quietest form: two readers of one fact, each with
	# its own copy of the rule. set_at answers ZERO outside the bands and the
	# cache below asks it once per 256 units, which is cheap enough that the
	# early-out was never worth a second edge.
	var at := player.global_position
	var cell := DeepSpace.cell_of(at)
	var sc := DeepSpace.supercell_of(cell.x, cell.y)
	if sc != _block:
		_block = sc
		_set = set_at(system_id, sc.x, sc.y)
		_aim_motes(DeepSpace.band_of(deep.depth_at(at)))

	if _set == Vector2.ZERO:
		_stand_down()
		return

	global_position = at
	if _motes != null:
		_motes.emitting = true

	# THE ALIGNMENT GATE, and the whole promise in one clamp. velocity rather
	# than facing: a hull that has been spun round by an EMP is not under way,
	# whatever it is pointing at.
	var vel := player.velocity
	vel.y = 0.0
	if vel.length() < UNDER_WAY:
		_riding = false
		return
	var align := vel.normalized().dot(Vector3(_set.x, 0.0, _set.y))
	if align <= 0.0:
		_riding = false
		return

	_riding = true
	# EVERY PHYSICS FRAME, never a poll: TETHER_RELEASE_DECAY bleeds the channel
	# to zero in about a third of a second, so a throttled feed is a sawtooth
	# the player feels as stutter. The storm's own note, and the same door.
	player.apply_tether(Vector3(_set.x, 0.0, _set.y), PUSH, DRIFT * align, delta)


func _aim_motes(band: int) -> void:
	if _motes == null:
		return
	if _set == Vector2.ZERO:
		_motes.emitting = false
		return
	_motes.direction = Vector3(_set.x, 0.0, _set.y)
	var c := Palette.band_color(band)
	_motes.color = Color(c.r, c.g, c.b, 0.5)


func _stand_down() -> void:
	# Not a clear_tether: the channel is shared, and a tide that zeroed it on the
	# way out would cancel a storm's pull the moment the two overlapped. Ceasing
	# to drive is enough -- _tick_tether bleeds what this file put there and
	# nothing it did not.
	_riding = false
	if _motes != null:
		_motes.emitting = false
