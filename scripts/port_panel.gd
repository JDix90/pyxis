class_name PortPanel
extends CanvasLayer
# The docked sheet: MARKET / OUTFITTER / DEPART.
#
# Same bottom-sheet vocabulary as the refit and chart consoles, so docking feels
# like another console rather than another game. Every price shown here comes
# from Market, which is also what charges the player — the number on the row is
# always the number you pay.

const SHEET_RATIO := 0.66
const SLIDE_TIME := 0.28

# Tabs are built from the port's `services` list, so a new kind of station is a
# data entry plus one `_build_<service>` method — never a new panel class. Ports
# that predate the field get the classic three.
const TAB_LABELS := {
	"market": "MARKET",
	"outfitter": "OUTFITTER",
	"contracts": "CONTRACTS",
	"rumors": "RUMORS",
	"games": "GAMES",
	"fence": "FENCE",
	"paint": "PAINT",
	"repair": "REPAIR",
	"lab": "LAB",
	"storage": "STORAGE",
	"forge": "FORGE",
	"commission": "COMMISSION",
}
const DEFAULT_SERVICES := ["market", "outfitter", "contracts"]

# The cantina's wager. Deliberately a LOSING bet with the odds printed on the
# table: 45% to double is -10% expected value, so it is a thing to do rather
# than a way to earn, and the streak lockout caps how much of a session it can
# eat. An honest bad bet you can see is fun; a hidden one is a con.
const GAMBLE_WIN_CHANCE := 0.45
const GAMBLE_STREAK_LIMIT := 3
const GAMBLE_STAKES := [250, 1000, 4000]

# Paint is cosmetic, so it is priced to be an early indulgence rather than a
# late-game milestone: roughly one derelict's worth of salvage in phase-2 money.
const PAINT_PRICE := 800

# Cost of a full hull repair, scaled by how much is actually missing.
const REPAIR_FULL_PRICE := 1400

var is_open := false

var _sheet: Panel
var _title: Label
var _salvage_label: Label
var _tab_row: HFlowContainer
var _depart_button: Button
var _body: VBoxContainer
var _cargo_track: ColorRect
var _cargo_fill: ColorRect
var _cargo_label: Label

var _port: Port = null
var _port_def := {}
var _tab := "market"
var _tabs := {}

# Session-only, deliberately not persisted. Rumours are things you were told,
# not a log; the streak is a table's memory of tonight, not a stat.
var _rumors_known: Array = []
var _gamble_streak := 0
var _gamble_last := ""
var _gamble_last_win := false


func _ready() -> void:
	layer = 3
	_build()
	visible = false
	_apply_layout()
	get_viewport().size_changed.connect(_apply_layout)
	GameState.salvage_changed.connect(func(_v: int) -> void:
		if is_open:
			_refresh()
	)


# --- construction -----------------------------------------------------------

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
	style.bg_color = Color(0.02, 0.025, 0.04, 0.98)
	style.border_color = Color(Palette.TEAL.r, Palette.TEAL.g, Palette.TEAL.b, 0.5)
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
	col.add_theme_constant_override("separation", 9)
	margin.add_child(col)

	var header := HBoxContainer.new()
	_title = Label.new()
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.add_theme_color_override("font_color", Palette.TEAL)
	_title.add_theme_font_size_override("font_size", 19)
	header.add_child(_title)
	_salvage_label = Label.new()
	_salvage_label.add_theme_color_override("font_color", Palette.GOLD)
	_salvage_label.add_theme_font_size_override("font_size", 16)
	header.add_child(_salvage_label)

	# DEPART lives HERE, not in the tab row below, and it carries a real
	# StyleBox. In the row it was the last child of an HFlowContainer wearing the
	# same stock-grey chrome as every service tab and differing only by a teal
	# label -- so it read as a seventh tab, which is both easy to miss when you
	# want it and easy to hit when you do not. Leaving is not a service; it is
	# the way out, and it belongs beside the readouts rather than among the
	# things you came here to do.
	_depart_button = UIKit.button("DEPART", Palette.TEAL, UIKit.SIZE_LABEL, Vector2(0, 30))
	_depart_button.pressed.connect(func() -> void:
		UIKit.press_pop(_depart_button)
		_on_tab("depart"))
	header.add_child(_depart_button)
	col.add_child(header)

	# HFlow, not HBox: a smuggler's den fields five service tabs, which is more
	# than fits across a 720-wide portrait screen in one row. (DEPART used to
	# ride here too and was the sixth; it moved to the header above.)
	_tab_row = HFlowContainer.new()
	_tab_row.add_theme_constant_override("h_separation", 6)
	_tab_row.add_theme_constant_override("v_separation", 4)
	col.add_child(_tab_row)

	_build_cargo_bar(col)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	col.add_child(scroll)

	_body = VBoxContainer.new()
	_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_body.add_theme_constant_override("separation", 6)
	scroll.add_child(_body)


func _build_cargo_bar(col: VBoxContainer) -> void:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 3)

	_cargo_label = Label.new()
	_cargo_label.add_theme_font_size_override("font_size", 11)
	_cargo_label.add_theme_color_override("font_color", Palette.AMBER_DIM)
	box.add_child(_cargo_label)

	_cargo_track = ColorRect.new()
	_cargo_track.custom_minimum_size = Vector2(0, 7)
	_cargo_track.color = Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.16)
	box.add_child(_cargo_track)

	_cargo_fill = ColorRect.new()
	_cargo_fill.color = Palette.GOLD
	_cargo_fill.anchor_bottom = 1.0
	_cargo_track.add_child(_cargo_fill)
	col.add_child(box)


# --- open / close -----------------------------------------------------------

func _apply_layout() -> void:
	UILayout.column_horizontal(_sheet)


func _sheet_height() -> float:
	return get_viewport().get_visible_rect().size.y * SHEET_RATIO


func _set_slide(v: float) -> void:
	_sheet.offset_top = v
	_sheet.offset_bottom = v


func services() -> Array:
	var list: Array = _port_def.get("services", [])
	return list if not list.is_empty() else DEFAULT_SERVICES


func _build_tabs() -> void:
	for c in _tab_row.get_children():
		c.queue_free()
	_tabs.clear()
	for key_v in services():
		var key := String(key_v)
		if not TAB_LABELS.has(key):
			continue
		var b := Button.new()
		b.text = String(TAB_LABELS[key])
		b.add_theme_font_size_override("font_size", 12)
		b.toggle_mode = true
		b.pressed.connect(func() -> void: _on_tab(key))
		_tab_row.add_child(b)
		_tabs[key] = b

	# DEPART is deliberately absent from this row -- it is built once, in the
	# header, and never rebuilt with the tabs. Still registered here so
	# _refresh's `if b.toggle_mode` skip keeps working unchanged.
	_tabs["depart"] = _depart_button


func open_for(port: Port) -> void:
	_port = port
	# The node's own def wins when it has one. For every authored port that field
	# is empty and this is the same SystemDB lookup it always was, returning the
	# same dictionary — so charted docking is bit-identical, not merely equivalent.
	_port_def = port.def if not port.def.is_empty() else SystemDB.port_def_by_id(port.port_id)
	_build_tabs()
	# First service, not hard-coded "market": an entertainment station has no
	# market tab to open onto.
	_tab = String(services()[0]) if not services().is_empty() else "market"
	# A new station is a new set of rumours — those are things you were told here.
	_rumors_known = []
	_gamble_last = ""
	# The streak deliberately does NOT reset. It used to, and since open_for runs
	# on every dock, the lockout was bypassable by tapping DEPART and docking
	# again — a guardrail you can step around in two taps is not a guardrail.
	# It clears on a loss, and otherwise lasts the session.
	if is_open:
		_refresh()
		return
	is_open = true
	visible = true
	_refresh()
	var h := _sheet_height()
	_set_slide(h)
	var tw := create_tween()
	tw.tween_method(_set_slide, h, 0.0, SLIDE_TIME).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func close_panel() -> void:
	if not is_open:
		return
	is_open = false
	var tw := create_tween()
	tw.tween_method(_set_slide, 0.0, _sheet_height(), SLIDE_TIME).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	tw.tween_callback(func() -> void: visible = false)


