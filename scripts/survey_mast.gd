class_name SurveyMast
extends Node3D
# A thing out here worth reading. Hold on it and you come away with CHART DATA:
# bearings, masses, whatever the lens can resolve — sellable at any counter that
# buys, because the people who buy charts are the people who will not fly out to
# make them.
#
# The fourth implementation of the same duck-typed hold contract Derelict and
# ApexWreck already carry (`hold_begin` / `hold_tick` / `hold_release` /
# `on_tapped` / `pick_anchor`). CameraRig picks by GROUP and calls by method, so
# joining "crackable" costs zero lines anywhere else — and buys the radar marker
# for free, since RadarLayer scans the same group.
#
# On a hulk this sits at the STERN while the breach beacon sits at the prow, 13.2
# units apart. That separation is doing three jobs: it gives `_pick` room to tell
# two verbs on one wreck apart, it puts the survey stand-off outside the ring of
# guard posts that ring the breach point, and -- since it exceeds CRACK_RANGE +
# SURVEY_RANGE -- it keeps the two in-range prompts from overlapping and fighting
# over hud.prompt's single slot. Surveying a guarded hulk is the sneak play;
# cracking it is what contests the post.

# Where the mast rides on a hulk, along the hull's forward axis. The breach
# beacon sits at Derelict.BEACON_LOCAL.z (-6.6); this is that mirrored, which is
# both why the wreck reads as symmetrical and why the dish clears the stern
# block. See the comment at the placement site in deep_space.gd for the geometry
# it used to be buried in.
const HULL_OFFSET := 6.6

const SURVEY_RANGE := 6.5
const DECAY_RATE := 1.6
const YIELD_UNITS := 2
# How close a working mast has to be to the lair before the engine's
# transmission shows up in its reading, and the half-angle it can promise.
# 220u is a little under two cells: close enough that finding a mast that hears
# anything is itself a signal, far enough that the band+quadrant the free
# broadcast gives you is a searchable area rather than a needle.
const RESONANCE_RANGE := 220.0
const MAST_ERROR_DEG := 8.0

# Set by whoever builds it, before add_child.
var band := 1
var survey_time := 3.0
# Where this reading is recorded once taken, so it is not taken twice. Session
# state owned by DeepSpace; the mast only reports.
var cell := Vector2i.ZERO

var surveyed := false

var _holding := false
var _progress := 0.0
var _dish: MeshInstance3D
var _dish_mat: StandardMaterial3D
var _spin := 0.0
var _in_range_last := false


func _ready() -> void:
	add_to_group("crackable")
	add_to_group("survey_mast")
	_build()


func _build() -> void:
	var mast := MeshInstance3D.new()
	var mm := CylinderMesh.new()
	mm.top_radius = 0.06
	mm.bottom_radius = 0.12
	mm.height = 1.9
	mast.mesh = mm
	mast.position.y = 0.95
	mast.material_override = Palette.matte(Color(0.22, 0.22, 0.26))
	add_child(mast)

	_dish = MeshInstance3D.new()
	var dm := TorusMesh.new()
	dm.inner_radius = 0.36
	dm.outer_radius = 0.52
	dm.ring_segments = 18
	_dish.mesh = dm
	_dish.position.y = 1.95
	_dish.rotation.x = PI / 2.4
	_dish_mat = Palette.emissive(Palette.band_color(band), 2.0)
	_dish.material_override = _dish_mat
	add_child(_dish)


func dish_aabb() -> AABB:
	# The dish's box in WORLD space, at its current spin. Read-back for
	# PYXIS_CARTTEST's MAST IS CLEAR: the thing that went wrong here was purely
	# geometric, so the assertion measures the geometry rather than the number
	# that produced it -- change the hull, the offset or the dish and it follows.
	if _dish == null:
		return AABB()
	var local := _dish.get_aabb()
	return _dish.global_transform * local


func pick_anchor() -> Vector3:
	return global_position + Vector3(0, 1.95, 0)


