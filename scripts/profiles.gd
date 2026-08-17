class_name Profiles
extends RefCounted
# The pilot registry: which saves exist, what they are called, and which one is
# live. It owns `user://profiles.json` and the `user://profiles/<id>/` folders,
# and it owns NOTHING ELSE -- GameState is still the only thing that writes a
# save file, and this never opens one except to peek at a legacy file's ship name
# during the one-time migration.
#
# DELIBERATELY A LEAF. It references no other class in this project: not
# GameState, not Main, not SystemDB. §39 records what a new compile-time
# dependency from a widely-preloaded script can do -- one closed a class-list
# cycle and produced forty parse errors in files nobody had touched, plus a boot
# that hung rather than failed. A registry that only speaks FileAccess, DirAccess
# and JSON cannot participate in that.
#
# Every path is a static var rather than a const so a harness can point the whole
# layer at a scratch directory. That is the same seam GameState.save_path has
# always been, for the same reason: a test that writes the player's files is not
# a test.

const SCHEMA := 1
# Five, which fits the title screen's fixed 240px button column without a
# ScrollContainer, and is enough for parallel builds without the page becoming a
# list to manage rather than a slot to pick.
const MAX_PROFILES := 5
const NAME_MAX := 18

static var registry_path := "user://profiles.json"
static var base_dir := "user://profiles"
# The pre-profiles save. Read once by the migration and never again; it is not
# where anything is written after that.
static var legacy_path := "user://save.json"


static func save_path_for(id: String) -> String:
	return "%s/%s/save.json" % [base_dir, id]


# --- the registry -----------------------------------------------------------

static func load_registry() -> Dictionary:
	# THE FILE IS INPUT, NOT TRUTH. Every field is re-derived or dropped rather
	# than trusted: an unreadable file, an unknown schema, a duplicate id, an id
	# whose folder is gone, a malformed row -- each is discarded and the rest of
	# the registry survives. The loader posture GameState._load_beacons
	# established, applied to a file a player could hand-edit.
	var out := {"schema": SCHEMA, "active": "", "profiles": []}
	if not FileAccess.file_exists(registry_path):
		return out
	var f := FileAccess.open(registry_path, FileAccess.READ)
	if f == null:
		return out
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Pyxis: profiles.json unreadable, starting with no pilots")
		return out
	var data: Dictionary = parsed
	if int(data.get("schema", 0)) > SCHEMA:
		# Written by a newer build. Refuse it whole rather than half-reading it,
		# for the same reason load_game refuses a newer save.
		push_warning("Pyxis: profiles.json is schema %d, this build reads %d" % [
			int(data.get("schema", 0)), SCHEMA])
		return out
	var seen := {}
	for row_v in data.get("profiles", []):
		if typeof(row_v) != TYPE_DICTIONARY:
			continue
		var row: Dictionary = row_v
		var id := String(row.get("id", ""))
		if id == "" or seen.has(id):
			continue
		if not DirAccess.dir_exists_absolute("%s/%s" % [base_dir, id]):
			continue
		seen[id] = true
		out["profiles"].append({
			"id": id,
			"name": _clean_name(String(row.get("name", ""))),
			"created": float(row.get("created", 0.0)),
			"last_played": float(row.get("last_played", 0.0)),
			"summary": row.get("summary", {}) if typeof(row.get("summary", {})) == TYPE_DICTIONARY else {},
		})
		if out["profiles"].size() >= MAX_PROFILES:
			break
	# The active id has to name a pilot that survived the pass above, or the
	# title screen offers CONTINUE into a folder that is not there.
	var active := String(data.get("active", ""))
	out["active"] = active if seen.has(active) else ""
	if out["active"] == "" and not (out["profiles"] as Array).is_empty():
		out["active"] = String((out["profiles"][0] as Dictionary)["id"])
	return out


