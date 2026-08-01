class_name Tutorial
extends Node
# The guided first run, played in the real PYX-01 rather than a sandbox.
#
# Six steps, each one verb, each introducing its own threat. Nothing else spawns
# while it runs: no sentries are built and swarm waves are held. It ends on the
# derelict breach, which charts PYX-02 — so the tutorial finishes by opening the
# world instead of by getting out of the way.
#
# Everything after this (chart, warp, dock, trade) is already covered
# contextually by scripts/barks.gd, which takes over on completion.

signal finished

const MOVE_DISTANCE := 8.0
const STEP_SETTLE := 0.6      # beat between a step completing and the next arriving
const GARRISON_DELAY := 5.0   # grace after the finale before the system arms

var _step := -1
var _active := false
var _armed := false           # completion checks ignored during the settle beat
var _move_origin := Vector3.ZERO
var _salvage_mark := 0
var _drones: Array[Node3D] = []
var _ability_used := false


func is_active() -> bool:
	return _active


func step_count() -> int:
	return 6


func _ready() -> void:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("tutorial_skip_button"):
		hud.tutorial_skip_button().pressed.connect(skip)


func arm() -> void:
	# Marks the tutorial live before the system is built, so the builder knows
	# to leave the sentries out. Without this the world is constructed first and
	# the new player is greeted by three of them.
	_active = true


func begin(from_step := 0) -> void:
	_active = true
	_set_return_fire(false)
	_step = from_step - 1
	_advance()


func _set_return_fire(on: bool) -> void:
	# The ship shoots back on its own everywhere except here. Step 1 is "click a
	# contact to engage", and its drone can shoot — so leaving return fire on
	# would resolve the lesson before the player took part in it.
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player != null and "return_fire_enabled" in player:
		player.return_fire_enabled = on


func skip() -> void:
	if not _active:
		return
	Sfx.play("equip", -10.0, 0.8)
	_clear_drones()
	_finish()


# --- step flow --------------------------------------------------------------

func _advance() -> void:
	_step += 1
	GameState.set_tutorial_step(_step)
	if _step >= step_count():
		_finish()
		return

	_armed = false
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.set_tutorial(_step + 1, step_count(), _text_for(_step))
	_setup(_step)
	get_tree().create_timer(STEP_SETTLE).timeout.connect(func() -> void: _armed = true)


func _complete_step() -> void:
	if not _active:
		return
	Sfx.play("equip", -5.0, 1.15)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.flash_tutorial()
	_advance()


func _finish() -> void:
	_active = false
	_set_return_fire(true)
	_step = -1
	GameState.set_tutorial_step(-1)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud:
		hud.hide_tutorial()
		hud.show_toast("SURVEY AUTHORITY GRANTED", Palette.GOLD)
	var main := get_tree().get_first_node_in_group("main")
	if main:
		# v18. THE FINALE POINTS PAST THE CORDON.
		#
		# This used to end by OPENING the world: the breach charted PYX-02 and
		# the guided run finished by handing over a frontier. The survey hull is
		# a hundred units outside charted space now, so the tutorial ends one
		# step earlier than that — it teaches the verb on a training hull and
		# then tells you where to go and use it.
		#
		# Deliberately a BEARING and a distance rather than a waypoint: the
		# whole game is about flying out past the marker on a heading, and the
		# first time the player does it should read like that rather than like
		# following an arrow. The numbers come from SystemDB.derelict_pos so
		# this line cannot disagree with where the hull actually is.
		var hull_at: Vector3 = SystemDB.derelict_pos(main.system_id)
		if hull_at != Vector3.ZERO and main.hud:
			var deg := int(round(fposmod(rad_to_deg(atan2(hull_at.z, hull_at.x)), 360.0)))
			main.hud.show_broadcast("GSA RELAY — SURVEY ASSIGNMENT",
				"Authority granted. The hull we need surveyed is not in charted "
				+ "space — it is %du out on bearing %03d, past the cordon. "
					% [int(round(SystemDB.derelict_depth(main.system_id))), deg]
				+ "Patrols do not operate beyond the marker. Breach it and the "
				+ "next system is yours to chart.", Palette.GOLD)
			GameState.note_log("SURVEY ASSIGNMENT — BEARING %03d" % deg)
		# Populate in place rather than reloading the system: a rebuild here
		# would delete the breach's loot vortex at the exact moment the player
		# earned it. The garrison also arrives on a delay so the finale gets to
		# land before anything starts shooting.
		if main.contracts:
			main.hud.set_contracts(main.contracts.rows())
		get_tree().create_timer(GARRISON_DELAY).timeout.connect(func() -> void:
			if is_instance_valid(main):
				main.spawn_sentries()
		)
	Barks.begin(self)
	finished.emit()


# --- per-step text and setup ------------------------------------------------

func _touch() -> bool:
	return DisplayServer.is_touchscreen_available()


