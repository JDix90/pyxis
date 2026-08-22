class_name CameraRig
extends Node3D
# Tilted top-down rig: drag to pan (with inertia), pinch/wheel to zoom, tap to
# command, hold to crack. Softly follows the ship, and yields to the player for
# a few seconds after any manual pan. Owns screen shake and zoom punch.

const PITCH_DEG := -55.0
const ZOOM_MIN := 9.0
const ZOOM_MAX := 34.0
const ZOOM_LERP := 9.0
const ZOOM_PUNCH_DECAY := 7.0
const PAN_INERTIA_DECAY := 26.0

# The camera is leashed to the SHIP, not to the world origin.
#
# It used to be a square clamp around the origin, sized per system — which is why
# the view stopped at the edge of the charted volume while the ship, which is
# never clamped anywhere (see PlayerShip._physics_process), kept going. The
# constraint that was actually wanted is "never lose the ship", and that is a
# leash on the ship. Space can now be endless without a manual pan ever being
# able to strand the player off screen.
#
# Derived from zoom rather than a constant: pan_bound was 40-48 from the origin,
# so from the system centre you could pan ~40 units off the ship. A fixed leash
# would silently make panning tighter than it has always been, and that is the
# kind of change a player feels without being able to name.
const PAN_LEASH_ZOOM := 1.9
const PAN_LEASH_MIN := 22.0
const PAN_LEASH_MAX := 76.0

const TAP_MAX_PX := 14.0
const TAP_MAX_TIME := 0.35
const PICK_PX := 60.0
# How long an armed engage stays armed. Long enough to read the line and
# decide, short enough that a tap three minutes later is not a war you started
# without meaning to.
const ENGAGE_CONFIRM := 3.0
var _engage_armed := 0        # instance id of the armed ship, 0 = nothing
var _engage_at := 0.0

const FOLLOW_SPEED := 2.6
const FOLLOW_DEADZONE := 1.6
const FOLLOW_RESUME_DELAY := 2.2

const SHAKE_DECAY := 5.5
const SHAKE_FREQ := 34.0

var zoom := 20.0
# Set false by the capture harnesses, which frame compositions by hand.
var leash_enabled := true

var _camera: Camera3D
var _pitch_node: Node3D
var _target_zoom := 20.0
var _zoom_punch := 0.0

var _touches := {}
var _press_pos := Vector2.ZERO
var _press_time := 0.0
var _dragged := false
var _pan_vel := Vector3.ZERO
var _pinch_last := 0.0
var _follow_timer := 0.0

var _shake_amp := 0.0
var _shake_t := 0.0
var _mouse_down := false
var _mouse_dragged := false

var _hold_target: Node3D = null


func _ready() -> void:
	add_to_group("camera_rig")
	_pitch_node = Node3D.new()
	add_child(_pitch_node)
	_pitch_node.rotation_degrees.x = PITCH_DEG
	_camera = Camera3D.new()
	_pitch_node.add_child(_camera)
	_camera.position.z = zoom
	_camera.fov = 55.0
	_camera.current = true


func _process(delta: float) -> void:
	# Exponential, not `lerp(a, b, k * delta)`. The rig runs on the render tick,
	# so delta is whatever the display gives us, and the old form made the whole
	# camera feel different at 120Hz than at 60 -- and inverted below ~9 FPS,
	# where ZOOM_LERP * delta passes 1.0. See scripts/smoothing.gd.
	_zoom_punch = Smoothing.decay(_zoom_punch, ZOOM_PUNCH_DECAY, delta)
	zoom = Smoothing.toward(zoom, _target_zoom, ZOOM_LERP, delta)
	_camera.position.z = zoom + _zoom_punch

	if is_instance_valid(_hold_target) and _hold_target.has_method("hold_tick"):
		_hold_target.hold_tick(delta)

	_follow_timer = maxf(_follow_timer - delta, 0.0)
	# Driving under direct control cancels the post-pan follow lockout — steering
	# away from the camera and having it lag behind feels broken.
	var player_node: Node3D = get_tree().get_first_node_in_group("player")
	if player_node and player_node.get("driving"):
		_follow_timer = 0.0
	if _touches.is_empty() and not _mouse_dragged:
		global_position += _pan_vel * delta
		_pan_vel = _pan_vel.move_toward(Vector3.ZERO, PAN_INERTIA_DECAY * delta)
		if _follow_timer <= 0.0 and _pan_vel.length() < 0.5:
			_follow(delta)

	_leash()

	_update_shake(delta)


