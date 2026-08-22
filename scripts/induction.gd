class_name Induction
extends CanvasLayer
# §133. THE INDUCTION. The Authority's own briefing film, played once between
# NEW SURVEY and the tutorial and replayable from the title -- the front door's
# lore, told the way the GSA would tell it: partial, confident, and quietly
# wrong. Every euphemism in the copy is a hook the deep later answers, and the
# copy rules are enforced by TITLETEST rather than remembered:
#
#   THE INDUCTION QUOTES NO FRAGMENT. The unsounded structures' sentences exist
#   only at the structures (UnsoundedSite.FRAGMENTS); this film writes new ones
#   that gesture at the same facts. The ONE allowed quotation is Directive 9's
#   public clause -- Beacon.DIRECTIVE_PAGES[0], text the Authority itself
#   published on charted infrastructure -- and the leg asserts it is quoted
#   EXACTLY, because a paraphrased legal text is a second version of the law.
#
# DRAWN IN CHART LANGUAGE, not staged in meshes, and that is a design decision
# rather than a shortcut: the Authority's induction film would be diagrams and
# light -- cells, rings, clocks, silhouettes -- not cockpit footage. It also
# keeps the title screen's own promise one layer down ("the live system drifts
# behind it"): the scrim is not opaque, so the real sky is the backdrop the
# whole way through.
#
# THE SCENE OWNS NO STATE. It never writes GameState -- the seen flag is a
# device preference Main sets on the finished signal -- so SKIP LEAVES NO TRACE
# is a property of the wiring, not a discipline. §17's expanse purity is not
# even adjacent: nothing here touches a generator.

signal finished(replay: bool)

# The film, as data, so the harness can walk it without a viewport. Durations
# in seconds; reduce_motion halves them and draws every element at its end
# state ("the accommodation is the end state, immediately" -- UIKit's rule).
# The first line of each beat is the header tint; the rest are body.
const BEATS := [
	{"id": "commission", "dur": 10.0, "lines": [
		"GSA SURVEY AUTHORITY",
		"PILOT INDUCTION · FIRST DEPLOYMENT",
		"THE WAR IS OVER. THE CHARTS DID NOT SURVIVE IT.",
		"WHAT THE AUTHORITY COULD HOLD, IT CHARTED.",
	]},
	{"id": "instruments", "dur": 12.0, "lines": [
		"THE SURVEY WENT OUT.",
		"DATUM RAISED. TIME KEPT. BEARINGS TAKEN.",
		"EVERY CELL FILED WAS A CELL HELD.",
	]},
	{"id": "arithmetic", "dur": 14.0, "lines": [
		"BEYOND THE DEEP MARKS, SCHEDULES RETURNED IN DISAGREEMENT.",
		"THE CLOCKS WERE NOT WRONG. THE DEEP KEEPS ITS OWN TIME.",
		"ACCOUNTS COULD NOT BE SETTLED ACROSS THE LINE.",
	]},
	{"id": "reclassification", "dur": 14.0, "lines": [
		"DIRECTIVE 9: \"THE FRONTIER BEYOND THE BEARING TERMINUS IS RECLASSIFIED UNSOUNDABLE. SURVEY OPERATIONS IN THE RECLASSIFIED VOLUME ARE SUSPENDED INDEFINITELY.\"",
		"ASSETS REMAIN ON STATION.",
	]},
	{"id": "you", "dur": 10.0, "lines": [
		"CHARTED SPACE IS PATROLLED. THE CHART IS NOT FINISHED.",
		"WHAT YOU READ, YOU MAY FILE. THE COUNTER PAYS FOR FIRSTS.",
		"FLY SAFE, PILOT. FILE RETURNS.",
	]},
]

const COPY_WIDTH := 640.0        # the prompt label's own width (§121)
const TAP_GUARD := 0.4           # seconds before a tap can advance -- the tap
                                 # that opened the menu must not eat beat one
const REDUCED_DUR_MULT := 0.5
# The scrim: SPACE_BG at high alpha, so the live system reads through faintly.
const SCRIM_BASE := Color(0.012, 0.014, 0.022, 0.93)
const SCRIM_COLD := Color(0.030, 0.045, 0.085, 0.95)
const STAR_COUNT := 90

var _replay := false
var _reduced := false
var _beat := -1
var _t := 0.0

