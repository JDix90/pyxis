class_name UIKit
extends Object
# The control voice, in one place -- the UI sibling of scripts/palette.gd.
#
# Before this, every button in the game was a bare `Button.new()` with its own
# `add_theme_*_override` calls, and there were three unrelated idioms: the title
# screen's styled buttons (the only ones with a StyleBox at all), the pause
# menu's, which had none and therefore rendered in stock Godot grey, and the
# port/refit tabs. Font sizes were magic numbers -- 10, 11, 12, 13, 14, 15, 16,
# 19, 22, 36 across five files -- with nothing saying which meant "heading".
#
# So: a type ramp with names, one stylebox family, and one set of motion
# constants. Palette owns what colour a thing is; this owns how big it is, how
# it reacts to a finger, and how long it takes to do so.
#
# TYPOGRAPHY. Everything below uses Godot's built-in font. The project ships no
# binary assets by design, and the ramp is built so a real display face is a
# one-line change rather than a refactor: set FACE to a loaded FontFile and every
# label in the game picks it up, because they all come through here.
const FACE: Font = null

# --- type ramp ---------------------------------------------------------------
# Named by role, not by size, so "make the headings bigger" is one edit here
# rather than a grep for `22`. The steps are a rounded major-third scale; the
# gaps are wide enough that two adjacent roles never read as a mistake.
const SIZE_DISPLAY := 36      # title wordmark
const SIZE_HEADING := 22      # page headings
const SIZE_TITLE := 19        # panel titles
const SIZE_BUTTON := 15       # primary actions
const SIZE_BODY := 13         # standard readable copy
const SIZE_LABEL := 12        # control labels, tab names
const SIZE_SMALL := 11        # log lines, list rows
const SIZE_FINE := 10         # footnotes, flavour

# Tracking. Wide letterspacing on short uppercase strings is most of what makes
# this read as instrumentation rather than as a game menu, and it costs nothing.
const TRACK_DISPLAY := 6
const TRACK_HEADING := 3
const TRACK_NONE := 0

# --- motion ------------------------------------------------------------------
# One family of durations. The rule is that nothing the player initiated is
# allowed to take longer than the panel slide, because every one of these is
# time between a tap and the answer.
const T_INSTANT := 0.08       # button press feedback
const T_QUICK := 0.12         # page cross-fade, unpause
const T_PANEL := 0.28         # console slide (matches PortPanel.SLIDE_TIME)
const T_STAGGER := 0.035      # per-item delay in a list reveal
const T_REVEAL := 0.22        # per-item fade in a list reveal

const HOVER_SCALE := 1.08
const PRESS_SCALE := 0.94


static func apply_font(c: Control, size: int, spacing := TRACK_NONE) -> void:
	if FACE != null:
		c.add_theme_font_override("font", FACE)
	c.add_theme_font_size_override("font_size", size)
	if spacing != TRACK_NONE:
		c.add_theme_constant_override("outline_size", 0)
	# Godot applies letter spacing through the font itself rather than a theme
	# constant, so with the built-in face this is a no-op that documents intent
	# and starts working the moment FACE is set. Kept here rather than at call
	# sites so there is exactly one place to change when it does.


static func label(text: String, size := SIZE_BODY, color := Palette.AMBER_DIM,
		align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = align
	apply_font(l, size)
	l.add_theme_color_override("font_color", color)
	return l


static func delta_line(after: Dictionary, size := 10) -> Control:
	# "REGEN 6/s -> 17/s   SHIELD 100 -> 70", drawn against the fit currently
	# flying. Returns null when nothing moves, so a caller can skip the row
	# entirely rather than render an empty strip.
	#
	# Lives here rather than in either screen because the refit console and the
	# store ask the identical question at the identical moment, and the whole
	# defect this answers was one hardcoded list being the only thing a player
	# could see. Two divergent copies of the fix would be the same mistake again.
	var pairs := ModuleDB.delta_lines(GameState.stats, after)
	if pairs.is_empty():
		return null

	var row := HFlowContainer.new()
	row.add_theme_constant_override("h_separation", 9)
	row.add_theme_constant_override("v_separation", 0)
	for triple in pairs:
		var cell := HBoxContainer.new()
		cell.add_theme_constant_override("separation", 3)
		cell.add_child(label(String(triple[0]), size, Palette.AMBER_DIM,
			HORIZONTAL_ALIGNMENT_LEFT))
		cell.add_child(label(String(triple[1]), size, Color(0.55, 0.55, 0.6),
			HORIZONTAL_ALIGNMENT_LEFT))
		cell.add_child(label("→", size, Color(0.45, 0.45, 0.5),
			HORIZONTAL_ALIGNMENT_LEFT))
		# The new value is the only thing here in full contrast: the eye should
		# land on what the ship BECOMES, not on what it already is.
		cell.add_child(label(String(triple[2]), size, Palette.HULL,
			HORIZONTAL_ALIGNMENT_LEFT))
		row.add_child(cell)
	return row


static func stylebox(color: Color, fill_alpha := 0.10, border_alpha := 0.55,
		radius := 8) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, fill_alpha)
	sb.border_color = Color(color.r, color.g, color.b, border_alpha)
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(radius)
	return sb


