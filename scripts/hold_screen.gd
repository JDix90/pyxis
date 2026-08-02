class_name HoldScreen
extends CanvasLayer
# THE HOLD, AS A PLACE RATHER THAN A LIST.
#
# This screen exists because the manifest it replaces lived in the wrong console
# for a reason it stated out loud. refit_panel.gd used to say:
#
#     "REFIT is the console that is open everywhere except a boss fight and a
#      dock, which makes it the one place this can live."
#
# That is a workaround written down honestly, and this is the answer to it: the
# hold now has a console of its own, open everywhere INCLUDING a boss fight and
# a dock, so it no longer has to hide behind the fitting screen.
#
# --- ONE CELL IS ONE UNIT OF SPACE ------------------------------------------
# The old manifest printed `ALLOYS x6`, which never showed the one fact a pilot
# actually needs. Goods cost 1, 2 or 3 space each, so `RELICS x8` and
# `ISOTOPE x8` read identically and occupy 24 and 8 units of a 24-unit hold.
# Here a good held xN fills N * space_of contiguous cells, free space draws as
# empty cells, and the picture cannot lie about what is eating the room.
#
# --- THE GRID IS TRIAGE, NOT IDENTIFICATION ---------------------------------
# A cell says what KIND of thing is there and how much room it takes. It does
# NOT say which good, and that is a measurement rather than a preference.
# Measured with ACCESSTEST's own confusion maths, the 34 commodity colours have
# a worst pair of 0.022 against the 0.20 threshold the deep bands are held to --
# and that is in NORMAL vision, an order of magnitude past the bands' worst
# case, with 212 of 561 pairs under the line. Twenty-six pairs share family AND
# bulk AND an indistinguishable colour. So colour is the weaker second channel,
# the family glyph is the primary one, and the good is NAMED IN WORDS in the
# strip below. See Palette.FAMILY_GLYPHS.
#
# --- IT DOES NOT COVER THE ACTION DOCK --------------------------------------
# Every other sheet in the game does, because HUD sets no `layer` and therefore
# sits at 0. This one stops short of it (`_dock_clear`), because its whole
# premise is that you can use it under pressure: the apex wreck seeds 4 isotopes
# and 3 relics among its spill -- 13 units of space against a bare hold of 24 --
# so dumping ore mid-fight to make room for the drop is a real play, and a
# console that covered the ABILITY button while you did it would be arguing
# with itself. `_root` stays MOUSE_FILTER_IGNORE for the same reason: a tap
# above the sheet still steers the ship.
#
# It never touches get_tree().paused. Whoever opened it owns the pause state.

const SLIDE_TIME := 0.28          # UIKit.T_PANEL, matching every other sheet
const MAX_RATIO := 0.72           # never more of the screen than this
const MIN_SHEET := 220.0
const SHEET_GAP := 8.0            # clearance above the action dock

var is_open := false

var _root: Control
var _sheet: Panel
var _col: VBoxContainer
var _header: Label
var _scroll: ScrollContainer
var _grid: HoldGrid
var _strip: VBoxContainer
var _height := 0.0
var _dock_clear := 0.0
# Two-tap arming for the dump, carried here rather than shared with anything
# else. refit_panel learned this the hard way and wrote it down: arming that
# outlives the interaction is a brake that stays pressed, so it is cleared on
# close and on any change of selection.
var _pending_cargo := ""
var _selected := ""
# Set by cargo_changed, consumed once per frame. Straight-wiring the signal to a
# rebuild would redraw the whole grid once per unit while strip_hottest unloads
# a raided hold one unit at a time.
var _dirty := false
var _needs_clamp := false
var refresh_count := 0