var _root: Control
var _scrim: ColorRect
var _canvas: Control
var _lines_box: VBoxContainer
var _skip: Button
var _stars: Array = []           # [{p: Vector2 (fractions), r, a}]


func _ready() -> void:
	layer = 7                    # above the title's 6, so a replay covers it
	_build()
	visible = false
	set_process(false)
	# One seeded roll at build, never per frame: the same sky every showing,
	# which is what makes a PYXIS_SHOTS still comparable across runs.
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("induction")
	for i in range(STAR_COUNT):
		_stars.append({"p": Vector2(rng.randf(), rng.randf()),
			"r": rng.randf_range(0.6, 1.8), "a": rng.randf_range(0.15, 0.7)})


func _build() -> void:
	_scrim = ColorRect.new()
	_scrim.color = SCRIM_BASE
	_scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_scrim)

	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	_canvas = Control.new()
	_canvas.set_anchors_preset(Control.PRESET_FULL_RECT)
	_canvas.draw.connect(_draw_beat)
	_canvas.gui_input.connect(_on_tap)
	_root.add_child(_canvas)

	_lines_box = VBoxContainer.new()
	# Taps land on the CANVAS, which advances -- a copy column that ate the tap
	# would make the middle of the screen a dead zone exactly where thumbs rest.
	_lines_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_lines_box.add_theme_constant_override("separation", 10)
	_lines_box.anchor_left = 0.5
	_lines_box.anchor_right = 0.5
	_lines_box.anchor_top = 0.62
	_lines_box.anchor_bottom = 0.62
	_lines_box.offset_left = -COPY_WIDTH * 0.5
	_lines_box.offset_right = COPY_WIDTH * 0.5
	_root.add_child(_lines_box)

	# §88: the exit is a control on screen, never a secret gesture. A tap
	# advances; this ends.
	_skip = Button.new()
	_skip.text = "SKIP ▸"
	_skip.flat = true
	_skip.add_theme_font_size_override("font_size", 12)
	_skip.add_theme_color_override("font_color", Palette.AMBER_DIM)
	_skip.anchor_left = 1.0
	_skip.anchor_right = 1.0
	_skip.offset_left = -110.0
	_skip.offset_top = 18.0
	_skip.offset_right = -16.0
	_skip.offset_bottom = 52.0
	_skip.pressed.connect(_finish)
	_root.add_child(_skip)


func open(replay: bool) -> void:
	UILayout.column(_root)
	_replay = replay
	_reduced = GameState.reduce_motion()
	_beat = -1
	visible = true
	set_process(true)
	_advance()


func is_running() -> bool:
	return visible


func beat_index() -> int:
	return _beat


func advance_beat() -> void:
	# Public for the tap handler and the harness alike -- the leg walks the film
	# with the same verb a thumb uses.
	_advance()


func _advance() -> void:
	_beat += 1
	if _beat >= BEATS.size():
		_finish()
		return
	_t = 0.0
	for c in _lines_box.get_children():
		c.queue_free()
	var lines: Array = (BEATS[_beat] as Dictionary)["lines"]
	var labels: Array = []
	for i in range(lines.size()):
		var l := Label.new()
		l.text = String(lines[i])
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 15 if i == 0 else 13)
		l.add_theme_color_override("font_color",
			Palette.GOLD if i == 0 else Palette.HULL)
		l.modulate.a = 0.0
		_lines_box.add_child(l)
		labels.append(l)
	UIKit.reveal_list(labels, _reduced)
	_canvas.queue_redraw()


func _finish() -> void:
	visible = false
	set_process(false)
	_beat = -1
	finished.emit(_replay)


func _process(delta: float) -> void:
	_t += delta
	var dur := float((BEATS[_beat] as Dictionary)["dur"]) \
		* (REDUCED_DUR_MULT if _reduced else 1.0)
	if _t >= dur:
		_advance()
		return
	if not _reduced:
		_canvas.queue_redraw()
	_scrim.color = _scrim_for_beat()


func _on_tap(ev: InputEvent) -> void:
	var pressed := (ev is InputEventScreenTouch and (ev as InputEventScreenTouch).pressed) \
		or (ev is InputEventMouseButton and (ev as InputEventMouseButton).pressed)
	if pressed and _t > TAP_GUARD:
		_advance()


