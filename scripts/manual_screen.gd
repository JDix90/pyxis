class_name ManualScreen
extends CanvasLayer
# The pilot's manual, in the game rather than beside it.
#
# Reachable from BOTH the title screen and the pause menu, which is the whole
# reason it is its own node instead of a fourth page inside pause_menu.gd: the
# title screen has no page system, and a new player is exactly the person who
# needs this before they have ever pressed NEW SURVEY.
#
# IT NEVER TOUCHES `get_tree().paused`, and that is load-bearing rather than an
# omission. It opens over the title screen (running) and over the pause sheet
# (already paused), so pausing on open would be wrong in the first case and
# unpausing on close would resume the game out from under the pause menu in the
# second. Whoever opened it owns the pause state; this node only draws.
#
# PROCESS_MODE_ALWAYS for the same reason everything in pause_menu.gd is: a
# console that stops processing when the tree pauses cannot be scrolled or
# closed, and this one is most often opened from a paused game.
#
# WHAT IT SAYS IS DERIVED, NOT RESTATED. Every number on these pages is read out
# of the data that defines it -- the reactor's power from ModuleDB, the band
# names from DeepSpace, the ore count from CommodityDB, the tier count from
# GameState. A manual that hardcodes "12 power" is a manual that lies the first
# time somebody retunes REACTOR_TIERS, and a lying manual is worse than none.
# PYXIS_MANUALTEST asserts the derivation rather than the wording.

const FADE_TIME := 0.16
const SCRIM := Color(0.01, 0.012, 0.02, 0.90)
# Wider than the pause sheet's 340: this is prose rather than a button column,
# and 340 at font 12 gives a measure short enough to hyphenate badly on a phone.
const SHEET_WIDTH := 360.0
const SHEET_MARGIN := 56.0
const MIN_SHEET := 160.0

# The contents, in the order a new pilot needs them: how to fly, how to read the
# screen, what the ship is, where you can go, how you make a living, what to do
# first. Data rather than six hand-written buttons so the contents page and the
# router can never disagree about which pages exist.
const PAGES := [
	{"id": "flying",  "title": "FLYING"},
	{"id": "hud",     "title": "READING THE HUD"},
	{"id": "ship",    "title": "YOUR SHIP"},
	{"id": "deep",    "title": "THE DEEP"},
	{"id": "living",  "title": "MAKING A LIVING"},
	{"id": "first",   "title": "YOUR FIRST HOUR"},
]

var is_open := false

var _root: Control
var _scrim: ColorRect
var _panel: PanelContainer
var _scroll: ScrollContainer
var _body: VBoxContainer
var _page := "contents"


func _ready() -> void:
	# Above the title screen and the pause menu, which both sit at 6. It has to
	# cover whichever of them opened it.
	layer = 7
	process_mode = Node.PROCESS_MODE_ALWAYS
	add_to_group("manual_screen")
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
	# STOP, like the pause scrim: a tap that misses a control must not fall
	# through to the ship underneath.
	_scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(_scrim)

	_panel = PanelContainer.new()
	_panel.set_anchors_preset(Control.PRESET_CENTER)
	_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	_panel.custom_minimum_size = Vector2(SHEET_WIDTH, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.04, 0.98)
	style.border_color = Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.45)
	style.set_border_width_all(2)
	style.set_corner_radius_all(14)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 16
	style.content_margin_bottom = 16
	_panel.add_theme_stylebox_override("panel", style)
	_root.add_child(_panel)

	# The same capped-scroll construction §27 put on the pause sheet, for the same
	# reason: a PanelContainer centred with grow-BOTH and no clip pushes its
	# heading off the top and its last control off the bottom at once. A manual
	# page is LONGER than any pause page, so this is not a precaution here, it is
	# the only thing that makes these pages readable at all.
	_scroll = ScrollContainer.new()
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_panel.add_child(_scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 8)
	_scroll.add_child(_body)


func _apply_layout() -> void:
	UILayout.column(_root)
	_clamp_height()


func _clamp_height() -> void:
	if _scroll == null or _root == null:
		return
	var avail := maxf(_root.size.y - SHEET_MARGIN, MIN_SHEET)
	_scroll.custom_minimum_size.y = minf(_body.get_combined_minimum_size().y, avail)


# --- open / close -----------------------------------------------------------

func open() -> void:
	if is_open:
		return
	is_open = true
	_page = "contents"
	visible = true
	_refresh()
	Sfx.play("tap", -8.0, 0.9)
	if GameState.reduce_motion():
		_root.modulate.a = 1.0
		return
	_root.modulate.a = 0.0
	var tw := create_tween()
	tw.set_ignore_time_scale(true)
	tw.tween_property(_root, "modulate:a", 1.0, FADE_TIME)