func _text_for(step: int) -> String:
	match step:
		0:
			return "HOLD W A S D TO FLY" if not _touch() else "TAP A BEARING TO FLY THERE"
		1:
			return "CONTACT ADRIFT — CLICK IT TO ENGAGE (OR PRESS TAB)" if not _touch() \
				else "CONTACT ADRIFT — TAP IT TO ENGAGE"
		2:
			return "SALVAGE ADRIFT — FLY THROUGH IT TO COLLECT"
		3:
			return "MORE CONTACTS — PRESS SPACE TO DISCHARGE THE CORE" if not _touch() \
				else "MORE CONTACTS — TAP OVERCHARGE TO DISCHARGE THE CORE"
		4:
			return "TRACTOR RIG RECOVERED — OPEN REFIT AND FIT IT"
		5:
			return "DERELICT AHEAD — HOLD ON THE BREACH POINT TO CRACK IT"
	return ""


func _setup(step: int) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	match step:
		0:
			if player:
				_move_origin = player.global_position
		1:
			_spawn_drone(Vector3(4.0, 0, -3.0))
		2:
			_salvage_mark = GameState.salvage
		3:
			_ability_used = false
			_spawn_drone(Vector3(-5.0, 0, -4.0))
			_spawn_drone(Vector3(-2.5, 0, -6.0))
			_spawn_drone(Vector3(0.5, 0, -5.0))
		4:
			# The wreck yields the module the step asks you to fit; the refit
			# console is swap-only, so without this there is nothing to equip.
			if not GameState.owns("util_tractor"):
				GameState.owned.append("util_tractor")
			var hud := get_tree().get_first_node_in_group("hud")
			if hud:
				hud.show_toast("RECOVERED — TRACTOR RIG", Palette.TEAL)
		5:
			# THE TRAINING HULL specifically. v18 moved the survey hull a hundred
			# units past the marker and put a small one on its old berth; with
			# two crackables in PYX-01, "crackable" answers "whichever is first
			# in the tree", which is not a rule a tutorial step should turn on.
			var derelict: Node3D = get_tree().get_first_node_in_group("training_hull")
			if derelict:
				FX.ring_pulse(get_parent(), derelict.global_position, Palette.AMBER, 3.0, 0.9)


func _spawn_drone(offset: Vector3) -> void:
	var main := get_tree().get_first_node_in_group("main")
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if main == null or player == null:
		return
	var drone := SwarmHostile.new()
	drone.difficulty = 0.5      # a training dummy that can still shoot back
	drone.hp_scale = 0.8
	main.system_root.add_child(drone)
	drone.global_position = player.global_position + offset
	_drones.append(drone)
	FX.ring_pulse(main, drone.global_position, Palette.THREAT, 1.6, 0.6)


func _clear_drones() -> void:
	for d in _drones:
		if is_instance_valid(d):
			d.queue_free()
	_drones.clear()


func _live_drones() -> int:
	var n := 0
	for d in _drones:
		if is_instance_valid(d):
			n += 1
	return n


# --- completion checks ------------------------------------------------------

func _process(_delta: float) -> void:
	if not _active or not _armed:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return

	match _step:
		0:
			if player.global_position.distance_to(_move_origin) >= MOVE_DISTANCE:
				_complete_step()
		1:
			if _live_drones() == 0:
				_drones.clear()
				_complete_step()
		2:
			if GameState.salvage > _salvage_mark:
				_complete_step()
		3:
			if _ability_used or _live_drones() == 0:
				_clear_drones()
				_complete_step()
		4:
			if String(GameState.fit.get(ModuleDB.Slot.UTILITY, "")) == "util_tractor":
				_complete_step()
		5:
			# THE TRAINING HULL specifically. v18 moved the survey hull a hundred
			# units past the marker and put a small one on its old berth; with
			# two crackables in PYX-01, "crackable" answers "whichever is first
			# in the tree", which is not a rule a tutorial step should turn on.
			var derelict: Node3D = get_tree().get_first_node_in_group("training_hull")
			# ASK THE HULL WHETHER IT IS CRACKED. The comment that used to sit
			# here said "the derelict leaves the group the instant it is
			# breached" and it was simply false: Derelict._breach() removes
			# itself from `crackable` and from nothing else, and the node is
			# never freed — it stays in the scene as an opened wreck, and stays
			# in `training_hull` forever.
			#
			# So this condition could never become true, and THE LAST STEP OF
			# THE TUTORIAL COULD NOT BE COMPLETED BY PLAYING IT. The only exit
			# was the SKIP button, which lands on _finish() directly. A player
			# who did as they were told and breached the hull sat at step 5
			# with the world still held back: no sentries, no pickets, no
			# waves, no events, forever.
			#
			# Shipped in stage 2b, when the step was re-pointed from the
			# `crackable` group to the new `training_hull` one without the
			# matching removal. TUTORIALTEST drove the whole sequence every
			# sweep and printed `sentries=0` — as an observation nobody read,
			# until it became a PASS/FAIL.
			#
			# The null check stays as well: a hull that IS gone is also done,
			# and this must not depend on the node outliving the step.
			if derelict == null or (derelict as Derelict).is_cracked():
				_complete_step()


func on_ability_used() -> void:
	_ability_used = true
