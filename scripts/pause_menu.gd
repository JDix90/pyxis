class_name PauseMenu
extends CanvasLayer
# The pause overlay: RESUME / SETTINGS / ABANDON TO TITLE.
#
# Uses `get_tree().paused`, which means everything here — and only things here —
# must run with PROCESS_MODE_ALWAYS. Sfx, GameState and Music already do (a
# volume slider you cannot hear move is not a slider); gameplay nodes pause by
# default, which is the whole point.
#
# Same bottom-sheet-adjacent vocabulary as the other consoles, but centred and
# modal rather than a sheet: pausing is not another console, it is stepping out.

const FADE_TIME := 0.18
const SCRIM := Color(0.01, 0.012, 0.02, 0.82)
# How much of the logical canvas the sheet may not take: the panel's own 18px
# margins top and bottom, plus a little air so the border never sits on the
# screen edge. MIN_SHEET is the floor for a window short enough that the
# subtraction would otherwise leave nothing.
const SHEET_MARGIN := 56.0
const MIN_SHEET := 160.0

var is_open := false

var _root: Control
var _scrim: ColorRect
var _panel: PanelContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _page := "root"
var _confirming_abandon := false
# Action awaiting a key press on the controls page, "" when not capturing.
var _capturing := ""


func _ready() -> void:
	layer = 6           # above every console sheet
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("pause_menu")
	_build()
	visible = false
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_scrim = ColorRect.new()
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.color = SCRIM
	# STOP, so a tap that misses a button cannot fall through and fly the ship.
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_scrim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(340, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.04, 0.98)
	style.border_color = Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 20
	style.content_margin_right = 20
	style.content_margin_top = 18
	style.content_margin_bottom = 18
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	# The sheet grows to its content and is CAPPED at the window, scrolling the
	# overflow. Without the cap it silently overflows both ways at once: a
	# PanelContainer centred with grow-BOTH and no clip pushes its heading off the
	# top and its last button off the bottom simultaneously, which is the one
	# failure mode a player cannot work around. The root page was already over the
	# line at a 1.6 UI scale before the log was added to it (530 rows against
	# 512) — a boss fight and an abandon-confirm can be on screen together and
	# nothing clears one when the other arrives.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 10)
	_scroll.add_child(_body)


func _apply_layout() -> void:
	UILayout.column(_root)
	_clamp_height()


func _clamp_height() -> void:
	# A ScrollContainer inside a height-unbounded PanelContainer sizes to its
	# content and scrolls nothing, so the bound has to be stated. Measured with
	# get_combined_minimum_size for the reason the title screen states: `size` is
	# still zero on the first layout pass, and reading it drops the sheet to
	# nothing on the frame the menu opens.
	if _scroll == null or _root == null:
		return
	var avail := maxf(_root.size.y - SHEET_MARGIN, MIN_SHEET)
	_scroll.custom_minimum_size.y = minf(_body.get_combined_minimum_size().y, avail)


# --- open / close -----------------------------------------------------------

func open() -> void:
	if is_open:
		return
	is_open = true
	_page = "root"
	_confirming_abandon = false
	visible = true
	_refresh()
	get_tree().paused = true
	Sfx.play("tap", -8.0, 0.8)
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_root, "modulate:a", 1.0, FADE_TIME)


func close_panel() -> void:
	# Named to match the other consoles, so CameraRig's escape ladder and any
	# future "close whatever is open" loop can treat them all alike.
	resume()


func resume() -> void:
	if not is_open:
		return
	is_open = false
	# Unpause immediately, fade the sheet out after. The game has to be running
	# again on the frame the player asked for it -- a menu that stays modal
	# through its own exit animation is the single most common way a pause screen
	# feels cheap. So the fade is decoration over a game already in motion, which
	# is why it is half the length of the fade in.
	get_tree().paused = false
	Sfx.play("tap", -12.0, 1.1)
	if GameState.reduce_motion():
		visible = false
		return
	var tw := create_tween()
	tw.tween_property(_root, "modulate:a", 0.0, UIKit.T_QUICK)
	tw.tween_callback(func() -> void:
		# Guarded: open() can win the race if the player re-pauses inside 0.12s,
		# and hiding the sheet out from under a fresh open would leave the game
		# paused with nothing on screen.
		if not is_open:
			visible = false)