func _ready() -> void:
	# Above chart/refit (2) and port (3), below pause (6) and manual (7). Stated
	# in one line rather than left to add_child order -- chart and refit are both
	# at 2 today and which one draws on top is an accident of construction.
	layer = 4
	# Named by group so CameraRig's hotkey can reach the manifest without
	# holding a typed reference to a node Main owns -- the same arrangement
	# every other cross-console call in this project uses.
	add_to_group("hold_screen")
	_build()
	visible = false
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	# In _ready, never in _apply_layout: that one is wired to size_changed, and
	# Godot cannot dedupe lambdas, so connecting from inside it would add a fresh
	# connection every time the window was dragged.
	GameState.cargo_changed.connect(_mark_dirty)


func _process(_delta: float) -> void:
	if _dirty and is_open:
		_dirty = false
		_refresh()
	elif _needs_clamp and is_open:
		# ONE FRAME LATER, ON PURPOSE. Godot settles container layout over a
		# frame, so the chrome measured during _refresh is the PRE-settle height
		# -- a wrapped label in the strip lands one row different once the column
		# has its real width. Clamping only at refresh time left the sheet 34
		# rows short at capacity 104, which THE CLAMP HOLDS caught by measuring
		# after the frame the way anything looking at the screen would.
		_needs_clamp = false
		_clamp_height()


func _mark_dirty() -> void:
	_dirty = true


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	# IGNORE, deliberately unlike the manual's STOP scrim: this console is used
	# while flying, and a tap above it must still reach the ship.
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_sheet = Panel.new()
	_sheet.anchor_left = 0.0
	_sheet.anchor_right = 1.0
	# BOTH anchors at the bottom, unlike the other sheets' `1.0 - RATIO`. The
	# height here is derived from the hold rather than fixed, and an anchor pair
	# cannot express that -- the offsets carry it, and _set_slide moves both
	# together so the sheet slides without resizing.
	_sheet.anchor_top = 1.0
	_sheet.anchor_bottom = 1.0
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.04, 0.97)
	style.border_color = Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.55)
	style.border_width_top = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	_sheet.add_theme_stylebox_override("panel", style)
	_root.add_child(_sheet)

	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_sheet.add_child(margin)

	_col = VBoxContainer.new()
	_col.add_theme_constant_override("separation", 8)
	margin.add_child(_col)

	var head_row := HBoxContainer.new()
	_header = UIKit.label("HOLD", UIKit.SIZE_TITLE, Palette.GOLD,
		HORIZONTAL_ALIGNMENT_LEFT)
	_header.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head_row.add_child(_header)
	var close := Button.new()
	close.text = "✕"
	close.flat = true
	UIKit.apply_font(close, UIKit.SIZE_TITLE)
	close.add_theme_color_override("font_color", Palette.GOLD)
	close.pressed.connect(close_panel)
	head_row.add_child(close)
	_col.add_child(head_row)

	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_col.add_child(_scroll)

	_grid = HoldGrid.new()
	_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_grid.cell_picked.connect(_on_cell_picked)
	_scroll.add_child(_grid)

	_strip = VBoxContainer.new()
	_strip.add_theme_constant_override("separation", 4)
	_col.add_child(_strip)


func _apply_layout() -> void:
	UILayout.column_horizontal(_sheet)
	_clamp_height()


func _clamp_height() -> void:
	# THE CLAMP, and it is written to be assertable rather than to be tidy.
	#
	# SHEET FITS measures _panel.size.y, which its own clamp guarantees, and so
	# cannot fail on content growth. THE CLAMP HOLDS on the manual is the
	# corrected shape and this follows it: the scroll viewport is pinned to
	# exactly min(content, room), so too tall fails and so does collapsed.
	if _grid == null or _root == null or _scroll == null:
		return
	var vp := _root.size
	if vp.y <= 1.0:
		return
	_dock_clear = HUD.DOCK_BOTTOM + _dock_height() + SHEET_GAP
	# TWO PASSES, because the clamp perturbs what it measures. Setting the
	# scroll's minimum re-lays-out the column, and a wrapped label in the strip
	# can settle one row taller or shorter than it measured at -- so a single
	# pass leaves the viewport off by exactly that row whenever `room` is the
	# binding term. Measured as a constant 34-unit gap at capacity 104 before
	# this loop existed. The second pass reads the settled layout; a third never
	# changes anything, because the strip's height is a function of the column
	# width and that no longer moves.
	for _pass in range(2):
		var chrome := _chrome_height()
		var room := maxf(vp.y * MAX_RATIO - chrome, MIN_SHEET - chrome)
		var content := _grid.get_combined_minimum_size().y
		_scroll.custom_minimum_size.y = minf(content, room)
	_height = _col.get_combined_minimum_size().y + 32.0
	if not is_open:
		_set_slide(_height)
	else:
		_set_slide(0.0)


