class_name ChartPanel
extends CanvasLayer
# The star chart: a bottom sheet showing systems as nodes on bearing lines.
# Locked systems show what you must breach to chart them, so progression is
# always legible from inside the fiction.

signal travel_requested(id: String)
signal recall_requested
signal colony_jump_requested(key: String)
signal course_requested(x: float, z: float, label: String)
signal beacon_jump_requested(x: float, z: float, depth: float, label: String)

const SHEET_RATIO := 0.55
const SLIDE_TIME := 0.28
const NODE_RADIUS := 17.0

# v21. THE PLOT'S OWN GEOMETRY. 180 rather than 150 because the plot now carries
# band rings, a legend and a scale bar under the picture; the arithmetic that
# says this still fits the 0.55 sheet at 720x1280 is asserted in PLOTTEST rather
# than trusted, because everything else in this column is a minimum too and the
# sheet cannot grow.
const PLOT_HEIGHT := 180.0
const PLOT_PAD := 10.0
# The bottom strip the scale bar and the legend own. Reserved out of the
# picture's height rather than drawn over it -- at this size the plot is barely
# taller than it is deep, so a legend laid on top would sit across the outer
# band rings, which are exactly the ones a reader is squinting at.
const FURNITURE_H := 26.0

# The column's own dimensions, named because PLOTTEST budgets against them and a
# budget built from retyped literals is a budget that goes stale silently -- it
# did, by 28px, in the direction that made the check pass. Every one of these is
# read by _build below; nothing may hard-code them in two places.
const COL_SEP := 8.0
const MAP_MIN_H := 126.0
const COLONY_ROW_H := 42.0
const COLONY_ROW_SEP := 4.0
# What the sheet can spare for rows, and therefore what the scroll viewport is.
# Two rows plus their separation. The container scrolls past this rather than
# growing, so this number is the column's cost no matter how many beacons and
# colonies the player has.
const ROWS_VIEWPORT_H := COLONY_ROW_H * 2.0 + COLONY_ROW_SEP
# Breathing room around whatever the fit radius turned out to be, so the
# outermost thing is INSIDE the rect rather than drawn on its edge.
const FIT_MARGIN := 1.10
const ZOOM_MIN := 0.75
const ZOOM_MAX := 8.0
const ZOOM_STEP := 1.25

var is_open := false

# Pan and zoom sit on top of the fit, never replace it: at _zoom 1.0 and no pan
# the plot shows everything fit_radius_for found, so the gesture is always a
# refinement of a correct default rather than the only way to see the picture.
var _zoom := 1.0
var _pan := Vector2.ZERO
var _drag_id := -1
var _drag_last := Vector2.ZERO
var _touches := {}
var _pinch_ref := 0.0

var _sheet: Panel
# Kept for _apply_layout: the sheet's height decision reads the column's real
# minimums, and the margin container is where they accumulate.
var _margin: MarginContainer
var _map: Control
var _title: Label
var _detail: Label
var _plot: Control
var _plot_note: Label
var _colony_rows: VBoxContainer
var _rows_scroll: ScrollContainer
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
	# v22 (88). THE SHEET GROWS UPWARD WHEN THE WINDOW IS SHORT. SHEET_RATIO is
	# a PORTRAIT design constant: 55% of 1280 holds this column's ~680px of
	# minimums with room to spare. On a wide desktop window 55% of ~1090 does
	# not -- and a VBoxContainer does not shrink children below their minimums,
	# so the overflow came out of the BOTTOM: the WARP button, which made the
	# chart read as "cannot travel" on any landscape window while the top 45%
	# of the screen sat empty. The playtest that found it reported exactly
	# that, as two separate symptoms.
	#
	# The ratio stays the FLOOR, so portrait is untouched byte for byte; the
	# sheet takes more of a short window only when the column's own minimums
	# demand it, capped at 95% so the world never fully disappears.
	if _margin != null:
		var vh := _sheet.get_viewport_rect().size.y
		var frac := clampf(_margin.get_combined_minimum_size().y / maxf(vh, 1.0),
			SHEET_RATIO, 0.95)
		_sheet.anchor_top = 1.0 - frac


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

	_margin = MarginContainer.new()
	var margin := _margin
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_sheet.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", int(COL_SEP))
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
	# 126, down from 170 in two steps -- the plot took 20 and the scrolling row
	# viewport took the rest. This column's
	# minimums have to fit the 0.55 sheet WITH two colony rows in it, and the map
	# is the one child here that expands -- it takes every spare pixel whenever
	# there is one, so lowering its FLOOR costs nothing except in the crowded case
	# this is about. The plot cannot do the same: it is the dense picture, and a
	# ring diagram that shrinks is a ring diagram you cannot read.
	#
	# The margin this leaves is ~26px, and it is deliberately not smaller. Four
	# rows in the budget -- header, title, detail, note -- have no
	# custom_minimum_size and are font-derived, so the sum is a MODEL rather
	# than a measurement. A spare of 2px would be a coincidence dressed up as a
	# design, which this file has already shipped once.
	_map.custom_minimum_size = Vector2(0, MAP_MIN_H)
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
	#
	# v21. IT TAKES INPUT NOW. MOUSE_FILTER_STOP rather than IGNORE, because the
	# plot has gestures of its own -- and because IGNORE would let a drag fall
	# through to the sheet behind it. The gesture logic is local to this Control
	# (gui_input, not _unhandled_input) so the world's tap/hold grammar is
	# untouched: a drag in here is a drag in here, and nothing outside the sheet
	# ever sees it.
	_plot = Control.new()
	_plot.custom_minimum_size = Vector2(0, PLOT_HEIGHT)
	_plot.mouse_filter = Control.MOUSE_FILTER_STOP
	# CLIPPED, AND NOT OPTIONALLY. Godot does NOT scissor a CanvasItem's own draw
	# calls to its rect -- `clip_contents` defaults to false and nothing else in
	# this project sets it, so every arc this Control draws past its own edge
	# renders straight over its siblings. The band rings make that unmissable: at
	# 720x1280 in pyx01 the band-4 ring is 183px in a rect 180px tall, so its top
	# arc lands across _detail, _title and the bottom of the system map, in the
	# DEFAULT view of the starting system.
	#
	# The culls below are visibility heuristics -- "is this ring worth drawing at
	# all" -- and were doing double duty as containment, which they cannot do:
	# _pan is unbounded and _zoom reaches 8, so any layer can be pushed
	# arbitrarily far outside the rect. Containment is this one line.
	_plot.clip_contents = true
	_plot.draw.connect(_draw_plot)
	_plot.gui_input.connect(_on_plot_input)
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
	_recall_button.custom_minimum_size = Vector2(0, COLONY_ROW_H)
	_recall_button.add_theme_font_size_override("font_size", 14)
	_recall_button.add_theme_color_override("font_color", Palette.TEAL)
	_recall_button.visible = false
	_recall_button.pressed.connect(_on_recall)
	col.add_child(_recall_button)

	# v20 HUNT STAGE 6. One row per founded colony in the selected system, between
	# the recall button and WARP: recall is "get me home", a colony jump is "get
	# me back out there", and travel is "another system" — nearest-first by how
	# urgent it is, which is the argument the recall button's own placement note
	# makes. Retained as a field because rows come and go as colonies are founded;
	# `col` above is a local and cannot be rebuilt into.
	#
	# v21. IT SCROLLS NOW, and that is a correctness fix rather than a nicety.
	# This container used to hold colonies only -- three to five at the very
	# most -- and the sheet budget was written for two. Beacon rows moved in
	# beside them and the stock is EIGHT, so the column could be asked for ten
	# rows: 364px of content in 90px of spare, pushing WARP off the bottom of
	# the screen. That is the exact failure THE PLOT STILL FITS ITS SHEET was
	# written to refuse, arriving a second time through a different door.
	#
	# A ScrollContainer with a fixed minimum is what makes the budget TRUE
	# rather than merely large enough today: the column's height stops depending
	# on how many rows exist at all, so no future row type can overflow it and
	# nothing has to be silently truncated to fit. Two rows' worth is the
	# viewport, which is what the sheet can actually spare.
	_rows_scroll = ScrollContainer.new()
	_rows_scroll.custom_minimum_size = Vector2(0, ROWS_VIEWPORT_H)
	_rows_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(_rows_scroll)

	_colony_rows = VBoxContainer.new()
	_colony_rows.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_colony_rows.add_theme_constant_override("separation", int(COLONY_ROW_SEP))
	_rows_scroll.add_child(_colony_rows)

	_travel_button = Button.new()
	_travel_button.custom_minimum_size = Vector2(0, COLONY_ROW_H)
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


