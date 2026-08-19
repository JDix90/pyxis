class_name RefitPanel
extends CanvasLayer
# The fitting console: a bottom sheet that slides up over the lower half of
# the screen. The system stays visible above it, so refitting never feels like
# leaving the game.
#
# Layout (top to bottom): header with salvage + reactor -> slot chips ->
# power bar -> module list for the selected slot -> the current fit's stats.
#
# That last line used to say "stat delta preview" and was a promise nothing
# kept: GameState.preview_stats existed with ZERO callers and the strip only
# ever drew the equipped fit. The delta is real now, and it lives on each module
# ROW rather than on the strip -- see _delta_line. This is a touch console, so
# there is no hover to hang a preview on; the answer has to be sitting next to
# the thing you are about to press.

const SHEET_RATIO := 0.62
const SLIDE_TIME := 0.28

# Wide enough for "HANDLING" at font 9 and "100%" at font 15. The flow row wraps
# rather than squeezing, so this is a floor on legibility instead of a guess at
# how many columns fit.
const CELL_MIN_W := 62.0

var is_open := false

var _root: Control
var _sheet: Panel
var _salvage_label: Label
var _reactor_label: Label
var _reactor_button: Button
var _power_label: Label
var _power_fill: ColorRect
var _power_track: ColorRect
var _chip_row: HFlowContainer
var _module_list: VBoxContainer
var _stat_row: HFlowContainer

var _slot := ModuleDB.Slot.WEAPON_A
var _chips := {}


func _ready() -> void:
	layer = 2
	_build()
	visible = false
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	# CONNECTED HERE, not in _apply_layout. _apply_layout is wired to
	# size_changed, so connecting from inside it added a fresh pair of lambdas on
	# every window resize — Godot cannot dedupe distinct lambdas, so after N
	# resizes one salvage_changed rebuilt the whole module list N+1 times. A
	# browser window that is dragged about is the worst case.
	GameState.fit_changed.connect(func(_s: Dictionary) -> void:
		if is_open:
			_refresh()
	)
	GameState.salvage_changed.connect(func(_v: int) -> void:
		if is_open:
			_refresh()
	)
	# Only the HOLD line, never the whole list. Cargo changes while this sheet is
	# open -- loot vacuumed up, a toll taken -- and the capacity readout has to
	# follow, but nothing else in a FITTING console depends on what is aboard.
	GameState.cargo_changed.connect(func() -> void:
		if is_open:
			_refresh_hold_line()
	)


func _apply_layout() -> void:
	# Horizontal only: the vertical offsets belong to the slide animation.
	UILayout.column_horizontal(_sheet)


# --- construction -----------------------------------------------------------

func _build() -> void:
	_root = Control.new()
	_root.set_anchors_preset(Control.PRESET_FULL_RECT)
	_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_root)

	_sheet = Panel.new()
	# Anchored explicitly: the slide animates offset_top/bottom together, which
	# keeps the anchor rect intact (setting `position` would fight the anchors
	# and snap the sheet to the top of the screen).
	_sheet.anchor_left = 0.0
	_sheet.anchor_right = 1.0
	_sheet.anchor_top = 1.0 - SHEET_RATIO
	_sheet.anchor_bottom = 1.0
	_sheet.offset_left = 0.0
	_sheet.offset_right = 0.0
	_sheet.offset_top = 0.0
	_sheet.offset_bottom = 0.0
	_sheet.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.02, 0.025, 0.04, 0.97)
	style.border_color = Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.55)
	style.border_width_top = 2
	style.corner_radius_top_left = 14
	style.corner_radius_top_right = 14
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 14
	style.content_margin_bottom = 14
	_sheet.add_theme_stylebox_override("panel", style)
	_root.add_child(_sheet)

	# A MarginContainer does the insetting: children anchored to the panel's
	# full rect would ignore the stylebox content margins and clip at the edges.
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	_sheet.add_child(margin)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 10)
	margin.add_child(col)

	col.add_child(_build_header())
	col.add_child(_build_chips())
	col.add_child(_build_power())

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_module_list = VBoxContainer.new()
	_module_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_module_list.add_theme_constant_override("separation", 7)
	scroll.add_child(_module_list)

	col.add_child(_build_stats())