func _chrome_height() -> float:
	# Everything in the column that is NOT the scroll, summed directly.
	#
	# NOT `_col.get_combined_minimum_size().y - _scroll.custom_minimum_size.y`,
	# which is the obvious spelling and is CIRCULAR: the column's minimum
	# INCLUDES the scroll's, so each call folds its own previous output back in.
	# It looks correct while the strip is short and diverges the moment it is
	# not -- measured at a room of -26,506 once the strip grew read buttons and
	# a pilot block. THE CLAMP HOLDS caught it, which is the entire reason that
	# assertion is written to recompute rather than to read back.
	var h := 32.0                       # the MarginContainer's 16 top + 16 bottom
	var seen := 0
	for c in _col.get_children():
		if c == _scroll:
			continue
		h += (c as Control).get_combined_minimum_size().y
		seen += 1
	h += float(_col.get_theme_constant("separation")) * float(maxi(seen, 0))
	return h


func _dock_height() -> float:
	var hud := get_tree().get_first_node_in_group("hud")
	if hud == null or not hud.has_method("band_rects"):
		return 96.0
	var rects: Dictionary = hud.band_rects()
	if not rects.has("dock"):
		return 96.0
	var r: Vector2 = rects["dock"]
	return maxf(r.y - r.x, 0.0)


func sheet_height() -> float:
	return _height


func _sheet_top() -> float:
	return _sheet.offset_top


func _set_slide(v: float) -> void:
	# Both offsets move together, the invariant every sheet in this game keeps --
	# expressed here for a height that is recomputed rather than fixed.
	_sheet.offset_top = -_height - _dock_clear + v
	_sheet.offset_bottom = -_dock_clear + v


# --- open / close -----------------------------------------------------------

func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	_selected = ""
	_pending_cargo = ""
	# UNCONDITIONALLY, not only on cargo_changed: the harnesses assign
	# GameState.cargo directly in about forty places, which no signal can see.
	_refresh()
	Sfx.play("equip", -8.0, 1.05)
	_clamp_height()
	if GameState.reduce_motion():
		_set_slide(0.0)
		return
	_set_slide(_height)
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_method(_set_slide, _height, 0.0, SLIDE_TIME) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func close_panel() -> void:
	# Named to match every other console so CameraRig's escape ladder can treat
	# them all alike.
	if not is_open:
		return
	is_open = false
	# The brake must not stay pressed. Arming a dump, closing the sheet and
	# flying for ten minutes must not leave the next tap live.
	_pending_cargo = ""
	_selected = ""
	Sfx.play("equip", -12.0, 0.9)
	if GameState.reduce_motion():
		visible = false
		return
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_method(_set_slide, 0.0, _height, SLIDE_TIME) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(func() -> void: visible = false)


func toggle() -> void:
	if is_open:
		close_panel()
	else:
		open()


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("cancel"):
		# One step at a time: a selection backs out to the grid, and the grid
		# backs out of the screen.
		if _selected != "":
			_selected = ""
			_pending_cargo = ""
			_refresh()
		else:
			close_panel()
		get_viewport().set_input_as_handled()


# --- contents ---------------------------------------------------------------

func _on_cell_picked(good: String) -> void:
	if good != _selected:
		# A change of selection disarms: the confirm belongs to the row it was
		# armed on, never to whatever the finger landed on next.
		_pending_cargo = ""
	_selected = good
	_refresh()


