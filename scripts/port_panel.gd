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
	"requisitions": "ORDERS",
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
# One standing tick per docking session, however much is fenced — a bound, so
# selling forty crates one at a time is not forty acts of friendship.
var _fence_marked := false
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
	_fence_marked = false
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
	var price := Market.buy_price(_port_def, _port.port_id, good, units, _bay_key())
	var affordable := int(GameState.salvage / maxi(price, 1))
	var fits := GameState.cargo_free() / maxi(CommodityDB.space_of(good), 1)
	# v27. The shelf is the third clamp, beside the wallet and the hold, and it
	# reads exactly like them: you get what was there. REFUSAL IS FREE -- nothing
	# is charged or loaded above, so a bare counter costs the player nothing.
	var on_shelf := Market.stock_left(_port_def, _bay_key(), good)
	var n := mini(units, mini(mini(affordable, fits), on_shelf))
	if n <= 0:
		_reject()
		return
	# Re-priced at what actually fit: buying 5 and only affording 3 must not
	# quietly keep the 5-unit discount.
	price = Market.buy_price(_port_def, _port.port_id, good, n, _bay_key())
	if not GameState.spend_salvage(price * n):
		_reject()
		return
	GameState.load_cargo(good, n)
	Market.apply_trade_pressure(_bay_key(), good, n, false)
	Market.note_bought(_bay_key(), good, n)
	Sfx.play("equip", -7.0, 1.1)
	Barks.fire("first_trade")
	_refresh()


func _sell(good: String, units: int) -> void:
	var n := mini(units, GameState.cargo_count(good))
	if n <= 0:
		_reject()
		return
	# The fence gate, AT THE ACTION as well as at the build — survey_mast's
	# lesson, and REFUSAL IS FREE: nothing has been unloaded or paid yet, so a
	# closed back room costs the player exactly nothing to be refused by.
	if Market.fences(_port_def, good) and not Market.fence_open(_port_def):
		_reject()
		return
	var price := Market.sell_price(_port_def, _port.port_id, good, n, _bay_key())
	GameState.unload_cargo(good, n)
	GameState.add_salvage(price * n)
	if CommodityDB.is_chart(good):
		GameState.note_ledger("chart_data_sold", n)
		# v22. The provenance half. AFTER the market half above has unloaded and
		# paid, so the settlement can be a pure bonus -- and through main, which
		# owns the world-side glue (which band a cell sits in), per
		# drop_beacon_here's split: the counter is a button, the rule lives
		# elsewhere.
		var m_file := get_tree().get_first_node_in_group("main")
		if m_file and m_file.has_method("file_charts_on_sale"):
			m_file.file_charts_on_sale(good, n)
	# SMUGGLING's one feed. At a FENCE specifically — the whole skill is about who
	# will deal with you off the books, and selling stolen goods over a legitimate
	# counter is not that.
	# v18 stage 5. A fence deal is an act the owner notices — once per dock,
	# +1, through the one mutator. The smuggling feed below is unchanged.
	if Market.fences(_port_def, good) and not _fence_marked:
		var fence_owner := Market.owner_of(_port_def)
		if fence_owner != "" and FactionDB.is_faction(fence_owner):
			_fence_marked = true
			GameState.shift_faction(FactionDB.SURVEYOR, fence_owner, 1, true)
	if GameState.SMUGGLING_GOODS.has(good) and Market.fences(_port_def, good):
		if GameState.mark_smuggling(n):
			var m0 := get_tree().get_first_node_in_group("main")
			if m0 and m0.hud:
				m0.hud.show_toast("SMUGGLING %d — %s" % [GameState.smuggling,
					"THE LANES KNOW YOU" if GameState.smuggling < 3
					else "EVERY DEEP FENCE DEALS WITH YOU"], Palette.GOLD)
	Market.apply_trade_pressure(_bay_key(), good, n, true)
	Market.note_sold(_bay_key(), good, n)
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


func _reactor_cap() -> int:
	# What this counter is allowed to sell. One reader, so the row and the button
	# cannot disagree about it — a button that offers what the row says is not
	# stocked is the shape of bug this pair invites.
	return int(_port_def.get("reactor_cap", ModuleDB.REACTOR_CAP_DEFAULT))


