class_name ChartPanel
extends CanvasLayer
# The star chart: a bottom sheet showing systems as nodes on bearing lines.
# Locked systems show what you must breach to chart them, so progression is
# always legible from inside the fiction.

signal travel_requested(id: String)
signal recall_requested

const SHEET_RATIO := 0.55
const SLIDE_TIME := 0.28
const NODE_RADIUS := 17.0

var is_open := false

var _sheet: Panel
var _map: Control
var _title: Label
var _detail: Label
var _travel_button: Button
var _recall_button: Button
var _selected := ""


func _ready() -> void:
	layer = 2
	_build()
	visible = false
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)


func _apply_layout() -> void:
	UILayout.column_horizontal(_sheet)


func _build() -> void:
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_sheet = Panel.new()
	_sheet.anchor_left = 0.0
	_sheet.anchor_right = 1.0
	_sheet.anchor_top = 1.0 - SHEET_RATIO
	_sheet.anchor_bottom = 1.0
	_sheet.offset_left = 0.0
	_sheet.offset_right = 0.0
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.04, 0.97)
	style.border_color = Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.55)
	style.border_width_top = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	_sheet.add_theme_stylebox_override("panel", style)
	root.add_child(_sheet)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_sheet.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 8)
	margin.add_child(col)

	var header := HBoxContainer.new()
	var title := Label.new()
	title.text = "CHART"
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	title.add_theme_color_override("font_color", Palette.AMBER)
	title.add_theme_font_size_override("font_size", 20)
	header.add_child(title)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	close.add_theme_font_size_override("font_size", 18)
	close.add_theme_color_override("font_color", Palette.AMBER)
	close.pressed.connect(close_panel)
	header.add_child(close)
	col.add_child(header)

	_map = Control.new()
	_map.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_map.custom_minimum_size = Vector2(0, 170)
	_map.mouse_filter = Control.MOUSE_FILTER_STOP
	_map.draw.connect(_draw_map)
	_map.gui_input.connect(_on_map_input)
	col.add_child(_map)

	_title = Label.new()
	_title.add_theme_font_size_override("font_size", 16)
	_title.add_theme_color_override("font_color", Palette.GOLD)
	col.add_child(_title)

	_detail = Label.new()
	_detail.add_theme_font_size_override("font_size", 11)
	_detail.add_theme_color_override("font_color", Color(0.62, 0.62, 0.68))
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_detail)

	# Above WARP, because when it is showing it is the more urgent of the two:
	# you are outside the charted volume and this is the way back in. Hidden
	# entirely inside a system rather than disabled — an always-present button
	# that is dead 95% of the time teaches players to stop reading the row.
	_recall_button = Button.new()
	_recall_button.custom_minimum_size = Vector2(0, 42)
	_recall_button.add_theme_font_size_override("font_size", 14)
	_recall_button.add_theme_color_override("font_color", Palette.TEAL)
	_recall_button.visible = false
	_recall_button.pressed.connect(_on_recall)
	col.add_child(_recall_button)

	_travel_button = Button.new()
	_travel_button.custom_minimum_size = Vector2(0, 42)
	_travel_button.add_theme_font_size_override("font_size", 14)
	_travel_button.pressed.connect(_on_travel)
	col.add_child(_travel_button)


# --- drawing ----------------------------------------------------------------

func _node_pos(id: String) -> Vector2:
	var p: Vector2 = SystemDB.get_system(id).get("chart_pos", Vector2(0.5, 0.5))
	var pad := NODE_RADIUS + 12.0
	return Vector2(
		lerpf(pad, _map.size.x - pad, p.x),
		lerpf(pad, _map.size.y - pad, p.y))