func close_panel() -> void:
	# Named to match every other console so CameraRig's escape ladder and any
	# future "close whatever is open" loop can treat them all alike.
	if not is_open:
		return
	is_open = false
	visible = false
	Sfx.play("tap", -12.0, 1.1)


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	if event.is_action_pressed("cancel"):
		# The same one-step-at-a-time ladder the rest of the game uses: a section
		# backs out to the contents, and the contents back out of the manual.
		if _page != "contents":
			_page = "contents"
			_refresh()
		else:
			close_panel()
		get_viewport().set_input_as_handled()


# --- pages ------------------------------------------------------------------

func _refresh() -> void:
	# REMOVED as well as freed, and that pairing is the whole reason this page
	# measures correctly. queue_free() is DEFERRED -- the outgoing page's children
	# are still in _body while the incoming page's are being added, so the
	# _clamp_height() at the bottom of this function would measure BOTH pages at
	# once and size the sheet for a page that no longer exists. It clamped the
	# Deep page to 456 rows against a true 435 until this line paired the two.
	#
	# "queue_free'd children still appear in get_children() that same frame" is
	# already written down in this repo's harness notes; this is that trap in
	# ordinary UI code rather than in a test.
	for c in _body.get_children():
		_body.remove_child(c)
		c.queue_free()
	match _page:
		"contents": _build_contents()
		"flying":   _build_flying()
		"hud":      _build_hud()
		"ship":     _build_ship()
		"deep":     _build_deep()
		"living":   _build_living()
		"first":    _build_first()
		_:          _build_contents()
	# Per-PAGE, not per-window: these pages differ wildly in length, and
	# re-measuring only on resize would leave a short page wearing a long one's
	# height. pause_menu.gd records the same trap.
	_clamp_height()


func _build_contents() -> void:
	_body.add_child(_heading("PILOT'S MANUAL"))
	_body.add_child(_sub("GSA SURVEY AUTHORITY · FIRST DEPLOYMENT"))
	_body.add_child(_spacer(6))
	for entry_v in PAGES:
		var entry: Dictionary = entry_v
		var id := String(entry["id"])
		_body.add_child(_action(String(entry["title"]), Palette.AMBER, func() -> void:
			_page = id
			_refresh()))
	_body.add_child(_spacer(6))
	_body.add_child(_action("CLOSE", Palette.TEAL, close_panel))