func _plot_is_useful(id: String) -> bool:
	# v21. THE PLOT IS NO LONGER A HUNT INSTRUMENT. It was drawn only during a
	# live apex hunt -- so a player who had killed the engine, or never heard of
	# one, opened the chart and found the deep represented by nothing at all.
	# That is most of what "extremely hard to understand" meant: the picture was
	# absent far more often than it was confusing.
	#
	# The bar is now CHARTED, which is the same bar the rest of this sheet uses:
	# an uncharted system's dossier is not empty, it is none of your business
	# yet. Everything the hunt used to gate -- the band, the cones, the estimate
	# -- still gates on _hunt_is_live inside the draw. Only the CANVAS is
	# unconditional.
	if id == "" or not SystemDB.exists(id):
		return false
	return GameState.is_system_charted(id)


func fit_radius_for(id: String, ship := Vector2.ZERO) -> float:
	# THE WORLD RADIUS THE PLOT MUST COVER, and the reason beacons stopped being
	# drawn outside the rect. The old scale came off the apex band's outer edge
	# (`bounds + band[1]`), which is not a bound on anything the player owns: a
	# beacon dropped past it -- in pyx01 that is only 340u out -- projected past
	# the plot's corner. NOT into nothing: until clip_contents was set in _build
	# it was drawn over whatever sibling occupied that pixel, so the symptom was a
	# mark in the wrong place rather than a missing one.
	#
	# SHIP IS AN ARGUMENT, not a scene lookup, for the reason drop_beacon takes
	# depth as one: this has to be checkable without a world, and a function that
	# reaches into the tree for half its answer cannot be handed a case. Callers
	# with a ship pass it; callers without pass nothing and get the same answer
	# they would have got with the ship at the origin.
	#
	# Survey coverage is DRAWN but deliberately not FITTED TO, and the reason
	# changed in v21 so it is restated: coverage now persists, so the old
	# argument (it vanishes on warp, the scale would jump) is gone. What stands
	# is this: the fit frames what you can ACT on now -- your ship, your
	# beacons, your colonies, the live hunt -- and coverage is history. One
	# far-out cell surveyed months ago would otherwise zoom every future look
	# at this system out to it, permanently, shrinking the working picture to
	# pay for a memory. The chart pans and zooms; history is reachable, not
	# resident.
	if id == "" or not SystemDB.exists(id):
		return 1.0
	var s := SystemDB.get_system(id)
	var bounds := float(s.get("bounds", 40.0))
	var r := bounds
	for be_v in GameState.beacons_in(id):
		var be: Dictionary = be_v
		r = maxf(r, Vector2(float(be["x"]), float(be["z"])).length())
	for co_v in GameState.colonies_in(id):
		var co: Dictionary = co_v
		r = maxf(r, Vector2(float(co["x"]), float(co["z"])).length())
	if _hunt_is_live(id):
		var lair: Dictionary = (s.get("apex", {}) as Dictionary).get("lair", {})
		var band: Array = lair.get("depth", [200.0, 300.0])
		r = maxf(r, bounds + float(band[1]))
	r = maxf(r, ship.length())
	return maxf(r * FIT_MARGIN, 1.0)


