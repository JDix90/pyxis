class_name RoundButton
extends Control
# Circular console button with an optional radial cooldown sweep.
# Corner-anchored, thumb-sized, drawn entirely in code so it inherits the
# palette without any texture assets.

signal pressed

const RADIUS := 34.0
const TOUCH_PAD := 6.0

var label := ""
var accent := Palette.AMBER
var cooldown_fraction := 0.0:  # 1.0 = fully on cooldown
	set(v):
		cooldown_fraction = clampf(v, 0.0, 1.0)
		queue_redraw()
var enabled := true:
	set(v):
		enabled = v
		queue_redraw()
var glowing := false:  # ability currently active
	set(v):
		glowing = v
		queue_redraw()

# Per-instance size multiplier. An instance property rather than a change to
# RADIUS because RADIUS is a const the layout harness measures the HUD footprint
# against (main.gd), and because only ONE button should be emphasised: the
# ability, which is the one pressed under pressure and therefore sits at the
# centre of the action dock.
var radius_scale := 1.0:
	set(v):
		radius_scale = maxf(v, 0.1)
		_resize()
		queue_redraw()

var _held := false


func _ready() -> void:
	_resize()
	mouse_filter = Control.MOUSE_FILTER_STOP


func _resize() -> void:
	var r := RADIUS * radius_scale
	custom_minimum_size = Vector2(r * 2 + TOUCH_PAD * 2, r * 2 + TOUCH_PAD * 2)
	size = custom_minimum_size
	pivot_offset = size * 0.5


func radius() -> float:
	return RADIUS * radius_scale


func _draw() -> void:
	var c := size * 0.5
	var r := radius()
	var ring := accent if enabled else Color(accent.r, accent.g, accent.b, 0.3)
	var fill_a := 0.22 if enabled else 0.08
	if glowing:
		draw_circle(c, r + 7.0, Color(accent.r, accent.g, accent.b, 0.18))

	draw_circle(c, r, Color(0.03, 0.04, 0.06, 0.85))
	draw_circle(c, r - 2.0, Color(accent.r, accent.g, accent.b, fill_a))
	draw_arc(c, r, 0.0, TAU, 48, ring, 2.5, true)

	# Cooldown sweeps clockwise from 12 o'clock as it empties.
	if cooldown_fraction > 0.001:
		draw_circle(c, r - 3.0, Color(0.0, 0.0, 0.0, 0.55))
		var start := -PI * 0.5
		draw_arc(c, r - 6.0, start, start + TAU * (1.0 - cooldown_fraction),
			40, Color(accent.r, accent.g, accent.b, 0.85), 4.0, true)

	if label != "":
		var font := ThemeDB.fallback_font
		var fsize := 10 if radius_scale <= 1.05 else 11
		# Shrink to fit rather than spill past the rim. Ability names come from
		# the Core module and vary in length — "OVERCHARGE" is half again as wide
		# as "AEGIS" — and the ability button is now the centrepiece of the dock,
		# so a label running outside its own circle is the first thing you notice.
		var usable := (r - 5.0) * 2.0
		while fsize > 7 and font.get_string_size(
				label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x > usable:
			fsize -= 1
		var text_w := font.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, fsize).x
		var col := ring if enabled else Color(ring.r, ring.g, ring.b, 0.4)
		draw_string(font, c + Vector2(-text_w * 0.5, 4.0), label,
			HORIZONTAL_ALIGNMENT_LEFT, -1, fsize, col)


func _gui_input(event: InputEvent) -> void:
	var press := false
	var release := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		press = event.pressed
		release = not event.pressed
	elif event is InputEventScreenTouch:
		press = event.pressed
		release = not event.pressed

	if press:
		_held = true
		accept_event()
		_pop(0.92)
	elif release and _held:
		_held = false
		accept_event()
		_pop(1.0)
		if enabled:
			pressed.emit()


func _pop(to: float) -> void:
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2(to, to), 0.08)
	if to < 1.0:
		return
	tw.tween_property(self, "scale", Vector2.ONE, 0.12)
