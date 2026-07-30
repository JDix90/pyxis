class_name MineableSeam
extends Node3D
# Ore on the flank of a rock. Fly to it, hold on it, cut it out.
#
# The fifth implementation of the same duck-typed hold contract Derelict,
# ApexWreck and SurveyMast already carry -- hold_begin / hold_tick /
# hold_release / on_tapped / pick_anchor. CameraRig picks by GROUP and calls by
# method, so the verb costs almost nothing structurally.
#
# It joins "mineable" rather than "crackable", and that is a decision rather
# than tidiness. Two reasons, both measured:
#
#   THE RADAR. MAX_MARKERS is 12 and crackable is TIER_SITE. A 5x5 streaming
#   window in the Drift holds about ten seams; in crackable they would compete
#   on equal footing with the hulk and the survey mast -- the two things the
#   whole trip was for -- and would routinely evict them. hud.gd's own comment
#   says a border ring of arrows is noise rather than information.
#
#   THE PICK. CameraRig._pick is screen-space within PICK_PX, no raycast, and
#   plan_cell has no keep-out between rocks and the hulk -- a rock can sit a few
#   units from a breach point. Both in one group and a player who meant to
#   breach starts cutting instead, on a coin flip, on a phone. camera_rig checks
#   crackable FIRST: a hulk is one-time, a rock is one of many.
#
# It is a SEPARATE NODE placed on the rock's surface, not a flag on the rock.
# That is the fix for a bug this codebase has already shipped once
# (system_builder.gd:288): a QUIET rock's obstacle sphere reaches 6.56 units, so
# a hold measured from the rock's centre would push the ship outside its own
# range and the seam could never be worked at all. Standing the seam off the
# collision sphere makes one range constant correct at every rock size.

const MINE_RANGE := 6.0
const DECAY_RATE := 1.6            # the mast's number, not a second one

# Set by whoever builds it, before add_child.
var good := "ore_ferrite"
var units := 3
var band := 1
var mine_time := 4.0
# Where this cut is recorded so it is not taken twice. Session state owned by
# DeepSpace; the seam only reports.
var cell := Vector2i.ZERO
var seam_index := 0
var mined := false
# Non-empty ("pyx01:2") for the eleven AUTHORED seams in charted space, which are
# remembered in the save. Empty for every expanse seam, which are remembered only
# for the session. See _record_cut().
var charted_key := ""

var _face: MeshInstance3D
var _face_mat: StandardMaterial3D
var _progress := 0.0
var _holding := false
var _spin := 0.0
var _in_range_last := false


func _ready() -> void:
	add_to_group("mineable")
	_build()
	if mined:
		_spend_visual()


func _build() -> void:
	# A shallow ring of cut face, tinted by what is in it. Small: this is a seam
	# on a boulder, not a structure, and the rock it sits on is already the
	# silhouette. The colour is the ore's own so a prospector can read a field
	# at a glance once MINING has taught them what the colours mean.
	_face = MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 0.22
	tm.outer_radius = 0.46
	tm.ring_segments = 12
	_face.mesh = tm
	_face.rotation.x = PI / 2.0
	_face_mat = Palette.emissive(CommodityDB.color_of(good), 1.8)
	_face.material_override = _face_mat
	add_child(_face)


func pick_anchor() -> Vector3:
	# Lifted clear of the rock's silhouette, the same trick the breach beacon
	# uses to sit above the hull's roof.
	return global_position + Vector3(0, 1.1, 0)


func is_cracked() -> bool:
	# The hold contract's name for "already taken", shared with Derelict so a
	# caller does not have to know which of the two it is holding.
	return mined


func _process(delta: float) -> void:
	if mined:
		return
	_spin += delta
	_face_mat.emission_energy_multiplier = 1.4 + sin(_spin * 2.0) * 0.5
	if not _holding and _progress > 0.0:
		_progress = maxf(_progress - DECAY_RATE * delta, 0.0)
		_sync_gauge()
	_update_prompt()