func _upgrade_reactor() -> void:
	if GameState.upgrade_reactor(_reactor_cap()):
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

	# v18 stage 5. THE DOCK LINE — the whole standing UI, and deliberately no
	# more than this. Standing already moves (the muster shifts it, unprovoked
	# kills cost it) and until this line it moved invisibly; gating anything on
	# a number the player cannot see is the hidden bad bet §12 calls a con. A
	# statement of record at dock, the Commission's posture — never a HUD row.
	# On EVERY tab rather than one, because which tab is the landing tab varies
	# by port and a record you have to hunt for is not a record.
	var owner := Market.owner_of(_port_def)
	if owner != "" and FactionDB.is_faction(owner):
		var band := GameState.faction_band(FactionDB.SURVEYOR, owner)
		var standing := Label.new()
		standing.text = "%s — STANDING: %s" % [FactionDB.display_name(owner),
			FactionDB.BAND_NAMES[band]]
		standing.add_theme_font_size_override("font_size", 10)
		standing.add_theme_color_override("font_color",
			Palette.THREAT if band == FactionDB.Band.HOSTILE else Color(0.6, 0.62, 0.7))
		_body.add_child(standing)

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
		"requisitions":
			_build_requisitions()
		_:
			_body.add_child(_reactor_row())
			# v24 (§94). THE BERTHS SIT WITH THE REACTOR, not in the module
			# stock, because that is what they are: hull work, priced against
			# the power budget, bought once and never sold back. Putting them in
			# `stock` would have made them modules -- ownable, fittable,
			# swappable -- which is the one thing a welded hardpoint is not.
			#
			# Gated on the counter's reactor cap, the same key that decides
			# whether the Mk V is on the rack: a yard that cannot sell you the
			# reactor to run a berth has no business selling the berth.
			if _reactor_cap() >= ModuleDB.BERTH_YARD_TIER:
				for bid_v in ModuleDB.BERTHS:
					_body.add_child(_berth_row(String(bid_v)))
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
	var sources := ""
	for good_v in rec:
		var good := String(good_v)
		var need := int(rec[good])
		var have := GameState.cargo_count(good)
		parts += "%s %d/%d   " % [CommodityDB.short_name(good), have, need]
		# v22 (90). THE SOURCE LINE THE COMMENT ABOVE ALWAYS CLAIMED. "A
		# component names the read that produces it" was written up top and
		# never wired -- the bill printed have/need and nothing else, and a
		# playtest concluded the forge's inputs did not exist in the game.
		# Derived from READS_AS, the same table the reads use, so it cannot
		# drift: the shallowest salvage grade whose read table yields this
		# component names the band to go crack.
		# v27 (§110). THE "+" WAS A LIE, and it was the lie that produced the
		# second playtest report of the same complaint the first one fixed.
		# READS_AS IS NOT MONOTONE: sink fell from the Drift and nowhere deeper,
		# manifest from the Reaches and nowhere deeper, plate and cell from the
		# Charted and Shoals and nowhere deeper. This line took the SHALLOWEST
		# yielding grade and printed "BAND n+", so a pilot standing in the Quiet
		# with a hold of Quiet salvage, following the game's own instruction,
		# could read crate after crate and never once see four of the eight
		# inputs.
		#
		# It now names the grades themselves, from the same table, so it cannot
		# be wrong in that direction again: a grade is listed if and only if
		# reading it can produce this part.
		var from_grades := []
		for sal_v in CommodityDB.READS_AS:
			if (CommodityDB.READS_AS[sal_v] as Array).has(good):
				from_grades.append(CommodityDB.short_name(String(sal_v)))
		if not from_grades.is_empty() and have < need:
			sources += "%s READS OUT OF %s\n" % [
				CommodityDB.short_name(good), ", ".join(from_grades)]
	var bill := Label.new()
	bill.text = parts
	bill.add_theme_font_size_override("font_size", 10)
	bill.add_theme_color_override("font_color",
		Palette.GOLD if GameState.can_craft(id) else Palette.AMBER_DIM)
	box.add_child(bill)
	if sources != "":
		var src := Label.new()
		src.text = sources.strip_edges()
		src.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		src.add_theme_font_size_override("font_size", 9)
		src.add_theme_color_override("font_color", Palette.TEAL)
		box.add_child(src)

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
		# Floored, the same guard and for the same reason as archeology_line's:
		# this is the untested twin of that subtraction.
		("%d MORE TO THE NEXT GRADE" % maxi(next_at - GameState.archeology_xp, 0)) if next_at >= 0
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
			main.hud.show_toast("ARCHEOLOGY %d — IDENTIFY %s SALVAGE WITHOUT DOCKING" % [
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

	# v22 (90). WHAT THIS PAGE IS, in one breath, before the record begins. The
	# statement-of-record posture above is the design and it held for a year --
	# and a playtest still filed "sees no purpose for this tab", because a page
	# that refuses to be a quest log still owes the reader one sentence saying
	# what it IS. Describing the page is not instructing the player; the line
	# below states what the registry does and what standing it confers, and
	# then the record speaks for itself.
	var why := Label.new()
	why.text = ("THE GSA'S FILE ON YOUR SURVEY. STAGES ARE ACKNOWLEDGED HERE AS "
		+ "YOU EARN THEM — %d OF %d ON FILE — AND THE FULL COMMISSION CHANGES "
		+ "HOW THE AUTHORITY ADDRESSES YOU EVERYWHERE IT SPEAKS.") % [
		GameState.commission_claimed, CommissionDB.count()]
	why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	why.add_theme_font_size_override("font_size", 10)
	why.add_theme_color_override("font_color", Palette.AMBER_DIM)
	_body.add_child(why)

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

	# §92. THE FIELD THAT WAS SWITCHED OFF. Absent until the pilot has
	# read Directive 9, and that placement is the decision rather than an
	# accident: an unexplained dash sitting here from the first dock would be a
	# teaser, and this page does not tease -- it states. After the order it is
	# corroboration, in the registry's own plain voice, of something the player
	# has already been told out at the terminus.
	#
	# ABOVE the complete/claim branch below, which returns early: the field
	# belongs to the file, not to whether the file is finished.
	#
	# Resurvey 44 is THE FIRST MERIDIAN's own fragment -- the resurvey that found
	# the datum had moved. The two records agree about the date without either
	# one explaining the other.
	if GameState.knows_directive_9():
		var retired := Label.new()
		retired.text = "RETURNS LOGGED FROM THE RECLASSIFIED VOLUME: —"
		retired.add_theme_font_size_override("font_size", 12)
		retired.add_theme_color_override("font_color", Palette.AMBER)
		_body.add_child(retired)
		var retired_why := Label.new()
		retired_why.text = ("FIELD RETIRED AT RESURVEY 44. FILINGS FROM THE VOLUME "
			+ "ARE ACCEPTED AND COUNTED ABOVE.")
		retired_why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		retired_why.custom_minimum_size = Vector2(280, 0)
		retired_why.add_theme_font_size_override("font_size", 10)
		retired_why.add_theme_color_override("font_color", Palette.AMBER_DIM)
		_body.add_child(retired_why)
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
	# The gate renders as a REFUSAL, not an absence. A tab that silently showed
	# nothing would read as a bug; a fence that names why it will not deal with
	# you is the standing system doing its job out loud.
	if not Market.fence_open(_port_def):
		var shut := Label.new()
		shut.text = "THE BACK ROOM IS CLOSED TO YOU. Word travels. Come back when %s has fewer reasons to remember your name." \
			% FactionDB.display_name(Market.owner_of(_port_def))
		shut.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		shut.add_theme_font_size_override("font_size", 11)
		shut.add_theme_color_override("font_color", Palette.THREAT)
		_body.add_child(shut)
		return
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

	var fenced := Market.sell_price(_port_def, _port.port_id, good, maxi(held, 1),
		_bay_key())
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

	# A DEAD CONTROL IS ITS OWN KIND OF LIE -- the hunt desk's rule, two screens
	# down, applied here now that the ladder can genuinely run dry. The button
	# says which of the two reasons it is refusing for.
	var nothing_left := _rumor_text() == ""
	var buy := Button.new()
	buy.text = "NOTHING NEW TONIGHT" if nothing_left \
		else "BUY INTEL   %s" % _comma(price)
	buy.custom_minimum_size = Vector2(0, 36)
	buy.add_theme_font_size_override("font_size", 12)
	buy.disabled = nothing_left or GameState.salvage < price
	buy.pressed.connect(func() -> void: _buy_rumor(price))
	_body.add_child(buy)

	var note := Label.new()
	note.text = "Intel names one thing worth knowing — a market event, a counter that has run short, or the best run anyone can actually fill tonight."
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
	# THE WORD IS SOLD ONCE. A ring desk sells a band and a quarter, which is
	# exactly what the GSA relay now broadcasts free the moment the lane closes
	# -- and the dossier refuses a duplicate ring. Without this the bar would
	# render a live BUY button that can only ever reject, and a button that does
	# nothing is worse than no button. No credits were ever at risk (the desk
	# files before it spends), but a dead control is its own kind of lie.
	if err <= 0.0 and GameState.has_ring_hint(sys_id):
		var told_rule := HSeparator.new()
		_body.add_child(told_rule)
		var told := Label.new()
		told.text = "THE HUNT — %s\nYou already have the word. The relay does not charge for it, and neither will we." \
			% String(apex.get("name", "THE ENGINE"))
		told.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		told.add_theme_font_size_override("font_size", 11)
		told.add_theme_color_override("font_color", Palette.AMBER_DIM)
		_body.add_child(told)
		return

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
	# WORD FIRST, MONEY SECOND -- the hunt desk's own posture, applied to the bar
	# it shares. This charged first and generated afterwards, which was safe only
	# while the last rung could never come up empty: the arbitrage line was
	# returned unconditionally and undeduplicated, so a second purchase with
	# nothing running took the money and printed the identical sentence again.
	# §108 gives the ladder a rung that CAN run out, which turns that from a
	# latent hole into a certainty, so it is closed here rather than worked
	# around. REFUSAL IS FREE: nothing is spent above this line.
	var line := _rumor_text()
	if line == "":
		_reject()
		return
	if GameState.salvage < price or not GameState.spend_salvage(price):
		_reject()
		return
	_rumors_known.append(line)
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
	# Events, charted and deep alike. THROUGH event_place, never through
	# SystemDB: an event out past the chart has no entry to look up, and this
	# line printed a literal "?" for one until §108 put the name on the event.
	var unheard := []
	for e in GameState.market_events:
		var ev: Dictionary = e
		var line := "%s at %s — %s, %s left" % [
			Market.event_label(ev).capitalize(),
			Market.event_place(ev),
			CommodityDB.short_name(String(ev.get("good", ""))),
			_mmss(float(ev.get("remaining", 0.0)))]
		if not _rumors_known.has(line):
			unheard.append(line)
	if not unheard.is_empty():
		return String(unheard[0])

	# §108. A BARE COUNTER, and how long it has left. Outranks the standing
	# spread below because it expires: the spread will still be there tomorrow,
	# and a shelf that is filling will not be.
	var bare := Market.bare_shelf_report()
	if not bare.is_empty():
		var mins := int(round(float(bare["seconds"]) / 60.0))
		var bare_line := "%s is short on %s — %d of %d on the shelf, and about %s before they can fill an order." % [
			String(bare["name"]), CommodityDB.short_name(String(bare["good"])),
			int(bare["left"]), int(bare["cap"]),
			"a minute" if mins <= 1 else "%d minutes" % mins]
		if not _rumors_known.has(bare_line):
			return bare_line

	# No events, nothing bare: name the best standing spread anyone here knows
	# about -- one somebody can actually FILL, which is the part that was wrong.
	var route := Market.best_stocked_route()
	if not route.is_empty():
		var route_line := "%s moves %s to %s for about %d a unit right now — they are standing %d." % [
			CommodityDB.short_name(String(route["good"])), String(route["from"]),
			String(route["to"]), int(route["margin"]), int(route["units"])]
		if not _rumors_known.has(route_line):
			return route_line

	# Everything this desk knows, it has already told you. It says so rather
	# than selling the same sentence twice.
	return ""


# --- requisitions (§110) -----------------------------------------------------

func _build_requisitions() -> void:
	# THE BACK ROOM ORDERS; IT STILL DOES NOT RETAIL. Market.can_buy is untouched
	# by this whole section and SELL ONLY keeps passing -- a fence that sold
	# components off a shelf would reopen the loop §11 closed. This is a distinct
	# verb: you pay now, at a price above every sale in the game, and somebody
	# brings one back later.
	#
	# It answers the second playtest complaint from the demand side. The read
	# table fix (§110, commodity_db) makes every recipe plannable from one band;
	# this makes the EIGHTH unit of something you already understand a purchase
	# rather than another four hours of hoping.
	var key := _bay_key()
	var head := Label.new()
	head.text = "THE BACK ROOM SOURCES PARTS. PAID UP FRONT, DELIVERED HERE."
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.add_theme_font_size_override("font_size", 10)
	head.add_theme_color_override("font_color", Palette.AMBER_DIM)
	_body.add_child(head)

	# THE STANDING GATE, at the build AND at the action -- survey_mast's lesson,
	# and the same double enforcement the fence itself uses. REFUSAL IS FREE and
	# it states its own terms (§58).
	if not Market.fence_open(_port_def):
		var shut := Label.new()
		shut.text = "THEY WILL SELL YOU NOTHING AND SOURCE YOU NOTHING. MEND IT WITH %s FIRST." % \
			FactionDB.display_name(Market.owner_of(_port_def)).to_upper()
		shut.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		shut.add_theme_font_size_override("font_size", 12)
		shut.add_theme_color_override("font_color", Palette.THREAT)
		_body.add_child(shut)
		return

	var waiting := GameState.orders_at(key)
	if not waiting.is_empty():
		var wh := Label.new()
		wh.text = "ON ORDER HERE"
		wh.add_theme_font_size_override("font_size", 12)
		wh.add_theme_color_override("font_color", Palette.GOLD)
		_body.add_child(wh)
	for o_v in waiting:
		var o: Dictionary = o_v
		_body.add_child(_order_waiting_row(o))

	var offered := 0
	for gid_v in CommodityDB.ids():
		var gid := String(gid_v)
		if not CommodityDB.is_component(gid) or not GameState.has_read(gid):
			continue
		offered += 1
		_body.add_child(_order_row(gid))

	var note := Label.new()
	if offered == 0:
		# A DESK WITH NOTHING ON IT SAYS WHY. The gate is "bring me one you have
		# held", so an empty book is a sentence about reading, not a broken tab.
		note.text = "THEY SOURCE WHAT YOU HAVE HANDLED. READ A CRATE AT A LAB OR IN THE FIELD AND THEY WILL FIND YOU ANOTHER."
	else:
		note.text = "%d OF %d ORDERS OPEN. DELIVERY TAKES %d MINUTES OF FLYING, AND THEY CHARGE FOR THE TROUBLE." % [
			GameState.requisition_orders.size(), GameState.REQ_MAX_OPEN,
			int(round(GameState.REQ_DELAY / 60.0))]
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	note.add_theme_font_size_override("font_size", 10)
	note.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	_body.add_child(note)


func _order_waiting_row(o: Dictionary) -> Control:
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.06)
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
	name_line.text = CommodityDB.display(String(o.get("good", "")))
	name_line.add_theme_font_size_override("font_size", 13)
	name_line.add_theme_color_override("font_color", Palette.GOLD)
	left.add_child(name_line)

	var ready := GameState.order_ready(o)
	var sub := Label.new()
	sub.text = "READY" if ready else "IN TRANSIT — %s" % _mmss(GameState.order_seconds_left(o))
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color",
		Palette.GOLD if ready else Palette.AMBER_DIM)
	left.add_child(sub)

	var idx := GameState.requisition_orders.find(o)
	var b := Button.new()
	b.text = "COLLECT" if ready else "WAITING"
	b.disabled = not ready
	b.custom_minimum_size = Vector2(96, 34)
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(func() -> void: _collect_order(idx))
	box.add_child(b)
	return row