func _refresh() -> void:
	refresh_count += 1
	var used := GameState.cargo_used()
	var cap := GameState.cargo_capacity()
	_header.text = "HOLD  %d / %d" % [used, cap]
	_header.add_theme_color_override("font_color",
		Palette.THREAT if used >= cap else Palette.GOLD)

	_grid.rebuild()

	# REMOVED as well as freed. queue_free is deferred, so without the pairing
	# the outgoing strip is still a child while the incoming one is measured --
	# and _clamp_height below would size the sheet for both at once. The manual
	# records this trap; refit_panel gets away with a bare queue_free only
	# because it never measures.
	for c in _strip.get_children():
		_strip.remove_child(c)
		c.queue_free()

	_build_overflow_exit()
	if _selected != "" and GameState.cargo_count(_selected) > 0:
		_build_selected(_selected)
	else:
		_selected = ""
		_build_idle()
	_clamp_height()
	_needs_clamp = true


func _docked_bay_key() -> String:
	# The bay of the station we are clamped to, or "" if flying or the station
	# keeps no store.
	var main := get_tree().get_first_node_in_group("main")
	if main == null or main.docked_port == null:
		return ""
	var port: Port = main.docked_port
	var pdef: Dictionary = port.def if not port.def.is_empty() \
		else SystemDB.port_def_by_id(port.port_id)
	if not GameState.port_has_bay(pdef):
		return ""
	return port.bay_key if port.bay_key != "" else port.port_id


func _build_overflow_exit() -> void:
	# THE HONEST WAY OUT OF AN OVER-FULL HOLD, offered only while docked at a
	# bay. It does not weaken JETTISON PAYS NOTHING: dumping stays free because
	# dodging a trip to a port should not also be profitable, and stashing IS
	# that trip -- the cargo goes into a paid bay at a station you flew to.
	var over := GameState.cargo_over()
	if over <= 0:
		return
	var key := _docked_bay_key()
	if key == "":
		_strip.add_child(UIKit.label(
			"OVER CAPACITY BY %d — DUMP SOMETHING, OR DOCK AT A BAY." % over,
			UIKit.SIZE_SMALL, Palette.THREAT, HORIZONTAL_ALIGNMENT_LEFT))
		return
	if not GameState.stash_would_fit_now(key):
		_strip.add_child(UIKit.label(
			"OVER CAPACITY BY %d — THE BAY CANNOT TAKE IT ALL." % over,
			UIKit.SIZE_SMALL, Palette.THREAT, HORIZONTAL_ALIGNMENT_LEFT))
		return
	var b := UIKit.button("STASH %d TO THE BAY" % over, Palette.GOLD,
		UIKit.SIZE_SMALL, Vector2(0, 34))
	b.pressed.connect(func() -> void:
		UIKit.press_pop(b)
		var moved := GameState.stash_to_fit_now(key)
		if moved <= 0:
			Sfx.play("tap", -14.0, 0.6)
			return
		Sfx.play("equip", -7.0, 0.9)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			hud.show_toast("STASHED %d UNIT%s" % [
				moved, "" if moved == 1 else "S"], Palette.GOLD)
		_refresh())
	_strip.add_child(b)