static func band_ring_radius(bounds: float, band: int) -> float:
	# WHERE BAND `band` BEGINS, as a radius from the system origin.
	#
	# BAND_EDGES IS OFF BY ONE FROM THE BAND NUMBER, and this function exists as
	# much to hold that fact in one place as to add `bounds`. `band_of` returns
	# `i + 1` for the largest edge it clears, so BAND_EDGES[i] is where band
	# i+1 STARTS -- BAND_EDGES[4] is 2600, which is the floor of band 5, THE
	# FATHOMS. Indexing this array with a band number gives you the ring for the
	# band below the one you asked for, which is a mistake that draws a perfectly
	# convincing picture: the rings are still evenly nested and still look right.
	#
	# The other half, since depth_at subtracts bounds: BAND_EDGES are DEPTHS, so
	# a ring sits at bounds + edge.
	var i := clampi(band - 1, 0, DeepSpace.BAND_EDGES.size() - 1)
	return bounds + float(DeepSpace.BAND_EDGES[i])


func legend_words(live: bool, has_ship: bool) -> PackedStringArray:
	# WHICH LAYERS ARE ON SCREEN, in draw order. A legend entry for a layer the
	# picture is not drawing is a promise it does not keep, so each one is
	# conditioned on the same thing its layer is -- which is why this is a
	# function and not a literal: the conditions have to stay next to each other
	# to stay in step.
	var out := PackedStringArray()
	if has_ship and _selected == GameState.current_system:
		out.append("YOU")
	if not GameState.beacons_in(_selected).is_empty():
		out.append("BEACON")
	if not GameState.colonies_in(_selected).is_empty():
		out.append("COLONY")
	if live and GameState.apex_hint_count(_selected) > 0:
		out.append("ESTIMATE")
	for seen_v in GameState.structures_seen_in(_selected):
		if not GameState.is_colony_claimed(String((seen_v as Dictionary)["key"])):
			out.append("SIGHTED")
			break
	var pref := _selected + ":"
	for cov_v in GameState.survey_coverage:
		if String(cov_v).begins_with(pref):
			out.append("SURVEYED")
			break
	return out


func legend_layout(words: PackedStringArray) -> PackedFloat32Array:
	# THE X OF EACH LEGEND ENTRY. Pure and exposed so PLOTTEST can assert the
	# positions strictly advance -- see the note at the call site: the first
	# version advanced a cursor captured by a lambda, which GDScript copies by
	# value, so every entry landed on the same x. Nothing in a diff or an
	# assertion could see it, because the only symptom is what the pixels look
	# like. A layout that is a list of numbers can at least be checked.
	var font := ThemeDB.fallback_font
	var out := PackedFloat32Array()
	var lx := 6.0
	for w in words:
		out.append(lx)
		# 13px of swatch and gap, plus the word. The swatches are all drawn
		# inside that 13 (widest is the 7px colony square at +1.5 stroke).
		var adv := 13.0
		if font != null:
			adv += font.get_string_size(w, HORIZONTAL_ALIGNMENT_LEFT, -1,
				UIKit.SIZE_FINE).x + 6.0
		else:
			adv += 6.0 * w.length()
		lx += adv
	return out


func ring_label(id: String, band: int) -> String:
	# THE EXACT STRING DRAWN BESIDE A BAND RING, exposed so the assertion can
	# read what the plot draws rather than rebuilding it from the same two
	# accessors. A test that composed band_glyph and band_name_of itself would
	# agree with a draw that had gone back to keying one of them off the edge
	# index -- which is the bug that shipped here once already, and it produces a
	# picture that looks entirely correct because the rings are still nested.
	#
	# Both halves keyed by BAND NUMBER. Nothing in this function may take an
	# index into BAND_EDGES.
	return "%s %s" % [Palette.band_glyph(band),
		SystemDB.band_name_of(id, band, DeepSpace.BAND_NAMES[band])]


static func scale_bar_units(want: float) -> float:
	# The largest 1/2/5 x 10^n that fits in `want` world units. A scale bar
	# reading "1,000u" is one a person can hold; one reading "1,347u" is one
	# they have to do arithmetic against, which defeats the point of drawing it.
	#
	# THE 10.0 IN THAT LIST IS NOT DECORATION, and this is the one thing to know
	# before touching this function. `log(1000.0) / log(10.0)` is
	# 2.9999999999999996 in doubles, so `floor` returns 2 and `mag` comes out an
	# order of magnitude LOW at every exact power of ten. The step list carries a
	# 10.0 precisely so an underestimated magnitude is recovered: 100 * 10 = 1000
	# still fits and still wins.
	#
	# Do not "fix" this by nudging the log with an epsilon. Underestimating is
	# harmless because the loop only ever accepts a step that FITS; overestimating
	# is not, because `units` starts at `mag` and would return a bar wider than
	# the space it was asked for when no step fits at all. Floor's bias is the
	# safe direction, and the 10.0 makes it free.
	var mag := pow(10.0, floor(log(maxf(want, 1.0)) / log(10.0)))
	var units := mag
	for step in [1.0, 2.0, 5.0, 10.0]:
		if mag * step <= want:
			units = mag * step
	return units


