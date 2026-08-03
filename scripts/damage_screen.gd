class_name DamageScreen
extends CanvasLayer
# DAMAGE CONTROL. The one console that stops the clock.
#
# Every other sheet in this game deliberately does NOT pause -- §14's rule is
# that a raid must not begin behind something the player cannot see past, and
# console_camping() exists because a sheet open at speed is a shield rather than
# a document. This one is the exception, and it earns it by being the panel you
# open when you are about to die: a decision made at 12% integrity with a swarm
# on you is not a decision anybody can make while flying.
#
# It still registers as a console (main.console_open), so the raid roll cannot
# fire behind it even in the frames around the pause going up and down. Belt and
# braces, and cheap.
#
# WHAT IT DOES. Sections are derived from live integrity (SectionDB) and cost
# nothing by themselves -- the pool they are read from has already been paid.
# A DAMAGED section can be burned: its power goes to a working section, which is
# overcharged for it, and the burned section stays dark until the ship docks.
# That is the whole trade, and it is meant to be bad news taken on purpose.

# 400, not 460. The logical canvas on a portrait phone is 720 / user_scale, and
# the settings slider caps user_scale at 1.6 -- so the narrowest supported canvas
# is 450px and a 460px sheet hung five pixels off each edge with its border
# clipped. Every other centred sheet is already under that ceiling (pause menu
# 340, manual 360); this one had no UILayout call and no clamp to catch it.
const PANEL_W := 400.0
const ROW_H := 62.0

signal closed

var is_open := false

var _root: Control
var _sheet: PanelContainer
var _rows: VBoxContainer
var _title: Label
var _status: Label
var _hint: Label
# The section the player has armed as a power SOURCE, or "" for none. Two taps
# to commit -- the same confirm shape the hold's dump button uses, because this
# is likewise irreversible until a dock.
var _armed := ""


func _ready() -> void:
	# ALWAYS, because this node is the thing holding the pause. A panel that
	# paused the tree and then stopped processing could never un-pause itself.
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 12
	visible = false
	_build()


func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_root)

	# A scrim, so the paused world reads as stopped rather than as a frame that
	# happens to be still.
	var scrim := ColorRect.new()
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.color = Color(0.02, 0.02, 0.05, 0.72)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	_root.add_child(scrim)

	_sheet = PanelContainer.new()
	_sheet.set_anchors_preset(Control.PRESET_CENTER)
	_sheet.grow_horizontal = Control.GROW_DIRECTION_BOTH
	_sheet.grow_vertical = Control.GROW_DIRECTION_BOTH
	_sheet.custom_minimum_size = Vector2(PANEL_W, 0)
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.05, 0.05, 0.08, 0.98)
	style.border_color = Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.55)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_sheet.add_theme_stylebox_override("panel", style)
	_root.add_child(_sheet)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	_sheet.add_child(col)

	_title = Label.new()
	_title.text = "DAMAGE CONTROL"
	_title.add_theme_color_override("font_color", Palette.AMBER)
	_title.add_theme_font_size_override("font_size", 20)
	col.add_child(_title)

	_status = Label.new()
	_status.add_theme_color_override("font_color", Palette.TEAL)
	_status.add_theme_font_size_override("font_size", 13)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.custom_minimum_size = Vector2(PANEL_W - 36, 0)
	col.add_child(_status)

	_rows = VBoxContainer.new()
	_rows.add_theme_constant_override("separation", 4)
	col.add_child(_rows)

	_hint = Label.new()
	_hint.add_theme_color_override("font_color", Palette.AMBER_DIM)
	_hint.add_theme_font_size_override("font_size", 12)
	_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint.custom_minimum_size = Vector2(PANEL_W - 36, 0)
	col.add_child(_hint)

	var close := Button.new()
	close.text = "RESUME"
	close.custom_minimum_size = Vector2(0, 40)
	close.pressed.connect(close_panel)
	col.add_child(close)


func _unhandled_input(event: InputEvent) -> void:
	# ESCAPE IS HANDLED HERE, not by CameraRig's ladder. The rig stops receiving
	# input the instant the tree pauses -- its own comment says so about the
	# pause menu -- so a sheet that pauses has to own its own way out or the key
	# does nothing and the game reads as hung.
	if not is_open:
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close_panel()


func _integrity() -> float:
	var p: Node = get_tree().get_first_node_in_group("player")
	if p == null or not p.has_method("shield_fraction"):
		return 1.0
	return float(p.shield_fraction())


func _refresh() -> void:
	for c in _rows.get_children():
		c.queue_free()

	var integrity := _integrity()
	var damaged := SectionDB.damaged_ids(integrity)
	_status.text = "INTEGRITY %d%%  ·  %d SECTION%s DAMAGED" % [
		int(round(integrity * 100.0)), damaged.size(),
		"" if damaged.size() == 1 else "S"]
	_status.add_theme_color_override("font_color",
		Palette.TEAL if damaged.is_empty() else Palette.THREAT)

	for id_v in SectionDB.ids():
		_rows.add_child(_build_row(String(id_v), integrity))

	if _armed != "":
		_hint.text = "%s IS ARMED. TAP A WORKING SECTION TO SEND IT THAT POWER — the armed section goes dark until you dock." \
			% String(SectionDB.section(_armed).get("name", ""))
	elif not damaged.is_empty() and _nothing_can_be_spent(integrity):
		# The honest version of the dead end rather than a hint that lies. A
		# player at 15% with the core already carrying power has damaged sections
		# and nowhere to put them, and telling them to tap one would be an
		# instruction the sheet cannot honour.
		_hint.text = "NOWHERE LEFT TO SEND POWER. Every working section is already carrying some, or shares a system with what is broken. Dock to restore."
	elif damaged.is_empty():
		_hint.text = "ALL SECTIONS NOMINAL. Power can only be diverted OUT of a damaged section, so there is nothing to trade yet."
	else:
		_hint.text = "TAP A DAMAGED SECTION to take its power. You lose it until you dock — this is a last resort, not a loadout."