func _order_row(good: String) -> Control:
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
	var name_line := Label.new()
	name_line.text = "%s   ×%d" % [CommodityDB.display(good), GameState.cargo_count(good)]
	name_line.add_theme_font_size_override("font_size", 13)
	name_line.add_theme_color_override("font_color", CommodityDB.color_of(good))
	left.add_child(name_line)

	var price := Market.requisition_price(good)
	var sub := Label.new()
	# WHY IT COSTS WHAT IT COSTS, on the row. A part sourced for you is dearer
	# than one you found -- that is the entire deal, and hiding the comparison
	# would make the price look arbitrary instead of like a premium.
	sub.text = "SOURCED %s   ·   THEY BUY AT ABOUT %d" % [_comma(price),
		Market.sell_price(_port_def, _port.port_id, good, 1, _bay_key())]
	sub.add_theme_font_size_override("font_size", 10)
	sub.add_theme_color_override("font_color", Palette.AMBER_DIM)
	left.add_child(sub)

	var full := GameState.requisition_orders.size() >= GameState.REQ_MAX_OPEN
	var b := Button.new()
	b.text = "BOOK FULL" if full else "ORDER"
	b.disabled = full or GameState.salvage < price
	b.custom_minimum_size = Vector2(96, 34)
	b.add_theme_font_size_override("font_size", 11)
	b.pressed.connect(func() -> void: _order(good))
	box.add_child(b)
	return row


