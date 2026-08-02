class_name Contracts
extends Node
# Tracks the two active survey contracts, their progress, and their rewards.
# Progress is fed by main.gd (kills, salvage, breaches) and persisted through
# GameState so a session picks up where it left off.
#
# Phase 2: contracts are ACCEPTED from a port's board, not handed out. The only
# survivor of auto-assignment is the starter pair, which fills the two slots on
# a brand-new run so the tracker is not empty during the tutorial — before the
# player has ever seen a port, there is nowhere to accept anything from.

signal changed
signal completed(title: String, reward: int)

var active: Array = []       # [{id, progress}]
var _system := ""


func _ready() -> void:
	_restore()


func on_system_changed(id: String) -> void:
	# Contracts survive travel now. Dropping the ones not offered in the new
	# system would silently cancel work the player deliberately took on, and a
	# delivery contract is *supposed* to send you somewhere else.
	_system = id
	_persist()
	changed.emit()


# --- the board --------------------------------------------------------------

func board(port_id: String) -> Array:
	# [{id, title, reward, desc, accepted, kind}] for the port panel.
	var out := []
	for id_v in ContractDB.board_for(port_id, _system, GameState.played_seconds):
		var id := String(id_v)
		var def := ContractDB.get_contract(id)
		out.append({
			"id": id,
			"title": String(def.get("title", id)),
			"reward": int(def.get("reward", 0)),
			"desc": ContractDB.describe(id),
			"kind": String(def.get("kind", "")),
			"accepted": has_active(id),
		})
	return out


func has_active(id: String) -> bool:
	for entry in active:
		if String(entry["id"]) == id:
			return true
	return false


func slots_free() -> int:
	return maxi(0, ContractDB.ACTIVE_SLOTS - active.size())


func accept(id: String) -> bool:
	if not ContractDB.exists(id) or has_active(id) or slots_free() <= 0:
		return false
	active.append({"id": id, "progress": 0})
	_persist()
	changed.emit()
	return true


func drop(id: String) -> bool:
	# Free, and deliberately so: a contract you cannot abandon is a contract that
	# can strand you, and nothing here is worth a soft-lock.
	for entry in active.duplicate():
		if String(entry["id"]) == id:
			active.erase(entry)
			_persist()
			changed.emit()
			return true
	return false


func on_kill(kind: String) -> void:
	# kind is "swarm" or "sentry"
	_advance("kill_" + kind, 1)


func on_salvage(amount: int) -> void:
	_advance("earn_salvage", amount)


func on_breach() -> void:
	_advance("breach", 1)


func on_docked(port_id: String) -> void:
	# Delivery contracts settle on arrival: dock at the right port holding the
	# goods and the cargo is handed over automatically.
	var dirty := false
	for entry in active.duplicate():
		var def := ContractDB.get_contract(String(entry["id"]))
		if String(def.get("kind", "")) != "deliver":
			continue
		if String(def.get("dest", "")) != port_id:
			continue
		var good := String(def.get("good", ""))
		var need := int(def.get("target", 0))
		if GameState.cargo_count(good) < need:
			continue
		GameState.unload_cargo(good, need)
		entry["progress"] = need
		dirty = true
		_complete(entry)
	if dirty:
		_persist()
		changed.emit()


func _advance(kind: String, amount: int) -> void:
	var dirty := false
	for entry in active.duplicate():
		var def := ContractDB.get_contract(String(entry["id"]))
		if String(def.get("kind", "")) != kind:
			continue
		entry["progress"] = int(entry["progress"]) + amount
		dirty = true
		if int(entry["progress"]) >= int(def["target"]):
			_complete(entry)
	if dirty:
		_persist()
		changed.emit()


func _complete(entry: Dictionary) -> void:
	var def := ContractDB.get_contract(String(entry["id"]))
	var reward := int(def.get("reward", 0))
	active.erase(entry)

	var main := get_tree().get_first_node_in_group("main")
	if main and main.has_method("add_salvage"):
		main.add_salvage(reward)
	Sfx.play_streak("pickup", -4.0)
	completed.emit(String(def.get("title", "CONTRACT")), reward)

	var hud := get_tree().get_first_node_in_group("hud")
	if hud and hud.has_method("show_toast"):
		hud.show_toast("CONTRACT COMPLETE  +%d" % reward, Palette.GOLD)
		hud.prompt("CONTRACT SLOT FREE — PICK UP ANOTHER AT ANY PORT")
	# Deliberately no refill. A finished contract frees a slot; what goes in it
	# is the player's call at the next board.


func _persist() -> void:
	GameState.set_contract_state({"system": _system, "active": active, "seeded": true})


func _restore() -> void:
	var state: Dictionary = GameState.contract_state
	_system = str(state.get("system", GameState.current_system))
	active = []
	for entry in state.get("active", []):
		var id := str((entry as Dictionary).get("id", ""))
		if ContractDB.exists(id):
			active.append({"id": id, "progress": int((entry as Dictionary).get("progress", 0))})

	# The one remaining auto-assignment: a run that has never held a contract and
	# has never touched a port gets the starter pair, so the HUD tracker has
	# something in it while the tutorial is still teaching the basics. `seeded`
	# is what stops this coming back after the player deliberately drops both.
	if not bool(state.get("seeded", false)):
		for id_v in ContractDB.STARTER_PAIR:
			var id := String(id_v)
			if ContractDB.exists(id) and active.size() < ContractDB.ACTIVE_SLOTS:
				active.append({"id": id, "progress": 0})
		_persist()


func rows() -> Array:
	# [{title, progress, target}] for the HUD tracker.
	var out := []
	for entry in active:
		var def := ContractDB.get_contract(String(entry["id"]))
		var progress := int(entry["progress"])
		# A delivery's real progress is what is in the hold right now, not a
		# counter — otherwise the tracker lies while you are out buying.
		if String(def.get("kind", "")) == "deliver":
			progress = GameState.cargo_count(String(def.get("good", "")))
		out.append({
			"title": String(def.get("title", "")),
			"progress": mini(progress, int(def.get("target", 1))),
			"target": int(def.get("target", 1)),
		})
	return out


func debug_state() -> String:
	var parts := []
	for r in rows():
		parts.append("%s %d/%d" % [r["title"], r["progress"], r["target"]])
	return ", ".join(parts)