func pan_leash() -> float:
	return clampf(zoom * PAN_LEASH_ZOOM, PAN_LEASH_MIN, PAN_LEASH_MAX)


func _leash() -> void:
	# Runs after _follow and after any external assignment, exactly where the old
	# clamp sat, so a scripted camera placement is corrected on the same frame.
	if not leash_enabled:
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var offset := global_position - player.global_position
	offset.y = 0.0
	var leash := pan_leash()
	if offset.length() > leash:
		global_position = player.global_position + offset.normalized() * leash
		global_position.y = 0.0
		_pan_vel = Vector3.ZERO      # stop inertia grinding against the leash


func _follow(delta: float) -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if not player:
		return
	var to_ship := player.global_position - global_position
	to_ship.y = 0.0
	if to_ship.length() <= FOLLOW_DEADZONE:
		return
	var pull := to_ship - to_ship.normalized() * FOLLOW_DEADZONE
	# The clamp here was already correct in the sense that it could not overshoot,
	# but the fraction still varied with frame time, so the follow lagged further
	# behind at low frame rates. 1 - exp(-k*dt) is the same curve at every rate.
	global_position += pull * (1.0 - Smoothing.factor(FOLLOW_SPEED, delta))


func _update_shake(delta: float) -> void:
	if _shake_amp <= 0.0001:
		_camera.h_offset = 0.0
		_camera.v_offset = 0.0
		return
	_shake_t += delta
	# Was `amp - SHAKE_DECAY * amp * delta`, the Euler step of this exact decay.
	# A long frame could drive it negative, which maxf() caught by cutting the
	# shake dead mid-effect rather than letting it ring out.
	_shake_amp = Smoothing.decay(_shake_amp, SHAKE_DECAY, delta)
	_camera.h_offset = sin(_shake_t * SHAKE_FREQ) * _shake_amp * randf_range(0.6, 1.0)
	_camera.v_offset = cos(_shake_t * SHAKE_FREQ * 1.31) * _shake_amp * randf_range(0.6, 1.0)


func shake(amount: float) -> void:
	# Respected at the single entry point rather than at ~20 call sites, so a new
	# effect cannot forget the setting exists.
	if not GameState.shake_enabled():
		return
	_shake_amp = maxf(_shake_amp, amount)


func shake_amp() -> float:
	# Read-backs for PYXIS_FEELTEST. An assertion is only worth what it can see,
	# and the shake setting is otherwise only observable as camera offsets that
	# a headless run never renders.
	return _shake_amp


func zoom_punch() -> float:
	return _zoom_punch


