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


func _mouse_button(event: InputEventMouseButton) -> void:
	# Desktop path. Deliberately separate from touch: mouse emulation is off so
	# these two device families can disagree about what the primary button means.
	if event.button_index == MOUSE_BUTTON_WHEEL_UP and event.pressed:
		_target_zoom = clampf(_target_zoom * 0.9, ZOOM_MIN, ZOOM_MAX)
		return
	if event.button_index == MOUSE_BUTTON_WHEEL_DOWN and event.pressed:
		_target_zoom = clampf(_target_zoom * 1.1, ZOOM_MIN, ZOOM_MAX)
		return
	if event.button_index != MOUSE_BUTTON_LEFT:
		return

	if event.pressed:
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


func _cancel() -> void:
	# Escape is a ladder: it always backs out exactly one step, never two.
	#   1. a console is open      -> close it
	#   2. a target is designated -> drop it
	#   3. otherwise              -> pause
	# The pause menu handles Escape itself once open, because this node stops
	# receiving input the moment the tree is paused.
	var main := get_tree().get_first_node_in_group("main")
	if main:
		# The manual is first: it is the only one of these that can be open on top
		# of another, so it has to be the first step off the ladder.
		for panel in [main.manual_screen, main.port_panel, main.refit_panel, main.chart_panel]:
			if panel != null and panel.is_open:
				panel.close_panel()
				return

	var player: Node3D = get_tree().get_first_node_in_group("player")
	if player and player.has_method("clear_target") and is_instance_valid(player.attack_target):
		player.clear_target()
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
	var best: Node3D = null
	var best_px := PICK_PX
	for node in get_tree().get_nodes_in_group(group):
		var n := node as Node3D
		if not is_instance_valid(n):
			continue
		var anchor: Vector3 = n.global_position
		if n.has_method("pick_anchor"):
			anchor = n.pick_anchor()
		var px := _camera.unproject_position(anchor).distance_to(screen_pos)
		if px < best_px:
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
		FX.ring_pulse(get_parent(), hostile.global_position, Palette.THREAT, 1.3)
		Sfx.play("tap", -4.0, 1.12)
		if player:
			player.command_attack(hostile)
		return true

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
