class_name Market
extends Object
# The price engine. Every price shown in the UI and every price charged goes
# through here, so the number on the row is always the number you pay.
#
#   price = base × port_bias × drift × pressure × event
#
# Deliberately NOT an agent simulation. Prices react to the one actor who can
# perceive them — the player — plus a slow clock and occasional events. A full
# NPC economy would be depth nobody can see, the same trap the fitting contract
# warns about (docs/STRATEGY.md §9).

const SPREAD := 0.10          # station sells at +spread, buys at -spread
const FREEPORT_SPREAD := 0.06
const DRIFT_AMPLITUDE := 0.12
const PRESSURE_CAP := 0.25    # max ±25% player-driven swing
const PRESSURE_PER_UNIT := 0.012
const PRESSURE_RECOVERY := 0.10   # fraction of the way back to neutral, per minute

const EVENT_MAX_ACTIVE := 2
const EVENT_ROLL_INTERVAL := 90.0
const EVENT_CHANCE := 0.25

const EVENT_KINDS := {
	"shortage": {"label": "SHORTAGE", "min_mult": 1.8, "max_mult": 2.2,
		"min_dur": 240.0, "max_dur": 360.0, "color": Palette.THREAT},
	"glut": {"label": "GLUT", "min_mult": 0.5, "max_mult": 0.62,
		"min_dur": 240.0, "max_dur": 360.0, "color": Palette.TEAL},
}


static func owner_of(port_def: Dictionary) -> String:
	# v18 stage 5. Which faction runs this desk. "" is legitimate — the Last
	# Watch answers to nobody, and the Procession's convoy def may choose the
	# same — and every gate below treats unowned as ungated, so a missing owner
	# fails OPEN rather than locking a counter by accident.
	return String(port_def.get("owner", ""))


static func fence_open(port_def: Dictionary) -> bool:
	# THE ONE STANDING GATE IN STAGE 5, and deliberately the only one. The
	# fence is the faction-flavoured service — the Cantina's back room, the
	# Void, the Long Haven — so it is the counter that plausibly knows your
	# name. Market, outfitter and repair stay open at every standing: a hostile
	# port that refused repairs would be a death trap, and that is a design
	# decision nobody has made.
	#
	# GATES, NEVER PRICES (HORIZON-4 §9). This function returns a bool and no
	# price function anywhere consults standing — which is what keeps the
	# sellback/outfit guard rail (max sellback < min outfit_mult, swept
	# pairwise by STATIONTEST) safe BY CONSTRUCTION rather than by re-proof at
	# every band. NO PRICE MOVES WITH STANDING asserts it stays that way.
	var owner := owner_of(port_def)
	if owner == "" or not FactionDB.is_faction(owner):
		return true
	return GameState.faction_band(FactionDB.SURVEYOR, owner) != FactionDB.Band.HOSTILE


static func _key(port_id: String, good: String) -> String:
	return port_id + "|" + good


# --- components -------------------------------------------------------------

static func port_bias(port_def: Dictionary, good: String) -> float:
	var biases: Dictionary = port_def.get("bias", {})
	return float(biases.get(good, 1.0))


static func drift(good: String, port_id: String) -> float:
	# A slow oscillation keyed to played time. Uses the persisted play clock,
	# never wall-clock, so a save reloads onto the same curve.
	var minutes := GameState.played_seconds / 60.0
	var seed := float(good.hash() % 997) * 0.0063 + float(port_id.hash() % 599) * 0.0104
	var period := 9.0 + float((good.hash() + port_id.hash()) % 5)   # 9-13 minutes
	return 1.0 + DRIFT_AMPLITUDE * sin(TAU * minutes / period + seed)


static func pressure(port_id: String, good: String) -> float:
	var p := float(GameState.market_pressure.get(_key(port_id, good), 0.0))
	return 1.0 + clampf(p, -PRESSURE_CAP, PRESSURE_CAP)


static func event_multiplier(port_id: String, good: String) -> float:
	var mult := 1.0
	for e in GameState.market_events:
		var ev: Dictionary = e
		if String(ev.get("port", "")) == port_id and String(ev.get("good", "")) == good:
			mult *= float(ev.get("mult", 1.0))
	return mult


static func event_for(port_id: String, good: String) -> Dictionary:
	for e in GameState.market_events:
		var ev: Dictionary = e
		if String(ev.get("port", "")) == port_id and String(ev.get("good", "")) == good:
			return ev
	return {}


# --- prices -----------------------------------------------------------------

static func unit_price(port_def: Dictionary, port_id: String, good: String) -> float:
	return float(CommodityDB.base_price(good)) \
		* port_bias(port_def, good) \
		* drift(good, port_id) \
		* pressure(port_id, good) \
		* event_multiplier(port_id, good)


static func _spread_for(port_def: Dictionary) -> float:
	return FREEPORT_SPREAD if bool(port_def.get("freeport", false)) else SPREAD


static func buy_price(port_def: Dictionary, port_id: String, good: String, units := 1) -> int:
	# What the player pays the station. `units` matters only at a port with a
	# bulk break — an industrial depot would rather move ten of something than
	# one, and says so in the price.
	var p := unit_price(port_def, port_id, good) * (1.0 + _spread_for(port_def))
	p *= 1.0 - _bulk_bonus(port_def, units)
	return maxi(1, int(round(p)))


static func sell_price(port_def: Dictionary, port_id: String, good: String, units := 1) -> int:
	# What the station pays the player.
	var p := unit_price(port_def, port_id, good) * (1.0 - _spread_for(port_def))
	p *= 1.0 + _bulk_bonus(port_def, units)
	p *= fence_bonus(port_def, good)
	return maxi(1, int(round(p)))