# --- the tableaux, in chart language -----------------------------------------

func _p() -> float:
	# Progress through the beat's visual ramp. Reduced motion is the END STATE,
	# immediately -- not the same tween faster.
	if _reduced:
		return 1.0
	var dur := float((BEATS[_beat] as Dictionary)["dur"])
	return clampf(_t / (dur * 0.7), 0.0, 1.0)


func _scrim_for_beat() -> Color:
	match _beat:
		2: return SCRIM_BASE.lerp(SCRIM_COLD, _p())
		3: return SCRIM_COLD
		4: return SCRIM_COLD.lerp(SCRIM_BASE, _p())
		_: return SCRIM_BASE


func _draw_beat() -> void:
	if _beat < 0 or _beat >= BEATS.size():
		return
	var s := _canvas.size
	var p := _p()
	_draw_stars(s, 0.9 if _beat == 0 else 0.5)
	match _beat:
		0: _draw_commission(s, p)
		1: _draw_lattice(s, p, 1.0)
		2: _draw_arithmetic(s, p)
		3: _draw_reclassification(s, p)
		4: _draw_you(s, p)


func _draw_stars(s: Vector2, dim: float) -> void:
	for st_v in _stars:
		var st: Dictionary = st_v
		_canvas.draw_circle((st["p"] as Vector2) * s, float(st["r"]),
			Color(0.85, 0.9, 1.0, float(st["a"]) * dim))


func _draw_commission(s: Vector2, p: float) -> void:
	# One bright star -- the datum. The reference's opening frame, in our sky.
	var at := Vector2(s.x * 0.5, s.y * 0.36)
	var pulse := 1.0 if _reduced else 1.0 + 0.06 * sin(_t * 2.1)
	_canvas.draw_circle(at, 30.0 * pulse * p, Color(0.55, 0.75, 1.0, 0.10 * p))
	_canvas.draw_circle(at, 14.0 * pulse * p, Color(0.7, 0.85, 1.0, 0.22 * p))
	_canvas.draw_circle(at, 4.5, Color(Palette.WHITE_HOT, 0.95 * p))


func _draw_lattice(s: Vector2, p: float, lit: float) -> void:
	# The chart ring and the filed cells lighting outward from it -- the game's
	# own survey language. `lit` scales how far the lighting has reached, so
	# beat 2 can run it backwards.
	var c := Vector2(s.x * 0.5, s.y * 0.40)
	var ring := minf(s.x, s.y) * 0.14
	_canvas.draw_arc(c, ring, 0.0, TAU, 64, Color(Palette.AMBER, 0.55), 1.5)
	var spacing := 30.0
	var reach := p * 8.0 * lit
	for gx in range(-6, 7):
		for gz in range(-6, 7):
			var off := Vector2(float(gx), float(gz)) * spacing
			var d := off.length() / spacing
			if d * spacing <= ring or d > reach:
				continue
			var a := clampf(0.5 - (d / 9.0) * 0.3, 0.08, 0.5)
			_canvas.draw_rect(Rect2(c + off - Vector2(1.5, 1.5),
				Vector2(3.0, 3.0)), Color(Palette.GOLD, a))
	# The instruments, raised in order as the survey reaches them.
	var marks := [Vector2(0.30, 0.22), Vector2(0.72, 0.30), Vector2(0.56, 0.14)]
	for i in range(marks.size()):
		if p * 3.0 < float(i) + 0.6:
			continue
		var m: Vector2 = (marks[i] as Vector2) * s
		_canvas.draw_colored_polygon(PackedVector2Array([
			m + Vector2(0, -5), m + Vector2(4, 0),
			m + Vector2(0, 5), m + Vector2(-4, 0)]),
			Color(Palette.TEAL, 0.8))