func _build_idle() -> void:
	var value := GameState.hold_value()
	_strip.add_child(UIKit.label(
		"%d OF %d UNITS OF SPACE USED  ·  %s ABOARD" % [
			GameState.cargo_used(), GameState.cargo_capacity(), _comma(value)],
		UIKit.SIZE_SMALL, Palette.AMBER_DIM, HORIZONTAL_ALIGNMENT_LEFT))
	if GameState.cargo.is_empty():
		_strip.add_child(UIKit.label("EMPTY. NOTHING ABOARD BUT YOU.",
			UIKit.SIZE_FINE, Palette.AMBER_DIM, HORIZONTAL_ALIGNMENT_LEFT))
		return
	_strip.add_child(UIKit.label("TAP A BLOCK TO SEE WHAT IT IS.",
		UIKit.SIZE_FINE, Palette.AMBER_DIM, HORIZONTAL_ALIGNMENT_LEFT))

	# The pilot's three skill lines, beside the read buttons they explain --
	# which is the reason they were worth moving with the manifest rather than
	# leaving in a console about modules.
	var readable := 0
	for gid in GameState.cargo:
		var g := String(gid)
		if CommodityDB.is_salvage(g) and GameState.can_read(g, false):
			readable += GameState.cargo_count(g)
	if readable > 0:
		_strip.add_child(UIKit.label(
			"%d UNIT%s READABLE ABOARD — TAP ONE TO OPEN IT." % [
				readable, "" if readable == 1 else "S"],
			UIKit.SIZE_FINE, Palette.TEAL, HORIZONTAL_ALIGNMENT_LEFT))
	var pilot := UIKit.label("%s\n%s\n%s" % [GameState.archeology_line(),
		GameState.smuggling_line(), GameState.mining_line()],
		UIKit.SIZE_FINE, Palette.AMBER_DIM, HORIZONTAL_ALIGNMENT_LEFT)
	pilot.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	# THE WIDTH FLOOR IS NOT COSMETIC. An autowrapping Label with no minimum
	# width computes its wrap at nearly zero width, so it reports a minimum
	# HEIGHT as if every word were its own line -- measured at 2,415 rows for
	# these three skill lines, which then became the column's minimum and drove
	# the sheet's clamp to a negative height. manual_screen and pause_menu both
	# pin wrapped labels to 300 for exactly this reason. THE CLAMP HOLDS is what
	# caught it, by recomputing rather than reading back.
	pilot.custom_minimum_size = Vector2(300, 0)
	_strip.add_child(pilot)


func _build_selected(good: String) -> void:
	var held := GameState.cargo_count(good)
	var fam := CommodityDB.family(good)
	var glyph := Palette.family_glyph(fam)
	var title := UIKit.label("%s  %s  ×%d" % [glyph, CommodityDB.display(good).to_upper(), held],
		UIKit.SIZE_BODY, _color_for(good), HORIZONTAL_ALIGNMENT_LEFT)
	_strip.add_child(title)

	# What it is, what it costs to carry, what it is worth. The category line is
	# the half of "goods became categories" that only ever reached the old
	# manifest, and it comes across intact.
	var detail := "%d SPACE EACH  ·  %d OF %d UNITS  ·  %s EACH" % [
		CommodityDB.space_of(good), held * CommodityDB.space_of(good),
		GameState.cargo_capacity(), _comma(CommodityDB.base_price(good))]
	if CommodityDB.is_component(good):
		detail = "%s  ·  %s" % [
			CommodityDB.short_name(CommodityDB.parent_of(good)), detail]
	_strip.add_child(UIKit.label(detail, UIKit.SIZE_FINE, Palette.AMBER_DIM,
		HORIZONTAL_ALIGNMENT_LEFT))

	_build_field_reads(good)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var armed := _pending_cargo == good
	row.add_child(_mini("DUMP 1" if not armed else "SURE?",
		func() -> void: _dump(good, 1)))
	if held > 1:
		row.add_child(_mini("DUMP ALL" if not armed else "SURE?",
			func() -> void: _dump(good, held)))
	_strip.add_child(row)