func punch_zoom(amount: float) -> void:
	# Gated for the same reason shake() is, and it was not: a punch is a camera
	# lurch the player did not ask for, which is exactly what someone turning
	# screen shake off is turning off. Every punch site also shakes, so leaving
	# this open meant the setting visibly did half its job.
	if not GameState.shake_enabled():
		return
	_zoom_punch = maxf(_zoom_punch, amount)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			_touches[event.index] = event.position
			if _touches.size() == 1:
				# Touch cannot OPEN the menu (see _mouse_button), but a machine
				# with both a mouse and a touchscreen can have one open when a
				# finger lands, and a plate that ignored the touch would be a
				# plate with no way to dismiss it on that device.
				_dismiss_contact_menu()
				_press_pos = event.position
				_press_time = Time.get_ticks_msec() / 1000.0
				_dragged = false
				_pan_vel = Vector3.ZERO
				_try_begin_hold(event.position)
			elif _touches.size() == 2:
				_pinch_last = _pinch_dist()
				_release_hold()
		else:
			var was_single := _touches.size() == 1
			_touches.erase(event.index)
			var held := Time.get_ticks_msec() / 1000.0 - _press_time
			_release_hold()
			if was_single and not _dragged and held <= TAP_MAX_TIME:
				_tap(event.position)
	elif event is InputEventScreenDrag:
		_touches[event.index] = event.position
		if _touches.size() == 1:
			if event.position.distance_to(_press_pos) > TAP_MAX_PX:
				if not _dragged:
					_release_hold()
				_dragged = true
			if _dragged:
				_pan(event.relative)
		elif _touches.size() == 2:
			var d := _pinch_dist()
			if _pinch_last > 0.0 and d > 0.0:
				_target_zoom = clampf(_target_zoom * (_pinch_last / d), ZOOM_MIN, ZOOM_MAX)
			_pinch_last = d
	elif event is InputEventMouseButton:
		_mouse_button(event)
	elif event is InputEventMouseMotion and _mouse_down:
		if event.position.distance_to(_press_pos) > TAP_MAX_PX:
			if not _mouse_dragged:
				_release_hold()
			_mouse_dragged = true
		if _mouse_dragged:
			_pan(event.relative)
	elif event.is_action_pressed("cycle_target"):
		_cycle_target()
	elif event.is_action_pressed("cancel"):
		_cancel()
	elif event.is_action_pressed("ability"):
		var player: Node3D = get_tree().get_first_node_in_group("player")
		if player and player.has_method("activate_ability"):
			player.activate_ability()
	elif event.is_action_pressed("toggle_hold"):
		# THE SECOND DOOR, onto the same room. The HOLD readout has opened this
		# sheet since it existed (hud.hold_pressed -> hold_screen.toggle), touch
		# is the primary platform, and a hotkey is an ADDITIVE desktop layer --
		# never the advertised door. The manual says so on the desktop page only.
		#
		# GATED ON PLAYING. Attract mode disables only SHIP input and merely
		# HIDES the chrome, so the readout's door is shut there by being
		# invisible while this rig keeps taking events -- an ungated hotkey
		# would slide the manifest up over the title screen.
		#
		# Pause needs nothing: this node is PROCESS_MODE_INHERIT while PauseMenu
		# and ManualScreen are ALWAYS, so a paused tree stops delivering here at
		# all and the key is correctly dead, exactly like every other hotkey.
		var main := get_tree().get_first_node_in_group("main")
		if main != null and main.has_method("is_playing") and main.is_playing():
			var hold := get_tree().get_first_node_in_group("hold_screen")
			if hold != null and hold.has_method("toggle"):
				hold.toggle()
	elif event.is_action_pressed("chart"):
		# THE VERB, NOT THE PANEL. The chart's lock lives on the BUTTON --
		# HUD.set_panels_locked flips chart_button.enabled and nothing else --
		# so a key that called chart_panel.open() would walk straight past it
		# and reopen the chart mid-apex fight, which disengage_apex's own
		# comment relies on being impossible ("the player had to stand there").
		# Main.toggle_chart carries the rule; this is only a door onto it.
		var main_chart := get_tree().get_first_node_in_group("main")
		if main_chart != null and main_chart.has_method("toggle_chart"):
			main_chart.toggle_chart()
	elif event.is_action_pressed("drop_beacon"):
		# drop_beacon_here already refuses on the chart, refuses with an empty
		# rack, and prints the right toast for each -- so the key hands it the
		# decision rather than re-deriving it here. §59: the rule lives in the
		# function, not at every door into it.
		var main_beacon := get_tree().get_first_node_in_group("main")
		if main_beacon != null and main_beacon.has_method("drop_beacon_here"):
			main_beacon.drop_beacon_here()
	elif event.is_action_pressed("pause"):
		# OPENS ONLY, and that is not an omission. This node is
		# PROCESS_MODE_INHERIT, so once the tree pauses it stops receiving
		# input entirely and could not close anything if it tried; PauseMenu is
		# ALWAYS and owns the close half. Escape is split down exactly this
		# seam today, for the reason PauseMenu._unhandled_input states at the
		# top: handling one key in both places closes a console and pauses at
		# once. toggle_pause is the same wrapper the HUD button uses, and it
		# holds the PLAYING/warping guard.
		var main_pause := get_tree().get_first_node_in_group("main")
		if main_pause != null and main_pause.has_method("toggle_pause"):
			main_pause.toggle_pause()