# --- click-outside-to-leave ---------------------------------------------------
# Two presses outside the sheet depart. On desktop and in a browser the sheet is
# a modal-looking thing floating over a live world, and the reflex when you are
# done with a modal is to click away from it -- so the reflex should work.
#
# Deliberately a DOUBLE press, not a single one. A single click outside is
# already a meaningful input: the world behind the sheet is live, the rig still
# pans and zooms while docked, and one stray click undocking you would be worse
# than the mis-tap this whole change is about. Two presses inside a third of a
# second is nothing anyone does by accident.
#
# No scrim, for the same reason -- a full-rect blocker would kill the panning
# that works today.
const OUTSIDE_DOUBLE_PX := 14.0        # same slop as CameraRig.TAP_MAX_PX

var _outside_last_time := 0.0
var _outside_last_pos := Vector2.ZERO


func _unhandled_input(event: InputEvent) -> void:
	if not is_open:
		return
	var press: Vector2
	if event is InputEventMouseButton:
		var mb := event as InputEventMouseButton
		if not mb.pressed or mb.button_index != MOUSE_BUTTON_LEFT:
			return
		press = mb.position
	elif event is InputEventScreenTouch:
		var st := event as InputEventScreenTouch
		if not st.pressed:
			return
		press = st.position
	else:
		return

	# Inside the sheet the sheet has already handled it -- this only runs for
	# what fell through, but check anyway so a future scrim cannot change the
	# meaning of this function silently.
	if _sheet.get_global_rect().has_point(press):
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now - _outside_last_time <= UIKit.T_PANEL \
			and press.distance_to(_outside_last_pos) <= OUTSIDE_DOUBLE_PX:
		_outside_last_time = 0.0
		_on_tab("depart")
		get_viewport().set_input_as_handled()
		return
	_outside_last_time = now
	_outside_last_pos = press


func _on_tab(key: String) -> void:
	if key == "depart":
		Sfx.play("equip", -10.0, 0.85)
		close_panel()
		var main := get_tree().get_first_node_in_group("main")
		if main and main.has_method("undock"):
			main.undock()
		return
	_tab = key
	Sfx.play("tap", -8.0, 1.0)
	_refresh()


# --- trading ----------------------------------------------------------------

func _buy(good: String, units: int) -> void:
	# Enforced here as well as hidden in the UI: the button is the affordance,
	# this is the rule.
	if not Market.can_buy(_port_def, good):
		_reject()
		return
	# Priced at the size actually being traded, so the bulk break the row
	# advertises is the break the player is charged.
	var price := Market.buy_price(_port_def, _port.port_id, good, units)
	var affordable := int(GameState.salvage / maxi(price, 1))
	var fits := GameState.cargo_free() / maxi(CommodityDB.space_of(good), 1)
	var n := mini(units, mini(affordable, fits))
	if n <= 0:
		_reject()
		return
	# Re-priced at what actually fit: buying 5 and only affording 3 must not
	# quietly keep the 5-unit discount.
	price = Market.buy_price(_port_def, _port.port_id, good, n)
	if not GameState.spend_salvage(price * n):
		_reject()
		return
	GameState.load_cargo(good, n)
	Market.apply_trade_pressure(_port.port_id, good, n, false)
	Sfx.play("equip", -7.0, 1.1)
	Barks.fire("first_trade")
	_refresh()


func _sell(good: String, units: int) -> void:
	var n := mini(units, GameState.cargo_count(good))
	if n <= 0:
		_reject()
		return
	var price := Market.sell_price(_port_def, _port.port_id, good, n)
	GameState.unload_cargo(good, n)
	GameState.add_salvage(price * n)
	if CommodityDB.is_chart(good):
		GameState.note_ledger("chart_data_sold", n)
	# SMUGGLING's one feed. At a FENCE specifically — the whole skill is about who
	# will deal with you off the books, and selling stolen goods over a legitimate
	# counter is not that.
	if GameState.SMUGGLING_GOODS.has(good) and Market.fences(_port_def, good):
		if GameState.mark_smuggling(n):
			var m0 := get_tree().get_first_node_in_group("main")
			if m0 and m0.hud:
				m0.hud.show_toast("SMUGGLING %d — %s" % [GameState.smuggling,
					"THE LANES KNOW YOU" if GameState.smuggling < 3
					else "EVERY DEEP FENCE DEALS WITH YOU"], Palette.GOLD)
	Market.apply_trade_pressure(_port.port_id, good, n, true)
	Sfx.play_streak("pickup", -8.0)
	var main := get_tree().get_first_node_in_group("main")
	if main and main.hud:
		main.hud.set_value(GameState.salvage)
	Barks.fire("first_trade")
	_refresh()


func _reject() -> void:
	Sfx.play("hit", -12.0, 0.7)


func _buy_module(id: String) -> void:
	var price := _module_price(id)
	if GameState.owns(id) or GameState.salvage < price:
		_reject()
		return
	if not GameState.spend_salvage(price):
		_reject()
		return
	GameState.owned.append(id)
	GameState.save_game()
	Sfx.play("equip", -5.0, 1.0)
	_refresh()


func _sell_module(id: String) -> void:
	# Sell-back at 60% by default; an industrial depot pays 75%, which is what
	# makes it worth flying to when you are rotating a fit rather than buying.
	# Starter kit is not sellable, so a player can never strand themselves
	# without a weapon or a drive.
	if not GameState.owns(id) or ModuleDB.STARTER_OWNED.has(id):
		_reject()
		return
	for slot in GameState.fit:
		if String(GameState.fit[slot]) == id:
			GameState.equip(slot, "")
	GameState.owned.erase(id)
	# Priced off the catalog, not off this port's discounted asking price: the
	# grey market must not be a place you can buy at -20% and sell back at 75%
	# of full for a profit.
	var base := int(ModuleDB.get_module(id).get("price", 0))
	GameState.add_salvage(int(base * float(_port_def.get("sellback", 0.6))))
	Sfx.play("equip", -8.0, 0.85)
	var main := get_tree().get_first_node_in_group("main")
	if main and main.hud:
		main.hud.set_value(GameState.salvage)
	_refresh()


func _module_price(id: String) -> int:
	var base := int(ModuleDB.get_module(id).get("price", 0))
	return int(round(base * float(_port_def.get("outfit_mult", 1.0))))


func _upgrade_reactor() -> void:
	if GameState.upgrade_reactor():
		Sfx.play("equip", -4.0, 0.7)
	else:
		_reject()
	_refresh()


# --- refresh ----------------------------------------------------------------

func _refresh() -> void:
	if _port == null:
		return
	_title.text = _port.port_name
	_salvage_label.text = "%s SALVAGE" % _comma(GameState.salvage)
	for key in _tabs:
		var b := _tabs[key] as Button
		if b.toggle_mode:
			b.button_pressed = (key == _tab)

	var used := GameState.cargo_used()
	var cap := GameState.cargo_capacity()
	_cargo_label.text = "HOLD  %d / %d" % [used, cap]
	_cargo_fill.size.x = _cargo_track.size.x * clampf(float(used) / maxf(float(cap), 1.0), 0.0, 1.0)
	_cargo_fill.color = Palette.THREAT if used >= cap else Palette.GOLD

	for c in _body.get_children():
		c.queue_free()
	match _tab:
		"market":
			# Restricted goods only appear where they can actually be traded, so
			# a contraband row is never a tease at a port that will not touch it.
			for good in CommodityDB.ids_for_port(_port.port_id):
				_body.add_child(_market_row(String(good)))
		"contracts":
			_build_contract_board()
		"fence":
			_build_fence()
		"rumors":
			_build_rumors()
		"games":
			_build_games()
		"paint":
			_build_paint()
		"repair":
			_build_repair()
		"lab":
			_build_lab()
		"storage":
			_build_storage()
		"forge":
			_build_forge()
		"commission":
			_build_commission()
		_:
			_body.add_child(_reactor_row())
			for id in _port_def.get("stock", []):
				_body.add_child(_module_row(String(id)))