func _draw_map() -> void:
	var current := GameState.current_system
	var drawn := {}

	# Bearing lines between connected systems.
	for id_v in SystemDB.ids():
		var id := str(id_v)
		for other_v in SystemDB.get_system(id).get("connections", []):
			var other := str(other_v)
			var key := id + "|" + other if id < other else other + "|" + id
			if drawn.has(key):
				continue
			drawn[key] = true
			var lit := GameState.is_system_unlocked(id) and GameState.is_system_unlocked(other)
			var col := Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.45 if lit else 0.13)
			_map.draw_line(_node_pos(id), _node_pos(other), col, 1.5, true)

	for id_v in SystemDB.ids():
		var id := str(id_v)
		var pos := _node_pos(id)
		var unlocked := GameState.is_system_unlocked(id)
		var is_current := id == current
		var is_sel := id == _selected

		if is_current:
			_map.draw_arc(pos, NODE_RADIUS + 7.0, 0.0, TAU, 32,
				Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.5), 1.5, true)
		if is_sel:
			_map.draw_arc(pos, NODE_RADIUS + 3.0, 0.0, TAU, 32, Palette.TEAL, 1.5, true)

		var fill := Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.9) if is_current \
			else (Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.32) if unlocked \
			else Color(0.16, 0.16, 0.2, 0.9))
		_map.draw_circle(pos, NODE_RADIUS, fill)
		_map.draw_arc(pos, NODE_RADIUS, 0.0, TAU, 32,
			Palette.AMBER if unlocked else Color(0.4, 0.35, 0.4), 1.5, true)

		if not unlocked:
			# A small lock glyph: a bar over a box.
			_map.draw_rect(Rect2(pos + Vector2(-4, -1), Vector2(8, 8)), Color(0.65, 0.6, 0.65))
			_map.draw_arc(pos + Vector2(0, -1), 4.0, PI, TAU, 10, Color(0.65, 0.6, 0.65), 1.5, true)

		var font := ThemeDB.fallback_font
		var label := String(SystemDB.get_system(id).get("name", id))
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		_map.draw_string(font, pos + Vector2(-w * 0.5, NODE_RADIUS + 15.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Palette.AMBER if unlocked else Color(0.5, 0.45, 0.5))


func _on_map_input(event: InputEvent) -> void:
	var pressed := false
	var pos := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true
		pos = event.position
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
		pos = event.position
	if not pressed:
		return
	for id_v in SystemDB.ids():
		var id := str(id_v)
		if _node_pos(id).distance_to(pos) <= NODE_RADIUS + 10.0:
			_select(id)
			Sfx.play("tap", -6.0, 1.05)
			return


func _select(id: String) -> void:
	_selected = id
	_refresh()


# --- open / close -----------------------------------------------------------

func _sheet_height() -> float:
	return get_viewport().get_visible_rect().size.y * SHEET_RATIO


func _set_slide(v: float) -> void:
	_sheet.offset_top = v
	_sheet.offset_bottom = v


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	_selected = GameState.current_system
	_refresh()
	Sfx.play("equip", -9.0, 1.15)
	var h := _sheet_height()
	_set_slide(h)
	var tw := create_tween()
	tw.tween_method(_set_slide, h, 0.0, SLIDE_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func close_panel() -> void:
	if not is_open:
		return
	is_open = false
	Sfx.play("equip", -13.0, 0.9)
	var tw := create_tween()
	tw.tween_method(_set_slide, 0.0, _sheet_height(), SLIDE_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(func() -> void: visible = false)


func _on_recall() -> void:
	close_panel()
	recall_requested.emit()


func _refresh_recall() -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main == null or not main.has_method("deep_depth"):
		_recall_button.visible = false
		return
	var depth := float(main.deep_depth())
	_recall_button.visible = depth > 0.0
	if not _recall_button.visible:
		return
	_recall_button.text = "RETURN TO SYSTEM  (%du OUT)" % int(round(depth))
	# Free, and it says so. The emergency warp already does this involuntarily
	# when the hull fails, so a fee would be a tax on doing it on purpose.
	_recall_button.disabled = not bool(main.can_recall())


func _on_travel() -> void:
	if _selected == "" or _selected == GameState.current_system:
		return
	if not GameState.is_system_unlocked(_selected):
		Sfx.play("hit", -10.0, 0.7)
		return
	var target := _selected
	close_panel()
	travel_requested.emit(target)


func _refresh() -> void:
	_map.queue_redraw()
	_refresh_recall()
	if _selected == "":
		return
	var def := SystemDB.get_system(_selected)
	var unlocked := GameState.is_system_unlocked(_selected)
	_title.text = SystemDB.display_name(_selected)

	if not unlocked:
		_detail.text = SystemDB.unlock_hint(_selected)
		_travel_button.text = "UNCHARTED"
		_travel_button.disabled = true
	elif _selected == GameState.current_system:
		_detail.text = "Current position.  Threat ×%.1f   Salvage ×%.2f" % [
			float(def.get("difficulty", 1.0)), float(def.get("loot_mult", 1.0))]
		_travel_button.text = "YOU ARE HERE"
		_travel_button.disabled = true
	else:
		_detail.text = "Threat ×%.1f   Salvage ×%.2f" % [
			float(def.get("difficulty", 1.0)), float(def.get("loot_mult", 1.0))]
		_travel_button.text = "WARP TO %s" % String(def.get("name", _selected))
		_travel_button.disabled = false