static func save_registry(reg: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(base_dir)
	var f := FileAccess.open(registry_path, FileAccess.WRITE)
	if f == null:
		push_warning("Pyxis: could not write profiles.json")
		return
	f.store_string(JSON.stringify({
		"schema": SCHEMA,
		"active": String(reg.get("active", "")),
		"profiles": reg.get("profiles", []),
	}, "\t"))
	f.close()


static func list_profiles() -> Array:
	return load_registry().get("profiles", [])


static func active_id() -> String:
	return String(load_registry().get("active", ""))


static func set_active(id: String) -> void:
	var reg := load_registry()
	for row_v in reg.get("profiles", []):
		if String((row_v as Dictionary)["id"]) == id:
			reg["active"] = id
			save_registry(reg)
			return


# --- creating and removing --------------------------------------------------

static func create(name: String, now: float) -> String:
	# Returns the new id, or "" when the rack is full. The id is opaque and is
	# never derived from the name, so renaming stays free and two pilots may
	# share a name without sharing a folder.
	var reg := load_registry()
	var rows: Array = reg.get("profiles", [])
	if rows.size() >= MAX_PROFILES:
		return ""
	var id := _new_id(reg)
	DirAccess.make_dir_recursive_absolute("%s/%s" % [base_dir, id])
	rows.append({
		"id": id,
		"name": _clean_name(name),
		"created": now,
		"last_played": now,
		"summary": {},
	})
	reg["profiles"] = rows
	reg["active"] = id
	save_registry(reg)
	return id


static func delete(id: String) -> void:
	var reg := load_registry()
	var kept: Array = []
	for row_v in reg.get("profiles", []):
		if String((row_v as Dictionary)["id"]) != id:
			kept.append(row_v)
	reg["profiles"] = kept
	if String(reg.get("active", "")) == id:
		reg["active"] = "" if kept.is_empty() else String((kept[0] as Dictionary)["id"])
	save_registry(reg)
	# The folder goes after the registry, never before: a crash between the two
	# leaves an orphan folder, which load_registry ignores, rather than a row
	# pointing at nothing, which it would have to clean up.
	var dir := "%s/%s" % [base_dir, id]
	var d := DirAccess.open(dir)
	if d != null:
		for file in d.get_files():
			DirAccess.remove_absolute("%s/%s" % [dir, file])
		DirAccess.remove_absolute(dir)


static func touch(id: String, now: float, summary: Dictionary) -> void:
	# Called on save, so the title screen's rows are the last thing each pilot
	# actually did rather than what they did when the app opened.
	var reg := load_registry()
	var hit := false
	for row_v in reg.get("profiles", []):
		var row: Dictionary = row_v
		if String(row["id"]) == id:
			row["last_played"] = now
			row["summary"] = summary
			hit = true
	if hit:
		save_registry(reg)


static func rename(id: String, name: String) -> void:
	var reg := load_registry()
	for row_v in reg.get("profiles", []):
		var row: Dictionary = row_v
		if String(row["id"]) == id:
			row["name"] = _clean_name(name)
	save_registry(reg)


# --- the one-time migration -------------------------------------------------

static func needs_migration() -> bool:
	return not FileAccess.file_exists(registry_path)


static func migrate_legacy(now: float) -> String:
	# ONCE, AND KEYED ON THE REGISTRY'S ABSENCE. A player upgrading into this
	# build has one save at user://save.json and no registry; they get one pilot
	# holding exactly that run, named from the ship they were flying. Somebody
	# who has never played gets an empty registry and no pilots at all, which is
	# what makes NEW PILOT the only door on a fresh install.
	#
	# The save is MOVED, not copied: two files that both look like the live save
	# is the state where a later bug picks the wrong one. Returns the new id, or
	# "" when there was nothing to migrate.
	if not needs_migration():
		return ""
	if not FileAccess.file_exists(legacy_path):
		save_registry({"schema": SCHEMA, "active": "", "profiles": []})
		return ""
	var id := create(_legacy_ship_name(), now)
	if id == "":
		return ""
	var moved := DirAccess.rename_absolute(legacy_path, save_path_for(id))
	if moved != OK:
		# The registry row is left in place deliberately: the pilot exists, the
		# folder exists, and the save simply did not move. That is recoverable by
		# hand; a registry rolled back under a save that DID move is not.
		push_warning("Pyxis: could not move the existing save into a pilot folder (%d)" % moved)
	return id


static func _legacy_ship_name() -> String:
	# A peek, not a load. The migration wants one string out of the old file and
	# has no business parsing the rest of it -- GameState does that, afterwards,
	# through its own loader.
	if not FileAccess.file_exists(legacy_path):
		return "SURVEYOR"
	var f := FileAccess.open(legacy_path, FileAccess.READ)
	if f == null:
		return "SURVEYOR"
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return "SURVEYOR"
	return _clean_name(String((parsed as Dictionary).get("ship_name", "")))


# --- helpers ----------------------------------------------------------------

static func _clean_name(raw: String) -> String:
	var out := raw.strip_edges()
	if out.length() > NAME_MAX:
		out = out.substr(0, NAME_MAX)
	return out if out != "" else "SURVEYOR"


static func _new_id(reg: Dictionary) -> String:
	var taken := {}
	for row_v in reg.get("profiles", []):
		taken[String((row_v as Dictionary)["id"])] = true
	var rng := RandomNumberGenerator.new()
	rng.randomize()
	for _attempt in range(64):
		var id := "p_%08x" % rng.randi()
		if not taken.has(id) and not DirAccess.dir_exists_absolute("%s/%s" % [base_dir, id]):
			return id
	# Sixty-four collisions on a 32-bit space with at most five rows is not a
	# thing that happens; falling back to a counter rather than looping forever
	# is what keeps that true statement from being load-bearing.
	var n := 0
	while taken.has("p_seq%04d" % n):
		n += 1
	return "p_seq%04d" % n