func _mouse_button(event: InputEventMouseButton) -> void:
	# Desktop path. Deliberately separate from touch: BOTH emulation directions
	# are off in project.godot, so these two device families can disagree about
	# what the primary button means. Both matters -- for a long time only
	# emulate_touch_from_mouse was off, emulate_mouse_from_touch defaulted to
	# true, and every phone tap arrived here as well as in the touch branch.
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_target_zoom = clampf(_target_zoom * 0.9, ZOOM_MIN, ZOOM_MAX)
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_target_zoom = clampf(_target_zoom * 1.1, ZOOM_MIN, ZOOM_MAX)
		return
	# THE SECOND BUTTON, and it is desktop-only on purpose. Touch is not getting a
	# gesture for this yet: tap-on-ship already means two things (arm an engage,
	# and fall through to a move order), press-and-hold already means "work this"
	# against a four-group pick ladder, and a third meaning on either of them
	# needs a gesture audit rather than a branch. A phone player still learns who
	# a ship is and how it regards them from the first tap's toast, which is the
	# information half of this menu. See STRATEGY §64 for the deferral.
	if event.button_index == MOUSE_BUTTON_RIGHT:
		if event.pressed:
			_context_menu(event.position)
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
		# ANY PRESS ELSEWHERE DISMISSES. Presses on the menu never reach here --
		# its panel and buttons stop mouse events themselves -- so this needs no
		# hit test against the plate.
		_dismiss_contact_menu()
		_mouse_down = true
		_mouse_dragged = false
		_press_pos = event.position
		_press_time = Time.get_ticks_msec() / 1000.0
		_pan_vel = Vector3.ZERO
		_try_begin_hold(event.position)
	else:
		var held := Time.get_ticks_msec() / 1000.0 - _press_time
		_release_hold()
		if _mouse_down and not _mouse_dragged and held <= TAP_MAX_TIME:
			_click(event.position)
		_mouse_down = false
		_mouse_dragged = false


func _cycle_target() -> void:
	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and player.has_method("cycle_target"):
		var picked: Node3D = player.cycle_target()
		if picked:
			FX.ring_pulse(get_parent(), picked.global_position, Palette.THREAT, 1.2, 0.35)
			Sfx.play("tap", -6.0, 1.2)
		else:
			Sfx.play("tap", -14.0, 0.7)


func _context_menu(screen_pos: Vector2) -> void:
	# Right-click a flagged ship that is not shooting at you and it tells you what
	# it will discuss. What is on the menu is the faction's business: the band
	# decides, in HUD.contact_options.
	var hud := get_tree().get_first_node_in_group("hud")
	var main := get_tree().get_first_node_in_group("main")
	if hud == null or main == null or not main.is_playing():
		return
	# A second right-click closes whatever was open, whether or not this one lands
	# on something -- otherwise a miss leaves the old menu up, pointing at a ship
	# the player has stopped talking to.
	if hud.contact_menu_open():
		hud.hide_contact_menu()
	# The tutorial is a scripted sequence with its own idea of what the next
	# input means; the same exclusion interdictions and musters already carry.
	if main.tutorial_active():
		return
	# Same group and same picker as the left-button ladder, so what is clickable
	# is what is right-clickable and the two cannot drift.
	var ship := _pick(screen_pos, "hostiles")
	if ship != null and main.contact_menu_eligible(ship):
		Sfx.play("tap", -8.0, 1.0)
		hud.show_contact_menu(ship)