func _order(good: String) -> void:
	# PAID IN FULL AT THE DESK, so an order is a receipt and never a debt --
	# abandoning one costs exactly what was already spent and nothing more.
	# Gated here as well as in the UI: the button is the affordance, this is the
	# rule (_buy's own line).
	if not Market.fence_open(_port_def) or not GameState.can_order(good):
		_reject()
		return
	var price := Market.requisition_price(good)
	if GameState.salvage < price or not GameState.spend_salvage(price):
		_reject()
		return
	if not GameState.place_order(good, _bay_key()):
		# Could not be recorded after all: hand the money back rather than eat
		# it. Nothing may vanish -- identify()'s rule, applied to a wallet.
		GameState.add_salvage(price)
		_reject()
		return
	Sfx.play("equip", -7.0, 0.9)
	var main_o := get_tree().get_first_node_in_group("main")
	if main_o and main_o.hud:
		main_o.hud.set_value(GameState.salvage)
		main_o.hud.show_toast("ORDERED — %s, %d MIN" % [
			CommodityDB.short_name(good),
			int(round(GameState.REQ_DELAY / 60.0))], Palette.GOLD)
	_refresh()


func _collect_order(index: int) -> void:
	if not GameState.collect_order(index):
		# The one refusal worth naming: a full hold. The order KEEPS -- paid-for
		# cargo is never deleted by arriving with two units of space.
		var main_f := get_tree().get_first_node_in_group("main")
		if main_f and main_f.hud:
			main_f.hud.show_toast("NO ROOM FOR IT — THEY WILL HOLD IT", Palette.THREAT)
		_reject()
		return
	Sfx.play("equip", -6.0, 1.15)
	_refresh()


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
		# §111, BROKERAGE t2. THE STANDING WORD: a broker reads a consignment
		# against the weather at its destination. Fine print under the row it is
		# about, INFORMATION only -- the reward and the terms move by nothing.
		if GameState.skill_tier("brokerage") >= GameState.BROKER_WORD_TIER \
				and String(offer.get("kind", "")) == "deliver":
			var cdef := ContractDB.get_contract(String(offer.get("id", "")))
			var dest := String(cdef.get("dest", ""))
			var dgood := String(cdef.get("good", ""))
			var dev := Market.event_for(dest, dgood)
			if not dev.is_empty():
				var word := Label.new()
				word.text = "THE WORD: %s AT %s — %s RUNS OUT IN %s" % [
					Market.event_label(dev), Market.event_place(dev),
					CommodityDB.short_name(dgood),
					_mmss(float(dev.get("remaining", 0.0)))]
				word.add_theme_font_size_override("font_size", 9)
				word.add_theme_color_override("font_color", Market.event_color(dev))
				_body.add_child(word)

	# §111, BROKERAGE t3. ROUTE SENSE: the pair, NEVER the margin. The paid
	# rumour quotes the number; a broker's own read of the board names only
	# where things are moving -- deliberately the weaker product, the same
	# ordering the hunt desk keeps between the free mast and the paid word.
	if GameState.skill_tier("brokerage") >= GameState.BROKER_ROUTE_TIER:
		var route := Market.best_stocked_route()
		if not route.is_empty():
			var sense := Label.new()
			sense.text = "ROUTE SENSE — %s IS MOVING %s TO %s TONIGHT" % [
				CommodityDB.short_name(String(route["good"])),
				String(route["from"]), String(route["to"])]
			sense.add_theme_font_size_override("font_size", 10)
			sense.add_theme_color_override("font_color", Palette.TEAL)
			_body.add_child(sense)


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

	# §95. WHO POSTED IT, WHAT IT IS WORTH, AND WHAT WALKING AWAY COSTS — all
	# three before the button, because the third is the one a player can only
	# learn the expensive way otherwise. A commission's credit reward is
	# deliberately below the survey row beside it, so this line is also the
	# answer to "why would I take the worse-paying one".
	var flag := String(offer.get("faction", ""))
	if flag != "":
		var terms := Label.new()
		terms.text = "%s COMMISSION  ·  +%d STANDING  ·  ABANDON: −%d" % [
			FactionDB.display_name(flag), int(offer.get("standing", 0)),
			ContractDB.break_cost(String(offer["id"]))]
		terms.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		terms.custom_minimum_size = Vector2(180, 0)
		terms.add_theme_font_size_override("font_size", 10)
		terms.add_theme_color_override("font_color", FactionDB.tint_of(flag))
		left.add_child(terms)

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
	var trend := Market.trend(_port_def, _port.port_id, good, _bay_key())
	var ev := Market.event_for(_bay_key(), good)
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

	# THIS DESK FENCES THIS, and until now nothing on the screen said so. A fence
	# sale is the ONLY thing that moves SMUGGLING (port_panel._sell -> Market.
	# fences -> mark_smuggling), and which desks qualify was knowable only by
	# reading `fence_goods` in system_db. The trap it closes is specific: THE
	# GRINNING VOID sells contraband, calls itself the smuggler's den and has a
	# fence tab, but contraband is NOT in its fence_goods -- so selling it back
	# there completes, pays credits, and moves the ladder by nothing, with no
	# tell. A playtester finished 68 minutes at smuggling 0 while carrying goods
	# a fence two systems away would have taken.
	#
	# On the ROW rather than in the tab header, because it is a fact about this
	# good at this desk: a port can fence one of the two goods and not the other,
	# which is exactly the Void's case.
	if Market.fences(_port_def, good):
		var fence_tag := Label.new()
		fence_tag.text = "THIS DESK FENCES IT%s" % (
			" — SMUGGLING XP" if GameState.SMUGGLING_GOODS.has(good) else "")
		fence_tag.add_theme_font_size_override("font_size", 10)
		fence_tag.add_theme_color_override("font_color", Palette.TEAL)
		left.add_child(fence_tag)

	var buy_price := Market.buy_price(_port_def, _port.port_id, good, 1, _bay_key())
	var sell_price := Market.sell_price(_port_def, _port.port_id, good, 1, _bay_key())

	# A bulk break the player cannot see is a bulk break that does not exist.
	var bulk_units := int(_port_def.get("bulk_units", 0))
	if bulk_units > 0:
		var note := Label.new()
		note.text = "BULK %d+: buy %d / sell %d" % [bulk_units,
			Market.buy_price(_port_def, _port.port_id, good, bulk_units, _bay_key()),
			Market.sell_price(_port_def, _port.port_id, good, bulk_units, _bay_key())]
		note.add_theme_font_size_override("font_size", 10)
		note.add_theme_color_override("font_color", Palette.TEAL)
		left.add_child(note)

	var buys := VBoxContainer.new()
	buys.add_theme_constant_override("separation", 2)
	# v27. WHAT IS ON THE SHELF, on the row, because a buy button that silently
	# hands you three of the five you asked for is a bug the player has no way to
	# read as a rule. Three states, and each says which it is in words: a number,
	# OUT, or a counter that never stocked this at all.
	var on_shelf := Market.stock_left(_port_def, _bay_key(), good)
	var shelf_cap := Market.stock_cap(_port_def, good)
	if Market.can_buy(_port_def, good) and on_shelf > 0:
		buys.add_child(_price_label("BUY %d" % buy_price, Palette.AMBER_DIM))
		buys.add_child(_price_label("IN STOCK %d" % on_shelf,
			Palette.GOLD if on_shelf >= shelf_cap else Palette.AMBER_DIM))
		var buy_row := HBoxContainer.new()
		buy_row.add_theme_constant_override("separation", 3)
		buy_row.add_child(_mini_button("+1", func() -> void: _buy(good, 1)))
		# The second step matches the bulk threshold where there is one, so the
		# discount is reachable without counting single purchases.
		var step := maxi(5, int(_port_def.get("bulk_units", 0)))
		buy_row.add_child(_mini_button("+%d" % step, func() -> void: _buy(good, step)))
		buys.add_child(buy_row)
	elif Market.can_buy(_port_def, good) and shelf_cap > 0:
		# Emptied, or under a shortage. Either way it comes back, and saying so is
		# the difference between a counter that is out and a counter that is dead.
		buys.add_child(_price_label("OUT", Palette.THREAT))
		buys.add_child(_price_label("RESTOCKING", Palette.AMBER_DIM))
	elif Market.can_buy(_port_def, good):
		# bias >= 1.25. This desk is a BUYER of the thing -- it is why the sell
		# price here is the best on the chart -- and it has never had a shelf.
		buys.add_child(_price_label("BUYS ONLY", Palette.TEAL))
		buys.add_child(_price_label("NOT STOCKED HERE", Palette.AMBER_DIM))
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

	var cap := _reactor_cap()
	var next_price := GameState.next_reactor_price(cap)
	if next_price < 0:
		var tag := Label.new()
		# TWO REASONS, AND THE PLAYER IS TOLD WHICH. "MAX" on a counter that
		# simply does not stock the next reactor would be a lie about the ship
		# rather than a fact about the shop — and it would hide the one thing
		# worth knowing, which is that the rack exists somewhere else. 58's rule:
		# say what to do about it.
		var finished: bool = GameState.reactor_tier >= ModuleDB.REACTOR_TIERS.size() - 1
		tag.text = "MAX" if finished else "NOT SOLD HERE"
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


