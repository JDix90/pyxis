class_name TitleScreen
extends CanvasLayer
# The front door. Deliberately transparent: the live system drifts behind it,
# so the first thing a player sees is the actual game rather than a still.

signal new_game_pressed
signal continue_pressed
# Deliberately NOT routed through _choose(): that fades the title out and hands
# control to the game. The manual opens on top and the title stays exactly where
# it was, because reading it is not a decision to start playing.
signal manual_pressed
# A pilot was picked or created, and the run behind it is already loaded. Main
# treats it exactly like CONTINUE, because that is what it is.
signal pilot_chosen

const FADE_TIME := 0.5

var _root: Control
var _scrim: ColorRect
var _compass: Control
var _title: Label
var _tagline: Label
var _buttons: VBoxContainer
var _ledger_line: Label
var _registry_line: Label
var _continue_button: Button
var _mute_button: Button
var _pilots: VBoxContainer
var _pilots_rows: VBoxContainer
var _name_edit: LineEdit
# The id armed for deletion. One tap arms a row and relabels it, a second tap on
# the SAME row deletes -- the two-tap confirm PortPanel's undock and the pause
# menu's ABANDON both use, rather than a modal nobody can style consistently.
var _arm_delete := ""
var _t := 0.0


func _ready() -> void:
	layer = 6
	_build()
	visible = false
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)


func _apply_layout() -> void:
	# The scrim stays full-bleed (it is parented outside the column) so the
	# vignette still covers the whole window.
	UILayout.column(_root)
	if _compass == null:
		return

	# Everything here is laid out as a fraction of the available height rather
	# than at fixed offsets. A desktop window gives roughly 620 logical rows
	# against the 1280 the portrait design assumed, so pixel offsets tuned for a
	# phone stack on top of each other on a laptop.
	var h := _root.size.y
	var w := _root.size.x
	var dial := clampf(h * 0.30, 130.0, 300.0)
	var dial_top := h * 0.06

	_compass.position = Vector2((w - dial) * 0.5, dial_top)
	_compass.size = Vector2(dial, dial)
	_compass.custom_minimum_size = Vector2(dial, dial)
	_compass.pivot_offset = Vector2(dial * 0.5, dial * 0.5)

	var title_y := dial_top + dial + h * 0.05
	_title.position = Vector2(0, title_y)
	_title.size = Vector2(w, h * 0.11)
	_title.add_theme_font_size_override("font_size", int(clampf(h * 0.085, 34.0, 62.0)))

	_tagline.position = Vector2(0, title_y + h * 0.10)
	_tagline.size = Vector2(w, h * 0.04)

	_ledger_line.position = Vector2(0, title_y + h * 0.155)
	_ledger_line.size = Vector2(w, h * 0.04)
	_registry_line.position = Vector2(0, title_y + h * 0.185)
	_registry_line.size = Vector2(w, h * 0.04)

	# get_combined_minimum_size is valid immediately; `size` is still zero on the
	# first layout pass, which drops the buttons off the bottom of the screen.
	var buttons_h := maxf(_buttons.get_combined_minimum_size().y, _buttons.size.y)
	_buttons.position = Vector2((w - 240.0) * 0.5, h - (h * 0.06) - buttons_h)
	_buttons.size = Vector2(240.0, buttons_h)

	# The pilot page anchors to the same bottom margin and grows upward, so five
	# rows plus the name field push toward the wordmark rather than off the
	# screen. Clamped to the space actually available above that margin, because
	# a full rack on a laptop window is taller than the column between them.
	if _pilots != null:
		var pilots_h := minf(maxf(_pilots.get_combined_minimum_size().y, _pilots.size.y),
			h - (h * 0.06) - (title_y + h * 0.22))
		_pilots.position = Vector2((w - 240.0) * 0.5, h - (h * 0.06) - pilots_h)
		_pilots.size = Vector2(240.0, pilots_h)