func _build_flying() -> void:
	_body.add_child(_heading("FLYING"))
	# Asked of the DEVICE rather than assumed, the same way Tutorial._text_for
	# does it: the two schemes are genuinely different verbs and a manual that
	# describes the wrong one is worse than a manual nobody opened.
	if _touch():
		_body.add_child(_row("TAP A BEARING", "Fly there."))
		_body.add_child(_row("TAP A CONTACT", "Engage it. Your mounts fire on the locked target by themselves."))
		_body.add_child(_row("TAP OVERCHARGE", "Discharge your fitted core."))
	else:
		# ASKED OF THE INPUT MAP, not typed. Every key on this page used to be a
		# hand-written literal -- "W A S D", "SPACE", "I" -- which was false for
		# any player who had used the rebinding page two taps away in settings:
		# the manual went on saying I while the game answered to something else.
		# GameState.binding_name is the same reader the settings rows use, so the
		# page cannot disagree with the page that changed it.
		_body.add_child(_row("%s %s %s %s" % [
			GameState.binding_name("move_up"), GameState.binding_name("move_left"),
			GameState.binding_name("move_down"), GameState.binding_name("move_right")],
			"Hold to fly."))
		_body.add_child(_row("CLICK / %s" % GameState.binding_name("cycle_target"),
			"Engage a contact. Your mounts fire on the locked target by themselves."))
		_body.add_child(_row(GameState.binding_name("ability"), "Discharge your fitted core."))
		_body.add_child(_row(GameState.binding_name("toggle_hold"),
			"Open the manifest. The same sheet the HOLD readout opens, and it works in flight."))
		_body.add_child(_row(GameState.binding_name("chart"),
			"Open the chart. Shut while docked and during an apex fight, exactly like the button."))
		_body.add_child(_row(GameState.binding_name("drop_beacon"),
			"Drop a beacon where you are standing. Deep space only, %d in stock, and holding on one takes it back." % GameState.BEACON_STOCK))
		# v21. The two verbs the chart adds to a beacon, taught beside the one
		# that creates them. THREE verbs, named together on purpose: a bookmark
		# you cannot return to is half a feature, and until this row the only
		# documented thing you could do with a beacon was pick it back up.
		_body.add_child(_row("CHART",
			"Every beacon in this system gets a row. COURSE flies you there for free and drops itself if anything goes wrong; JUMP puts you there at once for a fee, and refuses past the depth the colony network reaches."))
		_body.add_child(_row(GameState.binding_name("pause"),
			"Pause, and unpause again from any page of the pause menu. This page keeps its own back-out."))
		# Desktop only, and the manual says so by only appearing here — the same
		# device question the branch above is asked for. Touch has no gesture for
		# this yet; a manual that described one would be describing the wrong verb.
		_body.add_child(_row("RIGHT CLICK", "Hail a flagged ship that is not shooting at you. What it will discuss depends on how its faction regards you."))
	_body.add_child(_row("HOLD", "Fly close and hold on a derelict, a survey mast or an ore seam to work it. Cracking, reading and cutting are all the same gesture."))
	_body.add_child(_spacer(6))
	_body.add_child(_para("CANCEL backs out exactly one step, never two:"))
	# ASKED OF THE DEVICE, like the gestures above, because the ladder is not the
	# same length on both. CameraRig._cancel puts the contact menu on the top
	# rung, and the only way to raise one is a right-click -- so on touch that
	# rung is unreachable and naming it would describe a step the player cannot
	# be standing on. The numbering has to shift with it, which is the whole
	# reason this is built rather than written: a fourth rung was added above a
	# hard-coded list of three and the page went quietly false.
	var rung := 1
	if not _touch():
		_body.add_child(_para("%d.  a contact menu is open, so it closes" % rung))
		rung += 1
	_body.add_child(_para("%d.  a console is open, so it closes" % rung))
	_body.add_child(_para("%d.  a target is locked, so the lock drops" % (rung + 1)))
	_body.add_child(_para("%d.  a course is set, so the course drops" % (rung + 2)))
	_body.add_child(_para("%d.  otherwise the game pauses" % (rung + 3)))
	_body.add_child(_back())


func _build_hud() -> void:
	_body.add_child(_heading("READING THE HUD"))
	_body.add_child(_row("SALVAGE", "What you have earned and can spend at any outfitter."))
	_body.add_child(_row("HOLD", "Cargo used against capacity. A full hold refuses new loot and refuses a cut. Tap it to open the manifest."))
	_body.add_child(_row("HULL", "Shields take the hit first. Hull damage is the part that does not come back on its own."))
	_body.add_child(_row("HDG", "Which way your nose is pointing: a three-figure heading and the quarter of the sky it falls in. Every bearing you are given is in the same figures."))
	_body.add_child(_row("CRS", "Only while a course is running: the bearing and range to the beacon you set it for. When CRS and HDG agree you are flying it. The ship drops the course by itself on contact, on a hurt hull or on a stun, and says so."))
	_body.add_child(_spacer(6))
	_body.add_child(_para("THE RADAR RING marks what is off screen, nearest first:"))
	_body.add_child(_legend(Palette.TEAL, "HOME", "The way back to charted space, whenever you are outside it. This is a compass, not a ping — it does not fade near the edge."))
	_body.add_child(_legend(Palette.THREAT, "APEX", "The system's boss. It only appears once you are close enough to see it."))
	_body.add_child(_legend(Palette.TEAL, "PORT", "Somewhere to dock."))
	_body.add_child(_legend(Palette.AMBER, "SITE", "A derelict to breach, a mast to read, or a convoy passing through."))
	_body.add_child(_legend(Palette.THREAT, "HOSTILE", "Something that will fire on you. Red means exactly that and nothing else — a flagged ship that is not hunting you wears its faction's colour instead."))
	_body.add_child(_legend(Palette.HULL, "SEAM", "Ore on a rock. Grey until MINING teaches it to show its colour."))
	_body.add_child(_legend(Palette.GOLD, "GHOST", "Where your readings agree the engine is. It is a guess, and it moves as you gather more."))
	_body.add_child(_legend(Palette.GOLD, "BEACON", "A waypoint you dropped. %d in stock; hold on one to take it back." % GameState.BEACON_STOCK))
	_body.add_child(_legend(Palette.band_color(DeepSpace.BAND_NAMES.size() - 1), "STORM", "Weather in the deepest band. It pulls you in and it kills drives. Fly around it, or carry a Thermal Sink through it."))
	_body.add_child(_legend(Palette.HULL, "ODDITY", "Something only this system has, standing in its own bands. One will talk to you, one will burn you, one will give you a bearing for nothing."))
	_body.add_child(_back())