func _ship_flat() -> Vector2:
	# Vector2.ZERO when there is no ship, no world, or you are looking at a
	# system you are not standing in -- which is the same answer as "at the
	# origin" for fitting purposes and costs nothing, since bounds already
	# covers the origin.
	if _selected != GameState.current_system:
		return Vector2.ZERO
	var p := get_tree().get_first_node_in_group("player") as Node3D
	if p == null:
		return Vector2.ZERO
	return Vector2(p.global_position.x, p.global_position.z)


func _plot_geometry() -> Dictionary:
	# One place the scale is derived, so the drawing, the gestures and the
	# scale bar cannot disagree about how big a unit is.
	var size := _plot.size
	var fit := fit_radius_for(_selected, _ship_flat())
	var usable := maxf(size.y - FURNITURE_H, 20.0)
	var home := plot_home()
	var base := (minf(size.x, usable) * 0.5 - PLOT_PAD) / fit
	# `home` is where the origin sits with no pan -- the compass letters and the
	# furniture pin to it, while `mid` is what the panned layers draw against.
	return {"mid": home + _pan, "home": home, "usable": usable,
		"scale": base * _zoom, "fit": fit}


func _refresh_plot() -> void:
	var useful := _plot_is_useful(_selected)
	_plot.visible = useful
	# The note is still the HUNT's caption and stays on the hunt's gate. With
	# the plot always drawn, a "no intel" line under a post-kill system would be
	# answering a question nobody asked.
	var live := _hunt_is_live(_selected)
	_plot_note.visible = live
	if not useful:
		return
	_plot.queue_redraw()
	if not live:
		return
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
	if not _plot_is_useful(_selected):
		return
	var s := SystemDB.get_system(_selected)
	var bounds := float(s.get("bounds", 40.0))
	var live := _hunt_is_live(_selected)
	var lair: Dictionary = (s.get("apex", {}) as Dictionary).get("lair", {})
	var band: Array = lair.get("depth", [200.0, 300.0])
	var r_min := bounds + float(band[0])
	var r_max := bounds + float(band[1])

	var geo := _plot_geometry()
	var size := _plot.size
	var mid: Vector2 = geo["mid"]
	var scale: float = geo["scale"]
	var to_plot := func(w: Vector3) -> Vector2:
		return mid + Vector2(w.x, w.z) * scale
	var font := ThemeDB.fallback_font

	# 0. THE DEPTH BANDS, drawn first and underneath everything, because they are
	#    the thing every other layer is being read AGAINST. This is the answer to
	#    "the plot has no scale": the reader now sees the same five names the
	#    cockpit band line and the manual use, in the same order, at the radius
	#    they actually begin -- so "my beacon is in THE REACHES" is a thing the
	#    picture says rather than something you work out.
	#
	#    ITERATED BY BAND NUMBER, NOT BY EDGE INDEX, and everything below is
	#    keyed off that one number -- the radius through band_ring_radius, the
	#    name through band_name_of, the glyph and the colour through `b`. The
	#    first version walked BAND_EDGES and used the edge index for the glyph
	#    while the name came from the depth, so every ring carried the right word
	#    beside the wrong mark. §30's whole point is that the glyph is the
	#    channel that survives a colour-vision mode, so a glyph that disagrees
	#    with the word is worse than no glyph: it is confidently wrong in the
	#    mode where it is the only thing left.
	#
	#    band_name_of rather than band_name_in for the same reason: the depth
	#    round-trip is what let the two drift, and band 1's edge is depth 0,
	#    which band_of maps to CHARTED rather than THE SHOALS.
	for b in range(1, DeepSpace.BAND_NAMES.size()):
		var rr := band_ring_radius(bounds, b) * scale
		if rr < 6.0 or rr > minf(size.x, float(geo["usable"])) * 1.4:
			continue
		var bc := Palette.band_color(b)
		_plot.draw_arc(mid, rr, 0.0, TAU, 64,
			Color(bc.r, bc.g, bc.b, 0.30), 1.0, true)
		if font != null:
			# On the ring, upward from centre, so the labels stack in one column
			# rather than scattering -- and clipped to the rect, because a label
			# for a ring the pan pushed off screen is noise.
			var lp := mid + Vector2(4.0, -rr - 3.0)
			if lp.y > 8.0 and lp.y < float(geo["usable"]) and lp.x < size.x - 40.0:
				_plot.draw_string(font, lp, ring_label(_selected, b),
					HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SIZE_FINE,
					Color(bc.r, bc.g, bc.b, 0.75))

	# 0b. WHERE YOU HAVE WORKED. Every persisted survey cell in this system
	#     (v21, 80), drawn as a faint FILLED square the size of the cell itself
	#     -- world-sized, scaling with zoom, which is what separates it by SHAPE
	#     from the colony marker (a small OUTLINED square of fixed screen size)
	#     under 30's rule. Faint on purpose: this layer is the paper's texture,
	#     not a marker, and it must never compete with the things drawn on it.
	#     Under everything so a beacon dropped in a surveyed cell stays visible.
	var cov_prefix := _selected + ":"
	var cell_px := DeepSpace.CELL * scale
	for cov_v in GameState.survey_coverage:
		var cov := String(cov_v)
		if not cov.begins_with(cov_prefix):
			continue
		var cbits := cov.split(":")
		if cbits.size() != 3:
			continue
		var ccx := int(cbits[1])
		var ccz := int(cbits[2])
		var cworld := DeepSpace.cell_centre(ccx, ccz)
		var centre := to_plot.call(cworld) as Vector2
		# Skip cells wholly outside the rect: with clip_contents on this is
		# purely a draw-call economy, but coverage is the one layer that can
		# legitimately hold hundreds of entries.
		if centre.x < -cell_px or centre.x > size.x + cell_px \
				or centre.y < -cell_px or centre.y > size.y + cell_px:
			continue
		var cband := DeepSpace.band_of(maxf(
			Vector2(cworld.x, cworld.z).length() - bounds, 0.0))
		var cc := Palette.band_color(cband)
		_plot.draw_rect(Rect2(centre - Vector2(cell_px, cell_px) * 0.5,
			Vector2(cell_px, cell_px)), Color(cc.r, cc.g, cc.b, 0.10), true)

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
	if font != null:
		# Pinned to the RECT, not to `mid`, so panning does not carry the compass
		# off screen: which way is north does not change when you drag the map.
		var half: Vector2 = geo["home"]
		var edge := minf(size.x, float(geo["usable"])) * 0.5 - 5.0
		for dir_v in [Vector2(1, 0), Vector2(0, 1), Vector2(-1, 0), Vector2(0, -1)]:
			var d: Vector2 = dir_v
			var word := DeepSpace.quadrant_of(Vector3(d.x, 0.0, d.y))
			_plot.draw_string(font, half + d * edge - Vector2(3.0, -3.0),
				word.substr(0, 1), HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SIZE_FINE,
				Color(Palette.TEAL.r, Palette.TEAL.g, Palette.TEAL.b, 0.55))

	# 2. The authored band — the free information, and the clamp every estimate
	#    lives inside. Drawn as a thick ring rather than two thin circles so it
	#    reads as an AREA to search, not as two boundaries.
	var band_col := Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.13)
	if live:
		_plot.draw_arc(mid, (r_min + r_max) * 0.5 * scale, 0.0, TAU, 64,
			band_col, maxf((r_max - r_min) * scale, 1.0), true)
		_plot.draw_arc(mid, r_min * scale, 0.0, TAU, 64,
			Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.30), 1.0, true)
		_plot.draw_arc(mid, r_max * scale, 0.0, TAU, 64,
			Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.30), 1.0, true)

	# 3. Every reading on file. A bearing draws its cone from where the
	#    instrument stood; a rumour shades its quadrant. Both are drawn out to
	#    the band's edge, because that is as far as either can claim.
	for h_v in (GameState.apex_hints(_selected) if live else []):
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
	if live and GameState.apex_hint_count(_selected) > 0:
		var est: Dictionary = Hunt.estimate(_selected)
		var c := to_plot.call(est["center"] as Vector3) as Vector2
		var rad := maxf(float(est["radius"]) * scale, 2.0)
		_plot.draw_circle(c, rad, Color(Palette.TEAL.r, Palette.TEAL.g, Palette.TEAL.b, 0.16))
		_plot.draw_arc(c, rad, 0.0, TAU, 40, Palette.TEAL, 1.5, true)
		_plot.draw_circle(c, 2.5, Palette.TEAL)

	# 5. THE PLACES YOU MADE. Colonies as squares, beacons as ringed dots, both
	#    in the livery accent because both are yours.
	#
	#    NO LONGER HUNT-GATED, which was the second half of the illegibility: a
	#    player who had killed the engine could drop eight beacons and never see
	#    one of them on the chart again. Shape carries the distinction between
	#    the two, not hue -- they share the accent deliberately, since "mine" is
	#    what the colour means here.
	var accent := Palette.livery_accent(int(GameState.livery.get("accent", 0)))

	# 5a. STRUCTURES YOU HAVE SEEN BUT NOT TAKEN (v22). A hollow DIAMOND, which
	#     is the same square the colony draws turned forty-five degrees -- the
	#     shape says "this kind of thing", the rotation says "not yours yet",
	#     and neither reading depends on colour (30). Drawn under the colonies
	#     so a claimed one covers its own sighting rather than fighting it.
	#
	#     POSITION COMES FROM THE GENERATOR, not from the store. hyper_positions
	#     is a pure function of (system, run_seed) and the sighting records only
	#     THAT you saw it, so there is no stored coordinate that could disagree
	#     with where the thing actually is.
	var spots: Array = SystemDB.hyper_positions(_selected, GameState.run_seed)
	for seen_v in GameState.structures_seen_in(_selected):
		var seen: Dictionary = seen_v
		var si := int(seen["index"])
		if si < 0 or si >= spots.size():
			continue
		if GameState.is_colony_claimed(String(seen["key"])):
			continue
		var sp3 := to_plot.call(spots[si] as Vector3) as Vector2
		var dim := Color(accent.r, accent.g, accent.b, 0.55)
		var diamond := PackedVector2Array([
			sp3 + Vector2(0.0, -5.5), sp3 + Vector2(5.5, 0.0),
			sp3 + Vector2(0.0, 5.5), sp3 + Vector2(-5.5, 0.0),
			sp3 + Vector2(0.0, -5.5)])
		_plot.draw_polyline(diamond, dim, 1.5, true)

	for co_v in GameState.colonies_in(_selected):
		var co: Dictionary = co_v
		var cp2 := to_plot.call(Vector3(float(co["x"]), 0.0, float(co["z"]))) as Vector2
		_plot.draw_rect(Rect2(cp2 - Vector2(4.0, 4.0), Vector2(8.0, 8.0)),
			Color(accent.r, accent.g, accent.b, 0.28), true)
		_plot.draw_rect(Rect2(cp2 - Vector2(4.0, 4.0), Vector2(8.0, 8.0)),
			accent, false, 1.5)
	for be_v in GameState.beacons_in(_selected):
		var be: Dictionary = be_v
		var bp := to_plot.call(Vector3(float(be["x"]), 0.0, float(be["z"]))) as Vector2
		_plot.draw_circle(bp, 3.0, accent)
		_plot.draw_arc(bp, 5.0, 0.0, TAU, 12, Color(accent.r, accent.g, accent.b, 0.5), 1.0, true)

	# 6. YOU. The single most-asked question of any map, and this one could not
	#    answer it -- nothing in this file referenced the player node at all.
	#    Drawn last so it is never buried, and as a TRIANGLE POINTING WHERE THE
	#    SHIP POINTS, so it carries heading as well as position: the plot is
	#    drawn in the world's own orientation, which is what makes a bearing read
	#    off it flyable, and a dot would throw that away.
	var me := get_tree().get_first_node_in_group("player") as Node3D
	if me != null and _selected == GameState.current_system:
		var mp := to_plot.call(me.global_position) as Vector2
		var fwd := -me.global_transform.basis.z
		var ang := atan2(fwd.z, fwd.x)
		var nose := mp + Vector2(cos(ang), sin(ang)) * 7.0
		var l := mp + Vector2(cos(ang + 2.5), sin(ang + 2.5)) * 5.5
		var r2 := mp + Vector2(cos(ang - 2.5), sin(ang - 2.5)) * 5.5
		_plot.draw_colored_polygon(PackedVector2Array([nose, l, r2]), Palette.GOLD)
		_plot.draw_arc(mp, 9.0, 0.0, TAU, 16,
			Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.45), 1.0, true)

	# 7. THE SCALE BAR, in screen space and pinned to the rect, because it
	#    measures the PLOT and not the world -- panning must not carry it off.
	#    A round number of units wide, chosen as the largest 1/2/5 x 10^n that
	#    still fits a quarter of the rect, so the label is always something a
	#    person can hold in their head.
	if font != null:
		var want := (size.x * 0.28) / maxf(scale, 0.0001)
		var units := scale_bar_units(want)
		var px := units * scale
		var y := size.y - 8.0
		var x0 := 6.0
		var bar_col := Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.65)
		_plot.draw_line(Vector2(x0, y), Vector2(x0 + px, y), bar_col, 1.5, true)
		_plot.draw_line(Vector2(x0, y - 3.0), Vector2(x0, y + 3.0), bar_col, 1.5, true)
		_plot.draw_line(Vector2(x0 + px, y - 3.0), Vector2(x0 + px, y + 3.0),
			bar_col, 1.5, true)
		_plot.draw_string(font, Vector2(x0 + px + 5.0, y + 3.0), "%du" % int(units),
			HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SIZE_FINE, bar_col)

		# 8. THE LEGEND. Every layer gets SHAPE + COLOUR + WORD, which is §30's
		#    redundancy rule applied to a picture rather than to a palette: the
		#    three marks differ by outline before they differ by hue, so the plot
		#    survives every colour-vision mode without a second palette. Drawn
		#    from the same primitives the layers above use, so a legend entry
		#    cannot come to disagree with the thing it labels.
		#
		#    Hunt entries appear only while the hunt does, for the same reason
		#    the note does: a legend for a layer that is not on screen is a
		#    promise the picture does not keep.
		#    A PLAIN LOOP, NOT A LAMBDA, and the reason is a language rule rather
		#    than a style preference: GDSCRIPT LAMBDAS CAPTURE LOCALS BY VALUE.
		#    This was written as a `swatch` closure that advanced a captured `lx`
		#    cursor, which cannot work -- the `lx += ...` mutates the lambda's own
		#    copy and the outer variable never moves, so every entry draws at the
		#    same x and the legend renders as one smear. It is invisible in a diff
		#    and no assertion can see a draw call, so the layout is computed by
		#    legend_layout and PLOTTEST checks that the positions actually advance.
		var ly := size.y - 22.0
		var words := legend_words(live, me != null)
		var xs := legend_layout(words)
		for i in words.size():
			var word := words[i]
			var lx := xs[i]
			var c := accent
			if word == "YOU":
				c = Palette.GOLD
				_plot.draw_colored_polygon(PackedVector2Array([
					Vector2(lx + 5.0, ly), Vector2(lx, ly - 3.5),
					Vector2(lx, ly + 3.5)]), c)
			elif word == "COLONY":
				_plot.draw_rect(Rect2(Vector2(lx, ly - 3.5), Vector2(7.0, 7.0)),
					c, false, 1.5)
			elif word == "BEACON":
				_plot.draw_circle(Vector2(lx + 3.5, ly), 2.5, c)
			elif word == "SIGHTED":
				_plot.draw_polyline(PackedVector2Array([
					Vector2(lx + 3.5, ly - 4.0), Vector2(lx + 7.5, ly),
					Vector2(lx + 3.5, ly + 4.0), Vector2(lx - 0.5, ly),
					Vector2(lx + 3.5, ly - 4.0)]),
					Color(c.r, c.g, c.b, 0.55), 1.5, true)
			elif word == "SURVEYED":
				c = Palette.band_color(2)
				_plot.draw_rect(Rect2(Vector2(lx, ly - 3.5), Vector2(7.0, 7.0)),
					Color(c.r, c.g, c.b, 0.35), true)
			else:
				c = Palette.TEAL
				_plot.draw_arc(Vector2(lx + 3.5, ly), 3.5, 0.0, TAU, 12, c, 1.0, true)
			_plot.draw_string(font, Vector2(lx + 11.0, ly + 3.5), word,
				HORIZONTAL_ALIGNMENT_LEFT, -1, UIKit.SIZE_FINE, c)


