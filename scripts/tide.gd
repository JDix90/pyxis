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
# §143. THE FIRST VERSION OF THIS COULD NOT DRAW A SINGLE PIXEL, and the three
# reasons are worth keeping because each one alone was enough.
#
# 1. NO MESH AND NO MATERIAL. CPUParticles3D.mesh defaults to null and a null
#    mesh renders nothing; `color` only tints a material that is not there.
#    Every working particle system in this project -- FX.burst, FX.vortex --
#    builds a BoxMesh with Palette.emissive on it and assigns it. This did not,
#    and neither does storm.gd, which has had invisible motes since v20 and got
#    away with it because a storm also has an eye, arms, a ring and a shockwave
#    to be seen by. THE TIDE HAD ONLY THE MOTES.
#
# 2. THE RATE WAS 2.6 A SECOND. lifetime was (box * 2) / speed = 26.7s against
#    an amount of 70, and a particle system's emission rate is amount/lifetime.
#    Even drawable, that is a speck every third of a second.
#
# 3. THE BOX WAS TEN TIMES THE VIEW. 240 units across, while the lens sees
#    about 21 down its long axis at the default zoom -- so ~99% of what it
#    emitted was off screen before the other two problems got to it.
#
# The count and the lifetime are now stated as themselves and the RATE is
# derived from them, because the rate is the thing that has to be right.
const MOTE_COUNT := 140
const MOTE_LIFE := 3.2
# Sized against the LENS, not against the world, and re-sized as the lens
# changes: §142 opened the zoom range from under fourfold to thirteenfold, so a
# fixed box would be either a postage stamp at 80 or a waste of fill at 6. 1.1x
# the zoom covers the tall axis of a 55-degree lens with margin for a turned or
# panned view.
const MOTE_BOX_PER_ZOOM := 1.1
const MOTE_BOX_MIN := 12.0
const MOTE_BOX_MAX := 96.0
# Re-dressing a particle system is not free, so the box only follows the zoom in
# steps. An eighth is under the threshold at which a density change is visible.
const MOTE_ZOOM_STEP := 0.125
# Present versus riding, in the water rather than in a word. The tide is there
# either way; when it is carrying you, it moves faster and burns brighter.
const MOTE_SPEED_NEAR := 6.0
const MOTE_SPEED_RIDING := 13.0
const MOTE_DIM := 0.34
const MOTE_LIT := 0.85

