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
var _plot: Control
var _plot_note: Label
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

	# v16. THE SURVEY PLOT. Everything the dossier knows about this system's
	# engine, drawn as the picture it actually is: an annulus you were told about
	# for free, the cones you have paid for, and the circle where they agree.
	#
	# It lives here rather than on the map above because it is a DIFFERENT SPACE.
	# The map is the chart — systems and lanes, tens of units apart. This is one
	# system's deep, thousands of units across, and overlaying the two would put
	# a 1,400-unit search circle on top of a 40-unit system node.
	_plot = Control.new()
	_plot.custom_minimum_size = Vector2(0, 150)
	_plot.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_plot.draw.connect(_draw_plot)
	col.add_child(_plot)

	_plot_note = Label.new()
	_plot_note.add_theme_font_size_override("font_size", 10)
	_plot_note.add_theme_color_override("font_color", Palette.AMBER_DIM)
	_plot_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(_plot_note)

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


func _hunt_is_live(id: String) -> bool:
	# A plot is worth drawing only for a system with an engine still in it that
	# you have actually heard of. An uncharted system's dossier is not empty —
	# it is none of your business yet.
	if id == "" or not SystemDB.exists(id):
		return false
	if (SystemDB.get_system(id).get("apex", {}) as Dictionary).is_empty():
		return false
	return GameState.is_system_charted(id) and not GameState.has_killed_apex(id)


func _refresh_plot() -> void:
	var live := _hunt_is_live(_selected)
	_plot.visible = live
	_plot_note.visible = live
	if not live:
		return
	_plot.queue_redraw()
	var est: Dictionary = Hunt.estimate(_selected)
	var n := GameState.apex_hint_count(_selected)
	var engine := String((SystemDB.get_system(_selected).get("apex", {}) as Dictionary)
		.get("name", "THE ENGINE"))
	if n == 0:
		_plot_note.text = "%s — no intel. It is transmitting from somewhere in the shaded band." % engine
	else:
		_plot_note.text = "%s — %d reading%s, search area ±%du." % [
			engine, n, "" if n == 1 else "s", int(round(float(est["radius"])))]