func _process(delta: float) -> void:
	_spin += delta
	if _dish:
		_dish.rotation.y = _spin * 0.7
		_dish_mat.emission_energy_multiplier = (0.6 if surveyed else 1.6) \
			+ (0.0 if surveyed else sin(_spin * 2.2) * 0.5)

	if not _holding and _progress > 0.0:
		_progress = maxf(_progress - DECAY_RATE * delta, 0.0)
		_sync_gauge()

	var near := _player_in_range()
	if near != _in_range_last:
		_in_range_last = near
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			if near and not surveyed:
				hud.prompt(_prompt_line())
			else:
				hud.clear_prompt()


func reach() -> float:
	# SURVEYING t4, THE LONG ARM. §22 records that surveying a guarded hulk is
	# the sneak play and cracking it is what contests the post -- the mast rides
	# the stern precisely so the stand-off sits outside the guard ring. A longer
	# arm makes that play SAFER rather than making it pay more, which is the
	# shape a tier is allowed to have: it buys distance, not yield.
	if GameState.skill_tier("surveying") >= GameState.SURVEY_REACH_TIER:
		return SURVEY_RANGE * GameState.SURVEY_REACH_MULT
	return SURVEY_RANGE


func _player_in_range() -> bool:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return false
	return player.global_position.distance_to(global_position) <= reach()


func survey_seconds() -> float:
	# Scanners finally do something sensor-shaped. Until now "Targeting Scanner"
	# was a range-and-crit module wearing an instrument's name.
	var speed := 1.0 + float(GameState.stats.get("survey_speed", 0.0))
	# SURVEYING t2, MAST TEMPO. A hand that has worked sixteen of these is
	# quicker at it. Stacks with the scanner because they are different things --
	# the module is the instrument, this is the operator -- and it is TIME, which
	# is the currency §26 says a tier may be paid in.
	if GameState.skill_tier("surveying") >= GameState.SURVEY_TEMPO_TIER:
		speed += GameState.SURVEY_TEMPO_BONUS
	return survey_time / maxf(speed, 0.2)


func rival_was_first() -> bool:
	# Lifted out of _complete so the PROMPT can ask the same question the toast
	# does -- one source, so a tier-3 heads-up and the settlement afterwards
	# cannot disagree. The sentinel guard mirrors note_surveyed's: a rift mast
	# has no cell, so it has no rival either.
	var main_r := get_tree().get_first_node_in_group("main")
	if main_r == null or absi(cell.x) > 1 << 20 or absi(cell.y) > 1 << 20 \
			or not main_r.has_method("cell_depth_of_key"):
		return false
	var ck := DeepSpace.cell_key(main_r.system_id, cell.x, cell.y)
	return Rival.filed(ck, float(main_r.cell_depth_of_key(ck)),
		GameState.run_seed, GameState.played_seconds)


func _prompt_line() -> String:
	# The band was all this ever said. Two SURVEYING tiers add to it, and both
	# are INFORMATION -- neither changes what the mast yields or what it costs.
	# String(), and NOT because it is tidier: BAND_NAMES is an untyped const
	# Array, so indexing it yields a Variant and `:=` has nothing to infer from.
	# That is a PARSE error, and a parse error in a leaf class takes down every
	# script that depends on it -- deep_space, system_db, game_state and the
	# audio autoload all failed to compile behind this one line.
	var band_name := String(DeepSpace.BAND_NAMES[
		clampi(band, 0, DeepSpace.BAND_NAMES.size() - 1)])
	var line := "HOLD TO SURVEY — %s" % band_name
	# t1, THE READING IS NAMED. What comes aboard, before you spend the hold --
	# which matters most in the one case the mast already refuses for: a hold
	# with no room for it.
	if GameState.skill_tier("surveying") >= GameState.SURVEY_NAMED_TIER:
		var good := CommodityDB.chart_for_band(band)
		if good != "":
			line += " · %s x%d" % [CommodityDB.short_name(good), YIELD_UNITS]
	# t3, THE RIVAL SHOWS EARLY. The heads-up moves from AFTER the hold to
	# BEFORE it, so the reading becomes a choice rather than a surprise. The
	# cargo is unchanged either way -- only the first-filing bonus was ever at
	# stake -- so this buys a decision, not a credit.
	if GameState.skill_tier("surveying") >= GameState.SURVEY_RIVAL_TIER \
			and rival_was_first():
		line += " · ALREADY FILED" if not GameState.files_with_the_network() \
			else " · A COLLEAGUE HAS IT"
	return line