func _build() -> void:
	# A vignette so the wordmark holds against a moving starfield. Parented to
	# the layer rather than to _root, because _root gets capped to a column and
	# the darkening needs to cover the whole window.
	_scrim = ColorRect.new()
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	_scrim.color = Color(0.01, 0.012, 0.02, 0.55)
	_scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_scrim)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_compass = Control.new()
	_compass.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_compass.grow_horizontal = Control.GROW_DIRECTION_BOTH
	# CENTER_TOP anchors the control's top-LEFT to the centre, so it needs to be
	# pulled back by half its width or it sits off to the right and lands on the
	# wordmark.
	_compass.size = Vector2(220, 220)
	_compass.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_compass.draw.connect(_draw_compass)
	_root.add_child(_compass)

	# Positions for all of these are computed in _apply_layout from the available
	# height, so the composition survives both a phone and a laptop window.
	_title = Label.new()
	_title.text = "PYXIS"
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 58)
	_title.add_theme_color_override("font_color", Palette.GOLD)
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_title)

	_tagline = Label.new()
	_tagline.text = "CHART THE DEAD FRONTIER"
	_tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_tagline.add_theme_font_size_override("font_size", 13)
	_tagline.add_theme_color_override("font_color", Palette.AMBER_DIM)
	_tagline.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_root.add_child(_tagline)

	# The logbook line. Shown, never edited — naming happens at the paint counter,
	# where the rest of the ship's identity lives.
	_ledger_line = Label.new()
	_ledger_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_ledger_line.add_theme_font_size_override("font_size", 11)
	_ledger_line.add_theme_color_override("font_color", Palette.TEAL)
	_ledger_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ledger_line.visible = false
	_root.add_child(_ledger_line)

	# v13. The registry line: the GSA acknowledging you, in the authority's own
	# voice, on the front door. Gold rather than teal because it is the one line
	# here that was earned rather than counted.
	_registry_line = Label.new()
	_registry_line.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_registry_line.add_theme_font_size_override("font_size", 11)
	_registry_line.add_theme_color_override("font_color", Palette.GOLD)
	_registry_line.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_registry_line.visible = false
	_root.add_child(_registry_line)

	_buttons = VBoxContainer.new()
	_buttons.custom_minimum_size = Vector2(240, 0)
	_buttons.size = Vector2(240, 0)
	_buttons.add_theme_constant_override("separation", 10)
	_root.add_child(_buttons)

	_continue_button = _make_button("CONTINUE SURVEY", Palette.GOLD)
	_continue_button.pressed.connect(func() -> void: _choose(continue_pressed))
	_buttons.add_child(_continue_button)

	var new_button := _make_button("NEW SURVEY", Palette.AMBER)
	new_button.pressed.connect(func() -> void: _choose(new_game_pressed))
	_buttons.add_child(new_button)

	var manual_button := _make_button("PILOT'S MANUAL", Palette.TEAL)
	manual_button.pressed.connect(func() -> void: manual_pressed.emit())
	_buttons.add_child(manual_button)

	var pilots_button := _make_button("PILOTS", Palette.AMBER)
	pilots_button.pressed.connect(func() -> void:
		_arm_delete = ""
		_refresh_pilots()
		_buttons.visible = false
		_pilots.visible = true
		Sfx.play("tap", -10.0, 1.0))
	_buttons.add_child(pilots_button)

	_mute_button = _make_button("AUDIO ON", Palette.TEAL)
	_mute_button.pressed.connect(_toggle_mute)
	_buttons.add_child(_mute_button)

	# The pilot page sits in the same place as the button column and replaces it,
	# rather than opening a second surface over the top. There is nothing else on
	# this screen to keep visible behind it, and a sheet would need its own
	# scrim, its own escape rung and its own layout pass.
	_pilots = VBoxContainer.new()
	_pilots.custom_minimum_size = Vector2(240, 0)
	_pilots.size = Vector2(240, 0)
	_pilots.add_theme_constant_override("separation", 8)
	_pilots.visible = false
	_root.add_child(_pilots)

	_pilots_rows = VBoxContainer.new()
	_pilots_rows.add_theme_constant_override("separation", 6)
	_pilots.add_child(_pilots_rows)

	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 6)
	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "NAME"
	_name_edit.max_length = Profiles.NAME_MAX
	_name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_edit.add_theme_font_size_override("font_size", 12)
	name_row.add_child(_name_edit)
	var add := _make_button("NEW", Palette.TEAL)
	add.custom_minimum_size = Vector2(80, 34)
	add.pressed.connect(_create_pilot)
	name_row.add_child(add)
	_pilots.add_child(name_row)

	var back := _make_button("BACK", Palette.TEAL)
	back.custom_minimum_size = Vector2(240, 38)
	back.pressed.connect(func() -> void:
		_arm_delete = ""
		_pilots.visible = false
		_buttons.visible = true
		Sfx.play("tap", -12.0, 0.9))
	_pilots.add_child(back)


