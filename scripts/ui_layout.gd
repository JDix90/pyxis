class_name UILayout
extends Object
# One place that owns responsiveness, so no UI script invents its own breakpoints.
#
# The game is authored in a 720x1280 portrait space and stretched with
# `canvas_items` + `expand`, which means the canvas scale is
# `min(win_w/720, win_h/1280)`. On a phone that is exactly right — the UI stays a
# fixed fraction of the screen. On a wide desktop window the HEIGHT term wins and
# the whole interface shrinks: at 1440x900 the scale is 0.70, so a 15px label
# renders at ~10 physical pixels, smaller than the same label on a phone.
#
# So the scale boost applies ONLY when the window is wider than the design
# aspect. Portrait windows — every phone — are left exactly as they were.

const BASE := Vector2(720.0, 1280.0)
# The column is capped at the DESIGN width, so a wide window renders the layout
# exactly as authored — just larger — instead of stretching rows into long lines
# with the label at one edge and its buttons at the other.
const COLUMN_MAX := BASE.x
# Window height that maps to 1.0x on desktop. This number decides how much of a
# desktop screen the interface EATS, and 620 was too aggressive: it targeted a
# logical height less than half the phone's 1280, so a round button that occupies
# 5% of a phone screen occupied 12.3% of a desktop one. The rule was written to
# stop the UI shrinking on a wide window and quietly overshot into doubling it.
#
# 820 lands the same button at ~9% on every real desktop size while keeping the
# effective scale at or above 1.0 everywhere (asserted by PYXIS_LAYOUTTEST), so
# nothing renders smaller than authored. Portrait is untouched at exactly 1.0.
# 760 since v21. The 820 above was derived against a window height in DEVICE
# pixels, which on a HiDPI browser is twice the height the player is actually
# looking at -- so the number was answering a different question than the one it
# asks. With the dpr term below correcting the units, the remaining job is the
# original one: how much of a DESKTOP screen the interface should eat.
#
# The floor is not a matter of taste. PYXIS_LAYOUTTEST asserts desktop chrome
# stays within 1.8x the phone's share of screen height, every portrait probe
# resolves to a logical height of 1280, and every wide probe with y >= R clamps
# to exactly R -- so the assertion reduces to 1280/R <= 1.8, i.e. R >= 711.12.
# 760 keeps 6.4% margin against that; the floor itself keeps 0.02%, which is not
# a margin, it is a coincidence waiting to be edited.
const DESKTOP_REFERENCE := 760.0
const MAX_DESKTOP_SCALE := 2.4
# The player-facing slider's range, owned here because three files used to
# hard-code it and a range that disagrees with itself is a range nobody can
# reason about. The ceiling is bounded by A FINGER FITS, not by SHEET FITS: at
# 2.0 the smallest hold cell measures 48.0 against the 42px touch minimum, and
# at 2.2 it is 42.5 -- on the floor, which is not a place to ship.
const USER_SCALE_MIN := 0.7
const USER_SCALE_MAX := 2.0
# A ratio above 3 is a display nobody has; a ratio below 1 is a zoomed-out
# browser, and honouring that would shrink the UI below what the rule authored.
const MAX_DPI := 3.0

# Player-chosen multiplier from the settings panel (save v6). It COMPOSES with
# the rule above rather than replacing it: the automatic factor still does the
# job of stopping a wide desktop window shrinking the interface, and this is a
# preference applied on top. It is also the only thing that can move a portrait
# phone off 1.0 — which is the point, since "the text is too small" is a
# legitimate thing to say about a phone the rule considers already correct.
static var user_scale := 1.0

# devicePixelRatio, and exactly 1.0 everywhere it does not apply. At 1.0 the
# arithmetic in auto_factor reduces algebraically to the line that shipped, so
# native, headless and every harness run are bit-identical.
static var dpi_scale := 1.0


static func refresh_dpi() -> float:
	dpi_scale = probe_dpi()
	return dpi_scale


static func probe_dpi() -> float:
	# WEB ONLY, and deliberately NOT DisplayServer.screen_get_scale() on its own.
	# That returns 2.0 on a native Retina Mac, where Window.size is ALREADY in
	# logical points -- trusting it there would double the interface on every Mac
	# desktop build to fix a bug that only exists in a browser. The web canvas is
	# the one surface that reports device pixels while the player sees CSS ones,
	# so it is the one surface with anything to correct.
	if not OS.has_feature("web"):
		return 1.0
	var s := 0.0
	# Engine.get_singleton + call rather than naming JavaScriptBridge directly:
	# the singleton does not exist off web, and a hard reference is a parse-time
	# dependency on a platform this same file has to run on.
	if Engine.has_singleton("JavaScriptBridge"):
		var v: Variant = Engine.get_singleton("JavaScriptBridge") \
			.call("eval", "window.devicePixelRatio", true)
		if typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT:
			s = float(v)
	if s <= 0.0:
		s = DisplayServer.screen_get_scale()   # web fallback; never reached natively
	if s <= 0.0:
		return 1.0
	return clampf(s, 1.0, MAX_DPI)


static func stretch_scale(win_size: Vector2) -> float:
	return minf(win_size.x / BASE.x, win_size.y / BASE.y)


static func is_wide(win_size: Vector2) -> bool:
	if win_size.y <= 0.0:
		return false
	return (win_size.x / win_size.y) > (BASE.x / BASE.y)