func _build_ship() -> void:
	_body.add_child(_heading("YOUR SHIP"))
	# Derived: the slot count and the starting reactor are facts about the data,
	# and a manual is the last place they should be retyped by hand.
	_body.add_child(_para("%d slots against one power budget. The first reactor gives you %d power, and the starter fit already draws %d of it." % [
		ModuleDB.SLOT_NAMES.size(), ModuleDB.reactor_power(0),
		ModuleDB.power_draw(ModuleDB.STARTER_FIT)]))
	_body.add_child(_spacer(4))
	for slot_v in ModuleDB.SLOT_NAMES:
		var fitted := String(ModuleDB.STARTER_FIT.get(slot_v, ""))
		var label := "empty"
		if fitted != "":
			label = String(ModuleDB.get_module(fitted).get("name", fitted))
		_body.add_child(_row(String(ModuleDB.SLOT_NAMES[slot_v]), label))
	_body.add_child(_spacer(6))
	_body.add_child(_para("Nothing in the catalogue is a straight upgrade. Every module trades one thing for another, and the two utility slots are where a ship stops being general and starts being FOR something."))
	_body.add_child(_back())


func _build_deep() -> void:
	_body.add_child(_heading("THE DEEP"))
	_body.add_child(_para("Past the charted edge, distance is the difficulty. Each band is stranger, richer and less patrolled than the last, and a beacon tells you when you have crossed."))
	_body.add_child(_spacer(4))
	# Straight out of DeepSpace, glyph and all, so a renamed band renames itself
	# here. The glyph matters: it is what the colour-vision modes read instead of
	# the colour, and the manual must speak the same language the HUD does.
	for i in range(DeepSpace.BAND_NAMES.size()):
		var glyph := Palette.band_glyph(i)
		# NOT `name`: that is Node.name, and shadowing it here would compile but
		# leave the next reader wondering which one they are reading.
		var band_name := String(DeepSpace.BAND_NAMES[i])
		_body.add_child(_legend(Palette.band_color(i),
			("%s  %s" % [glyph, band_name]) if glyph != "" else band_name,
			_band_note(i)))
	_body.add_child(_back())


func _band_note(band: int) -> String:
	match band:
		0: return "Home. Patrolled, mapped, and where your first derelict is."
		1: return "Security stops here. A fallen survey pylon marks the edge."
		2: return "Nobody has swept this lane in a long time."
		3: return "Past where the beacons reliably answer."
		4: return "Nothing is transmitting. Nothing is listening."
		# The frontier's two say what is DIFFERENT out there, not merely that it
		# is worse -- a note reading "even more dangerous" teaches nothing a
		# bigger number would not. One names the thing you can dock at; the other
		# names the thing you cannot outrun.
		5: return "There are lights out here, and somebody keeps them. Their guns are for sale."
		6: return "Nothing is transmitting. Something is listening. It follows further than anything closer in."
	return ""


func _build_living() -> void:
	_body.add_child(_heading("MAKING A LIVING"))
	_body.add_child(_row("SALVAGE", "Kills and derelicts drop crates. Fly through one to take it."))
	_body.add_child(_row("TRADE", "Buy where a good is cheap and sell where it is dear. Every port prices differently, and a big trade moves the price against you."))
	_body.add_child(_row("CONTRACTS", "A board at every port. Two run at once, and finishing one offers another."))
	_body.add_child(_row("MINING", "%d ores on the flanks of rocks, charted space and out. Hold to cut; the seam yields the finished good with no refining step." % CommodityDB.ore_ids().size()))
	# THE RAIDER TOLL, WRITTEN DOWN AT LAST (v18, playtest round 4). This file had
	# no occurrence of the word "toll" anywhere in it, and the tutorial
	# structurally cannot teach the parley — interdiction_eligible() excludes an
	# active tutorial, which is asserted. So the only way a player ever met a
	# demand was mid-flight with six seconds on the clock, and a playtester
	# reported the whole system missing. A manual page is the one place it can be
	# read at rest.
	_body.add_child(_row("A TOLL", "Raiders with something to take will demand a cut of your hold instead of opening fire. You get a few seconds and three plates: PAY hands over the cargo, REFUSE starts the fight, TALK THEM DOWN gambles on your mouth. Doing nothing is refusing slowly."))
	_body.add_child(_spacer(6))
	# Derived count, static description: the tiers are named in GameState and
	# their number is the thing most likely to change.
	# THE LADDERS ARE NO LONGER THE SAME LENGTH, so "each has N tiers" became a
	# lie the moment the frontier gave archeology two more rungs — and it lied
	# about precisely the rungs that make the deepest salvage readable, telling
	# the player the only thing that opens the Fathoms does not exist. Both
	# numbers are derived, and the sentence now says which skill is the long one.
	_body.add_child(_para("Four skills, each fed by a different verb so no single run levels them all: ARCHEOLOGY reads salvage, SMUGGLING moves what a market will not touch, MINING cuts rock, PERSUASION talks a pack out of a toll. Most have %d tiers and ARCHEOLOGY has %d, because the deepest salvage needs the last two. Not one of them pays you in credits — they buy information, a choice, and access." % [GameState.MINING_TIERS.size() - 1, GameState.ARCHEOLOGY_TIERS.size() - 1]))
	_body.add_child(_back())