static func style_button(b: Button, color: Color) -> Button:
	# Four distinct boxes, which is the part that keeps getting missed. Sharing
	# one StyleBox across all four states -- which the livery swatches did -- means
	# no hover feedback and a disabled control that looks identical to an enabled
	# one, on a touch UI where the press is the only other signal.
	var normal := stylebox(color)
	b.add_theme_stylebox_override("normal", normal)

	var hover := stylebox(color, 0.20, 0.75)
	b.add_theme_stylebox_override("hover", hover)

	var pressed := stylebox(color, 0.32, 0.95)
	b.add_theme_stylebox_override("pressed", pressed)

	# Disabled has to be legible as "not now" without being invisible: the fill
	# nearly vanishes but the border stays, so the control still occupies its
	# space rather than appearing to have been removed.
	var disabled := stylebox(color, 0.03, 0.18)
	b.add_theme_stylebox_override("disabled", disabled)

	b.add_theme_color_override("font_color", color)
	b.add_theme_color_override("font_hover_color", Palette.WHITE_HOT)
	b.add_theme_color_override("font_pressed_color", Palette.WHITE_HOT)
	b.add_theme_color_override("font_disabled_color", Color(color.r, color.g, color.b, 0.35))
	return b


static func button(text: String, color := Palette.AMBER, size := SIZE_BUTTON,
		min_size := Vector2(0, 42)) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = min_size
	apply_font(b, size)
	return style_button(b, color)


static func press_pop(c: Control) -> void:
	# The RoundButton press feel, available to any control. Scales about the
	# centre, so pivot_offset has to track size -- a control popped about its
	# top-left corner slides diagonally instead of squashing.
	c.pivot_offset = c.size * 0.5
	var tw := c.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(c, "scale", Vector2.ONE * PRESS_SCALE, T_INSTANT)
	tw.tween_property(c, "scale", Vector2.ONE, T_QUICK)


static func reveal_list(items: Array, reduced_motion := false) -> void:
	# Staggered fade-and-slide for a column of labels. The captain's log built its
	# ten lines in a bare for-loop, so the page arrived as a block of text; read
	# top to bottom with a beat between entries it reads as a record being played
	# back, which is what the page is for.
	#
	# Reduced motion is not "the same thing, faster" -- it is the end state,
	# immediately. An animation that still animates is not an accommodation.
	for i in range(items.size()):
		var c := items[i] as Control
		if c == null:
			continue
		if reduced_motion:
			c.modulate.a = 1.0
			continue
		c.modulate.a = 0.0
		var from := c.position
		c.position = from - Vector2(12.0, 0.0)
		var tw := c.create_tween()
		tw.set_ignore_time_scale(true)      # the log is read while paused
		tw.set_parallel(true)
		tw.tween_property(c, "modulate:a", 1.0, T_REVEAL).set_delay(T_STAGGER * i)
		tw.tween_property(c, "position", from, T_REVEAL).set_delay(T_STAGGER * i) \
			.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


static func cross_fade(node: CanvasItem, rebuild: Callable) -> void:
	# Page changes used to queue_free the body and rebuild it in the same frame,
	# which popped. Fading through zero hides the rebuild without hiding the fact
	# that the page changed.
	var tw := node.create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(node, "modulate:a", 0.0, T_QUICK * 0.5)
	tw.tween_callback(rebuild)
	tw.tween_property(node, "modulate:a", 1.0, T_QUICK)