func _unhandled_input(event: InputEvent) -> void:
	# Only while open. When the game is running, Escape belongs to CameraRig's
	# back-out-one-step ladder, which is what decides to call open() in the first
	# place — handling it in both places would close a console and pause at once.
	if not is_open:
		return
	# THE MANUAL OWNS ESCAPE WHILE IT IS UP. _unhandled_input is delivered in
	# TREE order, not CanvasLayer order, so a higher `layer` buys drawing on top
	# and nothing else -- without this guard, Escape inside the manual would fall
	# through to the sheet underneath and resume the game instead of backing out
	# one page. Both nodes are PROCESS_MODE_ALWAYS, so both are live here.
	var manual := get_tree().get_first_node_in_group("manual_screen")
	if manual != null and bool(manual.get("is_open")):
		return
	# Ahead of the cancel ladder on purpose: while a row is armed, the very next
	# key IS the binding. Escape included -- otherwise Escape is the one key that
	# cannot be bound, and it would close the page instead.
	if _capturing != "":
		var key := event as InputEventKey
		if key != null and key.pressed and not key.echo:
			var action := _capturing
			_capturing = ""
			if not GameState.rebind(action, key.physical_keycode):
				Sfx.play("tap", -14.0, 0.7)
			_refresh()
			get_viewport().set_input_as_handled()
		return
	# THE CLOSE HALF OF THE PAUSE KEY. CameraRig opens (it is INHERIT, so it is
	# live only while the game runs); this closes (ALWAYS, so it is live only
	# once the tree is paused). Same seam Escape is split down, and for the
	# reason at the top of this function.
	#
	# It resumes from ANY page rather than backing out one step, which is the
	# whole difference between it and Escape below: `cancel` means "back out of
	# what I opened", `pause` means "unpause". A player on the settings page
	# who presses the pause key is asking for the game, not for the root page.
	#
	# Inert while the manual is up, because the guard above returns first. That
	# is deliberate and matches Escape: the manual owns its own back-out, and a
	# key that resumed the game out from under an open manual would leave the
	# player flying with a page in their face.
	if event.is_action_pressed("pause"):
		resume()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("cancel"):
		if _page != "root":
			_page = "root"
			_refresh()
		else:
			resume()
		get_viewport().set_input_as_handled()


# --- pages ------------------------------------------------------------------

func _refresh() -> void:
	for c in _body.get_children():
		c.queue_free()
	if _page == "settings":
		_build_settings()
	elif _page == "controls":
		_build_controls()
	elif _page == "log":
		_build_log()
	else:
		_build_root()
	# The cap is per-PAGE, not per-window: three pages of different heights share
	# one sheet, so re-measuring on resize alone would leave the log page wearing
	# the root page's height.
	_clamp_height()


func _build_root() -> void:
	_body.add_child(_heading("PAUSED"))
	_body.add_child(_sub(SystemDB.display_name(GameState.current_system)))
	# The pilot line. The pause menu is reachable anywhere, including 900u out
	# with no station in any direction — which is exactly where a player wants to
	# know what they can read.
	_body.add_child(_sub(GameState.archeology_line()))
	_body.add_child(_sub(GameState.smuggling_line()))
	# The third line is SAFE to add here, and that was measured rather than
	# assumed: the root page already sits past its scroll cap at a 1.6 UI scale
	# (546 rows against 456), so _clamp_height pins the panel at 492 of 512 and a
	# fourth _sub costs 26 rows of scroll rather than an overflow. SHEET FITS
	# cannot see the difference — see STRATEGY §36 for why that is its own defect.
	_body.add_child(_sub(GameState.mining_line()))
	# And a FOURTH, on the same measured argument as the third: the page is
	# already scrolling at a 1.6 UI scale, so this costs rows of scroll rather
	# than an overflow, and _clamp_height keeps the panel inside the canvas
	# either way. SHEET FITS still cannot tell the difference — it reads the
	# clamped panel height, which is exactly what the clamp guarantees.
	_body.add_child(_sub(GameState.persuasion_line()))
	_body.add_child(_spacer(6))
	_body.add_child(_action("RESUME", Palette.TEAL, resume))
	_body.add_child(_action("CAPTAIN'S LOG", Palette.AMBER, func() -> void:
		_page = "log"
		_refresh()))
	_body.add_child(_action("SETTINGS", Palette.AMBER, func() -> void:
		_page = "settings"
		_refresh()))
	# The manual opens OVER this sheet rather than as a page inside it, and the
	# pause state is deliberately left alone: ManualScreen never touches
	# get_tree().paused, so closing it returns here with the game still stopped.
	_body.add_child(_action("PILOT'S MANUAL", Palette.AMBER, func() -> void:
		var m := get_tree().get_first_node_in_group("manual_screen")
		if m != null:
			m.open()))

	# The way out of a boss fight. It lives here because the pause menu is the
	# one console reachable mid-encounter — the refit and chart buttons are
	# locked by set_panels_locked, and docking is refused outright.
	var main := get_tree().get_first_node_in_group("main")
	if main != null and bool(main.get("boss_active")):
		_body.add_child(_sub("The engine resets to full strength. Nothing you have earned is lost."))
		_body.add_child(_action("BREAK OFF ENGAGEMENT", Palette.TEAL, func() -> void:
			main.disengage_apex()
			resume()))

	if _confirming_abandon:
		_body.add_child(_sub("Progress is saved. The run stays where it is."))
		_body.add_child(_action("CONFIRM — ABANDON", Palette.THREAT, _abandon))
		_body.add_child(_action("KEEP FLYING", Palette.AMBER, func() -> void:
			_confirming_abandon = false
			_refresh()))
	else:
		_body.add_child(_action("ABANDON TO TITLE", Palette.THREAT, func() -> void:
			_confirming_abandon = true
			_refresh()))