func _berth_row(id: String) -> Control:
	# One hull berth: what it opens, what it costs in mass, and the price. The
	# mass is stated ON THE BUTTON'S OWN ROW rather than in a tooltip, because
	# it is permanent and cannot be sold back -- 58's rule, applied to a
	# purchase instead of to a refusal.
	var berth: Dictionary = ModuleDB.BERTHS.get(id, {})
	if berth.is_empty():
		return Control.new()
	var row := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(Palette.GOLD.r, Palette.GOLD.g, Palette.GOLD.b, 0.05)
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
	name_line.text = "%s — %s" % [String(berth["name"]),
		String(ModuleDB.SLOT_NAMES.get(int(berth["slot"]), "?"))]
	name_line.add_theme_font_size_override("font_size", 13)
	name_line.add_theme_color_override("font_color", Palette.GOLD)
	left.add_child(name_line)

	var terms := Label.new()
	terms.text = "+%d POWER, −%.2f TOP SPEED, PERMANENT" % [
		int(berth["power"]), float(berth["speed_cost"])]
	terms.add_theme_font_size_override("font_size", 10)
	terms.add_theme_color_override("font_color", Palette.AMBER_DIM)
	left.add_child(terms)

	var desc := Label.new()
	desc.text = String(berth.get("desc", ""))
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	desc.custom_minimum_size = Vector2(190, 0)
	desc.add_theme_font_size_override("font_size", 10)
	desc.add_theme_color_override("font_color", Color(0.6, 0.6, 0.66))
	left.add_child(desc)

	if GameState.berths.has(id):
		var fitted := Label.new()
		fitted.text = "WELDED ON"
		fitted.add_theme_font_size_override("font_size", 11)
		fitted.add_theme_color_override("font_color", Palette.AMBER_DIM)
		box.add_child(fitted)
		return row
	var b := Button.new()
	b.text = "CUT IT IN %s" % _comma(GameState.berth_price(id))
	b.custom_minimum_size = Vector2(120, 30)
	b.add_theme_font_size_override("font_size", 11)
	b.disabled = not GameState.can_buy_berth(id)
	b.pressed.connect(func() -> void: _buy_berth(id))
	box.add_child(b)
	return row


func _buy_berth(id: String) -> void:
	if not GameState.buy_berth(id):
		return
	Sfx.play("equip", -6.0, 0.9)
	_refresh()


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