func _build_field_reads(good: String) -> void:
	# READING SALVAGE, WITHOUT A LAB. It lives here rather than at a port for the
	# reason it always did: it is a hold operation, and this is now the console
	# that manages what is on your ship from anywhere. Ports keep SERVICES; this
	# is you and a prybar.
	if not CommodityDB.is_salvage(good):
		return
	if not GameState.can_read(good, false):
		_strip.add_child(UIKit.label(
			"SEALED — ARCHEOLOGY %d READS THIS GRADE." % CommodityDB.band_of(good),
			UIKit.SIZE_FINE, Palette.AMBER_DIM, HORIZONTAL_ALIGNMENT_LEFT))
		return
	var reads := CommodityDB.reads_as(good)
	if reads.is_empty():
		return
	_strip.add_child(UIKit.label("READ IT AS:", UIKit.SIZE_FINE, Palette.AMBER_DIM,
		HORIZONTAL_ALIGNMENT_LEFT))
	var reads_row := HBoxContainer.new()
	reads_row.add_theme_constant_override("separation", 6)
	for out_v in reads:
		var out := String(out_v)
		# The value and space deltas, printed. Reading compresses a hold 2.6-3.7x
		# and physically shrinks the deep grades, and a read button that did not
		# say so was asking the player to guess.
		var d_val := CommodityDB.base_price(out) - CommodityDB.base_price(good)
		var d_space := CommodityDB.space_of(out) - CommodityDB.space_of(good)
		var b := UIKit.button("%s  %s%s  %+d SPACE" % [
			CommodityDB.short_name(out), "+" if d_val >= 0 else "", _comma(d_val),
			d_space], Palette.TEAL, UIKit.SIZE_FINE, Vector2(0, 34))
		b.pressed.connect(func() -> void:
			UIKit.press_pop(b)
			_do_field_read(good, out))
		reads_row.add_child(b)
	_strip.add_child(reads_row)


func _do_field_read(sid: String, out: String) -> void:
	if not GameState.identify(sid, out, false):
		# A read that cannot be stowed fails cleanly rather than half-happening:
		# a component can be bulkier than the salvage it came out of.
		Sfx.play("tap", -14.0, 0.6)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			hud.show_toast("HOLD FULL — NO ROOM FOR WHAT IT IDENTIFIES AS",
				Palette.THREAT)
		return
	Sfx.play("equip", -7.0, 1.1)
	var hud2 := get_tree().get_first_node_in_group("hud")
	if hud2:
		hud2.show_toast("READ — %s" % CommodityDB.short_name(out),
			CommodityDB.color_of(out))
	if GameState.cargo_count(sid) <= 0:
		_selected = ""
	_refresh()


func _mini(text: String, cb: Callable) -> Button:
	var b := UIKit.button(text, Palette.THREAT, UIKit.SIZE_SMALL, Vector2(0, 34))
	b.pressed.connect(func() -> void:
		UIKit.press_pop(b)
		cb.call())
	return b


func _dump(good: String, units: int) -> void:
	# Two taps, and the toast is the dialog. This game has no modals for this:
	# the first tap says what will happen, the second means yes.
	if _pending_cargo != good:
		_pending_cargo = good
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			hud.show_toast("DUMP %s — TAP AGAIN TO CONFIRM" % (
				"ALL" if units > 1 else "1"), Palette.THREAT)
		_refresh()
		return
	_pending_cargo = ""
	var removed := GameState.unload_cargo(good, units)
	# NOTHING IS SPAWNED AND NOTHING IS PAID. Dumped cargo does not float:
	# JETTISON SPAWNS NOTHING is a pre-emptive assertion against exactly that,
	# because recoverable jettison converts a dump into full toll evasion.
	if removed > 0:
		Sfx.play("explode", -14.0, 1.4)
		var hud2 := get_tree().get_first_node_in_group("hud")
		if hud2:
			hud2.show_toast("DUMPED %s ×%d" % [
				CommodityDB.short_name(good), removed], Palette.THREAT)
		GameState.note_log("DUMPED — %s ×%d" % [
			CommodityDB.short_name(good), removed])
	if GameState.cargo_count(good) <= 0:
		_selected = ""
	_refresh()


func _color_for(good: String) -> Color:
	var fam := CommodityDB.family(good)
	var band := -1
	if fam == "salvage":
		band = CommodityDB.band_of(good)
	elif fam == "chart":
		band = CommodityDB.chart_band_of(good)
	return Palette.family_color(fam, band)