# --- the hold contract ------------------------------------------------------

func hold_begin() -> void:
	if surveyed or _holding:
		return
	if not _player_in_range():
		on_tapped()
		return
	_holding = true


func hold_release() -> void:
	if not _holding:
		return
	_holding = false
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and not surveyed:
		hud.crack_progress(-1.0)


func hold_tick(delta: float) -> void:
	if surveyed or not _holding:
		return
	if not _player_in_range():
		hold_release()
		_approach()
		return
	_progress += delta / maxf(survey_seconds(), 0.05)
	_sync_gauge()
	if _progress >= 1.0:
		_complete()


func on_tapped() -> void:
	if surveyed:
		return
	FX.ring_pulse(get_parent(), pick_anchor(), Palette.TEAL, 1.2)
	if _player_in_range():
		return
	_approach()


func _approach() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var toward: Vector3 = player.global_position - global_position
	toward.y = 0.0
	if toward.length() < 0.1:
		toward = Vector3.BACK
	var stand: Vector3 = global_position + toward.normalized() * (reach() * 0.78)
	stand.y = 0.0
	player.command_move(stand)


func _sync_gauge() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.crack_progress(_progress if _progress > 0.001 else -1.0, "SURVEYING")


func _complete() -> void:
	# Guards ITSELF rather than trusting hold_tick to have checked. Both callers
	# do check, which is exactly why this is worth writing down: a function that
	# is safe only because of who calls it stops being safe the moment something
	# else calls it, and nothing about the name says so.
	if surveyed:
		return

	# ALL OR NOTHING, asked BEFORE the mast is spent rather than repaired after.
	# load_cargo is PARTIAL -- it takes what fits and reports how many -- and the
	# revert this used to rely on only fired when it took ZERO. So the full hold
	# was always handled correctly and the NEARLY full hold was not: a mast worked
	# with one space free took 1 of its 2 units, marked itself read and toasted
	# "SURVEY LOGGED x1", destroying half the reading with no way to tell. That is
	# the harder half to notice and the one a working hold is actually in.
	#
	# MineableSeam._complete() was written this way from the start, against this
	# exact bug, and its comment names this function. This is the mast brought
	# into line with it.
	var good := CommodityDB.chart_for_band(band)
	var hud := get_tree().get_first_node_in_group("hud")
	if good == "" or not GameState.can_load(good, YIELD_UNITS):
		# Deferred, not wasted: nothing is spent and the mast stays workable.
		_holding = false
		_progress = 0.0
		if hud:
			hud.crack_progress(-1.0)
			hud.show_toast("NO ROOM FOR THE READING", Palette.THREAT)
		return

	surveyed = true
	_holding = false
	_progress = 0.0
	remove_from_group("crackable")
	var taken := GameState.load_cargo(good, YIELD_UNITS)

	# v22. THE EVIDENCE AT THE MAST. If the rival has already filed this cell,
	# the reading still pays its cargo in full -- the DATA is yours, only the
	# first-filing bonus at the counter is gone -- and the toast says so here,
	# in the deep, rather than letting the counter be the first to mention it
	# a session later. ONE toast, folded into the survey line, because a second
	# show_toast in the same frame overwrites the first.
	#
	# Through main.cell_depth_of_key, the same single source the counter reads,
	# so the mast's heads-up and the counter's verdict cannot disagree about
	# where this cell is. The sentinel guard mirrors note_surveyed's: a rift
	# mast has no cell, so it has no rival either.
	var rival_here := rival_was_first()

	if hud:
		hud.crack_progress(-1.0)
		if rival_here:
			# v25 (§97). THE SAME FACT, IN TWO REGISTERS. Nothing about the rival
			# changes here -- they reach the same cells at the same times and
			# still take nothing the player had. What changes is who the player
			# is: a pilot who has filed with the network knows the other
			# cartographer was one of them, and knows the mark went where their
			# own marks go. The sting was never in the event, it was in reading
			# it as a loss.
			if GameState.files_with_the_network():
				hud.show_toast("SURVEY LOGGED — %s x%d · A COLLEAGUE WAS FIRST" % [
					CommodityDB.short_name(good), taken], CommodityDB.color_of(good))
			else:
				hud.show_toast("SURVEY LOGGED — %s x%d · FILED ALREADY, SOMEBODY WAS FIRST" % [
					CommodityDB.short_name(good), taken], CommodityDB.color_of(good))
		else:
			hud.show_toast("SURVEY LOGGED — %s x%d" % [
				CommodityDB.short_name(good), taken], CommodityDB.color_of(good))
		hud.refresh_cargo()

	Sfx.play("equip", -7.0, 1.35)
	FX.ring_pulse(get_parent(), pick_anchor(), CommodityDB.color_of(good), 2.6, 0.7)

	var main := get_tree().get_first_node_in_group("main")
	if main and main.deep_space:
		main.deep_space.note_surveyed(cell)
		# §137. THE SHEET SAYS WHERE IT STANDS, and this line is the feature.
		# The premium at the end is the payment; THIS is the motivation -- a
		# pilot who cannot see that they are three readings into a block of five
		# has no reason to take the fourth, and "my only motivation is to go
		# further" is what that looks like from the cockpit.
		#
		# Read AFTER note_surveyed, so it counts the reading just taken. Silent
		# on the last one: the completion toast is already saying it, and two
		# messages for one act is the double-report §120 found in a print line.
		var sc := DeepSpace.supercell_of(cell.x, cell.y)
		var want := main.deep_space.sheet_readings(sc.x, sc.y)
		var have := main.deep_space.sheet_read(sc.x, sc.y)
		if hud and want > 1 and have < want:
			hud.show_toast("SHEET %d OF %d IN THIS BLOCK" % [have, want],
				Palette.AMBER)

	# §111. SURVEYING'S ONE FEED, and the verb nothing else in the game is fed
	# by. Counted per MAST rather than per unit or per cell: a mast is the act,
	# and a cell already worked cannot be worked again (the spawn checks
	# is_surveyed), so this cannot be farmed by re-holding the same dish.
	if GameState.mark_skill("surveying") and hud:
		hud.show_toast("SURVEYING %d — %s" % [
			GameState.skill_tier("surveying"),
			String((GameState.SKILL_PERKS["surveying"] as Array)[
				GameState.skill_tier("surveying")])], Palette.GOLD)

	# THE MAST HEARS THE ENGINE, but only from close enough to triangulate. A
	# survey dish is not an intel desk: it picks up the transmission as
	# interference on its own reading, which is why this costs nothing and why
	# it only works within RESONANCE_RANGE of the lair.
	#
	# That range is the whole design of this channel. It is free intel, so it
	# must not be free intel you can farm from the doorstep — you have to
	# already be deep, and roughly in the right part of the deep, before a mast
	# tells you anything. The hunt narrows what you can search; it does not
	# replace the searching.
	if main and main.has_method("file_apex_intel"):
		var lair: Vector3 = SystemDB.lair_pos(main.system_id, GameState.run_seed)
		if lair != Vector3.ZERO \
				and lair.distance_to(global_position) <= RESONANCE_RANGE:
			main.file_apex_intel("mast", global_position, MAST_ERROR_DEG)