func _build_first() -> void:
	_body.add_child(_heading("YOUR FIRST HOUR"))
	_body.add_child(_para("In order. This is the one place the order matters."))
	_body.add_child(_spacer(4))
	var steps := [
		"Fly the guided steps. Nothing else spawns until they are done.",
		"Dock at Waypoint Anchor. Read the market, then the outfitter.",
		"Buy one utility module. It is the first real choice you make.",
		"Take the two contracts already on your board.",
		"Cross into the Shoals at least once and listen to the beacon.",
		"Find the derelict. Hold on any seam you pass on the way.",
		"Decide what you are building toward — you only have two utility slots.",
	]
	var n := 0
	for s in steps:
		n += 1
		_body.add_child(_row("%d" % n, String(s)))
	_body.add_child(_back())


# --- widgets ----------------------------------------------------------------

func _touch() -> bool:
	return DisplayServer.is_touchscreen_available()


func _heading(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 20)
	l.add_theme_color_override("font_color", Palette.GOLD)
	return l


func _sub(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", Palette.AMBER_DIM)
	return l


func _para(text: String) -> Label:
	# LEFT aligned, unlike everything in pause_menu.gd, and that is deliberate
	# rather than inconsistent: the pause sheet is a column of controls and reads
	# as a menu, while this is prose. Centred prose is markedly harder to read at
	# more than a line and a half, which most of these are.
	var l := Label.new()
	l.text = text
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(300, 0)
	l.add_theme_font_size_override("font_size", 12)
	l.add_theme_color_override("font_color", Palette.AMBER_DIM)
	return l


func _row(key: String, text: String) -> Control:
	# A labelled line: the control or the term in the ship's own voice, and what
	# it does underneath it.
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	var k := Label.new()
	k.text = key
	k.add_theme_font_size_override("font_size", 12)
	k.add_theme_color_override("font_color", Palette.GOLD)
	box.add_child(k)
	var v := Label.new()
	v.text = text
	v.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.custom_minimum_size = Vector2(300, 0)
	v.add_theme_font_size_override("font_size", 11)
	v.add_theme_color_override("font_color", Palette.AMBER_DIM)
	box.add_child(v)
	return box


func _legend(swatch: Color, name: String, text: String) -> Control:
	# A colour chip beside the name, because the thing being explained IS a
	# colour on the radar. The chip is drawn from Palette.band_color and friends,
	# so a colour-vision mode recolours this page along with the HUD it explains.
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var dot := ColorRect.new()
	dot.color = swatch
	dot.custom_minimum_size = Vector2(10, 10)
	# BEGIN rather than CENTER: the text beside it is two lines, so centring puts
	# the chip level with the gap between the name and its description instead of
	# with the name it belongs to.
	dot.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	row.add_child(dot)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 1)
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var n := Label.new()
	n.text = name
	n.add_theme_font_size_override("font_size", 12)
	n.add_theme_color_override("font_color", Palette.HULL)
	box.add_child(n)
	var d := Label.new()
	d.text = text
	d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	d.custom_minimum_size = Vector2(280, 0)
	d.add_theme_font_size_override("font_size", 11)
	d.add_theme_color_override("font_color", Palette.AMBER_DIM)
	box.add_child(d)
	row.add_child(box)
	return row


func _spacer(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _action(text: String, accent: Color, cb: Callable) -> Button:
	var b := UIKit.button(text, accent, 13)
	b.pressed.connect(func() -> void:
		UIKit.press_pop(b)
		cb.call())
	return b


func _back() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	box.add_child(_spacer(4))
	box.add_child(_action("BACK", Palette.TEAL, func() -> void:
		_page = "contents"
		_refresh()))
	return box