func _dismiss_contact_menu() -> bool:
	# Returns whether there was one to dismiss, so _cancel can spend a rung on it
	# without asking the same question a second way.
	var hud := get_tree().get_first_node_in_group("hud")
	if hud != null and hud.has_method("contact_menu_open") and hud.contact_menu_open():
		hud.hide_contact_menu()
		return true
	return false


func _cancel() -> void:
	# Escape is a ladder: it always backs out exactly one step, never two.
	#   1. a contact menu is open -> close it
	#   2. a console is open      -> close it
	#   3. a target is designated -> drop it
	#   4. a course is set        -> drop it
	#   5. otherwise              -> pause
	# The pause menu handles Escape itself once open, because this node stops
	# receiving input the moment the tree is paused.
	#
	# THE MENU IS THE FIRST RUNG, above the consoles, for the manual's reason one
	# line down: it is the only one of these that can be open on top of another,
	# so it has to come off first.
	if _dismiss_contact_menu():
		Sfx.play("tap", -12.0, 0.8)
		return

	var main := get_tree().get_first_node_in_group("main")
	if main:
		# The manual is first: it is the only one of these that can be open on top
		# of another, so it has to be the first step off the ladder.
		for panel in [main.manual_screen, main.hold_screen, main.port_panel, main.refit_panel, main.chart_panel]:
			if panel != null and panel.is_open:
				panel.close_panel()
				return

	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and player.has_method("clear_target") and is_instance_valid(player.attack_target):
		player.clear_target()
		Sfx.play("tap", -12.0, 0.8)
		return

	# v21. BELOW THE TARGET LOCK, so the three rungs above keep the numbers the
	# manual already prints for them and only the new one is appended. A course
	# is also the larger commitment of the two: dropping a lock is the cheaper
	# backout, so it comes off first.
	if main and main.has_method("clear_course") and player \
			and player.has_method("course_active") and player.course_active():
		main.clear_course("COURSE DROPPED")
		Sfx.play("tap", -12.0, 0.8)
		return

	if main and main.has_method("toggle_pause"):
		main.toggle_pause()


func _pinch_dist() -> float:
	var vals := _touches.values()
	if vals.size() < 2:
		return 0.0
	return (vals[0] as Vector2).distance_to(vals[1] as Vector2)


func _pan(relative: Vector2) -> void:
	var k := zoom * 0.0016
	var motion := Vector3(-relative.x * k, 0, -relative.y * k)
	global_position += motion
	_pan_vel = motion * 18.0
	_follow_timer = FOLLOW_RESUME_DELAY