const COPY := {
	# §143. TWO STATES, and the shorter one is the DEFAULT -- the old line only
	# ever appeared while riding, so a pilot who stopped, or turned, or simply
	# finished a move order watched it vanish and reported the tide as
	# disappearing off their sensors. It had not: they had stopped using it.
	#
	# "SET" came off the front rather than being kept for symmetry. The number
	# IS the set, the manual says so, and the line it sits on already carries a
	# system, a band glyph, a band name, a range and sometimes a jam -- every
	# character here is one closer to a readout that does not fit.
	"tag": " · TIDE %03d",
	"riding": " · TIDE %03d ▸",
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
# §143. PRESENT is not RIDING, and the cockpit now says which. `_set` alone
# cannot answer it: it is a cache of the block's water and survives a stand-down
# (docked, or inside a storm), so a readout driven off it would announce a tide
# to a hull sitting in a dock.
var _present := false
# What the motes were last dressed FOR. Re-dressing rebuilds a material, so it
# happens when one of these three actually moves rather than every frame.
var _dressed_riding := false
var _dressed_band := -1
# The set is tracked alongside the other two, and it is the one a reader misses:
# crossing from one block of water into another can leave the band and the
# riding state untouched while the DIRECTION changes completely, which would
# have left the motes streaming the old way with nothing to say so.
var _dressed_set := Vector2.ZERO
var _mote_zoom := 0.0


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
	_motes.lifetime = MOTE_LIFE
	_motes.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	_motes.gravity = Vector3.ZERO
	_motes.spread = 3.0
	_motes.scale_amount_min = 0.7
	_motes.scale_amount_max = 1.5
	# ALIGNED TO THE FLOW. A mote that is a cube says "dust"; one stretched
	# along its own velocity says "current", which is the entire thing this
	# effect has to communicate before any text does.
	_motes.particle_flag_align_y = true
	var mote_mesh := BoxMesh.new()
	mote_mesh.size = Vector3(0.07, 0.62, 0.07)
	# THE LINE THAT WAS MISSING. FX.burst and FX.vortex both build exactly this
	# -- a BoxMesh carrying Palette.emissive -- and a CPUParticles3D without one
	# draws nothing at all. The material is rebuilt in _dress_motes with the
	# band's colour; this is the shape, and the shape is what makes it visible.
	mote_mesh.material = Palette.emissive(Palette.TEAL, 2.2)
	_motes.mesh = mote_mesh
	_set_mote_box(_zoom_now())
	add_child(_motes)


func _zoom_now() -> float:
	var rig := get_tree().get_first_node_in_group("camera_rig") as CameraRig
	return rig.zoom if rig != null else 20.0


func _set_mote_box(z: float) -> void:
	var half := clampf(z * MOTE_BOX_PER_ZOOM, MOTE_BOX_MIN, MOTE_BOX_MAX)
	_motes.emission_box_extents = Vector3(half, 4.0, half)
	_mote_zoom = z


func tide_deg() -> int:
	# §143. THE SET UNDERFOOT, riding or not, and -1 for no water. This used to
	# answer only while riding, which is why a playtester reported the tide
	# "quickly disappearing from sensors": finishing a move order drops the hull
	# under UNDER_WAY, `_riding` goes false, and the line went dark. Nothing had
	# disappeared -- they had stopped using it, and the cockpit could not tell
	# those two apart.
	return set_deg(_set) if _present else -1


func is_riding() -> bool:
	return _riding


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
	var band := DeepSpace.band_of(deep.depth_at(at))
	if sc != _block:
		_block = sc
		_set = set_at(system_id, sc.x, sc.y)

	if _set == Vector2.ZERO:
		_stand_down()
		return

	_present = true
	global_position = at
	if _motes != null:
		_motes.emitting = true
		# THE BOX FOLLOWS THE LENS, in steps. §142 made the zoom range
		# thirteenfold, so a fixed emission volume is either a postage stamp
		# pinned to the middle of a wide view or fill nobody sees.
		var z := _zoom_now()
		if absf(z - _mote_zoom) > _mote_zoom * MOTE_ZOOM_STEP:
			_set_mote_box(z)

	# THE ALIGNMENT GATE, and the whole promise in one clamp. velocity rather
	# than facing: a hull that has been spun round by an EMP is not under way,
	# whatever it is pointing at.
	var vel := player.velocity
	vel.y = 0.0
	var align := 0.0
	if vel.length() >= UNDER_WAY:
		align = vel.normalized().dot(Vector3(_set.x, 0.0, _set.y))
	_riding = align > 0.0
	# ONE PLACE DECIDES AND ONE PLACE DRESSES. The riding branch used to return
	# early from three places, so a look that depended on it had three exits to
	# be updated from and would have been forgotten at one of them.
	if _riding != _dressed_riding or band != _dressed_band \
			or not _set.is_equal_approx(_dressed_set):
		_dress_motes(band)
	if not _riding:
		return
	# EVERY PHYSICS FRAME, never a poll: TETHER_RELEASE_DECAY bleeds the channel
	# to zero in about a third of a second, so a throttled feed is a sawtooth
	# the player feels as stutter. The storm's own note, and the same door.
	player.apply_tether(Vector3(_set.x, 0.0, _set.y), PUSH, DRIFT * align, delta)


func _dress_motes(band: int) -> void:
	# Everything the look depends on, in one place, called when any of the three
	# things it depends on moves -- the set, the riding state, or the zoom.
	# Three separate update paths writing the same node is DEFECTS 2b waiting to
	# happen, and a particle system is exactly the kind of object where the last
	# writer wins silently.
	if _motes == null:
		return
	if _set == Vector2.ZERO:
		_motes.emitting = false
		return
	_motes.direction = Vector3(_set.x, 0.0, _set.y)
	var speed := MOTE_SPEED_RIDING if _riding else MOTE_SPEED_NEAR
	_motes.initial_velocity_min = speed * 0.8
	_motes.initial_velocity_max = speed * 1.25
	var c := Palette.band_color(band)
	var a := MOTE_LIT if _riding else MOTE_DIM
	_motes.color = Color(c.r, c.g, c.b, a)
	var mm := _motes.mesh as BoxMesh
	if mm != null:
		# Rebuilt rather than tinted in place: the mesh is this node's own and
		# nothing else reads it, and an emissive material's energy is the half
		# that actually carries "brighter" on an unshaded surface.
		mm.material = Palette.emissive(Color(c.r, c.g, c.b, a),
			3.0 if _riding else 1.6)
	_dressed_riding = _riding
	_dressed_band = band
	_dressed_set = _set


func _stand_down() -> void:
	# Not a clear_tether: the channel is shared, and a tide that zeroed it on the
	# way out would cancel a storm's pull the moment the two overlapped. Ceasing
	# to drive is enough -- _tick_tether bleeds what this file put there and
	# nothing it did not.
	_riding = false
	_present = false
	if _motes != null:
		_motes.emitting = false