func _on_plot_input(event: InputEvent) -> void:
	# PAN, ZOOM, AND A DOUBLE-TAP THAT PUTS IT BACK. All of it local to this
	# Control: a Control cannot use _unhandled_input for local gestures, and the
	# world's tap/hold grammar lives out there -- keeping this on gui_input is
	# what makes the two independent rather than a priority fight.
	#
	# The gesture SHAPE is camera_rig's (drag to move, pinch to scale, and the
	# same reference-distance trick), but none of its code: every state variable
	# there is a world-space Vector3 on a 3D camera, and reusing them would mean
	# making the chart depend on the rig. Fifteen lines of logic, re-derived in
	# two dimensions.
	# EVERY BRANCH THAT ACTS CALLS accept_event(). The sheet behind this Control is
	# MOUSE_FILTER_STOP and probably absorbs what is not consumed here, but
	# "probably absorbs" is not a thing to leave a wheel event resting on when
	# CameraRig._unhandled_input also binds the wheel -- project.godot's own note
	# records a bug from exactly that shape, an input reaching two handlers because
	# nobody marked it handled. round_button.gd sets the precedent.
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if mb.button_index == MOUSE_BUTTON_WHEEL_UP and mb.pressed:
			_zoom_about(mb.position, ZOOM_STEP)
			_plot.accept_event()
		elif mb.button_index == MOUSE_BUTTON_WHEEL_DOWN and mb.pressed:
			_zoom_about(mb.position, 1.0 / ZOOM_STEP)
			_plot.accept_event()
		elif mb.button_index == MOUSE_BUTTON_LEFT:
			if mb.pressed and mb.double_click:
				reset_view()
			elif mb.pressed:
				_drag_id = 0
				_drag_last = mb.position
			else:
				_drag_id = -1
			_plot.accept_event()
	elif event is InputEventMouseMotion and _drag_id == 0:
		var mm := event as InputEventMouseMotion
		_pan += mm.position - _drag_last
		_drag_last = mm.position
		_plot.queue_redraw()
		_plot.accept_event()
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if st.pressed:
			# DOUBLE-TAP IS ITS OWN EVENT ON TOUCH, and this is the platform that
			# matters. project.godot sets emulate_mouse_from_touch=false on
			# purpose, so a finger raises NO InputEventMouseButton at all -- the
			# double_click branch above is desktop-only, and without this line the
			# reset gesture simply did not exist on a phone. Checked before the
			# bookkeeping so a double-tap resets rather than starting a drag.
			if st.double_tap:
				reset_view()
				_plot.accept_event()
				return
			_touches[st.index] = st.position
			if _touches.size() == 1:
				_drag_id = st.index
				_drag_last = st.position
			else:
				# A second finger ends the drag and starts a pinch, rather than
				# letting one finger keep panning while the other scales.
				_drag_id = -1
				_pinch_ref = _pinch_span()
		else:
			_touches.erase(st.index)
			if _touches.size() == 1:
				_drag_id = int(_touches.keys()[0])
				_drag_last = _touches[_drag_id]
			elif _touches.is_empty():
				_drag_id = -1
			else:
				# RE-REFERENCE ON EVERY CHANGE OF PAIR. _pinch_ref is a distance
				# between two specific fingers; going from three down to two leaves
				# it measured against a pair that no longer exists, and the next
				# drag divides the new pair's span by that stale number and jumps
				# the zoom. Re-taking it costs one distance and makes the ratio
				# mean what the next frame assumes it means.
				_pinch_ref = _pinch_span()
		_plot.accept_event()
	elif event is InputEventScreenDrag:
		var sd := event as InputEventScreenDrag
		_touches[sd.index] = sd.position
		if _touches.size() >= 2:
			var span := _pinch_span()
			if _pinch_ref > 1.0 and span > 1.0:
				_zoom_about(_pinch_mid(), span / _pinch_ref)
				_pinch_ref = span
		elif sd.index == _drag_id:
			_pan += sd.position - _drag_last
			_drag_last = sd.position
			_plot.queue_redraw()
		_plot.accept_event()