func _pick(screen_pos: Vector2, group: String) -> Node3D:
	# §141. A TAP LANDS ON WHAT THE PLAYER CAN SEE, WHICH USED TO MEAN A POINT.
	#
	# This test was PICK_PX around ONE anchor for everything in the game, which
	# is right for a hulk, a seam, a beacon or a mark -- they are all a few
	# units across, so a sixty-pixel circle at their centre IS the object. It is
	# exactly wrong for the biggest object in the game. A hyper-structure spans
	# 140u; at claim range it fills the view, and its centre is usually off
	# frame. §88 fixed this object's LADDER after a playtest reported "no way to
	# interact", and the tap still could not land, because the ladder was never
	# the thing refusing it.
	#
	# So a node may declare a WORLD radius instead of accepting a pixel one, and
	# the pixels are measured rather than typed: project the anchor, project a
	# point one radius to the camera's right, and the distance between them is
	# what that object covers on THIS screen at THIS zoom. Self-correcting, no
	# magic number, and it means "tap anywhere on the thing" literally.
	#
	# FLOORED AT PICK_PX, never below: a structure seen from four thousand units
	# projects to a couple of pixels, and a big object must not become HARDER to
	# hit than a small one just because it is far away.
	#
	# IT CANNOT STEAL A TAP, and the reason is the ladder rather than care. Both
	# ladders ask each group in turn and take the first answer, with `hyper`
	# second-to-last in one and last-but-three in the other -- the ordering
	# comments there already argue that a contested tap near an instrument
	# should resolve to the smaller, more specific thing. That ordering is what
	# makes a wide radius safe here, and it was written two horizons before
	# anything needed it to be.
	var best: Node3D = null
	# Starts at infinity rather than at PICK_PX: the limit is now per node, so a
	# running best that doubled as the threshold would refuse every node whose
	# own radius is wider than the default before it was ever compared.
	var best_px := INF
	for node in get_tree().get_nodes_in_group(group):
		var n := node as Node3D
		if not is_instance_valid(n):
			continue
		var anchor: Vector3 = n.global_position
		if n.has_method("pick_anchor"):
			anchor = n.pick_anchor()
		# BEHIND THE LENS IS NOT ON THE SCREEN. unproject_position happily
		# projects a point behind the camera and returns a mirrored one, which
		# with a radius this wide would answer taps aimed at empty sky on the
		# opposite side -- a false hit that only appears once the radius is
		# large enough to reach, i.e. only on the object this commit is for.
		if _camera.is_position_behind(anchor):
			continue
		var lim := PICK_PX
		if n.has_method("pick_radius"):
			var edge := anchor + _camera.global_transform.basis.x \
				* float(n.pick_radius())
			if not _camera.is_position_behind(edge):
				lim = maxf(PICK_PX, _camera.unproject_position(anchor)
					.distance_to(_camera.unproject_position(edge)))
		var px := _camera.unproject_position(anchor).distance_to(screen_pos)
		if px < lim and px < best_px:
			best_px = px
			best = n
	return best


func _try_begin_hold(screen_pos: Vector2) -> void:
	# crackable FIRST, then mineable. The order is the whole reason seams are a
	# separate group: _pick is screen-space with no raycast, and plan_cell has no
	# keep-out between rocks and hulks, so the two can land within a tap of each
	# other. A hulk is one-time and a rock is one of many, so a contested tap
	# resolves to the hulk rather than to a coin flip.
	var target := _pick(screen_pos, "crackable")
	if target == null:
		target = _pick(screen_pos, "mineable")
	if target == null:
		# v20. Beacons LAST-but-one: they stand alone in empty deep by
		# construction (the player chose the spot), so a contested tap is nearly
		# impossible — but the ladder order is stated here rather than left to
		# accident.
		target = _pick(screen_pos, "beacon")
	if target == null:
		# And the instruments last of all, because they are the biggest thing on
		# the screen when they are on it: a hyper-structure fills the view at
		# claim range, so ANY contested tap near one should resolve to the
		# smaller, more specific thing the player was aiming at.
		target = _pick(screen_pos, "hyper")
	if target == null:
		# v23. The unsounded records, dead last for the same size argument --
		# a seven-by-sixty-four monolith owns the whole screen at read range.
		# Their own group, not "hyper": the harness cast-iterates hyper as
		# HyperStructure, and not "crackable": the radar would hang a permanent
		# band-6 arrow on a thing whose entire design is that you find the
		# depth, not the marker.
		target = _pick(screen_pos, "unsounded")
	if target == null:
		# 98. The network's buoys, after even those. A mark is SMALL -- a
		# forty-unit spar against the archive's sixty-four-unit monolith -- so
		# by the size argument it should outrank them; it goes last anyway,
		# because a mark stands 6,500u out where nothing else in this ladder can
		# be on screen at all. There is no contest to resolve, so the cheapest
		# correct thing is to leave every earlier rung untouched.
		target = _pick(screen_pos, "farmark")
	if target == null:
		# §103. THE LEGENDS' OWN GROUP, and it is one rung for all of them
		# rather than one each. The orrery carries a verb of its own, and so
		# will the forge and the procession -- three nodes that share nothing
		# except standing alone at a mark, which is exactly the case a shared
		# ladder group is for. Dead last, the far-marks argument: at 6,500u
		# nothing else in this ladder can be on screen to contest a tap.
		target = _pick(screen_pos, "legend")
	if target and target.has_method("hold_begin"):
		_hold_target = target
		target.hold_begin()