func _update_prompt() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if not hud:
		return
	var in_range := _player_in_range()
	if in_range == _in_range_last:
		return
	_in_range_last = in_range
	if in_range:
		if is_locked():
			# Says what is missing, not just that something is. A refusal with no
			# reason reads as a bug; a refusal that names the tier is a goal.
			hud.prompt("SEAM TOO DEEP — MINING %d REQUIRED" % GameState.MINING_DEEP_TIER)
		else:
			hud.prompt("HOLD TO CUT — %s x%d" % [
				CommodityDB.short_name(good), cut_units()])
	else:
		hud.clear_prompt()


func _player_in_range() -> bool:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	return player.global_position.distance_to(global_position) <= MINE_RANGE


func mine_seconds() -> float:
	# Divided by the fitted rate, exactly the shape SurveyMast.survey_seconds()
	# uses for survey_speed. compute_stats sums unknown keys additively, so
	# mining_rate needed no schema change anywhere.
	return mine_time / maxf(1.0 + float(GameState.stats.get("mining_rate", 0.0)), 0.2)


func cut_units() -> int:
	# What this seam gives THIS ship, as opposed to what is written in the cell
	# plan. Everything downstream -- the prompt, the room check, the load and the
	# toast -- reads this one function, because the failure mode of having two of
	# them is promising the player a number the hold never receives.
	#
	# Additive and flat, unlike mining_rate's multiplier: see util_assay.
	return units + int(GameState.stats.get("ore_yield", 0.0))


func on_tapped() -> void:
	if mined:
		return
	_approach()


func _approach() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and player.has_method("command_move"):
		var to_ship := player.global_position - global_position
		to_ship.y = 0.0
		if to_ship.length() < 0.01:
			to_ship = Vector3.FORWARD
		player.command_move(global_position + to_ship.normalized() * (MINE_RANGE * 0.78))


func hold_begin() -> void:
	if mined or is_locked() or not _player_in_range():
		return
	_holding = true


func hold_release() -> void:
	# The player LETTING GO is the t2 gesture. Deliberately not the same thing as
	# the hold lapsing because the ship drifted out of range -- see _drop_hold --
	# or a seam would be spent for half its ore by a hand off the controls.
	var was_holding := _holding
	_holding = false
	if was_holding and not mined \
			and GameState.mining >= GameState.MINING_SAMPLE_TIER \
			and _progress >= GameState.MINING_SAMPLE_FRACTION:
		_take_sample()
		return
	_sync_gauge()


func _drop_hold() -> void:
	# The hold ending because the world moved, not because the player chose. Never
	# takes a sample.
	_holding = false
	_sync_gauge()


func sample_units() -> int:
	# Half of what THIS ship would have taken, floored, never less than one.
	# Derived from cut_units() rather than `units`: the Assay Rig makes the two
	# differ, and a sample computed off the raw table would drift away from what a
	# finished cut actually pays. A sample must always be strictly worse than
	# staying -- CORE SAMPLE CANNOT OUT-YIELD A CUT asserts it at every band, with
	# and without the rig.
	return maxi(1, int(floor(float(cut_units()) * GameState.MINING_SAMPLE_FRACTION)))


func is_locked() -> bool:
	# t3 is ACCESS. A locked seam stays visible and stays on the radar, because a
	# thing you can see and cannot have is a goal and a thing that is simply
	# absent is nothing at all.
	return not GameState.can_work_band(band)


func marker_color() -> Color:
	# t1 buys INFORMATION, and this is the whole of it. Below the tier every seam
	# is the same grey arrow, so a 60-credit Silicate and a 240-credit Iridium are
	# indistinguishable until you fly inside MINE_RANGE and read the prompt. At t1
	# the marker takes the ore's own colour -- which the seam's cut face has worn
	# since stage 1, so the skill teaches a language the world already spoke.
	#
	# Read by hud.gd's collect loop through has_method, so no other marker needs
	# to know this exists.
	if GameState.mining < GameState.MINING_READ_TIER:
		return Palette.HULL
	return CommodityDB.color_of(good)


func hold_tick(delta: float) -> void:
	if mined or not _holding:
		return
	if not _player_in_range():
		_drop_hold()
		return
	_progress += delta / maxf(mine_seconds(), 0.01)
	_sync_gauge()
	if _progress >= 1.0:
		_complete()