# --- repair bay --------------------------------------------------------------

func _build_repair() -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	if player == null:
		return
	var frac := player.shield_fraction()
	var missing := 1.0 - frac
	# Priced off what is actually missing, so topping up a scratch is cheap and
	# limping in on fumes is not. Free at full, which stops the button being a
	# trap you can tap twice.
	var price := int(round(missing * float(_port_def.get("repair_price", REPAIR_FULL_PRICE))))

	var head := Label.new()
	head.text = "HULL INTEGRITY %d%%" % int(round(frac * 100.0))
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color",
		Palette.TEAL if frac > 0.6 else (Palette.AMBER if frac > 0.25 else Palette.THREAT))
	_body.add_child(head)

	var note := Label.new()
	note.text = "The hull knits itself back together between fights for free. This is what you pay to skip the wait."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Palette.AMBER_DIM)
	_body.add_child(note)

	var b := Button.new()
	b.custom_minimum_size = Vector2(0, 40)
	b.add_theme_font_size_override("font_size", 13)
	if missing <= 0.001:
		b.text = "HULL SOUND"
		b.disabled = true
	else:
		b.text = "REPAIR TO FULL   %s" % _comma(price)
		b.disabled = GameState.salvage < price
		b.pressed.connect(func() -> void: _do_repair(price))
	_body.add_child(b)


func _bay_key() -> String:
	# A charted port stores under its own id; a deep station under its cell, which
	# DeepSpace set on the node. port_id will not do out there — it is the
	# archetype, shared by every station of that kind in every system.
	if _port == null:
		return ""
	return _port.bay_key if _port.bay_key != "" else _port.port_id


func _build_storage() -> void:
	var key := _bay_key()
	var used := GameState.warehouse_used(key)

	var head := Label.new()
	head.text = "BONDED STORE  %d / %d" % [used, GameState.WAREHOUSE_SPACE]
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color",
		Palette.THREAT if used >= GameState.WAREHOUSE_SPACE else Palette.GOLD)
	_body.add_child(head)

	var note := Label.new()
	note.text = "UNLISTED MATERIAL ONLY. ANYTHING WITH A PRICE ON THE BOARD MOVES THROUGH THE MARKET."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Palette.AMBER_DIM)
	_body.add_child(note)

	var any := false
	for gid in CommodityDB.ids():
		var good := String(gid)
		if not GameState.can_store(good):
			continue
		var held := GameState.cargo_count(good)
		var stored := GameState.warehouse_count(key, good)
		if held <= 0 and stored <= 0:
			continue
		any = true
		_body.add_child(_storage_row(key, good, held, stored))

	if not any:
		var none := Label.new()
		none.text = "NOTHING ABOARD THIS BAY WILL TAKE, AND NOTHING IN IT."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.add_theme_font_size_override("font_size", 11)
		none.add_theme_color_override("font_color", Palette.AMBER_DIM)
		_body.add_child(none)


func _storage_row(key: String, good: String, held: int, stored: int) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)

	var label := Label.new()
	label.text = "%s\nHOLD %d   BAY %d" % [CommodityDB.display(good).to_upper(), held, stored]
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", CommodityDB.color_of(good))
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(label)

	if held > 0:
		row.add_child(_mini_button("STORE 1", func() -> void: _deposit(key, good, 1)))
		row.add_child(_mini_button("ALL", func() -> void: _deposit(key, good, held)))
	if stored > 0:
		row.add_child(_mini_button("TAKE 1", func() -> void: _withdraw(key, good, 1)))
		row.add_child(_mini_button("TAKE ALL", func() -> void: _withdraw(key, good, stored)))
	return row


func _deposit(key: String, good: String, units: int) -> void:
	if GameState.store_cargo(key, good, units) <= 0:
		_reject()
		_refresh()
		return
	Sfx.play("equip", -9.0, 0.85)
	var main := get_tree().get_first_node_in_group("main")
	if main and main.hud:
		main.hud.refresh_cargo()
	_refresh()


func _withdraw(key: String, good: String, units: int) -> void:
	if GameState.withdraw_cargo(key, good, units) <= 0:
		_reject()
		_refresh()
		return
	Sfx.play("equip", -9.0, 1.1)
	var main := get_tree().get_first_node_in_group("main")
	if main and main.hud:
		main.hud.refresh_cargo()
	# Contracts settle from cargo on the DOCK edge, and we are already docked —
	# so a delivery good pulled out of the bay would sit unclaimed until the
	# player undocked and came back. Idempotent, so re-running it costs nothing.
	if main and main.contracts:
		main.contracts.on_docked(_port.port_id)
	_refresh()


func _build_forge() -> void:
	# Four things no counter anywhere will sell you. EVERY recipe is printed
	# whether or not you can make it: a locked one names the component it wants,
	# and a component names the read that produces it — so the forge quietly
	# advertises archeology to a player who has never opened a lab.
	var head := Label.new()
	head.text = "THE FORGE"
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", Palette.GOLD)
	_body.add_child(head)

	var note := Label.new()
	note.text = "NOTHING HERE IS FOR SALE, HERE OR ANYWHERE. IT COSTS WHAT THE FENCE WOULD HAVE PAID FOR THE PARTS."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Palette.AMBER_DIM)
	_body.add_child(note)

	for id_v in ModuleDB.craftable_ids():
		_body.add_child(_forge_row(String(id_v)))