func _build_log() -> void:
	# The last ten things that happened, oldest first. Chronological rather than
	# newest-first on purpose: ten lines all fit on one sheet, so there is nothing
	# to scroll past, and read top to bottom they are the shape of the run — which
	# is the only thing this page is for. The ledger already answers "how many".
	_body.add_child(_heading("CAPTAIN'S LOG"))
	var lines := GameState.log_lines()
	if lines.is_empty():
		# The title screen's own rule: with nothing to summarise, say so rather
		# than printing a column of blanks.
		_body.add_child(_sub("NOTHING LOGGED THIS SURVEY YET"))
	# Revealed one at a time rather than built as a block. Ten lines arriving at
	# once is a wall of text; arriving in sequence they read as a record being
	# played back, which is the only thing this page is for. The stagger is short
	# enough (0.035s) that the whole log is legible in under half a second -- this
	# is a texture on the page appearing, not a cutscene to sit through.
	var entries: Array = []
	for line in lines:
		var l := _sub(String(line))
		entries.append(l)
		_body.add_child(l)
	UIKit.reveal_list(entries, GameState.reduce_motion())
	_body.add_child(_spacer(4))
	_body.add_child(_action("BACK", Palette.TEAL, func() -> void:
		_page = "root"
		_refresh()))


func show_log() -> void:
	# The log page, opened directly. Exists so PYXIS_UITEST can reach the reveal
	# without driving the menu through two synthetic button presses -- the page is
	# the thing under test, not the route to it.
	if not is_open:
		open()
	_page = "log"
	_refresh()


func log_entries() -> Array:
	# The rendered log lines, in order. The reveal is a per-label tween on
	# modulate:a, which is otherwise invisible to a headless run.
	var out: Array = []
	var seen_heading := false
	for c in _body.get_children():
		if c is Label:
			if not seen_heading:
				seen_heading = true      # skip the CAPTAIN'S LOG heading itself
				continue
			out.append(c)
	return out


func _build_settings() -> void:
	_body.add_child(_heading("SETTINGS"))
	_body.add_child(_slider("MUSIC", "music_vol", 0.0, 1.0, 0.05))
	_body.add_child(_slider("EFFECTS", "sfx_vol", 0.0, 1.0, 0.05))
	_body.add_child(_slider("UI SCALE", "ui_scale", 0.7, 1.6, 0.05))
	_body.add_child(_toggle("SCREEN SHAKE", "shake"))
	_body.add_child(_toggle("REDUCE MOTION", "reduce_motion"))
	_body.add_child(_toggle("HAPTICS", "haptics"))
	_body.add_child(_toggle("SHARE PLAY DATA", "telemetry"))
	_body.add_child(_cycler("COLOUR VISION", "colorblind", VISION_NAMES))
	_body.add_child(_spacer(4))
	_body.add_child(_action("CONTROLS", Palette.AMBER, func() -> void:
		_page = "controls"
		_refresh()))
	_body.add_child(_spacer(4))
	_body.add_child(_action("BACK", Palette.TEAL, func() -> void:
		_page = "root"
		_refresh()))


# --- widgets ----------------------------------------------------------------

func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 22)
	l.add_theme_color_override("font_color", Palette.GOLD)
	return l