func _sync_gauge() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(_progress if _progress > 0.001 else -1.0, "CUTTING")


func _complete() -> void:
	# Guards itself rather than trusting hold_tick -- a function that is safe
	# only because of its callers is a function the next caller breaks.
	if mined:
		return
	_yield_cut(cut_units(), "CUT")


func _take_sample() -> void:
	# t2's CHOICE, and it costs something: past halfway you may walk away with
	# half of what the seam holds, and the seam is SPENT either way. A free
	# partial would just be a slower full cut; paying the whole seam for half the
	# ore is what makes leaving early a decision instead of an optimisation.
	if mined:
		return
	_yield_cut(sample_units(), "CORE SAMPLE")


func _yield_cut(take: int, label: String) -> void:
	# ALL OR NOTHING. load_cargo is PARTIAL: it takes as many units as fit and
	# reports how many. SurveyMast used to call it and revert only when it took
	# zero, so a mast worked with one space free took 1 of its 2 units and marked
	# itself surveyed -- half the reading destroyed, silently. With a five-unit
	# seam that would be five times worse, which is why the seam was written this
	# way first. Stage 3 brought the mast into line, so this is now the shared
	# rule rather than a divergence: ask whether the whole yield fits BEFORE
	# spending the thing that holds it.
	if not GameState.can_load(good, take):
		var hud_full := get_tree().get_first_node_in_group("hud")
		if hud_full:
			hud_full.show_toast("NO ROOM FOR THE %s — %s x%d" % [
				label, CommodityDB.short_name(good), take], Palette.THREAT)
		# Deliberately NOT hold_release(): at t2 that re-enters _take_sample and
		# recurses. Clearing the hold inline does what hold_release did before the
		# sample existed, which is all this path ever wanted.
		_holding = false
		_sync_gauge()
		return

	mined = true
	_holding = false
	remove_from_group("mineable")
	GameState.load_cargo(good, take)

	# Deliberately NOT through Main.spawn_loot. That funnel applies
	# CommodityDB.SALVAGE_CHANCE, so 22% of every seam would come out as graded
	# salvage -- which is ARCHEOLOGY's feed. Routing mining through it would make
	# cutting rock level a reading skill and turn FEEDS COMPETE red.
	_record_cut()
	# Fed by the CUT, weighted by BAND. Never by the sale.
	GameState.mark_mining(band)

	Sfx.play("crack", -4.0, 0.75)
	Sfx.haptic("medium")
	var rig := get_tree().get_first_node_in_group("camera_rig")
	if rig:
		rig.shake(0.05)
	FX.burst(get_parent(), global_position, CommodityDB.color_of(good), 22, 4.0, 0.18, 0.5)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(-1.0)
		hud.show_toast("%s — %s x%d" % [label, CommodityDB.short_name(good), take],
			CommodityDB.color_of(good))
		hud.refresh_cargo()
	_spend_visual()


func _record_cut() -> void:
	# TWO stores, and which one a seam uses is design rather than plumbing. A
	# CHARTED seam is one of eleven authored rocks in the entire game and is
	# remembered in the SAVE: respawning a finite set on every warp is the
	# deep-hulk farm that deep_space.gd's own comment records shipping once. An
	# EXPANSE seam is one of thousands and is remembered only for the session,
	# which is safe precisely because the band gradient makes shallow farming pay
	# badly (see WARP FARM). Eleven fixed rocks have no gradient to hide behind.
	if charted_key != "":
		GameState.note_seam_cut(charted_key)
		return
	var main := get_tree().get_first_node_in_group("main")
	if main and main.deep_space:
		main.deep_space.note_mined(cell, seam_index)


func _spend_visual() -> void:
	# A worked face reads as a HOLE, not as rock: darker than the rock's own
	# 0.13/0.12/0.13 and no longer emitting. This is the only thing that makes
	# "mined rocks stay mined" legible without a UI element, and an anti-farm
	# rule the player cannot see reads as the game being arbitrary.
	_face_mat = null
	_face.material_override = Palette.matte(Color(0.09, 0.09, 0.10))
	set_process(false)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and _in_range_last:
		hud.clear_prompt()