func _draw_plot() -> void:
	# A TOP-DOWN PICTURE OF ONE SYSTEM'S DEEP, drawn in the same orientation the
	# radar and the world use (world +x right, world +z down), so a cone that
	# points down-left here points down-left when you fly it.
	if not _hunt_is_live(_selected):
		return
	var s := SystemDB.get_system(_selected)
	var bounds := float(s.get("bounds", 40.0))
	var lair: Dictionary = (s.get("apex", {}) as Dictionary).get("lair", {})
	var band: Array = lair.get("depth", [200.0, 300.0])
	var r_min := bounds + float(band[0])
	var r_max := bounds + float(band[1])

	var size := _plot.size
	var mid := size * 0.5
	# Scaled off the band's OUTER edge, so the whole searchable region is always
	# on screen whatever the system — pyx01's band is 340u out and pyx03's is
	# 1,450, and a fixed scale would render one of them as a dot.
	var scale := (minf(size.x, size.y) * 0.5 - 6.0) / maxf(r_max, 1.0)
	var to_plot := func(w: Vector3) -> Vector2:
		return mid + Vector2(w.x, w.z) * scale

	# 1. The charted volume you started from, for scale.
	_plot.draw_arc(mid, bounds * scale, 0.0, TAU, 48,
		Color(Palette.TEAL.r, Palette.TEAL.g, Palette.TEAL.b, 0.35), 1.0, true)

	# 1b. WHICH WAY IS WHICH. The orientation contract at the top of this
	#     function is what makes a cone drawn here flyable -- but until the
	#     cockpit grew a HDG readout the reader had to take it on trust, and a
	#     rumour naming a quarter of the sky had nothing on this plot to point
	#     at. The four letters come from DeepSpace.QUADRANTS through
	#     quadrant_of, so the plot, the rumour and the readout cannot drift
	#     apart -- and the unit vectors below are the same ones quadrant_of
	#     classifies, rather than a table of letters typed out here.
	var font := ThemeDB.fallback_font
	if font != null:
		var edge := minf(size.x, size.y) * 0.5 - 5.0
		for dir_v in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]:
			var d: Vector2 = dir_v
			var word := DeepSpace.quadrant_of(Vector3(d.x, 0.0, d.y))
			_plot.draw_string(font, mid + d * edge - Vector2(3.0, -3.0),
				word.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SIZE_FINE,
				Color(Palette.TEAL.r, Palette.TEAL.g, Palette.TEAL.b, 0.55))

	# 2. The authored band — the free information, and the clamp every estimate
	#    lives inside. Drawn as a thick ring rather than two thin circles so it
	#    reads as an AREA to search, not as two boundaries.
	var band_col := Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.13)
	_plot.draw_arc(mid, (r_min + r_max) * 0.5 * scale, 0.0, TAU, 64,
		band_col, maxf((r_max - r_min) * scale, 1.0), true)
	_plot.draw_arc(mid, r_min * scale, 0.0, TAU, 64,
		Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.30), 1.0, true)
	_plot.draw_arc(mid, r_max * scale, 0.0, TAU, 64,
		Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.30), 1.0, true)

	# 3. Every reading on file. A bearing draws its cone from where the
	#    instrument stood; a rumour shades its quadrant. Both are drawn out to
	#    the band's edge, because that is as far as either can claim.
	for h_v in GameState.apex_hints(_selected):
		var h: Dictionary = h_v
		if String(h.get("kind", "")) == "ring":
			var q := String(h.get("quadrant", ""))
			var q_from := -PI * 0.25
			if q == "SOUTH":
				q_from = PI * 0.25
			elif q == "WEST":
				q_from = PI * 0.75
			elif q == "NORTH":
				q_from = PI * 1.25
			_plot.draw_arc(mid, (r_min + r_max) * 0.5 * scale, q_from, q_from + PI * 0.5, 24,
				Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.22),
				maxf((r_max - r_min) * scale, 1.0), true)
			continue
		var origin := to_plot.call(Vector3(float(h.get("ox", 0.0)), 0.0, float(h.get("oz", 0.0)))) as Vector2
		var bearing := deg_to_rad(float(h.get("bearing", 0.0)))
		var err := deg_to_rad(float(h.get("err", 0.0)))
		# The two edges of the cone. Length is generous on purpose — a cone is a
		# direction, not a distance, and stopping it short would imply a range
		# the reading never claimed.
		var reach := (r_max + bounds) * 2.0 * scale
		var edge_col := Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.33)
		_plot.draw_line(origin, origin + Vector2(cos(bearing - err), sin(bearing - err)) * reach,
			edge_col, 1.0, true)
		_plot.draw_line(origin, origin + Vector2(cos(bearing + err), sin(bearing + err)) * reach,
			edge_col, 1.0, true)
		_plot.draw_circle(origin, 2.0, Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.5))

	# 4. And where they agree. Drawn LAST so it sits on top of its own evidence,
	#    and only once there is evidence — a circle covering the whole band on an
	#    empty dossier would read as a result rather than as the absence of one.
	if GameState.apex_hint_count(_selected) > 0:
		var est: Dictionary = Hunt.estimate(_selected)
		var c := to_plot.call(est["center"] as Vector3) as Vector2
		var rad := maxf(float(est["radius"]) * scale, 2.0)
		_plot.draw_circle(c, rad, Color(Palette.TEAL.r, Palette.TEAL.g, Palette.TEAL.b, 0.16))
		_plot.draw_arc(c, rad, 0.0, TAU, 40, Palette.TEAL, 1.5, true)
		_plot.draw_circle(c, 2.5, Palette.TEAL)

	# v20. The player's beacons, as dots in the livery accent — the plot's one
	# player-authored layer. Drawn last so a beacon dropped inside the estimate
	# ring stays visible on top of its shading. (The plot itself only renders
	# during a live hunt — its early return above — so beacons share that
	# window; a post-kill beacon map is stage-6 territory if it is anything.)
	var accent := Palette.livery_accent(int(GameState.livery.get("accent", 0)))
	for be_v in GameState.beacons_in(_selected):
		var be: Dictionary = be_v
		var bp := to_plot.call(Vector3(float(be["x"]), 0.0, float(be["z"]))) as Vector2
		_plot.draw_circle(bp, 3.0, accent)
		_plot.draw_arc(bp, 5.0, 0.0, TAU, 12, Color(accent.r, accent.g, accent.b, 0.5), 1.0, true)


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
			var lit := GameState.is_lane_open(id) and GameState.is_lane_open(other)
			var col := Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.45 if lit else 0.13)
			_map.draw_line(_node_pos(id), _node_pos(other), col, 1.5, true)

	for id_v in SystemDB.ids():
		var id := str(id_v)
		var pos := _node_pos(id)
		# THREE states since v15, not two. A charted-but-jammed system is KNOWN —
		# it has a name, a place on the chart and a reason you cannot fly there —
		# and drawing it identically to a system nobody has heard of would throw
		# away the thing the derelict breach just earned.
		var charted := GameState.is_system_charted(id)
		var unlocked := GameState.is_lane_open(id)
		var jammed := charted and not unlocked
		var is_current := id == current
		var is_sel := id == _selected

		if is_current:
			_map.draw_arc(pos, NODE_RADIUS + 7.0, 0.0, TAU, 32,
				Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.5), 1.5, true)
		if is_sel:
			_map.draw_arc(pos, NODE_RADIUS + 3.0, 0.0, TAU, 32, Palette.TEAL, 1.5, true)

		var fill := Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.9) if is_current \
			else (Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.32) if unlocked \
			else (Color(Palette.THREAT.r, Palette.THREAT.g, Palette.THREAT.b, 0.22) if jammed \
			else Color(0.16, 0.16, 0.2, 0.9)))
		_map.draw_circle(pos, NODE_RADIUS, fill)
		_map.draw_arc(pos, NODE_RADIUS, 0.0, TAU, 32,
			Palette.AMBER if unlocked else (Palette.THREAT if jammed else Color(0.4, 0.35, 0.4)),
			1.5, true)

		if jammed:
			# The jam, not a padlock: a broken ring around the node, the same
			# visual grammar the shattered survey pylon uses out in the Shoals.
			# It reads as interference rather than as bureaucracy.
			for arc_i in range(3):
				var a0: float = float(arc_i) * TAU / 3.0 + 0.22
				_map.draw_arc(pos, NODE_RADIUS + 5.0, a0, a0 + TAU / 3.0 - 0.44, 12,
					Color(Palette.THREAT.r, Palette.THREAT.g, Palette.THREAT.b, 0.75), 1.5, true)
		elif not unlocked:
			# A small lock glyph: a bar over a box.
			_map.draw_rect(Rect2(pos + Vector2(-4, -1), Vector2(8, 8)), Color(0.65, 0.6, 0.65))
			_map.draw_arc(pos + Vector2(0, -1), 4.0, PI, TAU, 10, Color(0.65, 0.6, 0.65), 1.5, true)

		var font := ThemeDB.fallback_font
		# A jammed system is NAMED. That is what the breach bought.
		var label := String(SystemDB.get_system(id).get("name", id))
		var w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, 11).x
		_map.draw_string(font, pos + Vector2(-w * 0.5, NODE_RADIUS + 15.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, 11,
			Palette.AMBER if unlocked else (Color(Palette.THREAT.r, Palette.THREAT.g,
				Palette.THREAT.b, 0.85) if jammed else Color(0.5, 0.45, 0.5)))


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
	if not GameState.is_lane_open(_selected):
		Sfx.play("hit", -10.0, 0.7)
		return
	var target := _selected
	close_panel()
	travel_requested.emit(target)


func _refresh() -> void:
	_map.queue_redraw()
	_refresh_plot()
	_refresh_recall()
	if _selected == "":
		return
	var def := SystemDB.get_system(_selected)
	var unlocked := GameState.is_lane_open(_selected)
	var charted := GameState.is_system_charted(_selected)
	_title.text = SystemDB.display_name(_selected)

	if not unlocked:
		_detail.text = SystemDB.unlock_hint(_selected)
		# The button says which of the two things is missing. "UNCHARTED" on a
		# system you have already charted would read as the game forgetting.
		_travel_button.text = "LANE JAMMED" if charted else "UNCHARTED"
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