func _pinch_span() -> float:
	var keys: Array = _touches.keys()
	if keys.size() < 2:
		return 0.0
	return (_touches[keys[0]] as Vector2).distance_to(_touches[keys[1]] as Vector2)


func _pinch_mid() -> Vector2:
	var keys: Array = _touches.keys()
	if keys.size() < 2:
		return _plot.size * 0.5
	return ((_touches[keys[0]] as Vector2) + (_touches[keys[1]] as Vector2)) * 0.5


func plot_home() -> Vector2:
	# THE UNPANNED ORIGIN, and the one place it is computed. It is NOT the rect's
	# centre -- FURNITURE_H is reserved off the bottom for the bar and legend, so
	# the picture's centre sits above the rect's. Zoom used `size * 0.5` while the
	# drawing used this, and the two disagreeing by thirteen pixels is a zoom that
	# slides the map a little further every step, which reads as drift with no
	# cause the player can see.
	var usable := maxf(_plot.size.y - FURNITURE_H, 20.0)
	return Vector2(_plot.size.x * 0.5, usable * 0.5)


func _zoom_about(anchor: Vector2, factor: float) -> void:
	# ZOOM TOWARD THE FINGER, not toward the centre. The point under the anchor
	# has to stay under it, or every zoom step also drags the map and the reader
	# loses the thing they were looking at. `mid` is `plot_home() + _pan`, so
	# holding `anchor - mid` proportional to the scale change is the whole fix.
	var before := clampf(_zoom, ZOOM_MIN, ZOOM_MAX)
	_zoom = clampf(_zoom * factor, ZOOM_MIN, ZOOM_MAX)
	var applied := _zoom / maxf(before, 0.0001)
	var mid := plot_home() + _pan
	_pan += (anchor - mid) * (1.0 - applied)
	_plot.queue_redraw()