func _sub(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	l.add_theme_font_size_override("font_size", 11)
	l.add_theme_color_override("font_color", Palette.AMBER_DIM)
	return l


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _action(text: String, accent: Color, cb: Callable) -> Button:
	# Was a bare Button with only a font colour set, which meant the most-used
	# menu in the game rendered in stock Godot grey while the title screen -- the
	# one screen a player sees least -- was the only styled surface in the build.
	var b := UIKit.button(text, accent, 14)
	b.pressed.connect(func() -> void:
		UIKit.press_pop(b)
		cb.call())
	return b


func _slider(label: String, key: String, lo: float, hi: float, step: float) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var head := HBoxContainer.new()
	var name_label := Label.new()
	name_label.text = label
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Palette.HULL)
	head.add_child(name_label)

	var value_label := Label.new()
	value_label.add_theme_font_size_override("font_size", 12)
	value_label.add_theme_color_override("font_color", Palette.AMBER)
	head.add_child(value_label)
	box.add_child(head)

	var slider := HSlider.new()
	slider.min_value = lo
	slider.max_value = hi
	slider.step = step
	slider.value = clampf(float(GameState.setting(key)), lo, hi)
	slider.custom_minimum_size = Vector2(0, 22)
	value_label.text = _percent(slider.value, key)
	slider.value_changed.connect(func(v: float) -> void:
		value_label.text = _percent(v, key)
		GameState.set_setting(key, v))
	box.add_child(slider)
	return box


func _percent(v: float, key: String) -> String:
	# UI scale reads as a multiplier; volumes read as percentages.
	return ("%.2fx" % v) if key == "ui_scale" else ("%d%%" % int(round(v * 100.0)))


# Named in the player's terms rather than in the palette's. "DEUTERANOPIA" is
# the correct word and the wrong label: most people who need this setting know
# what they cannot tell apart, not what it is called.
const VISION_NAMES := ["OFF", "RED-GREEN (A)", "RED-GREEN (B)", "BLUE-YELLOW"]


func _cycler(label: String, key: String, names: Array) -> Button:
	# A cycling button rather than a dropdown: this is a portrait phone UI with
	# no other popup anywhere in it, and four options do not earn a new widget.
	var b := UIKit.button("", Palette.AMBER, 12)
	b.custom_minimum_size = Vector2(0, 36)
	var sync := func() -> void:
		var i := clampi(int(GameState.setting(key)), 0, names.size() - 1)
		b.text = "%s   %s" % [label, String(names[i])]
	sync.call()
	b.pressed.connect(func() -> void:
		var i := (int(GameState.setting(key)) + 1) % names.size()
		GameState.set_setting(key, i)
		sync.call())
	return b


func _build_controls() -> void:
	_body.add_child(_heading("CONTROLS"))
	_body.add_child(_sub("TAP AN ACTION, THEN PRESS A KEY."))
	for action in GameState.REBINDABLE:
		_body.add_child(_binding_row(String(action)))
	_body.add_child(_spacer(4))
	# Escape is not in REBINDABLE and this is why: it is the way out of every
	# console and out of this page. A player who bound it to a key they cannot
	# reach would have no route back to the screen that could fix it.
	_body.add_child(_sub("CANCEL IS ALWAYS ESCAPE."))
	_body.add_child(_action("RESET TO DEFAULTS", Palette.AMBER, func() -> void:
		GameState.reset_bindings()
		_refresh()))
	_body.add_child(_action("BACK", Palette.TEAL, func() -> void:
		_page = "settings"
		_refresh()))


func _binding_row(action: String) -> Button:
	var b := UIKit.button("", Palette.AMBER, 12)
	b.custom_minimum_size = Vector2(0, 34)
	b.text = "%s   %s" % [action.to_upper().replace("_", " "), GameState.binding_name(action)]
	b.pressed.connect(func() -> void:
		_capturing = action
		b.text = "%s   PRESS A KEY" % action.to_upper().replace("_", " ")
		b.add_theme_color_override("font_color", Palette.GOLD))
	return b


func _toggle(label: String, key: String) -> Button:
	var b := Button.new()
	b.toggle_mode = true
	b.button_pressed = bool(GameState.setting(key))
	b.custom_minimum_size = Vector2(0, 36)
	b.add_theme_font_size_override("font_size", 12)
	_sync_toggle(b, label)
	b.toggled.connect(func(on: bool) -> void:
		GameState.set_setting(key, on)
		_sync_toggle(b, label))
	return b


func _sync_toggle(b: Button, label: String) -> void:
	b.text = "%s   %s" % [label, "ON" if b.button_pressed else "OFF"]
	b.add_theme_color_override("font_color",
		Palette.TEAL if b.button_pressed else Palette.AMBER_DIM)


# --- abandon ----------------------------------------------------------------

func _abandon() -> void:
	# Nothing is discarded: the save already holds everything, and the title's
	# CONTINUE picks the run back up exactly where it stood.
	GameState.save_game()
	resume()
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("abandon_to_title"):
		main.abandon_to_title()