func _build_header() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)

	var title := Label.new()
	title.text = "REFIT"
	title.add_theme_color_override("font_color", Palette.AMBER)
	title.add_theme_font_size_override("font_size", 20)
	row.add_child(title)

	_salvage_label = Label.new()
	_salvage_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_salvage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_salvage_label.add_theme_color_override("font_color", Palette.GOLD)
	_salvage_label.add_theme_font_size_override("font_size", 18)
	row.add_child(_salvage_label)

	var close := Button.new()
	close.text = "✕"
	close.add_theme_font_size_override("font_size", 18)
	close.add_theme_color_override("font_color", Palette.AMBER)
	close.flat = true
	close.pressed.connect(close_panel)
	row.add_child(close)
	return row


func _build_chips() -> Control:
	# HFlow and the slot list, not an HBox and a hardcoded one: six chips no
	# longer fit one row on a phone, and a seventh slot should cost a ModuleDB
	# entry rather than an edit here. v24 collected on that: three berth slots
	# arrived and this function did not change shape.
	#
	# open_slots(), not SLOT_NAMES: a berth this pilot has not bought is not a
	# chip they can press. Drawing it greyed would be a shop advert inside the
	# fitting console, and the console's job is the ship that exists.
	_chip_row = HFlowContainer.new()
	_chip_row.add_theme_constant_override("h_separation", 6)
	_chip_row.add_theme_constant_override("v_separation", 4)
	for slot in GameState.open_slots():
		var chip := Button.new()
		chip.text = _chip_text(slot)
		chip.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		chip.add_theme_font_size_override("font_size", 11)
		chip.toggle_mode = true
		chip.pressed.connect(func() -> void: _select_slot(slot))
		_chip_row.add_child(chip)
		_chips[slot] = chip
	return _chip_row


func _build_power() -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)

	var row := HBoxContainer.new()
	_power_label = Label.new()
	_power_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_power_label.add_theme_font_size_override("font_size", 12)
	_power_label.add_theme_color_override("font_color", Palette.AMBER_DIM)
	row.add_child(_power_label)

	_reactor_label = Label.new()
	_reactor_label.add_theme_font_size_override("font_size", 12)
	_reactor_label.add_theme_color_override("font_color", Palette.AMBER_DIM)
	row.add_child(_reactor_label)

	_reactor_button = Button.new()
	_reactor_button.add_theme_font_size_override("font_size", 11)
	_reactor_button.pressed.connect(_on_reactor_upgrade)
	row.add_child(_reactor_button)
	box.add_child(row)

	_power_track = ColorRect.new()
	_power_track.custom_minimum_size = Vector2(0, 8)
	_power_track.color = Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.16)
	box.add_child(_power_track)

	_power_fill = ColorRect.new()
	_power_fill.color = Palette.AMBER
	_power_fill.anchor_bottom = 1.0
	_power_track.add_child(_power_fill)

	# WHAT IS LEFT OF THE HOLD IN THIS CONSOLE, and deliberately only this.
	#
	# The manifest moved to its own screen, but a capacity line has to stay:
	# fitting a Cargo Bay is the one action in here that CHANGES how much room
	# you have, and a trade you cannot see is a trade you cannot weigh.
	# ModuleDB.summary_lines already prints fitted capacity in the stat row --
	# this adds USED, which is the half that was missing, and the chevron marks
	# it as a door rather than a second readout of the same number.
	_hold_button = Button.new()
	_hold_button.flat = true
	_hold_button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	UIKit.apply_font(_hold_button, UIKit.SIZE_LABEL)
	_hold_button.pressed.connect(func() -> void:
		# One sheet at a time: this console closes as the other opens, rather
		# than stacking two consoles the escape ladder would then have to unwind.
		close_panel()
		var main := get_tree().get_first_node_in_group("main")
		if main != null and main.hold_screen != null:
			main.hold_screen.open())
	box.add_child(_hold_button)
	return box