func _comma(n: int) -> String:
	var s := str(absi(n))
	var out := ""
	var c := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		c += 1
		if c % 3 == 0 and i > 0:
			out = "," + out
	return ("-" if n < 0 else "") + out


# --- harness accessors ------------------------------------------------------

func grid_cells() -> Array:
	return _grid.cells() if _grid != null else []


func strip_text() -> String:
	# What the strip ACTUALLY SAYS. The grid cannot name a good -- see the header
	# -- so this is where NOTHING IS NAMED BY COLOUR ALONE does its looking.
	var out := ""
	for c in _strip.get_children():
		out += _text_under(c) + " "
	return out.strip_edges()


func _text_under(n: Node) -> String:
	var out := ""
	if n is Label:
		out += (n as Label).text + " "
	elif n is Button:
		out += (n as Button).text + " "
	for c in n.get_children():
		out += _text_under(c)
	return out


func scroll_viewport_height() -> float:
	return _scroll.custom_minimum_size.y if _scroll != null else -1.0


func grid_content_height() -> float:
	return _grid.get_combined_minimum_size().y if _grid != null else -1.0


func room_for_grid() -> float:
	# Recomputed by the assertion independently; exposed here only so the two can
	# be compared rather than so the assertion can borrow the answer.
	if _root == null or _col == null:
		return -1.0
	var chrome := _chrome_height()
	return maxf(_root.size.y * MAX_RATIO - chrome, MIN_SHEET - chrome)


# --- the grid ---------------------------------------------------------------