func _build_row(id: String, integrity: float) -> Control:
	var def := SectionDB.section(id)
	var damaged := SectionDB.is_damaged(id, integrity)
	var burned: bool = GameState.diverts.has(id)
	var boosted: bool = GameState.diverts.values().has(id)

	var row := Button.new()
	row.custom_minimum_size = Vector2(0, ROW_H)
	row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	row.clip_text = false

	# STATE, IN WORDS, because a colour alone is the accessibility mistake the
	# band glyphs already fixed once (§55): amber-on-rose is close to a worst
	# case for the two commonest forms of colour blindness.
	var state := "NOMINAL"
	var tint := Palette.TEAL
	if burned:
		state = "DARK — POWER SENT TO %s" % String(
			SectionDB.section(String(GameState.diverts[id])).get("name", "?"))
		tint = Palette.AMBER_DIM
	elif boosted:
		state = "OVERCHARGED"
		tint = Palette.GOLD
	elif damaged:
		state = "DAMAGED"
		tint = Palette.THREAT
	elif id == _armed:
		state = "ARMED"
		tint = Palette.AMBER

	row.text = "%s\n%s · %s" % [String(def.get("name", id)), state,
		String(def.get("blurb", ""))]
	row.add_theme_color_override("font_color", tint)
	row.add_theme_font_size_override("font_size", 13)
	# A row that cannot be acted on says so by being unpressable, rather than by
	# accepting a tap and doing nothing.
	row.disabled = not _row_actionable(id, damaged, burned, boosted)
	row.pressed.connect(func() -> void: _on_row(id, damaged))
	return row


func _row_actionable(id: String, damaged: bool, burned: bool, boosted: bool) -> bool:
	if burned or boosted:
		return false
	if _armed == "":
		# ARMING NEEDS SOMEWHERE TO SEND IT. Without the second half this panel
		# dead-ends at exactly the integrity it exists for: below 22% every
		# section but the core is damaged, and once the core has taken a boost
		# there is no legal target left -- so the sheet accepted an arm, told the
		# player to "TAP A WORKING SECTION", and offered five disabled rows and a
		# cancel. A row that cannot lead anywhere must not light up.
		return damaged and not _targets_for(id).is_empty()
	if id == _armed:
		return true             # tapping the armed row again cancels
	return _targets_for(_armed).has(id)


func _nothing_can_be_spent(integrity: float) -> bool:
	for id_v in SectionDB.damaged_ids(integrity):
		if not _targets_for(String(id_v)).is_empty():
			return false
	return true


func _targets_for(source: String) -> Array:
	# Every section this source could legally be spent on, asked of the one
	# function that owns the rule. The panel does NOT re-implement the test --
	# that is what put the damaged-source rule in the rendering the first time.
	var out: Array = []
	if source == "":
		return out
	var integrity := _integrity()
	for id_v in SectionDB.ids():
		var id := String(id_v)
		if id == source:
			continue
		if GameState.can_divert(source, id, integrity):
			out.append(id)
	return out


func _on_row(id: String, damaged: bool) -> void:
	if _armed == "":
		if not damaged:
			return
		_armed = id
		Sfx.play("tap", -10.0, 0.9)
		_refresh()
		return
	if id == _armed:
		_armed = ""
		Sfx.play("tap", -14.0, 0.7)
		_refresh()
		return
	var source := _armed
	_armed = ""
	if not GameState.divert_power(source, id, _integrity()):
		Sfx.play("tap", -14.0, 0.6)
		_refresh()
		return
	Sfx.play("equip", -4.0, 1.2)
	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_toast"):
		hud.show_toast("POWER DIVERTED — %s IS DARK" % String(
			SectionDB.section(source).get("name", "")), Palette.AMBER)
	GameState.note_log("DIVERTED %s TO %s" % [
		String(SectionDB.section(source).get("name", "")),
		String(SectionDB.section(id).get("name", ""))])
	_refresh()


# --- open / close -----------------------------------------------------------

func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	_armed = ""
	_refresh()
	Sfx.play("equip", -8.0, 0.85)
	# THE PAUSE GOES UP LAST, after the sheet is populated. Building a panel
	# inside a paused tree is fine, but reading the ship's integrity is not
	# something to do while the world is mid-stop.
	get_tree().paused = true


func close_panel() -> void:
	# Named to match every other console so CameraRig's escape ladder treats them
	# alike.
	if not is_open:
		return
	is_open = false
	visible = false
	_armed = ""
	# UNCONDITIONALLY un-paused. This panel is the only thing that pauses outside
	# the pause menu, and a sheet that could close while leaving the tree stopped
	# would be a hang with a tidy explanation.
	get_tree().paused = false
	Sfx.play("equip", -12.0, 0.9)
	closed.emit()