func _forge_row(id: String) -> Control:
	var m := ModuleDB.get_module(id)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var owned := GameState.owns(id)
	var title := Label.new()
	title.text = "%s%s" % [String(m.get("name", id)).to_upper(),
		"  ·  ABOARD" if owned else ""]
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color",
		Palette.AMBER_DIM if owned else Palette.HULL)
	box.add_child(title)

	var desc := Label.new()
	desc.text = String(m.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	box.add_child(desc)

	# The bill of materials, each line saying whether you have it. Printed even
	# when you cannot craft — that IS the advertisement.
	var rec := ModuleDB.recipe(id)
	var parts := ""
	for good_v in rec:
		var good := String(good_v)
		var need := int(rec[good])
		var have := GameState.cargo_count(good)
		parts += "%s %d/%d   " % [CommodityDB.short_name(good), have, need]
	var bill := Label.new()
	bill.text = parts
	bill.add_theme_font_size_override("font_size", 10)
	bill.add_theme_color_override("font_color",
		Palette.GOLD if GameState.can_craft(id) else Palette.AMBER_DIM)
	box.add_child(bill)

	# What it costs to run, in the same words the refit console uses.
	var costs := ""
	for key in (m.get("stats", {}) as Dictionary):
		var v := float((m["stats"] as Dictionary)[key])
		if v < 0.0:
			costs += "%s %.2f   " % [String(key).to_upper().replace("_", " "), v]
	if costs != "":
		var cost_label := Label.new()
		cost_label.text = "COSTS  " + costs
		cost_label.add_theme_font_size_override("font_size", 9)
		cost_label.add_theme_color_override("font_color", Palette.THREAT)
		box.add_child(cost_label)

	if not owned:
		var b := Button.new()
		b.text = "FORGE IT" if GameState.can_craft(id) else "PARTS SHORT"
		b.disabled = not GameState.can_craft(id)
		b.custom_minimum_size = Vector2(0, 34)
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(func() -> void: _do_craft(id))
		box.add_child(b)
	return box


func _do_craft(id: String) -> void:
	if not GameState.craft(id):
		_reject()
		_refresh()
		return
	Sfx.play("equip", -4.0, 0.8)
	var main := get_tree().get_first_node_in_group("main")
	if main and main.hud:
		main.hud.show_toast("FORGED — %s" % String(
			ModuleDB.get_module(id).get("name", id)).to_upper(), Palette.GOLD)
		main.hud.refresh_cargo()
	_refresh()


func _build_lab() -> void:
	# Reading salvage. The whole console is one decision repeated: this grade can
	# be read as any of these things, which do you want?
	#
	# There is no roll here and there must never be one. 12 says the Cantina
	# prints its odds "because a hidden bad bet is a con" — a paid random reveal
	# is disqualified by the game's own standard. Choosing also makes a run
	# plannable, which is 9's legibility rule applied to loot.
	var tier := GameState.archeology
	var next_at := GameState.archeology_next_at()

	var head := Label.new()
	head.text = "ARCHEOLOGY %d" % tier
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", Palette.GOLD)
	_body.add_child(head)

	# One line, not a console. 12's "never a new panel class" is the precedent,
	# and a skill with its own screen is a skill that has become bookkeeping.
	var sub := Label.new()
	var readable: String = DeepSpace.BAND_NAMES[mini(tier + 1, DeepSpace.BAND_NAMES.size() - 1)]
	sub.text = "READS UP TO %s HERE. %s" % [readable,
		("%d MORE TO THE NEXT GRADE" % (next_at - GameState.archeology_xp)) if next_at >= 0
			else "NOTHING LEFT TO LEARN."]
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Palette.AMBER_DIM)
	_body.add_child(sub)

	var any := false
	for band in range(DeepSpace.BAND_NAMES.size()):
		var sid := CommodityDB.salvage_for_band(band)
		if sid == "" or GameState.cargo_count(sid) <= 0:
			continue
		any = true
		_body.add_child(_lab_row(sid))

	if not any:
		var none := Label.new()
		none.text = "NO UNREAD SALVAGE ABOARD. IT COMES OUT OF WRECKS, AND THE DEEPER THE WRECK THE BETTER IT READS."
		none.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		none.add_theme_font_size_override("font_size", 11)
		none.add_theme_color_override("font_color", Palette.AMBER_DIM)
		_body.add_child(none)


func _lab_row(sid: String) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)

	var held := GameState.cargo_count(sid)
	var name_row := HBoxContainer.new()
	var title := Label.new()
	title.text = "%s  x%d" % [CommodityDB.display(sid).to_upper(), held]
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", CommodityDB.color_of(sid))
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_row.add_child(title)
	box.add_child(name_row)

	# A lab reads one band further than you can manage in the field, so there is
	# always a reason to carry something home and always a reason to raise the
	# skill. Both stay true at every tier.
	var readable := GameState.can_read(sid, true)
	if not readable:
		var locked := Label.new()
		locked.text = "UNREADABLE — ARCHEOLOGY %d NEEDED" % maxi(CommodityDB.band_of(sid) - 1, 0)
		locked.add_theme_font_size_override("font_size", 10)
		locked.add_theme_color_override("font_color", Palette.THREAT)
		box.add_child(locked)
		return box

	var opts := HFlowContainer.new()
	opts.add_theme_constant_override("h_separation", 6)
	for out_v in CommodityDB.reads_as(sid):
		var out := String(out_v)
		opts.add_child(_mini_button("%s" % CommodityDB.short_name(out),
			func() -> void: _do_read(sid, out)))
	box.add_child(opts)
	return box


func _do_read(sid: String, out: String) -> void:
	if not GameState.identify(sid, out, true):
		_reject()
		_refresh()
		return
	Sfx.play("equip", -8.0, 1.25)
	var main := get_tree().get_first_node_in_group("main")
	if main and main.hud:
		main.hud.show_toast("READ AS %s" % CommodityDB.short_name(out),
			CommodityDB.color_of(out))
		main.hud.refresh_cargo()
		if GameState.last_read_tiered:
			main.hud.show_toast("ARCHEOLOGY %d — %s NOW READS IN THE FIELD" % [
				GameState.archeology, DeepSpace.BAND_NAMES[GameState.archeology]],
				Palette.GOLD)
	_refresh()


func _do_repair(price: int) -> void:
	var player: PlayerShip = get_tree().get_first_node_in_group("player")
	if player == null or not GameState.spend_salvage(price):
		_reject()
		return
	player.repair_full()
	Sfx.play("equip", -4.0, 0.9)
	FX.ring_pulse(get_tree().get_first_node_in_group("main"),
		player.global_position, Palette.TEAL, 2.0, 0.6)
	var main := get_tree().get_first_node_in_group("main")
	if main and main.hud:
		main.hud.set_value(GameState.salvage)
	_refresh()


# --- paint ------------------------------------------------------------------

func _build_paint() -> void:
	var price := int(_port_def.get("paint_price", PAINT_PRICE))
	var head := Label.new()
	head.text = "HULL AND TRIM. %s SALVAGE THE JOB." % _comma(price)
	head.add_theme_font_size_override("font_size", 10)
	head.add_theme_color_override("font_color", Palette.AMBER_DIM)
	_body.add_child(head)

	_body.add_child(_swatch_grid("HULL", Palette.LIVERY_HULLS,
		GameState.livery_index("hull"), price, true))
	_body.add_child(_swatch_grid("ACCENT", Palette.LIVERY_ACCENTS,
		GameState.livery_index("accent"), price, false))

	# The nameplate. Identity edits live where identity lives: the same counter
	# that paints the hull letters it. Title screen shows the name; only here
	# changes it.
	var name_row := HBoxContainer.new()
	name_row.add_theme_constant_override("separation", 8)
	var name_label := Label.new()
	name_label.text = "NAMEPLATE"
	name_label.add_theme_font_size_override("font_size", 12)
	name_label.add_theme_color_override("font_color", Palette.HULL)
	name_row.add_child(name_label)
	var name_edit := LineEdit.new()
	name_edit.text = GameState.ship_name
	name_edit.max_length = GameState.SHIP_NAME_MAX
	name_edit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	name_edit.add_theme_font_size_override("font_size", 12)
	name_row.add_child(name_edit)
	var name_set := Button.new()
	name_set.text = "LETTER IT"
	name_set.add_theme_font_size_override("font_size", 11)
	name_set.pressed.connect(func() -> void:
		GameState.set_ship_name(name_edit.text)
		name_edit.text = GameState.ship_name
		Sfx.play("equip", -8.0, 1.1)
		var m := get_tree().get_first_node_in_group("main")
		if m and m.hud:
			m.hud.show_toast("REGISTERED AS %s" % GameState.ship_name, Palette.GOLD))
	name_row.add_child(name_set)
	_body.add_child(name_row)

	var note := Label.new()
	note.text = "The Core still sets the ability glow and the engine bloom — paint never hides what you are flying."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	_body.add_child(note)