static func _bulk_bonus(port_def: Dictionary, units: int) -> float:
	var threshold := int(port_def.get("bulk_units", 0))
	if threshold <= 0 or units < threshold:
		return 0.0
	return float(port_def.get("bulk_bonus", 0.0))


static func fence_bonus(port_def: Dictionary, good: String) -> float:
	# A fence pays over the odds for the things nobody else will take clean.
	# Applied to the SELL side only: they are buying, not supplying.
	var goods: Array = port_def.get("fence_goods", [])
	if goods.is_empty() or not goods.has(good):
		return 1.0
	return float(port_def.get("fence_mult", 1.0))


static func fences(port_def: Dictionary, good: String) -> bool:
	# SMUGGLING t3 buys ACCESS, not a better price: out past the chart, a fence
	# who knows you will take anything you are carrying. Deliberately who-deals-
	# with-you rather than what-they-pay — a premium would move the best legal
	# route and drag PACINGTEST's band with it, which is why no tier touches a
	# number on a price.
	if GameState.smuggling >= GameState.SMUGGLING_ACCESS_TIER \
			and DeepPortDB.is_deep_port(String(port_def.get("id", ""))) \
			and (port_def.get("services", []) as Array).has("fence"):
		return true
	return (port_def.get("fence_goods", []) as Array).has(good)


static func can_buy(port_def: Dictionary, good: String) -> bool:
	# A fence buys; it does not retail the same goods back to you.
	#
	# This is load-bearing, not flavour. The premium (1.25x) is larger than the
	# spread (6% at a freeport), so with both sides open the sell price at a
	# fencing port exceeded its own buy price — Stolen Goods quoted BUY 169 /
	# SELL 188 at the Grinning Void, which is an infinite money loop you could
	# run by tapping two buttons. Closing the buy side removes it at the source
	# rather than by capping the premium, which would have made the fence
	# pointless. Asserted for every port and good by PYXIS_STATIONTEST.
	# Unidentified salvage and components are never retailed anywhere. Buy salvage
	# cheap, read it, sell the component dear is an infinite loop with no combat
	# and no risk in it — the same shape as the BUY 169 / SELL 188 fence loop
	# above, and closed the same way: at the source, on the buy side.
	if CommodityDB.no_retail(good):
		return false
	return not fences(port_def, good)


static func trend(port_def: Dictionary, port_id: String, good: String) -> int:
	# -1 / 0 / +1 versus the good's baseline, for the arrow on the row. This is
	# how a deal stays legible without the player doing arithmetic.
	var ratio := unit_price(port_def, port_id, good) / maxf(float(CommodityDB.base_price(good)), 1.0)
	if ratio >= 1.12:
		return 1
	if ratio <= 0.9:
		return -1
	return 0


# --- player pressure --------------------------------------------------------

static func apply_trade_pressure(port_id: String, good: String, units: int, selling: bool) -> void:
	# Selling into a port depresses its price; buying it out raises it.
	var k := _key(port_id, good)
	var current := float(GameState.market_pressure.get(k, 0.0))
	var delta := PRESSURE_PER_UNIT * float(units) * (-1.0 if selling else 1.0)
	GameState.market_pressure[k] = clampf(current + delta, -PRESSURE_CAP, PRESSURE_CAP)


static func recover_pressure(delta_seconds: float) -> void:
	# Markets drift back toward neutral, so flooding one is a temporary dent
	# rather than a permanent scar.
	if GameState.market_pressure.is_empty():
		return
	var factor := PRESSURE_RECOVERY * (delta_seconds / 60.0)
	var done := []
	for k in GameState.market_pressure:
		var v: float = GameState.market_pressure[k]
		v = move_toward(v, 0.0, absf(v) * factor)
		if absf(v) < 0.001:
			done.append(k)
		else:
			GameState.market_pressure[k] = v
	for k in done:
		GameState.market_pressure.erase(k)


# --- events -----------------------------------------------------------------

static func tick_events(delta_seconds: float) -> Array:
	# Returns events that expired this tick, so the caller can announce them.
	var expired := []
	var kept := []
	for e in GameState.market_events:
		var ev: Dictionary = e
		ev["remaining"] = float(ev.get("remaining", 0.0)) - delta_seconds
		if float(ev["remaining"]) <= 0.0:
			expired.append(ev)
		else:
			kept.append(ev)
	GameState.market_events = kept
	return expired


static func try_spawn_event(port_ids: Array) -> Dictionary:
	# Returns the new event, or {} if none was created.
	if GameState.market_events.size() >= EVENT_MAX_ACTIVE:
		return {}
	if randf() > EVENT_CHANCE or port_ids.is_empty():
		return {}

	var kind := "shortage" if randf() < 0.55 else "glut"
	var spec: Dictionary = EVENT_KINDS[kind]
	var port := String(port_ids[randi() % port_ids.size()])
	var goods := CommodityDB.ids()
	var good := String(goods[randi() % goods.size()])

	for e in GameState.market_events:
		if String((e as Dictionary).get("port", "")) == port and String((e as Dictionary).get("good", "")) == good:
			return {}

	var ev := {
		"kind": kind,
		"port": port,
		"good": good,
		"mult": randf_range(float(spec["min_mult"]), float(spec["max_mult"])),
		"remaining": randf_range(float(spec["min_dur"]), float(spec["max_dur"])),
	}
	GameState.market_events.append(ev)
	return ev


static func event_label(ev: Dictionary) -> String:
	if ev.is_empty():
		return ""
	return String(EVENT_KINDS.get(String(ev.get("kind", "")), {}).get("label", ""))


static func event_color(ev: Dictionary) -> Color:
	if ev.is_empty():
		return Palette.AMBER_DIM
	return EVENT_KINDS.get(String(ev.get("kind", "")), {}).get("color", Palette.AMBER)