func cancel_hold() -> void:
	# Called when the world takes the ship away mid-hold — an emergency warp, in
	# practice. Without it the hold survives the death: hold_tick sees the ship
	# out of range of the wreck it is holding and issues a fresh command_move,
	# flying a just-respawned player straight back toward whatever killed them.
	_release_hold()


func _release_hold() -> void:
	if is_instance_valid(_hold_target) and _hold_target.has_method("hold_release"):
		_hold_target.hold_release()
	_hold_target = null


func _select(screen_pos: Vector2) -> bool:
	# Shared selection order for both device families. Returns true if the press
	# landed on something.
	var player: Node3D = get_tree().get_first_node_in_group("player")

	var hostile := _pick(screen_pos, "hostiles")
	if hostile:
		if GameState.hostile_to_player(hostile):
			FX.ring_pulse(get_parent(), hostile.global_position, Palette.THREAT, 1.3)
			Sfx.play("tap", -4.0, 1.12)
			if player:
				player.command_attack(hostile)
			return true
		# A FLAG THAT IS NOT SHOOTING AT YOU IS NOT A TARGET YOU CAN ORDER BY
		# ACCIDENT -- and it is still a target you can order. Both halves matter:
		# the standing ramp is that four unprovoked kills close a faction's
		# fence, so removing the choice would remove a mechanic, while leaving
		# the accident in means a brawl beside a convoy starts a second war by
		# a stray finger.
		#
		# So the first tap says exactly what the second one will do. This is
		# the same shape as the hold gesture -- an action you have to mean --
		# rather than a confirm dialog, and it costs no new surface: the toast
		# is the one already on screen for everything else.
		var now := Time.get_ticks_msec() / 1000.0
		if _engage_armed == hostile.get_instance_id() and now - _engage_at <= ENGAGE_CONFIRM:
			_engage_armed = 0
			# THE FLAG'S COLOUR, NOT THREAT. The toast that armed this confirm
			# already named the faction in its own tint; a red pulse answering it
			# says the thing you just agreed to attack was hostile all along,
			# which is the misreading this whole branch exists to prevent. The
			# hostile branch above keeps THREAT — there it is the truth.
			#
			# Asked of the ship rather than of FactionDB directly, so the pulse
			# cannot come out invisible: marker_color carries the fallback for a
			# flag with no tint, and it is the same answer the radar, the reticle
			# and the HP bar are showing for this ship at this instant.
			var pulse_col: Color = hostile.marker_color() \
				if hostile.has_method("marker_color") else Palette.THREAT
			FX.ring_pulse(get_parent(), hostile.global_position, pulse_col, 1.3)
			Sfx.play("tap", -4.0, 1.12)
			if player:
				player.command_attack(hostile)
			return true
		_engage_armed = hostile.get_instance_id()
		_engage_at = now
		var hud := get_tree().get_first_node_in_group("hud")
		if hud and hud.has_method("show_toast"):
			var flag := String(hostile.faction)
			hud.show_toast("%s — %s. TAP AGAIN TO ENGAGE" % [
				FactionDB.display_name(flag),
				FactionDB.BAND_NAMES[GameState.faction_band(flag, FactionDB.SURVEYOR)]],
				FactionDB.tint_of(flag))
		# FALLS THROUGH on purpose. Tapping a convoy still means "go there",
		# which is what the gesture means everywhere else; _click returns
		# without moving by its own design, so the desktop path is unaffected.
		return false

	var crackable := _pick(screen_pos, "crackable")
	if crackable and crackable.has_method("on_tapped"):
		Sfx.play("tap", -4.0, 0.92)
		crackable.on_tapped()
		return true

	# Between crackable and dockable, and for the same reason it sits second in
	# _try_begin_hold: a hulk outranks a rock, and a dock ring outranks nothing
	# because a seam can never sit on one (rocks keep STATION_CLEARANCE).
	var seam := _pick(screen_pos, "mineable")
	if seam and seam.has_method("on_tapped"):
		Sfx.play("tap", -4.0, 0.86)
		seam.on_tapped()
		return true

	var port := _pick(screen_pos, "dockable")
	if port and port.has_method("on_tapped"):
		port.on_tapped()
		return true
	# §96. BEACONS, AND THIS BRANCH WAS MISSING. The hold ladder above has
	# picked "beacon" since v20, but this ladder never has -- so Beacon.on_tapped
	# existed, was improved in §93 to answer all three of its cases, and was
	# never once reachable from a finger or a mouse. That is §88's exact lesson
	# repeating on the file §88 was written about: a wired verb with no
	# affordance is an unbuilt feature, and the only reliable way to catch it is
	# to check the LADDER rather than the function.
	#
	# Placed here to mirror the hold ladder's own order (crackable, mineable,
	# beacon, hyper, unsounded), so the two ladders resolve a contested tap the
	# same way.
	var beacon := _pick(screen_pos, "beacon")
	if beacon and beacon.has_method("on_tapped"):
		beacon.on_tapped()
		return true
	# v22 (88). The instruments, last for the hold ladder's own reason: they are
	# the biggest thing on screen when they are on it, so any contested tap
	# should resolve to the smaller thing first. Before this line, CLICKING the
	# largest object in the game did nothing at all -- the claim hold was fully
	# wired and the tap that every player tries first was not.
	var hyper := _pick(screen_pos, "hyper")
	if hyper and hyper.has_method("on_tapped"):
		hyper.on_tapped()
		return true
	# v23. And the unsounded records after even those, mirroring the hold
	# ladder above -- both ladders gain the group in the same commit, per §88's
	# lesson: a wired verb without an affordance is an unbuilt feature.
	var unsounded := _pick(screen_pos, "unsounded")
	if unsounded and unsounded.has_method("on_tapped"):
		unsounded.on_tapped()
		return true
	# 98. And the marks last, mirroring the hold ladder above. BOTH LADDERS IN
	# THE SAME COMMIT, which is the rule 96 paid for: Beacon.on_tapped was
	# written, improved once, and never reachable from a finger for two
	# horizons because only one of these two lists knew about it.
	var mark := _pick(screen_pos, "farmark")
	if mark and mark.has_method("on_tapped"):
		mark.on_tapped()
		return true
	# §103. And the legends themselves, last. BOTH LADDERS IN THE SAME COMMIT,
	# the rule §96 paid two horizons for -- and this is the rung the rest of
	# commit 5 hangs on, so getting it wrong would leave the forge and the
	# procession unreachable by a finger without either file changing again.
	var legend := _pick(screen_pos, "legend")
	if legend and legend.has_method("on_tapped"):
		legend.on_tapped()
		return true
	return false


func _tap(screen_pos: Vector2) -> void:
	# Touch path (mobile). Unchanged: a tap on empty space moves, because that
	# is the only way to move without a keyboard.
	if _select(screen_pos):
		return
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var hit = Plane(Vector3.UP, 0.0).intersects_ray(
		_camera.project_ray_origin(screen_pos), _camera.project_ray_normal(screen_pos))
	if hit != null:
		FX.ring_pulse(get_parent(), hit, Palette.AMBER, 0.95)
		Sfx.play("tap", -6.0)
		if player:
			player.command_move(hit)


func _click(screen_pos: Vector2) -> void:
	# Mouse path (desktop). Selects only — a miss must never issue a move order,
	# which is what made clicking small fighters punishing. Movement is WASD.
	if _select(screen_pos):
		return
	# Still acknowledge the click so it never feels like dropped input.
	Sfx.play("tap", -18.0, 0.75)