func _swatch_grid(label: String, entries: Array, current: int, price: int, is_hull: bool) -> Control:
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 4)

	var title := Label.new()
	title.text = "%s — %s" % [label, String((entries[posmod(current, entries.size())] as Dictionary)["name"])]
	title.add_theme_font_size_override("font_size", 12)
	title.add_theme_color_override("font_color", Palette.HULL)
	box.add_child(title)

	var grid := GridContainer.new()
	# Nine, not eight: the earned REGISTRY accent is a ninth swatch, and at eight
	# columns it wraps onto a row of its own -- which reads as a rendering fault
	# rather than as the rarest thing on the screen.
	grid.columns = 9
	grid.add_theme_constant_override("h_separation", 5)
	grid.add_theme_constant_override("v_separation", 5)
	box.add_child(grid)

	for i in range(entries.size()):
		var entry: Dictionary = entries[i]
		var worn := i == posmod(current, entries.size())
		var locked := not _can_wear(i, is_hull)
		var b := Button.new()
		b.custom_minimum_size = Vector2(32, 32)
		# A locked swatch says what it is and what it costs -- which is not money.
		# Naming the requirement is the difference between a reward and a tease.
		b.tooltip_text = String(entry["name"])
		if locked:
			b.tooltip_text += " — EARNED AT COMMISSIONED"
			# Drawn, not disabled. `b.disabled = true` renders through the
			# disabled stylebox, and the point of the ninth swatch is that you can
			# SEE the colour you have not earned; a control that greys out to
			# nothing removes the reason to want it.
			b.modulate = Color(1, 1, 1, 0.45)

		# Four distinct boxes. All four states used to share one instance, so a
		# swatch gave no hover feedback at all and a disabled one was
		# indistinguishable from an available one -- on the single screen in the
		# game whose entire job is comparing sixteen things that differ only by
		# colour.
		var normal := _swatch_box(entry["color"], worn, 0.0)
		b.add_theme_stylebox_override("normal", normal)
		# Hover brightens the ring rather than the paint: the swatch has to keep
		# showing the colour truthfully, because that is what is being bought.
		b.add_theme_stylebox_override("hover", _swatch_box(entry["color"], worn, 0.45))
		b.add_theme_stylebox_override("pressed", _swatch_box(entry["color"], worn, 0.8))
		b.add_theme_stylebox_override("disabled", _swatch_box(entry["color"], worn, 0.0, 0.35))

		# Scale on hover, about the centre. pivot_offset has to be set after the
		# control has a size, hence the deferred connect rather than reading
		# b.size here, which is still zero during the build.
		b.mouse_entered.connect(func() -> void: _swatch_scale(b, UIKit.HOVER_SCALE))
		b.mouse_exited.connect(func() -> void: _swatch_scale(b, 1.0))

		var index := i
		b.pressed.connect(func() -> void:
			UIKit.press_pop(b)
			_apply_paint(index, is_hull, price))
		grid.add_child(b)
	return box


# --- the Grand Commission ----------------------------------------------------

func _build_commission() -> void:
	# The survey authority's file on you. Every line here is a STATEMENT OF
	# RECORD, never an instruction -- "44 OF 60 SURVEYS ON FILE", not "sell 16
	# more surveys". The distinction is the whole design: the Commission is the
	# GSA describing what you have done, and the moment it starts telling you
	# what to do next it is a quest board with a nicer font. There is no HUD
	# tracker for it anywhere, for the same reason.
	var head := Label.new()
	head.text = "GRAND COMMISSION — REGISTRY OF SURVEY"
	head.add_theme_font_size_override("font_size", 15)
	head.add_theme_color_override("font_color", Palette.GOLD)
	_body.add_child(head)

	var claimed := GameState.commission_claimed
	for i in range(CommissionDB.count()):
		var st: Dictionary = CommissionDB.stage(i)
		var row := VBoxContainer.new()
		row.add_theme_constant_override("separation", 1)

		var name_label := Label.new()
		var done := i < claimed
		name_label.text = ("✓ " if done else "") + String(st["name"])
		name_label.add_theme_font_size_override("font_size", 13)
		name_label.add_theme_color_override("font_color",
			Palette.GOLD if done else (Palette.AMBER if i == claimed else Palette.AMBER_DIM))
		row.add_child(name_label)

		var desc := Label.new()
		desc.text = String(st["desc"])
		desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		desc.custom_minimum_size = Vector2(280, 0)
		desc.add_theme_font_size_override("font_size", 10)
		desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
		row.add_child(desc)

		# Only the stage actually up for claiming shows its shortfall. Printing
		# all four turns the page into a checklist of everything you have not
		# done, which is the posture this system exists to avoid.
		if i == claimed:
			for line in CommissionDB.shortfalls(i, GameState.ledger):
				var sf := Label.new()
				sf.text = line
				sf.add_theme_font_size_override("font_size", 11)
				sf.add_theme_color_override("font_color", Palette.AMBER_DIM)
				row.add_child(sf)
		_body.add_child(row)

	_body.add_child(_spacer_row(6))

	if GameState.commission_complete():
		var closed := Label.new()
		closed.text = "THE FILE IS CLOSED. THE REGISTRY CARRIES YOUR NAME."
		closed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		closed.custom_minimum_size = Vector2(280, 0)
		closed.add_theme_font_size_override("font_size", 11)
		closed.add_theme_color_override("font_color", Palette.GOLD)
		_body.add_child(closed)
		return

	var stage := GameState.commission_stage()
	var pays := int(CommissionDB.stage(stage).get("pays", 0))
	if GameState.commission_ready():
		var b := UIKit.button("CLAIM %s — %d" % [String(CommissionDB.stage(stage)["name"]), pays],
			Palette.GOLD, 14)
		b.pressed.connect(func() -> void: _claim_commission())
		_body.add_child(b)
	else:
		var pending := Label.new()
		pending.text = "%s — %d ON ACKNOWLEDGEMENT" % [
			String(CommissionDB.stage(stage)["name"]), pays]
		pending.add_theme_font_size_override("font_size", 11)
		pending.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
		_body.add_child(pending)


func _claim_commission() -> void:
	# GameState.claim_commission re-checks the stage and the thresholds itself
	# and increments BEFORE it pays, because add_salvage emits salvage_changed
	# and _ready wires that straight back into _refresh() -- so a claim that paid
	# first would rebuild this sheet reading the pre-claim stage and redraw the
	# button it had just honoured.
	var result := GameState.claim_commission()
	if result.is_empty():
		_reject()
		return

	# The one moment in the game where the authority answers. Everything fires at
	# once on purpose: this is the payoff for a whole run, and it is the only
	# place shake, haptics, a burst and a count-up all land together.
	Sfx.play("equip", -2.0, 0.85)
	Sfx.haptic("heavy")
	var main := get_tree().get_first_node_in_group("main")
	if main:
		var rig := get_tree().get_first_node_in_group("camera_rig")
		if rig:
			rig.shake(0.09)
			rig.punch_zoom(0.7)
		if _port != null:
			FX.burst(_port.get_parent(), _port.global_position, Palette.GOLD, 46, 7.0, 0.26, 0.9)
			FX.ring_pulse(_port.get_parent(), _port.global_position, Palette.GOLD, 3.4, 0.7)
		# The HUD salvage readout is not wired to salvage_changed -- every payer
		# in this file sets it by hand.
		if main.hud:
			main.hud.set_value(GameState.salvage)
			main.hud.show_toast("%s — GSA REGISTRY" % String(result["name"]), Palette.GOLD)
	_refresh()


func _spacer_row(h: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(0, h)
	return c


func _can_wear(index: int, is_hull: bool) -> bool:
	# The gate for earned cosmetics, at the purchase layer rather than inside
	# GameState.set_livery -- set_livery is also how a save restores a colour, and
	# a lock that lives there would silently rewrite a legitimately earned livery
	# on load. Today every hull and the first eight accents are always wearable;
	# this exists so the Commission's ninth accent has exactly one place to say no.
	if is_hull:
		return index < Palette.LIVERY_HULLS.size()
	return index < Palette.LIVERY_ACCENTS.size() and GameState.accent_unlocked(index)


func _swatch_box(color: Color, worn: bool, lift: float, fade := 1.0) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(color.r, color.g, color.b, fade)
	sb.set_corner_radius_all(5)
	# The one you are wearing is ringed, so the current choice is readable
	# without reading the label above.
	sb.set_border_width_all(3 if worn else (2 if lift > 0.0 else 1))
	var base := Palette.GOLD if worn else Color(1, 1, 1, 0.18)
	sb.border_color = base.lerp(Palette.WHITE_HOT, lift)
	return sb


func _swatch_scale(b: Button, to: float) -> void:
	if GameState.reduce_motion():
		return
	b.pivot_offset = b.size * 0.5
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2.ONE * to, UIKit.T_INSTANT) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)