func _refresh_pilots() -> void:
	for child in _pilots_rows.get_children():
		child.queue_free()
	var rows := Profiles.list_profiles()
	var active := Profiles.active_id()
	for row_v in rows:
		var row: Dictionary = row_v
		var id := String(row["id"])
		var sum: Dictionary = row.get("summary", {})
		# The summary is whatever that pilot last SAVED, so a row nobody has
		# played yet says so rather than printing a line of zeroes -- the same
		# argument the ledger line makes for hiding itself with no save.
		var detail := "NEW SURVEY"
		if not sum.is_empty():
			detail = "%s · %du DEEPEST · %d HULLS" % [
				String(sum.get("ship_name", "—")),
				int(sum.get("deepest", 0)), int(sum.get("hulks", 0))]
		var armed := _arm_delete == id
		var tint := Palette.AMBER
		if armed:
			tint = Palette.THREAT
		elif id == active:
			tint = Palette.GOLD
		var b := _make_button("", tint)
		# Spelled out rather than folded into a ternary: `"%s" % x if c else "%s"`
		# reads as one expression and parses as another, and this line is the
		# difference between a delete confirm and a pilot row.
		if armed:
			b.text = "DELETE %s — TAP AGAIN" % String(row["name"])
		else:
			b.text = "%s\n%s" % [String(row["name"]), detail]
		b.custom_minimum_size = Vector2(240, 46)
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_on_pilot_pressed.bind(id))
		_pilots_rows.add_child(b)

		var kill := _make_button("×", Palette.THREAT)
		kill.custom_minimum_size = Vector2(240, 22)
		kill.add_theme_font_size_override("font_size", 11)
		kill.visible = not armed
		kill.pressed.connect(func() -> void:
			_arm_delete = id
			_refresh_pilots()
			Sfx.play("tap", -10.0, 0.8))
		_pilots_rows.add_child(kill)
	_apply_layout()


func _on_pilot_pressed(id: String) -> void:
	# One button, two meanings, decided by whether this row is armed -- which is
	# what makes the confirm a SECOND tap on the thing being deleted rather than
	# a yes/no somewhere else on the screen.
	if _arm_delete == id:
		Profiles.delete(id)
		_arm_delete = ""
		_refresh_pilots()
		Sfx.play("tap", -8.0, 0.7)
		return
	_arm_delete = ""
	if not GameState.switch_profile(id):
		return
	Sfx.play("equip", -8.0, 1.1)
	_choose(pilot_chosen)


func _create_pilot() -> void:
	if Profiles.list_profiles().size() >= Profiles.MAX_PROFILES:
		# Refused on the button rather than silently: §12's rule, that the odds
		# go on the button. There is no room and the page says so.
		_name_edit.placeholder_text = "NO ROOM — DELETE ONE FIRST"
		Sfx.play("tap", -14.0, 0.7)
		return
	var id := Profiles.create(_name_edit.text, Time.get_unix_time_from_system())
	if id == "":
		return
	_name_edit.text = ""
	if not GameState.switch_profile(id):
		return
	Sfx.play("equip", -8.0, 1.1)
	_choose(pilot_chosen)


func _make_button(text: String, color: Color) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(240, 46)
	b.add_theme_font_size_override("font_size", 15)
	b.add_theme_color_override("font_color", color)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(color.r, color.g, color.b, 0.10)
	style.border_color = Color(color.r, color.g, color.b, 0.55)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	b.add_theme_stylebox_override("normal", style)
	var hover := style.duplicate()
	hover.bg_color = Color(color.r, color.g, color.b, 0.20)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", hover)
	return b