func _build_stats() -> Control:
	# HFlowContainer, not HBoxContainer, and the swap is what let the six silent
	# stats be shown at all. An HBox with EXPAND_FILL cells does not overflow
	# visibly -- it SQUEEZES, so a fourteen-column fit (arc + torpedo + prospector
	# + assay is reachable) would have quietly shaved every label to nothing
	# rather than telling anyone. A flow row wraps to a second line instead, and
	# the sheet's own clamp already recomputes its height from content.
	_stat_row = HFlowContainer.new()
	_stat_row.add_theme_constant_override("h_separation", 8)
	_stat_row.add_theme_constant_override("v_separation", 2)
	return _stat_row


# --- open / close -----------------------------------------------------------

func _sheet_height() -> float:
	return get_viewport().get_visible_rect().size.y * SHEET_RATIO


func _set_slide(v: float) -> void:
	# v = 0 fully open, v = sheet height fully hidden below the screen edge.
	_sheet.offset_top = v
	_sheet.offset_bottom = v


func open() -> void:
	if is_open:
		return
	is_open = true
	visible = true
	_select_slot(_slot)
	Sfx.play("equip", -8.0, 1.0)
	var h := _sheet_height()
	_set_slide(h)
	var tw := create_tween()
	tw.tween_method(_set_slide, h, 0.0, SLIDE_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func close_panel() -> void:
	if not is_open:
		return
	is_open = false
	_disarm()
	Sfx.play("equip", -12.0, 0.85)
	var tw := create_tween()
	tw.tween_method(_set_slide, 0.0, _sheet_height(), SLIDE_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(func() -> void: visible = false)


func toggle() -> void:
	if is_open:
		close_panel()
	else:
		open()


# --- interaction ------------------------------------------------------------

func _select_slot(slot: int) -> void:
	_disarm()
	_slot = slot
	for s in _chips:
		(_chips[s] as Button).button_pressed = (s == slot)
	_refresh()


# Two-tap confirm for a destructive action. This game has no dialogs — the toast
# says what will happen and the second tap means yes.
#
# ARMING MUST NOT OUTLIVE THE INTERACTION. Nothing used to disarm these on close
# or on a slot change, so arming a jettison, closing the sheet and flying for ten
# minutes left the confirm live: the next tap on that row dumped cargo with no
# warning at all. A brake that stays pressed is not a brake.
var _hold_button: Button
var _pending_jettison := ""
var _jettison_armed := false
# The cargo manifest's own arming, deliberately SEPARATE from the module flow's.
# Good ids and module ids happen to be disjoint strings today, so one shared
# variable would work — until the day they are not, and then a primed module
# swap would be fired by a tap on a cargo row.


func _on_reactor_upgrade() -> void:
	if GameState.upgrade_reactor():
		Sfx.play("equip", -4.0, 0.7)
		FX_flash_power(Palette.TEAL)
	else:
		_reject()
	_refresh()


func _on_module_pressed(id: String) -> void:
	if not GameState.owns(id):
		if GameState.buy(id):
			Sfx.play("equip", -5.0, 1.1)
		else:
			_reject()
			_refresh()
			return
	if _confirm_jettison(id):
		return
	if GameState.equip(_slot, id):
		Sfx.play("equip", -6.0, 1.0)
	else:
		_reject()
	_refresh()


func _on_unequip() -> void:
	if _confirm_jettison(""):
		return
	GameState.equip(_slot, "")
	Sfx.play("equip", -10.0, 0.9)
	_refresh()


func _confirm_jettison(id: String) -> bool:
	# A swap that would shrink the hold below what is in it is refused rather
	# than allowed to leave cargo_used above cargo_capacity — an invalid state
	# every other system then had to tolerate. The player is offered the only
	# honest way out: dump the difference.
	#
	# Returns true if it took over the interaction.
	var over := GameState.cargo_overflow(_slot, id)
	if over <= 0:
		return false
	if _pending_jettison == id and _jettison_armed:
		var dumped := GameState.jettison_to_fit(_slot, id)
		_jettison_armed = false
		_pending_jettison = ""
		Sfx.play("hit", -6.0, 0.6)
		var hud := get_tree().get_first_node_in_group("hud")
		if hud:
			hud.show_toast("JETTISONED %d UNIT%s" % [dumped, "" if dumped == 1 else "S"],
				Palette.THREAT)
			hud.refresh_cargo()
		if GameState.equip(_slot, id):
			Sfx.play("equip", -6.0, 1.0)
		_refresh()
		return true
	_pending_jettison = id
	_jettison_armed = true
	_reject()
	var hud2 := get_tree().get_first_node_in_group("hud")
	if hud2:
		hud2.show_toast("HOLD TOO FULL — %d OVER. TAP AGAIN TO JETTISON" % over, Palette.THREAT)
	_refresh()
	return true


func _disarm() -> void:
	_pending_jettison = ""
	_jettison_armed = false


func _reject() -> void:
	# Over budget or unaffordable: flash the power bar red rather than popping
	# a dialog. The constraint should feel physical, not bureaucratic.
	Sfx.play("hit", -10.0, 0.7)
	FX_flash_power(Palette.THREAT)


func FX_flash_power(color: Color) -> void:
	var original := _power_fill.color
	_power_fill.color = color
	var tw := create_tween()
	tw.tween_property(_power_fill, "color", original, 0.45)


# --- refresh ----------------------------------------------------------------

func _refresh_hold_line() -> void:
	if _hold_button == null:
		return
	var used := GameState.cargo_used()
	var cap := GameState.cargo_capacity()
	_hold_button.text = "HOLD  %d / %d  ›" % [used, cap]
	_hold_button.add_theme_color_override("font_color",
		Palette.THREAT if used >= cap else Palette.GOLD)


func _refresh() -> void:
	_refresh_hold_line()
	_salvage_label.text = "%s SALVAGE" % _comma(GameState.salvage)

	var draw := GameState.power_draw()
	var cap := GameState.power_cap()
	_power_label.text = "POWER  %d / %d" % [draw, cap]
	_reactor_label.text = GameState.reactor_name()
	_power_fill.size.x = _power_track.size.x * clampf(float(draw) / maxf(float(cap), 1.0), 0.0, 1.0)

	# Reactor upgrades are sold at port outfitters, not in the field.
	_reactor_button.text = "AT PORT"
	_reactor_button.disabled = true

	for slot in _chips:
		(_chips[slot] as Button).text = _chip_text(slot)

	_rebuild_module_list()
	_rebuild_stats()


func _chip_text(slot: int) -> String:
	var id: String = GameState.fit.get(slot, "") if GameState.fit.has(slot) else ""
	var equipped: String = str(ModuleDB.get_module(id).get("name", "EMPTY")) if ModuleDB.exists(id) else "EMPTY"
	return "%s\n%s" % [ModuleDB.SLOT_NAMES[slot], String(equipped).to_upper()]


func _rebuild_module_list() -> void:
	for child in _module_list.get_children():
		child.queue_free()


	var equipped_id: String = GameState.fit.get(_slot, "")

	if equipped_id != "":
		var strip := Button.new()
		strip.text = "— LEAVE SLOT EMPTY —"
		strip.add_theme_font_size_override("font_size", 11)
		strip.add_theme_color_override("font_color", Palette.AMBER_DIM)
		strip.flat = true
		strip.pressed.connect(_on_unequip)
		_module_list.add_child(strip)

	# Owned modules only. Acquiring gear belongs to port outfitters now; swapping
	# what you already own stays free and available anywhere, which is what the
	# "reversible experimentation" pillar actually requires.
	var any_owned := false
	for id in ModuleDB.modules_for_slot(_slot):
		if not GameState.owns(id):
			continue
		any_owned = true
		_module_list.add_child(_build_module_row(id, id == equipped_id))

	var hint := Label.new()
	hint.text = "NO MODULES OWNED FOR THIS SLOT — BUY AT A PORT OUTFITTER" if not any_owned \
		else "MORE AVAILABLE AT PORT OUTFITTERS"
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Palette.AMBER_DIM)
	_module_list.add_child(hint)


func _build_module_row(id: String, equipped: bool) -> Control:
	var m := ModuleDB.get_module(id)
	var owned := GameState.owns(id)
	var affordable := GameState.salvage >= int(m["price"])
	var fits := GameState.can_equip(_slot, id)

	var row := Button.new()
	row.custom_minimum_size = Vector2(0, 58)
	row.pressed.connect(func() -> void: _on_module_pressed(id))

	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.10 if equipped else 0.035)
	style.border_color = Palette.AMBER if equipped else Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.2)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	row.add_theme_stylebox_override("normal", style)
	row.add_theme_stylebox_override("hover", style)
	row.add_theme_stylebox_override("pressed", style)

	var box := HBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 10.0
	box.offset_right = -10.0
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 8)
	row.add_child(box)

	var text := VBoxContainer.new()
	text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	text.add_theme_constant_override("separation", -1)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(text)

	var name_label := Label.new()
	name_label.text = String(m["name"])
	name_label.add_theme_font_size_override("font_size", 14)
	var name_color := Palette.GOLD if equipped else (Palette.HULL if owned else Palette.AMBER_DIM)
	if not owned and not affordable:
		name_color = Color(0.5, 0.45, 0.45)
	name_label.add_theme_color_override("font_color", name_color)
	text.add_child(name_label)

	var desc := Label.new()
	desc.text = String(m["desc"])
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	text.add_child(desc)

	# THE ANSWER, NEXT TO THE QUESTION. Everything above is prose; this is the
	# arithmetic, against the fit currently flying, computed for the slot this
	# row would actually occupy.
	if not equipped:
		var line := UIKit.delta_line(GameState.preview_stats(_slot, id), 10)
		if line != null:
			text.add_child(line)

	var right := VBoxContainer.new()
	right.add_theme_constant_override("separation", -1)
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(right)

	var status := Label.new()
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	status.add_theme_font_size_override("font_size", 12)
	if equipped:
		status.text = "EQUIPPED"
		status.add_theme_color_override("font_color", Palette.GOLD)
	elif owned:
		status.text = "EQUIP" if fits else "NO POWER"
		status.add_theme_color_override("font_color", Palette.TEAL if fits else Palette.THREAT)
	else:
		status.text = _comma(int(m["price"]))
		status.add_theme_color_override("font_color", Palette.GOLD if affordable else Color(0.55, 0.4, 0.4))
	right.add_child(status)

	var power := Label.new()
	power.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	power.text = "%d PWR" % int(m["power"])
	power.add_theme_font_size_override("font_size", 10)
	power.add_theme_color_override("font_color", Palette.AMBER_DIM)
	right.add_child(power)

	return row


func _rebuild_stats() -> void:
	for child in _stat_row.get_children():
		child.queue_free()
	for pair in ModuleDB.summary_lines(GameState.stats):
		var cell := VBoxContainer.new()
		# SHRINK, not EXPAND_FILL. In a flow container EXPAND_FILL stretches the
		# cells on each line to fill it, so a wrapped final row of two would sit
		# half a screen apart from each other; shrinking keeps the columns a
		# consistent width and lets the wrap do the work.
		cell.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		cell.custom_minimum_size = Vector2(CELL_MIN_W, 0)
		cell.add_theme_constant_override("separation", -2)

		var key := Label.new()
		key.text = String(pair[0])
		key.add_theme_font_size_override("font_size", 9)
		key.add_theme_color_override("font_color", Palette.AMBER_DIM)
		cell.add_child(key)

		var val := Label.new()
		val.text = String(pair[1])
		val.add_theme_font_size_override("font_size", 15)
		val.add_theme_color_override("font_color", Palette.HULL)
		cell.add_child(val)
		_stat_row.add_child(cell)


func _comma(n: int) -> String:
	var s := str(n)
	var out := ""
	var count := 0
	for i in range(s.length() - 1, -1, -1):
		out = s[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = "," + out
	return out