func _apply_paint(index: int, is_hull: bool, price: int) -> void:
	var current := GameState.livery_index("hull" if is_hull else "accent")
	if index == current:
		# Charging for the colour already on the hull would be a trap, not a
		# purchase. Refuse quietly.
		_reject()
		return
	# Decide, then charge, then apply. The old order spent first and applied
	# second, so any refusal added between the two -- which is exactly what the
	# Commission's locked ninth accent is -- would take the salvage and leave the
	# hull its old colour. Nothing between these two lines may fail.
	if not _can_wear(index, is_hull):
		_reject()
		return
	if not GameState.spend_salvage(price):
		_reject()
		return
	if is_hull:
		GameState.set_livery(index, GameState.livery_index("accent"))
	else:
		GameState.set_livery(GameState.livery_index("hull"), index)
	Sfx.play("equip", -5.0, 1.05)
	Sfx.haptic("light")
	var main := get_tree().get_first_node_in_group("main")
	if main and main.hud:
		main.hud.set_value(GameState.salvage)
	_refresh()


# --- fence (smuggler's den) --------------------------------------------------

func _build_fence() -> void:
	var goods: Array = _port_def.get("fence_goods", [])
	var mult := float(_port_def.get("fence_mult", 1.0))
	var head := Label.new()
	head.text = "NO QUESTIONS. %d%% OVER LOCAL, PAID ON THE SPOT." % int(round((mult - 1.0) * 100.0))
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_theme_font_size_override("font_size", 10)
	head.add_theme_color_override("font_color", Palette.THREAT)
	_body.add_child(head)

	for good_v in goods:
		var good := String(good_v)
		if not CommodityDB.exists(good):
			continue
		_body.add_child(_fence_row(good))


func _fence_row(good: String) -> Control:
	var held := GameState.cargo_count(good)
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.THREAT.r, Palette.THREAT.g, Palette.THREAT.b, 0.06)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	row.add_theme_stylebox_override("panel", style)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	row.add_child(box)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", -1)
	box.add_child(left)

	var name_line := Label.new()
	name_line.text = "%s   ×%d" % [CommodityDB.display(good), held]
	name_line.add_theme_font_size_override("font_size", 13)
	name_line.add_theme_color_override("font_color",
		CommodityDB.color_of(good) if held > 0 else Palette.HULL)
	left.add_child(name_line)

	var fenced := Market.sell_price(_port_def, _port.port_id, good, maxi(held, 1))
	var clean := int(round(float(fenced) / maxf(Market.fence_bonus(_port_def, good), 0.01)))
	var sub := Label.new()
	sub.text = "FENCE %d/unit   (clean price %d)" % [fenced, clean]
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Palette.AMBER_DIM)
	left.add_child(sub)

	box.add_child(_mini_button("-1", func() -> void: _sell(good, 1)))
	box.add_child(_mini_button("ALL", func() -> void: _sell(good, GameState.cargo_count(good))))
	return row


# --- rumors (cantina) --------------------------------------------------------

func _build_rumors() -> void:
	var price := int(_port_def.get("rumor_price", 400))
	var head := Label.new()
	head.text = "SOMEBODY ALWAYS KNOWS SOMETHING. %s SALVAGE A WORD." % _comma(price)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_theme_font_size_override("font_size", 10)
	head.add_theme_color_override("font_color", Palette.AMBER_DIM)
	_body.add_child(head)

	# Anything already bought stays visible for the session, so the purchase
	# feels like information gained rather than a toast that flashed past.
	for line in _rumors_known:
		var known := Label.new()
		known.text = "· %s" % line
		known.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		known.add_theme_font_size_override("font_size", 12)
		known.add_theme_color_override("font_color", Palette.GOLD)
		_body.add_child(known)

	var buy := Button.new()
	buy.text = "BUY INTEL   %s" % _comma(price)
	buy.custom_minimum_size = Vector2(0, 36)
	buy.add_theme_font_size_override("font_size", 12)
	buy.disabled = GameState.salvage < price
	buy.pressed.connect(func() -> void: _buy_rumor(price))
	_body.add_child(buy)

	var note := Label.new()
	note.text = "Intel names one market event on the chart — where it is, what it is, and how long it holds."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	_body.add_child(note)

	_build_hunt_desk()


func _build_hunt_desk() -> void:
	# THE SECOND THING SOLD OVER THIS BAR, and deliberately a separate row from
	# the market rumour above it. They are different goods: one is news about
	# prices that expires, the other is a line on a chart that does not. Folding
	# the hunt into `_rumor_text`'s ladder would have made buying a bearing a
	# matter of first exhausting every glut on the board.
	var price := int(_port_def.get("hunt_price", 0))
	if price <= 0:
		return
	var main := get_tree().get_first_node_in_group("main")
	if main == null or not main.has_method("file_apex_intel"):
		return
	var sys_id := String(main.system_id)
	# Nothing to sell once the engine is dead — and nothing to sell about a
	# system that never had one.
	var apex: Dictionary = SystemDB.get_system(sys_id).get("apex", {})
	if apex.is_empty() or GameState.has_killed_apex(sys_id):
		return

	var err := float(_port_def.get("hunt_error", 0.0))
	var rule := HSeparator.new()
	_body.add_child(rule)

	var head := Label.new()
	head.text = "THE HUNT — %s" % String(apex.get("name", "THE ENGINE"))
	head.add_theme_font_size_override("font_size", 12)
	head.add_theme_color_override("font_color", Palette.GOLD)
	_body.add_child(head)

	var buy := Button.new()
	buy.text = "BUY BEARING ±%d°   %s" % [int(round(err)), _comma(price)] if err > 0.0 \
		else "BUY THE WORD   %s" % _comma(price)
	buy.custom_minimum_size = Vector2(0, 36)
	buy.add_theme_font_size_override("font_size", 12)
	buy.disabled = GameState.salvage < price
	buy.pressed.connect(func() -> void: _buy_hunt_intel(price, err))
	_body.add_child(buy)

	var note := Label.new()
	note.text = ("A bearing to the engine, good to ±%d°. Plotted on the chart with everything else you have heard."
		% int(round(err))) if err > 0.0 \
		else "Which band it is transmitting from, and which quarter of the sky. No bearing — that is a deeper conversation."
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	_body.add_child(note)


func _buy_hunt_intel(price: int, err: float) -> void:
	var main := get_tree().get_first_node_in_group("main")
	if main == null or not main.has_method("file_apex_intel"):
		return
	if GameState.salvage < price:
		_reject()
		return
	# FILED FIRST, CHARGED SECOND. add_apex_hint refuses a reading it already
	# holds, and a desk that took the money anyway would be selling the same
	# sentence twice — the one thing a rumour desk must never do.
	var player: Node3D = get_tree().get_first_node_in_group("player")
	var from: Vector3 = player.global_position if player != null else Vector3.ZERO
	if not main.file_apex_intel("watch" if err > 0.0 else "rumor", from, err):
		_reject()
		return
	if not GameState.spend_salvage(price):
		_reject()
		return
	Sfx.play("equip", -6.0, 1.2)
	if main.hud:
		main.hud.set_value(GameState.salvage)
	_refresh()


func _buy_rumor(price: int) -> void:
	if GameState.salvage < price or not GameState.spend_salvage(price):
		_reject()
		return
	_rumors_known.append(_rumor_text())
	Sfx.play("equip", -6.0, 1.2)
	var main := get_tree().get_first_node_in_group("main")
	if main and main.hud:
		main.hud.set_value(GameState.salvage)
	_refresh()