func _draw_arithmetic(s: Vector2, p: float) -> void:
	# The lattice, fully lit, and then its outer lights going out inward.
	var c := Vector2(s.x * 0.5, s.y * 0.40)
	var ring := minf(s.x, s.y) * 0.14
	_canvas.draw_arc(c, ring, 0.0, TAU, 64, Color(Palette.AMBER, 0.55), 1.5)
	var spacing := 30.0
	var dark_past := 8.0 * (1.0 - 0.85 * p)
	for gx in range(-6, 7):
		for gz in range(-6, 7):
			var off := Vector2(float(gx), float(gz)) * spacing
			var d := off.length() / spacing
			if d * spacing <= ring or d > dark_past:
				continue
			_canvas.draw_rect(Rect2(c + off - Vector2(1.5, 1.5),
				Vector2(3.0, 3.0)), Color(Palette.GOLD, 0.4))
	# Two chronometers, drifting out of agreement. The whole cause, as a
	# diagram: same dial, different times.
	var drift := (1.9 if _reduced else 1.9 * p)
	for i in range(2):
		var at := Vector2(s.x * (0.36 + 0.28 * float(i)), s.y * 0.145)
		_canvas.draw_arc(at, 24.0, 0.0, TAU, 48, Color(Palette.AMBER, 0.30), 1.2)
		var ang := -PI * 0.5 + (drift if i == 1 else 0.0)
		_canvas.draw_line(at, at + Vector2(cos(ang), sin(ang)) * 19.0,
			Color(Palette.WHITE_HOT, 0.8) if i == 0
			else Color(Palette.THREAT, 0.8), 1.6)


func _draw_reclassification(s: Vector2, p: float) -> void:
	# The unrecalled: dark hulls adrift, and one warden lamp that was never
	# told. A dying ray for what the light used to be.
	_canvas.draw_line(Vector2(s.x * 0.62, 0.0), Vector2(s.x * 0.40, s.y * 0.55),
		Color(Palette.WHITE_HOT, 0.05 * (1.0 - p)), 34.0)
	var hulls := [
		[Vector2(0.30, 0.26), 46.0, 0.28],
		[Vector2(0.62, 0.35), 64.0, -0.12],
		[Vector2(0.44, 0.47), 34.0, 0.55],
	]
	var drift := (0.0 if _reduced else p * 6.0)
	for h_v in hulls:
		var h: Array = h_v
		var at: Vector2 = (h[0] as Vector2) * s + Vector2(drift, 0.0)
		var hull_len: float = float(h[1])
		var rot: float = float(h[2])
		var pts := PackedVector2Array()
		for base in [Vector2(-0.5, 0.0), Vector2(-0.3, -0.12), Vector2(0.34, -0.10),
				Vector2(0.5, 0.0), Vector2(0.34, 0.10), Vector2(-0.3, 0.12)]:
			pts.append(at + (base as Vector2).rotated(rot) * hull_len)
		_canvas.draw_colored_polygon(pts, Color(0.05, 0.06, 0.09, 0.96))
		var line := pts.duplicate()
		line.append(pts[0])
		_canvas.draw_polyline(line, Color(Palette.HULL, 0.14), 1.0)
	var lamp := Vector2(s.x * 0.64, s.y * 0.345)
	var glow := 0.30 if _reduced else 0.24 + 0.10 * (0.5 + 0.5 * sin(_t * 1.3))
	_canvas.draw_circle(lamp, 8.0, Color(Palette.TEAL, glow * 0.35))
	_canvas.draw_circle(lamp, 2.6, Color(Palette.TEAL, 0.9))


func _draw_you(s: Vector2, p: float) -> void:
	# One small hull, crossing the ring outward. The film's last statement is
	# the game's first verb.
	var c := Vector2(s.x * 0.5, s.y * 0.38)
	var ring := minf(s.x, s.y) * 0.14
	_canvas.draw_arc(c, ring, 0.0, TAU, 64, Color(Palette.AMBER, 0.55), 1.5)
	var ang := -PI * 0.25
	var r := ring * (0.55 + 1.1 * p)
	var at := c + Vector2(cos(ang), sin(ang)) * r
	var back := c + Vector2(cos(ang), sin(ang)) * maxf(r - 26.0, 0.0)
	_canvas.draw_line(back, at, Color(Palette.AMBER_DIM.r, Palette.AMBER_DIM.g,
		Palette.AMBER_DIM.b, 0.35), 1.4)
	var fwd := Vector2(cos(ang), sin(ang))
	var side := Vector2(-fwd.y, fwd.x)
	_canvas.draw_colored_polygon(PackedVector2Array([
		at + fwd * 9.0, at - fwd * 5.0 + side * 5.0, at - fwd * 5.0 - side * 5.0]),
		Color(Palette.GOLD, 0.95))