class HoldGrid extends Control:
	# ONE DRAWN CONTROL, not 104 Buttons, for three reasons that are all about
	# what this thing has to survive.
	#
	# CHURN. strip_hottest unloads a raided hold ONE UNIT AT A TIME in a while
	# loop, so a node-per-cell grid would tear down and rebuild up to 104
	# children -- each with four StyleBoxFlats -- dozens of times inside one
	# frame.
	#
	# WRAPPED BLOCKS. A 3-space unit starting in the last column has to read as
	# one shape continuing on the next row. Drawing the border only on edges that
	# are exterior to the block is four lines here and painful across discrete
	# children.
	#
	# PRECEDENT. RoundButton is already a touch control drawn in code so it
	# inherits the palette with no assets, and this follows it.

	signal cell_picked(good: String)

	const CELL := 52.0
	const CELL_SEP := 6.0
	const COLS_MIN := 6
	# The absolute floor a cell may never cross, independent of CELL above.
	# UIKit.button floors its own height at 42 and this matches it, so a cell is
	# at least as reachable as the smallest button the game ships. Named
	# separately BECAUSE A FINGER FITS asserts against it rather than against
	# CELL: a check that only said "cells are at least CELL" would still pass if
	# someone set CELL to 30, which is a constant agreeing with itself and no
	# statement at all about a thumb.
	const TAP_MIN := 42.0

	var _cells: Array = []

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_STOP

	func columns() -> int:
		# Derived from the width the container actually gave us, never from the
		# capacity. Capacity moves the ROW COUNT; it must never move the cell
		# size, because that is the whole tap-target guarantee.
		return maxi(COLS_MIN, floori((size.x + CELL_SEP) / (CELL + CELL_SEP)))

	func cell_size() -> float:
		# Slack is distributed INTO the cells rather than left as margin, so a
		# cell is never smaller than CELL and the grid always fills its width.
		var c := columns()
		return (size.x - float(c - 1) * CELL_SEP) / float(c)

	func rows() -> int:
		return ceili(float(maxi(GameState.cargo_capacity(), 1)) / float(columns()))

	func _get_minimum_size() -> Vector2:
		var r := rows()
		return Vector2(0, float(r) * cell_size() + float(maxi(r - 1, 0)) * CELL_SEP)

	func cells() -> Array:
		return _cells

	func rebuild() -> void:
		# PACKED ROW-MAJOR WITH NO PADDING EVER. Filled cells == cargo_used(),
		# empty == cargo_free(), total == cargo_capacity(). Aligning units to row
		# boundaries was considered and rejected: it makes the drawn cell count
		# stop equalling the capacity, and the one promise this screen makes is
		# that the picture does not lie.
		_cells.clear()
		var cap := GameState.cargo_capacity()
		# Family order, then price DESCENDING inside a family. Deterministic, and
		# it puts the dense valuable cargo top-left and the dumpable gravel next
		# to the free space -- so "what do I drop" becomes a spatial question.
		var order := ["bulk", "metal", "mineral", "salvage", "component", "chart", "restricted"]
		var held: Array = []
		for gid in GameState.cargo:
			held.append(String(gid))
		held.sort_custom(func(a: String, b: String) -> bool:
			var fa := order.find(CommodityDB.family(a))
			var fb := order.find(CommodityDB.family(b))
			if fa != fb:
				return fa < fb
			return CommodityDB.base_price(a) > CommodityDB.base_price(b))

		for good in held:
			var per := maxi(CommodityDB.space_of(good), 1)
			var units := GameState.cargo_count(good)
			for u in range(units):
				for s in range(per):
					if _cells.size() >= cap:
						break
					_cells.append({
						"good": good,
						# The glyph draws once per UNIT, on that unit's first
						# cell, while the cell COUNT is the space. So x4 relics
						# reads as four glyphs inside twelve cells and both
						# facts are countable off the same shape.
						"glyph": Palette.family_glyph(CommodityDB.family(good)) if s == 0 else "",
						"head": s == 0,
						"tail": s == per - 1,
					})
		while _cells.size() < cap:
			_cells.append({"good": "", "glyph": "", "head": false, "tail": false})
		update_minimum_size()
		queue_redraw()

	func _cell_rect(i: int) -> Rect2:
		var c := columns()
		var cs := cell_size()
		var col := i % c
		var row := i / c
		return Rect2(float(col) * (cs + CELL_SEP), float(row) * (cs + CELL_SEP), cs, cs)

	func _colour_for(good: String) -> Color:
		var fam := CommodityDB.family(good)
		var band := -1
		if fam == "salvage":
			band = CommodityDB.band_of(good)
		elif fam == "chart":
			band = CommodityDB.chart_band_of(good)
		return Palette.family_color(fam, band)

	func _draw() -> void:
		var font := get_theme_font("font")
		var cs := cell_size()
		var gsize := int(clampf(cs * 0.46, 10.0, 22.0))
		for i in range(_cells.size()):
			var cell: Dictionary = _cells[i]
			var r := _cell_rect(i)
			var good := String(cell["good"])
			if good == "":
				# Free space: an outline, so the room you have left is as
				# countable as the room you have spent.
				draw_rect(r, Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.05), true)
				draw_rect(r, Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.18), false, 1.0)
				continue
			var col := _colour_for(good)
			draw_rect(r, Color(col.r, col.g, col.b, 0.22), true)
			draw_rect(r, Color(col.r, col.g, col.b, 0.75), false, 1.0)
			var gl := String(cell["glyph"])
			if gl != "" and font != null:
				var sz := font.get_string_size(gl, HORIZONTAL_ALIGNMENT_CENTER, -1, gsize)
				draw_string(font, r.position + Vector2(
						(r.size.x - sz.x) * 0.5, (r.size.y + sz.y * 0.62) * 0.5),
					gl, HORIZONTAL_ALIGNMENT_LEFT, -1, gsize, col)

	func _gui_input(event: InputEvent) -> void:
		if not (event is InputEventMouseButton):
			return
		var mb := event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		for i in range(_cells.size()):
			if not _cell_rect(i).has_point(mb.position):
				continue
			var good := String((_cells[i] as Dictionary)["good"])
			if good != "":
				cell_picked.emit(good)
			return