func _rumor_text() -> String:
	# Prefers a live event, because that is what the player is paying for. With
	# nothing running it sells a genuine read on the market instead of a lie —
	# the cantina is a shortcut, never a con.
	#
	# A rift outranks everything: it is the scarcest thing on the ladder and the
	# only one with a fuse. No printer lives here — the shear exists and pays
	# identically whether or not anyone bought the word.
	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("rift_rumor"):
		var rift_line := String(main.rift_rumor())
		if rift_line != "" and not _rumors_known.has(rift_line):
			return rift_line
	var unheard := []
	for e in GameState.market_events:
		var ev: Dictionary = e
		var line := "%s at %s — %s, %s left" % [
			Market.event_label(ev).capitalize(),
			String(SystemDB.port_def_by_id(String(ev["port"])).get("name", "?")),
			CommodityDB.short_name(String(ev["good"])),
			_mmss(float(ev.get("remaining", 0.0)))]
		if not _rumors_known.has(line):
			unheard.append(line)
	if not unheard.is_empty():
		return String(unheard[0])

	# No events running: name the best standing spread anyone here knows about.
	var best_line := "Nothing moving on the chart tonight. Prices are what they look like."
	var best_margin := 0
	for good_v in CommodityDB.ids():
		var good := String(good_v)
		for a_v in SystemDB.port_ids():
			for b_v in SystemDB.port_ids():
				var a := String(a_v)
				var b := String(b_v)
				if a == b or not CommodityDB.trades_at(good, a) or not CommodityDB.trades_at(good, b):
					continue
				var margin := Market.sell_price(SystemDB.port_def_by_id(b), b, good) \
					- Market.buy_price(SystemDB.port_def_by_id(a), a, good)
				if margin > best_margin:
					best_margin = margin
					best_line = "%s moves %s to %s for about %d a unit right now." % [
						CommodityDB.short_name(good),
						String(SystemDB.port_def_by_id(a).get("name", "?")),
						String(SystemDB.port_def_by_id(b).get("name", "?")), margin]
	return best_line


# --- games (cantina) ---------------------------------------------------------

func _build_games() -> void:
	var head := Label.new()
	head.text = "PULSE. DOUBLE OR NOTHING, %d%% TO YOU. THE HOUSE IS HONEST AND THE HOUSE STILL WINS." % \
		int(round(GAMBLE_WIN_CHANCE * 100.0))
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_theme_font_size_override("font_size", 10)
	head.add_theme_color_override("font_color", Palette.AMBER_DIM)
	_body.add_child(head)

	var status := Label.new()
	status.text = "STREAK %d / %d" % [_gamble_streak, GAMBLE_STREAK_LIMIT]
	status.add_theme_font_size_override("font_size", 12)
	status.add_theme_color_override("font_color", Palette.GOLD if _gamble_streak > 0 else Palette.AMBER_DIM)
	_body.add_child(status)

	if _gamble_last != "":
		var last := Label.new()
		last.text = _gamble_last
		last.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		last.add_theme_font_size_override("font_size", 13)
		last.add_theme_color_override("font_color",
			Palette.GOLD if _gamble_last_win else Palette.THREAT)
		_body.add_child(last)

	var locked := _gamble_streak >= GAMBLE_STREAK_LIMIT
	if locked:
		var note := Label.new()
		note.text = "The table is closed to you tonight. Come back after a run."
		note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		note.add_theme_font_size_override("font_size", 11)
		note.add_theme_color_override("font_color", Palette.THREAT)
		_body.add_child(note)

	for stake in GAMBLE_STAKES:
		var amount := int(stake)
		var b := Button.new()
		b.text = "WAGER %s" % _comma(amount)
		b.custom_minimum_size = Vector2(0, 34)
		b.add_theme_font_size_override("font_size", 12)
		b.disabled = locked or GameState.salvage < amount
		b.pressed.connect(func() -> void: _wager(amount))
		_body.add_child(b)


func _wager(amount: int) -> void:
	if _gamble_streak >= GAMBLE_STREAK_LIMIT or not GameState.spend_salvage(amount):
		_reject()
		return
	# The stated odds are the real odds. A rigged number the player cannot see
	# would be the one dishonest thing in a game about reading a market.
	var won := randf() < GAMBLE_WIN_CHANCE
	if won:
		GameState.add_salvage(amount * 2)
		_gamble_streak += 1
		_gamble_last = "PULSE HOLDS. +%s" % _comma(amount)
		_gamble_last_win = true
		Sfx.play_streak("pickup", -4.0)
	else:
		_gamble_streak = 0
		_gamble_last = "PULSE BREAKS. -%s" % _comma(amount)
		_gamble_last_win = false
		Sfx.play("hit", -8.0, 0.7)
	var main := get_tree().get_first_node_in_group("main")
	if main and main.hud:
		main.hud.set_value(GameState.salvage)
	_refresh()


# --- contract board ---------------------------------------------------------

func _build_contract_board() -> void:
	var contracts := _contracts()
	if contracts == null:
		return

	var head := Label.new()
	var free := contracts.slots_free()
	head.text = "%d OF %d SLOTS OPEN   ·   BOARD REFRESHES IN %s" % [
		free, ContractDB.ACTIVE_SLOTS,
		_mmss(ContractDB.seconds_until_rotation(GameState.played_seconds))]
	head.add_theme_font_size_override("font_size", 10)
	head.add_theme_color_override("font_color", Palette.AMBER_DIM)
	_body.add_child(head)

	for offer in contracts.board(_port.port_id):
		_body.add_child(_contract_row(offer, free))


func _contract_row(offer: Dictionary, slots_free: int) -> Control:
	var accepted: bool = bool(offer["accepted"])
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.TEAL.r, Palette.TEAL.g, Palette.TEAL.b, 0.09 if accepted else 0.035)
	style.border_color = Color(Palette.TEAL.r, Palette.TEAL.g, Palette.TEAL.b, 0.3 if accepted else 0.14)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	row.add_theme_stylebox_override("panel", style)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	row.add_child(box)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", -1)
	box.add_child(left)

	var title := Label.new()
	title.text = String(offer["title"])
	title.add_theme_font_size_override("font_size", 13)
	title.add_theme_color_override("font_color", Palette.GOLD if accepted else Palette.HULL)
	left.add_child(title)

	var desc := Label.new()
	desc.text = String(offer["desc"])
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(180, 0)
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	left.add_child(desc)

	var pay := Label.new()
	pay.text = "+%s SALVAGE" % _comma(int(offer["reward"]))
	pay.add_theme_font_size_override("font_size", 10)
	pay.add_theme_color_override("font_color", Palette.AMBER)
	left.add_child(pay)

	var id := String(offer["id"])
	if accepted:
		box.add_child(_mini_button("DROP", func() -> void: _drop_contract(id)))
	else:
		var take := Button.new()
		take.text = "ACCEPT"
		take.custom_minimum_size = Vector2(76, 30)
		take.add_theme_font_size_override("font_size", 12)
		# Disabled rather than hidden when full, so the reason is visible: you
		# have two, and two is the limit.
		take.disabled = slots_free <= 0
		take.pressed.connect(func() -> void: _accept_contract(id))
		box.add_child(take)
	return row


func _contracts() -> Contracts:
	var main := get_tree().get_first_node_in_group("main")
	return main.contracts if main else null


func _accept_contract(id: String) -> void:
	var c := _contracts()
	if c and c.accept(id):
		Sfx.play("equip", -6.0, 1.15)
	else:
		_reject()
	_refresh()


func _drop_contract(id: String) -> void:
	var c := _contracts()
	if c and c.drop(id):
		Sfx.play("equip", -10.0, 0.8)
	else:
		_reject()
	_refresh()


func _mmss(seconds: float) -> String:
	var s := maxi(0, int(seconds))
	return "%d:%02d" % [s / 60, s % 60]