func reset_view() -> void:
	# Back to the fit. Public because the selection change and the open both
	# want it, and because a reader who has panned into the dark needs one
	# gesture that always works.
	#
	# The gesture bookkeeping goes with it. A panel closed mid-drag never
	# delivers the matching touch-up, so _touches keeps an entry and _drag_id
	# keeps an index -- and the next open starts with a phantom finger down,
	# which reads as a pan that follows the first touch from wherever it lands.
	# open() and close_panel() both come through here.
	_zoom = 1.0
	_pan = Vector2.ZERO
	_touches.clear()
	_drag_id = -1
	_pinch_ref = 0.0
	_plot.queue_redraw()


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
	# v21. A NEW SYSTEM GETS A FRESH VIEW. Pan and zoom are properties of the
	# picture, not of the panel, and carrying pyx01's zoom onto pyx03 -- whose
	# fit radius is an order of magnitude larger -- lands the reader somewhere
	# featureless with no way to know why.
	if id != _selected:
		reset_view()
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
	_apply_layout()
	reset_view()
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
	# Drop any half-finished gesture here rather than on the way back in, so the
	# state cannot survive even if the panel is reopened by a path that does not
	# reset. See reset_view.
	reset_view()
	Sfx.play("equip", -13.0, 0.9)
	var tw := create_tween()
	tw.tween_method(_set_slide, 0.0, _sheet_height(), SLIDE_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	# GUARDED, because open() can win the race. create_tween does not kill the
	# earlier one, so closing and reopening inside SLIDE_TIME left this callback
	# to fire on a panel that was open again and hide it -- an is_open chart with
	# visible false, which the next press "closes" and the player reads as a key
	# that did nothing. Unreachable while the HUD button was the only door (a
	# button only ever opens); a toggle key makes it one key pressed twice.
	# PauseMenu has carried this same guard, for this same race, since it shipped.
	tw.tween_callback(func() -> void:
		if not is_open:
			visible = false)


func _on_recall() -> void:
	close_panel()
	recall_requested.emit()


func _refresh_colonies() -> void:
	# Rebuilt rather than updated: the set changes only when a colony is founded,
	# and a stale row pointing at a colony that does not exist is worse than the
	# cost of four Buttons.
	for c in _colony_rows.get_children():
		_colony_rows.remove_child(c)
		c.queue_free()
	var main := get_tree().get_first_node_in_group("main")
	if main == null or not main.has_method("can_colony_jump"):
		return
	# Only for the system you are IN. A jump is in-system by definition, so a row
	# offered while looking at another system's page would be a button that
	# cannot mean what it says.
	if _selected != GameState.current_system:
		return
	# v21. THE BEACONS YOU DROPPED, above the colonies. Same-system only, which
	# the row set already enforces above and the STORE enforces structurally --
	# beacons are keyed by system id, so there is no cross-system path to
	# disable. Above the colonies because a beacon is the cheap, common,
	# reversible bookmark and a colony is the earned one; the near thing first,
	# which is the order beacon_rows already returns.
	#
	# TWO BUTTONS PER ROW, because the two verbs have genuinely different terms:
	# the course is free, unbounded and slow; the jump is paid, capped and
	# instant. One button that silently picked would hide the only decision the
	# feature actually offers.
	for b_v in GameState.beacon_rows(_selected):
		var bec: Dictionary = b_v
		var bx := float(bec["x"])
		var bz := float(bec["z"])
		var bdepth := float(bec["depth"])
		var blabel := String(bec["label"])
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 4)

		var course_btn := Button.new()
		course_btn.custom_minimum_size = Vector2(0, COLONY_ROW_H)
		course_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		course_btn.add_theme_font_size_override("font_size", 12)
		course_btn.add_theme_color_override("font_color", Palette.TEAL)
		course_btn.text = "COURSE  %s  ·  %dU" % [blabel, int(round(bdepth))]
		course_btn.pressed.connect(func() -> void:
			course_requested.emit(bx, bz, blabel))
		row.add_child(course_btn)

		var jump_btn := Button.new()
		jump_btn.custom_minimum_size = Vector2(0, COLONY_ROW_H)
		jump_btn.add_theme_font_size_override("font_size", 12)
		jump_btn.add_theme_color_override("font_color", Palette.GOLD)
		# THE ROW STATES ITS OWN TERMS, and the depth refusal names the verb that
		# still works -- a beacon past the instruments is not unreachable, it is
		# unjumpable, and those are different sentences (58).
		var cool: float = float(main.colony_jump_ready_in())
		if bdepth > main.BEACON_JUMP_MAX_DEPTH:
			jump_btn.text = "TOO DEEP"
		elif cool > 0.0:
			jump_btn.text = "%ds" % int(ceil(cool))
		else:
			jump_btn.text = "JUMP (%d)" % int(main.beacon_jump_fee(bdepth))
		jump_btn.disabled = not bool(main.can_beacon_jump(bdepth))
		jump_btn.pressed.connect(func() -> void:
			beacon_jump_requested.emit(bx, bz, bdepth, blabel))
		row.add_child(jump_btn)
		_colony_rows.add_child(row)

	for c_v in GameState.colonies_in(_selected):
		var c: Dictionary = c_v
		var key := String(c["key"])
		var parts := key.split(":")
		var idx: int = int(String(parts[1])) if parts.size() == 2 else 0
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, COLONY_ROW_H)
		b.add_theme_font_size_override("font_size", 13)
		b.add_theme_color_override("font_color", Palette.GOLD)
		var cooling: float = float(main.colony_jump_ready_in())
		# THE ROW STATES ITS OWN TERMS — the fee always, the clock when it is
		# running. A disabled button that does not say why is the refusal
		# problem the parley had.
		if cooling > 0.0:
			b.text = "%s  —  %ds" % [SystemDB.hyper_designation(_selected, idx),
				int(ceil(cooling))]
		else:
			b.text = "JUMP TO %s  (%d)" % [SystemDB.hyper_designation(_selected, idx),
				main.COLONY_JUMP_FEE]
		b.disabled = not bool(main.can_colony_jump(key))
		b.pressed.connect(func() -> void: colony_jump_requested.emit(key))
		_colony_rows.add_child(b)


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
	_refresh_colonies()
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