func _draw_compass() -> void:
	# The Pyxis motif: a mariner's compass rose drawn in the cartography amber.
	var c := _compass.size * 0.5
	var r := minf(c.x, c.y) * 0.86
	_compass.draw_arc(c, r, 0.0, TAU, 64, Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.5), 1.5, true)
	_compass.draw_arc(c, r * 0.72, 0.0, TAU, 48, Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.22), 1.0, true)
	for i in range(32):
		var ang := TAU * float(i) / 32.0
		var long := i % 8 == 0
		var inner := r * (0.80 if long else 0.90)
		var col := Palette.GOLD if long else Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.35)
		_compass.draw_line(c + Vector2(cos(ang), sin(ang)) * inner,
			c + Vector2(cos(ang), sin(ang)) * r, col, 1.5 if long else 1.0, true)
	# Cardinal points.
	for i in range(4):
		var ang := TAU * float(i) / 4.0 - PI * 0.5
		var tip := c + Vector2(cos(ang), sin(ang)) * r * 0.62
		var left := c + Vector2(cos(ang + 2.4), sin(ang + 2.4)) * r * 0.20
		var right := c + Vector2(cos(ang - 2.4), sin(ang - 2.4)) * r * 0.20
		_compass.draw_colored_polygon(PackedVector2Array([tip, left, c, right]),
			Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.55 if i == 0 else 0.25))


func _process(delta: float) -> void:
	if not visible:
		return
	_t += delta
	_compass.rotation = _t * 0.06
	_compass.queue_redraw()


func open(has_save: bool) -> void:
	visible = true
	# A save from a NEWER build exists but could not be read, so has_save() is
	# true while there is nothing to continue INTO: the state in memory is a
	# fresh starter run. Offering CONTINUE there walks the player into a new
	# game under a button that promised their pilot back. The file itself is
	# safe -- load_game locked saving before returning -- and the line below
	# says so, because "your save is fine, this build just cannot read it" is
	# the only part of this the player actually needs.
	# The page never survives a close: it is a picker, and reopening the title
	# with a row still armed for deletion is a live trap.
	_arm_delete = ""
	if _pilots != null:
		_pilots.visible = false
	_buttons.visible = true
	var refused := GameState.newer_save_refused
	_continue_button.visible = has_save and not refused
	# Hidden with CONTINUE, and for the same reason: with no save there is no run
	# to summarise, and a row of zeroes on the front door is worse than nothing.
	_ledger_line.visible = has_save
	if refused:
		_ledger_line.text = "SAVE WRITTEN BY A NEWER BUILD — NOT LOADED, NOT OVERWRITTEN"
		_ledger_line.add_theme_color_override("font_color", Palette.THREAT)
	elif has_save:
		_ledger_line.text = title_summary()
		_ledger_line.add_theme_color_override("font_color", Palette.TEAL)
	# Same has_save rule as the ledger line above, or the registry line renders
	# over empty space where a summary should have been.
	_registry_line.visible = has_save and GameState.commissioned and not refused
	if _registry_line.visible:
		_registry_line.text = registry_line()
	_refresh_mute()
	_root.modulate.a = 0.0
	_scrim.modulate.a = 0.0
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_root, "modulate:a", 1.0, FADE_TIME)
	tw.tween_property(_scrim, "modulate:a", 1.0, FADE_TIME)


func registry_line() -> String:
	# The in-universe acknowledgement, not a stat. It names the ship rather than
	# the player and states a fact about a file rather than a score, because the
	# whole point of the Commission is that the authority is describing you --
	# `commission_claimed` deliberately never appears on this screen.
	return "%s — COMMISSIONED, GALACTIC SURVEY AUTHORITY" % GameState.ship_name


func title_summary() -> String:
	# One line, read-only. Harness accessor for the same reason
	# continue_available() is one: the text a player sees on the front door is
	# worth asserting, and nothing else can reach it.
	return "%s · DEEPEST %du · %d HULLS · %du FLOWN" % [
		GameState.ship_name,
		int(GameState.ledger.get("deepest_depth", 0)),
		int(GameState.ledger.get("hulks_cracked", 0)),
		int(GameState.ledger.get("distance_flown", 0))]


func continue_available() -> bool:
	return _continue_button.visible


func _choose(sig: Signal) -> void:
	Sfx.play("equip", -4.0, 1.0)
	var tw := create_tween()
	tw.set_parallel(true)
	tw.tween_property(_root, "modulate:a", 0.0, FADE_TIME * 0.6)
	tw.tween_property(_scrim, "modulate:a", 0.0, FADE_TIME * 0.6)
	tw.chain().tween_callback(func() -> void:
		visible = false
		sig.emit()
	)


func _toggle_mute() -> void:
	GameState.set_audio_muted(not GameState.audio_muted)
	_refresh_mute()
	if not GameState.audio_muted:
		Sfx.play("tap", -6.0)


func _refresh_mute() -> void:
	_mute_button.text = "AUDIO OFF" if GameState.audio_muted else "AUDIO ON"