func _market_row(good: String) -> Control:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.04)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	row.add_theme_stylebox_override("panel", style)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	row.add_child(box)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", -1)
	box.add_child(left)

	var held := GameState.cargo_count(good)
	var name_line := Label.new()
	name_line.text = "%s   ×%d" % [CommodityDB.display(good), held]
	name_line.add_theme_font_size_override("font_size", 13)
	name_line.add_theme_color_override("font_color",
		CommodityDB.color_of(good) if held > 0 else Palette.HULL)
	left.add_child(name_line)

	# Trend arrow + event tag: the whole "is this a deal?" question, answered
	# without arithmetic.
	var trend := Market.trend(_port_def, _port.port_id, good)
	var ev := Market.event_for(_port.port_id, good)
	var sub := Label.new()
	var arrow := "▲ HIGH" if trend > 0 else ("▼ LOW" if trend < 0 else "— STEADY")
	var tag := ("   [%s]" % Market.event_label(ev)) if not ev.is_empty() else ""
	sub.text = "%s%s   %d/unit space" % [arrow, tag, CommodityDB.space_of(good)]
	sub.add_theme_font_size_override("font_size", 10)
	var sub_col := Palette.AMBER_DIM
	if trend > 0:
		sub_col = Palette.GOLD
	elif trend < 0:
		sub_col = Palette.TEAL
	if not ev.is_empty():
		sub_col = Market.event_color(ev)
	sub.add_theme_color_override("font_color", sub_col)
	left.add_child(sub)

	var buy_price := Market.buy_price(_port_def, _port.port_id, good)
	var sell_price := Market.sell_price(_port_def, _port.port_id, good)

	# A bulk break the player cannot see is a bulk break that does not exist.
	var bulk_units := int(_port_def.get("bulk_units", 0))
	if bulk_units > 0:
		var note := Label.new()
		note.text = "BULK %d+: buy %d / sell %d" % [bulk_units,
			Market.buy_price(_port_def, _port.port_id, good, bulk_units),
			Market.sell_price(_port_def, _port.port_id, good, bulk_units)]
		note.add_theme_font_size_override("font_size", 10)
		note.add_theme_color_override("font_color", Palette.TEAL)
		left.add_child(note)

	var buys := VBoxContainer.new()
	buys.add_theme_constant_override("separation", 2)
	if Market.can_buy(_port_def, good):
		buys.add_child(_price_label("BUY %d" % buy_price, Palette.AMBER_DIM))
		var buy_row := HBoxContainer.new()
		buy_row.add_theme_constant_override("separation", 3)
		buy_row.add_child(_mini_button("+1", func() -> void: _buy(good, 1)))
		# The second step matches the bulk threshold where there is one, so the
		# discount is reachable without counting single purchases.
		var step := maxi(5, int(_port_def.get("bulk_units", 0)))
		buy_row.add_child(_mini_button("+%d" % step, func() -> void: _buy(good, step)))
		buys.add_child(buy_row)
	else:
		# A fence takes these off your hands and does not sell them back.
		buys.add_child(_price_label("FENCED", Palette.THREAT))
		buys.add_child(_price_label("NOT SOLD HERE", Palette.AMBER_DIM))
	box.add_child(buys)

	var sells := VBoxContainer.new()
	sells.add_theme_constant_override("separation", 2)
	sells.add_child(_price_label("SELL %d" % sell_price, Palette.GOLD))
	var sell_row := HBoxContainer.new()
	sell_row.add_theme_constant_override("separation", 3)
	sell_row.add_child(_mini_button("-1", func() -> void: _sell(good, 1)))
	sell_row.add_child(_mini_button("ALL", func() -> void: _sell(good, GameState.cargo_count(good))))
	sells.add_child(sell_row)
	box.add_child(sells)
	return row


func _price_label(text: String, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", color)
	return l


func _mini_button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(38, 26)
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(cb)
	return b


func _module_row(id: String) -> Control:
	var m := ModuleDB.get_module(id)
	var owned := GameState.owns(id)
	var price := _module_price(id)

	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.09 if owned else 0.035)
	style.border_color = Color(Palette.AMBER.r, Palette.AMBER.g, Palette.AMBER.b, 0.22)
	style.set_border_width_all(1)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	row.add_theme_stylebox_override("panel", style)

	var box := HBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	row.add_child(box)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", -1)
	box.add_child(left)

	var name_line := Label.new()
	name_line.text = String(m.get("name", id))
	name_line.add_theme_font_size_override("font_size", 13)
	name_line.add_theme_color_override("font_color", Palette.GOLD if owned else Palette.HULL)
	left.add_child(name_line)

	var desc := Label.new()
	desc.text = String(m.get("desc", ""))
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	left.add_child(desc)

	# The store used to show a name, one line of flavour text and a number, and
	# that was the entire basis for a 19,500-credit decision -- not even the
	# "%d PWR" the refit console has always printed, on the screen where the
	# module is actually BOUGHT. Both go here now.
	#
	# Previewed into the slot this module would really occupy rather than a fixed
	# one, or a second Cargo Bay would preview into the bay already fitted and
	# report that it changes nothing.
	var meta := HBoxContainer.new()
	meta.add_theme_constant_override("separation", 8)
	left.add_child(meta)

	var pwr := Label.new()
	pwr.text = "%d PWR" % int(m.get("power", 0))
	pwr.add_theme_font_size_override("font_size", 10)
	pwr.add_theme_color_override("font_color", Palette.AMBER_DIM)
	meta.add_child(pwr)

	var slot := ModuleDB.default_slot(id, GameState.fit)
	if slot >= 0:
		var delta := UIKit.delta_line(GameState.preview_stats(slot, id), 10)
		if delta != null:
			delta.size_flags_horizontal = Control.SIZE_EXPAND_FILL
			meta.add_child(delta)

	if owned:
		var sellable := not ModuleDB.STARTER_OWNED.has(id)
		if sellable:
			box.add_child(_mini_button("SELL", func() -> void: _sell_module(id)))
		var tag := Label.new()
		tag.text = "OWNED"
		tag.add_theme_font_size_override("font_size", 11)
		tag.add_theme_color_override("font_color", Palette.GOLD)
		box.add_child(tag)
	else:
		var buy := Button.new()
		buy.text = "%s" % _comma(price)
		buy.custom_minimum_size = Vector2(76, 30)
		buy.add_theme_font_size_override("font_size", 12)
		buy.disabled = GameState.salvage < price
		buy.pressed.connect(func() -> void: _buy_module(id))
		box.add_child(buy)
	return row


func _reactor_row() -> Control:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.TEAL.r, Palette.TEAL.g, Palette.TEAL.b, 0.06)
	style.set_corner_radius_all(6)
	style.content_margin_left = 10
	style.content_margin_right = 10
	style.content_margin_top = 7
	style.content_margin_bottom = 7
	row.add_theme_stylebox_override("panel", style)

	var box := HBoxContainer.new()
	row.add_child(box)

	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", -1)
	box.add_child(left)

	var name_line := Label.new()
	name_line.text = GameState.reactor_name()
	name_line.add_theme_font_size_override("font_size", 13)
	name_line.add_theme_color_override("font_color", Palette.TEAL)
	left.add_child(name_line)

	var sub := Label.new()
	sub.text = "Power %d / %d in use" % [GameState.power_draw(), GameState.power_cap()]
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Palette.AMBER_DIM)
	left.add_child(sub)

	var next_price := GameState.next_reactor_price()
	if next_price < 0:
		var tag := Label.new()
		tag.text = "MAX"
		tag.add_theme_font_size_override("font_size", 11)
		tag.add_theme_color_override("font_color", Palette.AMBER_DIM)
		box.add_child(tag)
	else:
		var b := Button.new()
		b.text = "UPGRADE %s" % _comma(next_price)
		b.custom_minimum_size = Vector2(120, 30)
		b.add_theme_font_size_override("font_size", 11)
		b.disabled = GameState.salvage < next_price
		b.pressed.connect(_upgrade_reactor)
		box.add_child(b)
	return row


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