static func effective_scale(win_size: Vector2) -> float:
	return stretch_scale(win_size) * content_factor(win_size)


static func content_factor(win_size: Vector2) -> float:
	return auto_factor(win_size) * user_scale


static func auto_factor(win_size: Vector2) -> float:
	# The automatic rule, with no player preference applied. Kept separate so the
	# layout harness can keep asserting the rule itself.
	var stretch := stretch_scale(win_size)
	if stretch <= 0.0:
		return 1.0
	if not is_wide(win_size):
		# PORTRAIT NEEDS NO DPI TERM, and the reason is worth stating because it
		# looks like an omission. stretch_scale is a PROPORTIONAL mapping -- it
		# fits the design space onto whatever the screen is -- and a proportional
		# mapping is dpr-invariant by construction: twice the device pixels at
		# twice the ratio lands in the same place. A phone browser at dpr 3
		# already renders bit-identically to the native build. There is nothing
		# here to correct.
		return 1.0
	# THE DESKTOP PATH IS ABSOLUTE, which is why it alone needs the ratio.
	# DESKTOP_REFERENCE is a claim about a screen somebody is LOOKING at, and it
	# is compared against a raw pixel count -- so the height has to be in the
	# units they see. Godot's web canvas reports DEVICE pixels while the player
	# sees CSS ones, so on a 2x display this comparison was handed twice the
	# height it should have been: the rule computed 1082/820 = 1.32x, believed it
	# had scaled the interface UP, and rendered it at 0.66x of authored size
	# because every one of those pixels was half-size. A 12px label arrived at
	# 7.9 CSS px. The rule was right by its own metric and wrong in the eye,
	# which is exactly why nothing ever failed.
	var css_h := win_size.y / dpi_scale
	var desired := clampf(css_h / DESKTOP_REFERENCE, 1.0, MAX_DESKTOP_SCALE) * dpi_scale
	# Ceiling raised from 8.0: at dpr 3 with a fully clamped desired the numerator
	# reaches 7.2, and a narrow tall canvas can make `stretch` small enough that
	# the old cap would bind on the ratio rather than on anything real.
	return clampf(desired / stretch, 1.0, 12.0)


static func apply_scale(win: Window) -> void:
	if win == null:
		return
	# Re-probed rather than cached once: browser zoom CHANGES devicePixelRatio and
	# fires a canvas resize, and main.gd already reconnects this to size_changed.
	refresh_dpi()
	win.content_scale_factor = content_factor(Vector2(win.size))


# --- column helpers ---------------------------------------------------------

static func column(root: Control, max_w := COLUMN_MAX) -> void:
	# Full-rect root capped to a centred column. Every anchor inside it then
	# resolves against a portrait-shaped area instead of the whole window, which
	# is what stops corner controls drifting a thousand pixels apart.
	if root == null or not root.is_inside_tree():
		return
	var vp := root.get_viewport_rect().size
	var margin := maxf((vp.x - minf(vp.x, max_w)) * 0.5, 0.0)
	root.anchor_left = 0.0
	root.anchor_right = 1.0
	root.anchor_top = 0.0
	root.anchor_bottom = 1.0
	root.offset_left = margin
	root.offset_right = -margin
	root.offset_top = 0.0
	root.offset_bottom = 0.0


static func chrome(root: Control) -> void:
	# Corner-anchored HUD chrome hugs the REAL screen corners.
	#
	# The sheet consoles stay capped at the design column, and should: a market
	# row stretched across an ultrawide puts the label at one edge and its
	# buttons at the other. But the diegetic controls are not rows — they are
	# corners — and running them through the same cap inset them 337px from each
	# screen edge on a full-screen Mac window, parking CHART, REFIT and the
	# ability button in the play area they are supposed to frame.
	#
	# On portrait this is a no-op: the logical width there is exactly the design
	# width, so the column already spanned the full screen and every phone
	# renders bit-identically to before.
	if root == null or not root.is_inside_tree():
		return
	root.anchor_left = 0.0
	root.anchor_right = 1.0
	root.anchor_top = 0.0
	root.anchor_bottom = 1.0
	root.offset_left = 0.0
	root.offset_right = 0.0
	root.offset_top = 0.0
	root.offset_bottom = 0.0


static func column_horizontal(c: Control, max_w := COLUMN_MAX) -> void:
	# Horizontal-only version for the bottom sheets, whose vertical offsets are
	# driven by their slide animation and must not be touched.
	if c == null or not c.is_inside_tree():
		return
	var vp := c.get_viewport_rect().size
	var margin := maxf((vp.x - minf(vp.x, max_w)) * 0.5, 0.0)
	c.anchor_left = 0.0
	c.anchor_right = 1.0
	c.offset_left = margin
	c.offset_right = -margin


static func column_width(win_size: Vector2, max_w := COLUMN_MAX) -> float:
	var logical := win_size.x / maxf(effective_scale(win_size), 0.001)
	return minf(logical, max_w)


static func describe(win_size: Vector2) -> String:
	var eff := effective_scale(win_size)
	return "win %.0fx%.0f wide=%s stretch %.3f factor %.3f effective %.3f logical %.0fx%.0f column %.0f" % [
		win_size.x, win_size.y, str(is_wide(win_size)), stretch_scale(win_size),
		content_factor(win_size), eff,
		win_size.x / maxf(eff, 0.001), win_size.y / maxf(eff, 0.001),
		column_width(win_size)]
