class_name Telemetry
extends Object
# Local play recorder. Developer-facing, opt-in, and never read by the game.
#
# WHY THIS EXISTS. The Commission's thresholds -- 100 chart units, 80 hulls, 20
# posts, depth 1100 -- were derived from harness output, not from play, and
# HORIZON-3 §2 says so in as many words: "a number to fix later. The
# phone-performance and playtest pass deferred from Horizon 1 has still never
# run." A harness measures what the game can do; only a session measures what a
# person actually does in one sitting. This is how the second number gets
# collected without guessing.
#
# WHAT IT IS NOT. It never leaves the machine, there is no network code here and
# there will not be, and NOTHING IN THE GAME MAY READ IT. The moment a balance
# rule consults telemetry, the game is tuning itself against the player rather
# than the designer tuning it between builds -- and every session becomes
# unreproducible. It writes; it does not answer questions.
#
# One JSON object per line, appended. A line per session rather than a stream of
# events: the questions worth asking of a playtest ("did anyone reach THE QUIET
# in one sitting?", "how many hulls in an hour?") are all session-shaped, and an
# event log would be a visited-cells array by another name -- unbounded growth
# proportional to how long someone plays.

const DIR := "user://telemetry"
const PATH := "user://telemetry/sessions.jsonl"
# A session shorter than this is a bounce -- someone opening the build to check
# it still runs -- and averaging those in would drag every pacing number down.
const MIN_SESSION_SECONDS := 60.0
# Records past this are dropped from the front. A playtest is a handful of
# sessions; an unbounded file on a player's device is not something to ship.
const MAX_RECORDS := 500


static func enabled() -> bool:
	return bool(GameState.setting("telemetry"))


static func record_session(seconds: float) -> void:
	# Called once, at quit, from the same notification that saves the game.
	if not enabled() or seconds < MIN_SESSION_SECONDS:
		return
	var led: Dictionary = GameState.ledger
	var row := {
		"minutes": snappedf(seconds / 60.0, 0.1),
		# The four keys the Commission gates on, so a threshold can be checked
		# against what a session actually produced rather than against what the
		# harness can reach with the ledger written by hand.
		"chart_data_sold": int(led.get("chart_data_sold", 0)),
		"hulks_cracked": int(led.get("hulks_cracked", 0)),
		"posts_cleared": int(led.get("posts_cleared", 0)),
		"deepest_depth": int(led.get("deepest_depth", 0)),
		# Context for reading the four above: a run that bought the whole catalog
		# and one that bought nothing produce very different hull counts per hour.
		"salvage": GameState.salvage,
		"modules_owned": GameState.owned.size(),
		"commission_claimed": GameState.commission_claimed,
		"commissioned": GameState.commissioned,
		"apex_kills": GameState.apex_killed.size(),
	}
	_append(JSON.stringify(row))


static func _append(line: String) -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))
	var rows := read_all()
	rows.append(line)
	while rows.size() > MAX_RECORDS:
		rows.remove_at(0)
	# Rewritten rather than appended in place, because the cap has to apply. At
	# 500 short lines this is a few tens of kilobytes once per session, which is
	# not worth the complexity of a ring buffer on disk.
	var f := FileAccess.open(PATH, FileAccess.WRITE)
	if f == null:
		return
	for r in rows:
		f.store_line(String(r))
	f.close()


static func read_all() -> Array:
	var out: Array = []
	if not FileAccess.file_exists(PATH):
		return out
	var f := FileAccess.open(PATH, FileAccess.READ)
	if f == null:
		return out
	while not f.eof_reached():
		var line := f.get_line().strip_edges()
		if line != "":
			out.append(line)
	f.close()
	return out


static func summary() -> Dictionary:
	# What a developer actually wants after a playtest weekend: the medians, and
	# how many sessions got far enough to see the finale at all. Medians rather
	# than means because one six-hour session should not move the number that
	# decides what a normal sitting looks like.
	var rows: Array = []
	for line in read_all():
		var parsed = JSON.parse_string(String(line))
		if parsed is Dictionary:
			rows.append(parsed)
	if rows.is_empty():
		return {"sessions": 0}
	var out := {"sessions": rows.size()}
	for key in ["minutes", "chart_data_sold", "hulks_cracked", "posts_cleared", "deepest_depth"]:
		var vals: Array = []
		for r in rows:
			vals.append(float((r as Dictionary).get(key, 0)))
		vals.sort()
		out["median_" + key] = vals[vals.size() / 2]
		out["max_" + key] = vals[vals.size() - 1]
	var finished := 0
	for r in rows:
		if bool((r as Dictionary).get("commissioned", false)):
			finished += 1
	out["commissioned_sessions"] = finished
	return out
