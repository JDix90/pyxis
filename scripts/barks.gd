class_name Barks
extends Object
# Diegetic ship-AI lines used as onboarding. Each fires once ever (persisted in
# the save), so a returning player is never re-taught. There is no tutorial
# mode and no modal — the ship just tells you things.

const LINES := {
	"first_launch": "SURVEY VESSEL ONLINE — TAP A BEARING TO MOVE",
	"first_hostiles": "CONTACTS INBOUND — TAP A CONTACT TO ENGAGE",
	"first_kill": "SALVAGE ADRIFT — FLY THROUGH IT TO COLLECT",
	"refit_available": "SURPLUS SALVAGE — REFIT CONSOLE ONLINE",
	"first_breach_range": "DERELICT IN RANGE — HOLD ON THE BREACH POINT",
	"chart_unlocked": "NEW BEARING CHARTED — OPEN THE CHART",
	"first_warp": "TRANSIT COMPLETE — UNFAMILIAR SPACE",
	"apex_out_of_range": "SHOTS BREAKING ON THE SURVEY FIELD — CLOSE IN",
	"first_dock_range": "DOCKING CLAMPS AVAILABLE — TAP THE PORT",
	"first_docked": "CLAMPED ON. NOTHING REACHES YOU HERE",
	"first_trade": "CARGO IS WORTH WHAT THE NEXT PORT WILL PAY",
	"first_salvage": "UNREADABLE SALVAGE ABOARD — REFIT CAN READ WHAT YOU KNOW",
	"hold_full": "HOLD AT CAPACITY — CRATES ARE BEING SCRAPPED",
}

# THE SAME LINES, FOR A DEVICE THAT CANNOT TAP. Only the three that name a
# GESTURE differ -- everything else above is device-neutral and stays in one
# place, so this table can never drift into a second copy of the script.
#
# The ship's very first sentence used to tell a desktop player to tap a bearing,
# on a build where mouse-to-touch emulation is deliberately OFF (see
# project.godot) and tapping does nothing at all. Tutorial._touch and
# ManualScreen._build_flying have both branched on the device since they
# shipped; this table is the third and last place that had to.
#
# "HOLD ON THE BREACH POINT" is deliberately NOT here: CameraRig runs
# _try_begin_hold on the mouse path too, so a hold is one verb on both families
# and a second wording would be a lie in the other direction.
const DESK_LINES := {
	"first_launch": "SURVEY VESSEL ONLINE — HOLD W A S D TO FLY",
	"first_hostiles": "CONTACTS INBOUND — CLICK A CONTACT TO ENGAGE, OR TAB",
	"first_dock_range": "DOCKING CLAMPS AVAILABLE — CLICK THE PORT",
}

const HOLD_TIME := 3.2


static func begin(tree_node: Node) -> void:
	# Slight delay so the line lands after the scene settles in.
	tree_node.get_tree().create_timer(1.2).timeout.connect(func() -> void:
		fire("first_launch")
	)


static func fire(key: String) -> void:
	if not LINES.has(key) or GameState.has_seen_bark(key):
		return
	GameState.mark_bark(key)
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return
	var hud := tree.get_first_node_in_group("hud")
	if hud == null or not hud.has_method("prompt"):
		return
	var text := line_for(key)
	hud.prompt(text)
	# `text` is captured by value, which is what makes the clear match the
	# line that was actually shown rather than re-resolving it later.
	tree.create_timer(HOLD_TIME).timeout.connect(func() -> void:
		var h := tree.get_first_node_in_group("hud")
		if h and h.has_method("clear_prompt_if"):
			h.clear_prompt_if(text)
	)


static func line_for(key: String) -> String:
	# The line this DEVICE gets. Public so the harness can sweep every key for
	# a gesture the player cannot perform, rather than testing the one line
	# somebody remembered to check.
	if not DisplayServer.is_touchscreen_available() and DESK_LINES.has(key):
		return String(DESK_LINES[key])
	return String(LINES.get(key, ""))
